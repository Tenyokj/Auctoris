# Tenji Litepaper

## Abstract

Tenji is a meme token built around a familiar crypto truth: most traders are late.

The market moves fast, narratives rotate faster, and execution punishes hesitation. Tenji turns that shared pain into identity. The turtle mascot is not a symbol of ignorance. It is a symbol of delayed action, emotional timing, and the experience of watching the move happen just before you click.

TenjiCoin gives that idea an on-chain form through a fixed-supply ERC-20 token, a publicly visible airdrop reserve, a strategic reserve wallet, and a deliberately simple architecture.

## The Problem

Crypto culture often celebrates the fastest traders, the earliest buyers, and the people who somehow always catch the cleanest setup. That is not how most people actually experience the market.

Most participants know the pattern:

- they wait too long to buy
- they hold too long to sell
- they hesitate during panic
- they watch the move happen without them

Tenji speaks to that audience directly.

## The Tenji Character

Tenji is a turtle living inside the blockchain.

It watches price action, studies the chart, and tries to act rationally. But every action comes one step too late:

- when price has already pumped, Tenji decides to buy
- when the market starts dropping, Tenji still thinks there is more time
- when speed matters most, Tenji becomes a mirror for the trader who froze

Tenji is not the hero of perfect execution.
Tenji is the mascot of delayed conviction.

## Product Scope

The first version of the Tenji repository focuses on a minimal and inspectable on-chain base:

- `TenjiCoin` as the main token
- `TenjiAirdrop` as the initial distribution contract
- deployment and verification scripts
- unit tests and repository docs

This is enough to establish:

- token identity
- supply rules
- initial allocation
- airdrop mechanics
- public technical transparency

## Design Principles

## 1. Simplicity over gimmicks

Tenji does not rely on transfer taxes, reflection mechanics, or hidden token tricks.

## 2. Visible supply

The entire supply is minted once during deployment and can be tracked on-chain.

## 3. Cultural clarity

The project is not pretending to be a general-purpose infrastructure protocol. It is a meme token with a strong narrative identity and a lightweight technical core.

## 4. Operational transparency

The repository includes deployment logic, tests, and markdown documentation so the project can be inspected outside the website.

## Token Model

TenjiCoin has a fixed total supply of `167,000,000,000 TENJI`.

Initial allocation:

- `60,000,000,000 TENJI` to liquidity
- `20,000,000,000 TENJI` to team
- `20,000,000,000 TENJI` to airdrop
- `67,000,000,000 TENJI` to reserve for future liquidity, marketing, and operations

The token supports burning by holders, but it does not support additional minting after deployment.

## Airdrop Model

The airdrop contract is designed for a straightforward distribution phase:

- one claim per address
- EOA-only claim path
- configurable cooldown in blocks
- owner-controlled cooldown updates
- no hidden distribution math

The full `20,000,000,000 TENJI` airdrop reserve is minted directly into the airdrop contract during deployment.

## Security Position

Tenji favors a smaller feature set to reduce attack surface, but simple does not mean risk-free.

Current boundaries:

- the project should be treated as unaudited unless an external audit is completed
- the anti-bot logic is practical, not perfect
- owner permissions are intentionally minimal, but they still exist
- users should read the contracts before interacting

## Cultural Thesis

Tenji is not trying to outsmart crypto.
It is trying to describe it honestly.

The token is built around an emotional truth many people recognize immediately: being late does not stop people from coming back. The market moves without mercy, but participation keeps returning. Tenji is a meme for that persistence.

## Near-Term Goal

The near-term goal is simple:

- ship a clean token and airdrop core
- publish understandable docs
- build the website and public-facing identity
- grow the meme through culture, design, and community participation

## Long-Term Direction

If the Tenji identity resonates, the project can expand into broader community experiences, content, and ecosystem touchpoints. But the first responsibility is to make the core understandable and transparent.
