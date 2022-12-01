// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

abstract contract ERC721Mintable is ERC721Burnable, Ownable {
  constructor(string memory _name, string memory _symbol)
    ERC721(_name, _symbol) {
  }

  function mint(address to, uint256 tokenId) onlyOwner external {
    _mint(to, tokenId);
  }

  function mintBatch(
    address to,
    uint256[] memory tokenIds
  ) onlyOwner external {
    for (uint256 i = 0; i < tokenIds.length; ++i) {
      _mint(to, tokenIds[i]);
    }
  }
}
