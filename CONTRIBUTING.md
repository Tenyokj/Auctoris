# Contributing

## Purpose

This repository contains the on-chain core for Tenji:

- `TenjiCoin`
- `TenjiAirdrop`
- deployment scripts
- tests
- GitHub-facing documentation

Contributions should keep that scope clear and avoid adding unrelated protocol logic, frontend code, or speculative features without a strong reason.

## Development Setup

Requirements:

- Node.js `>= 22.10`
- npm

Install dependencies:

```bash
npm install
```

Compile:

```bash
npm run compile
```

Run tests:

```bash
npm test
```

Run coverage:

```bash
npm run coverage
```

## Repository Expectations

Before opening a pull request:

- keep changes scoped to one clear purpose
- update docs when behavior changes
- add or update tests for contract logic changes
- keep deployment scripts consistent with contract changes
- avoid dead config, dead docs, and stale names

## Solidity Style

For Solidity changes:

- prefer simple, explicit logic over clever patterns
- keep public and external interfaces documented with NatSpec
- use custom errors where they improve clarity and gas efficiency
- avoid unnecessary admin powers
- preserve deterministic behavior in deployment-critical flows

## Testing Expectations

If you change:

- token supply logic
- allocation rules
- deployment flow
- claim logic
- ownership behavior

then you should update tests in `test/` accordingly.

Minimum expectation for code changes:

- `npm run compile`
- `npm test`

Preferred expectation for meaningful contract work:

- `npm run coverage`

## Pull Requests

A good PR should include:

- a short description of what changed
- why the change is needed
- any contract or deployment impact
- any documentation updates
- any testing notes

## Security Reports

If you discover a security issue that should not be disclosed publicly, do not open a public exploit write-up in an issue first. Use a maintainer-controlled private contact channel if one is available through the project’s official communication surface.

## Non-Code Contributions

Useful non-code contributions include:

- docs improvements
- consistency fixes
- typo fixes
- README improvements
- deployment guide corrections
- audit-note clarifications

Small clarity improvements are welcome if they reduce confusion for users, reviewers, or future contributors.
