**Security Overview**

**Contents**
1. Security Model
2. Runtime Protections
3. Upgrade Protections
4. Governance and Admin Risk
5. Known Tradeoffs
6. Recommended Practices

**Security Model**
1. Protocol follows AMM best practices for testnet usage
2. Critical paths use OpenZeppelin guards and safe token ops
3. Router and pool enforce deadline/slippage boundaries

**Runtime Protections**
1. `ReentrancyGuard` for critical mutative flows
2. `SafeERC20` for token transfers
3. `PausableUpgradeable` for emergency shutdown
4. Factory pause propagated to router and pools
5. Flash swap amount bounded by optional limiter

**Upgrade Protections**
1. Transparent proxy pattern via OpenZeppelin
2. Per-proxy `ProxyAdmin` ownership checks
3. Storage gaps in all upgradeable contracts
4. Upgrade script verifies EIP-1967 slots after tx

**Governance and Admin Risk**
1. Admin can change fee parameters and pause system
2. Timelock in governance reduces sudden-parameter risk
3. ProxyAdmin key compromise is critical risk

**Known Tradeoffs**
1. System targets Sepolia and developer workflows
2. Not optimized for mainnet MEV-hardening
3. Route optimization is limited to direct and 2-hop paths

**Recommended Practices**
1. Use multisig for owner and ProxyAdmin control
2. Enforce delay for sensitive config changes
3. Track reserve anomalies and failed tx rate
4. Rehearse upgrades on localhost and Sepolia first
