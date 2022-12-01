// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./OperatorHub.sol";
import "./ERC20Mintable.sol";

abstract contract ERC20Bridge is OperatorHub {
  event LogERC20Mint(bytes32 transactionHash, address tokenContract, address recipient, uint256 amount);

  event LogERC20CrossChainTransfer(uint32 chainId, address tokenContract, address recipient, uint256 amount);

  function erc20CanMint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 amount
  ) public view
  whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) returns (bool) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, amount)));

    return !hashStore.hashes(hash);
  }

  function erc20Mint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 amount,
    bytes[] memory signatures
  ) external whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, amount)));

    hashStore.addHash(hash);

    require(checkSignatures(hash, signatures) >= requiredOperators, "not enough signatures");

    ERC20Mintable(tokenContract).mint(recipient, amount);

    emit LogERC20Mint(transactionHash, tokenContract, recipient, amount);
  }

  function erc20CrossChainTransfer(
    uint32 chainId,
    address tokenContract,
    address recipient,
    uint256 amount
  ) external whenChainIsInvalid(chainId) whenTokenAddressIsInvalid(tokenContract) whenRecipientAddressIsInvalid(recipient) {
    require(ERC20Mintable(tokenContract).balanceOf(msg.sender) >= amount, "not enough balance");

    ERC20Mintable(tokenContract).burnFrom(msg.sender, amount);

    emit LogERC20CrossChainTransfer(chainId, tokenContract, recipient, amount);
  }
}
