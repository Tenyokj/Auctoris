// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IPoolFactoryConfig} from "../interfaces/IPoolFactoryConfig.sol";
import {IFlashSwapCallee} from "../interfaces/IFlashSwapCallee.sol";
import {IFlashLoanLimiter} from "../interfaces/IFlashLoanLimiter.sol";
import {ILiquidityPool} from "../interfaces/ILiquidityPool.sol";
import {DEXErrors} from "../common/DEXErrors.sol";

/**
 * @title LiquidityPool
 * @notice Constant-product AMM liquidity pool for ERC20 token pair.
 * @dev LP shares are represented by this contract's ERC20 token.
 * @dev Supports swaps, flash swaps, TWAP accounting, and protocol fee split.
 *
 * @custom:version 1.0.0
 */
contract LiquidityPool is ERC20, ReentrancyGuard, ILiquidityPool, DEXErrors {
    using SafeERC20 for IERC20;

    /* ========== CONSTANTS ========== */

    /// @notice Basis points denominator.
    uint256 public constant BPS = 10_000;
    /// @notice Permanently locked LP amount to prevent inflation attacks.
    uint256 public constant MINIMUM_LIQUIDITY = 1_000;
    /// @notice Precision scale used for cumulative price accounting.
    uint256 private constant PRICE_PRECISION = 1e18;
    /// @notice Burn address receiving initial minimum liquidity.
    address private constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    /// @notice Token0 address for this pool pair.
    address public immutable tokenA;
    /// @notice Token1 address for this pool pair.
    address public immutable tokenB;
    /// @notice Wrapped ETH token used by ETH helper swaps.
    address public immutable WETH;
    /// @notice Factory configuration source for fees/pause/limiter.
    address public immutable factory;

    /// @notice Current reserve of `tokenA`.
    uint256 public reserveA;
    /// @notice Current reserve of `tokenB`.
    uint256 public reserveB;

    /// @notice Cumulative price of tokenA in terms of tokenB over time.
    uint256 public priceACumulativeLast;
    /// @notice Cumulative price of tokenB in terms of tokenA over time.
    uint256 public priceBCumulativeLast;
    /// @notice Last timestamp used to update cumulative prices.
    uint32 public blockTimestampLast;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Deploys a pool for a sorted token pair.
     * @param _tokenA tokenA address.
     * @param _tokenB tokenB address.
     * @param _weth Wrapped ETH token address.
     * @param _factory Factory address used for fee/pause/limiter config.
     * @custom:requires token addresses are non-zero and distinct.
     * @custom:requires `_weth` and `_factory` are non-zero.
     */
    constructor(address _tokenA, address _tokenB, address _weth, address _factory) ERC20("AlsoSwap LP Token", "ASLP") {
        if (_tokenA == address(0) || _tokenB == address(0) || _tokenA == _tokenB) revert InvalidToken();
        if (_weth == address(0)) revert InvalidWETH();
        if (_factory == address(0)) revert InvalidFactory();

        tokenA = _tokenA;
        tokenB = _tokenB;
        WETH = _weth;
        factory = _factory;
        blockTimestampLast = uint32(block.timestamp);
    }

    /* ========== RECEIVE ========== */

    /**
     * @notice Receives ETH only from WETH contract during unwrap flows.
     * @custom:requires `msg.sender == WETH`.
     */
    receive() external payable {
        if (msg.sender != WETH) revert EthNotSupported();
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Adds liquidity by transferring both assets from caller.
     * @param amountA Desired tokenA amount.
     * @param amountB Desired tokenB amount.
     * @param minShares Minimum acceptable LP shares.
     * @param deadline Expiration timestamp.
     * @return shares Minted LP shares.
     */
    function addLiquidity(
        uint256 amountA,
        uint256 amountB,
        uint256 minShares,
        uint256 deadline
    ) external nonReentrant returns (uint256 shares) {
        _checkNotPaused();
        _checkDeadline(deadline);
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        uint256 balanceABefore = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceBBefore = IERC20(tokenB).balanceOf(address(this));

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        uint256 receivedA = IERC20(tokenA).balanceOf(address(this)) - balanceABefore;
        uint256 receivedB = IERC20(tokenB).balanceOf(address(this)) - balanceBBefore;

        shares = _mintLiquidityShares(receivedA, receivedB, minShares, msg.sender);
        _syncReserves();

        emit LiquidityAdded(msg.sender, receivedA, receivedB, shares);
    }

    /**
     * @notice Adds liquidity from tokens already transferred to pool.
     * @param minShares Minimum acceptable LP shares.
     * @param deadline Expiration timestamp.
     * @return shares Minted LP shares.
     */
    function addLiquidityFromBalances(uint256 minShares, uint256 deadline)
        external
        nonReentrant
        returns (uint256 shares)
    {
        _checkNotPaused();
        _checkDeadline(deadline);

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        if (balanceA < reserveA || balanceB < reserveB) revert InsufficientLiquidity();

        uint256 receivedA = balanceA - reserveA;
        uint256 receivedB = balanceB - reserveB;

        shares = _mintLiquidityShares(receivedA, receivedB, minShares, msg.sender);
        _syncReserves();

        emit LiquidityAdded(msg.sender, receivedA, receivedB, shares);
    }

    /**
     * @notice Removes liquidity and returns proportional underlying reserves.
     * @param liquidityShare LP amount to burn.
     * @param amountAMin Minimum tokenA output.
     * @param amountBMin Minimum tokenB output.
     * @param deadline Expiration timestamp.
     * @return amountA tokenA output.
     * @return amountB tokenB output.
     */
    function removeLiquidity(
        uint256 liquidityShare,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        _checkNotPaused();
        _checkDeadline(deadline);
        if (liquidityShare == 0) revert ZeroAmount();

        uint256 totalShares = totalSupply();
        if (totalShares == 0) revert InsufficientLiquidity();

        amountA = (liquidityShare * reserveA) / totalShares;
        amountB = (liquidityShare * reserveB) / totalShares;

        if (amountA == 0 || amountB == 0) revert InsufficientLiquidity();
        if (amountA < amountAMin || amountB < amountBMin) revert SlippageExceeded();

        _burn(msg.sender, liquidityShare);

        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);

        _syncReserves();

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityShare);
    }

    /**
     * @notice Executes exact-input swap after input tokens are pre-transferred.
     * @param tokenIn Input token address.
     * @param amountOutMin Minimum output amount accepted by caller.
     * @param deadline Expiration timestamp.
     * @return amountOut Output token amount transferred to caller.
     */
    function swap(address tokenIn, uint256 amountOutMin, uint256 deadline)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        _checkNotPaused();
        _checkDeadline(deadline);
        amountOut = _swapFromCurrentBalance(tokenIn, amountOutMin, msg.sender);
        emit SwapExecuted(msg.sender, tokenIn, tokenIn == tokenA ? tokenB : tokenA, amountOut);
    }

    /**
     * @notice Executes flash swap with callback and invariant validation.
     * @param amountAOut tokenA amount to borrow.
     * @param amountBOut tokenB amount to borrow.
     * @param to Receiver/callback contract.
     * @param data Callback payload.
     * @param deadline Expiration timestamp.
     */
    function flashSwap(
        uint256 amountAOut,
        uint256 amountBOut,
        address to,
        bytes calldata data,
        uint256 deadline
    ) external nonReentrant {
        _checkNotPaused();
        _checkDeadline(deadline);
        if (to == address(0)) revert InvalidRecipient();
        if (amountAOut == 0 && amountBOut == 0) revert InvalidFlashSwap();
        if (amountAOut >= reserveA || amountBOut >= reserveB) revert InsufficientLiquidity();

        uint256 reserveABefore = reserveA;
        uint256 reserveBBefore = reserveB;
        _checkFlashLimits(msg.sender, reserveABefore, reserveBBefore, amountAOut, amountBOut);

        if (amountAOut > 0) IERC20(tokenA).safeTransfer(to, amountAOut);
        if (amountBOut > 0) IERC20(tokenB).safeTransfer(to, amountBOut);

        if (data.length > 0) {
            IFlashSwapCallee(to).flashSwapCall(msg.sender, amountAOut, amountBOut, data);
        }

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        uint256 expectedA = reserveABefore - amountAOut;
        uint256 expectedB = reserveBBefore - amountBOut;

        uint256 amountAIn = balanceA > expectedA ? balanceA - expectedA : 0;
        uint256 amountBIn = balanceB > expectedB ? balanceB - expectedB : 0;
        if (amountAIn == 0 && amountBIn == 0) revert InsufficientInputAmount();

        (uint256 swapFeeBps, uint256 protocolFeeBps, address feeReceiver) = _feeConfig();
        uint256 lpFeeBps = swapFeeBps - protocolFeeBps;
        uint256 amountAInAfterProtocol = _takeProtocolFee(tokenA, amountAIn, protocolFeeBps, feeReceiver);
        uint256 amountBInAfterProtocol = _takeProtocolFee(tokenB, amountBIn, protocolFeeBps, feeReceiver);

        _checkFlashInvariant(reserveABefore, reserveBBefore, amountAInAfterProtocol, amountBInAfterProtocol, lpFeeBps);

        _syncReserves();
    }

    /**
     * @notice Swaps exact ETH (wrapped to WETH) for paired token.
     * @param amountOutMin Minimum token output.
     * @param deadline Expiration timestamp.
     * @return amountOut Output token amount.
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 amountOut) {
        _checkNotPaused();
        _checkDeadline(deadline);
        if (msg.value == 0) revert ZeroAmount();
        if (tokenA != WETH && tokenB != WETH) revert EthNotSupported();

        IWETH(WETH).deposit{value: msg.value}();
        amountOut = _swapFromCurrentBalance(WETH, amountOutMin, msg.sender);

        address tokenOut = tokenA == WETH ? tokenB : tokenA;
        emit SwapEthForToken(msg.sender, msg.value, tokenOut, amountOut);
    }

    /**
     * @notice Swaps exact ERC20 token input for native ETH output.
     * @param tokenIn Input token (must be non-WETH side of this pool).
     * @param amountIn Input amount to transfer from caller.
     * @param amountOutMin Minimum ETH output.
     * @param deadline Expiration timestamp.
     * @return amountOutEth ETH amount returned.
     */
    function swapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOutEth) {
        _checkNotPaused();
        _checkDeadline(deadline);
        if (amountIn == 0) revert ZeroAmount();
        if (tokenA != WETH && tokenB != WETH) revert EthNotSupported();
        if (tokenIn == WETH || (tokenIn != tokenA && tokenIn != tokenB)) revert InvalidToken();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        amountOutEth = _swapFromCurrentBalance(tokenIn, amountOutMin, address(this));

        IWETH(WETH).withdraw(amountOutEth);
        (bool ok, ) = msg.sender.call{value: amountOutEth}("");
        if (!ok) revert TransferFailed();

        emit SwapTokenForEth(msg.sender, tokenIn, amountIn, amountOutEth);
    }

    /**
     * @notice Pure proportion quote helper for liquidity operations.
     * @param amountAIn Input amount.
     * @param reserveAIn Reserve corresponding to input side.
     * @param reserveBIn Reserve corresponding to output side.
     * @return amountBOut Quoted output amount.
     */
    function quote(uint256 amountAIn, uint256 reserveAIn, uint256 reserveBIn) public pure returns (uint256 amountBOut) {
        if (amountAIn == 0 || reserveAIn == 0 || reserveBIn == 0) revert InsufficientLiquidity();
        amountBOut = (amountAIn * reserveBIn) / reserveAIn;
    }

    /**
     * @notice Returns AMM output quote using current factory fee config.
     * @param amountIn Input amount.
     * @param reserveIn Input reserve.
     * @param reserveOut Output reserve.
     * @return amountOut Quoted output amount.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        (uint256 swapFeeBps, uint256 protocolFeeBps, ) = _feeConfig();
        uint256 protocolFee = (amountIn * protocolFeeBps) / BPS;
        uint256 amountInAfterProtocol = amountIn - protocolFee;
        uint256 lpFeeBps = swapFeeBps - protocolFeeBps;

        amountOut = _getAmountOutWithLpFee(amountInAfterProtocol, reserveIn, reserveOut, lpFeeBps);
    }

    /**
     * @notice Preview helper for token-side swap quote using current reserves.
     * @param tokenIn Input token.
     * @param amountIn Input amount.
     * @return amountOut Quoted output amount.
     */
    function previewSwap(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        if (tokenIn != tokenA && tokenIn != tokenB) revert InvalidToken();

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == tokenA ? (reserveA, reserveB) : (reserveB, reserveA);
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /**
     * @notice Returns cumulative prices with counterfactual update to current timestamp.
     * @return priceACumulative Cumulative price of tokenA.
     * @return priceBCumulative Cumulative price of tokenB.
     * @return blockTimestamp Current block timestamp casted to uint32.
     */
    function currentCumulativePrices()
        external
        view
        returns (uint256 priceACumulative, uint256 priceBCumulative, uint32 blockTimestamp)
    {
        priceACumulative = priceACumulativeLast;
        priceBCumulative = priceBCumulativeLast;
        blockTimestamp = uint32(block.timestamp);

        if (reserveA > 0 && reserveB > 0 && blockTimestamp > blockTimestampLast) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            priceACumulative += ((reserveB * PRICE_PRECISION) / reserveA) * timeElapsed;
            priceBCumulative += ((reserveA * PRICE_PRECISION) / reserveB) * timeElapsed;
        }
    }

    /**
     * @notice Synchronizes reserves to current token balances.
     */
    function sync() external nonReentrant {
        _syncReserves();
    }

    /**
     * @notice Transfers excess balance above reserves to recipient.
     * @param to Recipient address for surplus tokens.
     */
    function skim(address to) external nonReentrant {
        if (to == address(0)) revert InvalidRecipient();

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        uint256 extraA;
        uint256 extraB;

        if (balanceA > reserveA) {
            extraA = balanceA - reserveA;
            IERC20(tokenA).safeTransfer(to, extraA);
        }
        if (balanceB > reserveB) {
            extraB = balanceB - reserveB;
            IERC20(tokenB).safeTransfer(to, extraB);
        }

        emit Skimmed(to, extraA, extraB);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @notice Core swap routine reading input from balance delta.
     * @param tokenIn Input token.
     * @param amountOutMin Minimum output amount.
     * @param recipient Receiver of output tokens.
     * @return amountOut Output amount transferred.
     */
    function _swapFromCurrentBalance(address tokenIn, uint256 amountOutMin, address recipient) internal returns (uint256 amountOut) {
        if (tokenIn != tokenA && tokenIn != tokenB) revert InvalidToken();
        if (recipient == address(0)) revert InvalidRecipient();

        bool isTokenAIn = tokenIn == tokenA;
        address tokenOut = isTokenAIn ? tokenB : tokenA;
        (uint256 reserveIn, uint256 reserveOut) = isTokenAIn ? (reserveA, reserveB) : (reserveB, reserveA);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 balanceIn = IERC20(tokenIn).balanceOf(address(this));
        if (balanceIn <= reserveIn) revert InsufficientInputAmount();
        uint256 amountIn = balanceIn - reserveIn;

        (uint256 swapFeeBps, uint256 protocolFeeBps, address feeReceiver) = _feeConfig();
        uint256 amountInAfterProtocol = _takeProtocolFee(tokenIn, amountIn, protocolFeeBps, feeReceiver);
        if (amountInAfterProtocol == 0) revert InsufficientInputAmount();

        uint256 lpFeeBps = swapFeeBps - protocolFeeBps;
        amountOut = _getAmountOutWithLpFee(amountInAfterProtocol, reserveIn, reserveOut, lpFeeBps);

        if (amountOut == 0) revert InsufficientOutputAmount();
        if (amountOut < amountOutMin) revert SlippageExceeded();

        IERC20(tokenOut).safeTransfer(recipient, amountOut);

        _syncReserves();
    }

    /**
     * @notice Reverts when provided deadline is in the past.
     * @param deadline Expiration timestamp.
     */
    function _checkDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    /**
     * @notice Reverts when factory is paused.
     */
    function _checkNotPaused() internal view {
        if (IPoolFactoryConfig(factory).paused()) revert ProtocolPaused();
    }

    function _checkFlashLimits(
        address caller,
        uint256 reserveABefore,
        uint256 reserveBBefore,
        uint256 amountAOut,
        uint256 amountBOut
    ) internal view {
        address limiter = IPoolFactoryConfig(factory).flashLoanLimiter();
        if (limiter != address(0)) {
            IFlashLoanLimiter(limiter).validateFlashSwap(
                address(this), caller, reserveABefore, reserveBBefore, amountAOut, amountBOut
            );
        }
    }

    /**
     * @notice Mints LP shares based on received token amounts.
     * @param receivedA Net tokenA received.
     * @param receivedB Net tokenB received.
     * @param minShares Minimum accepted shares.
     * @param recipient Share recipient.
     * @return shares Minted shares.
     */
    function _mintLiquidityShares(
        uint256 receivedA,
        uint256 receivedB,
        uint256 minShares,
        address recipient
    ) internal returns (uint256 shares) {
        if (receivedA == 0 || receivedB == 0) revert ZeroAmount();

        uint256 totalShares = totalSupply();
        if (totalShares == 0) {
            uint256 liquidity = Math.sqrt(receivedA * receivedB);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();

            _mint(BURN_ADDRESS, MINIMUM_LIQUIDITY);
            shares = liquidity - MINIMUM_LIQUIDITY;
        } else {
            uint256 sharesFromA = (receivedA * totalShares) / reserveA;
            uint256 sharesFromB = (receivedB * totalShares) / reserveB;
            shares = Math.min(sharesFromA, sharesFromB);
            if (shares == 0) revert InsufficientLiquidity();
        }

        if (shares < minShares) revert SlippageExceeded();
        _mint(recipient, shares);
    }

    /**
     * @notice Reads current balances and updates reserves/cumulative price state.
     */
    function _syncReserves() internal {
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        _updateReserves(balanceA, balanceB);
    }

    /**
     * @notice Updates reserve state and cumulative price accumulators.
     * @param balanceA Current tokenA balance.
     * @param balanceB Current tokenB balance.
     */
    function _updateReserves(uint256 balanceA, uint256 balanceB) internal {
        uint32 blockTimestamp = uint32(block.timestamp);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && reserveA > 0 && reserveB > 0) {
            priceACumulativeLast += ((reserveB * PRICE_PRECISION) / reserveA) * timeElapsed;
            priceBCumulativeLast += ((reserveA * PRICE_PRECISION) / reserveB) * timeElapsed;
        }

        reserveA = balanceA;
        reserveB = balanceB;
        blockTimestampLast = blockTimestamp;

        emit Synced(balanceA, balanceB);
    }

    /**
     * @notice Loads and validates fee configuration from factory.
     * @return swapFee Total swap fee bps.
     * @return protocolFee Protocol fee bps.
     * @return receiver Protocol fee receiver.
     */
    function _feeConfig() internal view returns (uint256 swapFee, uint256 protocolFee, address receiver) {
        IPoolFactoryConfig cfg = IPoolFactoryConfig(factory);
        swapFee = cfg.swapFeeBps();
        protocolFee = cfg.protocolFeeBps();
        receiver = cfg.feeReceiver();

        if (swapFee >= BPS || protocolFee > swapFee) revert InvalidFeeConfig();
        if (protocolFee > 0 && receiver == address(0)) revert InvalidFeeConfig();
    }

    /**
     * @notice Internal AMM quote with LP fee portion applied.
     * @param amountIn Effective input amount after protocol cut.
     * @param reserveIn Input reserve.
     * @param reserveOut Output reserve.
     * @param lpFeeBps LP fee in bps.
     * @return amountOut Output amount.
     */
    function _getAmountOutWithLpFee(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 lpFeeBps)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * (BPS - lpFeeBps);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * BPS + amountInWithFee);
    }

    /**
     * @notice Calculates and transfers protocol fee from input amount.
     * @param token Fee token.
     * @param amountIn Input amount before protocol cut.
     * @param protocolFeeBps Protocol fee in bps.
     * @param feeReceiver Receiver of protocol fee.
     * @return amountAfter Remaining amount after fee transfer.
     */
    function _takeProtocolFee(address token, uint256 amountIn, uint256 protocolFeeBps, address feeReceiver)
        internal
        returns (uint256 amountAfter)
    {
        uint256 protocolFee = (amountIn * protocolFeeBps) / BPS;
        amountAfter = amountIn - protocolFee;
        if (protocolFee > 0) {
            IERC20(token).safeTransfer(feeReceiver, protocolFee);
            emit ProtocolFeePaid(token, feeReceiver, protocolFee);
        }
    }

    /**
     * @notice Validates post-flash adjusted invariant with fee adjustments.
     * @param reserveABefore Pre-flash reserveA.
     * @param reserveBBefore Pre-flash reserveB.
     * @param amountAInAfterProtocol Net tokenA returned after protocol fee.
     * @param amountBInAfterProtocol Net tokenB returned after protocol fee.
     * @param lpFeeBps LP fee in bps.
     */
    function _checkFlashInvariant(
        uint256 reserveABefore,
        uint256 reserveBBefore,
        uint256 amountAInAfterProtocol,
        uint256 amountBInAfterProtocol,
        uint256 lpFeeBps
    ) internal view {
        uint256 balanceAFinal = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceBFinal = IERC20(tokenB).balanceOf(address(this));

        uint256 balanceAAdjusted = (balanceAFinal * BPS) - (amountAInAfterProtocol * lpFeeBps);
        uint256 balanceBAdjusted = (balanceBFinal * BPS) - (amountBInAfterProtocol * lpFeeBps);

        if (balanceAAdjusted * balanceBAdjusted < reserveABefore * reserveBBefore * BPS * BPS) {
            revert InvalidK();
        }
    }
}
