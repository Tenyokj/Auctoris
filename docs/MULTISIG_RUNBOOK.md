# Auctoris Multisig Runbook

## Purpose

This document explains how Auctoris should handle upgrade authority once the protocol moves beyond pure developer testing.

## Why multisig matters

The owner of each `ProxyAdmin` effectively controls protocol upgrades.

That means a single EOA owner is a single point of failure.

Using a multisig reduces:

1. Key-loss risk
2. Key-compromise risk
3. Unilateral-upgrade risk
4. Operational fragility

## Recommended setup

For Auctoris early production:

1. Use a Safe multisig
2. Use `2 of 3` signers
3. Keep signers on separate devices and recovery paths

## Current proxy-admin model

The current deployment wrapper creates:

1. One `ProxyAdmin` for the registry proxy
2. One `ProxyAdmin` for the token proxy

Both should eventually be transferred to the Safe.

## Transfer ownership to Safe

Set environment values:

```bash
SAFE_MULTISIG_ADDRESS=0xYourSafe
PROXY_ADMIN_SCOPE=all
```

Then run:

```bash
npm run ops:transfer-safe:sepolia
```

This script:

1. Loads `deployments/sepolia.json`
2. Finds the Auctoris registry and token `ProxyAdmin` addresses
3. Transfers ownership from the current signer to the Safe

## Prepare or execute an upgrade

Set:

```bash
UPGRADE_TARGET=registry
UPGRADE_CALLDATA=0x
```

Then run:

```bash
npm run ops:upgrade:sepolia
```

Behavior:

1. A new implementation is deployed
2. If the current signer still owns the `ProxyAdmin`, the upgrade executes directly
3. If the `ProxyAdmin` is already owned by the Safe, the script prints the exact Safe payload:

1. `to`
2. `value`
3. `data`

That payload can then be submitted through Safe.

## Operational recommendation

Use this order:

1. Deploy to Sepolia with an EOA
2. Validate the protocol and smoke-test it
3. Transfer both `ProxyAdmin` contracts to Safe
4. Use Safe-driven upgrades from that point onward
