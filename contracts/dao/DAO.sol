// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract DAOInterface {
  // The minimum debate period that a generic proposal can have
  uint constant minProposalDebatePeriod = 2 weeks;
  // The minimum debate period that a split proposal can have
  uint constant quorumHalvingPeriod = 25 weeks;
  // Period after which a proposal is closed
  // (used in the case `executeProposal` fails because it throws)
  uint constant executeProposalPeriod = 10 days;
  // Time for vote freeze. A proposal needs to have majority support before votingDeadline - preSupportTime
  uint constant preSupportTime = 2 days;
  // Denotes the maximum proposal deposit that can be given. It is given as
  // a fraction of total Ether spent plus balance of the DAO
  uint constant maxDepositDivisor = 100;

  //Token contract
  IERC20 token;

  // Proposals to spend the DAO's ether
  Proposal[] public proposals;
  // The quorum needed for each proposal is partially calculated by
  // totalSupply / minQuorumDivisor
  uint public minQuorumDivisor;
  // The unix time of the last time quorum was reached on a proposal
  uint public lastTimeMinQuorumMet;

  // Address of the curator
  address public curator;
  // The whitelist: List of addresses the DAO is allowed to send ether to
  mapping (address => bool) public allowedRecipients;

  // Map of addresses blocked during a vote (not allowed to transfer DAO
  // tokens). The address points to the proposal ID.
  mapping (address => uint) public blocked;

  // Map of addresses and proposal voted on by this address
  mapping (address => uint[]) public votingRegister;

  // The minimum deposit (in wei) required to submit any proposal that is not
  // requesting a new Curator (no deposit is required for splits)
  uint public proposalDeposit;

  // the accumulated sum of all current proposal deposits
  uint sumOfProposalDeposits;

  // A proposal with `newCurator == false` represents a transaction
  // to be issued by this DAO
  // A proposal with `newCurator == true` represents a DAO split
  struct Proposal {
    // The address where the `amount` will go to if the proposal is accepted
    address recipient;
    // The amount to transfer to `recipient` if the proposal is accepted.
    uint amount;
    // A plain text description of the proposal
    string description;
    // A unix timestamp, denoting the end of the voting period
    uint votingDeadline;
    // True if the proposal's votes have yet to be counted, otherwise False
    bool open;
    // True if quorum has been reached, the votes have been counted, and
    // the majority said yes
    bool proposalPassed;
    // A hash to check validity of a proposal
    bytes32 proposalHash;
    // Deposit in wei the creator added when submitting their proposal. It
    // is taken from the msg.value of a newProposal call.
    uint proposalDeposit;
    // True if this proposal is to assign a new Curator
    bool newCurator;
    // true if more tokens are in favour of the proposal than opposed to it at
    // least `preSupportTime` before the voting deadline
    bool preSupport;
    // Number of Tokens in favor of the proposal
    uint yea;
    // Number of Tokens opposed to the proposal
    uint nay;
    // Simple mapping to check if a shareholder has voted for it
    mapping (address => bool) votedYes;
    // Simple mapping to check if a shareholder has voted against it
    mapping (address => bool) votedNo;
    // Address of the shareholder who created the proposal
    address creator;
  }

  /// @notice donate without getting tokens
  receive() external payable virtual;

  /// @notice `msg.sender` creates a proposal to send `_amount` Wei to
  /// `_recipient` with the transaction data `_transactionData`. If
  /// `_newCurator` is true, then this is a proposal that splits the
  /// DAO and sets `_recipient` as the new DAO's Curator.
  /// @param _recipient Address of the recipient of the proposed transaction
  /// @param _amount Amount of wei to be sent with the proposed transaction
  /// @param _description String describing the proposal
  /// @param _transactionData Data of the proposed transaction
  /// @param _debatingPeriod Time used for debating a proposal, at least 2
  /// weeks for a regular proposal, 10 days for new Curator proposal
  /// @param _newCurator Bool defining whether this proposal is about
  /// a new Curator or not
  function newProposal(
    address _recipient,
    uint _amount,
    string memory _description,
    bytes memory _transactionData,
    uint _debatingPeriod,
    bool _newCurator
  ) public payable virtual returns (uint _proposalID);

  /// @notice Check that the proposal with the ID `_proposalID` matches the
  /// transaction which sends `_amount` with data `_transactionData`
  /// to `_recipient`
  /// @param _proposalID The proposal ID
  /// @param _recipient The recipient of the proposed transaction
  /// @param _amount The amount of wei to be sent in the proposed transaction
  /// @param _transactionData The data of the proposed transaction
  function checkProposalCode(
    uint _proposalID,
    address _recipient,
    uint _amount,
    bytes memory _transactionData
  ) public view virtual returns (bool _codeChecksOut);

  /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
  /// @param _proposalID The proposal ID
  /// @param _supportsProposal Yes/No - support of the proposal
  function vote(uint _proposalID, bool _supportsProposal) virtual public;

  /// @notice Checks whether proposal `_proposalID` with transaction data
  /// `_transactionData` has been voted for or rejected, and executes the
  /// transaction in the case it has been voted for.
  /// @param _proposalID The proposal ID
  /// @param _transactionData The data of the proposed transaction
  function executeProposal(
    uint _proposalID,
    bytes memory _transactionData
  ) public virtual returns (bool _success);


  /// @dev can only be called by the DAO itself through a proposal
  /// updates the contract of the DAO by sending all ether and rewardTokens
  /// to the new DAO. The new DAO needs to be approved by the Curator
  /// @param _newContract the address of the new contract
  function newContract(address _newContract) public virtual;


  /// @notice Add a new possible recipient `_recipient` to the whitelist so
  /// that the DAO can send transactions to them (using proposals)
  /// @param _recipient New recipient address
  /// @dev Can only be called by the current Curator
  function changeAllowedRecipients(address _recipient, bool _allowed) external virtual returns (bool _success);


  /// @notice Change the minimum deposit required to submit a proposal
  /// @param _proposalDeposit The new proposal deposit
  /// @dev Can only be called by this DAO (through proposals with the
  /// recipient being this DAO itself)
  function changeProposalDeposit(uint _proposalDeposit) external virtual;

  /// @notice Doubles the 'minQuorumDivisor' in the case quorum has not been
  /// achieved in 52 weeks
  function halveMinQuorum() public virtual returns (bool _success);

  function numberOfProposals() public virtual view returns (uint _numberOfProposals);

  /// @param _account The address of the account which is checked.
  function getOrModifyBlocked(address _account) internal virtual returns (bool);

  /// @notice If the caller is blocked by a proposal whose voting deadline
  /// has exprired then unblock him.
  function unblockMe() public virtual returns (bool);

  event ProposalAdded(
    uint indexed proposalID,
    address recipient,
    uint amount,
    string description
  );
  event Voted(
    uint indexed proposalID, 
    bool position, 
    address indexed voter
  );
  event ProposalTallied(
    uint indexed proposalID, 
    bool result, 
    uint quorum
  );
  event AllowedRecipientChanged(
    address indexed _recipient, 
    bool _allowed
  );
}

// The DAO contract
abstract contract DAO is DAOInterface{
  // Modifier that allows only shareholders to vote and create new proposals
  modifier onlyTokenholders {
    if (token.balanceOf(msg.sender) == 0) revert();
    _;
  }

  constructor(
    address _curator,
    uint _proposalDeposit,
    IERC20 _token
  ) {
    token = _token;
    curator = _curator;
    proposalDeposit = _proposalDeposit;
    lastTimeMinQuorumMet = block.timestamp;
    minQuorumDivisor = 7; // sets the minimal quorum to 14.3%

    allowedRecipients[address(this)] = true;
    allowedRecipients[curator] = true;
  }

  receive() external override payable {}

  function newProposal(
    address _recipient,
    uint _amount,
    string memory _description,
    bytes memory _transactionData,
    uint64 _debatingPeriod
  ) public onlyTokenholders payable returns (uint _proposalID) {
    if (!allowedRecipients[_recipient]
        || _debatingPeriod < minProposalDebatePeriod
        || _debatingPeriod > 8 weeks
        || msg.value < proposalDeposit
        || msg.sender == address(this) //to prevent a 51% attacker to convert the ether into deposit
      )
        revert();

    // to prevent curator from halving quorum before first proposal
    if (proposals.length == 1) // initial length is 1 (see constructor)
      lastTimeMinQuorumMet = block.timestamp;

    Proposal storage p = proposals[_proposalID];
    p.recipient = _recipient;
    p.amount = _amount;
    p.description = _description;
    p.votingDeadline = block.timestamp + _debatingPeriod;
    p.open = true;
    //p.proposalPassed = False; // that's default
    p.creator = msg.sender;
    p.proposalDeposit = msg.value;

    sumOfProposalDeposits += msg.value;

    emit ProposalAdded(
      _proposalID,
      _recipient,
      _amount,
      _description
    );
  }

  function checkProposalCode(
    uint _proposalID,
    address _recipient,
    uint _amount,
    bytes memory _transactionData
  ) public view override returns (bool _codeChecksOut) {
    Proposal storage p = proposals[_proposalID];
    return p.proposalHash == keccak256(abi.encodePacked(_recipient, _amount, _transactionData));
  }

  function vote(uint _proposalID, bool _supportsProposal) public override {
    Proposal storage p = proposals[_proposalID];

    unVote(_proposalID);

    if (_supportsProposal) {
      p.yea += token.balanceOf(msg.sender);
      p.votedYes[msg.sender] = true;
    } else {
      p.nay += token.balanceOf(msg.sender);
      p.votedNo[msg.sender] = true;
    }

    if (blocked[msg.sender] == 0) {
      blocked[msg.sender] = _proposalID;
    } else if (p.votingDeadline > proposals[blocked[msg.sender]].votingDeadline) {
      // this proposal's voting deadline is further into the future than
      // the proposal that blocks the sender so make it the blocker
      blocked[msg.sender] = _proposalID;
    }

    votingRegister[msg.sender].push(_proposalID);
    emit Voted(_proposalID, _supportsProposal, msg.sender);
  }

  function unVote(uint _proposalID) public {
    Proposal storage p = proposals[_proposalID];

    if (block.timestamp >= p.votingDeadline) {
      revert();
    }

    if (p.votedYes[msg.sender]) {
      p.yea -= token.balanceOf(msg.sender);
      p.votedYes[msg.sender] = false;
    }

    if (p.votedNo[msg.sender]) {
      p.nay -= token.balanceOf(msg.sender);
      p.votedNo[msg.sender] = false;
    }
  }

  function unVoteAll() public {
    // DANGEROUS loop with dynamic length - needs improvement
    for (uint i = 0; i < votingRegister[msg.sender].length; i++) {
      Proposal storage p = proposals[votingRegister[msg.sender][i]];
      if (block.timestamp < p.votingDeadline)
        unVote(i);
    }

    blocked[msg.sender] = 0;
  }
  
  function verifyPreSupport(uint _proposalID) public {
    Proposal storage p = proposals[_proposalID];
    if (block.timestamp < p.votingDeadline - preSupportTime) {
      if (p.yea > p.nay) {
        p.preSupport = true;
      }
      else
        p.preSupport = false;
    }
  }

  function executeProposal(
    uint _proposalID,
    bytes memory _transactionData
  ) public override returns (bool _success) {
    Proposal storage p = proposals[_proposalID];

    // If we are over deadline and waiting period, assert proposal is closed
    if (p.open && block.timestamp > p.votingDeadline + executeProposalPeriod) {
      closeProposal(_proposalID);
      return true;
    }

    // Check if the proposal can be executed
    if (block.timestamp < p.votingDeadline  // has the voting deadline arrived?
      // Have the votes been counted?
      || !p.open
      || p.proposalPassed // anyone trying to call us recursively?
      // Does the transaction code match the proposal?
      || p.proposalHash != keccak256(abi.encodePacked(p.recipient, p.amount, _transactionData))
    )
      revert();

    // If the curator removed the recipient from the whitelist, close the proposal
    // in order to free the deposit and allow unblocking of voters
    if (!allowedRecipients[p.recipient]) {
      closeProposal(_proposalID);
      // the return value is not checked to prevent a malicious creator
      // from delaying the closing of the proposal
      return true;
    }

    bool proposalCheck = true;

    if (p.amount > actualBalance() || p.preSupport == false)
      proposalCheck = false;

    uint quorum = p.yea;

    // require max quorum for calling newContract()
    if (_transactionData.length >= 4 && _transactionData[0] == 0x68
      && _transactionData[1] == 0x37 && _transactionData[2] == 0xff
      && _transactionData[3] == 0x1e
      && quorum < minQuorum(actualBalance())
    )
      proposalCheck = false;

    if (quorum >= minQuorum(p.amount)) {
      lastTimeMinQuorumMet = block.timestamp;
      // set the minQuorum to 14.3% again, in the case it has been reached
      if (quorum > token.totalSupply() / 7)
        minQuorumDivisor = 7;
    }

    // Execute result
    if (quorum >= minQuorum(p.amount) && p.yea > p.nay && proposalCheck) {
      // we are setting this here before the CALL() value transfer to
      // assure that in the case of a malicious recipient contract trying
      // to call executeProposal() recursively money can't be transferred
      // multiple times out of the DAO
      p.proposalPassed = true;

      // this call is as generic as any transaction. It sends all gas and
      // can do everything a transaction can do. It can be used to reenter
      // the DAO. The `p.proposalPassed` variable prevents the call from 
      // reaching this line again
      _success = true;
    }

    closeProposal(_proposalID);

    // Initiate event
    emit ProposalTallied(_proposalID, _success, quorum);
  }


  function closeProposal(uint _proposalID) internal {
    Proposal storage p = proposals[_proposalID];
    if (p.open)
      sumOfProposalDeposits -= p.proposalDeposit;
    p.open = false;
  }


  function newContract(address _newContract) public view override {
    if (msg.sender != address(this) || !allowedRecipients[_newContract]) return;
  }

  function changeProposalDeposit(uint _proposalDeposit) external override {
    proposalDeposit = _proposalDeposit;
  }


  function changeAllowedRecipients(address _recipient, bool _allowed) external override returns (bool _success) {
    if (msg.sender != curator)
      revert();
    allowedRecipients[_recipient] = _allowed;
    emit AllowedRecipientChanged(_recipient, _allowed);
    return true;
  }

  function minQuorum(uint _value) internal view returns (uint _minQuorum) {
    // minimum of 14.3% and maximum of 47.6%
    return token.totalSupply() / minQuorumDivisor;
  }


  function halveMinQuorum() public override returns (bool _success) {
    // this can only be called after `quorumHalvingPeriod` has passed or at anytime after
    // fueling by the curator with a delay of at least `minProposalDebatePeriod`
    // between the calls
    if ((lastTimeMinQuorumMet < (block.timestamp - quorumHalvingPeriod) || msg.sender == curator)
      && lastTimeMinQuorumMet < (block.timestamp - minProposalDebatePeriod)
      && proposals.length > 1) {
      lastTimeMinQuorumMet = block.timestamp;
      minQuorumDivisor *= 2;
      return true;
    } else {
      return false;
    }
  }

  function numberOfProposals() public view override returns (uint _numberOfProposals) {
    // Don't count index 0. It's used by getOrModifyBlocked() and exists from start
    return proposals.length - 1;
  }

  function getOrModifyBlocked(address _account) internal override returns (bool) {
    if (blocked[_account] == 0)
      return false;
    Proposal storage p = proposals[blocked[_account]];
    if (!p.open) {
      blocked[_account] = 0;
      return false;
    } else {
      return true;
    }
  }

  function unblockMe() public override returns (bool) {
    return getOrModifyBlocked(msg.sender);
  }

  function actualBalance() public view returns (uint _actualBalance) {
    return address(this).balance - sumOfProposalDeposits;
  }
}
