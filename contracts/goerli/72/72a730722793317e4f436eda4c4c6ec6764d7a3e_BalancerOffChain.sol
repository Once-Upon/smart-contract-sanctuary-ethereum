/**
 *Submitted for verification at Etherscan.io on 2022-10-19
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
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

/**
 * @dev Example contract which perform most of the computation in `checkUpkeep`
 *
 * @notice important to implement {AutomationCompatibleInterface}
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract BalancerOffChain is AutomationCompatibleInterface {
    uint256 public constant SIZE = 1000;
    uint256 public constant LIMIT = 1000;
    uint256[SIZE] public balances;
    uint256 public liquidity = 1000000;

    constructor() {
        // On the initialization of the contract, all the elements have a balance equal to the limit
        for (uint256 i = 0; i < SIZE; i++) {
            balances[i] = LIMIT;
        }
    }

    /// @dev called to increase the liquidity of the contract
    function addLiquidity(uint256 liq) public {
        liquidity += liq;
    }

    /// @dev withdraw an `amount`from multiple elements of the `balances` array. The elements are provided in `indexes`
    function withdraw(uint256 amount, uint256[] memory indexes) public {
        for (uint256 i = 0; i < indexes.length; i++) {
            require(indexes[i] < SIZE, 'Provided index out of bound');
            balances[indexes[i]] -= amount;
        }
    }

    /* @dev this method is called by the Chainlink Automation Nodes to check if `performUpkeep` must be done. Note that `checkData` is used to segment the computation to subarrays.
     *
     *  @dev `checkData` is an encoded binary data and which contains the lower bound and upper bound on which to perform the computation
     *
     *  @dev return `upkeepNeeded`if rebalancing must be done and `performData` which contains an array of indexes that require rebalancing and their increments. This will be used in `performUpkeep`
     */
    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // perform the computation to a subarray of `balances`. This opens the possibility of having several checkUpkeeps done at the same time
        (uint256 lowerBound, uint256 upperBound) = abi.decode(checkData, (uint256, uint256));
        require(upperBound < SIZE && lowerBound < upperBound, 'Lowerbound and Upperbound not correct');
        // first get number of elements requiring updates
        uint256 counter;
        for (uint256 i = 0; i < upperBound - lowerBound + 1; i++) {
            if (balances[lowerBound + i] < LIMIT) {
                counter++;
            }
        }
        // initialize array of elements requiring increments as long as the increments
        uint256[] memory indexes = new uint256[](counter);
        uint256[] memory increments = new uint256[](counter);

        upkeepNeeded = false;
        uint256 indexCounter;

        for (uint256 i = 0; i < upperBound - lowerBound + 1; i++) {
            if (balances[lowerBound + i] < LIMIT) {
                // if one element has a balance < LIMIT then rebalancing is needed
                upkeepNeeded = true;
                // store the index which needs increment as long as the increment
                indexes[indexCounter] = lowerBound + i;
                increments[indexCounter] = LIMIT - balances[lowerBound + i];
                indexCounter++;
            }
        }
        performData = abi.encode(indexes, increments);
        return (upkeepNeeded, performData);
    }

    /* @dev this method is called by the Automation Nodes. it increases all elements whose balances are lower than the LIMIT. Note that the elements are bounded by `lowerBound`and `upperBound`
     *  (provided by `performData`
     *
     *  @dev `performData` is an encoded binary data which contains the lower bound and upper bound of the subarray on which to perform the computation.
     *  it also contains the increments
     *
     *  @dev return `upkeepNeeded`if rebalancing must be done and `performData` which contains an array of increments. This will be used in `performUpkeep`
     */
    function performUpkeep(bytes calldata performData) external override {
        (uint256[] memory indexes, uint256[] memory increments) = abi.decode(performData, (uint256[], uint256[]));
        // important to always check that the data provided by the Automation Node is not corrupted.
        require(indexes.length == increments.length, "indexes and increments arrays' lengths not equal");

        uint256 _balance;
        uint256 _liquidity = liquidity;

        for (uint256 i = 0; i < indexes.length; i++) {
            _balance = balances[indexes[i]] + increments[i];
            // important to always check that the data provided by the Automation Nodes is not corrupted. Here we check that after rebalancing, the balance of the element is equal to the LIMIT
            require(_balance == LIMIT, 'Provided increment not correct');
            _liquidity -= increments[i];
            balances[indexes[i]] = _balance;
        }
        liquidity = _liquidity;
    }
}