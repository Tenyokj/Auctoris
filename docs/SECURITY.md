# Tenji Security

## Current Security Posture

The Tenji contracts are intentionally small and simple, but they should still be treated as unaudited software unless an external audit is completed.

The main security advantage of the current design is limited scope:

- no upgradeability
- no post-deploy mint function
- no transfer tax logic
- no reflection or rebasing
- no DEX router complexity inside the token

## Trust Assumptions

Users should understand the following trust boundaries:

- `TenjiCoin` does not expose privileged minting after deployment
- `TenjiAirdrop` owner can update the cooldown value
- the owner does not control user claim history or token balances directly
- deployment parameters matter because they shape initial distribution

## Important Invariants

The design relies on these invariants:

- total token supply is fixed at deployment
- initial allocation is split into liquidity, team, airdrop, and reserve wallets
- the `20,000,000,000 TENJI` airdrop reserve is minted directly into `TenjiAirdrop`
- each address can claim only once
- airdrop claims fail when the pool no longer covers `amountPerUser`

## Known Limitations

## 1. Anti-bot checks are practical, not perfect

The airdrop blocks contract callers by checking `msg.sender.code.length`.

This helps against simple contract wrappers, but it is not a universal Sybil defense and may exclude some smart-wallet users.

## 2. Cooldown is owner-controlled

The owner can change `cooldownBlocks`. This is intentionally narrow admin power, but it still affects claim behavior.

## 3. No pause switch

The current contracts do not implement a pause mechanism. Simplicity reduces complexity, but it also means emergency controls are limited.

## 4. No on-chain vesting for team allocation

The `20,000,000,000 TENJI` team allocation is minted directly to the configured wallet. If vesting is desired, it must be handled operationally or by future tooling outside the current contracts.

## 5. Reserve wallet is operationally sensitive

The `67,000,000,000 TENJI` reserve is minted directly to the configured reserve wallet. That wallet is intended for future liquidity, marketing, and ecosystem operations, so its custody and disclosure matter operationally even though the token contract itself exposes no admin mint path.

## Operational Recommendations

- keep deployer keys private and out of version control
- use a dedicated deployer for live networks
- verify deployed contracts on the target explorer
- publish deployed addresses clearly
- review airdrop parameters before deployment
- test the full deployment flow on Sepolia before any production-style launch

## User Recommendations

- confirm token and airdrop addresses from official project channels
- check the airdrop contract balance on-chain
- verify that `amountPerUser` and `maxUsers` make sense for the intended campaign
- do not assume smart wallets are supported by the current claim restrictions

## Scope of This Document

This document describes the current repository state only. It is not a formal audit report and does not replace independent review.
