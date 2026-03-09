// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {LiquidityPool} from "./LiquidityPool.sol";
import {DEXErrors} from "../common/DEXErrors.sol";
import {IPoolFactoryAdmin} from "../interfaces/IPoolFactoryAdmin.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";

/**
 * @title PoolFactory
 * @notice Upgradeable factory for creating AMM pools and managing protocol-wide configuration.
 * @dev Deploy behind TransparentUpgradeableProxy and initialize once.
 * @dev Uses OpenZeppelin OwnableUpgradeable and PausableUpgradeable as protocol admin standard.
 *
 * @custom:version 1.0.0
 */
contract PoolFactory is Initializable, OwnableUpgradeable, PausableUpgradeable, IPoolFactoryAdmin, DEXErrors {
    /* ========== STATE VARIABLES ========== */

    /// @notice Wrapped ETH token address shared by pools and routers.
    address public WETH;

    /// @notice Total swap fee in basis points.
    uint256 public swapFeeBps;

    /// @notice Protocol share of swap fee in basis points.
    uint256 public protocolFeeBps;

    /// @notice Address receiving protocol fee transfers from pools.
    address public feeReceiver;

    /// @notice Optional flash-swap limiter contract.
    address public flashLoanLimiter;

    /// @notice Pair-to-pool registry: token0 => token1 => pool address.
    mapping(address token0 => mapping(address token1 => address pool)) public getPool;

    /// @notice Enumerable list of all deployed pools.
    address[] public allPools;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes factory state for proxy deployment.
     * @param owner_ Protocol admin address.
     * @param weth_ Wrapped ETH token address.
     * @custom:requires `owner_` and `weth_` are non-zero.
     */
    function initialize(address owner_, address weth_) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();

        if (owner_ == address(0)) revert InvalidAddress();
        if (weth_ == address(0)) revert InvalidWETH();

        WETH = weth_;
        swapFeeBps = 30;
        protocolFeeBps = 0;
        feeReceiver = owner_;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Creates a new pool for token pair if it does not exist.
     * @param tokenA First token.
     * @param tokenB Second token.
     * @return pool Newly created pool address.
     */
    function createPool(address tokenA, address tokenB) external whenNotPaused returns (address pool) {
        if (tokenA == tokenB) revert IdenticalTokenAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddressToken();

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (getPool[token0][token1] != address(0)) revert PoolAlreadyExists();

        pool = address(new LiquidityPool(token0, token1, WETH, address(this)));
        getPool[token0][token1] = pool;
        getPool[token1][token0] = pool;
        allPools.push(pool);

        emit PoolCreated(token0, token1, pool, allPools.length);
    }

    /**
     * @notice Returns number of pools created by factory.
     */
    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    /**
     * @inheritdoc IPoolFactoryAdmin
     */
    function setFeeConfig(uint256 swapFeeBps_, uint256 protocolFeeBps_, address feeReceiver_)
        external
        onlyOwner
    {
        if (swapFeeBps_ >= 10_000 || protocolFeeBps_ > swapFeeBps_) revert InvalidFeeConfig();
        if (protocolFeeBps_ > 0 && feeReceiver_ == address(0)) revert InvalidFeeConfig();

        swapFeeBps = swapFeeBps_;
        protocolFeeBps = protocolFeeBps_;
        feeReceiver = feeReceiver_;

        emit FeeConfigUpdated(swapFeeBps_, protocolFeeBps_, feeReceiver_);
    }

    /**
     * @inheritdoc IPoolFactoryAdmin
     */
    function setFlashLoanLimiter(address limiter) external onlyOwner {
        if (limiter == address(0)) revert InvalidLimiter();
        flashLoanLimiter = limiter;
        emit FlashLoanLimiterUpdated(limiter);
    }

    /**
     * @inheritdoc IPoolFactoryAdmin
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @inheritdoc IPoolFactoryAdmin
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Returns pause state of factory.
     * @return True when protocol is paused.
     */
    function paused() public view override(IPoolFactory, PausableUpgradeable) returns (bool) {
        return super.paused();
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @notice Sorts two token addresses into canonical order.
     * @param tokenA First token candidate.
     * @param tokenB Second token candidate.
     * @return token0 Lower lexical address.
     * @return token1 Higher lexical address.
     */
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
