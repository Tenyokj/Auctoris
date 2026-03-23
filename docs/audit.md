# Tenji Audit Status

## Current Status

As of March 23, 2026, this repository has not undergone a public third-party security audit.

That means:

- the contracts are reviewable
- the tests are present
- the CI workflow can run compile, test, and coverage
- but there is no external audit report included in this repository at this time

## What Has Been Done Internally

The current repository includes:

- unit tests for `TenjiCoin`
- unit tests for `TenjiAirdrop`
- deployment-script validation checks
- NatSpec and markdown documentation
- GitHub Actions CI configuration

These measures improve transparency and reduce obvious regressions, but they are not a substitute for an independent audit.

## Audit Scope That Would Matter Most

If an external audit is commissioned, the highest-priority review areas would likely be:

- `TenjiCoin` fixed-supply and allocation correctness
- deployment flow that predicts and pre-mints to the future airdrop address
- `TenjiAirdrop` claim restrictions and anti-bot rules
- owner powers and configuration boundaries
- failure cases around claim exhaustion and funding assumptions

## Known Design Boundaries

The current system is intentionally simple, but auditors and reviewers should still note:

- the airdrop anti-bot guard is practical, not perfect
- contract-based callers are rejected by design
- smart-wallet compatibility may be limited
- cooldown is owner-controlled
- there is no pause mechanism
- there is no post-deploy mint function

## Recommended Public Positioning

Until an external audit exists, the safest public claim is:

"The contracts are open-source, documented, and tested, but unaudited."

That statement is accurate and avoids overstating security guarantees.

## If an Audit Is Added Later

When an audit is completed, this file should be updated with:

- auditor name
- audit date
- scope of reviewed contracts
- report link
- summary of findings
- remediation status
