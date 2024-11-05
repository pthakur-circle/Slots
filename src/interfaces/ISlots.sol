// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

abstract contract ISlots {
    /**
     * ---------- CONSTANTS ----------
     */

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant PAUSE_AUTHORITY = keccak256('PAUSE_AUTHORITY');

    /**
     * ---------- ERRORS ----------
     */
    error InvalidMerkleProof();
    error InvalidReferralCode();
    error ReferralCodeAlreadyUsed();
    error NotAdmin();
    error TierNotActive();
    error TierActivationFailed();
    error InsufficientPayment();
    error MaxSlotsOrdered();
    error ZeroAddress();

    error PriceCannotBeZero();
    error PublicSlotsCannotBeZero();
    error WhitelistedSlotsCannotBeZero();
    error TimeCannotBeZero();
    error IdEmpty();
    error CodeEmpty();
    error MaxUseCannotBeZero();
    error MaxUsePerWalletCannotBeZero();
    error CodeAlreadyExists();
    error PublicCapCannotBeZero();
    error TierIdMismatch();
    error NewTierInvalid();
    error ReferralCodeNotActive();
    error NFTMintingNotEnabled();

    /**
     * ---------- STRUCTS ----------
     */
    struct Tier {
        string id;
        // TODO: change from uint256 to something smaller?
        uint256 price; // price in wei
        uint256 numberOfPublicSlots; // any slots that are not public are whitelisted
        uint256 numberOfWhitelistedSlots; // merkle root doesn't need to adhere to this in TS since we could have more addresses than whitelisted slots (first come first serve)
        uint256 numberOfReservedSlots; // reserved slots will pull from public slots, not from whitelisted (check validateOrder for implementation)
        uint256 numberOfPublicSlotsOrdered;
        uint256 publicCapPerAddress;
        uint32 publicStartTime;
        uint32 publicEndTime;
        bool isActive;
        address nftAddress;
        uint256 tokenId;
    }

    struct ReferralCode {
        string tierId;
        address referrer;
        uint256 maxUse;
        uint256 maxUsePerWallet;
        uint256 currentUses;
        bool isActive;
        uint256 discount; // in bps
        uint256 commission; // in bps
        // TODO: potentially increase precision from bps to more?
    }

    struct WhitelistConfig {
        bytes32 root; // root of the merkle tree where each leaf is the address of a whitelisted user
        uint32 whitelistStartTime;
        uint32 whitelistEndTime;
        uint256 numberOfWhitelistedSlotsOrdered;
        uint256 capPerAddress; 
        bool isActive;
    }

    struct Order {
        address buyer;
        string tierId;
        uint256 amount;
        uint256 timestamp;
        string referralCode;
    }

    struct UserOrders {
        uint32 numberOfSlotsOrdered;
        uint32 whitelistUses;
        mapping(string => uint64) referralUses;
    }

    /**
     * ---------- EVENTS ----------
     */
    event TierCreated(string indexed id);
    event TierUpdated(string indexed id);
    event SlotOrdered(
        address indexed buyer,
        string indexed id,
        uint256 amount,
        string referralCode,
        uint256 nftId
    ); 
    event ReferralCodeCreated(string referralCode, address referrer);
    event ReferralCodeDeactivated(string referralCode);
    event ReferralCodeUsed(string referralCode, address user);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event TierOverwritten(string indexed id);
    event AdminWithdrawn(uint256 amount);
    event WhitelistRootUpdated(string indexed id);


    // admin actions:
    function createTier(Tier memory tier) external virtual;
    function overwriteTier(
        Tier memory newTier,
        string memory tierId
    ) external virtual; // should we allow updating tiers? could make more sense to just have functions for specific fields on a tier
    function startSale(string memory tierId) external virtual; // starts the sale for a tier

    function withdrawAdmin(uint256 amount) external virtual; // withdraws eth funds generated from the contract to the admin
    function addWhitelistConfig(
        string memory tierId,
        string memory whitelistId,
        WhitelistConfig memory config,
        uint256 totalNumberOfWhitelistedSlots
    ) external virtual;

    function setWhitelistActive(string memory tierId, string memory whitelistId, bool isActive) external virtual;

    function addReferralCode(
        ReferralCode memory referral,
        string memory tierId,
        string memory referralCode
    ) external virtual;
    function setReferralCodeActive(
        string memory tierId,
        string memory referralCode,
        bool isActive
    ) external virtual;

    function pause() external virtual;
    function unpause() external virtual;
    function rescueFunds(
        address errantToken,
        address rescueAddress
    ) external virtual;

    // user actions:
    function order(
        string memory tierId,
        string memory orderId
    ) external payable virtual;

    function orderReferral(
        string memory tierId,
        string memory orderId,
        string memory referralCode
    ) external payable virtual;

    function orderWhitelist(
        string memory tierId,
        string memory whitelistId,
        string memory orderId,
        bytes32[] memory proof
    ) external payable virtual;

    function orderWhitelistReferral(
        string memory tierId,
        string memory whitelistId,
        string memory orderId,
        bytes32[] memory proof,
        string memory referralCode
    ) external payable virtual;

    // view functions:
    function getTier(
        string memory tierId
    ) external view virtual returns (Tier memory);
    function getReferral(
        string memory tierId,
        string memory referralCode
    ) external view virtual returns (ReferralCode memory);
    function getOrder(
        string memory orderId
    ) external view virtual returns (Order memory);
}
