// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Alliance
 * @notice Collective NFT acquisition and sale contract funded with a custom ERC20 token.
 * @dev Participants fund a target amount, execute OTC NFT purchase, vote sale parameters, and split proceeds by fixed shares.
 * @custom:version 1.1.0
 */
contract Alliance is Ownable, ReentrancyGuard, IERC721Receiver, Pausable {
    using SafeERC20 for IERC20;

    /* ========== TYPES ========== */

    /**
     * @notice Lifecycle stages of the alliance.
     */
    enum State {
        Funding,
        Acquired,
        Closed
    }

    /* ========== CONSTANTS ========== */

    /**
     * @notice Basis for participant percentage shares.
     */
    uint256 public constant SHARES_SUM = 100;

    /* ========== CORE STATE ========== */

    /**
     * @notice ERC20 token used for funding, settlement, and payouts.
     */
    IERC20 public immutable token;

    /**
     * @notice Current alliance state.
     */
    State public state;

    /**
     * @notice NFT contract address once an asset is acquired.
     */
    address public nftAddress;

    /**
     * @notice NFT token id once an asset is acquired.
     */
    uint256 public tokenId;

    /**
     * @notice Required funding amount to be able to buy the NFT.
     */
    uint256 public immutable targetPrice;

    /**
     * @notice Total amount deposited by all participants.
     */
    uint256 public totalDeposited;

    /**
     * @notice Funding deadline as a unix timestamp.
     */
    uint256 public immutable deadline;

    /**
     * @notice Quorum percentage required to approve a normal sale and acquisition.
     */
    uint256 public immutable quorumPercent;

    /**
     * @notice Quorum percentage required to approve a sale below `minSalePrice`.
     */
    uint256 public immutable lossSaleQuorumPercent;

    /**
     * @notice Price threshold that separates normal and loss sale quorum.
     */
    uint256 public immutable minSalePrice;

    /**
     * @notice Accumulated voting weight for the active sale proposal.
     */
    uint256 public yesVotesWeight;

    /**
     * @notice Sale price proposed by participants.
     */
    uint256 public proposedPrice;

    /**
     * @notice Deadline of the currently proposed sale.
     */
    uint256 public proposedSaleDeadline;

    /**
     * @notice Buyer address of the currently proposed sale.
     */
    address public proposedBuyer;

    /**
     * @notice Accumulated voting weight for emergency withdrawal.
     */
    uint256 public emergencyVotesWeight;

    /**
     * @notice Recipient selected for emergency NFT withdrawal.
     */
    address public emergencyRecipient;

    /**
     * @notice Deadline of the currently proposed emergency withdrawal.
     */
    uint256 public emergencyWithdrawalDeadline;

    /**
     * @notice Accumulated voting weight for the active acquisition proposal.
     */
    uint256 public acquisitionVotesWeight;

    /**
     * @notice Price of the currently proposed acquisition.
     */
    uint256 public proposedAcquisitionPrice;

    /**
     * @notice Deadline of the currently proposed acquisition.
     */
    uint256 public proposedAcquisitionDeadline;

    /**
     * @notice NFT contract of the currently proposed acquisition.
     */
    address public proposedAcquisitionNft;

    /**
     * @notice Token id of the currently proposed acquisition.
     */
    uint256 public proposedAcquisitionTokenId;

    /**
     * @notice Seller of the currently proposed acquisition.
     */
    address public proposedAcquisitionSeller;

    /**
     * @notice True when funding was cancelled due to unsuccessful raise.
     */
    bool public fundingFailed;

    /**
     * @notice True when sale proceeds were allocated for claims.
     */
    bool public saleProceedsAllocated;

    /**
     * @notice Total amount distributed to claim balances after sale.
     */
    uint256 public totalProceedsAllocated;

    /**
     * @notice Total claimed sale proceeds.
     */
    uint256 public totalProceedsClaimed;

    /**
     * @notice Ordered list of alliance participants.
     */
    address[] public participants;

    /**
     * @notice Checks whether an address is an alliance participant.
     */
    mapping(address => bool) public isParticipant;

    /**
     * @notice Share percentage per participant. Sum across all participants equals `SHARES_SUM`.
     */
    mapping(address => uint256) public sharePercent;

    /**
     * @notice Required funding quota for each participant.
     */
    mapping(address => uint256) public requiredContribution;

    /**
     * @notice Total deposited amount per participant.
     */
    mapping(address => uint256) public contributed;

    /**
     * @notice Claimable sale proceeds per participant.
     */
    mapping(address => uint256) public pendingProceeds;

    /**
     * @notice Internal sale vote round marker for each participant.
     */
    mapping(address => uint256) private saleVotedRound;

    /**
     * @notice Internal emergency vote round marker for each participant.
     */
    mapping(address => uint256) private emergencyVotedRound;

    /**
     * @notice Internal acquisition vote round marker for each participant.
     */
    mapping(address => uint256) private acquisitionVotedRound;

    /**
     * @notice Current round id for sale voting.
     */
    uint256 public saleVoteRound = 1;

    /**
     * @notice Current round id for emergency voting.
     */
    uint256 public emergencyVoteRound = 1;

    /**
     * @notice Current round id for acquisition voting.
     */
    uint256 public acquisitionVoteRound = 1;

    /* ========== EVENTS ========== */

    event GovernanceConfigured(uint256 quorumPercent, uint256 lossSaleQuorumPercent, uint256 minSalePrice);
    event Deposit(address indexed user, uint256 amount, uint256 userTotalContribution, uint256 totalDeposited);
    event FundingTargetReached(uint256 totalDeposited, uint256 timestamp);
    event FundingCancelled(uint256 totalDeposited, uint256 timestamp);
    event Refunded(address indexed user, uint256 amount, uint256 remainingContribution, uint256 totalDeposited);
    event NFTBought(address indexed nftAddress, uint256 indexed tokenId, uint256 price, address indexed seller);
    event AcquisitionVoted(
        address indexed voter,
        uint256 indexed round,
        uint256 weight,
        uint256 totalWeight,
        uint256 requiredWeight,
        address indexed nftAddress,
        uint256 tokenId,
        address seller,
        uint256 price,
        uint256 deadline
    );
    event AcquisitionProposalReset(uint256 indexed round);
    event Voted(
        address indexed voter,
        uint256 indexed round,
        uint256 weight,
        uint256 totalWeight,
        uint256 requiredWeight,
        address indexed buyer,
        uint256 price,
        uint256 saleDeadline
    );
    event SaleProposalReset(uint256 indexed round);
    event SaleExecuted(address indexed buyer, uint256 price, uint256 totalAllocated);
    event EmergencyVoted(
        address indexed voter,
        uint256 indexed round,
        uint256 weight,
        uint256 totalWeight,
        uint256 requiredWeight,
        address indexed recipient,
        uint256 emergencyDeadline
    );
    event EmergencyProposalReset(uint256 indexed round);
    event EmergencyWithdrawn(address indexed recipient, address indexed nftAddress, uint256 indexed tokenId);
    event ProceedsAllocated(address indexed participant, uint256 amount);
    event ProceedsClaimed(address indexed participant, uint256 amount, uint256 totalClaimed);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Creates a new alliance.
     * @param _targetPrice Required funding amount.
     * @param _deadline Funding duration in seconds from deployment.
     * @param _participants Participant addresses.
     * @param _shares Participant shares, must sum to 100.
     * @param _token ERC20 funding/payment token.
     * @param _admin Admin address for pause/unpause controls.
     * @param _quorumPercent Quorum required for acquisition, emergency withdrawal, and normal sale.
     * @param _lossSaleQuorumPercent Quorum required for a sale below `_minSalePrice`.
     * @param _minSalePrice Sale price threshold separating normal and loss quorum.
     */
    constructor(
        uint256 _targetPrice,
        uint256 _deadline,
        address[] memory _participants,
        uint256[] memory _shares,
        address _token,
        address _admin,
        uint256 _quorumPercent,
        uint256 _lossSaleQuorumPercent,
        uint256 _minSalePrice
    ) Ownable(_admin) {
        require(_targetPrice > 0, "Alliance: invalid target");
        require(_deadline > 0, "Alliance: invalid deadline");
        require(_token != address(0), "Alliance: zero token");
        require(_admin != address(0), "Alliance: zero admin");
        require(_participants.length > 0, "Alliance: no participants");
        require(_participants.length == _shares.length, "Alliance: length mismatch");
        require(_quorumPercent > 0 && _quorumPercent <= SHARES_SUM, "Alliance: bad quorum");
        require(
            _lossSaleQuorumPercent >= _quorumPercent && _lossSaleQuorumPercent <= SHARES_SUM,
            "Alliance: bad loss quorum"
        );
        require(_minSalePrice > 0, "Alliance: bad min sale");

        uint256 sharesTotal;
        uint256 participantsLength = _participants.length;
        for (uint256 i = 0; i < participantsLength;) {
            address participant = _participants[i];
            uint256 share = _shares[i];

            require(participant != address(0), "Alliance: zero participant");
            require(!isParticipant[participant], "Alliance: duplicate participant");
            require(share > 0, "Alliance: zero share");

            participants.push(participant);
            isParticipant[participant] = true;
            sharePercent[participant] = share;
            sharesTotal += share;

            unchecked {
                ++i;
            }
        }

        require(sharesTotal == SHARES_SUM, "Alliance: shares must sum to 100");

        uint256 assignedQuota;
        for (uint256 i = 0; i < participantsLength;) {
            address participant = participants[i];
            uint256 quota;

            if (i == participantsLength - 1) {
                quota = _targetPrice - assignedQuota;
            } else {
                quota = (_targetPrice * sharePercent[participant]) / SHARES_SUM;
                assignedQuota += quota;
            }
            requiredContribution[participant] = quota;

            unchecked {
                ++i;
            }
        }

        token = IERC20(_token);
        targetPrice = _targetPrice;
        deadline = block.timestamp + _deadline;
        quorumPercent = _quorumPercent;
        lossSaleQuorumPercent = _lossSaleQuorumPercent;
        minSalePrice = _minSalePrice;
        state = State.Funding;

        emit GovernanceConfigured(_quorumPercent, _lossSaleQuorumPercent, _minSalePrice);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyParticipant() {
        require(isParticipant[msg.sender], "Alliance: only participant");
        _;
    }

    modifier inState(State s) {
        require(state == s, "Alliance: invalid state");
        _;
    }

    /* ========== FUNDING ========== */

    /**
     * @notice Deposit funding tokens while the alliance is in `Funding`.
     * @param amount Amount of funding tokens to deposit.
     */
    function deposit(uint256 amount) external onlyParticipant whenNotPaused inState(State.Funding) nonReentrant {
        require(block.timestamp < deadline, "Alliance: funding over");
        require(amount > 0, "Alliance: zero amount");

        uint256 participantContribution = contributed[msg.sender];
        uint256 quota = requiredContribution[msg.sender];
        require(participantContribution < quota, "Alliance: quota filled");
        require(participantContribution + amount <= quota, "Alliance: exceeds quota");

        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBalance = token.balanceOf(address(this));
        uint256 received = afterBalance - beforeBalance;
        require(received > 0, "Alliance: zero received");
        require(received == amount, "Alliance: unsupported token");

        totalDeposited += received;
        contributed[msg.sender] = participantContribution + received;

        emit Deposit(msg.sender, received, contributed[msg.sender], totalDeposited);

        if (totalDeposited == targetPrice) {
            emit FundingTargetReached(totalDeposited, block.timestamp);
        }
    }

    /**
     * @notice Cancel funding after deadline if target was not reached.
     */
    function cancelFunding() external onlyParticipant inState(State.Funding) {
        require(block.timestamp >= deadline, "Alliance: funding active");
        require(totalDeposited < targetPrice, "Alliance: target reached");

        fundingFailed = true;
        state = State.Closed;

        emit FundingCancelled(totalDeposited, block.timestamp);
    }

    /* ========== ACQUISITION GOVERNANCE ========== */

    /**
     * @notice Vote for acquisition parameters while in `Funding`.
     * @dev The first vote initializes proposal fields. Next votes must match exactly.
     */
    function voteToAcquire(
        address _nftAddress,
        uint256 _tokenId,
        address seller,
        uint256 price,
        uint256 acquisitionDeadline
    ) external onlyParticipant whenNotPaused inState(State.Funding) returns (bool reached) {
        require(totalDeposited >= targetPrice, "Alliance: not enough funds");
        require(_nftAddress != address(0), "Alliance: zero NFT");
        require(seller != address(0), "Alliance: zero seller");
        require(price == targetPrice, "Alliance: bad acquisition price");
        require(acquisitionDeadline > block.timestamp, "Alliance: bad acquisition deadline");
        require(acquisitionVotedRound[msg.sender] != acquisitionVoteRound, "Alliance: already acquisition voted");
        require(IERC721(_nftAddress).ownerOf(_tokenId) == seller, "Alliance: seller not owner");

        if (proposedAcquisitionPrice == 0) {
            proposedAcquisitionNft = _nftAddress;
            proposedAcquisitionTokenId = _tokenId;
            proposedAcquisitionSeller = seller;
            proposedAcquisitionPrice = price;
            proposedAcquisitionDeadline = acquisitionDeadline;
        } else {
            require(_nftAddress == proposedAcquisitionNft, "Alliance: NFT mismatch");
            require(_tokenId == proposedAcquisitionTokenId, "Alliance: token mismatch");
            require(seller == proposedAcquisitionSeller, "Alliance: seller mismatch");
            require(price == proposedAcquisitionPrice, "Alliance: price mismatch");
            require(acquisitionDeadline == proposedAcquisitionDeadline, "Alliance: deadline mismatch");
        }

        acquisitionVotedRound[msg.sender] = acquisitionVoteRound;
        uint256 voterWeight = sharePercent[msg.sender];
        acquisitionVotesWeight += voterWeight;
        uint256 requiredWeight = quorumPercent;

        emit AcquisitionVoted(
            msg.sender,
            acquisitionVoteRound,
            voterWeight,
            acquisitionVotesWeight,
            requiredWeight,
            _nftAddress,
            _tokenId,
            seller,
            price,
            acquisitionDeadline
        );
        return acquisitionVotesWeight >= requiredWeight;
    }

    /**
     * @notice Reset an expired acquisition proposal and clear associated votes.
     */
    function resetAcquisitionProposal() external onlyParticipant whenNotPaused inState(State.Funding) {
        require(proposedAcquisitionPrice > 0, "Alliance: no acquisition proposal");
        require(block.timestamp > proposedAcquisitionDeadline, "Alliance: acquisition active");

        uint256 round = acquisitionVoteRound;
        _resetAcquisitionVoting();
        emit AcquisitionProposalReset(round);
    }

    /**
     * @notice Buy the selected NFT once acquisition quorum has approved proposal.
     */
    function buyNFT() external onlyParticipant whenNotPaused inState(State.Funding) nonReentrant {
        require(proposedAcquisitionPrice > 0, "Alliance: no acquisition proposal");
        require(block.timestamp <= proposedAcquisitionDeadline, "Alliance: acquisition expired");
        require(acquisitionVotesWeight >= quorumPercent, "Alliance: quorum not reached");
        require(
            IERC721(proposedAcquisitionNft).ownerOf(proposedAcquisitionTokenId) == proposedAcquisitionSeller,
            "Alliance: seller not owner"
        );

        address acquiredNft = proposedAcquisitionNft;
        uint256 acquiredTokenId = proposedAcquisitionTokenId;
        address acquiredSeller = proposedAcquisitionSeller;
        uint256 acquiredPrice = proposedAcquisitionPrice;

        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransfer(acquiredSeller, acquiredPrice);
        uint256 afterBalance = token.balanceOf(address(this));
        require(afterBalance <= beforeBalance, "Alliance: unsupported token");
        require(beforeBalance - afterBalance == acquiredPrice, "Alliance: unsupported token");

        IERC721(acquiredNft).safeTransferFrom(acquiredSeller, address(this), acquiredTokenId);

        nftAddress = acquiredNft;
        tokenId = acquiredTokenId;
        state = State.Acquired;
        _resetAcquisitionVoting();

        emit NFTBought(nftAddress, tokenId, acquiredPrice, acquiredSeller);
    }

    /* ========== SALE GOVERNANCE ========== */

    /**
     * @notice Vote for sale parameters in `Acquired` state.
     * @dev The first vote initializes proposal fields. Next votes must match exactly.
     */
    function voteToSell(address buyer, uint256 price, uint256 saleDeadline)
        external
        onlyParticipant
        whenNotPaused
        inState(State.Acquired)
        returns (bool reached)
    {
        require(buyer != address(0), "Alliance: zero buyer");
        require(price > 0, "Alliance: zero price");
        require(saleDeadline > block.timestamp, "Alliance: bad sale deadline");
        require(saleVotedRound[msg.sender] != saleVoteRound, "Alliance: already voted");

        if (proposedPrice == 0) {
            proposedBuyer = buyer;
            proposedPrice = price;
            proposedSaleDeadline = saleDeadline;
        } else {
            require(buyer == proposedBuyer, "Alliance: buyer mismatch");
            require(price == proposedPrice, "Alliance: price mismatch");
            require(saleDeadline == proposedSaleDeadline, "Alliance: deadline mismatch");
        }

        saleVotedRound[msg.sender] = saleVoteRound;
        uint256 voterWeight = sharePercent[msg.sender];
        yesVotesWeight += voterWeight;
        uint256 requiredWeight = _requiredSaleQuorum(price);

        emit Voted(
            msg.sender,
            saleVoteRound,
            voterWeight,
            yesVotesWeight,
            requiredWeight,
            buyer,
            price,
            saleDeadline
        );
        return yesVotesWeight >= requiredWeight;
    }

    /**
     * @notice Reset an expired sale proposal and clear associated votes.
     */
    function resetSaleProposal() external onlyParticipant whenNotPaused inState(State.Acquired) {
        require(proposedPrice > 0, "Alliance: no proposal");
        require(block.timestamp > proposedSaleDeadline, "Alliance: proposal active");

        uint256 round = saleVoteRound;
        _resetSaleVoting();
        emit SaleProposalReset(round);
    }

    /**
     * @notice Execute approved sale, transfer NFT to buyer, and allocate proceeds for participant claims.
     */
    function executeSale() external onlyParticipant whenNotPaused inState(State.Acquired) nonReentrant {
        require(proposedPrice > 0, "Alliance: no proposal");
        require(block.timestamp <= proposedSaleDeadline, "Alliance: sale expired");
        require(yesVotesWeight >= _requiredSaleQuorum(proposedPrice), "Alliance: quorum not reached");
        require(IERC721(nftAddress).ownerOf(tokenId) == address(this), "Alliance: NFT not held");

        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(proposedBuyer, address(this), proposedPrice);
        uint256 afterBalance = token.balanceOf(address(this));
        uint256 received = afterBalance - beforeBalance;
        require(received == proposedPrice, "Alliance: unsupported token");

        IERC721(nftAddress).safeTransferFrom(address(this), proposedBuyer, tokenId);

        uint256 allocated = _allocateProceeds(received);

        state = State.Closed;
        saleProceedsAllocated = true;

        emit SaleExecuted(proposedBuyer, proposedPrice, allocated);
    }

    /* ========== EMERGENCY ========== */

    /**
     * @notice Vote for emergency withdrawal of the held NFT.
     * @param recipient Address that will receive the NFT if quorum is reached.
     * @param emergencyDeadline Deadline by which emergency withdrawal must be executed.
     * @return reached True if emergency quorum is met after this vote.
     */
    function voteEmergencyWithdraw(address recipient, uint256 emergencyDeadline)
        external
        onlyParticipant
        whenNotPaused
        inState(State.Acquired)
        returns (bool reached)
    {
        require(recipient != address(0), "Alliance: zero recipient");
        require(emergencyDeadline > block.timestamp, "Alliance: bad emergency deadline");
        require(emergencyVotedRound[msg.sender] != emergencyVoteRound, "Alliance: already emergency voted");

        if (emergencyRecipient == address(0)) {
            emergencyRecipient = recipient;
            emergencyWithdrawalDeadline = emergencyDeadline;
        } else {
            require(recipient == emergencyRecipient, "Alliance: recipient mismatch");
            require(emergencyDeadline == emergencyWithdrawalDeadline, "Alliance: emergency deadline mismatch");
        }

        emergencyVotedRound[msg.sender] = emergencyVoteRound;
        uint256 voterWeight = sharePercent[msg.sender];
        emergencyVotesWeight += voterWeight;
        uint256 requiredWeight = quorumPercent;

        emit EmergencyVoted(
            msg.sender,
            emergencyVoteRound,
            voterWeight,
            emergencyVotesWeight,
            requiredWeight,
            recipient,
            emergencyDeadline
        );
        return emergencyVotesWeight >= requiredWeight;
    }

    /**
     * @notice Reset an expired emergency withdrawal proposal and clear associated votes.
     */
    function resetEmergencyProposal() external onlyParticipant whenNotPaused inState(State.Acquired) {
        require(emergencyRecipient != address(0), "Alliance: no emergency proposal");
        require(block.timestamp > emergencyWithdrawalDeadline, "Alliance: emergency active");

        uint256 round = emergencyVoteRound;
        _resetEmergencyVoting();
        emit EmergencyProposalReset(round);
    }

    /**
     * @notice Transfer NFT to emergency recipient once emergency quorum is reached.
     */
    function emergencyWithdrawNFT() external onlyParticipant whenNotPaused inState(State.Acquired) nonReentrant {
        require(emergencyVotesWeight >= quorumPercent, "Alliance: quorum not reached");
        require(emergencyRecipient != address(0), "Alliance: no recipient");
        require(block.timestamp <= emergencyWithdrawalDeadline, "Alliance: emergency expired");
        require(IERC721(nftAddress).ownerOf(tokenId) == address(this), "Alliance: NFT not held");

        IERC721(nftAddress).safeTransferFrom(address(this), emergencyRecipient, tokenId);

        state = State.Closed;
        emit EmergencyWithdrawn(emergencyRecipient, nftAddress, tokenId);
    }

    /**
     * @notice Withdraw participant's deposited contribution after failed funding.
     */
    function withdrawRefund() external onlyParticipant nonReentrant {
        require(state == State.Closed && fundingFailed, "Alliance: refund unavailable");

        uint256 amount = contributed[msg.sender];
        require(amount > 0, "Alliance: nothing to refund");

        contributed[msg.sender] = 0;
        totalDeposited -= amount;
        token.safeTransfer(msg.sender, amount);

        emit Refunded(msg.sender, amount, contributed[msg.sender], totalDeposited);
    }

    /**
     * @notice Claim participant sale proceeds after successful sale execution.
     */
    function claimProceeds() external onlyParticipant nonReentrant {
        require(state == State.Closed && saleProceedsAllocated, "Alliance: proceeds unavailable");

        uint256 amount = pendingProceeds[msg.sender];
        require(amount > 0, "Alliance: nothing to claim");

        pendingProceeds[msg.sender] = 0;
        totalProceedsClaimed += amount;
        token.safeTransfer(msg.sender, amount);

        emit ProceedsClaimed(msg.sender, amount, totalProceedsClaimed);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function hasVoted(address participant) public view returns (bool) {
        return saleVotedRound[participant] == saleVoteRound;
    }

    function hasVotedAcquisition(address participant) public view returns (bool) {
        return acquisitionVotedRound[participant] == acquisitionVoteRound;
    }

    function hasVotedEmergency(address participant) public view returns (bool) {
        return emergencyVotedRound[participant] == emergencyVoteRound;
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    function remainingContribution(address participant) external view returns (uint256) {
        return requiredContribution[participant] - contributed[participant];
    }

    function getAllianceSummary()
        external
        view
        returns (
            State currentState,
            address fundingToken,
            address heldNft,
            uint256 heldTokenId,
            uint256 fundingTarget,
            uint256 deposited,
            uint256 fundingDeadline,
            uint256 saleQuorum,
            uint256 lossQuorum,
            uint256 minimumSalePrice,
            bool failedFunding,
            bool proceedsReady
        )
    {
        return (
            state,
            address(token),
            nftAddress,
            tokenId,
            targetPrice,
            totalDeposited,
            deadline,
            quorumPercent,
            lossSaleQuorumPercent,
            minSalePrice,
            fundingFailed,
            saleProceedsAllocated
        );
    }

    function getCurrentAcquisitionProposal()
        external
        view
        returns (
            uint256 round,
            address proposedNft,
            uint256 proposedTokenId,
            address seller,
            uint256 price,
            uint256 proposalDeadline,
            uint256 totalWeight,
            uint256 requiredWeight
        )
    {
        return (
            acquisitionVoteRound,
            proposedAcquisitionNft,
            proposedAcquisitionTokenId,
            proposedAcquisitionSeller,
            proposedAcquisitionPrice,
            proposedAcquisitionDeadline,
            acquisitionVotesWeight,
            quorumPercent
        );
    }

    function getCurrentSaleProposal()
        external
        view
        returns (
            uint256 round,
            address buyer,
            uint256 price,
            uint256 saleDeadline,
            uint256 totalWeight,
            uint256 requiredWeight
        )
    {
        return (
            saleVoteRound,
            proposedBuyer,
            proposedPrice,
            proposedSaleDeadline,
            yesVotesWeight,
            proposedPrice == 0 ? quorumPercent : _requiredSaleQuorum(proposedPrice)
        );
    }

    function getCurrentEmergencyProposal()
        external
        view
        returns (
            uint256 round,
            address recipient,
            uint256 proposalDeadline,
            uint256 totalWeight,
            uint256 requiredWeight
        )
    {
        return (
            emergencyVoteRound,
            emergencyRecipient,
            emergencyWithdrawalDeadline,
            emergencyVotesWeight,
            quorumPercent
        );
    }

    /* ========== ADMIN FUNCTIONS ========== */

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function isPaused() external view returns (bool) {
        return paused();
    }

    /* ========== TOKEN RECEIVER ========== */

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _requiredSaleQuorum(uint256 price) internal view returns (uint256) {
        if (price >= minSalePrice) {
            return quorumPercent;
        }
        return lossSaleQuorumPercent;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _resetSaleVoting() internal {
        proposedBuyer = address(0);
        proposedPrice = 0;
        proposedSaleDeadline = 0;
        yesVotesWeight = 0;
        unchecked {
            saleVoteRound += 1;
        }
    }

    function _resetEmergencyVoting() internal {
        emergencyRecipient = address(0);
        emergencyWithdrawalDeadline = 0;
        emergencyVotesWeight = 0;
        unchecked {
            emergencyVoteRound += 1;
        }
    }

    function _resetAcquisitionVoting() internal {
        proposedAcquisitionNft = address(0);
        proposedAcquisitionTokenId = 0;
        proposedAcquisitionSeller = address(0);
        proposedAcquisitionPrice = 0;
        proposedAcquisitionDeadline = 0;
        acquisitionVotesWeight = 0;
        unchecked {
            acquisitionVoteRound += 1;
        }
    }

    function _allocateProceeds(uint256 totalFunds) internal returns (uint256 allocated) {
        uint256 participantsLength = participants.length;
        for (uint256 i = 0; i < participantsLength;) {
            address participant = participants[i];
            uint256 payout;

            if (i == participantsLength - 1) {
                payout = totalFunds - allocated;
            } else {
                payout = (totalFunds * sharePercent[participant]) / SHARES_SUM;
                allocated += payout;
            }

            if (payout > 0) {
                pendingProceeds[participant] += payout;
                emit ProceedsAllocated(participant, payout);
            }

            unchecked {
                ++i;
            }
        }

        totalProceedsAllocated = totalFunds;
    }
}
