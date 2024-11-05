pragma solidity =0.8.24;

import '@openzeppelin/token/ERC20/ERC20.sol';
import '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';
import { EIP712 } from '@openzeppelin/utils/cryptography/EIP712.sol';

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) { }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

contract TokenWithVotes is Token, ERC20Votes {
    constructor(string memory _name, string memory _symbol) Token(_name, _symbol) EIP712(_name, '1') { }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20Votes, ERC20) {
        ERC20Votes._update(from, to, value);
    }
}
