// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ILiquidityPool} from "../interfaces/ILiquidityPool.sol";
import {DEXErrors} from "../common/DEXErrors.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle
 * @notice Upgradeable pull-based TWAP oracle over pool cumulative prices.
 * @dev Uses OZ OwnableUpgradeable and PausableUpgradeable for operational control.
 *
 * @custom:version 1.0.0
 */
contract PriceOracle is Initializable, OwnableUpgradeable, PausableUpgradeable, IPriceOracle, DEXErrors {
    /* ========== STRUCTS ========== */

    /**
     * @notice Observation snapshot used to compute TWAP.
     */
    struct Observation {
        /// @notice Last cumulative priceA observed.
        uint256 priceACumulative;
        /// @notice Last cumulative priceB observed.
        uint256 priceBCumulative;
        /// @notice Last observation timestamp.
        uint32 timestamp;
        /// @notice Latest computed TWAP for tokenA.
        uint256 twapA;
        /// @notice Latest computed TWAP for tokenB.
        uint256 twapB;
        /// @notice Initialization marker.
        bool initialized;
    }

    /* ========== STATE VARIABLES ========== */

    /// @notice Per-pool oracle observation state.
    mapping(address pool => Observation) public observations;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes oracle contract.
     * @param owner_ Owner/admin address.
     */
    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();
        if (owner_ == address(0)) revert InvalidAddress();
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Updates TWAP snapshot for pool.
     * @param pool Pool address.
     */
    function update(address pool) external whenNotPaused {
        (uint256 cumulativeA, uint256 cumulativeB, uint32 nowTs) = ILiquidityPool(pool).currentCumulativePrices();

        Observation storage obs = observations[pool];
        if (!obs.initialized) {
            obs.priceACumulative = cumulativeA;
            obs.priceBCumulative = cumulativeB;
            obs.timestamp = nowTs;
            obs.initialized = true;
            return;
        }

        uint32 elapsed = nowTs - obs.timestamp;
        if (elapsed == 0) revert StaleObservation();

        obs.twapA = (cumulativeA - obs.priceACumulative) / elapsed;
        obs.twapB = (cumulativeB - obs.priceBCumulative) / elapsed;
        obs.priceACumulative = cumulativeA;
        obs.priceBCumulative = cumulativeB;
        obs.timestamp = nowTs;

        emit OracleUpdated(pool, obs.twapA, obs.twapB, nowTs);
    }

    /**
     * @notice Returns latest TWAP quote for provided side.
     * @param pool Pool address.
     * @param amountIn Input amount.
     * @param tokenIn Input token side.
     * @return amountOut TWAP-quoted output amount.
     */
    function consult(address pool, uint256 amountIn, address tokenIn) external view returns (uint256 amountOut) {
        Observation memory obs = observations[pool];
        if (!obs.initialized || obs.twapA == 0 || obs.twapB == 0) revert NotInitialized();

        address tokenA = ILiquidityPool(pool).tokenA();
        if (tokenIn == tokenA) {
            amountOut = (amountIn * obs.twapA) / 1e18;
        } else {
            amountOut = (amountIn * obs.twapB) / 1e18;
        }
    }

    /**
     * @notice Pauses oracle updates.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses oracle updates.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
