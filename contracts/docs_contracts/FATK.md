# Flash Alliance Token 

**Summary**
ERC20 token used in FlashAlliance for funding, sale settlement, and payout distribution.

**Key Features**
1. Standard ERC20 transfers.
2. Burnable extension.
3. Permit (`EIP-2612`) approvals.
4. Owner-only mint.
5. Owner-only pause/unpause.

**Access Control**
1. `onlyOwner` for `mint`, `pause`, `unpause`.

**Main Functions**
1. `mint(address,uint256)`
2. `pause()`
3. `unpause()`

**Notes**
Pause affects transfer paths through ERC20Pausable `_update` hook.
