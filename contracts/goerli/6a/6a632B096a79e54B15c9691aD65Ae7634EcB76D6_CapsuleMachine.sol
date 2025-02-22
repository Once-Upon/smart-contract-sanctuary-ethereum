/**
 *Submitted for verification at Etherscan.io on 2022-09-16
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC721 {
    function exist(uint tokenId) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}

contract CapsuleMachine is VRFConsumerBaseV2, Ownable {

    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Goerli coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;

    // todo: update the mainnet config when deploying
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 2500000; 

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;


    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    // mapping(uint256 => uint256[]) public s_requestIdToRandomWords;
    mapping(uint256 => address) public s_requestIdToAddress;
    mapping(uint256 => uint256) public s_requestIdToCapsuleID;


    ///  In order to get All-Active-Capsules:
    ///  Iterate from 0 -> allCapsules.length in front-end, 
    ///  and skip all finishedCapsuleIDs to get all-active-game IDs. 
    ///  Then use these IDs to 'getCapsuleDetail'
    uint256[] public finishedCapsuleIDs; 
    uint256 public numOfFinishedCapsules; 
    // Capsule[] public allActiveCapsules; // not necessary

    Capsule[] public allCapsules;
    // uint256 public numOfCapsules;

    // to have Capsule-played count for each player?
    // mapping (address => int) public allPlayerBalances; // how much does each player own (msg.value)
    // mapping (address => uint) public allPlayerHostCount; 
    // mapping (address => uint) public allPlayerPlayCount; 
    // uint public OverallWonAmount; // unit in wei (like msg.value)
    // mapping (uint => uint256) public allCapsuleBalances; // how much a game's pool having (msg.value)

    mapping(uint256 => address) public capIdToHost; 
    mapping(address => bool) public whitelistedAddresses; 
    mapping(address => mapping(uint256 => bool)) public isNFTinCapsule;
    // mapping(address => uint256[]) public winnerToCapsules;
    uint256 betFee = 0.001 ether;
    uint256 public capsuleCommission = 25; // 2.5%


    // EVENETS 
    event CapsuleCreated(uint capID, address host, address nftAddr, uint256 nftID);
    event BuyCapsulePartition(uint capID, address player, uint256 requestAmt);
    event CapsuleWon(uint capID, address winner, address nftAddr, uint256 nftID);


    struct Capsule { 
        // uint256 capID;
        uint256 startTime;
        uint256 endTime;
        // bool ended;
        
        address host;
        address nftAddr; 
        uint256 nftId;
        uint256 partition; 
        uint256 eachPrice;
        uint256 soldPartition;
        address[] buyers;

        
        uint256 betPool; 
        uint256 ethContributed;

        address winner;
    }
    
    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    
    function setupMachine(address _assetAddress, uint256 _tokenId, uint256 _partition, uint256 _price, uint256 _duration) 
        external
        returns (uint256 capID)
    {   
        // check whitelisted nft
        require(isAddressWhitelisted(_assetAddress) == true, "Asset not whitelisted");

        // check owner
        IERC721 _thisNFT = IERC721(_assetAddress);
        require (msg.sender == _thisNFT.ownerOf(_tokenId), "not NFT owner.");

        // check duplicate setup
        require(isNFTinCapsule[_assetAddress][_tokenId] != true, "NFT already in capsule.");

        // deposit nft
        _thisNFT.transferFrom(msg.sender, address(this), _tokenId);

        // setup capsule info
        uint256 _newCapID = allCapsules.length;

        Capsule memory c;  
        c.startTime = block.timestamp;
        c.host = msg.sender;
        c.nftAddr = _assetAddress;
        c.nftId = _tokenId;
        c.partition = _partition;
        c.eachPrice = _price;
        c.endTime = block.timestamp + _duration;
        // c.jackpotNum = _generateJackpotNum(_odds);

        isNFTinCapsule[_assetAddress][_tokenId] = true;
        capIdToHost[_newCapID] = msg.sender;

        allCapsules.push(c);
        // allActiveCapsules.push(c);
        // numOfCapsules++;

        emit CapsuleCreated(_newCapID, msg.sender, _assetAddress, _tokenId);

        return _newCapID;
    }

    // generate jackpotNum using blockHash % (odds)
    // function _generateJackpotNum(uint256 odds) internal view returns (uint256 rand) {
    //     return uint256(keccak256(abi.encodePacked(block.difficulty))) % (odds) ;
    // }    

    // player buys capsule partition
    function buyCapsulePartition(uint256 _capId, uint256 requestAmt) public payable
    {
        require(requestAmt > 0, "request amount cannot be zero");
        require(isCapsuleEnded(_capId) != true, "Capsule is ended.");
        Capsule storage c = allCapsules[_capId];

        require(block.timestamp <= c.endTime, "Purchase period ended.");
        require(requestAmt <= (c.partition - c.soldPartition), "Insufficient remaining partition");

        uint256 checkValue = requestAmt * c.eachPrice;
        require(msg.value >= checkValue, "Insufficient fund");

        uint256 _max = c.soldPartition + requestAmt;
        // update 
        for (uint256 i = c.soldPartition; i < _max; i++) {
            c.buyers.push(msg.sender);
        }
        c.betPool += checkValue;
        c.ethContributed += checkValue;
        c.soldPartition += requestAmt;
        
        emit BuyCapsulePartition(_capId, msg.sender, requestAmt);
    }

    function hostClaim(uint256 _capId) external {
        // check if host
        Capsule storage c = allCapsules[_capId];
        require(msg.sender == c.host, "Host only.");

        require(block.timestamp > c.endTime, "Time not end.");
        require(c.soldPartition == 0, "Cannot claim once started.");

        // withdraw nft
        IERC721 _thisNft = IERC721(c.nftAddr);
        _thisNft.transferFrom(address(this), msg.sender, c.nftId);
    }

    // host or owner to execute
    function selectWinner(uint256 _capId) external {
        require(isCapsuleEnded(_capId) != true, "Capsule is ended.");
        Capsule storage c = allCapsules[_capId];

        bool onlyAdminOrHost = (msg.sender == owner()) || (msg.sender == c.host);
        require(onlyAdminOrHost, "only for admin or host");

        bool eitherSoldoutOrTimeout = (block.timestamp > c.endTime) || (c.soldPartition == c.partition);
        require(eitherSoldoutOrTimeout, "Its not sold-out or time-out yet");

        requestRandomWords(_capId);
    }

    function requestRandomWords(uint256 _capId) internal 
    {
        uint256 _requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );
        
        // s_requestIdToAddress[_requestId] = msg.sender;
        s_requestIdToCapsuleID[_requestId] = _capId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {

        s_requestId = requestId;
        s_randomWords = randomWords;

        uint256 _capId = s_requestIdToCapsuleID[requestId];
        Capsule storage c = allCapsules[_capId];
        uint256 resultIndex = randomWords[0] % c.soldPartition;

        if (c.winner == address(0)) {
            address winner = c.buyers[resultIndex];
            c.winner = winner;
            
            // transfer nft
            IERC721 _thisNft = IERC721(c.nftAddr);
            _thisNft.transferFrom(address(this), winner, c.nftId);

            // transfer fund
            uint256 commission = c.betPool * capsuleCommission / 1000;
            uint256 transferAmt = 0;
            if (c.betPool - commission > betFee)
                transferAmt = c.betPool - commission - betFee;

            if (transferAmt > 0) {
                (bool success1, ) = (address(c.host)).call{value: transferAmt }("");
                require(success1, "transfer failed.");
            }
            if (c.betPool - transferAmt > 0) {
                (bool success2, ) = owner().call{value: (c.betPool - transferAmt) }("");
                require(success2, "transfer failed.");
            }
            

            // c.ended = true; 
            c.betPool = 0;
            isNFTinCapsule[c.nftAddr][c.nftId] = false;

            // delete allActiveCapsules[_capId];
            finishedCapsuleIDs.push(_capId);
            numOfFinishedCapsules++;

            emit CapsuleWon(_capId, c.winner, c.nftAddr, c.nftId);  
        }
        
    }


    // function winnerClaimPrize() external {
        // uint256[] memory wonCapsules = winnerToCapsules[msg.sender];
        // require(wonCapsules.length > 0, "No capsules can be claimed.");

        // for (uint256 i = 0; i < wonCapsules.length; i++) {
            // uint _capId = wonCapsules[i];

            
        // }
    // }

    // function hostWithdrawFund(uint256 _capId) external {
    //     require(isCapsuleExist(_capId), "capsule not exist.");        
    //     Capsule storage c = allCapsules[_capId];
    //     require(msg.sender == c.host, "only for capsule host");
    //     require(c.betPool > 0, "no available fund for withdraw.");

    //     // transfer fund
    //     uint256 commission = c.betPool * (capsuleCommission/100);
    //     uint256 withdrawAmt = c.betPool - commission;
    //     (bool success1, ) = msg.sender.call{value: withdrawAmt }("");
    //     require(success1, "withdraw failed.");
    //     (bool success2, ) = owner().call{value: commission }("");
    //     require(success2, "withdraw failed.");
    // }
    

    // when host end the capsule, nft and fund will be transferred
    // function hostEndingCapsule(uint256 _capId) external {
    //     require(isCapsuleExist(_capId), "capsule not exist.");        
    //     Capsule storage c = allCapsules[_capId];
    //     require(msg.sender == c.host, "only for capsule host");
    //     require(c.winner == address(0), "Capsule already has a winner.");

    //     // if capsule still valid, withdraw nft and fund and airdrop
    //     if (!c.ended) {
    //         // transfer nft
    //         IERC721 _thisNft = IERC721(c.nftAddr);
    //         _thisNft.transferFrom(address(this), msg.sender, c.nftId);

    //         // transfer fund
    //         uint256 commission = c.betPool * (capsuleCommission/100);
    //         uint256 withdrawAmt = c.betPool - commission;
    //         (bool success1, ) = msg.sender.call{value: withdrawAmt }("");
    //         require(success1, "withdraw failed.");
    //         (bool success2, ) = owner().call{value: commission }("");
    //         require(success2, "withdraw failed.");

    //         c.ended = true;
    //         c.betPool = 0;
    //         // c.endTime = block.timestamp;
    //         isNFTinCapsule[c.nftAddr][c.nftId] = false;

    //         // delete allActiveCapsules[_capId];
    //         finishedCapsuleIDs.push(_capId);
    //         numOfFinishedCapsules++;
    //     }
        
    // }

    function isCapsuleExist(uint256 _capId) public view returns (bool) {
        if (_capId < 0 || _capId >= allCapsules.length) 
            return false;

        return true;
    }

    function isCapsuleEnded(uint256 _capId) public view returns (bool) {
        require(isCapsuleExist(_capId), "capsule not exist.");
        Capsule memory c = allCapsules[_capId];
        if (c.winner != address(0))
            return true;

        return false;
    }

    // function getCapsuleJackpotNum(uint _capId) public view
    //     returns (uint resultNum)
    // {
    //     require(isCapsuleExist(_capId), "capsule not exist.");
    //     Capsule memory c = allCapsules[_capId];
    //     return c.jackpotNum;
    // }

    function getCapsuleDetail(uint _capId) public view
    returns(uint256, uint256, address, address, uint256, uint256, uint256, uint256, address[] memory, uint256, uint256, address)
    {
        require(isCapsuleExist(_capId), "capsule not exist.");
        Capsule memory c = allCapsules[_capId];
        return (
            // c.capID,
            c.startTime, 
            c.endTime,
            // c.ended,

            c.host,
            c.nftAddr,
            c.nftId,
            c.partition,
            c.eachPrice,
            c.soldPartition,
            c.buyers,
            
            c.betPool,
            c.ethContributed,
            c.winner
        );
    }
    
    
    // function getPlayerBalance(address _playerAdr) 
    //     returns (int balance)
    // {
    //     return allPlayerBalances[_playerAdr];
    // }

    // function modifyWinningCommission(uint newPercent) onlyOwner
    // {
    //     winningCommissionPercent = newPercent;
    // }

    // function getActiveCapsuleNum() public view returns (uint256) 
    // {
    //     return allActiveCapsules.length;
    // }

    function getCapsuleNum() public view returns (uint256) 
    {
        return allCapsules.length;
    }

    function isAddressWhitelisted(address _whitelistedAddress) public view returns(bool) {
        return whitelistedAddresses[_whitelistedAddress] == true;
    }

    function addAddressesToWhitelist(address[] memory _addressesToWhitelist) public onlyOwner {
        for (uint256 index = 0; index < _addressesToWhitelist.length; index++) {
            require(whitelistedAddresses[_addressesToWhitelist[index]] != true, "Address is already whitlisted");
            whitelistedAddresses[_addressesToWhitelist[index]] = true;
        }        
    }

    function removeAddressesFromWhitelist(address[] memory _addressesToRemove) public onlyOwner {
        for (uint256 index = 0; index < _addressesToRemove.length; index++) {
            require(whitelistedAddresses[_addressesToRemove[index]] == true, "Address isn't whitelisted");
            whitelistedAddresses[_addressesToRemove[index]] = false;
        }
    }

    
    
    // not applying for now
    // function flipOnlyWhitelist() public onlyOwner {
    //     _onlyWhitelisted = !_onlyWhitelisted;
    // }

    function adjustBetFee(uint256 newFee) external onlyOwner {
        betFee = newFee;
    }

    function editCapsuleCommission(uint256 newAmt) external onlyOwner {
        capsuleCommission = newAmt;
    }

    function kill() external onlyOwner {
        selfdestruct(payable(address(owner())));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

}


// todo: review and remove all unnecessary comment