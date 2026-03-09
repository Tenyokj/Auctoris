**Architecture Overview**

**Contents**
1. System Flow
2. Core Modules
3. Core Responsibilities
4. Data Flow
5. Access and Trust Boundaries
6. Upgradeability Model
7. Diagram (ASCII)

**System Flow**
1. User sends action to `Router` or `RouterV2`
2. Router resolves pools through `PoolFactory`
3. `LiquidityPool` executes add/remove/swap logic
4. Pool updates reserves and cumulative prices
5. Protocol fee is routed to `FeeCollector`
6. `PriceOracle` consumes cumulative data for TWAP
7. `DEXGovernance` changes admin parameters with timelock

**Core Modules**
1. Core: `PoolFactory`, `LiquidityPool`, `Router`, `RouterV2`
2. Governance: `DEXGovernance`, `DEXTransparentProxyFactory`
3. Treasury and Oracle: `FeeCollector`, `PriceOracle`
4. Extensions: `FlashLoanLimiter`, `LiquidityMining`
5. Shared: interfaces and `DEXErrors`

**Core Responsibilities**
1. `PoolFactory` creates pools and stores global fee/pause config
2. `LiquidityPool` stores reserves and executes AMM math
3. `Router` provides user-friendly add/remove/swap methods
4. `RouterV2` selects best direct or 2-hop path
5. `FeeCollector` receives protocol fee share
6. `PriceOracle` exposes TWAP quote API

**Data Flow**
1. Factory stores pool registry and protocol config
2. Pools store reserves, LP balances, TWAP cumulatives
3. Router stores no long-term market state
4. Treasury stores collected fees
5. Governance stores queued actions and ETA

**Access and Trust Boundaries**
1. `OwnableUpgradeable` protects admin functions
2. `PausableUpgradeable` protects emergency paths
3. Pool critical methods also check factory pause status
4. Upgrade rights are controlled by per-proxy `ProxyAdmin`

**Upgradeability Model**
1. `PoolFactory`, `Router`, `RouterV2`, `FeeCollector`, `PriceOracle`, `FlashLoanLimiter`, `DEXGovernance` are upgradeable
2. `LiquidityPool` pair contracts are immutable (non-upgradeable instances)
3. Upgradeable contracts keep storage gaps for future versions

**Diagram (ASCII)**
```text
User
  |
  v
Router / RouterV2
  |
  v
PoolFactory -----> LiquidityPool(s)
  |                    |
  |                    +--> FeeCollector
  |                    +--> PriceOracle (cumulative source)
  |
  +--> global config (fees, pause, limiter)

DEXGovernance (timelock) --> PoolFactory admin actions
```
