// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KOK is ERC20Burnable, Ownable {
  uint256 public constant CAP = 1e8 * 1 ether;

  event LogMinted(address indexed account, uint256 amount);
  event LogBurned(address indexed account, uint256 amount);

  constructor(
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) {
    super._mint(msg.sender, CAP);
    emit LogMinted(msg.sender, CAP);
  }
}
