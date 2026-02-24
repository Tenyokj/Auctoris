// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title ERC721Mock
/// @notice Test-only ERC721 used in FlashAlliance test scenarios.
/// @dev Anyone can mint arbitrary token ids.
/// @custom:version 1.0.0
contract ERC721Mock is ERC721 {
    /// @notice Optional counter field for test experiments.
    uint256 public tokenIdCounter;

    /// @notice Deploy mock collection.
    /// @param name Token name.
    /// @param symbol Token symbol.
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /// @notice Mint a token to an address.
    /// @dev Intended only for tests; no access control is enforced.
    /// @param to Recipient address.
    /// @param tokenId Token id to mint.
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
