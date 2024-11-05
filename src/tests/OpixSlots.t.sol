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

   

    function test_overwriteTier_FailWhenNewTierIsInvalid() public {
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

    function test_overwriteTier_FailWhenNumberOfWhitelistedSlotsIsLessThanOldTier() public {
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

    function test_startSale_FailWhenTierIsNotActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        vm.warp(101);
    
        vm.expectRevert(ISlots.TierActivationFailed.selector);
        slots.startSale(tier.id);
    
        vm.stopPrank();
    }

    function test_withdrawAdmin_SuccessfulWithdraw() public {
        vm.startPrank(admin);
    
        vm.deal(address(slots), 1 ether);
    
        slots.withdrawAdmin(1 ether);
    
        assertEq(admin.balance, 1 ether);
        assertEq(address(slots).balance, 0);
    
        vm.stopPrank();
    }

    function test_addWhitelistConfig_FailWhenRootIsZero() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        vm.expectRevert("root cannot be 0");
        slots.addWhitelistConfig(tier.id, "whitelist1", ISlots.WhitelistConfig({
            root: bytes32(0),
            whitelistStartTime: 0,
            whitelistEndTime: 0,
            numberOfWhitelistedSlotsOrdered: 0,
            capPerAddress: 0,
            isActive: false
        }), 10);
    
        vm.stopPrank();
    }

    function test_addReferralCode_FailWhenReferralCodeIsEmpty() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        vm.expectRevert(ISlots.InvalidReferralCode.selector);
        slots.addReferralCode(referral, tier.id, "");
    
        vm.stopPrank();
    }

    function test_addReferralCode_FailWhenMaxUseIsZero() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 0,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        vm.expectRevert(ISlots.MaxUseCannotBeZero.selector);
        slots.addReferralCode(referral, tier.id, "referral1");
    
        vm.stopPrank();
    }

    function test_addReferralCode_FailWhenMaxUsePerWalletIsZero() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 0,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        vm.expectRevert(ISlots.MaxUsePerWalletCannotBeZero.selector);
        slots.addReferralCode(referral, tier.id, "referral1");
    
        vm.stopPrank();
    }

    function test_addReferralCode_SuccessfulAddReferralCode() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        ISlots.ReferralCode memory addedReferral = slots.getReferral(tier.id, "referral1");
    
        assertEq(addedReferral.tierId, tier.id);
        assertEq(addedReferral.referrer, address(0x123));
        assertEq(addedReferral.maxUse, 10);
        assertEq(addedReferral.maxUsePerWallet, 5);
        assertEq(addedReferral.currentUses, 0);
        assertEq(addedReferral.isActive, true);
        assertEq(addedReferral.discount, 1000);
        assertEq(addedReferral.commission, 500);
    
        vm.stopPrank();
    }

    function test_addReferralCode_FailWhenReferralCodeAlreadyExists() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        vm.expectRevert(ISlots.CodeAlreadyExists.selector);
        slots.addReferralCode(referral, tier.id, "referral1");
    
        vm.stopPrank();
    }

    function test_setReferralCodeActive_SuccessfulSetReferralCodeActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        slots.setReferralCodeActive(tier.id, "referral1", false);
    
        ISlots.ReferralCode memory updatedReferral = slots.getReferral(tier.id, "referral1");
    
        assertEq(updatedReferral.isActive, false);
    
        vm.stopPrank();
    }

    function test_pause_SuccessfulPause() public {
        vm.startPrank(admin);
        slots.pause();
        vm.stopPrank();
        assertTrue(slots.paused());
    }

    function test_unpause_SuccessfulUnpause() public {
        vm.startPrank(admin);
    
        slots.pause();
    
        slots.unpause();
    
        assert(!slots.paused());
    
        vm.stopPrank();
    }

    function test_order_SuccessfulOrder() public {
        vm.startPrank(admin);
        slots.createTier(tier);
        slots.startSale(tier.id);
        vm.stopPrank();
    
        vm.deal(user, 1 ether);
    
        vm.startPrank(user);
        slots.order{value: 1 ether}(tier.id, "order1");
        vm.stopPrank();
    
        ISlots.Order memory order = slots.getOrder("order1");
        assertEq(order.buyer, user);
        assertEq(order.tierId, tier.id);
        assertEq(order.amount, 1 ether);
        assertEq(order.timestamp, block.timestamp);
        assertEq(order.referralCode, "");
    
        assertEq(slots.getUserSlotCount(user, tier.id), 1);
        assertEq(slots.getTier(tier.id).numberOfPublicSlotsOrdered, 1);
    }

    function test_order_FailWhenNFTMintingFeatureIsEnabled() public {
        vm.startPrank(admin);
    
        slots = new Slots(admin, true);
    
        slots.createTier(tier);
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 1 ether);
    
        vm.startPrank(user);
    
        vm.expectRevert();
        slots.order{value: 1 ether}(tier.id, "order1");
    
        vm.stopPrank();
    }

    function test_getReferralUses_SuccessfulGetReferralUses() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 1 ether);
    
        vm.startPrank(user);
    
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        uint256 referralUses = slots.getReferralUses(tier.id, "referral1");
    
        assertEq(referralUses, 1);
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenReferrerIsInvalid() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 1 ether);
    
        vm.startPrank(user);
    
        vm.expectRevert(ISlots.InvalidReferralCode.selector);
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenMaxUsesExceeded() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 1,
            maxUsePerWallet: 5,
            currentUses: 2,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 1 ether);
    
        vm.startPrank(user);
    
        vm.expectRevert(MaxUsesExceeded.selector);
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenInsufficientPayment() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 0,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 0.9 ether);
    
        vm.startPrank(user);
    
        vm.expectRevert(ISlots.InsufficientPayment.selector);
        slots.orderReferral{value: 0.9 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenReferralCodeIsAlreadyUsed() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 1,
            maxUsePerWallet: 1,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 2 ether);
    
        vm.startPrank(user);
    
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.expectRevert(ISlots.ReferralCodeAlreadyUsed.selector);
        slots.orderReferral{value: 1 ether}(tier.id, "order2", "referral1");
    
        vm.stopPrank();
    }

    function test_validateReferralCode_FailWhenReferralCodeIsInvalid() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: address(0x123),
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: false,
            discount: 1000,
            commission: 500
        });
    
        slots.addReferralCode(referral, tier.id, "referral1");
    
        slots.startSale(tier.id);
    
        vm.stopPrank();
    
        vm.deal(user, 1 ether);
    
        vm.startPrank(user);
    
        vm.expectRevert(ISlots.InvalidReferralCode.selector);
        slots.orderReferral{value: 1 ether}(tier.id, "order1", "referral1");
    
        vm.stopPrank();
    }

    function test_validateOrder_FailWhenTierIsNotActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        vm.stopPrank();
    
        vm.deal(address(this), 1 ether);
    
        vm.expectRevert(ISlots.TierNotActive.selector);
        slots.order{value: 1 ether}(tier.id, "order1");
    }

    function test_validateOrder_FailWhenUserSlotCountIsGreaterThanPublicCapPerAddress() public {
        vm.startPrank(admin);
        slots.createTier(tier);
        slots.startSale(tier.id);
        vm.stopPrank();
    
        vm.deal(user, 10 ether);
    
        vm.startPrank(user);
    
        for (uint256 i = 0; i < 5; i++) {
            slots.order{value: 1 ether}(tier.id, string(abi.encodePacked("order", i)));
        }
    
        vm.expectRevert(ISlots.MaxSlotsOrdered.selector);
        slots.order{value: 1 ether}(tier.id, "order5");
    
        vm.stopPrank();
    }

    function test_validateOrder_FailWhenNumberOfPublicSlotsOrderedPlusNumberOfReservedSlotsIsGreaterThanNumberOfPublicSlots() public {
        vm.startPrank(admin);
        
        ISlots.Tier memory tierWithReservedSlots = ISlots.Tier({
            id: "tier1",
            price: 1 ether,
            numberOfPublicSlots: 10,
            numberOfWhitelistedSlots: 10,
            numberOfReservedSlots: 10,
            numberOfPublicSlotsOrdered: 0,
            publicCapPerAddress: 5,
            publicStartTime: 1,
            publicEndTime: 100,
            isActive: false,
            nftAddress: address(0),
            tokenId: 0
        });
        
        slots.createTier(tierWithReservedSlots);
        slots.startSale(tierWithReservedSlots.id);
        
        vm.stopPrank();
        
        vm.deal(user, 1 ether);
        
        vm.startPrank(user);
        
        vm.expectRevert(ISlots.MaxSlotsOrdered.selector);
        slots.order{value: 1 ether}(tierWithReservedSlots.id, "order1");
        
        vm.stopPrank();
    }
}