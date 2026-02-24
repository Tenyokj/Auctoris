# FlashAlliance Security Notes

**Threat Model**
1. Participants are semi-trusted and can coordinate voting.
2. Owner/admin is trusted for pause controls.
3. External token/NFT contracts are trusted only by interface assumptions.

**Built-in Protections**
1. `ReentrancyGuard` on sensitive state-changing paths.
2. `SafeERC20` wrappers for token transfers.
3. `safeTransferFrom` for NFT transfers.
4. Share sum validation (`== 100`) at construction.
5. Participant-only gating on core actions.

**Known Trust Assumptions**
1. Admin can pause and unpause operations.
2. Participants are fixed at deployment (no dynamic membership management).
3. ERC20 token and NFT contracts behave according to standards.

**Operational Recommendations**
1. Use multisig as alliance admin for production.
2. Pre-verify participant list and shares before deployment.
3. Add monitoring for deadline and proposal expiry.
4. Prefer audited token/NFT contracts in non-test environments.
