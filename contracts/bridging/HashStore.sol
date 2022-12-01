// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract HashStore is Ownable {
  mapping(bytes32 => bool) public hashes;

  function addHash(bytes32 key) external onlyOwner {
    require(!hashes[key], "already minted");

    hashes[key] = true;
  }
}
