**LiquidityMining**

**Summary**
LP staking rewards module using `accRewardPerShare` accounting.

**Role In System**
1. Accepts LP deposits
2. Streams reward token emissions
3. Handles claim and withdraw flows

**Key Features**
1. `deposit`, `withdraw`, `claim`
2. `pendingRewards`
3. Configurable `rewardPerSecond`

**Access Control**
1. Owner-only parameter updates
2. Pause controls for emergency stop

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
