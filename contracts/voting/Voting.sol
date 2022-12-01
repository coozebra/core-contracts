// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * Voting contract that offers 2 options YES / NO
 */
contract Voting is Ownable2Step, AccessControl {
  using Counters for Counters.Counter;

  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
  Counters.Counter public pollIds;

  /* EVENTS  */
  event VoteCasted(address indexed voter, uint256 pollID, bool vote, uint256 weight);
	event PollCreated(address indexed creator, uint256 pollID, string description, uint256 votingTimeInDays);
	event PollEnded(uint256 pollID, PollStatus status);

  /* Determine the current state of a poll */
	enum PollStatus {
    IN_PROGRESS,
    PASSED,
    REJECTED
  }

  /* POLL */
  struct Poll {
		uint256 yesVotes;
		uint256 noVotes;
		uint256 startTime;
		uint256 endTime;
    uint256 minimumStakeTimeInDays;
		string description;
		PollStatus status;
		address creator;
		address[] voters;
	}

  /* VOTER */
  struct Voter {
    bool voted;
    bool vote;
    uint256 weight;
  }

  // poll id => poll info
  mapping(uint256 => Poll) private _polls;
  // poll id => voter address => voter info
  mapping(uint256 => mapping(address => Voter)) private _voters;

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(OPERATOR_ROLE, _msgSender());
  }

  /***********************|
  |          Role         |
  |______________________*/

  /**
    * @dev Restricted to members of the admin role.
    */
  modifier onlyAdmin() {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "CALLER_NO_ADMIN_ROLE");
    _;
  }

  /**
    * @dev Restricted to members of the operator role.
    */
  modifier onlyOperator() {
    require(hasRole(OPERATOR_ROLE, _msgSender()), "CALLER_NO_OPERATOR_ROLE");
    _;
  }

  /**
    * @dev Add an account to the operator role.
    * @param account address
    */
  function addOperator(address account)
    public
    onlyAdmin
  {
    require(!hasRole(OPERATOR_ROLE, account), "ALREADY_OERATOR_ROLE");
    grantRole(OPERATOR_ROLE, account);
  }

  /**
    * @dev Remove an account from the operator role.
    * @param account address
    */
  function removeOperator(address account)
    public
    onlyAdmin
  {
    require(hasRole(OPERATOR_ROLE, account), "NO_OPERATOR_ROLE");
    revokeRole(OPERATOR_ROLE, account);
  }

  /**
    * @dev Check if an account is operator.
    * @param account address
    */
  function checkOperator(address account)
    public
    view
    returns (bool)
  {
    return hasRole(OPERATOR_ROLE, account);
  }    

  /***********************|
  |          Poll         |
  |______________________*/

  /*
  * Modifier that checks for a valid poll ID.
  */
  modifier validPoll(uint256 _pollId) {
    require(_pollId > 0 && _pollId <= pollIds.current(), "POLL_ID_INVALID");
    _;
  }

  /* GETTERS */

  /**
    * @dev Return poll general info.
    * Except for voting result.
    *
    * @param _pollId poll id
    * @return description string, poll startTime, endTime, minimumStakeTimeInDays, status, creator address, voter address array
    */
  function getPollInfo(uint256 _pollId)
    public
    view
    validPoll(_pollId)
    returns (string memory, uint256, uint256, uint256, PollStatus, address, address[] memory)
  {
    Poll memory poll = _polls[_pollId];
    return (poll.description, poll.startTime, poll.endTime, poll.minimumStakeTimeInDays, poll.status, poll.creator, poll.voters);
  }

  /**
    * @dev Return poll voting info.
    * If poll is not ended, operators can call.
    * After ended, any user can call.
    * @param _pollId poll id
    * @return poll YES Votes, NO Votes, poll status
    */
  function getPollVotingInfo(uint256 _pollId)
    public
    view
    validPoll(_pollId)
    returns (uint256, uint256, PollStatus)
  {
    Poll memory poll = _polls[_pollId];
    require(poll.status == PollStatus.IN_PROGRESS || checkOperator(_msgSender()), "POLL_NOT_ENDED__CALLER_NO_OPERATOR");
    return (poll.yesVotes, poll.noVotes, poll.status);
  }

  /**
    * @dev Return `_voter` info for `_pollId` poll.
    * If poll is not ended, operators can call.
    * After ended, any user can call.
    *
    * @param _pollId poll id
    * @param _voter address of voter
    * @return voter voted status (true - vote casted, no - no vote cast), voter's vote option (true - YES, false - NO), voter's voting weight
    */
  function getVoterInfo(
    uint256 _pollId,
    address _voter
  )
    public
    view
    validPoll(_pollId)
    returns (bool, bool, uint256)
  {
    require(_polls[_pollId].status == PollStatus.IN_PROGRESS || checkOperator(_msgSender()), "POLL_NOT_ENDED__CALLER_NO_OPERATOR");
    return (_voters[_pollId][_voter].voted, _voters[_pollId][_voter].vote, _voters[_pollId][_voter].weight);
  }

  /**
    * @dev Create a new poll.
    *
    * @param _description poll description.
    * @param _durationTimeInDays poll duration time.
    * @param _minimumStakeTimeInDays minimum stake duration time for poll voters.
  */
  function createPoll(
    string memory _description,
    uint256 _durationTimeInDays,
    uint256 _minimumStakeTimeInDays
  )
    external
    onlyOperator
    returns (uint256)
  {
    require(bytes(_description).length > 0, "DESCRIPTION_INVALID");
    require(_durationTimeInDays > 0, "DURATION_TIME_INVALID");

    pollIds.increment();
    Poll storage poll = _polls[pollIds.current()];
    poll.startTime = block.timestamp;
    poll.endTime = block.timestamp + _durationTimeInDays * (1 days);
    poll.minimumStakeTimeInDays = _minimumStakeTimeInDays;
    poll.description = _description;
    poll.creator = _msgSender();

    emit PollCreated(_msgSender(), pollIds.current(), _description, _durationTimeInDays);
    return pollIds.current();
  }

  /**
  * @dev End `_pollId` poll.
    *
    * @param _pollId poll id.
  */
  function endPoll(uint256 _pollId)
    external
    onlyOperator
    validPoll(_pollId)
  {
    Poll storage poll = _polls[_pollId];
    require(block.timestamp >= poll.endTime, "VOTING_PERIOD_NOT_EXPIRED");
    require(poll.status == PollStatus.IN_PROGRESS, "POLL_ALREADY_ENDED");
    if (poll.yesVotes > poll.noVotes) {
      poll.status = PollStatus.PASSED;
    } else {
      poll.status = PollStatus.REJECTED;
    }

    emit PollEnded(_pollId, poll.status);
  }

  /**
  * @dev Check if `_account` already voted for `_pollId`.
    *
    * @param _pollId poll id.
    * @param _account user.
  */
  function checkIfVoted(
    uint256 _pollId,
    address _account
  )
    public
    view
    validPoll(_pollId)
    returns (bool)
  {
    return _voters[_pollId][_account].voted;
  }

  /***********************|
  |          Vote         |
  |______________________*/

  /**
  * @dev User vote `_vote` for `_pollId`.
    *
    * @param _pollId poll id.
    * @param _vote bool.
  */
  function castVote(
    uint256 _pollId,
    bool _vote
  )
    external
    validPoll(_pollId)
  {
    Poll storage poll = _polls[_pollId];
    require(poll.status == PollStatus.IN_PROGRESS, "POLL_ALREADY_ENDED");
    require(block.timestamp < poll.endTime, "VOTING_PERIOD_EXPIRED");
    require(!checkIfVoted(_pollId, _msgSender()), "USER_ALREADY_VOTED");

    uint256 w = getWeight(_pollId, _msgSender());
    if (_vote) {
      poll.yesVotes = poll.yesVotes + w;
    } else {
      poll.noVotes = poll.noVotes + w;
    }

    Voter storage voter = _voters[_pollId][_msgSender()];
    voter.voted = true;
    voter.vote = _vote;
    voter.weight = w;

    emit VoteCasted(_msgSender(), _pollId, _vote, w);
  }

  /*****************************|
  |          StakeToken         |
  |____________________________*/

  /**
  * @dev Get `_account` weight for `_pollId`.
    *
    * @param _pollId poll id.
    * @param _account.
  */
  function getWeight(
    uint256 _pollId,
    address _account
  )
    public
    view
    validPoll(_pollId)
    returns (uint256)
  {
    require(_account != address(0), "ACCOUNT_INVALID");
    uint256 w = 0; // total weight
    Poll memory poll = _polls[_pollId];
    require(poll.status == PollStatus.IN_PROGRESS, "POLL_ALREADY_ENDED");

    w = w + 1;
    return w;
  }
}
