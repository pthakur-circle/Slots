// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

// ADDED BY PRANJALI
error MaxUsesExceeded();
// END

import "../interfaces/ISlots.sol";
import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/utils/Pausable.sol";
import "@openzeppelin/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/utils/Multicall.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {NFT} from "../utils/NFT.sol";

/// @title Slots
/// @author Magna
/// @notice A contract to track purchases of a certain asset with different Tiers
contract Slots is ISlots, Pausable, AccessControl, ReentrancyGuard, Multicall {
    /**
     * ---------- STATE ----------
     */
    address public admin;

    bool public NFTMintingFeature;

    /// @notice Stores all tiers, should be a uuid generated off-chain, tierId => Tier
    mapping(string => Tier) public tiers;

    // @notice Stores all whitelist configs, tierId => whitelistId => WhitelistConfig
    mapping(string => mapping(string => WhitelistConfig)) public whitelists;

    /// @notice Stores referral code information for each tier, tier => referral code (string) => ReferralCode (struct)
    mapping(string => mapping(string => ReferralCode)) private referrals;

    /// @notice Stores relevant information on a user's purchases inside of a singular tier, tierId => user address => UserOrders
    mapping(string => mapping(address => UserOrders)) public userOrders;

    /// @notice Stores all orders, should be a uuid generated off-chain, orderId (uuid) => order
    mapping(string => Order) public orders;

    /// @dev admins are given pause authority by default, but additional pause roles can be added via grantRole.
    /// @dev Pause authority can for example be given to external parties that monitor blockchain state to pause in the event of suspicious withdrawals or suspected compromise
    constructor(address _admin, bool _NFTMintingFeature) {
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        NFTMintingFeature = _NFTMintingFeature;
        _grantRole(ADMIN, _admin);
        _grantRole(PAUSE_AUTHORITY, _admin);
    }

    /**
     * ------- NFT MINTING FEATURE -------
     */
    function setNFTAddress(
        string memory tierId,
        address _NFTAddress
    ) external onlyRole(ADMIN) {
        if (!NFTMintingFeature) revert NFTMintingNotEnabled();
        tiers[tierId].nftAddress = _NFTAddress;
    }

    /**
     * ---------- ADMIN WRITE ACTIONS ----------
     */

    /// @notice Creates a new tier
    /// @param tier The Tier struct to create
    function createTier(Tier memory tier) external override onlyRole(ADMIN) {
        validateTier(tier);

        tiers[tier.id] = tier;
        emit TierCreated(tier.id);
    }

    /// @notice Overwrites an existing tier
    /// @param newTier The Tier struct to overwrite
    /// @param tierId The id of the tier to overwrite
    /// @dev This function is destructive and should only be used in extreme circumstances (should be a warning in the app)
    function overwriteTier(
        Tier memory newTier,
        string memory tierId
    ) external override onlyRole(ADMIN) {
        Tier memory oldTier = tiers[tierId];

        // if (newTier.id != oldTier.id) revert TierIdMismatch(); // comparing strings in solidity is stupid (have to hash each and check equality of hash)
        if (newTier.numberOfPublicSlots < oldTier.numberOfPublicSlots)
            revert NewTierInvalid();
        if (newTier.numberOfWhitelistedSlots < oldTier.numberOfWhitelistedSlots)
            revert NewTierInvalid();

        validateTier(newTier);
        tiers[tierId] = newTier;

        emit TierOverwritten(tierId);
    }

    /// @notice Starts the sale for a tier
    /// @param tierId The id of the tier to start the sale for
    function startSale(string memory tierId) external override onlyRole(ADMIN) {
        Tier storage tier = tiers[tierId];

        if (
            !tier.isActive &&
            tier.publicStartTime <= block.timestamp &&
            block.timestamp <= tier.publicEndTime
        ) {
            tier.isActive = true;
        } else {
            revert TierActivationFailed();
        }
    }

    /// @notice Withdraws admin funds in ETH
    /// @param amount The amount of ETH to withdraw
    /// @dev If amount is 0, all ETH in the contract will be withdrawn
    function withdrawAdmin(
        uint256 amount
    ) external override nonReentrant onlyRole(ADMIN) {
        if (amount == 0) {
            amount = address(this).balance;
        }

        (bool sent, ) = admin.call{value: amount}("");
        require(sent, "Failed to send Ether");

        emit AdminWithdrawn(amount);
    }

    /// @notice Sets the whitelist config for a tier
    /// @param tierId The id of the tier to set the whitelist config for
    /// @param config The whitelist config to set
    /// @param totalNumberOfWhitelistedSlots The total number of whitelisted slots for the tier
    /// @dev On app side, ensure that the # of addresses in the root aligns with numberOfWhitelistedSlots
    function addWhitelistConfig(
        string memory tierId,
        string memory whitelistId,
        WhitelistConfig memory config,
        uint256 totalNumberOfWhitelistedSlots
    ) external override onlyRole(ADMIN) {
        require(config.root != bytes32(0), "root cannot be 0"); // custom error this
        Tier storage tier = tiers[tierId];

        whitelists[tierId][whitelistId] = config;
        tier.numberOfWhitelistedSlots = totalNumberOfWhitelistedSlots;

        emit WhitelistRootUpdated(tierId);
    }

    function setWhitelistActive(
        string memory tierId,
        string memory whitelistId,
        bool isActive
    ) external override onlyRole(ADMIN) {
        WhitelistConfig storage config = whitelists[tierId][whitelistId];
        config.isActive = isActive;
    }

    /// @notice Adds a referral code to a tier
    /// @param referral The ReferralCode struct to add
    /// @param tierId The id of the tier to add the referral code to
    /// @param referralCode The referral code to add
    function addReferralCode(
        ReferralCode memory referral,
        string memory tierId,
        string memory referralCode
    ) external override onlyRole(ADMIN) {
        if (bytes(referralCode).length == 0) revert InvalidReferralCode();
        if (referral.maxUse == 0) revert MaxUseCannotBeZero();
        if (referral.maxUsePerWallet == 0) revert MaxUsePerWalletCannotBeZero();
        if (referrals[tierId][referralCode].referrer != address(0))
            revert CodeAlreadyExists();

        referrals[tierId][referralCode] = referral;

        emit ReferralCodeCreated(referralCode, referral.referrer);
    }

    /// @notice Deactivates a referral code
    /// @param tierId The id of the tier to deactivate the referral code for
    /// @param referralCode The referral code to deactivate
    function setReferralCodeActive(
        string memory tierId,
        string memory referralCode,
        bool isActive
    ) external override {
        ReferralCode storage referral = referrals[tierId][referralCode];

        referral.isActive = isActive;

        emit ReferralCodeDeactivated(referralCode);
    }

    /// @notice Rescues funds from the contract to an address
    /// @param errantTokenAddress The address of the token to rescue
    /// @param rescueAddress The address to rescue the funds to
    function rescueFunds(
        address errantTokenAddress,
        address rescueAddress
    ) external override nonReentrant onlyRole(ADMIN) {
        SafeTransferLib.safeTransferAll(errantTokenAddress, rescueAddress);
    }

    /// @notice Pauses the contract
    /// @dev refer to constructor for more info on pause authority
    function pause() external override onlyRole(PAUSE_AUTHORITY) {
        _pause();
    }

    /// @notice Unpauses the contract
    /// @dev refer to constructor for more info on pause authority
    function unpause() external override onlyRole(PAUSE_AUTHORITY) {
        _unpause();
    }

    /**
     * ---------- USER WRITE ACTIONS ----------
     */

    /// @notice Orders a tier
    /// @param tierId The id of the tier to order
    /// @param orderId The id of the order to create
    function order(
        string memory tierId,
        string memory orderId
    ) external payable override nonReentrant {
        Tier storage tier = tiers[tierId];
        validateOrder(tier, true, false, new bytes32[](0), "", "");

        _order(tier, orderId, "", "", true, false);
    }

    /// @notice Orders a tier with a whitelist proof
    /// @param tierId The id of the tier to order
    /// @param orderId The id of the order to create
    /// @param proof The merkle proof to use for the whitelist
    function orderWhitelist(
        string memory tierId,
        string memory orderId,
        string memory whitelistId,
        bytes32[] calldata proof
    ) external payable override nonReentrant {
        Tier storage tier = tiers[tierId];
        validateOrder(tier, false, false, proof, "", whitelistId);

        _order(tier, orderId, "", whitelistId, false, false);
    }

    /// @notice Orders a tier with a referral code
    /// @param tierId The id of the tier to order
    /// @param orderId The id of the order to create
    /// @param referralCode The referral code to use
    function orderReferral(
        string memory tierId,
        string memory orderId,
        string memory referralCode
    ) external payable override nonReentrant {
        Tier storage tier = tiers[tierId];
        validateOrder(tier, true, true, new bytes32[](0), referralCode, "");

        _order(tier, orderId, referralCode, "", true, true);

        userOrders[tierId][msg.sender].referralUses[referralCode]++;
    }

    /// @notice Orders a tier with a whitelist proof and a referral code
    /// @param tierId The id of the tier to order
    /// @param orderId The id of the order to create
    /// @param proof The merkle proof to use for the whitelist
    /// @param referralCode The referral code to use
    function orderWhitelistReferral(
        string memory tierId,
        string memory orderId,
        string memory whitelistId,
        bytes32[] calldata proof,
        string memory referralCode
    ) external payable override nonReentrant {
        Tier storage tier = tiers[tierId];
        validateOrder(tier, false, true, proof, referralCode, whitelistId);

        _order(tier, orderId, referralCode, whitelistId, false, true);

        userOrders[tierId][msg.sender].referralUses[referralCode]++;
    }

    /// @notice Internal function to order a tier
    /// @param tier The Tier struct to order
    /// @param orderId The id of the order to create
    /// @param referralCode The referral code to use
    /// @param isPublic Whether the order is public or not
    /// @dev This function is internal and is only called by other order functions

    // ADDED BY PRANJALI
    // function _order(
    //     Tier storage tier,
    //     string memory orderId,
    //     string memory referralCode,
    //     string memory whitelistId,
    //     bool isPublic,
    //     bool isReferral
    // ) internal {
    //     string memory id = tier.id;

    //     Order memory newOrder = Order({
    //         buyer: msg.sender,
    //         tierId: id,
    //         amount: msg.value,
    //         timestamp: block.timestamp,
    //         referralCode: referralCode
    //     });

    //     orders[orderId] = newOrder;

    //     isPublic
    //         ? tier.numberOfPublicSlotsOrdered++
    //         : whitelists[id][whitelistId].numberOfWhitelistedSlotsOrdered++;

    //     userOrders[id][msg.sender].numberOfSlotsOrdered++;

    //     if (!isPublic) userOrders[id][msg.sender].whitelistUses++;

    //     if (NFTMintingFeature) {
    //         NFT(tier.nftAddress).mint(msg.sender, tier.tokenId);
    //         tier.tokenId++;
    //     }

    //     ReferralCode memory referral = referrals[id][referralCode];
    //     if (isReferral) { // TODO: Introduce claim rewards function for referral code rather than sending to referrer in this function
    //         (bool sent, ) = referral.referrer.call{
    //             value: (tier.price * referral.discount) / 10000
    //         }("");
    //         require(sent, "Failed to send Ether"); // TODO: change to if revert
    //     }

    //     emit SlotOrdered(msg.sender, id, msg.value, referralCode, tier.tokenId);
    // }

    function _order(
        Tier storage tier,
        string memory orderId,
        string memory referralCode,
        string memory whitelistId,
        bool isPublic,
        bool isReferral
    ) internal {
        string memory id = tier.id;

        Order memory newOrder = Order({
            buyer: msg.sender,
            tierId: id,
            amount: msg.value,
            timestamp: block.timestamp,
            referralCode: referralCode
        });

        orders[orderId] = newOrder;

        if (isPublic) {
            require(tier.numberOfPublicSlotsOrdered < tier.numberOfPublicSlots, "Max public slots reached");
            tier.numberOfPublicSlotsOrdered++; // Increment only if order is successful
        } else {
            require(whitelists[id][whitelistId].numberOfWhitelistedSlotsOrdered < tiers[id].numberOfWhitelistedSlots, "Max whitelisted slots reached");
            whitelists[id][whitelistId].numberOfWhitelistedSlotsOrdered++;
        }

        userOrders[id][msg.sender].numberOfSlotsOrdered++;

        if (!isPublic) userOrders[id][msg.sender].whitelistUses++;

        // Check NFT minting feature
        if (NFTMintingFeature) {
            NFT(tier.nftAddress).mint(msg.sender, tier.tokenId);
            tier.tokenId++;
        }

        // Check for referrals
        if (isReferral) {
            require(referralCodeExists(id, referralCode), "Referral code does not exist");
            (bool sent, ) = referrals[id][referralCode].referrer.call{
                value: (tier.price * referrals[id][referralCode].discount) / 10000
            }("");
            require(sent, "Failed to send Ether");  // Keeping the revert as it is critical
        }

        emit SlotOrdered(msg.sender, id, msg.value, referralCode, tier.tokenId);
    }

    // END

    /**
     * ---------- VIEW FUNCTIONS ----------
     */

    /// @notice Gets a tier
    /// @param tierId The id of the tier to get
    function getTier(
        string memory tierId
    ) external view override returns (Tier memory) {
        return tiers[tierId];
    }

    /// @notice Gets a referral code
    /// @param tierId The id of the tier to get the referral code for
    /// @param referralCode The referral code to get
    function getReferral(
        string memory tierId,
        string memory referralCode
    ) external view override returns (ReferralCode memory) {
        return referrals[tierId][referralCode];
    }

    /// @notice Gets the number of referral uses for a user
    /// @param tierId The id of the tier to get the referral uses for
    /// @param referralCode The referral code to get the uses for
    function getReferralUses(
        string memory tierId,
        string memory referralCode
    ) external view returns (uint256 uses) {
        return userOrders[tierId][msg.sender].referralUses[referralCode];
    }

    /// @notice Gets an order
    /// @param orderId The id of the order to get
    function getOrder(
        string memory orderId
    ) external view override returns (Order memory) {
        return orders[orderId];
    }

    /// @notice Gets the number of slots ordered by a user
    /// @param user The user to get the number of slots ordered for
    /// @param tierId The id of the tier to get the number of slots ordered for
    function getUserSlotCount(
        address user,
        string memory tierId
    ) public view returns (uint256) {
        return userOrders[tierId][user].numberOfSlotsOrdered;
    }

    /**
     * ---------- INTERNAL VALIDATION FUNCTIONS ----------
     */

    /// @notice Validates a referral code
    /// @param tierId The id of the tier to validate the referral code for
    /// @param referralCode The referral code to validate
    function validateReferralCode(
        string memory tierId,
        string memory referralCode,
        uint256 tierPrice
    ) internal view returns (bool) {
        ReferralCode memory referral = referrals[tierId][referralCode];
        // ADDED BY PRANJALI
        if (referral.referrer == address(0)) revert InvalidReferralCode(); // Check for empty referrer
        if (referral.maxUse < referral.currentUses) revert MaxUsesExceeded(); // Added check
        // END

        uint256 discountedPrice = (tierPrice * (10000 - referral.discount)) /
            10000;
        if (discountedPrice > msg.value) revert InsufficientPayment();
        if (referral.referrer != address(0) && referral.isActive) { // checking whether valid referral code
            if ( // checking whether max uses has been reached
                referral.currentUses < referral.maxUse &&
                userOrders[tierId][msg.sender].referralUses[referralCode] <
                referral.maxUsePerWallet
            ) {
                return true;
            }
            revert ReferralCodeAlreadyUsed();
        }
        revert InvalidReferralCode();
    }

    /// @notice Validates an address against a merkle root
    /// @param root The merkle root to validate against
    /// @param proof The merkle proof to validate
    /// @dev Merkle leafs in this case are strictly the address of the user
    function validateLeaf(bytes32 root, bytes32[] memory proof) internal view {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        bool isValidLeaf = MerkleProof.verify(proof, root, leaf);
        if (!isValidLeaf) revert InvalidMerkleProof();
    }

    // ADDED BY PRANJALI
    function referralCodeExists(string memory tierId, string memory referralCode) internal view returns (bool) {
        return referrals[tierId][referralCode].referrer != address(0);
    }
    // END

    /// @notice Validates a tier
    /// @param tier The Tier struct to validate
    function validateTier(Tier memory tier) internal pure {
        if (bytes(tier.id).length == 0) revert IdEmpty();
        if (tier.price == 0) revert PriceCannotBeZero();
        if (tier.numberOfPublicSlots == 0) revert PublicSlotsCannotBeZero();
        if (tier.publicStartTime == 0) revert TimeCannotBeZero();
        if (tier.publicEndTime == 0) revert TimeCannotBeZero();
        if (tier.publicCapPerAddress == 0) revert PublicCapCannotBeZero();
    }

    /// @notice Validates an order
    /// @param tier The Tier struct to validate the order against
    /// @param isPublic Whether the order is public or not
    /// @param proof The merkle proof to validate the order against
    /// @param referralCode The referral code to validate the order against
    /// @param whitelistId The whitelist id to validate the order against
    function validateOrder( // TODO: split up into smaller functions, it's a bit of a mess rn
        Tier memory tier,
        bool isPublic,
        bool isReferral,
        bytes32[] memory proof,
        string memory referralCode,
        string memory whitelistId
    ) internal view {
        string memory id = tier.id;
        WhitelistConfig memory whitelist = whitelists[id][whitelistId];

        if (!tier.isActive) revert TierNotActive();
        if (getUserSlotCount(msg.sender, id) >= tier.publicCapPerAddress)
            revert MaxSlotsOrdered();
        // TODO: cache block.timestamp in a variable
        if (isPublic) {
            if (tier.publicStartTime > block.timestamp || block.timestamp > tier.publicEndTime) {
                revert TierNotActive();
            }

            if (tier.numberOfPublicSlotsOrdered + tier.numberOfReservedSlots >= tier.numberOfPublicSlots) {
                revert MaxSlotsOrdered();
            }
            // ADDED BY PRANJALI
            if (tier.price == 0) revert PriceCannotBeZero();
            // END
        } else {
            validateLeaf(whitelist.root, proof);

            if (whitelist.whitelistStartTime > block.timestamp || block.timestamp > whitelist.whitelistEndTime) {
                revert TierNotActive();
            }

            if (whitelist.numberOfWhitelistedSlotsOrdered >= tier.numberOfWhitelistedSlots) {
                revert MaxSlotsOrdered();
            }
        }

        if (isReferral) {
            if (!validateReferralCode(tier.id, referralCode, tier.price)) revert InvalidReferralCode();
        } else {
            // checking price in here rather than outside, b/c you are allowed to purchase with lower price if you have referral code w/ discount
            if (tier.price > msg.value) revert InsufficientPayment();
        }
    }
}
