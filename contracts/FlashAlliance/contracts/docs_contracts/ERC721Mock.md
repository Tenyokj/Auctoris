# ERC721Mock

**Summary**
Test-only ERC721 used by FlashAlliance tests and local simulations.

**Role In System**
Helper contract for exercising `buyNFT`, voting, and settlement flows.

**Key Features**
1. Open `mint(address,uint256)` for quick test setup.
2. Minimal ERC721 behavior with no business-specific restrictions.

**Security Note**
Not for production usage as-is because mint is unrestricted.
