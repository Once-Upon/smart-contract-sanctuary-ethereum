// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/INormalPoolDeployer.sol";
import "./interfaces/INormalPoolFactory.sol";
import "./PoolBaseDerivativeNFT.sol";

contract NormalPoolNFT is PoolBaseDerivativeNFT {

    struct TokenInfo {
        uint tokenId;
        address owner;
        uint256 createdAt;
        uint256 lastCollectedAt;
    }

    // make offer data structure
    struct Offer {
        uint256 offerId;
        address bidder;
        uint256 offerAmount;
        bool isCancelled;
    }

    struct StakedToken {
        address staker;
        uint256 tokenId;
    }

    struct Staker {
        // Amount of tokens staked by the staker
        uint256 amountStaked;
        // Staked token ids
        StakedToken[] stakedTokens;
        // Last time of the rewards were calculated for this user
        uint256 timeOfLastUpdate;
    }

    // init to 1
    uint256 public offerIdToUse = 1;
    uint256 public highestOffer;
    uint256 public highestOfferId;
    mapping(address => uint256) public userOfferCount;
    mapping(uint256 => Offer) public getOfferById;
    uint256[] public activeOfferIds;

    mapping(uint256 => TokenInfo) public tokenInfoMap;
    mapping(address => uint256) public depositBalances;  // The deposit balance map
    // Mapping of User Address to Staker info
    mapping(address => Staker) public stakers; // The NFT pool staker
    // Mapping of Token Id to staker. Made for the SC to remember
    // who to send back the ERC721 Token to.
    mapping(uint256 => address) public stakerAddress;
    address[] public stakerArray;
    uint256 public totalNFTStakedInPool;
    uint256 public lastUpdatedBlockTimeStamp;
    uint256 public unclaimedProfit;
    // the number of upgraded license we have;
    uint256 public totalUpgradedNFTReleased;
    mapping(uint256 => bool) isUpgraded;
    mapping(uint256 => uint256) upgradeValidUntil;
    uint256[] upgradedTokenList;

    mapping(address => uint256) public tokenOwnerCounterMap;
    // note that 0 is a valid tokenid. Check the number of tokenId the user owns first before return the tokenId below.
    mapping(address => uint256) public ownerToTokenIdMap;
    uint256[] tokenIdsUnclaimed;
    uint32 public taxNumerator = 100;
    uint32 public taxDenominator = 10000;
    event Deposit(address indexed to, uint256 indexed amount);
    event Withdraw(address indexed from, uint256 indexed amount);

    event TokenStaked(address indexed from, uint256 indexed tokenId);
    event TokenUnstaked(address indexed to, uint256 indexed tokenId);

    event MintItem(
        bytes32 indexed to,
        uint256 indexed tokenId,
        uint256 currentBalance,
        uint256 blockTimeStamp
    );

    event OfferPlaced(
        address indexed from,
        uint256 indexed amount,
        uint256 indexed offerId
    );

    event OfferCancelled(
        uint256 indexed OfferId
    );

    event OfferAccepted(
        uint256 indexed OfferId,
        address indexed seller,
        address indexed buyer,
        uint256 offerAmount
    );

    event RewardDistributed(
        address indexed sender
    );

    event OfferRefund(
        address indexed user,
        uint256 indexed refundAmount
    );

    event TokenUpgraded(
        address indexed tokenUpgraded,
        uint256 indexed EthAmount,
        uint256 indexed tokenId
    );

    // set contract name and ticker.
    constructor(address delegate_)
        PoolBaseDerivativeNFT("FroopylandNormalPool", "FNP", delegate_)
    {
        (factory, NFTCollectionAddress) = INormalPoolDeployer(
            msg.sender
        ).parameters();
        SpanningERC721 originalNFTContract = SpanningERC721(NFTCollectionAddress);
    }

    function upgrade(uint256 tokenId) public payable {
        require(upgradedTokenList.length <= 15, "Only 15 licenses are allowed to be upgraded.");
        require(INormalPoolFactory(factory).whiteListMap(ownerOf(tokenId)), "Not Selected WhiteList Builder.");
        require(msg.value >= highestOffer * taxNumerator * 365 days / taxDenominator, "Not sufficient fund for the upgrade.");

        isUpgraded[tokenId] = true;
        upgradeValidUntil[tokenId] = block.timestamp + 365 days;
        upgradedTokenList.push(tokenId);

        emit TokenUpgraded(msg.sender, msg.value, tokenId);
    }

    // no UI interface, called by the team.
    function downgrade() public payable {
        uint256 countToRemove = 0;
        for(uint256 i = 0; i < upgradedTokenList.length; i++) {
            if(block.timestamp > upgradeValidUntil[upgradedTokenList[i]]) {
                countToRemove++;
                delete upgradeValidUntil[upgradedTokenList[i]];
                delete isUpgraded[upgradedTokenList[i]];
                upgradedTokenList[upgradedTokenList.length - countToRemove] = upgradedTokenList[i];
            }
        }

        for(uint256 i = 0; i < countToRemove; i++) {
            upgradedTokenList.pop();
        }
    }

    // Asset owners calls this with Ether to deposit tax payments for all owned assets
    function deposit() public payable {
        depositBalances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // Withdraw tax payments, omitted for simplicity
    function withdraw(uint256 amount) public {
        require(depositBalances[msg.sender] >= amount, "not enough balance.");
        depositBalances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function stake(uint256 _tokenId) external nonReentrant {
        calculateRewards();
        _stake(msg.sender, _tokenId);
    }

    function batchStake(uint256[] calldata _tokenIds) external nonReentrant {
        calculateRewards();
        for(uint256 i = 0; i < _tokenIds.length; i++) {
            _stake(msg.sender, _tokenIds[i]);
        }
    }

    function _stake(address _user, uint256 _tokenId) internal {
        // Wallet must own the token they are trying to stake
        require(
            IERC721(NFTCollectionAddress).ownerOf(_tokenId) == _user,
            "You don't own this token!"
        );

        // Transfer the token from the wallet to the Smart contract
        IERC721(NFTCollectionAddress).transferFrom(_user, address(this), _tokenId);

        // Create StakedToken
        StakedToken memory stakedToken = StakedToken(_user, _tokenId);

        // Add the token to the stakedTokens array
        stakers[_user].stakedTokens.push(stakedToken);

        // Increment the amount staked for this wallet
        stakers[_user].amountStaked++;
        totalNFTStakedInPool++;
        if(stakers[_user].amountStaked == 1) {
            stakerArray.push(_user);
        }
        // Update the mapping of the tokenId to the staker's address
        stakerAddress[_tokenId] = _user;
        // Update the timeOfLastUpdate for the staker
        stakers[_user].timeOfLastUpdate = block.timestamp;

        emit TokenStaked(_user, _tokenId);
    }

    function indexOfStaker(address searchFor) private returns (uint256) {
        for (uint256 i = 0; i < stakerArray.length; i++) {
            if (stakerArray[i] == searchFor) {
                return i;
            }
        }
        return stakerArray.length + 1; // not found
    }

    function unstake(uint256 _tokenId) external nonReentrant {
        calculateRewards();
        _unstake(msg.sender, _tokenId);
    }

    function batchUnstake(uint256[] calldata _tokenIds) external nonReentrant {
        //TODO: claim reward
        calculateRewards();
        for(uint256 i = 0; i < _tokenIds.length; i++) {
            _unstake(msg.sender, _tokenIds[i]);
        }
    }

    // Check if user has any ERC721 Tokens Staked and if they tried to withdraw,
    // calculate the rewards and store them in the unclaimedRewards
    // decrement the amountStaked of the user and transfer the ERC721 token back to them
    function _unstake(address _user, uint256 _tokenId) internal {
        // Make sure the user has at least one token staked before withdrawing
        require(
            stakers[_user].amountStaked > 0,
            "You have no tokens staked"
        );

        // Wallet must own the token they are trying to withdraw
        require(stakerAddress[_tokenId] == _user, "You don't own this token!");

        // Update the rewards for this user, as the amount of rewards decreases with less tokens.

        // Find the index of this token id in the stakedTokens array
        uint256 index = 0;
        for (uint256 i = 0; i < stakers[_user].stakedTokens.length; i++) {
            if (stakers[_user].stakedTokens[i].tokenId == _tokenId
                &&
                stakers[_user].stakedTokens[i].staker != address(0)
            ) {
                index = i;
                break;
            }
        }

        // Set this token's staker to be address 0 to mark it as no longer staked
        stakers[_user].stakedTokens[index].staker = address(0);
        // Update the timeOfLastUpdate for the withdrawer
        stakers[_user].timeOfLastUpdate = block.timestamp;

        // Decrement the amount staked for this wallet
        stakers[_user].amountStaked--;
        if(stakers[_user].amountStaked == 0) {
            uint256 index = indexOfStaker(_user);
            require(index != stakerArray.length + 1, "staker array search failed. Revert Tx.");

            stakerArray[index] = stakerArray[stakerArray.length - 1];
            stakerArray.pop();
        }

        totalNFTStakedInPool--;
        // Update the mapping of the tokenId to the be address(0) to indicate that the token is no longer staked
        stakerAddress[_tokenId] = address(0);

        // Transfer the token back to the withdrawer
        IERC721(NFTCollectionAddress).transferFrom(address(this), _user, _tokenId);

        emit TokenUnstaked(_user, _tokenId);
    }

    function mintItem()
    public
    payable
    returns (uint256 tokenId)
    {
        require(tokenOwnerCounterMap[msg.sender] == 0, "Tx Revert: You already own a license.");
        if(tokenIdsUnclaimed.length > 0) {
            tokenId = tokenIdsUnclaimed[tokenIdsUnclaimed.length - 1];
            transferFrom(address(this), msg.sender, tokenId);
            tokenIdsUnclaimed.pop();
        } else {
            tokenId = _mintItem();
        }

        tokenInfoMap[tokenId] = TokenInfo(
            tokenId,
            msg.sender,
            block.timestamp,
            block.timestamp
        );
        // TODO: If the license one per user and is not transferable, then we can just use counter map to reduce search.
         tokenOwnerCounterMap[msg.sender]++;
         ownerToTokenIdMap[msg.sender] = tokenId;
        _removeUserOffers(msg.sender);

        emit MintItem(
            spanningMsgSender(),
            tokenId,
            depositBalances[msg.sender],
            block.timestamp
        );

        return tokenId;
    }

    function makeOffer()
    public
    payable
    returns (uint256 offerId) {
        require(msg.value > 0, "Invalid Offer.");
        Offer memory newOffer = Offer(offerIdToUse, msg.sender, msg.value, false);
        getOfferById[offerIdToUse] = newOffer;
        activeOfferIds.push(offerIdToUse);
        offerId = offerIdToUse;
        offerIdToUse++;
        if(msg.value > highestOffer) {
            calculateRewards();
            highestOffer = newOffer.offerAmount;
            highestOfferId = newOffer.offerId;
        }

        userOfferCount[msg.sender]++;
        emit OfferPlaced(msg.sender, msg.value, offerId);
        return offerId;
    }

    function acceptOffer()
    public
    payable
    returns (uint256 offerId) {
        require(isApprovedForAll(msg.sender, address(this)), "Please approve the contract to transfer your token first.");
        require(tokenOwnerCounterMap[msg.sender] == 1, "You don't own a license");
        uint256 tokenId = ownerToTokenIdMap[msg.sender];
        Offer storage currOffer = getOfferById[highestOfferId];
        currOffer.isCancelled = true;
        offerId =  highestOfferId;
        uint256 indexToFind = _locateOffer(highestOfferId);

        // pop the cancelled offer Id;
        activeOfferIds[indexToFind] = activeOfferIds[activeOfferIds.length - 1];
        activeOfferIds.pop();

        payable(msg.sender).transfer(currOffer.offerAmount);
        transferFrom(msg.sender, currOffer.bidder, tokenId);
        tokenInfoMap[tokenId] = TokenInfo(
            tokenId,
            currOffer.bidder,
            block.timestamp,
            block.timestamp
        );
        delete tokenOwnerCounterMap[msg.sender];
        delete ownerToTokenIdMap[msg.sender];
        tokenOwnerCounterMap[currOffer.bidder]++;
        ownerToTokenIdMap[currOffer.bidder] = tokenId;

        _removeUserOffers(currOffer.bidder);

        emit OfferAccepted(offerId, msg.sender, currOffer.bidder, currOffer.offerAmount);
        return offerId;
    }

    function cancelOffer(uint256 offerId)
    public
    payable
    returns (uint256) {
        require(getOfferById[offerId].bidder == msg.sender && getOfferById[offerId].isCancelled == false, "invalid Cancel request.");
        Offer storage currOffer = getOfferById[offerId];
        currOffer.isCancelled = true;

        uint256 indexToFind = _locateOffer(offerId);

        // pop the cancelled offer Id;
        activeOfferIds[indexToFind] = activeOfferIds[activeOfferIds.length - 1];
        activeOfferIds.pop();

        userOfferCount[msg.sender]--;
        emit OfferCancelled(offerId);
        return offerId;
    }

    // The internal function to remove the offer from active list, and update the corresponding offer vars.
    function _locateOffer(uint256 _offerId) internal returns(uint256 indexToFind) {
        indexToFind = activeOfferIds.length + 1;
        uint256 highestOfferId = 0;

        //TODO: Update profit && find highest bid (find better ways)
        calculateRewards();

        for(uint256 i = 0; i < activeOfferIds.length; i++) {
            if(activeOfferIds[i] == _offerId) {
                indexToFind = i;
            } else if(getOfferById[activeOfferIds[i]].offerAmount > getOfferById[highestOfferId].offerAmount) {
                highestOfferId = activeOfferIds[i];
                highestOffer = getOfferById[activeOfferIds[i]].offerAmount;
            }
        }

        // the index is not in the activeOfferId array.
        require(indexToFind != activeOfferIds.length + 1, "Revert Tx: unable to locate the offer Id.");

        return indexToFind;
    }

    function _removeUserOffers(address user) internal returns(uint256 offerRefund) {
        uint256 offerCount = 0;
        offerRefund = 0;
        uint256 currActiveLength = activeOfferIds.length;
        for(uint256 i = 0; i < currActiveLength; i++) {
            if(getOfferById[activeOfferIds[i]].bidder == user) {
                offerCount++;
                activeOfferIds[i] = activeOfferIds[currActiveLength - offerCount];
                getOfferById[activeOfferIds[i]].isCancelled = true;
                offerRefund += getOfferById[activeOfferIds[i]].offerAmount;
            }
        }

        for(uint256 i = 0; i < offerCount; i++) {
            activeOfferIds.pop();
        }

        payable(user).transfer(offerRefund);
        delete userOfferCount[user];
        emit OfferRefund(user, offerRefund);
    }

    function _calculateReward(uint256 tokenId)
    internal
    returns(uint256) {
        uint tax = taxOwed(tokenId);
        if(tax == 0) {
            return 0;
        }

        address tokenOwner = ownerOf(tokenId);
        tokenInfoMap[tokenId].lastCollectedAt = block.timestamp;
        uint256 tokenReward;
        if (tax <= depositBalances[tokenOwner]) {
            depositBalances[tokenOwner] -= tax;
            tokenReward = tax;
        } else {
            tokenReward = depositBalances[tokenOwner];
            depositBalances[tokenOwner] = 0;
            transferFrom(tokenOwner, address(this), tokenId);
            delete tokenOwnerCounterMap[tokenOwner];
            delete ownerToTokenIdMap[tokenOwner];
            delete tokenInfoMap[tokenId];
        }
        return tokenReward;
    }

    function calculateRewards()
    public
    {
        if(block.timestamp == lastUpdatedBlockTimeStamp) {
            return;
        }

        uint256 totalRewards = 0;
        // calculate total rewards
        for(uint256 i = 0; i < getCounterValue(); i++) {
            if(_exists(i)) {
                totalRewards += _calculateReward(i);
            }
        }

        // TODO: if there is no staked nft then no profit should be calculated.
        // But how do we handle the eth?
        if(totalNFTStakedInPool == 0) {
            unclaimedProfit += totalRewards;
            lastUpdatedBlockTimeStamp = block.timestamp;
            return;
        }

        // calculate reward per NFT
        uint256 individualRewards = (totalRewards + unclaimedProfit) / totalNFTStakedInPool;
        unclaimedProfit = 0;

        // distribute to the holders (TODO: move to database or research to find gas efficient way)
        for(uint256 i = 0; i < stakerArray.length; i++) {
            depositBalances[stakerArray[i]] += (individualRewards * stakers[stakerArray[i]].amountStaked);
            stakers[stakerArray[i]].timeOfLastUpdate = block.timestamp;
        }

        lastUpdatedBlockTimeStamp = block.timestamp;
        emit RewardDistributed(msg.sender);
    }

    function getOffers() public view returns(Offer[] memory offerArray) {
        offerArray = new Offer[](activeOfferIds.length);
        for(uint256 i = 0; i < activeOfferIds.length; i++) {
            offerArray[i] = getOfferById[activeOfferIds[i]];
        }
        return offerArray;
    }

    // View getter: to get the user staked NFTs in the current pool
    function getStakedTokens(address _user) public view returns (StakedToken[] memory) {
        // Check if we know this user
        if (stakers[_user].amountStaked > 0) {
            // Return all the tokens in the stakedToken Array for this user that are not -1
            StakedToken[] memory _stakedTokens = new StakedToken[](stakers[_user].amountStaked);
            uint256 _index = 0;

            for (uint256 j = 0; j < stakers[_user].stakedTokens.length; j++) {
                if (stakers[_user].stakedTokens[j].staker != (address(0))) {
                    _stakedTokens[_index] = stakers[_user].stakedTokens[j];
                    _index++;
                }
            }

            return _stakedTokens;
        }

        // Otherwise, return empty array
        else {
            return new StakedToken[](0);
        }
    }

    function getStakedInfoArray() public view returns(StakedToken[] memory) {
            StakedToken[] memory result = new StakedToken[](totalNFTStakedInPool);
        uint256 count = 0;
        for(uint256 i = 0; i < stakerArray.length; i++) {
            for(uint256 j = 0; j < stakers[stakerArray[i]].amountStaked; j++) {
                result[count] = stakers[stakerArray[i]].stakedTokens[j];
            }
        }
        return result;
    }

    function taxOwed(uint256 tokenId) public view returns (uint256) {
        if(!_exists(tokenId) || ownerOf(tokenId) == address(this) || isUpgraded[tokenId] == true) {
            return 0;
        }

        // Accumulate tax every day
        return
        ((block.timestamp - tokenInfoMap[tokenId].lastCollectedAt)) *
        highestOffer *
        taxNumerator /
        taxDenominator /
        1 days;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @title An interface for a contract that is capable of deploying derivative nft license contract
/// @notice A contract that constructs a contract must implement this to pass arguments to the contract
/// @dev This is used to avoid having constructor arguments in the contract, which results in the init code hash
/// of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
interface INormalPoolDeployer {
    /// @notice Get the parameters to be used in constructing the pool, set transiently during contract creation.
    /// @dev Called by the pool constructor to fetch the parameters of the contract
    /// Returns factory The factory address
    /// Returns originalNFT The NFT address
    /// Returns tokenId The token of the nft address
    function parameters()
        external
        view
        returns (address factory, address originalNFT);

    function deploy(
        address factory,
        address originalNFTAddress,
        address spanningLabDelegate
    ) external returns (address licenseAddress);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface INormalPoolFactory {

    function whiteListMap(
        address user
    ) external returns (bool isWhiteListed);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@spanning/contracts/token/ERC721/extensions/SpanningERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Base64.sol";

/*, IERC721Receiver*/
abstract contract PoolBaseDerivativeNFT is SpanningERC721Enumerable, ReentrancyGuard {
    using Counters for Counters.Counter;

    address public factory;
    address public NFTCollectionAddress; // The pool related NFT collection address
    uint256 public maxTokenNum = 100;
    uint256 public maxUpgradeNum = 10;
    Counters.Counter public _tokenCounter;

    // set contract name, ticker, and delegate address
    constructor(string memory name,
                string memory ticker,
                address delegate_)
                SpanningERC721(name, ticker, delegate_)
    { }

    function getCounterValue() public view returns (uint256) {
        return _tokenCounter.current();
    }

    function _mintItem() internal returns (uint256) {
        uint256 newTokenId = _tokenCounter.current();
        require(
            newTokenId < maxTokenNum,
            "new tokenId reach the max limit, invalid"
        );
        _mint(spanningMsgSender(), newTokenId);
        _tokenCounter.increment();
        return newTokenId;
    }
}

// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright (C) 2022 Spanning Labs Inc.

pragma solidity ^0.8.0;

import "../SpanningERC721.sol";
import "./ISpanningERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract SpanningERC721Enumerable is
    SpanningERC721,
    ISpanningERC721Enumerable
{
    // Mapping from owner to list of owned token IDs
    mapping(bytes32 => mapping(uint256 => uint256)) private ownedTokens_;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private ownedTokensIndex_;

    // Array with all token ids, used for enumeration
    uint256[] private allTokens_;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private allTokensIndex_;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, SpanningERC721)
        returns (bool)
    {
        return
            interfaceId == type(ISpanningERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        bytes32 derivedSpanningAddress = getAddressFromLegacy(owner);

        require(
            index < SpanningERC721.balanceOf(derivedSpanningAddress),
            "ERC721Enumerable: owner index out of bounds"
        );
        return ownedTokens_[derivedSpanningAddress][index];
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(bytes32 owner, uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < SpanningERC721.balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        return ownedTokens_[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return allTokens_.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < SpanningERC721Enumerable.totalSupply(),
            "ERC721Enumerable: global index out of bounds"
        );
        return allTokens_[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(senderAddress, receiverAddress, tokenId);

        if (senderAddress == bytes32(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (senderAddress != receiverAddress) {
            _removeTokenFromOwnerEnumeration(senderAddress, tokenId);
        }
        if (receiverAddress == bytes32(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (receiverAddress != senderAddress) {
            _addTokenToOwnerEnumeration(receiverAddress, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param receiverAddress address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(
        bytes32 receiverAddress,
        uint256 tokenId
    ) private {
        uint256 length = SpanningERC721.balanceOf(receiverAddress);
        ownedTokens_[receiverAddress][length] = tokenId;
        ownedTokensIndex_[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        allTokensIndex_[tokenId] = allTokens_.length;
        allTokens_.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `ownedTokensIndex_` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the ownedTokens_ array.
     * @param senderAddress address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(
        bytes32 senderAddress,
        uint256 tokenId
    ) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = SpanningERC721.balanceOf(senderAddress) - 1;
        uint256 tokenIndex = ownedTokensIndex_[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedTokens_[senderAddress][lastTokenIndex];

            ownedTokens_[senderAddress][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ownedTokensIndex_[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete ownedTokensIndex_[tokenId];
        delete ownedTokens_[senderAddress][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the allTokens_ array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = allTokens_.length - 1;
        uint256 tokenIndex = allTokensIndex_[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = allTokens_[lastTokenIndex];

        allTokens_[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        allTokensIndex_[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete allTokensIndex_[tokenId];
        allTokens_.pop();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
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

pragma solidity ^0.8.0;

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}

// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright (C) 2022 Spanning Labs Inc.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../../ISpanningDelegate.sol";
import "./ISpanningERC721.sol";
import "../../SpanningUtils.sol";
import "../../Spanning.sol";

/**
 * @dev Implementation of the {ISpanningERC721} interface.
 */
abstract contract SpanningERC721 is
    Spanning,
    Context,
    ERC165,
    ISpanningERC721,
    IERC721Metadata
{
    // This allows us to efficiently unpack data in our address specification.
    using SpanningAddress for bytes32;

    using Address for address;
    using Strings for uint256;

    // Standard metadata: token name
    string private name_;

    // Standard metadata: token symbol
    string private symbol_;

    // Mapping from token ID to owner address
    mapping(uint256 => bytes32) private owners_;

    // Mapping owner address to token count
    mapping(bytes32 => uint256) private balances_;

    // Mapping from token ID to approved address
    mapping(uint256 => bytes32) private tokenApprovals_;

    // Mapping from sender to receiver approvals
    mapping(bytes32 => mapping(bytes32 => bool)) private operatorApprovals_;

    // Convenience modifier for common bounds checks
    modifier onlyOwnerOrApproved(uint256 tokenId) {
        require(
            _isApprovedOrOwner(spanningMsgSender(), tokenId),
            "onlyOwnerOrApproved: bad role"
        );
        _;
    }

    /**
     * @dev Creates the instance and assigns required values.
     *
     * @param nameIn - Desired name for the token collection
     * @param symbolIn - Desired symbol for the token collection
     * @param delegate - Legacy (local) address for the Spanning Delegate
     */
    constructor(
        string memory nameIn,
        string memory symbolIn,
        address delegate
    ) Spanning(delegate) {
        name_ = nameIn;
        symbol_ = symbolIn;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address accountLegacyAddress)
        public
        view
        virtual
        override
        returns (uint256)
    {
        bytes32 accountAddress = getAddressFromLegacy(accountLegacyAddress);
        return balanceOf(accountAddress);
    }

    /**
     * @dev Returns the number of tokens owned by an account.
     *
     * @param accountAddress - Address to be queried
     *
     * @return uint256 - Number of tokens owned by an account
     */
    function balanceOf(bytes32 accountAddress)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            accountAddress.valid(),
            "ERC721: balance query for the invalid address"
        );
        return balances_[accountAddress];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        bytes32 ownerAddress = ownerOfSpanning(tokenId);
        // To prevent incorrect data leakage, we return the legacy address
        // only if that user is local to the current domain.
        bytes4 ownerDomain = getDomainFromAddress(ownerAddress);
        require(
            ownerDomain == getDomain(),
            "ERC721: remote account requesting legacy address"
        );
        return getLegacyFromAddress(ownerAddress);
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOfSpanning(uint256 tokenId)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        bytes32 ownerAddress = owners_[tokenId];
        require(
            ownerAddress.valid(),
            "ERC721: owner query for nonexistent token"
        );
        return ownerAddress;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return name_;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return symbol_;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address receiverLegacyAddress, uint256 tokenId)
        public
        virtual
        override
    {
        bytes32 receiverAddress = getAddressFromLegacy(receiverLegacyAddress);
        approve(receiverAddress, tokenId);
    }

    /**
     * @dev Sets a token allowance for a pair of addresses (sender and receiver).
     *
     * @param receiverAddress - Address of the allowance receiver
     * @param tokenId - Token allowance to be approved
     */
    function approve(bytes32 receiverAddress, uint256 tokenId)
        public
        virtual
        override
        onlyOwnerOrApproved(tokenId)
    {
        bytes32 tokenOwner = SpanningERC721.ownerOfSpanning(tokenId);
        require(
            receiverAddress != tokenOwner,
            "ERC721: approval to current owner"
        );
        _approve(receiverAddress, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        bytes32 ownerAddress = getApprovedSpanning(tokenId);
        // To prevent incorrect data leakage, we return the legacy address
        // only if that user is local to the current domain.
        bytes4 ownerDomain = getDomainFromAddress(ownerAddress);
        require(
            ownerDomain == getDomain(),
            "ERC721: remote account requesting legacy address"
        );
        return getLegacyFromAddress(ownerAddress);
    }

    function getApprovedSpanning(uint256 tokenId)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        require(
            _exists(tokenId),
            "ERC721: approved query for nonexistent token"
        );

        return tokenApprovals_[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(
        address receiverLegacyAddress,
        bool shouldApprove
    ) public virtual override {
        bytes32 receiverAddress = getAddressFromLegacy(receiverLegacyAddress);
        setApprovalForAll(receiverAddress, shouldApprove);
    }

    /**
     * @dev Allows an account to have control over another account's tokens.
     *
     * @param receiverAddress - Address of the allowance receiver (gains control)
     * @param shouldApprove - Whether to approve or revoke the approval
     */
    function setApprovalForAll(bytes32 receiverAddress, bool shouldApprove)
        public
        virtual
        override
    {
        _setApprovalForAll(receiverAddress, shouldApprove);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(
        address senderLegacyAddress,
        address receiverLegacyAddress
    ) public view virtual override returns (bool) {
        bytes32 senderAddress = getAddressFromLegacy(senderLegacyAddress);
        bytes32 receiverAddress = getAddressFromLegacy(receiverLegacyAddress);
        return isApprovedForAll(senderAddress, receiverAddress);
    }

    /**
     * @dev Indicates if an account has total control over another's assets.
     *
     * @param senderAddress - Address of the allowance sender (cede control)
     * @param receiverAddress - Address of the allowance receiver (gains control)
     *
     * @return bool - Indicates whether the account is approved for all
     */
    function isApprovedForAll(bytes32 senderAddress, bytes32 receiverAddress)
        public
        view
        virtual
        override
        returns (bool)
    {
        return operatorApprovals_[senderAddress][receiverAddress];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address senderLegacyAddress,
        address receiverLegacyAddress,
        uint256 tokenId
    ) public virtual override {
        bytes32 senderAddress = getAddressFromLegacy(senderLegacyAddress);
        bytes32 receiverAddress = getAddressFromLegacy(receiverLegacyAddress);
        transferFrom(senderAddress, receiverAddress, tokenId);
    }

    /**
     * @dev Moves requested tokens between accounts.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     */
    function transferFrom(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) public virtual override onlyOwnerOrApproved(tokenId) {
        _transfer(senderAddress, receiverAddress, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address senderLegacyAddress,
        address receiverLegacyAddress,
        uint256 tokenId
    ) public virtual override {
        bytes32 senderAddress = getAddressFromLegacy(senderLegacyAddress);
        bytes32 receiverAddress = getAddressFromLegacy(receiverLegacyAddress);
        safeTransferFrom(senderAddress, receiverAddress, tokenId, "");
    }

    /**
     * @dev Safely moves requested tokens between accounts.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     */
    function safeTransferFrom(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(senderAddress, receiverAddress, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address senderLegacyAddress,
        address receiverLegacyAddress,
        uint256 tokenId,
        bytes memory payload
    ) public virtual override {
        bytes32 senderAddress = getAddressFromLegacy(senderLegacyAddress);
        bytes32 receiverAddress = getAddressFromLegacy(receiverLegacyAddress);
        safeTransferFrom(senderAddress, receiverAddress, tokenId, payload);
    }

    /**
     * @dev Safely moves requested tokens between accounts, including data.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     * @param payload - Additional, unstructured data to be included
     */
    function safeTransferFrom(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId,
        bytes memory payload
    ) public virtual override onlyOwnerOrApproved(tokenId) {
        _safeTransfer(senderAddress, receiverAddress, tokenId, payload);
    }

    /**
     * @dev Safely transfers a token between accounts, checking for ERC721 validity.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     * @param payload - Additional, unstructured data to be included
     */
    function _safeTransfer(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId,
        bytes memory payload
    ) internal virtual {
        _transfer(senderAddress, receiverAddress, tokenId);
        require(
            _checkOnERC721Received(
                senderAddress,
                receiverAddress,
                tokenId,
                payload
            ),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Checks if the token exists (has been minted but not burned).
     *
     * @param tokenId - Token to be checked
     *
     * @return bool - Whether the token exists
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return owners_[tokenId].valid();
    }

    /**
     * @dev Checks if the account is authorized to spend the token.
     *
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be checked
     *
     * @return bool - Whether the account is authorized to spend the token
     */
    function _isApprovedOrOwner(bytes32 receiverAddress, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        require(
            _exists(tokenId),
            "ERC721: operator query for nonexistent token"
        );
        bytes32 tokenOwner = SpanningERC721.ownerOfSpanning(tokenId);
        return (receiverAddress == tokenOwner ||
            isApprovedForAll(tokenOwner, receiverAddress) ||
            getApprovedSpanning(tokenId) == receiverAddress);
    }

    /**
     * @dev Safely mints a new token to an account
     *
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be minted
     */
    function _safeMint(bytes32 receiverAddress, uint256 tokenId)
        internal
        virtual
    {
        _safeMint(receiverAddress, tokenId, "");
    }

    /**
     * @dev Safely mints a new token to an account
     *
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be minted
     * @param payload - Additional, unstructured data to be included
     */
    function _safeMint(
        bytes32 receiverAddress,
        uint256 tokenId,
        bytes memory payload
    ) internal virtual {
        _mint(receiverAddress, tokenId);
        require(
            _checkOnERC721Received(
                SpanningAddress.invalidAddress(),
                receiverAddress,
                tokenId,
                payload
            ),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints a new token to an account
     *
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be minted
     */
    function _mint(bytes32 receiverAddress, uint256 tokenId) internal virtual {
        require(receiverAddress.valid(), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(
            SpanningAddress.invalidAddress(),
            receiverAddress,
            tokenId
        );

        balances_[receiverAddress] += 1;
        owners_[tokenId] = receiverAddress;

        emit SpanningTransfer(
            SpanningAddress.invalidAddress(),
            receiverAddress,
            tokenId
        );
        emit Transfer(
            address(0),
            getLegacyFromAddress(receiverAddress),
            tokenId
        );

        _afterTokenTransfer(
            SpanningAddress.invalidAddress(),
            receiverAddress,
            tokenId
        );
    }

    /**
     * @dev Burns the token
     *
     * @param tokenId - Token to be burned
     */
    function _burn(uint256 tokenId) internal virtual {
        bytes32 tokenOwner = SpanningERC721.ownerOfSpanning(tokenId);

        _beforeTokenTransfer(
            tokenOwner,
            SpanningAddress.invalidAddress(),
            tokenId
        );

        // Clear approvals
        _approve(SpanningAddress.invalidAddress(), tokenId);

        balances_[tokenOwner] -= 1;
        delete owners_[tokenId];

        emit SpanningTransfer(
            tokenOwner,
            SpanningAddress.invalidAddress(),
            tokenId
        );
        emit Transfer(getLegacyFromAddress(tokenOwner), address(0), tokenId);

        _afterTokenTransfer(
            tokenOwner,
            SpanningAddress.invalidAddress(),
            tokenId
        );
    }

    /**
     * @dev Transfers the token between accounts
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     */
    function _transfer(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) internal virtual {
        require(
            SpanningERC721.ownerOfSpanning(tokenId).equals(senderAddress),
            "ERC721: transfer from incorrect owner"
        );
        require(
            receiverAddress.valid(),
            "ERC721: transfer to the zero address"
        );

        _beforeTokenTransfer(senderAddress, receiverAddress, tokenId);

        // Clear approvals from the previous owner
        _approve(SpanningAddress.invalidAddress(), tokenId);

        balances_[senderAddress] -= 1;
        balances_[receiverAddress] += 1;
        owners_[tokenId] = receiverAddress;

        emit Transfer(
            getLegacyFromAddress(senderAddress),
            getLegacyFromAddress(receiverAddress),
            tokenId
        );
        emit SpanningTransfer(senderAddress, receiverAddress, tokenId);

        _afterTokenTransfer(senderAddress, receiverAddress, tokenId);
    }

    /**
     * @dev Sets a token allowance for a pair of addresses (sender and receiver).
     *
     * @param receiverAddress - Address of the allowance receiver
     * @param tokenId - Token allowance to be approved
     */
    function _approve(bytes32 receiverAddress, uint256 tokenId)
        internal
        virtual
    {
        tokenApprovals_[tokenId] = receiverAddress;
        bytes32 owner = SpanningERC721.ownerOfSpanning(tokenId);
        emit Approval(
            getLegacyFromAddress(owner),
            getLegacyFromAddress(receiverAddress),
            tokenId
        );
        emit SpanningApproval(owner, receiverAddress, tokenId);
    }

    /**
     * @dev Allows an account to have control over another account's tokens.
     *
     * @param receiverAddress - Address of the allowance receiver (gains control)
     * @param shouldApprove - Whether to approve or revoke the approval
     */
    function _setApprovalForAll(bytes32 receiverAddress, bool shouldApprove)
        internal
        virtual
    {
        require(
            !spanningMsgSender().equals(receiverAddress),
            "ERC721: approve to caller"
        );
        operatorApprovals_[spanningMsgSender()][
            receiverAddress
        ] = shouldApprove;
        emit ApprovalForAll(
            getLegacyFromAddress(spanningMsgSender()),
            getLegacyFromAddress(receiverAddress),
            shouldApprove
        );
        emit SpanningApprovalForAll(
            spanningMsgSender(),
            receiverAddress,
            shouldApprove
        );
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     * @param payload - Additional, unstructured data to be included
     *
     * @return bool - If call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId,
        bytes memory payload
    ) private returns (bool) {
        address senderLegacyAddress = getLegacyFromAddress(senderAddress);
        address receiverLegacyAddress = getLegacyFromAddress(receiverAddress);

        // Only dispatch if the destination is a contract and also on the same domain
        if (
            receiverLegacyAddress.isContract() &&
            getDomainFromAddress(receiverAddress) == getDomain()
        ) {
            // TODO(jade) Implement SpanningERC721Receiver
            // https://linear.app/spanninglabs/issue/ENG-135/implement-spanningerc721receiver-for-safe-transfers
            try
                IERC721Receiver(receiverLegacyAddress).onERC721Received(
                    getLegacyFromAddress(spanningMsgSender()),
                    senderLegacyAddress,
                    tokenId,
                    payload
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens.
     *
     * @param senderAddress - Address initiating the transfer
     * @param receiverAddress - Address receiving the transfer
     * @param tokenId - Token to be transferred
     */
    function _beforeTokenTransfer(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any burn of tokens.
     *
     * @param senderAddress - Address sending tokens to burn
     * @param receiverAddress - Unused
     * @param tokenId - Token to be burned
     */
    function _afterTokenTransfer(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface ISpanningERC721Enumerable is IERC721Enumerable {
    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(bytes32 ownerAddress, uint256 index)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright (C) 2022 Spanning Labs Inc.

pragma solidity ^0.8.0;

/**
 * @dev Interface of a Delegate in the Spanning Protocol.
 */
interface ISpanningDelegate {
    /**
     * @return bytes4 - Domain of the delegate.
     */
    function getDomain() external view returns (bytes4);

    /**
     * @dev Sets the deployable status to true.
     */
    function makeDeployable() external;

    /**
     * @dev Sets the deployable status to false.
     */
    function revokeDeployable() external;

    /**
     * @return bool - Deployable status of the delegate.
     */
    function isDeployable() external view returns (bool);

    /**
     * @return bool - If the current stack has set Spanning Info correctly
     */
    function isValidData() external view returns (bool);

    /**
     * @return bytes32 - Address of the entity that contacted the delegate.
     */
    function currentSenderAddress() external view returns (bytes32);

    /**
     * @return bytes32 - Address of the originator of the transaction.
     */
    function currentTxnSenderAddress() external view returns (bytes32);

    /**
     * @dev Used by authorized middleware to run a transaction on this domain.
     *
     * Note: We currently we assume the contract owner == authorized address
     *
     * @param programAddress - Address to be called
     * @param msgSenderAddress - Address of the entity that contacted the delegate
     * @param txnSenderAddress - Address of the originator of the transaction
     * @param payload - ABI-encoding of the desired function call
     */
    function spanningCall(
        bytes32 programAddress,
        bytes32 msgSenderAddress,
        bytes32 txnSenderAddress,
        bytes calldata payload
    ) external;

    /**
     * @dev Allows a user to request a call over authorized middleware nodes.
     *
     * Note: This can result in either a local or cross-domain transaction.
     * Note: Dispatch uses EVM Events as a signal to our middleware.
     *
     * @param programAddress - Address to be called
     * @param payload - ABI-encoding of the desired function call
     */
    function makeRequest(bytes32 programAddress, bytes calldata payload)
        external;

    /**
     * @dev Emitted when payment is received in local gas coin.
     *
     * @param addr - Legacy (local) address that sent payment
     * @param value - Value (in wei) that was sent
     */
    event Received(address addr, uint256 value);

    /**
     * @dev Emitted when a Spanning transaction stays on the current domain.
     *
     * @param programAddress - Address to be called
     * @param msgSenderAddress - Address of the entity that contacted the delegate
     * @param txnSenderAddress - Address of the originator of the transaction
     * @param payload - ABI-encoding of the desired function call
     * @param returnData - Information from the result of the function call
     */
    event LocalRequest(
        bytes32 indexed programAddress,
        bytes32 indexed msgSenderAddress,
        bytes32 indexed txnSenderAddress,
        bytes payload,
        bytes returnData
    );

    /**
     * @dev Emitted when a Spanning transaction must leave the current domain.
     *
     * Note: Spanning's middleware nodes are subscribed to this event.
     *
     * @param programAddress - Address to be called
     * @param msgSenderAddress - Address of the entity that contacted the delegate
     * @param txnSenderAddress - Address of the originator of the transaction
     * @param payload - ABI-encoding of the desired function call
     */
    event SpanningRequest(
        bytes32 indexed programAddress,
        bytes32 indexed msgSenderAddress,
        bytes32 indexed txnSenderAddress,
        bytes payload
    );

    /**
     * @dev Emitted when deployable status is set
     *
     * @param deployable - whether the delegate is deployable or not
     */
    event Deployable(
        bool indexed deployable
    );

    /**
     * @dev Emitted when SPAN contract is set
     *
     * @param spanAddr - the address of the set SPAN contract
     */
    event SetSPAN(
        address indexed spanAddr
    );
}

// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright (C) 2022 Spanning Labs Inc.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Interface of ERC721 in the Spanning Protocol
 *
 * NOTE: Spanning uses receiverAddress in favor of operatorAddress.
 * This pattern matches the language used to represent approvals elsewhere.
 */
interface ISpanningERC721 is IERC721 {
    /**
     * @dev Returns the number of tokens owned by an account.
     *
     * @param accountAddress - Address to be queried
     *
     * @return uint256 - Number of tokens owned by an account
     */
    function balanceOf(bytes32 accountAddress) external view returns (uint256);

    /**
     * @dev Returns the owner of the queried token.
     *
     * @param tokenId - Token to be queried
     *
     * @return bytes32 - Address of the owner of the queried token
     */
    function ownerOfSpanning(uint256 tokenId) external view returns (bytes32);

    /**
     * @dev Safely moves requested tokens between accounts, including data.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     * @param payload - Additional, unstructured data to be included
     */
    function safeTransferFrom(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId,
        bytes calldata payload
    ) external;

    /**
     * @dev Safely moves requested tokens between accounts.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     */
    function safeTransferFrom(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) external;

    /**
     * @dev Moves requested tokens between accounts.
     *
     * @param senderAddress - Address of the sender
     * @param receiverAddress - Address of the receiver
     * @param tokenId - Token to be transferred
     */
    function transferFrom(
        bytes32 senderAddress,
        bytes32 receiverAddress,
        uint256 tokenId
    ) external;

    /**
     * @dev Sets a token allowance for a pair of addresses (sender and receiver).
     *
     * @param receiverAddress - Address of the allowance receiver
     * @param tokenId - Token allowance to be approved
     */
    function approve(bytes32 receiverAddress, uint256 tokenId) external;

    /**
     * @dev Allows an account to have control over another account's tokens.
     *
     * @param receiverAddress - Address of the allowance receiver (gains control)
     * @param shouldApprove - Whether to approve or revoke the approval
     */
    function setApprovalForAll(bytes32 receiverAddress, bool shouldApprove)
        external;

    /**
     * @dev Returns the account approved for a token.
     *
     * @param tokenId - Token to be queried
     *
     * @return bytes32 - Address of the account approved for a token
     */
    function getApprovedSpanning(uint256 tokenId)
        external
        view
        returns (bytes32);

    /**
     * @dev Indicates if an account has total control over another's assets.
     *
     * @param senderAddress - Address of the allowance sender (cede control)
     * @param receiverAddress - Address of the allowance receiver (gains control)
     *
     * @return bool - Indicates whether the account is approved for all
     */
    function isApprovedForAll(bytes32 senderAddress, bytes32 receiverAddress)
        external
        view
        returns (bool);

    /**
     * @dev Emitted tokens are transferred
     *
     * Note that `amount` may be zero.
     *
     * @param senderAddress - Address initiating the transfer
     * @param receiverAddress - Address receiving the transfer
     * @param tokenId - Token under transfer
     */
    event SpanningTransfer(
        bytes32 indexed senderAddress,
        bytes32 indexed receiverAddress,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when an allowance pair changes.
     *
     * @param senderAddress - Address of the allowance sender
     * @param receiverAddress - Address of the allowance receiver
     * @param tokenId - Token under allowance
     */
    event SpanningApproval(
        bytes32 indexed senderAddress,
        bytes32 indexed receiverAddress,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when an account gives control to another account's tokens.
     *
     * @param senderAddress - Address of the allowance sender (cede control)
     * @param receiverAddress - Address of the allowance receiver (gains control)
     * @param approved - Whether the approval was approved or revoked
     */
    event SpanningApprovalForAll(
        bytes32 indexed senderAddress,
        bytes32 indexed receiverAddress,
        bool approved
    );
}

// SPDX-License-Identifier: MIT

// NOTE: The assembly in this file relies on the specifics of the 0.8.0 spec.
// Validate all changes before upgrading.
pragma solidity ^0.8.0;

import "./ISpanningDelegate.sol";

/**
 * @dev This library adds interpretation of our `SpanningAddress` as follows:
 *
 * 31    27        19                   0
 * |-----+---------+--------------------|
 *
 * +The bottom 0-19 bytes are the local address
 * +Bytes 20-27 are left empty for future expansion
 * +Bytes 28 - 31 are the domain ID
 * +Byte 20 - the number of blocks the protocol
 *            will wait before settling the transaction
 */
library SpanningAddress {
    /**
     * @dev Helper function to pack a Spanning Address.
     *
     * @param legacyAddress - Legacy (local) address to pack
     * @param domain - Domain identifier to pack
     * @return bytes32 - Generated Spanning Address
     */
    function create(address legacyAddress, bytes4 domain)
        public
        pure
        returns (bytes32)
    {
        bytes32 packedSpanningAddress = 0x0;
        assembly {
            // `address` is left extension and `bytes` is right extension
            packedSpanningAddress := add(legacyAddress, domain)
        }
        return packedSpanningAddress;
    }

    /**
     * @dev Sentinel value for an invalid Spanning Address.
     *
     * @return bytes32 - An invalid Spanning Address
     */
    function invalidAddress() public pure returns (bytes32) {
        return create(address(0), bytes4(0));
    }

    function valid(bytes32 addr) public pure returns (bool) {
        return addr != invalidAddress();
    }

    /**
     * @dev Extracts legacy (local) address.
     *
     * @param input - Spanning Address to unpack
     *
     * @return address - Unpacked legacy (local) address
     */
    function getAddress(bytes32 input) public pure returns (address) {
        address unpackedLegacyAddress = address(0);
        assembly {
            // `address` asm will extend from top
            unpackedLegacyAddress := input
        }
        return unpackedLegacyAddress;
    }

    /**
     * @dev Extracts domain identifier.
     *
     * @param input - Spanning Address to unpack
     *
     * @return bytes4 - Unpacked domain identifier
     */
    function getDomain(bytes32 input) public pure returns (bytes4) {
        bytes4 unpackedDomain = 0x0;
        assembly {
            // `bytes` asm will extend from the bottom
            unpackedDomain := input
        }
        return unpackedDomain;
    }

    /**
     * @dev Determines if two Spanning Addresses are equal.
     *
     * Note: This function only considers LegacyAddress and Domain for equality
     * Note: Thus, `equals()` can return true even if `first != second`
     *
     * @param first - the first Spanning Address
     * @param second - the second Spanning Address
     *
     * @return bool - true if the two Spanning Addresses are equal
     */
    function equals(bytes32 first, bytes32 second) public pure returns (bool) {
        // TODO(ENG-137): This may be faster if we use bitwise ops. Profile it.
        return (getDomain(first) == getDomain(second) &&
            getAddress(first) == getAddress(second));
    }

    /**
     * @dev Packs data into an existing Spanning Address
     *
     * This can be used to add routing parameters into a
     * Spanning Addresses buffer space.
     *
     * Example to specify a message waits `numFinalityBlocks`
     * before settling:
     * newSpanningAddress = packAddressData(prevSpanningAddress,
     *                                      numFinalityBlocks,
     *                                      20)
     *
     * @param existingAddress - the Spanning Address to modify
     * @param payload - the data to pack
     * @param index - the byte location to put the payload into
     */
    function packAddressData(
        bytes32 existingAddress,
        uint8 payload,
        uint8 index
    ) public pure returns (bytes32) {
        require(index > 19 && index < 28,
                "Trying to overwrite address data");
        bytes32 encodedAddress = 0x0;
        bytes32 dataMask = 0x0;
        uint8 payloadIndex = index * 8;
        assembly {
            // `payload` is right extension
            dataMask := shl(payloadIndex, payload)
            encodedAddress := add(existingAddress, dataMask)
        }
        return encodedAddress;
    }
}

// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright (C) 2022 Spanning Labs Inc.

pragma solidity ^0.8.0;

import "./ISpanningDelegate.sol";
import "./SpanningUtils.sol";
import "./ISpanning.sol";

/**
 * @dev This module provides a number of utility functions and modifiers for
 * interacting with the Spanning Network.
 *
 * It includes:
 *  + Functions abstracting delegate state and methods
 *  + Functions for multi-domain ownership
 *
 * Note: This module is meant to be used through inheritance.
 */
abstract contract Spanning is ISpanning {
    // This allows us to efficiently unpack data in our Address specification.
    using SpanningAddress for bytes32;

    // Legacy address of the delegate for the current domain
    address private delegateLegacyAddress;

    // Reference to a Spanning Delegate interface
    ISpanningDelegate private delegate_;

    // Address of the owner of all contracts in this inheritance hierarchy
    bytes32 private rootOwner;

    /**
     * @dev Initializes a Spanning base module.
     *
     * Note: The initial rootOwner is set to the whomever deployed the contract.
     *
     * @param delegate - Legacy (local) address of our Spanning Delegate
     */
    constructor(address delegate) {
        delegateLegacyAddress = delegate;
        delegate_ = ISpanningDelegate(delegate);
        _transferOwnership(getAddressFromLegacy(msg.sender));
    }

    /**
     * @return bool - true if the contract is a Spanning contract
     */
    function isSpanning() external pure override returns (bool) {
        return true;
    }

    /**
     * @dev Reverts if the function is executed by anyone but the Delegate.
     */
    modifier onlySpanning() {
        require(isSpanningCall(), "onlySpanning: bad role");
        _;
    }

    /**
     * @return bool - true if a sender is a Spanning Delegate
     */
    function isSpanningCall() public view override returns (bool) {
        return (delegateAddress() == msg.sender);
    }

    /**
     * @return bytes4 - Domain identifier
     */
    function getDomain() internal view returns (bytes4) {
        return delegate_.getDomain();
    }

    /**
     * @return address - Local (legacy) address of the Delegate
     */
    function delegateAddress() internal view returns (address) {
        return delegateLegacyAddress;
    }

    /**
     * @dev Updates Delegate's legacy (local) address.
     *
     * @param newDelegateLegacyAddress - Desired address for Spanning Delegate
     */
    function updateDelegate(address newDelegateLegacyAddress)
        external
        override
        onlyOwner
    {
        require(newDelegateLegacyAddress != address(0), "Invalid Address");
        emit DelegateUpdated(delegateLegacyAddress, newDelegateLegacyAddress);
        delegateLegacyAddress = newDelegateLegacyAddress;
        delegate_ = ISpanningDelegate(newDelegateLegacyAddress);
    }

    /**
     * @dev Creates a function request for a delegate to execute.
     *
     * Note: This can result in either a local or cross-domain transaction.
     *
     * @param programAddress - Address to be called
     * @param payload - ABI-encoding of the desired function call
     */
    function makeRequest(bytes32 programAddress, bytes memory payload)
        internal
        virtual
    {
        delegate_.makeRequest(programAddress, payload);
    }

    /**
     * @dev Gets a Legacy Address from an Address, if in the same domain.
     *
     * Note: This function can be used to create backwards-compatible events.
     *
     * @param inputAddress - Address to convert to a Legacy Address
     *
     * @return address - Legacy Address if in the same domain, otherwise 0x0
     */
    function getLegacyFromAddress(bytes32 inputAddress)
        internal
        view
        returns (address)
    {
        address legacyAddress = address(0);
        if (inputAddress.getDomain() == delegate_.getDomain()) {
            legacyAddress = inputAddress.getAddress();
        }
        return legacyAddress;
    }

    /**
     * @dev Gets a Domain from an Address
     *
     * @param inputAddress - Address to convert to a domain
     *
     * @return domain -  Domain ID
     */
    function getDomainFromAddress(bytes32 inputAddress)
        internal
        pure
        returns (bytes4)
    {
        return inputAddress.getDomain();
    }

    /**
     * @dev Creates an Address from a Legacy Address, using the local domain.
     *
     * @param legacyAddress - Legacy (local) address to convert
     *
     * @return bytes32 - Packed Address
     */
    function getAddressFromLegacy(address legacyAddress)
        internal
        view
        returns (bytes32)
    {
        return SpanningAddress.create(legacyAddress, getDomain());
    }

    /**
     * @return bytes32 - Multi-domain msg.sender, defaulting to local sender.
     */
    function spanningMsgSender() internal view returns (bytes32) {
        if (delegate_.currentSenderAddress().valid()) {
            return delegate_.currentSenderAddress();
        }
        return getAddressFromLegacy(msg.sender);
    }

    /**
     * @return bytes32 - Multi-domain tx.origin, defaulting to local origin.
     */
    function spanningTxnSender() internal view returns (bytes32) {
        if (delegate_.currentTxnSenderAddress().valid()) {
            return delegate_.currentTxnSenderAddress();
        }
        return getAddressFromLegacy(tx.origin);
    }

    /**
     * @return bool - True if the current call stack has valid Spanning Info
     */
    function isValidSpanningInfo() internal view returns (bool) {
        return delegate_.isValidData();
    }

    /**
     * @return bytes32 - Multi-domain msg.sender, defaulting to local sender.
     */
    function spanningMsgSenderUnchecked() internal view returns (bytes32) {
        return delegate_.currentSenderAddress();
    }

    /**
     * @return bytes32 - Multi-domain tx.origin.
     */
    function spanningTxnSenderUnchecked() internal view returns (bytes32) {
        return delegate_.currentTxnSenderAddress();
    }

    /**
     * @dev Reverts if the function is executed by anyone but the owner.
     */
    modifier onlyOwner() {
        require(spanningMsgSender().equals(owner()), "onlyOwner: bad role");
        _;
    }

    /**
     * @return bytes32 - Address of current owner
     */
    function owner() public view virtual override returns (bytes32) {
        return rootOwner;
    }

    /**
     * @dev Sets the owner to null, effectively removing contract ownership.
     *
     * Note: It will not be possible to call `onlyOwner` functions anymore
     * Note: Can only be called by the current owner
     */
    function renounceOwnership() public virtual override onlyOwner {
        _transferOwnership(bytes32(0));
    }

    /**
     * @dev Assigns new owner for the contract.
     *
     * Note: Can only be called by the current owner
     *
     * @param newOwnerAddress - Address for desired owner
     */
    function transferOwnership(bytes32 newOwnerAddress)
        public
        virtual
        override
        onlyOwner
    {
        require(
            newOwnerAddress != bytes32(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwnerAddress);
    }

    /**
     * @dev Transfers ownership of the contract to a new Address.
     *
     * @param newOwnerAddress - Address for desired owner
     */
    function _transferOwnership(bytes32 newOwnerAddress) internal virtual {
        bytes32 oldOwner = rootOwner;
        rootOwner = newOwnerAddress;
        emit OwnershipTransferred(oldOwner, newOwnerAddress);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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

// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright (C) 2022 Spanning Labs Inc.

pragma solidity ^0.8.0;

/**
 * @dev This module provides a number of utility functions and modifiers for
 * interacting with the Spanning Network.
 *
 * It includes:
 *  + Functions abstracting delegate state and methods
 *  + Functions for multi-domain ownership
 *
 * Note: This module is meant to be used through inheritance.
 */
interface ISpanning {
    /**
     * @return bool - true if the contract is a Spanning contract
     */
    function isSpanning() external pure returns (bool);

    /**
     * @return bool - true if a sender is a Spanning Delegate
     */
    function isSpanningCall() external returns (bool);

    /**
     * @dev Updates Delegate's legacy (local) address.
     *
     * @param newDelegateLegacyAddress - Desired address for Spanning Delegate
     */
    function updateDelegate(address newDelegateLegacyAddress) external;

    /**
     * @return bytes32 - Address of current owner
     */
    function owner() external returns (bytes32);

    /**
     * @dev Sets the owner to null, effectively removing contract ownership.
     *
     * Note: It will not be possible to call `onlyOwner` functions anymore
     * Note: Can only be called by the current owner
     */
    function renounceOwnership() external;

    /**
     * @dev Assigns new owner for the contract.
     *
     * Note: Can only be called by the current owner
     *
     * @param newOwnerAddress - Address for desired owner
     */
    function transferOwnership(bytes32 newOwnerAddress) external;

    /**
     * @dev Emitted when an ownership change has occurred.
     *
     * @param previousOwnerAddress - Address for previous owner
     * @param newOwnerAddress - Address for new owner
     */
    event OwnershipTransferred(
        bytes32 indexed previousOwnerAddress,
        bytes32 indexed newOwnerAddress
    );

    /**
     * @dev Emitted when an Delegate endpoint change has occurred.
     *
     * @param delegateLegacyAddress - Address for previous delegate
     * @param newDelegateLegacyAddress - Address for new delegate
     */
    event DelegateUpdated(
        address indexed delegateLegacyAddress,
        address indexed newDelegateLegacyAddress
    );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}