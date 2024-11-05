pragma solidity ^0.8.13;

import {ERC721} from '@solady/tokens/ERC721.sol';
contract NFT is ERC721 {
    string public nftName;
    string public nftSymbol;

    constructor(string memory _name, string memory _symbol){
        nftName = _name;
        nftSymbol = _symbol;
    }

    function name() public view virtual override returns (string memory) {
        return nftName;
    }

    function symbol() public view virtual override returns (string memory) {
        return nftSymbol;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return 'https://example.com/';
    }

    function mint(address to, uint256 tokenId) public virtual {
        _safeMint(to, tokenId);
    }
}
