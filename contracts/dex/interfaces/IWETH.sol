// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IWETH
 * @notice Interface for Wrapped Ether token contract.
 * @dev Extends IERC20 with `deposit` and `withdraw` for ETH wrapping/unwrapping.
 *
 * @custom:version 1.0.0
 */
interface IWETH is IERC20 {
    /**
     * @notice Wraps native ETH into WETH.
     * @dev Mints WETH to `msg.sender` for `msg.value`.
     */
    function deposit() external payable;

    /**
     * @notice Unwraps WETH into native ETH.
     * @param wad Amount of WETH to burn and return as ETH.
     */
    function withdraw(uint256 wad) external;
}
