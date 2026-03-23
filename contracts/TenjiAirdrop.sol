 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TenjiAirdrop V3
 * @notice Advanced airdrop contract with anti-bot protections and single-claim enforcement.
 * @dev Designed for fair token distribution with minimal attack surface and predictable gas behavior.
 * @custom:author @Tenyokj | https://tenyokj.vercel.app
 */
contract TenjiAirdrop is Ownable {
    using SafeERC20 for IERC20;

    // ===================== ERRORS =====================

    /// @notice User has already claimed tokens
    error AlreadyClaimed();

    /// @notice Airdrop allocation is fully claimed
    error AirdropFinished();

    /// @notice Contract does not have enough tokens
    error NoTokensLeft();

    /// @notice Caller is not an externally owned account (EOA)
    error NotEOA();

    /// @notice Cooldown period not passed
    error CooldownActive();

    // ===================== STATE =====================

    /// @notice ERC20 token being distributed
    IERC20 public immutable token;

    /// @notice Amount of tokens per user claim
    uint256 public immutable amountPerUser;

    /// @notice Maximum number of users allowed to claim
    uint256 public immutable maxUsers;

    /// @notice Number of users who successfully claimed
    uint256 public claimedCount;

    /// @notice Tracks whether user already claimed
    mapping(address => bool) public hasClaimed;

    /// @notice Last claim block per user (anti spam)
    mapping(address => uint256) public lastClaimBlock;

    /// @notice Minimum blocks between claims (rate limit)
    uint256 public cooldownBlocks = 3;

    // ===================== EVENTS =====================

    /**
     * @notice Emitted when a user successfully claims tokens
     * @param user Address that received tokens
     * @param amount Amount transferred
     */
    event Claimed(address indexed user, uint256 amount);

    // ===================== CONSTRUCTOR =====================

    /**
     * @notice Initializes airdrop contract
     * @param _token ERC20 token address
     * @param _amountPerUser tokens per claim
     * @param _maxUsers max number of claims
     * @param owner contract owner
     */
    constructor(
        address _token,
        uint256 _amountPerUser,
        uint256 _maxUsers,
        address owner
    ) Ownable(owner) {

        require(_token != address(0), "ZERO_TOKEN");
        require(_amountPerUser > 0, "INVALID_AMOUNT");
        require(_maxUsers > 0, "INVALID_MAX");

        token = IERC20(_token);
        amountPerUser = _amountPerUser;
        maxUsers = _maxUsers;
    }

    // ===================== MAIN LOGIC =====================

    /**
     * @notice Claim airdrop tokens
     * @dev Includes anti-bot checks: EOA validation and cooldown
     */
    function claim() external {

        // ===================== BASIC CHECKS =====================

        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (claimedCount >= maxUsers) revert AirdropFinished();

        // ===================== ANTI-BOT LAYER =====================

        /**
         * @dev Ensures caller is not a contract.
         * tx.origin is used as simple anti-bot protection (not perfect, but effective for drops).
         */
        if (msg.sender.code.length != 0) revert NotEOA();

        /**
         * @dev Block-level cooldown prevents spam transactions from same address.
         */
        uint256 previousClaimBlock = lastClaimBlock[msg.sender];
        if (
            previousClaimBlock != 0 &&
            block.number <= previousClaimBlock + cooldownBlocks
        ) {
            revert CooldownActive();
        }

        // ===================== STATE UPDATE =====================

        lastClaimBlock[msg.sender] = block.number;

        uint256 balance = token.balanceOf(address(this));
        if (balance < amountPerUser) revert NoTokensLeft();

        hasClaimed[msg.sender] = true;
        claimedCount++;

        // ===================== TOKEN TRANSFER =====================

        token.safeTransfer(msg.sender, amountPerUser);

        emit Claimed(msg.sender, amountPerUser);
    }

    // ===================== VIEW FUNCTIONS =====================

    /**
     * @notice Returns remaining tokens in the airdrop pool
     * @return Remaining token balance of contract
     */
    function remainingTokens() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Checks if a user can claim tokens
     * @param user Address to check
     * @return true if user is eligible
     */
    function canClaim(address user) external view returns (bool) {
        if (hasClaimed[user]) return false;
        if (claimedCount >= maxUsers) return false;
        if (user.code.length != 0) return false;
        uint256 previousClaimBlock = lastClaimBlock[user];
        if (
            previousClaimBlock != 0 &&
            block.number <= previousClaimBlock + cooldownBlocks
        ) return false;
        if (token.balanceOf(address(this)) < amountPerUser) return false;
        return true;
    }

    // ===================== ADMIN FUNCTIONS =====================

    /**
     * @notice Updates cooldown period
     * @param blocks number of blocks between claims
     */
    function setCooldown(uint256 blocks) external onlyOwner {
        cooldownBlocks = blocks;
    }

}
