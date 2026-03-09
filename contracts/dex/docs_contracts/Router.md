**Router**

**Summary**
User-facing execution layer for liquidity operations and routed swaps.

**Role In System**
1. Handles token and ETH liquidity entry/exit
2. Executes single-hop and multi-hop swaps
3. Enforces deadlines and output constraints

**Key Features**
1. `addLiquidity` and `addLiquidityETH`
2. `removeLiquidity` and `removeLiquidityETH`
3. `swapExactTokensForTokens`
4. `swapExactETHForTokens` and `swapExactTokensForETH`
5. Quote helpers: `getAmountsOut`

**Access Control**
1. Owner-controlled pause/unpause
2. Checks factory pause before execution

**Upgradeability**
Transparent proxy compatible with initializer and storage gap.
