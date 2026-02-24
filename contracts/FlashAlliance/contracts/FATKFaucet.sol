// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title FATKFaucet
/// @notice Simple ERC20 faucet with per-wallet cooldown.
contract FATKFaucet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public claimAmount;
    uint256 public claimCooldown;
    mapping(address => uint256) public lastClaimAt;

    event Claimed(address indexed user, uint256 amount, uint256 timestamp);
    event ClaimAmountUpdated(uint256 amount);
    event ClaimCooldownUpdated(uint256 cooldown);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(address token_, address owner_, uint256 claimAmount_, uint256 claimCooldown_)
        Ownable(owner_)
    {
        require(token_ != address(0), "Faucet: zero token");
        require(owner_ != address(0), "Faucet: zero owner");
        require(claimAmount_ > 0, "Faucet: zero amount");
        require(claimCooldown_ > 0, "Faucet: zero cooldown");

        token = IERC20(token_);
        claimAmount = claimAmount_;
        claimCooldown = claimCooldown_;
    }

    function claim() external nonReentrant {
        uint256 last = lastClaimAt[msg.sender];
        require(block.timestamp >= last + claimCooldown, "Faucet: cooldown active");

        lastClaimAt[msg.sender] = block.timestamp;
        token.safeTransfer(msg.sender, claimAmount);

        emit Claimed(msg.sender, claimAmount, block.timestamp);
    }

    function setClaimAmount(uint256 amount) external onlyOwner {
        require(amount > 0, "Faucet: zero amount");
        claimAmount = amount;
        emit ClaimAmountUpdated(amount);
    }

    function setClaimCooldown(uint256 cooldown) external onlyOwner {
        require(cooldown > 0, "Faucet: zero cooldown");
        claimCooldown = cooldown;
        emit ClaimCooldownUpdated(cooldown);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Faucet: zero recipient");
        token.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }
}
