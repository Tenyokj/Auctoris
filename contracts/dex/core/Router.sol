// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ILiquidityPool} from "../interfaces/ILiquidityPool.sol";
import {IRouter} from "../interfaces/IRouter.sol";
import {DEXErrors} from "../common/DEXErrors.sol";

/**
 * @title Router
 * @notice Upgradeable user-facing router for liquidity and swap operations.
 * @dev Deploy behind Transparent proxy and initialize with owner/factory/WETH.
 * @dev Uses OZ PausableUpgradeable and ReentrancyGuardUpgradeable.
 *
 * @custom:version 1.0.0
 */
contract Router is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, IRouter, DEXErrors {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice Factory contract used for pool discovery and config checks.
    IPoolFactory public factory;

    /// @notice Wrapped ETH token address.
    address public WETH;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes router for proxy deployment.
     * @param owner_ Owner/admin address.
     * @param factory_ Factory address.
     * @param weth_ Wrapped ETH address.
     */
    function initialize(address owner_, address factory_, address weth_) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();
        __ReentrancyGuard_init();

        if (owner_ == address(0) || factory_ == address(0) || weth_ == address(0)) revert InvalidAddress();
        factory = IPoolFactory(factory_);
        WETH = weth_;
    }

    /* ========== RECEIVE ========== */

    /**
     * @notice Receives ETH only from WETH contract during unwrap operations.
     */
    receive() external payable {
        if (msg.sender != WETH) revert InvalidAddress();
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 minShares,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (address pool, uint256 amountA, uint256 amountB, uint256 shares) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        if (amountADesired == 0 || amountBDesired == 0) revert InsufficientAmount();

        pool = _getOrCreatePool(tokenA, tokenB);
        (amountA, amountB) = _calculateLiquidityAmounts(
            pool, tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin
        );

        IERC20(tokenA).safeTransferFrom(msg.sender, pool, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pool, amountB);

        shares = ILiquidityPool(pool).addLiquidityFromBalances(minShares, deadline);
        IERC20(pool).safeTransfer(msg.sender, shares);
        emit RouterLiquidityAdded(msg.sender, pool, tokenA, tokenB, amountA, amountB, shares);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 minShares,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused returns (address pool, uint256 amountToken, uint256 amountETH, uint256 shares) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        if (amountTokenDesired == 0 || msg.value == 0) revert InsufficientAmount();

        pool = _getOrCreatePool(token, WETH);
        (amountToken, amountETH) =
            _calculateLiquidityAmounts(pool, token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);

        IERC20(token).safeTransferFrom(msg.sender, pool, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        IERC20(WETH).safeTransfer(pool, amountETH);

        shares = ILiquidityPool(pool).addLiquidityFromBalances(minShares, deadline);
        IERC20(pool).safeTransfer(msg.sender, shares);
        emit RouterLiquidityAdded(msg.sender, pool, token, WETH, amountToken, amountETH, shares);

        if (msg.value > amountETH) {
            (bool ok, ) = msg.sender.call{value: msg.value - amountETH}("");
            if (!ok) revert ExternalCallFailed();
        }
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityShare,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        address pool = factory.getPool(tokenA, tokenB);
        if (pool == address(0)) revert PoolNotFound();

        IERC20(pool).safeTransferFrom(msg.sender, address(this), liquidityShare);

        (amountA, amountB) = ILiquidityPool(pool).removeLiquidity(liquidityShare, amountAMin, amountBMin, deadline);
        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);
        emit RouterLiquidityRemoved(msg.sender, pool, tokenA, tokenB, amountA, amountB, liquidityShare);
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidityShare,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountToken, uint256 amountETH) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        address pool = factory.getPool(token, WETH);
        if (pool == address(0)) revert PoolNotFound();

        IERC20(pool).safeTransferFrom(msg.sender, address(this), liquidityShare);

        (amountToken, amountETH) = ILiquidityPool(pool).removeLiquidity(liquidityShare, amountTokenMin, amountETHMin, deadline);
        IERC20(token).safeTransfer(msg.sender, amountToken);
        IWETH(WETH).withdraw(amountETH);
        (bool ok, ) = msg.sender.call{value: amountETH}("");
        if (!ok) revert ExternalCallFailed();
        emit RouterLiquidityRemoved(msg.sender, pool, token, WETH, amountToken, amountETH, liquidityShare);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256[] memory amounts) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        if (path.length < 2) revert InvalidPath();
        if (to == address(0)) revert InvalidAddress();

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256[] memory noHopMins = new uint256[](0);
        amounts = _executePathSwap(path, amountIn, deadline, noHopMins);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
        IERC20(path[path.length - 1]).safeTransfer(to, amounts[amounts.length - 1]);
        emit RouterSwap(msg.sender, to, path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
    }

    function swapExactTokensForTokensWithHopMin(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata hopMinOuts,
        address to,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256[] memory amounts) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        if (path.length < 2) revert InvalidPath();
        if (hopMinOuts.length != path.length - 1) revert InvalidHopMins();
        if (to == address(0)) revert InvalidAddress();

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        amounts = _executePathSwap(path, amountIn, deadline, hopMinOuts);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
        IERC20(path[path.length - 1]).safeTransfer(to, amounts[amounts.length - 1]);
        emit RouterSwap(msg.sender, to, path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused returns (uint256[] memory amounts) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        if (path.length < 2 || path[0] != WETH) revert InvalidPath();
        if (to == address(0)) revert InvalidAddress();

        IWETH(WETH).deposit{value: msg.value}();
        uint256[] memory noHopMins = new uint256[](0);
        amounts = _executePathSwap(path, msg.value, deadline, noHopMins);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
        IERC20(path[path.length - 1]).safeTransfer(to, amounts[amounts.length - 1]);
        emit RouterSwap(msg.sender, to, path[0], path[path.length - 1], msg.value, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256[] memory amounts) {
        _checkFactoryNotPaused();
        _checkDeadline(deadline);
        if (path.length < 2 || path[path.length - 1] != WETH) revert InvalidPath();
        if (to == address(0)) revert InvalidAddress();

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256[] memory noHopMins = new uint256[](0);
        amounts = _executePathSwap(path, amountIn, deadline, noHopMins);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();

        uint256 ethAmount = amounts[amounts.length - 1];
        IWETH(WETH).withdraw(ethAmount);
        (bool ok, ) = to.call{value: ethAmount}("");
        if (!ok) revert ExternalCallFailed();
        emit RouterSwap(msg.sender, to, path[0], path[path.length - 1], amountIn, ethAmount);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 0; i < path.length - 1; i++) {
            address pool = factory.getPool(path[i], path[i + 1]);
            if (pool == address(0)) revert PoolNotFound();

            (uint256 reserveIn, uint256 reserveOut) = _getReserves(pool, path[i], path[i + 1]);
            amounts[i + 1] = ILiquidityPool(pool).getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice Pauses router operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses router operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _executePathSwap(
        address[] calldata path,
        uint256 initialAmountIn,
        uint256 deadline,
        uint256[] memory hopMinOuts
    ) internal returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = initialAmountIn;

        for (uint256 i = 0; i < path.length - 1; i++) {
            address input = path[i];
            address output = path[i + 1];
            address pool = factory.getPool(input, output);
            if (pool == address(0)) revert PoolNotFound();

            uint256 amountInForHop = amounts[i];
            IERC20(input).safeTransfer(pool, amountInForHop);

            uint256 outputBalanceBefore = IERC20(output).balanceOf(address(this));
            uint256 hopMinOut = hopMinOuts.length == path.length - 1 ? hopMinOuts[i] : 0;
            ILiquidityPool(pool).swap(input, hopMinOut, deadline);
            amounts[i + 1] = IERC20(output).balanceOf(address(this)) - outputBalanceBefore;
        }
    }

    function _getOrCreatePool(address tokenA, address tokenB) internal returns (address pool) {
        pool = factory.getPool(tokenA, tokenB);
        if (pool == address(0)) {
            pool = factory.createPool(tokenA, tokenB);
        }
    }

    function _calculateLiquidityAmounts(
        address pool,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = _getReserves(pool, tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            return (amountADesired, amountBDesired);
        }

        uint256 amountBOptimal = _quote(amountADesired, reserveA, reserveB);
        if (amountBOptimal <= amountBDesired) {
            if (amountBOptimal < amountBMin) revert InsufficientAmount();
            return (amountADesired, amountBOptimal);
        }

        uint256 amountAOptimal = _quote(amountBDesired, reserveB, reserveA);
        if (amountAOptimal < amountAMin) revert InsufficientAmount();
        return (amountAOptimal, amountBDesired);
    }

    function _getReserves(address poolAddr, address tokenIn, address tokenOut)
        internal
        view
        returns (uint256 reserveIn, uint256 reserveOut)
    {
        ILiquidityPool pool = ILiquidityPool(poolAddr);
        address poolTokenA = pool.tokenA();
        (uint256 reserveA, uint256 reserveB) = (pool.reserveA(), pool.reserveB());

        if (tokenIn == poolTokenA) {
            return (reserveA, reserveB);
        }
        if (tokenOut == poolTokenA) {
            return (reserveB, reserveA);
        }
        revert InvalidPath();
    }

    function _checkDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _checkFactoryNotPaused() internal view {
        if (factory.paused()) revert ProtocolPaused();
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256) {
        if (amountA == 0 || reserveA == 0 || reserveB == 0) revert InsufficientAmount();
        return (amountA * reserveB) / reserveA;
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
