// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import '@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol';
import '@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import '@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol';
import './interfaces/ISmoltingInu.sol';
import './SmolGame.sol';

contract CoinFlip is SmolGame, VRFConsumerBaseV2 {
  uint256 private constant PERCENT_DENOMENATOR = 1000;

  ISmoltingInu smol = ISmoltingInu(0x553539d40AE81FD0d9C4b991B0b77bE6f6Bc030e);
  VRFCoordinatorV2Interface vrfCoord;
  LinkTokenInterface link;
  uint64 private _vrfSubscriptionId;
  bytes32 private _vrfKeyHash;
  uint16 private _vrfNumBlocks = 3;
  uint32 private _vrfCallbackGasLimit = 600000;
  mapping(uint256 => address) private _flipWagerInitUser;
  mapping(uint256 => bool) private _flipWagerInitIsHeads;
  mapping(uint256 => uint256) private _flipWagerInitAmount;
  mapping(uint256 => uint256) private _flipWagerInitNonce;
  mapping(uint256 => bool) private _flipWagerInitSettled;
  mapping(address => uint256) public userWagerNonce;

  uint256 public coinFlipMinBalancePerc = (PERCENT_DENOMENATOR * 50) / 100; // 50% user's balance
  uint256 public coinFlipWinPercentage = (PERCENT_DENOMENATOR * 95) / 100; // 95% wager amount
  uint256 public coinFlipsWon;
  uint256 public coinFlipsLost;
  uint256 public coinFlipAmountWon;
  uint256 public coinFlipAmountLost;
  mapping(address => uint256) public coinFlipsUserWon;
  mapping(address => uint256) public coinFlipsUserLost;
  mapping(address => uint256) public coinFlipUserAmountWon;
  mapping(address => uint256) public coinFlipUserAmountLost;
  mapping(address => bool) public lastCoinFlipWon;

  event InitiatedCoinFlip(
    address indexed wagerer,
    uint256 indexed nonce,
    uint256 requestId,
    bool isHeads,
    uint256 amountWagered
  );
  event SettledCoinFlip(
    address indexed wagerer,
    uint256 indexed nonce,
    uint256 requestId,
    bool isHeads,
    uint256 amountWagered,
    bool isWinner,
    uint256 amountWon
  );

  constructor(
    address _nativeUSDFeed,
    address _vrfCoordinator,
    uint64 _subscriptionId,
    address _linkToken,
    bytes32 _keyHash
  ) SmolGame(_nativeUSDFeed) VRFConsumerBaseV2(_vrfCoordinator) {
    vrfCoord = VRFCoordinatorV2Interface(_vrfCoordinator);
    link = LinkTokenInterface(_linkToken);
    _vrfSubscriptionId = _subscriptionId;
    _vrfKeyHash = _keyHash;
  }

  // coinFlipMinBalancePerc <= _percent <= 1000
  function flipCoin(uint16 _percent, bool _isHeads) external payable {
    require(smol.balanceOf(msg.sender) > 0, 'must have a bag to wager');
    require(
      _percent >= coinFlipMinBalancePerc && _percent <= PERCENT_DENOMENATOR,
      'must wager between the minimum and your entire bag'
    );
    uint256 _finalWagerAmount = (smol.balanceOf(msg.sender) * _percent) /
      PERCENT_DENOMENATOR;

    _enforceMinMaxWagerLogic(msg.sender, _finalWagerAmount);
    smol.transferFrom(msg.sender, address(this), _finalWagerAmount);

    uint256 requestId = vrfCoord.requestRandomWords(
      _vrfKeyHash,
      _vrfSubscriptionId,
      _vrfNumBlocks,
      _vrfCallbackGasLimit,
      uint16(1)
    );

    _flipWagerInitUser[requestId] = msg.sender;
    _flipWagerInitAmount[requestId] = _finalWagerAmount;
    _flipWagerInitNonce[requestId] = userWagerNonce[msg.sender];
    _flipWagerInitIsHeads[requestId] = _isHeads;
    userWagerNonce[msg.sender]++;

    smol.addPlayThrough(
      msg.sender,
      _finalWagerAmount,
      percentageWagerTowardsRewards
    );
    _payServiceFee();
    emit InitiatedCoinFlip(
      msg.sender,
      _flipWagerInitNonce[requestId],
      requestId,
      _isHeads,
      _finalWagerAmount
    );
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
    internal
    override
  {
    _settleCoinFlip(requestId, randomWords[0]);
  }

  function manualFulfillRandomWords(
    uint256 requestId,
    uint256[] memory randomWords
  ) external onlyOwner {
    _settleCoinFlip(requestId, randomWords[0]);
  }

  function _settleCoinFlip(uint256 requestId, uint256 randomNumber) internal {
    address _user = _flipWagerInitUser[requestId];
    require(_user != address(0), 'coin flip record does not exist');
    require(!_flipWagerInitSettled[requestId], 'already settled');
    _flipWagerInitSettled[requestId] = true;

    uint256 _amountWagered = _flipWagerInitAmount[requestId];
    uint256 _nonce = _flipWagerInitNonce[requestId];
    bool _isHeads = _flipWagerInitIsHeads[requestId];
    uint256 _amountToWin = (_amountWagered * coinFlipWinPercentage) /
      PERCENT_DENOMENATOR;
    uint8 _selectionMod = _isHeads ? 0 : 1;
    bool _didUserWin = randomNumber % 2 == _selectionMod;

    if (_didUserWin) {
      smol.transfer(_user, _amountWagered);
      smol.gameMint(_user, _amountToWin);
      coinFlipsWon++;
      coinFlipAmountWon += _amountToWin;
      coinFlipsUserWon[_user]++;
      coinFlipUserAmountWon[_user] += _amountToWin;
      lastCoinFlipWon[_user] = true;
    } else {
      smol.gameBurn(address(this), _amountWagered);
      coinFlipsLost++;
      coinFlipAmountLost += _amountWagered;
      coinFlipsUserLost[_user]++;
      coinFlipUserAmountLost[_user] += _amountWagered;
      lastCoinFlipWon[_user] = false;
    }
    smol.setCanSellWithoutElevation(_user, true);
    emit SettledCoinFlip(
      _user,
      _nonce,
      requestId,
      _isHeads,
      _amountWagered,
      _didUserWin,
      _amountToWin
    );
  }

  function setCoinFlipMinBalancePerc(uint256 _percentage) external onlyOwner {
    require(_percentage <= PERCENT_DENOMENATOR, 'cannot exceed 100%');
    coinFlipMinBalancePerc = _percentage;
  }

  function setCoinFlipWinPercentage(uint256 _percentage) external onlyOwner {
    require(_percentage <= PERCENT_DENOMENATOR, 'cannot exceed 100%');
    coinFlipWinPercentage = _percentage;
  }

  function getSmolToken() external view returns (address) {
    return address(smol);
  }

  function setSmolToken(address _token) external onlyOwner {
    smol = ISmoltingInu(_token);
  }

  function setVrfSubscriptionId(uint64 _subId) external onlyOwner {
    _vrfSubscriptionId = _subId;
  }

  function setVrfNumBlocks(uint16 _numBlocks) external onlyOwner {
    _vrfNumBlocks = _numBlocks;
  }

  function setVrfCallbackGasLimit(uint32 _gas) external onlyOwner {
    _vrfCallbackGasLimit = _gas;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/interfaces/IERC20.sol';

/**
 * @dev SmoltingInu token interface
 */

interface ISmoltingInu is IERC20 {
  function gameMint(address _user, uint256 _amount) external;

  function gameBurn(address _user, uint256 _amount) external;

  function addPlayThrough(
    address _user,
    uint256 _amountWagered,
    uint8 _percentContribution
  ) external;

  function setCanSellWithoutElevation(address _wallet, bool _canSellWithoutElev)
    external;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import './interfaces/ISmolGame.sol';
import './interfaces/ISmolGameFeeAdjuster.sol';

contract SmolGame is ISmolGame, Ownable {
  address payable public treasury;
  uint256 public serviceFeeUSDCents = 200; // $2
  uint8 public percentageWagerTowardsRewards = 0; // 0%

  address[] public walletsPlayed;
  mapping(address => bool) internal _walletsPlayedIndexed;

  ISmolGameFeeAdjuster internal _feeDiscounter;
  AggregatorV3Interface internal _feeUSDConverterFeed;

  uint256 public gameMinWagerAbsolute;
  uint256 public gameMaxWagerAbsolute;
  uint256 public gameMinWhaleWagerAbsolute = 500 * 10**18;
  uint256 public gameMaxWhaleWagerAbsolute;
  mapping(address => bool) public isGameWhale;

  constructor(address _clPriceFeed) {
    // https://docs.chain.link/docs/reference-contracts/
    // https://github.com/pcaversaccio/chainlink-price-feed/blob/main/README.md
    _feeUSDConverterFeed = AggregatorV3Interface(_clPriceFeed);
  }

  function _payServiceFee() internal {
    uint256 _serviceFeeWei = getFinalServiceFeeWei();
    if (_serviceFeeWei > 0) {
      require(msg.value >= _serviceFeeWei, 'not able to pay service fee');
      address payable _treasury = treasury == address(0)
        ? payable(owner())
        : treasury;
      (bool success, ) = _treasury.call{ value: msg.value }('');
      require(success, 'could not pay service fee');
    }
    if (!_walletsPlayedIndexed[msg.sender]) {
      walletsPlayed.push(msg.sender);
      _walletsPlayedIndexed[msg.sender] = true;
    }
  }

  function getFinalServiceFeeWei() public view override returns (uint256) {
    uint256 _serviceFeeWei = getBaseServiceFeeWei(serviceFeeUSDCents);
    if (address(_feeDiscounter) != address(0)) {
      _serviceFeeWei = _feeDiscounter.getFinalServiceFeeWei(_serviceFeeWei);
    }
    return _serviceFeeWei;
  }

  function getBaseServiceFeeWei(uint256 _costUSDCents)
    public
    view
    override
    returns (uint256)
  {
    // Creates a USD balance with 18 decimals
    uint256 paymentUSD18 = (10**18 * _costUSDCents) / 100;

    // adding back 18 decimals to get returned value in wei
    return (10**18 * paymentUSD18) / _getLatestETHPrice();
  }

  /**
   * Returns the latest ETH/USD price with returned value at 18 decimals
   * https://docs.chain.link/docs/get-the-latest-price/
   */
  function _getLatestETHPrice() internal view returns (uint256) {
    uint8 decimals = _feeUSDConverterFeed.decimals();
    (, int256 price, , , ) = _feeUSDConverterFeed.latestRoundData();
    return uint256(price) * (10**18 / 10**decimals);
  }

  function _enforceMinMaxWagerLogic(address _wagerer, uint256 _wagerAmount)
    internal
    view
  {
    if (isGameWhale[_wagerer]) {
      require(
        _wagerAmount >= gameMinWhaleWagerAbsolute,
        'does not meet minimum whale amount requirements'
      );
      require(
        gameMaxWhaleWagerAbsolute == 0 ||
          _wagerAmount <= gameMaxWhaleWagerAbsolute,
        'exceeds maximum whale amount requirements'
      );
    } else {
      require(
        _wagerAmount >= gameMinWagerAbsolute,
        'does not meet minimum amount requirements'
      );
      require(
        gameMaxWagerAbsolute == 0 || _wagerAmount <= gameMaxWagerAbsolute,
        'exceeds maximum amount requirements'
      );
    }
  }

  function getNumberWalletsPlayed() external view returns (uint256) {
    return walletsPlayed.length;
  }

  function getFeeDiscounter() external view returns (address) {
    return address(_feeDiscounter);
  }

  function setFeeDiscounter(address _discounter) external onlyOwner {
    _feeDiscounter = ISmolGameFeeAdjuster(_discounter);
  }

  function setTreasury(address _treasury) external onlyOwner {
    treasury = payable(_treasury);
  }

  function setServiceFeeUSDCents(uint256 _cents) external onlyOwner {
    serviceFeeUSDCents = _cents;
  }

  function setPercentageWagerTowardsRewards(uint8 _percent) external onlyOwner {
    require(_percent <= 100, 'cannot be more than 100%');
    percentageWagerTowardsRewards = _percent;
  }

  function setGameMinWagerAbsolute(uint256 _amount) external onlyOwner {
    gameMinWagerAbsolute = _amount;
  }

  function setGameMaxWagerAbsolute(uint256 _amount) external onlyOwner {
    gameMaxWagerAbsolute = _amount;
  }

  function setGameMinWhaleWagerAbsolute(uint256 _amount) external onlyOwner {
    gameMinWhaleWagerAbsolute = _amount;
  }

  function setGameMaxWhaleWagerAbsolute(uint256 _amount) external onlyOwner {
    gameMaxWhaleWagerAbsolute = _amount;
  }

  function setIsGameWhale(address _user, bool _isWhale) external onlyOwner {
    isGameWhale[_user] = _isWhale;
  }

  function withdrawTokens(address _tokenAddy, uint256 _amount)
    external
    onlyOwner
  {
    IERC20 _token = IERC20(_tokenAddy);
    _amount = _amount > 0 ? _amount : _token.balanceOf(address(this));
    require(_amount > 0, 'make sure there is a balance available to withdraw');
    _token.transfer(owner(), _amount);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

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
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @dev ISmolGame interface
 */

interface ISmolGame {
  function getFinalServiceFeeWei() external view returns (uint256);

  function getBaseServiceFeeWei(uint256 costUSDCents)
    external
    view
    returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @dev ISmolGameFeeAdjuster interface
 */

interface ISmolGameFeeAdjuster {
  function getFinalServiceFeeWei(uint256 _baseFeeWei)
    external
    view
    returns (uint256);
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