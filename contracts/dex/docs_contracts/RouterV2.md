**RouterV2**

**Summary**
Route optimizer wrapper over base router execution.

**Role In System**
1. Computes best output across direct and 2-hop routes
2. Delegates execution to `Router`
3. Improves UX for best-path swaps

**Key Features**
1. `getBestPathOut`
2. `swapBestTokensForTokens`
3. Candidate-token based 2-hop search

**Access Control**
1. Owner-controlled pause/unpause
2. Factory pause checks before execution

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
