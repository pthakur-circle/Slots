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

    function test_startSale_FailWhenTierIsActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        slots.startSale(tier.id);
    
        vm.expectRevert(ISlots.TierActivationFailed.selector);
        slots.startSale(tier.id);
    
        vm.stopPrank();
    }

    function test_withdrawAdmin_SuccessfulWithdraw() public {
        vm.startPrank(admin);
    
        uint256 depositAmount = 1 ether;
        vm.deal(address(slots), depositAmount);
    
        uint256 withdrawAmount = 0.5 ether;
        slots.withdrawAdmin(withdrawAmount);
    
        assertEq(admin.balance, withdrawAmount);
        assertEq(address(slots).balance, depositAmount - withdrawAmount);
    
        vm.stopPrank();
    }

    function test_addReferralCode_FailWhenReferralCodeAlreadyExists() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: user,
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 1000
        });
    
        string memory referralCode = "referralCode1";
        slots.addReferralCode(referral, tier.id, referralCode);
    
        vm.expectRevert(ISlots.CodeAlreadyExists.selector);
        slots.addReferralCode(referral, tier.id, referralCode);
    
        vm.stopPrank();
    }

    function test_setReferralCodeActive_SuccessfulSetReferralCodeActive() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: user,
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 1000
        });
    
        string memory referralCode = "referralCode1";
        slots.addReferralCode(referral, tier.id, referralCode);
    
        slots.setReferralCodeActive(tier.id, referralCode, false);
    
        ISlots.ReferralCode memory updatedReferral = slots.getReferral(tier.id, referralCode);
        assertFalse(updatedReferral.isActive);
    
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

    function test_getTier_SuccessfulGetTier() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.Tier memory retrievedTier = slots.getTier(tier.id);
    
        assertEq(retrievedTier.id, tier.id);
        assertEq(retrievedTier.price, tier.price);
        assertEq(retrievedTier.numberOfPublicSlots, tier.numberOfPublicSlots);
        assertEq(retrievedTier.numberOfWhitelistedSlots, tier.numberOfWhitelistedSlots);
        assertEq(retrievedTier.numberOfReservedSlots, tier.numberOfReservedSlots);
        assertEq(retrievedTier.numberOfPublicSlotsOrdered, tier.numberOfPublicSlotsOrdered);
        assertEq(retrievedTier.publicCapPerAddress, tier.publicCapPerAddress);
        assertEq(retrievedTier.publicStartTime, tier.publicStartTime);
        assertEq(retrievedTier.publicEndTime, tier.publicEndTime);
        assertEq(retrievedTier.isActive, tier.isActive);
        assertEq(retrievedTier.nftAddress, tier.nftAddress);
        assertEq(retrievedTier.tokenId, tier.tokenId);
    
        vm.stopPrank();
    }

    function test_getReferral_SuccessfulGetReferral() public {
        vm.startPrank(admin);
    
        slots.createTier(tier);
    
        ISlots.ReferralCode memory referral = ISlots.ReferralCode({
            tierId: tier.id,
            referrer: user,
            maxUse: 10,
            maxUsePerWallet: 5,
            currentUses: 0,
            isActive: true,
            discount: 1000,
            commission: 1000
        });
    
        string memory referralCode = "referralCode1";
        slots.addReferralCode(referral, tier.id, referralCode);
    
        vm.stopPrank();
    
        vm.startPrank(user);
    
        ISlots.ReferralCode memory retrievedReferral = slots.getReferral(tier.id, referralCode);
        assertEq(retrievedReferral.referrer, referral.referrer);
        assertEq(retrievedReferral.maxUse, referral.maxUse);
        assertEq(retrievedReferral.maxUsePerWallet, referral.maxUsePerWallet);
        assertEq(retrievedReferral.currentUses, referral.currentUses);
        assertEq(retrievedReferral.isActive, referral.isActive);
        assertEq(retrievedReferral.discount, referral.discount);
        assertEq(retrievedReferral.commission, referral.commission);
    
        vm.stopPrank();
    }
}