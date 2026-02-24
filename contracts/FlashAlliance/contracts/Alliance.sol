// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Alliance
/// @notice Collective NFT acquisition and sale contract funded with a custom ERC20 token.
/// @dev Participants fund a target amount, execute OTC NFT purchase, vote sale parameters, and split proceeds by fixed shares.
/// @custom:version 1.0.0
contract Alliance is Ownable, ReentrancyGuard, IERC721Receiver, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Lifecycle stages of the alliance.
    enum State {
        /// @notice Capital is being raised from participants.
        Funding,
        /// @notice NFT was acquired and sale voting is active.
        Acquired,
        /// @notice Alliance finished by sale execution, emergency withdrawal, or failed funding.
        Closed
    }

    /// @notice Basis for participant percentage shares.
    uint256 public constant SHARES_SUM = 100;

    /// @notice ERC20 token used for funding, settlement, and payouts.
    IERC20 public immutable token;
    /// @notice Current alliance state.
    State public state;

    /// @notice NFT contract address once an asset is acquired.
    address public nftAddress;
    /// @notice NFT token id once an asset is acquired.
    uint256 public tokenId;

    /// @notice Required funding amount to be able to buy the NFT.
    uint256 public immutable targetPrice;
    /// @notice Total amount deposited by all participants.
    uint256 public totalDeposited;
    /// @notice Funding deadline as a unix timestamp.
    uint256 public immutable deadline;

    /// @notice Quorum percentage required to approve a normal sale.
    uint256 public quorumPercent = 60;
    /// @notice Quorum percentage required to approve a sale below `minSalePrice`.
    uint256 public lossSaleQuorumPercent = 80;
    /// @notice Price threshold that separates normal and loss sale quorum.
    uint256 public minSalePrice;

    /// @notice Accumulated voting weight for the active sale proposal.
    uint256 public yesVotesWeight;
    /// @notice Sale price proposed by participants.
    uint256 public proposedPrice;
    /// @notice Deadline of the currently proposed sale.
    uint256 public proposedSaleDeadline;
    /// @notice Buyer address of the currently proposed sale.
    address public proposedBuyer;

    /// @notice Accumulated voting weight for emergency withdrawal.
    uint256 public emergencyVotesWeight;
    /// @notice Recipient selected for emergency NFT withdrawal.
    address public emergencyRecipient;

    /// @notice True when funding was cancelled due to unsuccessful raise.
    bool public fundingFailed;

    /// @notice Ordered list of alliance participants.
    address[] public participants;

    /// @notice Checks whether an address is an alliance participant.
    mapping(address => bool) public isParticipant;
    /// @notice Share percentage per participant. Sum across all participants equals `SHARES_SUM`.
    mapping(address => uint256) public sharePercent;
    /// @notice Total deposited amount per participant.
    mapping(address => uint256) public contributed;
    /// @notice Tracks whether a participant voted for the current sale proposal.
    mapping(address => bool) public hasVoted;
    /// @notice Tracks whether a participant voted for emergency withdrawal.
    mapping(address => bool) public hasVotedEmergency;

    /// @notice Emitted when a participant deposits funding tokens.
    /// @param user Depositor address.
    /// @param amount Deposited token amount.
    event Deposit(address indexed user, uint256 amount);
    /// @notice Emitted when funding is cancelled after deadline with insufficient deposits.
    event FundingCancelled();
    /// @notice Emitted when a participant withdraws refund after failed funding.
    /// @param user Refunding participant address.
    /// @param amount Refunded token amount.
    event Refunded(address indexed user, uint256 amount);
    /// @notice Emitted when the NFT is purchased by the alliance.
    /// @param nftAddress NFT contract address.
    /// @param tokenId Purchased token id.
    /// @param price Purchase price in funding token.
    /// @param seller Seller address.
    event NFTBought(address indexed nftAddress, uint256 tokenId, uint256 price, address indexed seller);
    /// @notice Emitted when a participant votes for a sale proposal.
    /// @param voter Voter address.
    /// @param weight Voting weight used for the vote.
    /// @param buyer Proposed buyer address.
    /// @param price Proposed sale price.
    /// @param saleDeadline Proposed sale deadline.
    event Voted(address indexed voter, uint256 weight, address indexed buyer, uint256 price, uint256 saleDeadline);
    /// @notice Emitted when an expired sale proposal is reset.
    event SaleProposalReset();
    /// @notice Emitted when sale is executed successfully.
    /// @param buyer Buyer that paid and received the NFT.
    /// @param price Final sale price.
    event SaleExecuted(address indexed buyer, uint256 price);
    /// @notice Emitted when a participant votes for emergency withdrawal.
    /// @param voter Voter address.
    /// @param weight Voting weight used for the vote.
    /// @param recipient Recipient selected for NFT withdrawal.
    event EmergencyVoted(address indexed voter, uint256 weight, address indexed recipient);
    /// @notice Emitted when NFT is withdrawn through emergency flow.
    /// @param recipient Recipient of the NFT.
    /// @param nftAddress NFT contract address.
    /// @param tokenId Token id withdrawn.
    event EmergencyWithdrawn(address indexed recipient, address indexed nftAddress, uint256 indexed tokenId);

    /// @notice Creates a new alliance.
    /// @param _targetPrice Required funding amount.
    /// @param _deadline Funding duration in seconds from deployment.
    /// @param _participants Participant addresses.
    /// @param _shares Participant shares, must sum to 100.
    /// @param _token ERC20 funding/payment token.
    /// @param _admin Admin address for pause/unpause controls.
    constructor(
        uint256 _targetPrice,
        uint256 _deadline,
        address[] memory _participants,
        uint256[] memory _shares,
        address _token,
        address _admin
    ) Ownable(_admin) {
        require(_targetPrice > 0, "Alliance: invalid target");
        require(_deadline > 0, "Alliance: invalid deadline");
        require(_token != address(0), "Alliance: zero token");
        require(_admin != address(0), "Alliance: zero admin");
        require(_participants.length > 0, "Alliance: no participants");
        require(_participants.length == _shares.length, "Alliance: length mismatch");

        uint256 sharesTotal;
        for (uint256 i = 0; i < _participants.length; i++) {
            address participant = _participants[i];
            uint256 share = _shares[i];

            require(participant != address(0), "Alliance: zero participant");
            require(!isParticipant[participant], "Alliance: duplicate participant");
            require(share > 0, "Alliance: zero share");

            participants.push(participant);
            isParticipant[participant] = true;
            sharePercent[participant] = share;
            sharesTotal += share;
        }

        require(sharesTotal == SHARES_SUM, "Alliance: shares must sum to 100");

        token = IERC20(_token);
        targetPrice = _targetPrice;
        minSalePrice = _targetPrice;
        deadline = block.timestamp + _deadline;
        state = State.Funding;
    }

    /// @notice Restricts access to configured alliance participants.
    modifier onlyParticipant() {
        require(isParticipant[msg.sender], "Alliance: only participant");
        _;
    }

    /// @notice Restricts function execution to a specific lifecycle state.
    /// @param s Required state.
    modifier inState(State s) {
        require(state == s, "Alliance: invalid state");
        _;
    }

    /// @notice Deposit funding tokens while the alliance is in `Funding`.
    /// @param amount Amount of funding tokens to deposit.
    function deposit(uint256 amount) external onlyParticipant whenNotPaused inState(State.Funding) nonReentrant {
        require(block.timestamp < deadline, "Alliance: funding over");
        require(amount > 0, "Alliance: zero amount");

        uint256 remaining = targetPrice - totalDeposited;
        require(amount <= remaining, "Alliance: exceeds target");

        token.safeTransferFrom(msg.sender, address(this), amount);

        totalDeposited += amount;
        contributed[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /// @notice Cancel funding after deadline if target was not reached.
    function cancelFunding() external onlyParticipant inState(State.Funding) {
        require(block.timestamp >= deadline, "Alliance: funding active");
        require(totalDeposited < targetPrice, "Alliance: target reached");

        fundingFailed = true;
        state = State.Closed;

        emit FundingCancelled();
    }

    /// @notice Buy the selected NFT once target funding has been reached.
    /// @param _nftAddress NFT contract address.
    /// @param _tokenId NFT token id to purchase.
    /// @param seller Current owner/seller of the NFT.
    function buyNFT(address _nftAddress, uint256 _tokenId, address seller)
        external
        onlyParticipant
        whenNotPaused
        inState(State.Funding)
        nonReentrant
    {
        require(totalDeposited >= targetPrice, "Alliance: not enough funds");
        require(_nftAddress != address(0), "Alliance: zero NFT");
        require(seller != address(0), "Alliance: zero seller");
        require(IERC721(_nftAddress).ownerOf(_tokenId) == seller, "Alliance: seller not owner");

        token.safeTransfer(seller, targetPrice);
        IERC721(_nftAddress).safeTransferFrom(seller, address(this), _tokenId);

        nftAddress = _nftAddress;
        tokenId = _tokenId;
        state = State.Acquired;

        emit NFTBought(_nftAddress, _tokenId, targetPrice, seller);
    }

    /// @notice Vote for sale parameters in `Acquired` state.
    /// @dev The first vote initializes proposal fields. Next votes must match exactly.
    /// @param buyer Proposed buyer address.
    /// @param price Proposed sale price in funding token.
    /// @param saleDeadline Deadline (unix timestamp) by which sale must be executed.
    /// @return reached True if the quorum requirement is met after this vote.
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
        require(!hasVoted[msg.sender], "Alliance: already voted");

        if (proposedPrice == 0) {
            proposedBuyer = buyer;
            proposedPrice = price;
            proposedSaleDeadline = saleDeadline;
        } else {
            require(buyer == proposedBuyer, "Alliance: buyer mismatch");
            require(price == proposedPrice, "Alliance: price mismatch");
            require(saleDeadline == proposedSaleDeadline, "Alliance: deadline mismatch");
        }

        hasVoted[msg.sender] = true;
        uint256 voterWeight = sharePercent[msg.sender];
        yesVotesWeight += voterWeight;

        emit Voted(msg.sender, voterWeight, buyer, price, saleDeadline);
        return yesVotesWeight >= _requiredSaleQuorum(price);
    }

    /// @notice Reset an expired sale proposal and clear associated votes.
    function resetSaleProposal() external onlyParticipant whenNotPaused inState(State.Acquired) {
        require(proposedPrice > 0, "Alliance: no proposal");
        require(block.timestamp > proposedSaleDeadline, "Alliance: proposal active");

        _resetSaleVoting();
        emit SaleProposalReset();
    }

    /// @notice Execute approved sale, transfer NFT to buyer, and distribute proceeds.
    function executeSale() external onlyParticipant whenNotPaused inState(State.Acquired) nonReentrant {
        require(proposedPrice > 0, "Alliance: no proposal");
        require(block.timestamp <= proposedSaleDeadline, "Alliance: sale expired");
        require(yesVotesWeight >= _requiredSaleQuorum(proposedPrice), "Alliance: quorum not reached");
        require(IERC721(nftAddress).ownerOf(tokenId) == address(this), "Alliance: NFT not held");

        token.safeTransferFrom(proposedBuyer, address(this), proposedPrice);
        IERC721(nftAddress).safeTransferFrom(address(this), proposedBuyer, tokenId);

        _distribute(proposedPrice);

        state = State.Closed;
        emit SaleExecuted(proposedBuyer, proposedPrice);
    }

    /// @notice Vote for emergency withdrawal of the held NFT.
    /// @param recipient Address that will receive the NFT if quorum is reached.
    /// @return reached True if emergency quorum is met after this vote.
    function voteEmergencyWithdraw(address recipient)
        external
        onlyParticipant
        whenNotPaused
        inState(State.Acquired)
        returns (bool reached)
    {
        require(recipient != address(0), "Alliance: zero recipient");
        require(!hasVotedEmergency[msg.sender], "Alliance: already emergency voted");

        if (emergencyRecipient == address(0)) {
            emergencyRecipient = recipient;
        } else {
            require(recipient == emergencyRecipient, "Alliance: recipient mismatch");
        }

        hasVotedEmergency[msg.sender] = true;
        uint256 voterWeight = sharePercent[msg.sender];
        emergencyVotesWeight += voterWeight;

        emit EmergencyVoted(msg.sender, voterWeight, recipient);
        return emergencyVotesWeight >= quorumPercent;
    }

    /// @notice Transfer NFT to emergency recipient once emergency quorum is reached.
    function emergencyWithdrawNFT() external onlyParticipant whenNotPaused inState(State.Acquired) nonReentrant {
        require(emergencyVotesWeight >= quorumPercent, "Alliance: quorum not reached");
        require(emergencyRecipient != address(0), "Alliance: no recipient");
        require(IERC721(nftAddress).ownerOf(tokenId) == address(this), "Alliance: NFT not held");

        IERC721(nftAddress).safeTransferFrom(address(this), emergencyRecipient, tokenId);

        state = State.Closed;
        emit EmergencyWithdrawn(emergencyRecipient, nftAddress, tokenId);
    }

    /// @notice Withdraw participant's deposited contribution after failed funding.
    function withdrawRefund() external onlyParticipant whenNotPaused nonReentrant {
        require(state == State.Closed && fundingFailed, "Alliance: refund unavailable");

        uint256 amount = contributed[msg.sender];
        require(amount > 0, "Alliance: nothing to refund");

        contributed[msg.sender] = 0;
        totalDeposited -= amount;
        token.safeTransfer(msg.sender, amount);

        emit Refunded(msg.sender, amount);
    }

    /// @notice Return the full participant list.
    /// @return Array of participant addresses.
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /// @notice Pause operational functions guarded by `whenNotPaused`.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause operational functions guarded by `whenNotPaused`.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Convenience view returning current pause status.
    /// @return True if paused, false otherwise.
    function isPaused() external view returns (bool) {
        return paused();
    }

    /// @notice ERC721 receiver hook to allow safe transfers into this contract.
    /// @return Selector confirming ERC721 reception support.
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Compute required quorum based on proposed sale price.
    /// @param price Proposed sale price.
    /// @return Required quorum weight in percentage points.
    function _requiredSaleQuorum(uint256 price) internal view returns (uint256) {
        if (price >= minSalePrice) {
            return quorumPercent;
        }
        return lossSaleQuorumPercent;
    }

    /// @notice Clear current sale proposal and reset sale vote flags for all participants.
    function _resetSaleVoting() internal {
        proposedBuyer = address(0);
        proposedPrice = 0;
        proposedSaleDeadline = 0;
        yesVotesWeight = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            hasVoted[participants[i]] = false;
        }
    }

    /// @notice Distribute settlement proceeds according to participant share percentages.
    /// @param totalFunds Total amount of tokens to distribute.
    function _distribute(uint256 totalFunds) internal {
        uint256 distributed;

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 payout;

            if (i == participants.length - 1) {
                payout = totalFunds - distributed;
            } else {
                payout = (totalFunds * sharePercent[participant]) / SHARES_SUM;
                distributed += payout;
            }

            if (payout > 0) {
                token.safeTransfer(participant, payout);
            }
        }
    }
}
