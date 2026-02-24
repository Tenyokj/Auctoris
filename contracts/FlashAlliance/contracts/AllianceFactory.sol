// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./Alliance.sol";

/// @title AllianceFactory
/// @notice Deploys and tracks Alliance contracts.
/// @dev Each created alliance sets `msg.sender` as admin/owner.
/// @custom:version 1.0.0
contract AllianceFactory {
    /// @notice List of all alliances deployed through this factory.
    Alliance[] public alliances;

    /// @notice Emitted when a new alliance is created.
    /// @param allianceAddress Newly deployed alliance address.
    /// @param token ERC20 token used by the created alliance.
    /// @param admin Admin/owner configured for the new alliance.
    event AllianceCreated(address indexed allianceAddress, address indexed token, address indexed admin);

    /// @notice Deploy a new alliance contract.
    /// @param _targetPrice Required funding amount.
    /// @param _deadline Funding duration in seconds from creation time.
    /// @param _participants Participant list.
    /// @param _shares Participant shares, must sum to 100.
    /// @param _token ERC20 token used for funding/sale payments.
    /// @return allianceAddress Address of newly deployed alliance.
    function createAlliance(
        uint256 _targetPrice,
        uint256 _deadline,
        address[] memory _participants,
        uint256[] memory _shares,
        address _token
    ) external returns (address allianceAddress) {
        require(_participants.length == _shares.length, "Factory: length mismatch");
        require(_token != address(0), "Factory: zero token");

        uint256 sumShares;
        for (uint256 i = 0; i < _shares.length; i++) {
            sumShares += _shares[i];
        }
        require(sumShares == 100, "Factory: shares must sum to 100");

        Alliance alliance = new Alliance(_targetPrice, _deadline, _participants, _shares, _token, msg.sender);
        alliances.push(alliance);

        allianceAddress = address(alliance);
        emit AllianceCreated(allianceAddress, _token, msg.sender);
    }

    /// @notice Returns all alliances created by this factory.
    /// @return List of deployed alliance contract instances.
    function getAllAlliances() external view returns (Alliance[] memory) {
        return alliances;
    }
}
