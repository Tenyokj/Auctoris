# Tenji Tokenomics

## Overview

TenjiCoin is designed as a fixed-supply meme token with a simple distribution model and no hidden token mechanics.

- Token: `TenjiCoin`
- Symbol: `TENJI`
- Decimals: `18`
- Total supply: `167,000,000,000 TENJI`
- Post-deploy minting: not available
- Transfer tax: none
- Burn support: yes

## Initial Supply Allocation

- Liquidity: `60,000,000,000 TENJI` or about `35.93%`
- Team: `20,000,000,000 TENJI` or about `11.98%`
- Airdrop reserve: `20,000,000,000 TENJI` or about `11.98%`
- Reserve for marketing and future liquidity: `67,000,000,000 TENJI` or about `40.12%`

These allocations are enforced at deployment by the `TenjiCoin` constructor.

## Supply Properties

- Supply is minted once at deployment.
- There is no owner mint function.
- There is no inflation schedule.
- There is no rebase logic.
- There is no tax or fee on transfers.
- Holders can burn their own tokens through the burnable ERC-20 extension.

## Airdrop Reserve

The full `20,000,000,000 TENJI` airdrop reserve is minted directly into the `TenjiAirdrop` contract during deployment.

That means:

- the airdrop pool exists on-chain from day one
- the reserve does not depend on a later manual transfer
- users can verify the balance of the airdrop contract directly

## Campaign Parameters

The reserve and the active campaign are related, but not identical.

The reserve is always `20,000,000,000 TENJI`.

The currently claimable portion depends on:

- `amountPerUser`
- `maxUsers`

Their product defines how many tokens the current campaign can distribute:

`claimable campaign size = amountPerUser * maxUsers`

The current intended campaign uses:

- `200,000 TENJI` per user
- `100,000` maximum users

That configuration consumes the full `20,000,000,000 TENJI` airdrop reserve.

## Strategic Reserve

The remaining `67,000,000,000 TENJI` is held in a dedicated reserve wallet.

Its intended role is to support:

- future liquidity additions
- marketing and growth campaigns
- ecosystem operations
- strategic treasury decisions

This reserve is part of the fixed initial supply. It is not future minting.

## Economic Philosophy

Tenji is intentionally simple.

It does not try to hide tokenomics behind complex emissions, auto-liquidity features, tax gimmicks, or admin-heavy controls. The design favors transparency over cleverness:

- fixed supply
- visible allocation
- simple ERC-20 behavior
- explicit airdrop reserve
- explicit strategic reserve

## What Tokenomics Does Not Promise

- guaranteed price appreciation
- guaranteed liquidity depth
- guaranteed exchange listings
- guaranteed buyback behavior
- guaranteed staking or yield programs

Tenji is a meme project with a clear narrative, not a yield machine disguised as culture.
