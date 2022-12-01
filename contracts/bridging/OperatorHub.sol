// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./HashStore.sol";

contract OperatorHub is Ownable {
  using ECDSA for bytes32;

  bytes constant public ETH_PREFIX = "\x19Ethereum Signed Message:\n32";

  uint8 public requiredOperators;

  mapping(address => bool) public operators;

  mapping(address => string) public operatorLocation;

  address[] public operatorList;

  HashStore public immutable hashStore;

  event OperatorAdded(address operator);

  event OperatorRemoved(address operator);

  event LocationUpdated(address operator, string location);

  constructor(HashStore _hashStore, uint8 _requiredOperators, address[] memory initialOperators) {
    require(_requiredOperators != 0 && initialOperators.length >= _requiredOperators, "invalid operator numbers");

    for (uint i = 0; i < initialOperators.length; i++) {
      addOperator(initialOperators[i]);
    }

    if (address(_hashStore) == address(0)) {
      _hashStore = new HashStore();
    }

    hashStore = _hashStore;

    setRequiredOperators(_requiredOperators);
  }

  function addOperator(address operator) public onlyOwner {
    require(operator != address(0), "invalid operator address");
    require(!operators[operator], "operator address duplicate");

    operators[operator] = true;
    operatorList.push(operator);

    emit OperatorAdded(operator);
  }

  /**
   * @dev Transfers ownership of the HashStore contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferHashStoreOwnership(address newOwner) public onlyOwner {
    hashStore.transferOwnership(newOwner);
  }

  function removeOperator(address operator) public onlyOwner {
    require(!operators[operator], "invalid operator address");
    require(operatorList.length > requiredOperators, "invalid operator numbers");

    delete operators[operator];
    delete operatorLocation[operator];

    emit OperatorRemoved(operator);

    for (uint256 i = 0; i < operatorList.length; i++) {
      if (operatorList[i] == operator) {
        operatorList[i] = operatorList[operatorList.length - 1];
        operatorList.pop();
        return;
      }
    }
  }

  function updateLocation(address operator, string memory location) public onlyOwner {
    require(operators[operator], "invalid operator address");

    operatorLocation[operator] = location;

    emit LocationUpdated(operator, location);
  }

  function setRequiredOperators(uint8 requiredOperators_) public onlyOwner {
    require(requiredOperators_ > 0 && operatorList.length >= requiredOperators_, "invalid operator number");

    requiredOperators = requiredOperators_;
  }

  function isOperator(address operator) public view returns (bool) {
    return (operators[operator] == true);
  }

  function operatorCount() public view returns (uint) {
    return operatorList.length;
  }

  function operatorAddresses() public view returns (address[] memory) {
    return operatorList;
  }

  function checkSignatures(
    bytes32 hash,
    bytes[] memory signatures
  ) public view returns(uint8) {
    uint8 approvals = 0;

    address prevOperator = address(0x0);

    for (uint i = 0; i < signatures.length; ++i) {
      address operator = hash.recover(signatures[i]);

      require(isOperator(operator), "not operator");
      require(prevOperator < operator, "unordered signatures");

      prevOperator = operator;
      approvals ++;
    }

    return approvals;
  }

  function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
  }

  function _chainId() internal view returns (uint256) {
    return block.chainid;
  }

  modifier onlyOperator(address operator) {
    assert(operators[operator] == true);
    _;
  }

  modifier whenTokenAddressIsInvalid(address _tokenContract) {
    require(_tokenContract != address(0x0), "invalid token address");
    _;
  }

  modifier whenRecipientAddressIsInvalid(address _recipient) {
    require(_recipient != address(0x0), "invalid recipient address");
    _;
  }

  modifier whenTransactionHashAddressIsInvalid(bytes32 _transactionHash) {
    require(_transactionHash > 0, "invalid transaction hash");
    _;
  }

  modifier whenChainIsInvalid(uint32 chainId) {
    require(chainId != _chainId(), "invalid chain");
    _;
  }
}
