# Auctoris Operations

## Purpose

This document is the practical operations checklist for running **Auctoris Licensing Authority** like a real protocol rather than a local-only codebase.

## Ownership

For public deployment, do not leave operational control on a single EOA longer than necessary.

Move control of proxy admins to a multisig.

That should be your default production posture.

### Recommended multisig posture

For Auctoris, the clean default is:

1. Safe multisig
2. `2 of 3` signers for early production
3. Separate signer devices and recovery paths

Why this matters:

1. A single EOA is a single point of failure
2. Proxy admin ownership is effectively protocol control
3. Multisig reduces key-loss, key-compromise, and unilateral-upgrade risk

## Upgrade discipline

When preparing an upgrade:

1. Deploy the new implementation
2. Run the full test suite
3. Run storage-layout review manually before upgrading
4. Upgrade through the proxy admin
5. Re-run post-upgrade smoke tests

## Metadata policy

Define a stable metadata policy early.

Decide:

1. Whether metadata is immutable or not
2. Whether asset metadata and license metadata live on IPFS, Arweave, or controlled HTTPS
3. How legal license text is represented and versioned

## Monitoring

Monitor:

1. Purchase success and failure rates
2. Revoke activity
3. Asset and license-type configuration changes
4. Proxy admin ownership changes
5. Unusual signed-order usage patterns

## API operations

If you launch a hosted API:

1. Keep the chain as source of truth
2. Index events into a database
3. Expose normalized read endpoints
4. Reconcile indexed data against direct contract reads
5. Log every API request path that partners depend on

## Partner onboarding

For every new partner, provide:

1. The network name and chain id
2. Registry proxy address
3. Token proxy address
4. ABI or SDK package
5. Example `hasValidLicense` request
6. Example `getLicenseState` request
7. Example webhook or polling strategy if they use your hosted API

## Incident response

Prepare for:

1. Mispriced license terms
2. Wrong metadata
3. Bad signed-order configuration
4. A partner caching stale state
5. The need to revoke or pause quickly

At minimum, define:

1. Who can pause operationally
2. Who can revoke operationally
3. Who controls the proxy admins
4. How partners will be notified of an incident

## Production mindset

The contracts are the protocol.

The SDK, docs, and API are the institution around the protocol.

If you want Auctoris to feel respected, the operational layer has to be as deliberate as the smart contracts themselves.
