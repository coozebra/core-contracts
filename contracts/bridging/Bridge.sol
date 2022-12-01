// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC721Bridge.sol";
import "./ERC20Bridge.sol";
import "./ERC1155Bridge.sol";
import "./OperatorHub.sol";


contract Bridge is ERC721Bridge, ERC20Bridge, ERC1155Bridge {
  constructor(HashStore _hashStore, uint8 requiredOperators_, address[] memory initialOperators)
    OperatorHub(_hashStore, requiredOperators_, initialOperators) {
  }
}
