# FlashAlliance Architecture

**Contents**
1. System Components
2. Lifecycle
3. Data Model
4. Access Control
5. Voting and Quorum
6. Failure and Emergency Paths
7. Diagram

**System Components**
1. `AllianceFactory` deploys and tracks alliance instances.
2. `Alliance` manages funding, NFT acquisition, sale voting, and proceeds distribution.
3. `FATK` is an ERC20 used for funding and settlement.
4. `ERC721Mock` is a test helper NFT contract.

**Lifecycle**
1. `Funding`:
   Participants deposit ERC20 up to `targetPrice` before `deadline`.
2. `Acquired`:
   NFT is purchased when funding target is reached.
3. `Closed`:
   Final state after sale execution, emergency withdrawal, or failed funding cancellation.

**Data Model**
1. Participant set and fixed shares are immutable after deployment.
2. Deposits are tracked in `contributed[address]`.
3. Sale proposal data is tracked in `proposedBuyer`, `proposedPrice`, `proposedSaleDeadline`.
4. Voting weight is share-based (`sharePercent[address]`).

**Access Control**
1. `Ownable` owner (admin) can pause/unpause.
2. `onlyParticipant` gates business actions.
3. Sale/emergency decisions are participant-vote based.

**Voting and Quorum**
1. Normal sale (`price >= minSalePrice`) requires `quorumPercent` (default 60).
2. Loss sale (`price < minSalePrice`) requires `lossSaleQuorumPercent` (default 80).
3. Emergency withdrawal requires `quorumPercent`.

**Failure and Emergency Paths**
1. If target is not reached by deadline, any participant can call `cancelFunding`.
2. Participants reclaim own deposits via `withdrawRefund`.
3. In `Acquired`, participants can vote an emergency recipient and transfer NFT out.

**Diagram**
```text
Participants
   | (deposit ERC20)
   v
Alliance (Funding) ----> cancelFunding ----> Closed + withdrawRefund
   |
   | buyNFT (when target reached)
   v
Alliance (Acquired)
   |                       \
   | voteToSell + executeSale \ voteEmergencyWithdraw + emergencyWithdrawNFT
   v                           v
Closed (proceeds split)       Closed (NFT rescued)
```
