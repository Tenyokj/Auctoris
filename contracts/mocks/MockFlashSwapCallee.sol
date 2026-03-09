// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFlashSwapCallee} from "../dex/interfaces/IFlashSwapCallee.sol";

/**
 * @title MockFlashSwapCallee
 * @notice Test callback receiver for pool flash swaps.
 * @dev Repays configured amounts back to calling pool in callback.
 *
 * @custom:version 1.0.0
 */
contract MockFlashSwapCallee is IFlashSwapCallee {
    using SafeERC20 for IERC20;

    /// @notice tokenA address expected from pool.
    address public tokenA;
    /// @notice tokenB address expected from pool.
    address public tokenB;
    /// @notice Extra tokenA amount to return above borrowed amount.
    uint256 public extraA;
    /// @notice Extra tokenB amount to return above borrowed amount.
    uint256 public extraB;
    /// @notice Whether callback should skip repayment (negative test path).
    bool public skipRepay;

    /**
     * @notice Configures callback behavior.
     * @param tokenA_ Pool tokenA.
     * @param tokenB_ Pool tokenB.
     * @param extraA_ Additional tokenA to repay.
     * @param extraB_ Additional tokenB to repay.
     * @param skipRepay_ If true, callback will not repay.
     */
    function configure(address tokenA_, address tokenB_, uint256 extraA_, uint256 extraB_, bool skipRepay_) external {
        tokenA = tokenA_;
        tokenB = tokenB_;
        extraA = extraA_;
        extraB = extraB_;
        skipRepay = skipRepay_;
    }

    /**
     * @notice Flash-swap callback.
     * @param sender Original caller of flash swap.
     * @param amountAOut Borrowed tokenA amount.
     * @param amountBOut Borrowed tokenB amount.
     * @param data Unused payload.
     */
    function flashSwapCall(address sender, uint256 amountAOut, uint256 amountBOut, bytes calldata data) external override {
        sender;
        data;
        if (skipRepay) return;

        if (amountAOut > 0) {
            IERC20(tokenA).safeTransfer(msg.sender, amountAOut + extraA);
        }
        if (amountBOut > 0) {
            IERC20(tokenB).safeTransfer(msg.sender, amountBOut + extraB);
        }
    }
}

