// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DEXErrors} from "../common/DEXErrors.sol";
import {ILiquidityMining} from "../interfaces/ILiquidityMining.sol";

/**
 * @title LiquidityMining
 * @notice Upgradeable LP staking rewards distributor.
 * @dev Rewards stream linearly at `rewardPerSecond`.
 * @dev Uses OZ OwnableUpgradeable, PausableUpgradeable, and ReentrancyGuardUpgradeable.
 *
 * @custom:version 1.0.0
 */
contract LiquidityMining is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ILiquidityMining,
    DEXErrors
{
    using SafeERC20 for IERC20;

    /* ========== CONSTANTS ========== */

    /// @notice Precision constant for accumulated reward-per-share math.
    uint256 private constant ACC_PRECISION = 1e12;

    /* ========== STATE VARIABLES ========== */

    /// @notice LP token address staked by users.
    IERC20 public lpToken;

    /// @notice Reward token distributed to stakers.
    IERC20 public rewardToken;

    /// @notice Reward emission speed in tokens per second.
    uint256 public rewardPerSecond;

    /// @notice Accumulated rewards per LP share.
    uint256 public accRewardPerShare;

    /// @notice Last accounting timestamp.
    uint256 public lastRewardTime;

    /// @notice Total staked LP token amount.
    uint256 public totalStaked;

    /**
     * @notice User position data.
     */
    struct UserInfo {
        /// @notice Staked LP amount.
        uint256 amount;
        /// @notice Reward debt offset.
        uint256 rewardDebt;
    }

    /// @notice User staking positions.
    mapping(address user => UserInfo) public users;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes liquidity-mining contract.
     * @param owner_ Owner/admin address.
     * @param lpToken_ LP token address.
     * @param rewardToken_ Reward token address.
     * @param rewardPerSecond_ Initial emissions-per-second.
     */
    function initialize(address owner_, address lpToken_, address rewardToken_, uint256 rewardPerSecond_)
        external
        initializer
    {
        __Ownable_init(owner_);
        __Pausable_init();
        __ReentrancyGuard_init();

        if (owner_ == address(0) || lpToken_ == address(0) || rewardToken_ == address(0)) revert InvalidAddress();

        lpToken = IERC20(lpToken_);
        rewardToken = IERC20(rewardToken_);
        rewardPerSecond = rewardPerSecond_;
        lastRewardTime = block.timestamp;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Updates reward emission speed.
     */
    function setRewardPerSecond(uint256 value) external onlyOwner whenNotPaused {
        _updatePool();
        rewardPerSecond = value;
        emit EmissionUpdated(value);
    }

    /**
     * @notice Stakes LP tokens and harvests pending rewards.
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        _updatePool();

        UserInfo storage user = users[msg.sender];
        _harvest(user, msg.sender);

        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        user.amount += amount;
        totalStaked += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Withdraws staked LP tokens and harvests rewards.
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        _updatePool();

        UserInfo storage user = users[msg.sender];
        if (user.amount < amount) revert InsufficientStake();
        _harvest(user, msg.sender);

        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;
        lpToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Claims pending rewards only.
     */
    function claim() external nonReentrant whenNotPaused {
        _updatePool();
        UserInfo storage user = users[msg.sender];
        _harvest(user, msg.sender);
        user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;
    }

    /**
     * @notice Returns pending rewards for account.
     */
    function pendingRewards(address account) external view returns (uint256 pending) {
        UserInfo memory user = users[account];
        uint256 _acc = accRewardPerShare;

        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            uint256 reward = (block.timestamp - lastRewardTime) * rewardPerSecond;
            _acc += (reward * ACC_PRECISION) / totalStaked;
        }

        pending = ((user.amount * _acc) / ACC_PRECISION) - user.rewardDebt;
    }

    /**
     * @notice Pauses staking/claiming operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses staking/claiming operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _updatePool() internal {
        if (block.timestamp <= lastRewardTime) return;
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 reward = (block.timestamp - lastRewardTime) * rewardPerSecond;
        accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    function _harvest(UserInfo storage user, address recipient) internal {
        uint256 accumulated = (user.amount * accRewardPerShare) / ACC_PRECISION;
        uint256 pending = accumulated - user.rewardDebt;
        if (pending > 0) {
            rewardToken.safeTransfer(recipient, pending);
            emit RewardClaimed(recipient, pending);
        }
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
