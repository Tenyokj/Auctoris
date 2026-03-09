// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {ILiquidityPool} from "../interfaces/ILiquidityPool.sol";
import {IRouter} from "../interfaces/IRouter.sol";
import {IRouterV2} from "../interfaces/IRouterV2.sol";
import {DEXErrors} from "../common/DEXErrors.sol";

/**
 * @title RouterV2
 * @notice Upgradeable route-optimizer wrapper over base router.
 * @dev Evaluates direct and 2-hop paths across provided candidate intermediates.
 *
 * @custom:version 1.0.0
 */
contract RouterV2 is Initializable, OwnableUpgradeable, PausableUpgradeable, IRouterV2, DEXErrors {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice Factory used to discover pools and reserves.
    IPoolFactory public factory;

    /// @notice Base router used for final swap execution.
    IRouter public router;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes RouterV2.
     * @param owner_ Owner/admin address.
     * @param factory_ Factory address.
     * @param router_ Base router address.
     */
    function initialize(address owner_, address factory_, address router_) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();

        if (owner_ == address(0) || factory_ == address(0) || router_ == address(0)) revert InvalidAddress();
        factory = IPoolFactory(factory_);
        router = IRouter(router_);
    }

    /* ========== EXTERNAL / PUBLIC FUNCTIONS ========== */

    function getBestPathOut(uint256 amountIn, address tokenIn, address tokenOut, address[] calldata candidates)
        public
        view
        returns (address[] memory bestPath, uint256 bestAmountOut)
    {
        if (tokenIn == address(0) || tokenOut == address(0) || tokenIn == tokenOut) revert InvalidPath();

        bestAmountOut = _quoteHop(amountIn, tokenIn, tokenOut);
        if (bestAmountOut > 0) {
            bestPath = new address[](2);
            bestPath[0] = tokenIn;
            bestPath[1] = tokenOut;
        }

        for (uint256 i = 0; i < candidates.length; i++) {
            address mid = candidates[i];
            if (mid == address(0) || mid == tokenIn || mid == tokenOut) continue;

            uint256 first = _quoteHop(amountIn, tokenIn, mid);
            if (first == 0) continue;
            uint256 second = _quoteHop(first, mid, tokenOut);
            if (second > bestAmountOut) {
                bestAmountOut = second;
                bestPath = new address[](3);
                bestPath[0] = tokenIn;
                bestPath[1] = mid;
                bestPath[2] = tokenOut;
            }
        }
    }

    function swapBestTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address[] calldata candidates,
        address to,
        uint256 deadline
    ) external whenNotPaused returns (uint256[] memory amounts, address[] memory bestPath) {
        if (factory.paused()) revert ProtocolPaused();

        (bestPath, ) = getBestPathOut(amountIn, tokenIn, tokenOut, candidates);
        if (bestPath.length < 2) revert NoRoute();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(address(router), amountIn);
        amounts = router.swapExactTokensForTokens(amountIn, amountOutMin, bestPath, to, deadline);

        emit BestPathSwap(msg.sender, tokenIn, tokenOut, amountIn, amounts[amounts.length - 1]);
    }

    /**
     * @notice Pauses router-v2 operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses router-v2 operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _quoteHop(uint256 amountIn, address tokenIn, address tokenOut) internal view returns (uint256 amountOut) {
        address pool = factory.getPool(tokenIn, tokenOut);
        if (pool == address(0)) return 0;

        ILiquidityPool lp = ILiquidityPool(pool);
        address tokenA = lp.tokenA();
        (uint256 reserveA, uint256 reserveB) = (lp.reserveA(), lp.reserveB());
        (uint256 reserveIn, uint256 reserveOut) = tokenIn == tokenA ? (reserveA, reserveB) : (reserveB, reserveA);
        if (reserveIn == 0 || reserveOut == 0) return 0;

        amountOut = lp.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
