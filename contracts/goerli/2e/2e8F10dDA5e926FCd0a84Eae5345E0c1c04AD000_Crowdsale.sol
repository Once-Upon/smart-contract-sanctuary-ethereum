// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.6.12;

import "./IHubAdminAccess.sol";

/**
 * @notice Access Controls
 * @author Attr: BlockRocket.tech
 */
contract IHubAccessControls is IHubAdminAccess {
    /// @notice Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SMART_CONTRACT_ROLE = keccak256("SMART_CONTRACT_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /**
     * @notice The deployer is automatically given the admin role which will allow them to then grant roles to other addresses
     */
    // solhint-disable-next-line no-empty-blocks
    constructor() public {}

    /////////////
    // Lookups //
    /////////////

    /**
     * @notice Used to check whether an address has the minter role
     * @param _address EOA or contract being checked
     * @return bool True if the account has the role or false if it does not
     */
    function hasMinterRole(address _address) public view returns (bool) {
        return hasRole(MINTER_ROLE, _address);
    }

    /**
     * @notice Used to check whether an address has the smart contract role
     * @param _address EOA or contract being checked
     * @return bool True if the account has the role or false if it does not
     */
    function hasSmartContractRole(address _address) public view returns (bool) {
        return hasRole(SMART_CONTRACT_ROLE, _address);
    }

    /**
     * @notice Used to check whether an address has the operator role
     * @param _address EOA or contract being checked
     * @return bool True if the account has the role or false if it does not
     */
    function hasOperatorRole(address _address) public view returns (bool) {
        return hasRole(OPERATOR_ROLE, _address);
    }

    ///////////////
    // Modifiers //
    ///////////////

    /**
     * @notice Grants the minter role to an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract receiving the new role
     */
    function addMinterRole(address _address) external {
        grantRole(MINTER_ROLE, _address);
    }

    /**
     * @notice Removes the minter role from an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract affected
     */
    function removeMinterRole(address _address) external {
        revokeRole(MINTER_ROLE, _address);
    }

    /**
     * @notice Grants the smart contract role to an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract receiving the new role
     */
    function addSmartContractRole(address _address) external {
        grantRole(SMART_CONTRACT_ROLE, _address);
    }

    /**
     * @notice Removes the smart contract role from an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract affected
     */
    function removeSmartContractRole(address _address) external {
        revokeRole(SMART_CONTRACT_ROLE, _address);
    }

    /**
     * @notice Grants the operator role to an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract receiving the new role
     */
    function addOperatorRole(address _address) external {
        grantRole(OPERATOR_ROLE, _address);
    }

    /**
     * @notice Removes the operator role from an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract affected
     */
    function removeOperatorRole(address _address) external {
        revokeRole(OPERATOR_ROLE, _address);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.6.12;

import "../OpenZeppelin/access/AccessControl.sol";

contract IHubAdminAccess is AccessControl {
    /// @dev Whether access is initialised.
    bool private initAccess;

    /// @notice The deployer is automatically given the admin role which will allow them to then grant roles to other addresses.
    // solhint-disable-next-line no-empty-blocks
    constructor() public {}

    /**
     * @notice Initializes access controls.
     * @param _admin Admins address.
     */
    function initAccessControls(address _admin) public {
        require(!initAccess, "Already initialised");
        require(_admin != address(0), "Incorrect input");
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        initAccess = true;
    }

    /////////////
    // Lookups //
    /////////////

    /**
     * @notice Used to check whether an address has the admin role.
     * @param _address EOA or contract being checked.
     * @return bool True if the account has the role or false if it does not.
     */
    function hasAdminRole(address _address) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _address);
    }

    ///////////////
    // Modifiers //
    ///////////////

    /**
     * @notice Grants the admin role to an address.
     * @dev The sender must have the admin role.
     * @param _address EOA or contract receiving the new role.
     */
    function addAdminRole(address _address) external {
        grantRole(DEFAULT_ADMIN_ROLE, _address);
    }

    /**
     * @notice Removes the admin role from an address.
     * @dev The sender must have the admin role.
     * @param _address EOA or contract affected.
     */
    function removeAdminRole(address _address) external {
        revokeRole(DEFAULT_ADMIN_ROLE, _address);
    }
}

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// Crowdsale
//
// A fixed price token swap contract.
//
// Inspired by the Open Zeppelin crowsdale and delta.financial
// https://github.com/OpenZeppelin/openzeppelin-contracts
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// ---------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0
// ---------------------------------------------------------------------

import "../OpenZeppelin/utils/ReentrancyGuard.sol";
import "../Access/IHubAccessControls.sol";
import "../Utils/SafeTransfer.sol";
import "../Utils/BoringBatchable.sol";
import "../Utils/BoringERC20.sol";
import "../Utils/BoringMath.sol";
import "../Utils/Documents.sol";
import "../interfaces/IPointList.sol";
import "../interfaces/IIHubMarket.sol";

contract Crowdsale is IIHubMarket, IHubAccessControls, BoringBatchable, SafeTransfer, Documents, ReentrancyGuard {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringMath64 for uint64;
    using BoringERC20 for IERC20;

    /// @notice IHubMarket template id for the factory contract.
    /// @dev For different marketplace types, this must be incremented.
    // solhint-disable-next-line const-name-snakecase
    uint256 public constant override marketTemplate = 1;

    /// @notice The placeholder ETH address.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The decimals of the auction token.
    uint256 private constant AUCTION_TOKEN_DECIMAL_PLACES = 18;
    uint256 private constant AUCTION_TOKEN_DECIMALS = 10 ** AUCTION_TOKEN_DECIMAL_PLACES;

    /**
     * @notice rate - How many token units a buyer gets per token or wei.
     * The rate is the conversion between wei and the smallest and indivisible token unit.
     * So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
     * 1 wei will give you 1 unit, or 0.001 TOK.
     */
    /// @notice goal - Minimum amount of funds to be raised in weis or tokens.
    struct MarketPrice {
        uint128 rate;
        uint128 goal;
    }
    MarketPrice public marketPrice;

    /// @notice Starting time of crowdsale.
    /// @notice Ending time of crowdsale.
    /// @notice Total number of tokens to sell.
    struct MarketInfo {
        uint64 startTime;
        uint64 endTime;
        uint128 totalTokens;
    }
    MarketInfo public marketInfo;

    /// @notice Amount of wei raised.
    /// @notice Whether crowdsale has been initialized or not.
    /// @notice Whether crowdsale has been finalized or not.
    struct MarketStatus {
        uint128 commitmentsTotal;
        bool finalized;
        bool usePointList;
    }
    MarketStatus public marketStatus;

    /// @notice The token being sold.
    address public auctionToken;
    /// @notice Address where funds are collected.
    address payable public wallet;
    /// @notice The currency the crowdsale accepts for payment. Can be ETH or token address.
    address public paymentCurrency;
    /// @notice Address that manages auction approvals.
    address public pointList;

    /// @notice The commited amount of accounts.
    mapping(address => uint256) public commitments;
    /// @notice Amount of tokens to claim per address.
    mapping(address => uint256) public claimed;

    /// @notice Event for all auction data. Emmited on deployment.
    event AuctionDeployed(
        address funder,
        address token,
        address paymentCurrency,
        uint256 totalTokens,
        address admin,
        address wallet
    );

    /// @notice Event for updating auction times.  Needs to be before auction starts.
    event AuctionTimeUpdated(uint256 startTime, uint256 endTime);
    /// @notice Event for updating auction prices. Needs to be before auction starts.
    event AuctionPriceUpdated(uint256 rate, uint256 goal);
    /// @notice Event for updating auction wallet. Needs to be before auction starts.
    event AuctionWalletUpdated(address wallet);
    /// @notice Event for updating the point list.
    event AuctionPointListUpdated(address pointList, bool enabled);

    /// @notice Event for adding a commitment.
    event AddedCommitment(address addr, uint256 commitment);

    /// @notice Event for finalization of the crowdsale
    event AuctionFinalized();
    /// @notice Event for cancellation of the auction.
    event AuctionCancelled();

    /**
     * @notice Initializes main contract variables and transfers funds for the sale.
     * @dev Init function.
     * @param _funder The address that funds the token for crowdsale.
     * @param _token Address of the token being sold.
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address.
     * @param _totalTokens The total number of tokens to sell in crowdsale.
     * @param _startTime Crowdsale start time.
     * @param _endTime Crowdsale end time.
     * @param _rate Number of token units a buyer gets per wei or token.
     * @param _goal Minimum amount of funds to be raised in weis or tokens.
     * @param _admin Address that can finalize auction.
     * @param _pointList Address that will manage auction approvals.
     * @param _wallet Address where collected funds will be forwarded to.
     */
    function initCrowdsale(
        address _funder,
        address _token,
        address _paymentCurrency,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        uint256 _goal,
        address _admin,
        address _pointList,
        address payable _wallet
    ) public {
        require(_endTime < 10000000000, "in seconds, not miliseconds");
        // solhint-disable-next-line not-rely-on-time
        require(_startTime >= block.timestamp, "start is before current");
        require(_endTime > _startTime, "start is not before end");
        require(_rate > 0, "rate is 0");
        require(_wallet != address(0), "wallet is the zero address");
        require(_admin != address(0), "admin is the zero address");
        require(_totalTokens > 0, "total tokens is 0");
        require(_goal > 0, "goal is 0");
        require(IERC20(_token).decimals() == AUCTION_TOKEN_DECIMAL_PLACES, "Token does not have 18 decimals");
        if (_paymentCurrency != ETH_ADDRESS) {
            require(IERC20(_paymentCurrency).decimals() > 0, "Payment currency is not ERC20");
        }

        marketPrice.rate = BoringMath.to128(_rate);
        marketPrice.goal = BoringMath.to128(_goal);

        marketInfo.startTime = BoringMath.to64(_startTime);
        marketInfo.endTime = BoringMath.to64(_endTime);
        marketInfo.totalTokens = BoringMath.to128(_totalTokens);

        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        wallet = _wallet;

        initAccessControls(_admin);

        _setList(_pointList);

        require(_getTokenAmount(_goal) <= _totalTokens, "goal <= total tokens");

        _safeTransferFrom(_token, _funder, _totalTokens);

        emit AuctionDeployed(_funder, _token, _paymentCurrency, _totalTokens, _admin, _wallet);
        emit AuctionTimeUpdated(_startTime, _endTime);
        emit AuctionPriceUpdated(_rate, _goal);
    }

    ///--------------------------------------------------------
    /// Commit to buying tokens!
    ///--------------------------------------------------------

    receive() external payable {
        revertBecauseUserDidNotProvideAgreement();
    }

    /**
     * @dev Attribution to the awesome delta.financial contracts
     */
    function marketParticipationAgreement() public pure returns (string memory) {
        return
            "I understand that I am interacting with a smart contract. I understand that tokens commited are subject to the token issuer and local laws where applicable. I reviewed code of the smart contract and understand it fully. I agree to not hold developers or other people associated with the project liable for any losses or misunderstandings";
    }

    /**
     * @dev Not using modifiers is a purposeful choice for code readability.
     */
    function revertBecauseUserDidNotProvideAgreement() internal pure {
        // solhint-disable-next-line reason-string
        revert("No agreement provided, please review the smart contract before interacting with it");
    }

    /**
     * @notice Checks the amount of ETH to commit and adds the commitment. Refunds the buyer if commit is too high.
     * @dev low level token purchase with ETH ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it should not be called by
     * another `nonReentrant` function.
     * @param _beneficiary Recipient of the token purchase.
     */
    function commitEth(
        address payable _beneficiary,
        bool readAndAgreedToMarketParticipationAgreement
    ) public payable nonReentrant {
        require(paymentCurrency == ETH_ADDRESS, "Payment currency is not ETH");
        if (readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }

        /// @dev Get ETH able to be committed.
        uint256 ethToTransfer = calculateCommitment(msg.value);

        /// @dev Accept ETH Payments.
        uint256 ethToRefund = msg.value.sub(ethToTransfer);
        if (ethToTransfer > 0) {
            _addCommitment(_beneficiary, ethToTransfer);
        }

        /// @dev Return any ETH to be refunded.
        if (ethToRefund > 0) {
            _beneficiary.transfer(ethToRefund);
        }

        /// @notice Revert if commitmentsTotal exceeds the balance
        require(marketStatus.commitmentsTotal <= address(this).balance, "Committed ETH exceeds balance");
    }

    /**
     * @notice Buy Tokens by commiting approved ERC20 tokens to this contract address.
     * @param _amount Amount of tokens to commit.
     */
    function commitTokens(uint256 _amount, bool readAndAgreedToMarketParticipationAgreement) public {
        commitTokensFrom(msg.sender, _amount, readAndAgreedToMarketParticipationAgreement);
    }

    /**
     * @notice Checks how much is user able to commit and processes that commitment.
     * @dev Users must approve contract prior to committing tokens to auction.
     * @param _from User ERC20 address.
     * @param _amount Amount of approved ERC20 tokens.
     */
    function commitTokensFrom(
        address _from,
        uint256 _amount,
        bool readAndAgreedToMarketParticipationAgreement
    ) public nonReentrant {
        require(address(paymentCurrency) != ETH_ADDRESS, "Payment currency is not a token");
        if (readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        uint256 tokensToTransfer = calculateCommitment(_amount);
        if (tokensToTransfer > 0) {
            _safeTransferFrom(paymentCurrency, msg.sender, tokensToTransfer);
            _addCommitment(_from, tokensToTransfer);
        }
    }

    /**
     * @notice Checks if the commitment does not exceed the goal of this sale.
     * @param _commitment Number of tokens to be commited.
     * @return committed The amount able to be purchased during a sale.
     */
    function calculateCommitment(uint256 _commitment) public view returns (uint256 committed) {
        uint256 tokens = _getTokenAmount(_commitment);
        uint256 tokensCommited = _getTokenAmount(uint256(marketStatus.commitmentsTotal));
        if (tokensCommited.add(tokens) > uint256(marketInfo.totalTokens)) {
            return _getTokenPrice(uint256(marketInfo.totalTokens).sub(tokensCommited));
        }
        return _commitment;
    }

    /**
     * @notice Updates commitment of the buyer and the amount raised, emits an event.
     * @param _addr Recipient of the token purchase.
     * @param _commitment Value in wei or token involved in the purchase.
     */
    function _addCommitment(address _addr, uint256 _commitment) internal {
        require(
            // solhint-disable-next-line not-rely-on-time
            block.timestamp >= uint256(marketInfo.startTime) && block.timestamp <= uint256(marketInfo.endTime),
            "outside auction hours"
        );
        require(_addr != address(0), "beneficiary is the zero address");
        require(!marketStatus.finalized, "Auction is finalized");
        uint256 newCommitment = commitments[_addr].add(_commitment);
        if (marketStatus.usePointList) {
            require(IPointList(pointList).hasPoints(_addr, newCommitment), "points is less than given number");
        }

        commitments[_addr] = newCommitment;

        /// @dev Update state.
        marketStatus.commitmentsTotal = BoringMath.to128(uint256(marketStatus.commitmentsTotal).add(_commitment));

        emit AddedCommitment(_addr, _commitment);
    }

    function withdrawTokens() public {
        withdrawTokens(msg.sender);
    }

    /**
     * @notice Withdraws bought tokens, or returns commitment if the sale is unsuccessful.
     * @dev Withdraw tokens only after crowdsale ends.
     * @param beneficiary Whose tokens will be withdrawn.
     */
    function withdrawTokens(address payable beneficiary) public nonReentrant {
        if (auctionSuccessful()) {
            require(marketStatus.finalized, "not finalized");
            /// @dev Successful auction! Transfer claimed tokens.
            uint256 tokensToClaim = tokensClaimable(beneficiary);
            require(tokensToClaim > 0, "no tokens to claim");
            claimed[beneficiary] = claimed[beneficiary].add(tokensToClaim);
            _safeTokenPayment(auctionToken, beneficiary, tokensToClaim);
        } else {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.
            // solhint-disable-next-line not-rely-on-time
            require(block.timestamp > uint256(marketInfo.endTime), "auction has not finished yet");
            uint256 accountBalance = commitments[beneficiary];
            commitments[beneficiary] = 0; // Stop multiple withdrawals and free some gas
            _safeTokenPayment(paymentCurrency, beneficiary, accountBalance);
        }
    }

    /**
     * @notice Adjusts users commitment depending on amount already claimed and unclaimed tokens left.
     * @return claimerCommitment How many tokens the user is able to claim.
     */
    function tokensClaimable(address _user) public view returns (uint256 claimerCommitment) {
        uint256 unclaimedTokens = IERC20(auctionToken).balanceOf(address(this));
        claimerCommitment = _getTokenAmount(commitments[_user]);
        claimerCommitment = claimerCommitment.sub(claimed[_user]);

        if (claimerCommitment > unclaimedTokens) {
            claimerCommitment = unclaimedTokens;
        }
    }

    //--------------------------------------------------------
    // Finalize Auction
    //--------------------------------------------------------

    /**
     * @notice Manually finalizes the Crowdsale.
     * @dev Must be called after crowdsale ends, to do some extra finalization work.
     * Calls the contracts finalization function.
     */
    function finalize() public nonReentrant {
        require(
            hasAdminRole(msg.sender) ||
                wallet == msg.sender ||
                hasSmartContractRole(msg.sender) ||
                finalizeTimeExpired(),
            "sender must be an admin"
        );
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "already finalized");
        MarketInfo storage info = marketInfo;
        require(info.totalTokens > 0, "Not initialized");
        require(auctionEnded(), "Has not finished yet");

        if (auctionSuccessful()) {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            _safeTokenPayment(paymentCurrency, wallet, uint256(status.commitmentsTotal));
            /// @dev Transfer unsold tokens to wallet.
            uint256 soldTokens = _getTokenAmount(uint256(status.commitmentsTotal));
            uint256 unsoldTokens = uint256(info.totalTokens).sub(soldTokens);
            if (unsoldTokens > 0) {
                _safeTokenPayment(auctionToken, wallet, unsoldTokens);
            }
        } else {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            _safeTokenPayment(auctionToken, wallet, uint256(info.totalTokens));
        }

        status.finalized = true;

        emit AuctionFinalized();
    }

    /**
     * @notice Cancel Auction
     * @dev Admin can cancel the auction before it starts
     */
    function cancelAuction() public nonReentrant {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "already finalized");
        require(uint256(status.commitmentsTotal) == 0, "Funds already raised");

        _safeTokenPayment(auctionToken, wallet, uint256(marketInfo.totalTokens));

        status.finalized = true;
        emit AuctionCancelled();
    }

    function tokenPrice() public view returns (uint256) {
        return uint256(marketPrice.rate);
    }

    function _getTokenPrice(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(uint256(marketPrice.rate)).div(AUCTION_TOKEN_DECIMALS);
    }

    function getTokenAmount(uint256 _amount) public view returns (uint256) {
        return _getTokenAmount(_amount);
    }

    /**
     * @notice Calculates the number of tokens to purchase.
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _amount Value in wei or token to be converted into tokens.
     * @return tokenAmount Number of tokens that can be purchased with the specified amount.
     */
    function _getTokenAmount(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(AUCTION_TOKEN_DECIMALS).div(uint256(marketPrice.rate));
    }

    /**
     * @notice Checks if the sale is open.
     * @return isOpen True if the crowdsale is open, false otherwise.
     */
    function isOpen() public view returns (bool) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp >= uint256(marketInfo.startTime) && block.timestamp <= uint256(marketInfo.endTime);
    }

    /**
     * @notice Checks if the sale minimum amount was raised.
     * @return auctionSuccessful True if the commitmentsTotal is equal or higher than goal.
     */
    function auctionSuccessful() public view returns (bool) {
        return uint256(marketStatus.commitmentsTotal) >= uint256(marketPrice.goal);
    }

    /**
     * @notice Checks if the sale has ended.
     * @return auctionEnded True if sold out or time has ended.
     */
    function auctionEnded() public view returns (bool) {
        return
            // solhint-disable-next-line not-rely-on-time
            block.timestamp > uint256(marketInfo.endTime) ||
            _getTokenAmount(uint256(marketStatus.commitmentsTotal) + 1) >= uint256(marketInfo.totalTokens);
    }

    /**
     * @notice Checks if the sale has been finalised.
     * @return bool True if sale has been finalised.
     */
    function finalized() public view returns (bool) {
        return marketStatus.finalized;
    }

    /**
     * @return True if 7 days have passed since the end of the auction
     */
    function finalizeTimeExpired() public view returns (bool) {
        // solhint-disable-next-line not-rely-on-time
        return uint256(marketInfo.endTime) + 7 days < block.timestamp;
    }

    //--------------------------------------------------------
    // Documents
    //--------------------------------------------------------

    function setDocument(string calldata _name, string calldata _data) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        _setDocument(_name, _data);
    }

    function setDocuments(string[] calldata _name, string[] calldata _data) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        uint256 numDocs = _name.length;
        for (uint256 i = 0; i < numDocs; i++) {
            _setDocument(_name[i], _data[i]);
        }
    }

    function removeDocument(string calldata _name) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        _removeDocument(_name);
    }

    //--------------------------------------------------------
    // Point Lists
    //--------------------------------------------------------

    function setList(address _list) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        _setList(_list);
    }

    function enableList(bool _status) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        marketStatus.usePointList = _status;

        emit AuctionPointListUpdated(pointList, marketStatus.usePointList);
    }

    function _setList(address _pointList) private {
        if (_pointList != address(0)) {
            pointList = _pointList;
            marketStatus.usePointList = true;
        }

        emit AuctionPointListUpdated(pointList, marketStatus.usePointList);
    }

    //--------------------------------------------------------
    // Setter Functions
    //--------------------------------------------------------

    /**
     * @notice Admin can set start and end time through this function.
     * @param _startTime Auction start time.
     * @param _endTime Auction end time.
     */
    function setAuctionTime(uint256 _startTime, uint256 _endTime) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        require(_startTime < 10000000000, "in seconds, not miliseconds");
        require(_endTime < 10000000000, "in seconds, not miliseconds");
        // solhint-disable-next-line not-rely-on-time
        require(_startTime >= block.timestamp, "start time is before current");
        require(_endTime > _startTime, "end must be older than start");

        require(marketStatus.commitmentsTotal == 0, "cannot have already started");

        marketInfo.startTime = BoringMath.to64(_startTime);
        marketInfo.endTime = BoringMath.to64(_endTime);

        emit AuctionTimeUpdated(_startTime, _endTime);
    }

    /**
     * @notice Admin can set auction price through this function.
     * @param _rate Price per token.
     * @param _goal Minimum amount raised and goal for the auction.
     */
    function setAuctionPrice(uint256 _rate, uint256 _goal) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        require(_goal > 0, "goal is 0");
        require(_rate > 0, "rate is 0");
        require(marketStatus.commitmentsTotal == 0, "cannot have already started");
        marketPrice.rate = BoringMath.to128(_rate);
        marketPrice.goal = BoringMath.to128(_goal);
        require(_getTokenAmount(_goal) <= uint256(marketInfo.totalTokens), "minimum target exceeds hard cap");

        emit AuctionPriceUpdated(_rate, _goal);
    }

    /**
     * @notice Admin can set the auction wallet through this function.
     * @param _wallet Auction wallet is where funds will be sent.
     */
    function setAuctionWallet(address payable _wallet) external {
        require(hasAdminRole(msg.sender), "sender must be an admin");
        require(_wallet != address(0), "wallet is the zero address");
        wallet = _wallet;

        emit AuctionWalletUpdated(_wallet);
    }

    //--------------------------------------------------------
    // Market Launchers
    //--------------------------------------------------------
    // solhint-disable-next-line no-empty-blocks
    function init(bytes calldata _data) external payable override {}

    /**
     * @notice Decodes and hands Crowdsale data to the initCrowdsale function.
     * @param _data Encoded data for initialization.
     */
    function initMarket(bytes calldata _data) public override {
        (
            address _funder,
            address _token,
            address _paymentCurrency,
            uint256 _totalTokens,
            uint256 _startTime,
            uint256 _endTime,
            uint256 _rate,
            uint256 _goal,
            address _admin,
            address _pointList,
            address payable _wallet
        ) = abi.decode(
                _data,
                (address, address, address, uint256, uint256, uint256, uint256, uint256, address, address, address)
            );

        initCrowdsale(
            _funder,
            _token,
            _paymentCurrency,
            _totalTokens,
            _startTime,
            _endTime,
            _rate,
            _goal,
            _admin,
            _pointList,
            _wallet
        );
    }

    /**
     * @notice Collects data to initialize the crowd sale.
     * @param _funder The address that funds the token for crowdsale.
     * @param _token Address of the token being sold.
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address.
     * @param _totalTokens The total number of tokens to sell in crowdsale.
     * @param _startTime Crowdsale start time.
     * @param _endTime Crowdsale end time.
     * @param _rate Number of token units a buyer gets per wei or token.
     * @param _goal Minimum amount of funds to be raised in weis or tokens.
     * @param _admin Address that can finalize crowdsale.
     * @param _pointList Address that will manage auction approvals.
     * @param _wallet Address where collected funds will be forwarded to.
     * @return _data All the data in bytes format.
     */
    function getCrowdsaleInitData(
        address _funder,
        address _token,
        address _paymentCurrency,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        uint256 _goal,
        address _admin,
        address _pointList,
        address payable _wallet
    ) external pure returns (bytes memory _data) {
        return
            abi.encode(
                _funder,
                _token,
                _paymentCurrency,
                _totalTokens,
                _startTime,
                _endTime,
                _rate,
                _goal,
                _admin,
                _pointList,
                _wallet
            );
    }

    function getBaseInformation() external view returns (address, uint64, uint64, bool) {
        return (auctionToken, marketInfo.startTime, marketInfo.endTime, marketStatus.finalized);
    }

    function getTotalTokens() external view returns (uint256) {
        return uint256(marketInfo.totalTokens);
    }
}

pragma solidity 0.6.12;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

pragma solidity 0.6.12;

interface IIHubMarket {
    function init(bytes calldata data) external payable;

    function initMarket(bytes calldata data) external;

    function marketTemplate() external view returns (uint256);
}

pragma solidity 0.6.12;

// ----------------------------------------------------------------------------
// Purple List interface
// ----------------------------------------------------------------------------

interface IPointList {
    function isInList(address account) external view returns (bool);

    function hasPoints(address account, uint256 amount) external view returns (bool);

    function setPoints(address[] memory accounts, uint256[] memory amounts) external;

    function initPointList(address accessControl) external;
}

pragma solidity 0.6.12;

import "../utils/EnumerableSet.sol";
import "../utils/Context.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct RoleData {
        EnumerableSet.AddressSet members;
        bytes32 adminRole;
    }

    mapping (bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members.contains(account);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roles[role].members.length();
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view returns (address) {
        return _roles[role].members.at(index);
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to grant");

        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to revoke");

        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        emit RoleAdminChanged(role, _roles[role].adminRole, adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (_roles[role].members.add(account)) {
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (_roles[role].members.remove(account)) {
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

pragma solidity 0.6.12;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity 0.6.12;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

pragma solidity 0.6.12;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly

// Audit on 5-Jan-2021 by Keno and BoringCrypto

import "./BoringERC20.sol";

contract BaseBoringBatchable {
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @notice Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    /// @param revertOnFail If True then reverts after a failed call and stops doing further calls.
    /// @return successes An array indicating the success of a call, mapped one-to-one to `calls`.
    /// @return results An array with the returned data of each function call, mapped one-to-one to `calls`.
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(
        bytes[] calldata calls,
        bool revertOnFail
    ) external payable returns (bool[] memory successes, bytes[] memory results) {
        successes = new bool[](calls.length);
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, _getRevertMsg(result));
            successes[i] = success;
            results[i] = result;
        }
    }
}

contract BoringBatchable is BaseBoringBatchable {
    /// @notice Call wrapper that performs `ERC20.permit` on `token`.
    /// Lookup `IERC20.permit`.
    // F6: Parameters can be used front-run the permit and the user's permit will fail (due to nonce or other revert)
    //     if part of a batch this could be used to grief once as the second call would not need the permit
    function permitToken(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        token.permit(from, to, amount, deadline, v, r, s);
    }
}

pragma solidity 0.6.12;
import "../interfaces/IERC20.sol";

// solhint-disable avoid-low-level-calls

library BoringERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant SIG_TRANSFER_FROM = 0x23b872dd; // transferFrom(address,address,uint256)

    /// @notice Provides a safe ERC20.symbol version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token symbol.
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    /// @notice Provides a safe ERC20.name version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token name.
    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
    /// @param token The address of the ERC-20 token contract.
    /// @return (uint8) Token decimals.
    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    /// @notice Provides a safe ERC20.transfer version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    /// @notice Provides a safe ERC20.transferFrom version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param from Transfer tokens from.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(SIG_TRANSFER_FROM, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}

pragma solidity 0.6.12;

/// @notice A library for performing overflow-/underflow-safe math,
/// updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math).
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b == 0 || (c = a * b) / b == a, "BoringMath: Mul Overflow");
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b > 0, "BoringMath: Div zero");
        c = a / b;
    }

    function to128(uint256 a) internal pure returns (uint128 c) {
        require(a <= uint128(-1), "BoringMath: uint128 Overflow");
        c = uint128(a);
    }

    function to64(uint256 a) internal pure returns (uint64 c) {
        require(a <= uint64(-1), "BoringMath: uint64 Overflow");
        c = uint64(a);
    }

    function to32(uint256 a) internal pure returns (uint32 c) {
        require(a <= uint32(-1), "BoringMath: uint32 Overflow");
        c = uint32(a);
    }

    function to16(uint256 a) internal pure returns (uint16 c) {
        require(a <= uint16(-1), "BoringMath: uint16 Overflow");
        c = uint16(a);
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint128.
library BoringMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint64.
library BoringMath64 {
    function add(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint32.
library BoringMath32 {
    function add(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint32.
library BoringMath16 {
    function add(uint16 a, uint16 b) internal pure returns (uint16 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint16 a, uint16 b) internal pure returns (uint16 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title Standard implementation of ERC1643 Document management
 */
contract Documents {
    struct Document {
        uint32 docIndex; // Store the document name indexes
        uint64 lastModified; // Timestamp at which document details was last modified
        string data; // data of the document that exist off-chain
    }

    // mapping to store the documents details in the document
    mapping(string => Document) internal _documents;
    // mapping to store the document name indexes
    mapping(string => uint32) internal _docIndexes;
    // Array use to store all the document name present in the contracts
    string[] public _docNames;

    // Document Events
    event DocumentRemoved(string indexed _name, string _data);
    event DocumentUpdated(string indexed _name, string _data);

    /**
     * @notice Used to attach a new document to the contract, or update the data or hash of an existing attached document
     * @dev Can only be executed by the owner of the contract.
     * @param _name Name of the document. It should be unique always
     * @param _data Off-chain data of the document from where it is accessible to investors/advisors to read.
     */
    function _setDocument(string calldata _name, string calldata _data) internal {
        require(bytes(_name).length > 0, "Zero name is not allowed");
        require(bytes(_data).length > 0, "Should not be a empty data");
        // Document storage document = _documents[_name];
        if (_documents[_name].lastModified == uint64(0)) {
            _docNames.push(_name);
            _documents[_name].docIndex = uint32(_docNames.length);
        }
        // solhint-disable-next-line not-rely-on-time
        _documents[_name] = Document(_documents[_name].docIndex, uint64(now), _data);
        emit DocumentUpdated(_name, _data);
    }

    /**
     * @notice Used to remove an existing document from the contract by giving the name of the document.
     * @dev Can only be executed by the owner of the contract.
     * @param _name Name of the document. It should be unique always
     */

    function _removeDocument(string calldata _name) internal {
        require(_documents[_name].lastModified != uint64(0), "Document should exist");
        uint32 index = _documents[_name].docIndex - 1;
        if (index != _docNames.length - 1) {
            _docNames[index] = _docNames[_docNames.length - 1];
            _documents[_docNames[index]].docIndex = index + 1;
        }
        _docNames.pop();
        emit DocumentRemoved(_name, _documents[_name].data);
        delete _documents[_name];
    }

    /**
     * @notice Used to return the details of a document with a known name (`string`).
     * @param _name Name of the document
     * @return string The data associated with the document.
     * @return uint256 the timestamp at which the document was last modified.
     */
    function getDocument(string calldata _name) external view returns (string memory, uint256) {
        return (_documents[_name].data, uint256(_documents[_name].lastModified));
    }

    /**
     * @notice Used to retrieve a full list of documents attached to the smart contract.
     * @return string List of all documents names present in the contract.
     */
    function getAllDocuments() external view returns (string[] memory) {
        return _docNames;
    }

    /**
     * @notice Used to retrieve the total documents in the smart contract.
     * @return uint256 Count of the document names present in the contract.
     */
    function getDocumentCount() external view returns (uint256) {
        return _docNames.length;
    }

    /**
     * @notice Used to retrieve the document name from index in the smart contract.
     * @return string Name of the document name.
     */
    function getDocumentName(uint256 _index) external view returns (string memory) {
        require(_index < _docNames.length, "Index out of bounds");
        return _docNames[_index];
    }
}

pragma solidity 0.6.12;

contract SafeTransfer {
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Event for token withdrawals.
    event TokensWithdrawn(address token, address to, uint256 amount);

    /// @dev Helper function to handle both ETH and ERC20 payments
    function _safeTokenPayment(address _token, address payable _to, uint256 _amount) internal {
        if (address(_token) == ETH_ADDRESS) {
            _safeTransferETH(_to, _amount);
        } else {
            _safeTransfer(_token, _to, _amount);
        }

        emit TokensWithdrawn(_token, _to, _amount);
    }

    /// @dev Helper function to handle both ETH and ERC20 payments
    function _tokenPayment(address _token, address payable _to, uint256 _amount) internal {
        if (address(_token) == ETH_ADDRESS) {
            _to.transfer(_amount);
        } else {
            _safeTransfer(_token, _to, _amount);
        }

        emit TokensWithdrawn(_token, _to, _amount);
    }

    /// @dev Transfer helper from UniswapV2 Router
    function _safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: APPROVE_FAILED");
    }

    /**
     * There are many non-compliant ERC20 tokens... this can handle most, adapted from UniSwap V2
     * Im trying to make it a habit to put external calls last (reentrancy)
     * You can put this in an internal function if you like.
     */
    function _safeTransfer(address token, address to, uint256 amount) internal virtual {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0xa9059cbb = bytes4(keccak256("transfer(address,uint256)"))
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        // solhint-disable-next-line reason-string
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 Transfer failed
    }

    function _safeTransferFrom(address token, address from, uint256 amount) internal virtual {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0x23b872dd = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0x23b872dd, from, address(this), amount)
        );
        // solhint-disable-next-line reason-string
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 TransferFrom failed
    }

    function _safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        // solhint-disable-next-line reason-string
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
    }

    function _safeTransferETH(address to, uint value) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{value: value}(new bytes(0));
        // solhint-disable-next-line reason-string
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }
}