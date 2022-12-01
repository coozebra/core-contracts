// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakingRewardToken.sol";

/*
 * @notice This contract follows MasterChef algorithm for sharing staking rewards among stakers
 */
contract Staking is Ownable {
  IERC20 private stakeToken;
  StakingRewardToken private rewardToken;

  uint256 private rewardTokensPerBlock;
  uint256 private amountOfTokensStaked;

  uint256 private accRewardPerShare;
  uint256 private lastAccRewardPerShareBlock;
  uint256 private constant REWARDS_PRECISION = 1e12;

  struct Staker {
    uint256 amount;
    uint256 rewardDebt;
    uint256 pendingRewards;
  }

  mapping(address => Staker) public stakers;

  event Withdrawal(
    address indexed staker,
    uint256 amount,
    uint256 indexed withdrawalBlock
  );
  event ClaimRewards(
    address indexed staker,
    uint256 rewardHarvested,
    uint256 indexed rewardBlock
  );
  event Deposit(
    address indexed depositor,
    uint256 amount,
    uint256 indexed depositBlock
  );

  constructor(
    IERC20 _stakeToken,
    address _rewardToken,
    uint256 _rewardTokensPerBlock
  ) {
    stakeToken = _stakeToken;
    rewardToken = StakingRewardToken(_rewardToken);
    rewardTokensPerBlock = _rewardTokensPerBlock;
  }

  /**
    * @notice Allows anyone to deposit into the contract
    * @param _amount The amount to deposit to the contract
    */
  function deposit(uint256 _amount) external {
    require(_amount > 0, "amount cannot be zero");
    Staker storage staker = stakers[msg.sender];
    //1. Update accRewardPerShare
    updateAccRewardPerShare();
    //2. Update user rewards
    uint256 userRewards = ((staker.amount * accRewardPerShare) /
      REWARDS_PRECISION) - staker.rewardDebt;
    staker.pendingRewards += userRewards;
    //3. Update user balance
    staker.amount += _amount;
    //4. Update rewardDebt
    staker.rewardDebt =
      (staker.amount * accRewardPerShare) /
      REWARDS_PRECISION;
    amountOfTokensStaked += _amount;
    stakeToken.transferFrom(msg.sender, address(this), _amount);
    emit Deposit(msg.sender, _amount, block.number);
  }

  /**
    * @notice Allows anyone to withdraw their stake from the contract and harvest their rewards alongside
    * @param _amount The amount to withdraw from the contract
    */
  function withdraw(uint256 _amount) external {
    Staker storage staker = stakers[msg.sender];
    require(staker.amount > 0, "balance is zero");
    require(staker.amount >= _amount, "amount > balance");
    claimRewards();
    staker.amount -= _amount;
    amountOfTokensStaked -= _amount;
    stakeToken.transfer(msg.sender, _amount);
    emit Withdrawal(msg.sender, _amount, block.number);
  }

  /**
    * @notice Allows anyone to harvest their staking rewards
    */
  function claimRewards() public {
    Staker storage staker = stakers[msg.sender];
    require(staker.amount > 0, "balance is zero");
    //1. Update accRewardPerShare
    updateAccRewardPerShare();
    //2. Calculate user rewards to harvest
    uint256 rewardsToHarvest = ((staker.amount * accRewardPerShare) /
      REWARDS_PRECISION) - staker.rewardDebt;
    //3. Update rewardDebt
    staker.rewardDebt =
      (staker.amount * accRewardPerShare) /
      REWARDS_PRECISION;

    rewardsToHarvest += staker.pendingRewards;

    if (rewardsToHarvest <= 0) {
      return;
    }

    staker.pendingRewards = 0;

    rewardToken.mint(msg.sender, rewardsToHarvest);
    emit ClaimRewards(msg.sender, rewardsToHarvest, block.number);
  }

  /**
    * @notice Allows anyone to check their rewards
    * @param _staker The staker's address
    * @return staker's unharvested rewards
    */
  function checkRewards(address _staker) external view returns (uint256) {
    Staker storage staker = stakers[_staker];
    if (staker.amount <= 0) {
      return 0;
    }
    //1. Calculate accRewardPerShareTemp
    uint256 accRewardPerShareTemp = accRewardPerShare;
    if (amountOfTokensStaked > 0) {
      uint256 blocksDiff = block.number - lastAccRewardPerShareBlock;
      uint256 rewardsPerShare = blocksDiff * rewardTokensPerBlock;
      accRewardPerShareTemp =
        accRewardPerShareTemp +
        ((rewardsPerShare * REWARDS_PRECISION) / amountOfTokensStaked);
    } else {
      return 0;
    }
    //2. Calculate user rewards to harvest
    uint256 rewardsToHarvest = ((staker.amount * accRewardPerShareTemp) /
      REWARDS_PRECISION) - staker.rewardDebt;

    rewardsToHarvest += staker.pendingRewards;

    if (rewardsToHarvest <= 0) {
      return 0;
    }

    return rewardsToHarvest;
  }

  /**
    * @notice Used to update accRewardPerShare
    */
  function updateAccRewardPerShare() private {
    if (amountOfTokensStaked > 0) {
      uint256 blocksDiff = block.number - lastAccRewardPerShareBlock;
      uint256 rewardsPerShare = blocksDiff * rewardTokensPerBlock;
      accRewardPerShare =
        accRewardPerShare +
        ((rewardsPerShare * REWARDS_PRECISION) / amountOfTokensStaked);
    }
    lastAccRewardPerShareBlock = block.number;
  }

  /**
    * @notice Used to get the summary of data in the contract
    * @return token rewards per block
    * @return amount of tokens staked
    * @return accumulated reward per share
    * @return last reward block
    */
  function getSummary()
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return (
      rewardTokensPerBlock,
      amountOfTokensStaked,
      accRewardPerShare,
      lastAccRewardPerShareBlock
    );
  }
}
