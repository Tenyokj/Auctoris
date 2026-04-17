# Auctoris Licensing Model

## v1 asset model

For Auctoris v1, the recommended asset categories are:

1. `background_track`
2. `podcast_pack`
3. `beat_pack`
4. `sample_pack`
5. `audio_loop_pack`

At the smart-contract level, the protocol remains generic.

But at the product and frontend layer, these categories give you a much cleaner catalog and much stronger messaging.

## Asset metadata expectations

Each asset should eventually carry metadata that clearly describes:

1. Asset title
2. Creator name
3. Category
4. Audio duration or pack size
5. Preview URL
6. Cover artwork
7. Canonical license summary
8. Full legal terms URL or content reference

## Recommended v1 license tiers

The recommended first commercial tiers are:

1. `Creator`
2. `Commercial`
3. `Agency`
4. `Enterprise`

An optional subscription-like tier can also exist:

1. `Commercial 30d`
2. `Commercial 365d`

## Tier meaning

### Creator

Use for individual creators with basic monetized usage.

Good for:

1. Solo YouTube channels
2. Small podcasts
3. Independent social content creators

### Commercial

Use for broader monetized or business usage.

Good for:

1. Small brands
2. Freelancers creating paid client content
3. Small media teams

### Agency

Use for multi-client production environments.

Good for:

1. Agencies
2. Studios
3. Teams producing content for several brands

### Enterprise

Use for high-trust negotiated usage.

Good for:

1. Large organizations
2. Managed procurement flows
3. Custom pricing and rights packages

## Suggested on-chain mapping

At the product level, each asset should have several license types under it.

Example:

1. Asset `1` = `Podcast Intro Pack Vol. 1`
2. License type `0` = `Creator`
3. License type `1` = `Commercial`
4. License type `2` = `Agency`
5. License type `3` = `Enterprise`

Each of those becomes a distinct token id in the protocol.

## Transferability recommendation

For most Auctoris v1 creator-audio licenses:

1. Default to `non-transferable`
2. Treat the token as a license key, not a collectible

Transferable licenses may be useful later for:

1. Resale-enabled rights markets
2. Secondary trading experiments
3. Special commercial packages

But the default professional posture should be non-transferable.

## Duration recommendation

For the first product release:

1. Use perpetual licenses for most one-time purchase tiers
2. Use fixed-duration licenses for subscription-style products

That gives you a clean split between:

1. Permanent commercial rights products
2. Renewable access products

## Marketplace recommendation

When presenting these licenses on the future frontend, focus less on "NFT" language and more on:

1. License
2. Usage tier
3. Commercial rights
4. On-chain verification

That framing will feel more professional and easier for mainstream users to trust.
