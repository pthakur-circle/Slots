// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "../contracts/Slots.sol";
// import "../interfaces/ISlots.sol";
// import "../utils/Merkle.sol";
// import "../utils/NFT.sol";
// import "@openzeppelin/utils/cryptography/MerkleProof.sol";
// import "forge-std/console.sol";

// import { OlympixUnitTest } from "./OlympixUnitTest.sol";

// contract SlotsTest is OlympixUnitTest("Slots") {
//     address admin = address(0x1);
//     address user = address(0x2);
//     address user2 = address(0x3);
//     address user3 = address(0x4);

//     Slots slots;
//     ISlots.Tier tier;
//     ISlots.WhitelistConfig whitelist;
//     Merkle merkle;
    
//     function setUp() public {
//         slots = new Slots(admin, false);
//         merkle = new Merkle();

//         tier = ISlots.Tier({
//             id: "tier1",
//             price: 1 ether,
//             // numberOfSlots: 100,
//             numberOfPublicSlots: 10,
//             numberOfWhitelistedSlots: 10,
//             numberOfReservedSlots: 0,
//             numberOfPublicSlotsOrdered: 0,
//             publicCapPerAddress: 5,
//             publicStartTime: 1,
//             publicEndTime: 100,
//             isActive: false,
//             nftAddress: address(0),
//             tokenId: 0
//         });
//     }

   
// }


pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/Slots.sol";
import "../interfaces/ISlots.sol";
import "../utils/Merkle.sol";
import "../utils/NFT.sol";
import "@openzeppelin/utils/cryptography/MerkleProof.sol";
import "forge-std/console.sol";

import { OlympixUnitTest } from "./OlympixUnitTest.sol";

contract SlotsTest is OlympixUnitTest("Slots") {
    address admin = address(0x1);
    address user = address(0x2);
    address user2 = address(0x3);
    address user3 = address(0x4);

    Slots slots;
    ISlots.Tier tier;
    ISlots.WhitelistConfig whitelist;
    Merkle merkle;
    
    function setUp() public {
        slots = new Slots(admin, false);
        merkle = new Merkle();

        tier = ISlots.Tier({
            id: "tier1",
            price: 1 ether,
            // numberOfSlots: 100,
            numberOfPublicSlots: 10,
            numberOfWhitelistedSlots: 10,
            numberOfReservedSlots: 0,
            numberOfPublicSlotsOrdered: 0,
            publicCapPerAddress: 5,
            publicStartTime: 1,
            publicEndTime: 100,
            isActive: false,
            nftAddress: address(0),
            tokenId: 0
        });
    }

   

    function test_setNFTAddress_FailWhenNFTMintingIsNotEnabled() public {
        vm.startPrank(admin);
    
        vm.expectRevert(ISlots.NFTMintingNotEnabled.selector);
        slots.setNFTAddress(tier.id, address(0x123));
    
        vm.stopPrank();
    }

    function test_setNFTAddress_SuccessfulSetNFTAddress() public {
        vm.startPrank(admin);
    
        slots = new Slots(admin, true);
    
        slots.createTier(tier);
    
        slots.setNFTAddress(tier.id, address(0x123));
    
        ISlots.Tier memory updatedTier = slots.getTier(tier.id);
        assertEq(updatedTier.nftAddress, address(0x123));
    
        vm.stopPrank();
    }

    function test_overwriteTier_FailWhenNewTierNumberOfPublicSlotsIsLessThanOldTierNumberOfPublicSlots() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.Tier memory newTier = ISlots.Tier({
            id: "tier1",
            price: 1 ether,
            numberOfPublicSlots: 5,
            numberOfWhitelistedSlots: 10,
            numberOfReservedSlots: 0,
            numberOfPublicSlotsOrdered: 0,
            publicCapPerAddress: 5,
            publicStartTime: 1,
            publicEndTime: 100,
            isActive: false,
            nftAddress: address(0),
            tokenId: 0
        });
    
        vm.expectRevert(ISlots.NewTierInvalid.selector);
        slots.overwriteTier(newTier, tier.id);
    
        vm.stopPrank();
    }

    function test_overwriteTier_FailWhenNewTierNumberOfWhitelistedSlotsIsLessThanOldTierNumberOfWhitelistedSlots() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.Tier memory newTier = ISlots.Tier({
            id: "tier1",
            price: 1 ether,
            numberOfPublicSlots: 10,
            numberOfWhitelistedSlots: 5,
            numberOfReservedSlots: 0,
            numberOfPublicSlotsOrdered: 0,
            publicCapPerAddress: 5,
            publicStartTime: 1,
            publicEndTime: 100,
            isActive: false,
            nftAddress: address(0),
            tokenId: 0
        });
    
        vm.expectRevert(ISlots.NewTierInvalid.selector);
        slots.overwriteTier(newTier, tier.id);
    
        vm.stopPrank();
    }

    function test_startSale_SuccessfulStartSale() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        ISlots.Tier memory updatedTier = slots.getTier(tier.id);
        assertTrue(updatedTier.isActive);
    
        vm.stopPrank();
    }

    function test_startSale_FailWhenTierIsActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.expectRevert(ISlots.TierActivationFailed.selector);
        slots.startSale(tier.id);
    
        vm.stopPrank();
    }

    function test_withdraw_SuccessfulWithdraw() public {
        vm.deal(admin, 10 ether);
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        slots.startSale(tier.id);
    
        slots.order{value: 1 ether}(tier.id, "order1");
    
        slots.withdrawAdmin(0);
    
        assertEq(admin.balance, 10 ether);
    
        vm.stopPrank();
    }

    function test_withdrawAdmin_SuccessfulWithdrawAdmin() public {
        vm.deal(admin, 10 ether);
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        slots.startSale(tier.id);
    
        slots.order{value: 1 ether}(tier.id, "order1");
    
        slots.withdrawAdmin(1 ether);
    
        assertEq(admin.balance, 10 ether);
    
        vm.stopPrank();
    }

    function test_addWhitelistConfig_FailWhenRootIsZero() public {
        vm.startPrank(admin);
    
        vm.expectRevert("root cannot be 0");
        slots.addWhitelistConfig(tier.id, "whitelist1", ISlots.WhitelistConfig({
            root: bytes32(0),
            whitelistStartTime: 0,
            whitelistEndTime: 0,
            numberOfWhitelistedSlotsOrdered: 0,
            capPerAddress: 0,
            isActive: false
        }), 0);
    
        vm.stopPrank();
    }

    function test_addWhitelistConfig_SuccessfulAddWhitelistConfig() public {
        vm.startPrank(admin);
    
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(user));
        leaves[1] = keccak256(abi.encodePacked(user2));
        bytes32 root = merkle.getRoot(leaves);
    
        slots.addWhitelistConfig(tier.id, "whitelist1", ISlots.WhitelistConfig({
            root: root,
            whitelistStartTime: 0,
            whitelistEndTime: 0,
            numberOfWhitelistedSlotsOrdered: 0,
            capPerAddress: 0,
            isActive: false
        }), 10);
    
        vm.stopPrank();
    
        (bytes32 rootAdded, uint32 whitelistStartTime, uint32 whitelistEndTime, uint256 numberOfWhitelistedSlotsOrdered, uint256 capPerAddress, bool isActive) = slots.whitelists(tier.id, "whitelist1");
        assertEq(rootAdded, root);
        assertEq(whitelistStartTime, 0);
        assertEq(whitelistEndTime, 0);
        assertEq(numberOfWhitelistedSlotsOrdered, 0);
        assertEq(capPerAddress, 0);
        assertEq(isActive, false);
    }

    function test_setWhitelistActive_SuccessfulSetWhitelistActive() public {
        vm.startPrank(admin);
    
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(user));
        leaves[1] = keccak256(abi.encodePacked(user2));
        bytes32 root = merkle.getRoot(leaves);
    
        slots.addWhitelistConfig(tier.id, "whitelist1", ISlots.WhitelistConfig({
            root: root,
            whitelistStartTime: 0,
            whitelistEndTime: 0,
            numberOfWhitelistedSlotsOrdered: 0,
            capPerAddress: 0,
            isActive: false
        }), 10);
    
        slots.setWhitelistActive(tier.id, "whitelist1", true);
    
        vm.stopPrank();
    
        (bytes32 rootAdded, uint32 whitelistStartTime, uint32 whitelistEndTime, uint256 numberOfWhitelistedSlotsOrdered, uint256 capPerAddress, bool isActive) = slots.whitelists(tier.id, "whitelist1");
        assertEq(rootAdded, root);
        assertEq(whitelistStartTime, 0);
        assertEq(whitelistEndTime, 0);
        assertEq(numberOfWhitelistedSlotsOrdered, 0);
        assertEq(capPerAddress, 0);
        assertEq(isActive, true);
    }

    function test_addReferralCode_FailWhenReferralCodeIsEmpty() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        vm.expectRevert(ISlots.InvalidReferralCode.selector);
        slots.addReferralCode(referral, "tier1", "");
    
        vm.stopPrank();
    }

    function test_addReferralCode_SuccessfulAddReferralCode() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        ISlots.ReferralCode memory addedReferral = slots.getReferral("tier1", "referral1");
    
        assertEq(addedReferral.tierId, "tier1");
        assertEq(addedReferral.referrer, address(0x5));
        assertEq(addedReferral.maxUse, 10);
        assertEq(addedReferral.maxUsePerWallet, 5);
        assertEq(addedReferral.currentUses, 0);
        assertEq(addedReferral.isActive, true);
        assertEq(addedReferral.discount, 1000);
        assertEq(addedReferral.commission, 500);
    
        vm.stopPrank();
    }

    function test_addReferralCode_FailWhenReferralAlreadyExists() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        vm.expectRevert(ISlots.CodeAlreadyExists.selector);
        slots.addReferralCode(referral, "tier1", "referral1");
    
        vm.stopPrank();
    }

    function test_setReferralCodeActive_SuccessfulSetReferralCodeActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        slots.setReferralCodeActive("tier1", "referral1", false);
    
        ISlots.ReferralCode memory updatedReferral = slots.getReferral("tier1", "referral1");
        assertEq(updatedReferral.isActive, false);
    
        vm.stopPrank();
    }

    function test_pause_SuccessfulPause() public {
        vm.startPrank(admin);
    
        slots.pause();
    
        assertTrue(slots.paused());
    
        vm.stopPrank();
    }

    function test_unpause_SuccessfulUnpause() public {
        vm.startPrank(admin);
    
        slots.pause();
        slots.unpause();
    
        assertFalse(slots.paused());
    
        vm.stopPrank();
    }

    function test_orderWhitelist_FailWhenWhitelistRootIsInvalid() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(user));
        leaves[1] = keccak256(abi.encodePacked(user2));
        bytes32 root = merkle.getRoot(leaves);
    
        slots.addWhitelistConfig(tier.id, "whitelist1", ISlots.WhitelistConfig({
            root: root,
            whitelistStartTime: 0,
            whitelistEndTime: 0,
            numberOfWhitelistedSlotsOrdered: 0,
            capPerAddress: 0,
            isActive: false
        }), 10);
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user3, 10 ether);
        vm.startPrank(user3);
    
        bytes32[] memory proof = new bytes32[](0);
    
        vm.expectRevert(ISlots.InvalidMerkleProof.selector);
        slots.orderWhitelist{value: 1 ether}(tier.id, "order1", "whitelist1", proof);
    
        vm.stopPrank();
    }

    function test_orderWhitelistReferral_SuccessfulOrderWhitelistReferral() public {
        vm.startPrank(admin);
    
        slots = new Slots(admin, true);
    
        address nftAddress = address(new NFT("TestNFT", "TNFT"));
        tier.nftAddress = nftAddress;
    
        slots.createTier(tier);
    
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(user));
        leaves[1] = keccak256(abi.encodePacked(user2));
        bytes32 root = merkle.getRoot(leaves);
    
        slots.addWhitelistConfig(tier.id, "whitelist1", ISlots.WhitelistConfig({
            root: root,
            whitelistStartTime: 0,
            whitelistEndTime: 100,
            numberOfWhitelistedSlotsOrdered: 0,
            capPerAddress: 0,
            isActive: false
        }), 10);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        bytes32[] memory proof = merkle.getProof(leaves, 0);
    
        slots.orderWhitelistReferral{value: 1 ether}(tier.id, "order1", "whitelist1", proof, "referral1");
    
        vm.stopPrank();
    
        ISlots.Order memory order = slots.getOrder("order1");
        assertEq(order.buyer, user);
        assertEq(order.tierId, tier.id);
        assertEq(order.amount, 1 ether);
        assertEq(order.timestamp, futureTimestamp);
        assertEq(order.referralCode, "referral1");
    
        assertEq(slots.getUserSlotCount(user, tier.id), 1);
    }

    function test_order_SuccessfulOrder() public {
        vm.startPrank(admin);
    
        slots = new Slots(admin, true);
    
        address nftAddress = address(new NFT("TestNFT", "TNFT"));
        tier.nftAddress = nftAddress;
    
        slots.createTier(tier);
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        slots.order{value: 1 ether}(tier.id, "order1");
    
        vm.stopPrank();
    
        ISlots.Order memory order = slots.getOrder("order1");
        assertEq(order.buyer, user);
        assertEq(order.tierId, tier.id);
        assertEq(order.amount, 1 ether);
        assertEq(order.timestamp, futureTimestamp);
        assertEq(order.referralCode, "");
    
        assertEq(slots.getUserSlotCount(user, tier.id), 1);
    }

    function test_getReferralUses_SuccessfulGetReferralUses() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    
        vm.startPrank(user);
    
        uint256 referralUses = slots.getReferralUses(tier.id, "referral1");
        assertEq(referralUses, 1);
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenReferralMaxUseIsLessThanReferralCurrentUses() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 1,
            maxUsePerWallet: 5,
            currentUses: 2,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        vm.expectRevert(MaxUsesExceeded.selector);
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenDiscountedPriceIsGreaterThanMsgValue() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 5000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        vm.expectRevert(ISlots.InsufficientPayment.selector);
        slots.orderReferral{value: 0.4 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenReferralCurrentUsesIsGreaterThanOrEqualToReferralMaxUse() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 1,
            maxUsePerWallet: 5,
            currentUses: 1,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        vm.expectRevert(ISlots.ReferralCodeAlreadyUsed.selector);
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenReferralIsNotActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: "tier1",
            referrer: address(0x5),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: false,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, "tier1", "referral1");
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        vm.expectRevert(ISlots.InvalidReferralCode.selector);
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_order_FailWhenUserSlotCountIsGreaterThanOrEqualToTierPublicCapPerAddress() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        uint256 futureTimestamp = 10;
        vm.warp(futureTimestamp);
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
        vm.startPrank(user);
    
        for (uint256 i = 0; i < tier.publicCapPerAddress; i++) {
            slots.order{value: 1 ether}(tier.id, string(abi.encodePacked("order", i)));
        }
    
        vm.expectRevert(ISlots.MaxSlotsOrdered.selector);
        slots.order{value: 1 ether}(tier.id, "order5");
    
        vm.stopPrank();
    }
}
