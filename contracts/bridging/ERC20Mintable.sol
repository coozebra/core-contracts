// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

abstract contract ERC20Mintable is ERC20Burnable, Ownable {
  constructor(string memory _name, string memory _symbol)
    ERC20(_name, _symbol) {
  }

  function mint(address to, uint256 amount) onlyOwner external {
    _mint(to, amount);
  }

  function mintBatch(
    address to,
    uint256[] memory values
  ) onlyOwner external {
    for (uint256 i = 0; i < values.length; ++i) {
      _mint(to, values[i]);
    }
  }
}
