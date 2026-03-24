# Tenji Contracts

## Overview

The repository currently centers around three Solidity contracts:

- `TenjiCoin`
- `TenjiAirdrop`
- `AirdropClaimCaller`

There is also `MockERC20` for test scenarios.

## `TenjiCoin`

File: `contracts/TenjiCoin.sol`

Purpose:

- create the main `TENJI` token
- mint the full initial supply once
- expose standard ERC-20 functionality
- allow token burning by holders

Key properties:

- fixed total supply of `167,000,000,000 TENJI`
- fixed launch split of `60B / 20B / 20B / 67B`
- no post-deploy mint function
- no transfer tax
- no blacklist
- no pause logic

Constructor arguments:

- `liquidityWallet`
- `teamWallet`
- `airdropWallet`
- `reserveWallet`

## `TenjiAirdrop`

File: `contracts/TenjiAirdrop.sol`

Purpose:

- hold the airdrop reserve
- distribute fixed-size claims
- block duplicate claims
- reject contract-based callers

Core state:

- `token`
- `amountPerUser`
- `maxUsers`
- `claimedCount`
- `hasClaimed`
- `lastClaimBlock`
- `cooldownBlocks`

Main functions:

- `claim()`
- `remainingTokens()`
- `canClaim(address user)`
- `setCooldown(uint256 blocks)`

Owner powers:

- update cooldown only

## `AirdropClaimCaller`

File: `contracts/AirdropClaimCaller.sol`

Purpose:

- call `claim()` from another contract
- prove that the anti-contract guard works during tests

This contract is a helper, not a required production component.

## `MockERC20`

File: `contracts/MockERC20.sol`

Purpose:

- support unit tests
- provide mintable test balances without using the production token flow

## Architectural Notes

The current architecture is intentionally small.

Benefits:

- easier to inspect
- easier to document
- smaller surface area than feature-heavy meme token contracts

Tradeoff:

- fewer admin controls
- fewer built-in operational safety switches
- no advanced distribution tooling beyond the current airdrop logic
