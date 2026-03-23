# Tenji FAQ

## What is Tenji?

Tenji is a meme token project built around the idea of the late trader. Its mascot is a turtle that understands the market, but always reacts too slowly.

## Why a turtle?

Because the turtle captures a specific crypto feeling: watching the move, thinking about the move, and acting after the best moment has already passed.

## Is Tenji a serious protocol or a meme project?

It is a meme project with a real on-chain implementation. The culture is meme-first, but the contracts, deployment, and documentation are meant to be inspectable and concrete.

## What standard does the token use?

`TenjiCoin` is an ERC-20 token.

## What is the symbol?

`TENJI`

## Can more tokens be minted later?

No. The current token contract mints the full supply during deployment and does not expose a post-deploy mint function.

## Does the token charge transfer fees?

No. TenjiCoin has no transfer tax or fee logic.

## Can holders burn tokens?

Yes. The token includes burn support.

## How much supply exists?

`167,000,000,000 TENJI`

## How is the supply split initially?

- `60%` liquidity
- `10%` team
- `30%` airdrop

## Does the airdrop contract really hold the full reserve?

Yes. The deployment script predicts the future airdrop address and mints the full reserve directly into `TenjiAirdrop`.

## Why might the claim campaign be smaller than the full reserve?

Because the reserve and the active campaign are different things. The reserve is fixed at `50,100,000,000 TENJI`, but the current campaign size is defined by `amountPerUser * maxUsers`.

## Why can contracts not claim the airdrop?

The current design tries to reduce simple bot farming and multi-step contract claim flows by rejecting contract callers.

## Will smart wallets work?

Not necessarily. The current anti-contract logic may reject some smart-wallet patterns by design.

## Is the project audited?

Not at the moment, unless a public external audit is later published.

## Where will the full user-facing docs live?

The long-form user experience is intended for the website. This repository keeps the markdown reference set for GitHub and technical transparency.
