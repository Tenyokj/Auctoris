**DEXGovernance**

**Summary**
Timelock governance executor for protocol-level admin actions.

**Role In System**
1. Queues sensitive factory updates with delay
2. Executes queued actions after ETA
3. Supports cancellation before execution

**Key Features**
1. Timelocked fee updates
2. Timelocked pause and limiter updates
3. Action hash tracking for replay protection

**Access Control**
1. Owner-only queue/execute/cancel
2. Pausable governance action paths

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
