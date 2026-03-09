// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRouterLike {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 minShares,
        uint256 deadline
    ) external payable returns (address pool, uint256 amountToken, uint256 amountETH, uint256 shares);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/**
 * @title MockEthRejector
 * @notice Helper contract that rejects ETH receives.
 * @dev Used to test ETH transfer/refund failure paths.
 *
 * @custom:version 1.0.0
 */
contract MockEthRejector {
    /**
     * @notice Reverts on direct ETH receive.
     */
    receive() external payable {
        revert("REJECT_ETH");
    }

    /**
     * @notice Approves token spending for router.
     * @param token ERC20 token.
     * @param spender Router address.
     * @param amount Allowance amount.
     */
    function approveToken(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }

    /**
     * @notice Calls router `addLiquidityETH` forwarding ETH value.
     */
    function callAddLiquidityETH(
        address router,
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 minShares,
        uint256 deadline
    ) external payable {
        IRouterLike(router).addLiquidityETH{value: msg.value}(
            token, amountTokenDesired, amountTokenMin, amountETHMin, minShares, deadline
        );
    }

    /**
     * @notice Calls router token->ETH swap with this contract as ETH receiver.
     */
    function callSwapExactTokensForETH(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external {
        IRouterLike(router).swapExactTokensForETH(amountIn, amountOutMin, path, address(this), deadline);
    }

    /**
     * @notice Calls pool helper token->ETH swap with this contract as caller/receiver.
     */
    function callPoolSwapExactTokensForETH(
        address pool,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external {
        (bool ok, ) = pool.call(
            abi.encodeWithSignature(
                "swapExactTokensForETH(address,uint256,uint256,uint256)",
                tokenIn,
                amountIn,
                amountOutMin,
                deadline
            )
        );
        require(ok, "POOL_SWAP_FAILED");
    }
}
