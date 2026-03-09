**LiquidityPool**

**Summary**
Constant-product AMM pool for a single token pair with embedded LP ERC20.

**Role In System**
1. Holds reserves for token pair
2. Mints/burns LP shares on add/remove liquidity
3. Executes swaps with fee and invariant checks
4. Maintains cumulative prices for TWAP
5. Supports flash swap callback flow

**Key Features**
1. `MINIMUM_LIQUIDITY` anti-inflation lock
2. Balance-delta input accounting (fee-on-transfer friendly)
3. Protocol fee split routed to treasury
4. `sync()` and `skim()` maintenance methods
5. Factory pause enforcement in critical functions

**Access Control**
1. No owner-only trade logic inside pool
2. Runtime checks rely on factory configuration and pause state

**Upgradeability**
Pool instances are immutable and non-upgradeable by design.
