// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
pragma abicoder v2;

// AutomationCompatible.sol imports the functions from both ./AutomationBase.sol and
// ./interfaces/AutomationCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PredictionGame is AutomationCompatibleInterface{

    AggregatorV3Interface internal priceFeed;
    
    mapping(address => uint) public pendingReturns;
    mapping(address => bool) public voted;
    uint immutable public minBid;
    uint immutable public roundDuration;
    int public lastRoundPrice;
    uint public lastRoundEndTime;
    uint immutable public maxVotingDuration;

    mapping(address => uint) public currentBids;
    address[] public currentUpVoters;
    address[] public currentDownVoters;
    uint public currentPotSize;
    uint public currentUpPotSize;
    uint public currentDownPotSize;

    mapping(address => uint) public previousBids;
    address[] public previousUpVoters;
    address[] public previousDownVoters;
    uint public previousPotSize;
    uint public previousUpPotSize;
    uint public previousDownPotSize;
    
    /**
     * Network: Goerli
     * Aggregator: ETH/USD
     * Address: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
     */
    constructor(uint _minBid, uint _roundDuration, uint _cooldownDuration) {
        priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        minBid = _minBid;
        roundDuration = _roundDuration * 1 seconds;
        maxVotingDuration = _roundDuration - _cooldownDuration * 1 seconds;

        currentPotSize = 0;
        currentUpPotSize = 0;
        currentDownPotSize = 0;
        previousPotSize = 0;
        previousUpPotSize = 0;
        previousDownPotSize = 0;


        lastRoundPrice = getLatestPrice();
        lastRoundEndTime = block.timestamp;
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    /**
    * Allows user to place a bet with bool isVoteUp being True if vote is up, False if vote is down
    */
    function placeBet(bool isVoteUp) public payable {
        require(
            msg.value > minBid,
            "Bet is too small, please place a higher bet!"
        );
        require(
            voted[msg.sender] == false,
            "You have already voted! Please wait for the next round to vote"
        );
        require(
            (block.timestamp - lastRoundEndTime) < maxVotingDuration,
            "Voting for the next round has ended. Please wait for the next voting round to start!"
        );

        if (isVoteUp) {
            currentUpVoters.push(msg.sender);
            currentUpPotSize += msg.value;
        } else {
            currentDownVoters.push(msg.sender);
            currentDownPotSize += msg.value;
        }
        voted[msg.sender] = true;
        currentPotSize += msg.value;
        currentBids[msg.sender] += msg.value;
    }

    function withdraw() public returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;

            if (!payable(msg.sender).send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastRoundEndTime) > roundDuration;
        // We don't use the checkData. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - lastRoundEndTime) > roundDuration) {
            lastRoundEndTime = block.timestamp;
            endRound();
        }
        // We don't use the performData. The performData is generated by the Automation Node's call to your checkUpkeep function
    }

    function endRound() private {
        int currentRoundPrice = getLatestPrice();
        if (currentRoundPrice >= lastRoundPrice) {
            for (uint i = 0; i < previousUpVoters.length; i++) {
                address voter = previousUpVoters[i];
                pendingReturns[voter] += (previousBids[voter]/previousUpPotSize) * previousPotSize;
                previousBids[voter] = 0;
            }
            for (uint i = 0; i < previousDownVoters.length; i++) {
                previousBids[previousDownVoters[i]] = 0;
            }
        } else {
            for (uint i = 0; i < previousDownVoters.length; i++) {
                address voter = previousDownVoters[i];
                pendingReturns[voter] += (previousBids[voter]/previousDownPotSize) * previousPotSize;
                previousBids[voter] = 0;
            }
            for (uint i = 0; i < previousUpVoters.length; i++) {
                previousBids[previousUpVoters[i]] = 0;
            }
        }

        for (uint i = 0; i< currentUpVoters.length; i++) {
                address voter = currentUpVoters[i];
                previousBids[voter] = currentBids[voter];
        }
        for (uint i = 0; i< currentDownVoters.length; i++) {
                address voter = currentDownVoters[i];
                previousBids[voter] = currentBids[voter];
        }

        previousUpVoters = currentUpVoters;
        previousDownVoters = currentDownVoters;
        previousPotSize = currentPotSize;
        previousUpPotSize = currentUpPotSize;
        previousDownPotSize = currentDownPotSize;

        delete currentUpVoters;
        delete currentDownVoters;
        currentPotSize = 0;
        currentUpPotSize = 0;
        currentDownPotSize = 0;

        lastRoundPrice = currentRoundPrice;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

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
pragma solidity ^0.8.0;

import "./AutomationBase.sol";
import "./interfaces/AutomationCompatibleInterface.sol";

abstract contract AutomationCompatible is AutomationBase, AutomationCompatibleInterface {}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AutomationBase {
  error OnlySimulatedBackend();

  /**
   * @notice method that allows it to be simulated via eth_call by checking that
   * the sender is the zero address.
   */
  function preventExecution() internal view {
    if (tx.origin != address(0)) {
      revert OnlySimulatedBackend();
    }
  }

  /**
   * @notice modifier that allows it to be simulated via eth_call by checking
   * that the sender is the zero address.
   */
  modifier cannotExecute() {
    preventExecution();
    _;
  }
}