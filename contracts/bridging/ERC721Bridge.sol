// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./OperatorHub.sol";
import "./ERC721Mintable.sol";


abstract contract ERC721Bridge is OperatorHub {
  event LogERC721Mint(bytes32 transactionHash, address tokenContract, address recipient, uint256 tokenId);

  event LogERC721BatchMint(bytes32 transactionHash, address tokenContract, address recipient, uint256[] tokenIds);

  event LogERC721CrossChainTransfer(uint32 chainId, address tokenContract, address recipient, uint256 tokenId);

  event LogERC721BatchCrossChainTransfer(uint32 chainId, address tokenContract, address recipient, uint256[] tokenIds);

  mapping(uint32 => uint32) public maxERC721BatchSize;

  function setMaxERC721BatchSize(uint32 chainId, uint32 batchSize) public onlyOwner {
    maxERC721BatchSize[chainId] = batchSize;
  }

  function erc721CanMint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 tokenId
  ) public view
  whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) returns (bool) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, tokenId)));

    return !hashStore.hashes(hash);
  }

  function erc721Mint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 tokenId,
    bytes[] memory signatures
  ) external whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, tokenId)));

    hashStore.addHash(hash);

    require(checkSignatures(hash, signatures) >= requiredOperators, "not enough signatures");

    ERC721Mintable(tokenContract).mint(recipient, tokenId);

    emit LogERC721Mint(transactionHash, tokenContract, recipient, tokenId);
  }

  function erc721BatchMint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256[] memory tokenIds,
    bytes[] memory signatures
  ) external whenTokenAddressIsInvalid(tokenContract) whenTransactionHashAddressIsInvalid(transactionHash) whenRecipientAddressIsInvalid(recipient) {
    bytes32 hash = prefixed(keccak256(abi.encodePacked(_chainId(), transactionHash, tokenContract, recipient, tokenIds)));

    hashStore.addHash(hash);

    require(checkSignatures(hash, signatures) >= requiredOperators, "not enough signatures");

    ERC721Mintable(tokenContract).mintBatch(recipient, tokenIds);

    emit LogERC721BatchMint(transactionHash, tokenContract, recipient, tokenIds);
  }

  function erc721CrossChainTransfer(
    uint32 chainId,
    address tokenContract,
    address recipient,
    uint256 tokenId
  ) external whenChainIsInvalid(chainId) whenTokenAddressIsInvalid(tokenContract) whenRecipientAddressIsInvalid(recipient) {
    require(maxERC721BatchSize[chainId] != 0, "exceed batch size");
    require(ERC721Mintable(tokenContract).ownerOf(tokenId) == msg.sender, "not token owner");

    ERC721Mintable(tokenContract).burn(tokenId);

    emit LogERC721CrossChainTransfer(chainId, tokenContract, recipient, tokenId);
  }

  function erc721BatchCrossChainTransfer(
    uint32 chainId,
    address tokenContract,
    address recipient,
    uint256[] memory tokenIds
  ) external whenChainIsInvalid(chainId) whenTokenAddressIsInvalid(tokenContract) whenRecipientAddressIsInvalid(recipient) {
    require(tokenIds.length <= maxERC721BatchSize[chainId], "exceed batch size");

    for (uint i = 0; i < tokenIds.length; ++i) {
      require(ERC721Mintable(tokenContract).ownerOf(tokenIds[i]) == msg.sender, "not token owner");

      ERC721Mintable(tokenContract).burn(tokenIds[i]);
    }

    emit LogERC721BatchCrossChainTransfer(chainId, tokenContract, recipient, tokenIds);
  }
}
