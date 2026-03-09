**PoolFactory**

**Summary**
Factory for pool creation, pair registry, and global protocol configuration.

**Role In System**
1. Creates one pool per token pair
2. Stores `getPool[tokenA][tokenB]`
3. Stores swap fee and protocol fee config
4. Stores fee receiver and flash limiter
5. Acts as global pause root

**Key Features**
1. Canonical token sorting for duplicate protection
2. Configurable `swapFeeBps` and `protocolFeeBps`
3. Governance/admin hooks for protocol updates
4. Emits pool-creation and config-change events

**Access Control**
1. Owner-only admin setters
2. `whenNotPaused` restrictions for sensitive paths

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
