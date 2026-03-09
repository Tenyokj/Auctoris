**FlashLoanLimiter**

**Summary**
Safety policy module for limiting flash swap output size.

**Role In System**
1. Applies max-out percentage bounds
2. Supports global defaults and per-pool overrides

**Key Features**
1. `defaultMaxOutBps`
2. `poolMaxOutBps[pool]`
3. Validation hook callable by pools

**Access Control**
1. Owner-only configuration updates
2. Pause support for emergency disable

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
