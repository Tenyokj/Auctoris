# FlashAlliance FAQ

**What is FlashAlliance?**
A lightweight module where a fixed participant group pools ERC20 funds to buy and later sell an NFT.

**Is this integrated with BERT governance?**
No. It is standalone and has local `Ownable` admin controls.

**Can participants be changed after deployment?**
No. Participant list and shares are fixed in constructor.

**How are sale decisions approved?**
By share-weighted voting:
1. Normal price: `quorumPercent` (default 60)
2. Loss price: `lossSaleQuorumPercent` (default 80)

**What happens if target funding is not reached?**
After deadline, a participant can call `cancelFunding`, then everyone withdraws own deposit via `withdrawRefund`.

**Can NFT be rescued if sale is stuck?**
Yes. Use emergency voting + `emergencyWithdrawNFT` once quorum is reached.

**Is FlashAlliance upgradeable?**
No. Contracts are non-upgradeable in current design.
