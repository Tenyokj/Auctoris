// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ITenjiAirdrop
 * @notice Minimal interface for calling the Tenji airdrop claim function.
 */
interface ITenjiAirdrop {
    /**
     * @notice Claims the configured airdrop allocation for the caller.
     */
    function claim() external;
}

/**
 * @title AirdropClaimCaller
 * @notice Helper contract used to call `TenjiAirdrop.claim()` from a contract context.
 * @dev Mainly useful for tests that verify contract-based claim attempts are rejected.
 * @custom:author @Tenyokj | https://tenyokj.vercel.app
 */
contract AirdropClaimCaller {
    /**
     * @notice Attempts to claim tokens from the target airdrop contract
     * @param airdrop Address of the deployed Tenji airdrop contract
     */
    function claimFromContract(address airdrop) external {
        ITenjiAirdrop(airdrop).claim();
    }
}
