# FlashAlliance Operations

**Daily Operations**
1. Monitor new alliances created via `AllianceFactory`.
2. Track alliance state transitions (`Funding` -> `Acquired` -> `Closed`).
3. Verify critical events: `FundingTargetReached`, `NFTBought`, `SaleExecuted`, `FundingCancelled`, `EmergencyWithdrawn`.
4. Monitor `ProceedsAllocated` / `ProceedsClaimed` to track post-sale settlement.

**Runbook: New Alliance**
1. Ensure participants and shares are correct (sum must be 100).
2. Ensure governance params are correct (`quorumPercent`, `lossSaleQuorumPercent`, `minSalePrice`).
3. Create alliance through factory.
3. Record alliance address and owner/admin address.
4. Record participant quotas from `requiredContribution(address)`.

**Runbook: Funding Failure**
1. Wait until funding deadline passes.
2. Participant calls `cancelFunding`.
3. Each participant calls `withdrawRefund`.

**Runbook: Sale Execution**
1. Seller approves NFT to alliance.
2. Participant buys NFT through `buyNFT`.
3. Participants vote via `voteToSell`.
4. Buyer approves ERC20 to alliance.
5. Participant executes sale via `executeSale`.
6. Participants claim funds via `claimProceeds`.

**Runbook: Emergency Rescue**
1. Participants vote recipient using `voteEmergencyWithdraw`.
2. If proposal expires, call `resetEmergencyProposal` and revote.
3. Once quorum is reached, call `emergencyWithdrawNFT`.

**Observability**
1. Index alliance addresses from `AllianceCreated`.
2. Index voting events with round ids and accumulated weight to show current proposal status.
3. Index `ProceedsAllocated` and `ProceedsClaimed` to expose payout progress.
4. Alert on stalled alliances close to deadline without target reached.
