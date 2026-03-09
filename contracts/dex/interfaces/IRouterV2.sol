// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IRouterV2
 * @notice Event interface for route-optimizer router.
 *
 * @custom:version 1.0.0
 */
interface IRouterV2 {
    event BestPathSwap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
}
