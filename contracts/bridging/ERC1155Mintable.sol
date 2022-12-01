// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

abstract contract ERC1155Mintable is ERC1155Burnable, Ownable {
  constructor(string memory _url)
    ERC1155(_url) {
  }

  function mint(address to, uint256 tokenId, uint256 amount) onlyOwner external {
    _mint(to, tokenId, amount, "");
  }

  function mintBatch(
    address to,
    uint256[] memory tokenIds,
    uint256[] memory amounts
  ) onlyOwner external {
    _mintBatch(to, tokenIds, amounts, "");
  }
}
