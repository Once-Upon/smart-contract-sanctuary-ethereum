/*

      ___           ___           ___           ___           ___           ___                       ___
     /\  \         /\  \         /\  \         /\  \         |\__\         /\  \          ___        /\  \
    /::\  \       /::\  \       /::\  \        \:\  \        |:|  |       /::\  \        /\  \      /::\  \
   /:/\:\  \     /:/\:\  \     /:/\:\  \        \:\  \       |:|  |      /:/\:\  \       \:\  \    /:/\:\  \
  /::\~\:\  \   /::\~\:\  \   /::\~\:\  \       /::\  \      |:|__|__   /::\~\:\__\      /::\__\  /:/  \:\__\
 /:/\:\ \:\__\ /:/\:\ \:\__\ /:/\:\ \:\__\     /:/\:\__\     /::::\__\ /:/\:\ \:|__|  __/:/\/__/ /:/__/ \:|__|
 \/__\:\/:/  / \/__\:\/:/  / \/_|::\/:/  /    /:/  \/__/    /:/~~/~    \:\~\:\/:/  / /\/:/  /    \:\  \ /:/  /
      \::/  /       \::/  /     |:|::/  /    /:/  /        /:/  /       \:\ \::/  /  \::/__/      \:\  /:/  /
       \/__/        /:/  /      |:|\/__/     \/__/         \/__/         \:\/:/  /    \:\__\       \:\/:/  /
                   /:/  /       |:|  |                                    \::/__/      \/__/        \::/__/
                   \/__/         \|__|                                     ~~                        ~~

Anna Carroll for PartyDAO
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ Internal Imports ============
import {Party} from "./Party.sol";
import {IMarketWrapper} from "./market-wrapper/IMarketWrapper.sol";
import {Structs} from "./Structs.sol";

contract PartyBid is Party {
    // partyStatus Transitions:
    //   (1) PartyStatus.ACTIVE on deploy
    //   (2) PartyStatus.WON or PartyStatus.LOST on finalize()

    enum ExpireCapability {
        CanExpire, // The party can be expired
        BeforeExpiration, // The expiration date is in the future
        PartyOver, // The party is inactive, either won, or lost.
        CurrentlyWinning // The party is currently winning its auction
    }

    // ============ Internal Constants ============

    // PartyBid version 3
    uint16 public constant VERSION = 3;

    // ============ Public Not-Mutated Storage ============

    // market wrapper contract exposing interface for
    // market auctioning the NFT
    IMarketWrapper public marketWrapper;
    // ID of auction within market contract
    uint256 public auctionId;
    // the timestamp at which the Party can be expired.
    // This is mainly to prevent a party from collecting contributions
    // but never reaching the reserve price and having contributions
    // locked up indefinitely.  The party can still continue past
    // this time, but if someone calls `expire()` it will move to
    // the LOST state.
    uint256 public expiresAt;

    // ============ Public Mutable Storage ============

    // the highest bid submitted by PartyBid
    uint256 public highestBid;

    // ============ Events ============

    event Bid(uint256 amount);

    // @notice emitted when a party is won, lost, or expires.
    // @param result The `WON` or `LOST` final party state.
    // @param totalSpent The amount of eth actually spent, including the price of the NFT and the fee.
    // @param fee The eth fee paid to PartyDAO.
    // @param totalContributed Total eth deposited by all contributors, including eth not used in purchase.
    // @param expired True if the party expired before reaching a reserve / placing a bid.
    event Finalized(
        PartyStatus result,
        uint256 totalSpent,
        uint256 fee,
        uint256 totalContributed,
        bool expired
    );

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth
    ) Party(_partyDAOMultisig, _tokenVaultFactory, _weth) {}

    // ======== Initializer =========

    function initialize(
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        Structs.AddressAndAmount calldata _split,
        Structs.AddressAndAmount calldata _tokenGate,
        string memory _name,
        string memory _symbol,
        uint256 _durationInSeconds
    ) external initializer {
        // validate auction exists
        require(
            IMarketWrapper(_marketWrapper).auctionIdMatchesToken(
                _auctionId,
                _nftContract,
                _tokenId
            ),
            "PartyBid::initialize: auctionId doesn't match token"
        );
        // initialize & validate shared Party variables
        __Party_init(_nftContract, _split, _tokenGate, _name, _symbol);
        // verify token exists
        tokenId = _tokenId;
        require(
            _getOwner() != address(0),
            "PartyBid::initialize: NFT getOwner failed"
        );
        // set PartyBid-specific state variables
        marketWrapper = IMarketWrapper(_marketWrapper);
        auctionId = _auctionId;
        expiresAt = block.timestamp + _durationInSeconds;
    }

    // ======== External: Contribute =========

    /**
     * @notice Contribute to the Party's treasury
     * while the Party is still active
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function contribute() external payable nonReentrant {
        _contribute();
    }

    // ======== External: Bid =========

    /**
     * @notice Submit a bid to the Market
     * @dev Reverts if insufficient funds to place the bid and pay PartyDAO fees,
     * or if any external auction checks fail (including if PartyBid is current high bidder)
     * Emits a Bid event upon success.
     * Callable by any contributor
     */
    function bid() external nonReentrant {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBid::bid: auction not active"
        );
        require(
            totalContributed[msg.sender] > 0,
            "PartyBid::bid: only contributors can bid"
        );
        require(
            address(this) != marketWrapper.getCurrentHighestBidder(auctionId),
            "PartyBid::bid: already highest bidder"
        );
        require(
            !marketWrapper.isFinalized(auctionId),
            "PartyBid::bid: auction already finalized"
        );
        // get the minimum next bid for the auction
        uint256 _bid = marketWrapper.getMinimumBid(auctionId);
        // ensure there is enough ETH to place the bid including PartyDAO fee
        require(
            _bid <= getMaximumBid(),
            "PartyBid::bid: insufficient funds to bid"
        );
        // submit bid to Auction contract using delegatecall
        (bool success, bytes memory returnData) = address(marketWrapper)
            .delegatecall(
                abi.encodeWithSignature("bid(uint256,uint256)", auctionId, _bid)
            );
        require(
            success,
            string(
                abi.encodePacked(
                    "PartyBid::bid: place bid failed: ",
                    returnData
                )
            )
        );
        // update highest bid submitted & emit success event
        highestBid = _bid;
        emit Bid(_bid);
    }

    // ======== External: Finalize =========

    /**
     * @notice Finalize the state of the auction
     * @dev Emits a Finalized event upon success; callable by anyone
     */
    function finalize() external nonReentrant {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBid::finalize: auction not active"
        );
        // finalize auction if it hasn't already been done
        if (!marketWrapper.isFinalized(auctionId)) {
            marketWrapper.finalize(auctionId);
        }
        // after the auction has been finalized,
        // if the NFT is owned by the PartyBid, then the PartyBid won the auction
        address _owner = _getOwner();
        partyStatus = _owner == address(this)
            ? PartyStatus.WON
            : PartyStatus.LOST;
        uint256 _ethFee;
        // if the auction was won,
        if (partyStatus == PartyStatus.WON) {
            // record totalSpent,
            // send ETH fees to PartyDAO,
            // fractionalize the Token
            // send Token fees to PartyDAO & split proceeds to split recipient
            _ethFee = _closeSuccessfulParty(highestBid);
        }
        // set the contract status & emit result
        emit Finalized(
            partyStatus,
            totalSpent,
            _ethFee,
            totalContributedToParty,
            false
        );
    }

    // ======== External: Expire =========

    /**
     * @notice Determines whether a party can be expired. Any status other than `CanExpire` will
     * fail the `expire()` call.
     */
    function canExpire() public view returns (ExpireCapability) {
        if (partyStatus != PartyStatus.ACTIVE) {
            return ExpireCapability.PartyOver;
        }
        // In case there's some variation in how contracts define a "high bid"
        // we fall back to making sure none of the eth contributed is outstanding.
        // If we ever add any features that can send eth for any other purpose we
        // will revisit/remove this.
        if (
            address(this) == marketWrapper.getCurrentHighestBidder(auctionId) ||
            address(this).balance < totalContributedToParty
        ) {
            return ExpireCapability.CurrentlyWinning;
        }
        if (block.timestamp < expiresAt) {
            return ExpireCapability.BeforeExpiration;
        }

        return ExpireCapability.CanExpire;
    }

    function errorStringForCapability(ExpireCapability capability)
        internal
        pure
        returns (string memory)
    {
        if (capability == ExpireCapability.PartyOver)
            return "PartyBid::expire: auction not active";
        if (capability == ExpireCapability.CurrentlyWinning)
            return "PartyBid::expire: currently highest bidder";
        if (capability == ExpireCapability.BeforeExpiration)
            return "PartyBid::expire: expiration time in future";
        return "";
    }

    /**
     * @notice Expires an auction, moving it to LOST state and ending the ability to contribute.
     * @dev Emits a Finalized event upon success; callable by anyone once the expiration date passes.
     */
    function expire() external nonReentrant {
        ExpireCapability expireCapability = canExpire();
        require(
            expireCapability == ExpireCapability.CanExpire,
            errorStringForCapability(expireCapability)
        );
        partyStatus = PartyStatus.LOST;
        emit Finalized(partyStatus, 0, 0, totalContributedToParty, true);
    }

    // ======== Public: Utility Calculations =========

    /**
     * @notice The maximum bid that can be submitted
     * while paying the ETH fee to PartyDAO
     * @return _maxBid the maximum bid
     */
    function getMaximumBid() public view returns (uint256 _maxBid) {
        _maxBid = getMaximumSpend();
    }
}

/*
__/\\\\\\\\\\\\\_____________________________________________________________/\\\\\\\\\\\\________/\\\\\\\\\__________/\\\\\______
 _\/\\\/////////\\\__________________________________________________________\/\\\////////\\\____/\\\\\\\\\\\\\______/\\\///\\\____
  _\/\\\_______\/\\\__________________________________/\\\_________/\\\__/\\\_\/\\\______\//\\\__/\\\/////////\\\___/\\\/__\///\\\__
   _\/\\\\\\\\\\\\\/___/\\\\\\\\\_____/\\/\\\\\\\___/\\\\\\\\\\\___\//\\\/\\\__\/\\\_______\/\\\_\/\\\_______\/\\\__/\\\______\//\\\_
    _\/\\\/////////____\////////\\\___\/\\\/////\\\_\////\\\////_____\//\\\\\___\/\\\_______\/\\\_\/\\\\\\\\\\\\\\\_\/\\\_______\/\\\_
     _\/\\\_______________/\\\\\\\\\\__\/\\\___\///_____\/\\\__________\//\\\____\/\\\_______\/\\\_\/\\\/////////\\\_\//\\\______/\\\__
      _\/\\\______________/\\\/////\\\__\/\\\____________\/\\\_/\\___/\\_/\\\_____\/\\\_______/\\\__\/\\\_______\/\\\__\///\\\__/\\\____
       _\/\\\_____________\//\\\\\\\\/\\_\/\\\____________\//\\\\\___\//\\\\/______\/\\\\\\\\\\\\/___\/\\\_______\/\\\____\///\\\\\/_____
        _\///_______________\////////\//__\///______________\/////_____\////________\////////////_____\///________\///_______\/////_______

Anna Carroll for PartyDAO
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ External Imports: Inherited Contracts ============
// NOTE: we inherit from OpenZeppelin upgradeable contracts
// because of the proxy structure used for cheaper deploys
// (the proxies are NOT actually upgradeable)
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
// ============ External Imports: External Contracts & Contract Interfaces ============
import {IERC721VaultFactory} from "./external/interfaces/IERC721VaultFactory.sol";
import {ITokenVault} from "./external/interfaces/ITokenVault.sol";
import {IWETH} from "./external/interfaces/IWETH.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// ============ Internal Imports ============
import {Structs} from "./Structs.sol";

contract Party is ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
    // ============ Enums ============

    // State Transitions:
    //   (0) ACTIVE on deploy
    //   (1) WON if the Party has won the token
    //   (2) LOST if the Party is over & did not win the token
    enum PartyStatus {
        ACTIVE,
        WON,
        LOST
    }

    // ============ Structs ============

    struct Contribution {
        uint256 amount;
        // NOTE: This is stored to use for determining whether or not a
        //       contribution was actually used towards buying the NFT.
        uint256 previousTotalContributedToParty;
    }

    // ============ Internal Constants ============

    // tokens are minted at a rate of 1 ETH : 1000 tokens
    uint16 internal constant TOKEN_SCALE = 1000;
    // PartyDAO receives an ETH fee equal to 2.5% of the amount spent
    uint16 internal constant ETH_FEE_BASIS_POINTS = 250;
    // PartyDAO receives a token fee equal to 2.5% of the total token supply
    uint16 internal constant TOKEN_FEE_BASIS_POINTS = 250;
    // token is relisted on Fractional with an
    // initial reserve price equal to 2x the price of the token
    uint8 internal constant RESALE_MULTIPLIER = 2;

    // ============ Immutables ============

    // NOTE: Contract that is used to deploy new parties.
    address public immutable partyFactory;

    // NOTE: Has special privileges that it can use in-case of an emergency.
    address public immutable partyDAOMultisig;

    // NOTE: Used to deploy fractionalized NFT vaults through fractional.art.
    IERC721VaultFactory public immutable tokenVaultFactory;
    IWETH public immutable weth;

    // ============ Public Not-Mutated Storage ============

    // NFT contract
    IERC721Metadata public nftContract;
    // ID of token within NFT contract
    uint256 public tokenId;
    // Fractionalized NFT vault responsible for post-purchase experience
    ITokenVault public tokenVault;
    // the address that will receive a portion of the tokens
    // if the Party successfully buys the token
    address public splitRecipient;
    // percent of the total token supply
    // taken by the splitRecipient
    uint256 public splitBasisPoints;
    // address of token that users need to hold to contribute
    // address(0) if party is not token gated
    IERC20 public gatedToken;
    // amount of token that users need to hold to contribute
    // 0 if party is not token gated
    uint256 public gatedTokenAmount;
    // ERC-20 name and symbol for fractional tokens
    string public name;
    string public symbol;

    // ============ Public Mutable Storage ============

    // state of the contract
    PartyStatus public partyStatus;
    // total ETH deposited by all contributors
    uint256 public totalContributedToParty;
    // the total spent buying the token;
    // 0 if the NFT is not won; price of token + 2.5% PartyDAO fee if NFT is won
    uint256 public totalSpent;
    // contributor => array of Contributions
    mapping(address => Contribution[]) public contributions;
    // contributor => total amount contributed
    mapping(address => uint256) public totalContributed;
    // contributor => true if contribution has been claimed
    mapping(address => bool) public claimed;

    // ============ Events ============

    event Contributed(
        address indexed contributor,
        uint256 amount,
        uint256 previousTotalContributedToParty,
        uint256 totalFromContributor
    );

    event Claimed(
        address indexed contributor,
        uint256 totalContributed,
        uint256 excessContribution,
        uint256 tokenAmount
    );

    // ======== Modifiers =========

    modifier onlyPartyDAO() {
        require(
            msg.sender == partyDAOMultisig,
            "Party:: only PartyDAO multisig"
        );
        _;
    }

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth
    ) {
        partyFactory = msg.sender;
        partyDAOMultisig = _partyDAOMultisig;
        tokenVaultFactory = IERC721VaultFactory(_tokenVaultFactory);
        weth = IWETH(_weth);
    }

    // ======== Internal: Initialize =========

    function __Party_init(
        address _nftContract,
        Structs.AddressAndAmount calldata _split,
        Structs.AddressAndAmount calldata _tokenGate,
        string memory _name,
        string memory _symbol
    ) internal {
        require(
            msg.sender == partyFactory,
            "Party::__Party_init: only factory can init"
        );
        // if split is non-zero,
        if (_split.addr != address(0) && _split.amount != 0) {
            // validate that party split won't retain the total token supply
            uint256 _remainingBasisPoints = 10000 - TOKEN_FEE_BASIS_POINTS;
            require(
                _split.amount < _remainingBasisPoints,
                "Party::__Party_init: basis points can't take 100%"
            );
            splitBasisPoints = _split.amount;
            splitRecipient = _split.addr;
        }
        // if token gating is non-zero
        if (_tokenGate.addr != address(0) && _tokenGate.amount != 0) {
            // call totalSupply to verify that address is ERC-20 token contract
            IERC20(_tokenGate.addr).totalSupply();
            gatedToken = IERC20(_tokenGate.addr);
            gatedTokenAmount = _tokenGate.amount;
        }
        // initialize ReentrancyGuard and ERC721Holder
        __ReentrancyGuard_init();
        __ERC721Holder_init();
        // set storage variables
        nftContract = IERC721Metadata(_nftContract);
        name = _name;
        symbol = _symbol;
    }

    // ======== Internal: Contribute =========

    /**
     * @notice Contribute to the Party's treasury
     * while the Party is still active
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function _contribute() internal {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "Party::contribute: party not active"
        );
        address _contributor = msg.sender;
        uint256 _amount = msg.value;
        // if token gated, require that contributor has balance of gated tokens
        if (address(gatedToken) != address(0)) {
            require(
                gatedToken.balanceOf(_contributor) >= gatedTokenAmount,
                "Party::contribute: must hold tokens to contribute"
            );
        }
        require(_amount > 0, "Party::contribute: must contribute more than 0");
        // get the current contract balance
        uint256 _previousTotalContributedToParty = totalContributedToParty;
        // add contribution to contributor's array of contributions
        Contribution memory _contribution = Contribution({
            amount: _amount,
            previousTotalContributedToParty: _previousTotalContributedToParty
        });
        contributions[_contributor].push(_contribution);
        // add to contributor's total contribution
        totalContributed[_contributor] =
            totalContributed[_contributor] +
            _amount;
        // add to party's total contribution & emit event
        totalContributedToParty = _previousTotalContributedToParty + _amount;
        emit Contributed(
            _contributor,
            _amount,
            _previousTotalContributedToParty,
            totalContributed[_contributor]
        );
    }

    // ======== External: Claim =========

    /**
     * @notice Claim the tokens and excess ETH owed
     * to a single contributor after the party has ended
     * @dev Emits a Claimed event upon success
     * callable by anyone (doesn't have to be the contributor)
     * @param _contributor the address of the contributor
     */
    function claim(address _contributor) external nonReentrant {
        // ensure party has finalized
        require(
            partyStatus != PartyStatus.ACTIVE,
            "Party::claim: party not finalized"
        );
        // ensure contributor submitted some ETH
        require(
            totalContributed[_contributor] != 0,
            "Party::claim: not a contributor"
        );
        // ensure the contributor hasn't already claimed
        require(
            !claimed[_contributor],
            "Party::claim: contribution already claimed"
        );
        // mark the contribution as claimed
        claimed[_contributor] = true;
        // calculate the amount of fractional NFT tokens owed to the user
        // based on how much ETH they contributed towards the party,
        // and the amount of excess ETH owed to the user
        (uint256 _tokenAmount, uint256 _ethAmount) = getClaimAmounts(
            _contributor
        );
        // transfer tokens to contributor for their portion of ETH used
        _transferTokens(_contributor, _tokenAmount);
        // if there is excess ETH, send it back to the contributor
        _transferETHOrWETH(_contributor, _ethAmount);
        emit Claimed(
            _contributor,
            totalContributed[_contributor],
            _ethAmount,
            _tokenAmount
        );
    }

    // ======== External: Emergency Escape Hatches (PartyDAO Multisig Only) =========

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can use emergencyWithdrawEth to withdraw
     * ETH stuck in the contract
     */
    function emergencyWithdrawEth(uint256 _value) external onlyPartyDAO {
        _transferETHOrWETH(partyDAOMultisig, _value);
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can use emergencyCall to call an external contract
     * (e.g. to withdraw a stuck NFT or stuck ERC-20s)
     */
    function emergencyCall(address _contract, bytes memory _calldata)
        external
        onlyPartyDAO
        returns (bool _success, bytes memory _returnData)
    {
        (_success, _returnData) = _contract.call(_calldata);
        require(_success, string(_returnData));
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can force the Party to finalize with status LOST
     * (e.g. if finalize is not callable)
     */
    function emergencyForceLost() external onlyPartyDAO {
        // set partyStatus to LOST
        partyStatus = PartyStatus.LOST;
    }

    // ======== Public: Utility Calculations =========

    /**
     * @notice Convert ETH value to equivalent token amount
     */
    function valueToTokens(uint256 _value)
        public
        pure
        returns (uint256 _tokens)
    {
        _tokens = _value * TOKEN_SCALE;
    }

    /**
     * @notice The maximum amount that can be spent by the Party
     * while paying the ETH fee to PartyDAO
     * @return _maxSpend the maximum spend
     */
    function getMaximumSpend() public view returns (uint256 _maxSpend) {
        _maxSpend =
            (totalContributedToParty * 10000) /
            (10000 + ETH_FEE_BASIS_POINTS);
    }

    /**
     * @notice Calculate the amount of fractional NFT tokens owed to the contributor
     * based on how much ETH they contributed towards buying the token,
     * and the amount of excess ETH owed to the contributor
     * based on how much ETH they contributed *not* used towards buying the token
     * @param _contributor the address of the contributor
     * @return _tokenAmount the amount of fractional NFT tokens owed to the contributor
     * @return _ethAmount the amount of excess ETH owed to the contributor
     */
    function getClaimAmounts(address _contributor)
        public
        view
        returns (uint256 _tokenAmount, uint256 _ethAmount)
    {
        require(
            partyStatus != PartyStatus.ACTIVE,
            "Party::getClaimAmounts: party still active; amounts undetermined"
        );
        uint256 _totalContributed = totalContributed[_contributor];
        if (partyStatus == PartyStatus.WON) {
            // calculate the amount of this contributor's ETH
            // that was used to buy the token
            uint256 _totalEthUsed = totalEthUsed(_contributor);
            if (_totalEthUsed > 0) {
                _tokenAmount = valueToTokens(_totalEthUsed);
            }
            // the rest of the contributor's ETH should be returned
            _ethAmount = _totalContributed - _totalEthUsed;
        } else {
            // if the token wasn't bought, no ETH was spent;
            // all of the contributor's ETH should be returned
            _ethAmount = _totalContributed;
        }
    }

    /**
     * @notice Calculate the total amount of a contributor's funds
     * that were used towards the buying the token
     * @dev always returns 0 until the party has been finalized
     * @param _contributor the address of the contributor
     * @return _total the sum of the contributor's funds that were
     * used towards buying the token
     */
    function totalEthUsed(address _contributor)
        public
        view
        returns (uint256 _total)
    {
        require(
            partyStatus != PartyStatus.ACTIVE,
            "Party::totalEthUsed: party still active; amounts undetermined"
        );
        // load total amount spent once from storage
        uint256 _totalSpent = totalSpent;
        // get all of the contributor's contributions
        Contribution[] memory _contributions = contributions[_contributor];
        for (uint256 i = 0; i < _contributions.length; i++) {
            // calculate how much was used from this individual contribution
            uint256 _amount = _ethUsed(_totalSpent, _contributions[i]);
            // if we reach a contribution that was not used,
            // no subsequent contributions will have been used either,
            // so we can stop calculating to save some gas
            if (_amount == 0) break;
            _total = _total + _amount;
        }
    }

    // ============ Internal ============

    function _closeSuccessfulParty(uint256 _nftCost)
        internal
        returns (uint256 _ethFee)
    {
        // calculate PartyDAO fee & record total spent
        _ethFee = _getEthFee(_nftCost);
        totalSpent = _nftCost + _ethFee;
        // transfer ETH fee to PartyDAO
        _transferETHOrWETH(partyDAOMultisig, _ethFee);
        // deploy fractionalized NFT vault
        // and mint fractional ERC-20 tokens
        _fractionalizeNFT(_nftCost);
    }

    /**
     * @notice Calculate ETH fee for PartyDAO
     * NOTE: Remove this fee causes a critical vulnerability
     * allowing anyone to exploit a Party via price manipulation.
     * See Security Review in README for more info.
     * @return _fee the portion of _amount represented by scaling to ETH_FEE_BASIS_POINTS
     */
    function _getEthFee(uint256 _amount) internal pure returns (uint256 _fee) {
        _fee = (_amount * ETH_FEE_BASIS_POINTS) / 10000;
    }

    /**
     * @notice Calculate token amount for specified token recipient
     * @return _totalSupply the total token supply
     * @return _partyDAOAmount the amount of tokens for partyDAO fee,
     * which is equivalent to TOKEN_FEE_BASIS_POINTS of total supply
     * @return _splitRecipientAmount the amount of tokens for the token recipient,
     * which is equivalent to splitBasisPoints of total supply
     */
    function _getTokenInflationAmounts(uint256 _amountSpent)
        internal
        view
        returns (
            uint256 _totalSupply,
            uint256 _partyDAOAmount,
            uint256 _splitRecipientAmount
        )
    {
        // the token supply will be inflated to provide a portion of the
        // total supply for PartyDAO, and a portion for the splitRecipient
        uint256 inflationBasisPoints = TOKEN_FEE_BASIS_POINTS +
            splitBasisPoints;
        _totalSupply = valueToTokens(
            (_amountSpent * 10000) / (10000 - inflationBasisPoints)
        );
        // PartyDAO receives TOKEN_FEE_BASIS_POINTS of the total supply
        _partyDAOAmount = (_totalSupply * TOKEN_FEE_BASIS_POINTS) / 10000;
        // splitRecipient receives splitBasisPoints of the total supply
        _splitRecipientAmount = (_totalSupply * splitBasisPoints) / 10000;
    }

    /**
     * @notice Query the NFT contract to get the token owner
     * @dev nftContract must implement the ERC-721 token standard exactly:
     * function ownerOf(uint256 _tokenId) external view returns (address);
     * See https://eips.ethereum.org/EIPS/eip-721
     * @dev Returns address(0) if NFT token or NFT contract
     * no longer exists (token burned or contract self-destructed)
     * @return _owner the owner of the NFT
     */
    function _getOwner() internal view returns (address _owner) {
        (bool _success, bytes memory _returnData) = address(nftContract)
            .staticcall(abi.encodeWithSignature("ownerOf(uint256)", tokenId));
        if (_success && _returnData.length > 0) {
            _owner = abi.decode(_returnData, (address));
        }
    }

    /**
     * @notice Upon winning the token, transfer the NFT
     * to fractional.art vault & mint fractional ERC-20 tokens
     */
    function _fractionalizeNFT(uint256 _amountSpent) internal {
        // approve fractionalized NFT Factory to withdraw NFT
        nftContract.approve(address(tokenVaultFactory), tokenId);
        // Party "votes" for a reserve price on Fractional
        // equal to 2x the price of the token
        uint256 _listPrice = RESALE_MULTIPLIER * _amountSpent;
        // users receive tokens at a rate of 1:TOKEN_SCALE for each ETH they contributed that was ultimately spent
        // partyDAO receives a percentage of the total token supply equivalent to TOKEN_FEE_BASIS_POINTS
        // splitRecipient receives a percentage of the total token supply equivalent to splitBasisPoints
        (
            uint256 _tokenSupply,
            uint256 _partyDAOAmount,
            uint256 _splitRecipientAmount
        ) = _getTokenInflationAmounts(totalSpent);
        // deploy fractionalized NFT vault
        uint256 vaultNumber = tokenVaultFactory.mint(
            name,
            symbol,
            address(nftContract),
            tokenId,
            _tokenSupply,
            _listPrice,
            0
        );
        // store token vault address to storage
        tokenVault = ITokenVault(tokenVaultFactory.vaults(vaultNumber));
        // transfer curator to null address (burn the curator role)
        tokenVault.updateCurator(address(0));
        // transfer tokens to PartyDAO multisig
        _transferTokens(partyDAOMultisig, _partyDAOAmount);
        // transfer tokens to token recipient
        if (splitRecipient != address(0)) {
            _transferTokens(splitRecipient, _splitRecipientAmount);
        }
    }

    // ============ Internal: Claim ============

    /**
     * @notice Calculate the amount of a single Contribution
     * that was used towards buying the token
     * @param _contribution the Contribution struct
     * @return the amount of funds from this contribution
     * that were used towards buying the token
     */
    function _ethUsed(uint256 _totalSpent, Contribution memory _contribution)
        internal
        pure
        returns (uint256)
    {
        if (
            _contribution.previousTotalContributedToParty +
                _contribution.amount <=
            _totalSpent
        ) {
            // contribution was fully used
            return _contribution.amount;
        } else if (
            _contribution.previousTotalContributedToParty < _totalSpent
        ) {
            // contribution was partially used
            return _totalSpent - _contribution.previousTotalContributedToParty;
        }
        // contribution was not used
        return 0;
    }

    // ============ Internal: TransferTokens ============

    /**
     * @notice Transfer tokens to a recipient
     * @param _to recipient of tokens
     * @param _value amount of tokens
     */
    function _transferTokens(address _to, uint256 _value) internal {
        // skip if attempting to send 0 tokens
        if (_value == 0) {
            return;
        }
        // guard against rounding errors;
        // if token amount to send is greater than contract balance,
        // send full contract balance
        uint256 _partyBalance = tokenVault.balanceOf(address(this));
        if (_value > _partyBalance) {
            _value = _partyBalance;
        }
        tokenVault.transfer(_to, _value);
    }

    // ============ Internal: TransferEthOrWeth ============

    /**
     * @notice Attempt to transfer ETH to a recipient;
     * if transferring ETH fails, transfer WETH insteads
     * @param _to recipient of ETH or WETH
     * @param _value amount of ETH or WETH
     */
    function _transferETHOrWETH(address _to, uint256 _value) internal {
        // skip if attempting to send 0 ETH
        if (_value == 0) {
            return;
        }
        // guard against rounding errors;
        // if ETH amount to send is greater than contract balance,
        // send full contract balance
        if (_value > address(this).balance) {
            _value = address(this).balance;
        }
        // Try to transfer ETH to the given recipient.
        if (!_attemptETHTransfer(_to, _value)) {
            // If the transfer fails, wrap and send as WETH
            weth.deposit{value: _value}();
            weth.transfer(_to, _value);
            // At this point, the recipient can unwrap WETH.
        }
    }

    /**
     * @notice Attempt to transfer ETH to a recipient
     * @dev Sending ETH is not guaranteed to succeed
     * this method will return false if it fails.
     * We will limit the gas used in transfers, and handle failure cases.
     * @param _to recipient of ETH
     * @param _value amount of ETH
     */
    function _attemptETHTransfer(address _to, uint256 _value)
        internal
        returns (bool)
    {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title IMarketWrapper
 * @author Anna Carroll
 * @notice IMarketWrapper provides a common interface for
 * interacting with NFT auction markets.
 * Contracts can abstract their interactions with
 * different NFT markets using IMarketWrapper.
 * NFT markets can become compatible with any contract
 * using IMarketWrapper by deploying a MarketWrapper contract
 * that implements this interface using the logic of their Market.
 *
 * WARNING: MarketWrapper contracts should NEVER write to storage!
 * When implementing a MarketWrapper, exercise caution; a poorly implemented
 * MarketWrapper contract could permanently lose access to the NFT or user funds.
 */
interface IMarketWrapper {
    /**
     * @notice Given the auctionId, nftContract, and tokenId, check that:
     * 1. the auction ID matches the token
     * referred to by tokenId + nftContract
     * 2. the auctionId refers to an *ACTIVE* auction
     * (e.g. an auction that will accept bids)
     * within this market contract
     * 3. any additional validation to ensure that
     * a PartyBid can bid on this auction
     * (ex: if the market allows arbitrary bidding currencies,
     * check that the auction currency is ETH)
     * Note: This function probably should have been named "isValidAuction"
     * @dev Called in PartyBid.sol in `initialize` at line 174
     * @return TRUE if the auction is valid
     */
    function auctionIdMatchesToken(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId
    ) external view returns (bool);

    /**
     * @notice Calculate the minimum next bid for this auction.
     * PartyBid contracts always submit the minimum possible
     * bid that will be accepted by the Market contract.
     * usually, this is either the reserve price (if there are no bids)
     * or a certain percentage increase above the current highest bid
     * @dev Called in PartyBid.sol in `bid` at line 251
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 auctionId) external view returns (uint256);

    /**
     * @notice Query the current highest bidder for this auction
     * It is assumed that there is always 1 winning highest bidder for an auction
     * This is used to ensure that PartyBid cannot outbid itself if it is already winning
     * @dev Called in PartyBid.sol in `bid` at line 241
     * @return highest bidder
     */
    function getCurrentHighestBidder(uint256 auctionId)
        external
        view
        returns (address);

    /**
     * @notice Submit bid to Market contract
     * @dev Called in PartyBid.sol in `bid` at line 259
     */
    function bid(uint256 auctionId, uint256 bidAmount) external;

    /**
     * @notice Determine whether the auction has been finalized
     * Used to check if it is still possible to bid
     * And to determine whether the PartyBid should finalize the auction
     * @dev Called in PartyBid.sol in `bid` at line 247
     * @dev and in `finalize` at line 288
     * @return TRUE if the auction has been finalized
     */
    function isFinalized(uint256 auctionId) external view returns (bool);

    /**
     * @notice Finalize the results of the auction
     * on the Market contract
     * It is assumed  that this operation is performed once for each auction,
     * that after it is done the auction is over and the NFT has been
     * transferred to the auction winner.
     * @dev Called in PartyBid.sol in `finalize` at line 289
     */
    function finalize(uint256 auctionId) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface Structs {
    struct AddressAndAmount {
        address addr;
        uint256 amount;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721ReceiverUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

  /**
   * @dev Implementation of the {IERC721Receiver} interface.
   *
   * Accepts all token transfers.
   * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
   */
contract ERC721HolderUpgradeable is Initializable, IERC721ReceiverUpgradeable {
    function __ERC721Holder_init() internal initializer {
        __ERC721Holder_init_unchained();
    }

    function __ERC721Holder_init_unchained() internal initializer {
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    uint256[50] private __gap;
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IERC721VaultFactory {
    /// @notice the mapping of vault number to vault address
    function vaults(uint256) external returns (address);

    /// @notice the function to mint a new vault
    /// @param _name the desired name of the vault
    /// @param _symbol the desired sumbol of the vault
    /// @param _token the ERC721 token address fo the NFT
    /// @param _id the uint256 ID of the token
    /// @param _listPrice the initial price of the NFT
    /// @return the ID of the vault
    function mint(string memory _name, string memory _symbol, address _token, uint256 _id, uint256 _supply, uint256 _listPrice, uint256 _fee) external returns(uint256);
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ITokenVault {
    /// @notice allow curator to update the curator address
    /// @param _curator the new curator
    function updateCurator(address _curator) external;

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
      * @dev Safely transfers `tokenId` token from `from` to `to`.
      *
      * Requirements:
      *
      * - `from` cannot be the zero address.
      * - `to` cannot be the zero address.
      * - `tokenId` token must exist and be owned by `from`.
      * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
      * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
      *
      * Emits a {Transfer} event.
      */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}