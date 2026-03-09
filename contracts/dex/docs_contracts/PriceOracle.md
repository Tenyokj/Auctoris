**PriceOracle**

**Summary**
TWAP oracle built from pool cumulative price observations.

**Role In System**
1. Stores observation snapshots
2. Calculates TWAP for integrations
3. Avoids direct spot-price manipulation issues

**Key Features**
1. `update(pool)`
2. `consult(pool, amountIn, tokenIn)`
3. Minimum-interval and stale-data guards

**Access Control**
1. Owner-controlled pause/unpause
2. Observation updates blocked when paused

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
