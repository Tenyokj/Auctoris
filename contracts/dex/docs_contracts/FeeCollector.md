**FeeCollector**

**Summary**
Protocol treasury module for collecting and withdrawing fee assets.

**Role In System**
1. Receives protocol fees from pools
2. Allows owner withdrawals and emergency flow

**Key Features**
1. Single and batch ERC20 withdraw
2. Explicit balance checks and custom errors
3. Pause-aware emergency behavior

**Access Control**
1. Owner-only admin actions
2. Regular withdraw flow restricted by pause policy

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
