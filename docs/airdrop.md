# Tenji Airdrop

## Purpose

`TenjiAirdrop` is the distribution contract for the initial `30%` token reserve allocated to the community side of the project.

Its role is intentionally narrow:

- hold the airdrop reserve
- allow eligible users to claim
- prevent duplicate claims
- reject contract-based claim attempts

## Deployment Model

During deployment, the script predicts the future `TenjiAirdrop` address and passes that address into the `TenjiCoin` constructor.

As a result:

- the full `50,100,000,000 TENJI` reserve is minted directly into the airdrop contract
- there is no separate post-deploy funding step
- the contract balance can be verified immediately after deployment

## Claim Rules

Each claim is subject to the following rules:

- one claim per address
- claims stop once `claimedCount >= maxUsers`
- caller must be an EOA
- caller must not be within the cooldown window
- contract balance must still cover `amountPerUser`

If all checks pass, the contract transfers `amountPerUser` tokens to the caller and records the claim.

## Anti-Bot Design

The contract includes a lightweight anti-bot layer:

- `msg.sender.code.length != 0` causes a revert
- repeated claims from the same address are blocked
- a block-based cooldown reduces rapid repetitive attempts

This is a pragmatic protection layer, not a perfect one. It is best understood as friction against simple contract-driven farming, not as a universal Sybil defense.

## Key Parameters

- `token`: ERC-20 token being distributed
- `amountPerUser`: claim size per successful address
- `maxUsers`: maximum successful claims
- `cooldownBlocks`: minimum blocks between repeated attempts from the same address

## Owner Controls

The owner can update only one live parameter:

- `setCooldown(uint256 blocks)`

The owner cannot mint new tokens through the airdrop contract and cannot bypass the one-claim rule.

## Useful Read Functions

- `remainingTokens()`: current token balance held by the airdrop contract
- `canClaim(address user)`: convenience check for frontends and integrations
- `hasClaimed(address user)`: per-address claim status
- `claimedCount()`: number of successful claims

## Operational Notes

- If `amountPerUser * maxUsers` is lower than the full reserve, not all tokens will be distributed in the first campaign.
- If `amountPerUser * maxUsers` is higher than the reserve, the deployment script rejects the configuration.
- Smart wallets and contract accounts may be rejected by design because the contract checks runtime code length.

## Example Balance Check

From Hardhat console:

```js
const { ethers } = await network.connect()
const token = await ethers.getContractAt("TenjiCoin", "0xTOKEN")
const airdrop = await ethers.getContractAt("TenjiAirdrop", "0xAIRDROP")

ethers.formatUnits(await token.balanceOf(await airdrop.getAddress()), 18)
ethers.formatUnits(await airdrop.remainingTokens(), 18)
```

## Intended Role of `AirdropClaimCaller`

`AirdropClaimCaller` is a helper contract used for testing that contract-based calls are rejected.

It is not required for production deployment.
