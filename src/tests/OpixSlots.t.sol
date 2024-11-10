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

