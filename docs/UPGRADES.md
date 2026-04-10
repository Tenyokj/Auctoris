# FlashAlliance Upgrade Policy

**Current model**
FlashAlliance contracts are deployed as non-upgradeable contracts.

**Implications**
1. No proxy admin and no implementation upgrades.
2. Bug fixes or logic changes require deploying new contract instances.
3. Existing alliance instances keep original behavior forever.

**Migration Strategy**
1. Deploy new contract version.
2. Create new alliances via updated factory.
3. For active old alliances, complete lifecycle under old logic.
4. Do not force-migrate funds/NFTs unless explicit migration logic exists.
