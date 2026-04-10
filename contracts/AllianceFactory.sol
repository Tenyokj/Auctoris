// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./Alliance.sol";

/**
 * @title AllianceFactory
 * @notice Deploys and tracks Alliance contracts.
 * @dev Each created alliance sets `msg.sender` as admin/owner.
 * @custom:version 1.1.0
 */
contract AllianceFactory {
    /**
     * @notice List of all alliances deployed through this factory.
     */
    Alliance[] public alliances;

    /**
     * @notice Quick membership check for factory-created alliances.
     */
    mapping(address => bool) public isAlliance;

    /**
     * @notice Index of alliances by admin address.
     */
    mapping(address => address[]) private alliancesByAdmin;

    /**
     * @notice Index of alliances by participant address.
     */
    mapping(address => address[]) private alliancesByParticipant;

    /**
     * @notice Emitted when a new alliance is created.
     * @param allianceAddress Newly deployed alliance address.
     * @param token ERC20 token used by the created alliance.
     * @param admin Admin/owner configured for the new alliance.
     * @param targetPrice Required funding amount.
     * @param minSalePrice Sale threshold for standard quorum.
     * @param quorumPercent Base quorum.
     * @param lossSaleQuorumPercent Loss-sale quorum.
     */
    event AllianceCreated(
        address indexed allianceAddress,
        address indexed token,
        address indexed admin,
        uint256 targetPrice,
        uint256 minSalePrice,
        uint256 quorumPercent,
        uint256 lossSaleQuorumPercent
    );

    /**
     * @notice Deploy a new alliance contract.
     * @param _targetPrice Required funding amount.
     * @param _deadline Funding duration in seconds from creation time.
     * @param _participants Participant list.
     * @param _shares Participant shares, must sum to 100.
     * @param _token ERC20 token used for funding/sale payments.
     * @param _quorumPercent Quorum required for acquisition, emergency withdrawal, and normal sale.
     * @param _lossSaleQuorumPercent Quorum required for a sale below `_minSalePrice`.
     * @param _minSalePrice Sale threshold separating normal and loss sale quorums.
     * @return allianceAddress Address of newly deployed alliance.
     */
    function createAlliance(
        uint256 _targetPrice,
        uint256 _deadline,
        address[] memory _participants,
        uint256[] memory _shares,
        address _token,
        uint256 _quorumPercent,
        uint256 _lossSaleQuorumPercent,
        uint256 _minSalePrice
    ) external returns (address allianceAddress) {
        require(_participants.length == _shares.length, "Factory: length mismatch");
        require(_token != address(0), "Factory: zero token");
        require(_quorumPercent > 0 && _quorumPercent <= 100, "Factory: bad quorum");
        require(
            _lossSaleQuorumPercent >= _quorumPercent && _lossSaleQuorumPercent <= 100,
            "Factory: bad loss quorum"
        );
        require(_minSalePrice > 0, "Factory: bad min sale");

        uint256 sumShares;
        for (uint256 i = 0; i < _shares.length; i++) {
            sumShares += _shares[i];
        }
        require(sumShares == 100, "Factory: shares must sum to 100");

        Alliance alliance = new Alliance(
            _targetPrice,
            _deadline,
            _participants,
            _shares,
            _token,
            msg.sender,
            _quorumPercent,
            _lossSaleQuorumPercent,
            _minSalePrice
        );
        alliances.push(alliance);

        allianceAddress = address(alliance);
        isAlliance[allianceAddress] = true;
        alliancesByAdmin[msg.sender].push(allianceAddress);

        for (uint256 i = 0; i < _participants.length; i++) {
            alliancesByParticipant[_participants[i]].push(allianceAddress);
        }

        emit AllianceCreated(
            allianceAddress,
            _token,
            msg.sender,
            _targetPrice,
            _minSalePrice,
            _quorumPercent,
            _lossSaleQuorumPercent
        );
    }

    /**
     * @notice Returns all alliances created by this factory.
     * @return List of deployed alliance contract instances.
     */
    function getAllAlliances() external view returns (Alliance[] memory) {
        return alliances;
    }

    /**
     * @notice Returns all alliance addresses created by the provided admin.
     * @param admin Admin address.
     * @return List of alliance addresses.
     */
    function getAlliancesByAdmin(address admin) external view returns (address[] memory) {
        return alliancesByAdmin[admin];
    }

    /**
     * @notice Returns all alliance addresses that include the provided participant.
     * @param participant Participant address.
     * @return List of alliance addresses.
     */
    function getAlliancesByParticipant(address participant) external view returns (address[] memory) {
        return alliancesByParticipant[participant];
    }

    /**
     * @notice Returns total number of alliances created through the factory.
     * @return Number of deployed alliance instances.
     */
    function allAlliancesCount() external view returns (uint256) {
        return alliances.length;
    }
}
