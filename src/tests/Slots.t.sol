// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "../contracts/Slots.sol";
// import "../interfaces/ISlots.sol";
// import "../utils/Merkle.sol";
// import "../utils/NFT.sol";
// import "@openzeppelin/utils/cryptography/MerkleProof.sol";
// import "forge-std/console.sol";

// contract SlotsTest is Test {
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

//     function testHappyPath() public {
//         vm.startPrank(admin);

//         slots.createTier(tier);
//         vm.deal(user, 1000 ether);
//         slots.startSale("tier1");

//         vm.startPrank(user);

//         slots.order{value: 1 ether}("tier1", "order1");
//         assertEq(slots.getUserSlotCount(user, "tier1"), 1);

//         ISlots.Order memory order = slots.getOrder("order1");
//         assertEq(order.buyer, user);
//         assertEq(order.tierId, "tier1");
//         assertEq(order.amount, 1 ether);
//         assertEq(order.timestamp, block.timestamp);
//         string memory orderid = "order1";

//         (address buyer, string memory tierId, uint256 amount, uint256 timestamp, string memory referralCode)= slots.orders(orderid);

//         vm.stopPrank();
//     }

//     function testMaxSlotsOrdered() public {
//         vm.startPrank(admin);

//         slots.createTier(tier);
//         slots.startSale("tier1");

//         vm.deal(user, 1000 ether);
//         vm.startPrank(user);
        
//         for(uint256 i = 0; i < 5; i++) { // maxcap per address is 5
//             slots.order{value: 1 ether}("tier1", "order1");
//         }

//         vm.expectRevert(ISlots.MaxSlotsOrdered.selector);
//         slots.order{value: 1 ether}("tier1", "order2");

//         vm.stopPrank();
//     }

//     function testOnlyWhitelist() public {
//         vm.startPrank(admin);
        
//         slots.createTier(tier);
//         slots.startSale("tier1");
        
//         vm.deal(user, 1000 ether);
        
//         bytes32[] memory data = new bytes32[](2);
//         data[0] = keccak256(abi.encodePacked(user));
//         data[1] = keccak256(abi.encodePacked(user2));
//         bytes32 root = merkle.getRoot(data);
        
//         whitelist = ISlots.WhitelistConfig({
//             root: root,
//             whitelistStartTime: 0,
//             whitelistEndTime: 100,
//             numberOfWhitelistedSlotsOrdered: 0,
//             capPerAddress: 10,
//             isActive: true
//         });

//         slots.addWhitelistConfig("tier1", "whitelist1", whitelist, 10);
        
//         vm.startPrank(user);
//         bytes32[] memory proof = merkle.getProof(data, 0);
//         merkle.verifyProof(root, proof, keccak256(abi.encodePacked(user)));
//         for(uint i=0; i<5; i++) {
//             slots.orderWhitelist{value: 1 ether}("tier1", "order1", "whitelist1", proof);
//         }

//         vm.expectRevert(ISlots.MaxSlotsOrdered.selector);
//         slots.orderWhitelist{value: 1 ether}("tier1", "order2", "whitelist1", proof);
//     }

//     function testReservedSlots() public {
//         vm.startPrank(admin);
        
//         // Create a tier with 10 reserved slots and 14 public slots
//         ISlots.Tier memory reservedTier = ISlots.Tier({
//             id: "reservedTier",
//             price: 1 ether,
//             numberOfPublicSlots: 14,
//             numberOfWhitelistedSlots: 0,
//             numberOfReservedSlots: 10,
//             numberOfPublicSlotsOrdered: 0,
//             publicCapPerAddress: 5,
//             publicStartTime: 1,
//             publicEndTime: 100,
//             isActive: false,
//             nftAddress: address(0),
//             tokenId: 0
//         });

//         slots.createTier(reservedTier);
//         slots.startSale("reservedTier");

//         vm.stopPrank();

//         vm.deal(user, 1000 ether);
//         vm.startPrank(user);

//         // Purchase the first 4 public slots
//         for(uint256 i = 0; i < 4; i++) {
//             slots.order{value: 1 ether}("reservedTier", string(abi.encodePacked("order", i)));
//         }

//         // The next purchase should revert because the reserved slots are pulling from public
//         vm.expectRevert(ISlots.MaxSlotsOrdered.selector);
//         slots.order{value: 1 ether}("reservedTier", "orderFail");

//         vm.stopPrank();
//     }

//     function testReservedSlotsWithWhitelist() public {
//         vm.startPrank(admin);
        
//         // Create a tier with 10 reserved slots, 10 whitelisted slots, and 14 public slots
//         ISlots.Tier memory reservedTier = ISlots.Tier({
//             id: "reservedTier",
//             price: 1 ether,
//             numberOfPublicSlots: 14,
//             numberOfWhitelistedSlots: 10,
//             numberOfReservedSlots: 10,
//             numberOfPublicSlotsOrdered: 0,
//             publicCapPerAddress: 5,
//             publicStartTime: 1,
//             publicEndTime: 100,
//             isActive: false,
//             nftAddress: address(0),
//             tokenId: 0
//         });

//         slots.createTier(reservedTier);
//         slots.startSale("reservedTier");

//         // Set up whitelist
//         bytes32[] memory data = new bytes32[](2);
//         data[0] = keccak256(abi.encodePacked(user));
//         data[1] = keccak256(abi.encodePacked(user2));
//         bytes32 root = merkle.getRoot(data);
        
//         whitelist = ISlots.WhitelistConfig({
//             root: root,
//             whitelistStartTime: 0,
//             whitelistEndTime: 100,
//             numberOfWhitelistedSlotsOrdered: 0,
//             capPerAddress: 10,
//             isActive: true
//         });

//         slots.addWhitelistConfig("reservedTier", "whitelist1", whitelist, 10);

//         vm.stopPrank();

//         vm.deal(user, 1000 ether);
//         vm.deal(user2, 1000 ether);
//         vm.startPrank(user);

//         // Purchase the first 4 public slots
//         for(uint256 i = 0; i < 4; i++) {
//             slots.order{value: 1 ether}("reservedTier", "order1");
//         }

//         // Purchase 2 whitelisted slots
//         vm.startPrank(user2);
//         bytes32[] memory proof = merkle.getProof(data, 1);
//         for(uint256 i = 4; i < 6; i++) {
//             slots.orderWhitelist{value: 1 ether}("reservedTier", "order1", "whitelist1", proof);
//         }

//         // The next purchase should revert because the reserved slots are pulling from public
//         vm.expectRevert(ISlots.MaxSlotsOrdered.selector);
//         slots.order{value: 1 ether}("reservedTier", "orderFail");

//         vm.stopPrank();
//     }
    
//     function testReferralCode() public {
//         vm.startPrank(admin);
        
//         slots.createTier(tier);
//         slots.startSale("tier1");
        
//         ISlots.ReferralCode memory referral = ISlots.ReferralCode({
//             tierId: "tier1",
//             referrer: user2,
//             maxUse: 10,
//             maxUsePerWallet: 1,
//             currentUses: 0,
//             isActive: true,
//             discount: 100,
//             commission: 100
//         });
        
//         slots.addReferralCode(referral, "tier1", "code1");
        
//         vm.deal(user, 1000 ether);
//         vm.startPrank(user);
        
//         slots.orderReferral{value: 0.99 ether}("tier1", "order1", "code1"); // note that they're buying with less than the full price
//         assertEq(slots.getUserSlotCount(user, "tier1"), 1);
//         assertEq(slots.getReferralUses("tier1", "code1"), 1);
//         assertEq(user2.balance, 0.01 ether); // make sure the referrer got the commission

//         bytes memory error = abi.encodeWithSignature("ReferralCodeAlreadyUsed()");
//         vm.expectRevert(error);
//         slots.orderReferral{value: 1 ether}("tier1", "order1", "code1");

//     }

//     function testWhitelist() public {
//         vm.startPrank(admin);
        
//         slots.createTier(tier);
//         slots.startSale("tier1");
        
//         ISlots.ReferralCode memory referral = ISlots.ReferralCode({
//             tierId: "tier1",
//             referrer: user2,
//             maxUse: 10,
//             maxUsePerWallet: 1,
//             currentUses: 0,
//             isActive: true,
//             discount: 100,
//             commission: 100
//         });
        
//         slots.addReferralCode(referral, "tier1", "code1");

        
//         vm.deal(user, 1000 ether);
        
//         bytes32[] memory data = new bytes32[](2);
//         data[0] = keccak256(abi.encodePacked(user));
//         data[1] = keccak256(abi.encodePacked(user2));
//         bytes32 root = merkle.getRoot(data);
        
//         whitelist = ISlots.WhitelistConfig({
//             root: root,
//             whitelistStartTime: 0,
//             whitelistEndTime: 100,
//             numberOfWhitelistedSlotsOrdered: 0,
//             capPerAddress: 10,
//             isActive: true
//         });

//         slots.addWhitelistConfig("tier1", "whitelist1", whitelist, 10);
        
//         vm.startPrank(user);
//         bytes32[] memory proof = merkle.getProof(data, 0);
//         slots.orderWhitelistReferral{value: 1 ether}("tier1", "order1", "whitelist1", proof, "code1");
//         assertEq(slots.getUserSlotCount(user, "tier1"), 1);
//         // assertEq(slots.getTier("tier1").whitelist.numberOfWhitelistedSlotsOrdered, 1);
//     }

//     function testNFTMinting() public {
//         vm.startPrank(admin);
//         slots = new Slots(admin, true);

//         NFT nft = new NFT("MagnaNft", "NFT");

//         slots.createTier(tier);

//         // NFTs are set by the tier (higher tiers can have cooler NFTs)
//         slots.setNFTAddress("tier1", address(nft));

//         vm.deal(user, 1000 ether);
//         slots.startSale("tier1");

//         vm.startPrank(user);

//         slots.order{value: 1 ether}("tier1", "order1");
//         assertEq(slots.getUserSlotCount(user, "tier1"), 1);

//         ISlots.Order memory order = slots.getOrder("order1");
//         assertEq(order.buyer, user);
//         assertEq(order.tierId, "tier1");
//         assertEq(order.amount, 1 ether);
//         assertEq(order.timestamp, block.timestamp);

//         // Check that the nft was minted to the correct user & has correct tokenId
//         assertEq(nft.balanceOf(user), 1);
//         assertEq(nft.ownerOf(0), user);

//     }
// }