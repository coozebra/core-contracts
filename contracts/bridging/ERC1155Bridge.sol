// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./OperatorHub.sol";
import "./ERC1155Mintable.sol";


abstract contract ERC1155Bridge is OperatorHub {
  event LogERC1155Mint(bytes32 transactionHash, address tokenContract, address recipient, uint256 tokenId, uint256 amount);

  event LogERC1155BatchMint(bytes32 transactionHash, address tokenContract, address recipient, uint256[] tokenIds, uint256[] amounts);

  event LogERC1155CrossChainTransfer(uint32 chainId, address tokenContract, address recipient, uint256 tokenId, uint256 amount);

  event LogERC1155BatchCrossChainTransfer(uint32 chainId, address tokenContract, address recipient, uint256[] tokenIds, uint256[] amounts);

  mapping(uint32 => uint32) public maxERC1155BatchSize;

  function setMaxERC1155BatchSize(uint32 chainId, uint32 batchSize) public onlyOwner {
    maxERC1155BatchSize[chainId] = batchSize;
  }

  function erc1155CanMint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 tokenId,
    uint256 amount
  ) public view
  whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) returns (bool) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, tokenId, amount)));

    return !hashStore.hashes(hash);
  }

  function erc1155Mint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 tokenId,
    uint256 amount,
    bytes[] memory signatures
  ) external whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, tokenId, amount)));

    hashStore.addHash(hash);

    require(checkSignatures(hash, signatures) >= requiredOperators, "not enough signatures");

    ERC1155Mintable(tokenContract).mint(recipient, tokenId, amount);

    emit LogERC1155Mint(transactionHash, tokenContract, recipient, tokenId, amount);
  }

  function erc1155BatchMint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256[] memory tokenIds,
    uint256[] memory amounts,
    bytes[] memory signatures
  ) external whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, tokenIds, amounts)));

    hashStore.addHash(hash);

    require(checkSignatures(hash, signatures) >= requiredOperators, "not enough signatures");

    ERC1155Mintable(tokenContract).mintBatch(recipient, tokenIds, amounts);

    emit LogERC1155BatchMint(transactionHash, tokenContract, recipient, tokenIds, amounts);
  }

  function erc1155CrossChainTransfer(
    uint32 chainId,
    address tokenContract,
    address recipient,
    uint256 tokenId,
    uint256 amount
  ) external whenChainIsInvalid(chainId) whenTokenAddressIsInvalid(tokenContract) whenRecipientAddressIsInvalid(recipient) {
    require(maxERC1155BatchSize[chainId] > 0, "exceed batch size");
    require(ERC1155Mintable(tokenContract).balanceOf(msg.sender, tokenId) >= amount, "not token owner");

    ERC1155Mintable(tokenContract).burn(msg.sender, tokenId, amount);

    emit LogERC1155CrossChainTransfer(chainId, tokenContract, recipient, tokenId, amount);
  }

  function erc1155BatchCrossChainTransfer(
    uint32 chainId,
    address tokenContract,
    address recipient,
    uint256[] memory tokenIds,
    uint256[] memory amounts
  ) external whenChainIsInvalid(chainId) whenTokenAddressIsInvalid(tokenContract) whenRecipientAddressIsInvalid(recipient) {
    require(tokenIds.length <= maxERC1155BatchSize[chainId], "exceed batch size");

    for (uint i = 0; i < tokenIds.length; ++i) {
      require(ERC1155Mintable(tokenContract).balanceOf(msg.sender, tokenIds[i]) >= amounts[i], "not token owner");
    }

    ERC1155Mintable(tokenContract).burnBatch(msg.sender, tokenIds, amounts);

    emit LogERC1155BatchCrossChainTransfer(chainId, tokenContract, recipient, tokenIds, amounts);
  }
}
