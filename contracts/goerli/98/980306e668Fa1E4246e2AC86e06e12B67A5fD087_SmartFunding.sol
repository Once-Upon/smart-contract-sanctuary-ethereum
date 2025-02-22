// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

// contract
contract SmartFunding is KeeperCompatibleInterface{
    // get address contract
    uint256 public fundingStage; // if 0 inactive | 1 active | 2 success | 3 fail
    address public tokenAddress;
    uint public goal;
    uint public pool;
    uint public endTime;
    address upKeepAddress;

    mapping(address => uint256) public investOf; // investor => amount invest
    mapping(address => uint256) public rewardOf; // investor => amount reward
    mapping(address => bool) public claimedOf; // address => status after claim

    event Invest(address indexed from, uint256 amount);
    event ClaimReward(address indexed from, uint256 amount);
    event Refund(address indexed from, uint256 amount);
 
    // set contract address
    constructor(address _tokenAddress, address _upKeepAddress){
        tokenAddress = _tokenAddress;
        fundingStage = 0;
        upKeepAddress = _upKeepAddress;
    }

    // set goal
    function initialize(uint _goal, uint _endTimeInDay) external{
        goal = _goal;
        endTime = block.timestamp + (_endTimeInDay * 1 minutes); // time to end 
        fundingStage = 1;
    }

    // for another function call this function
    function invest() external payable {
        require(fundingStage == 1, "Stage is not active");
        require(msg.value > 0, "Reject amount of invest");
        require(investOf[msg.sender] == 0, "Already invest");

        // calculate reward from user when invest to this pool
        // (totalSupply / goal) * input == reward of token
        uint256 totalSupply = IERC20(tokenAddress).totalSupply();
        uint256 rewardAmount = (totalSupply / goal) * msg.value;
    
        // set reward
        investOf[msg.sender] = msg.value; // investor => amount
        pool += msg.value;
        rewardOf[msg.sender] = rewardAmount; // investor => reward

        emit Invest(msg.sender, msg.value);
    }

    // clain reward
    function claim() external {
        require(fundingStage == 2, "Stage is not success");
        require(claimedOf[msg.sender] == false, "Already claimed");
        require(rewardOf[msg.sender] > 0, "No reward");
        
        // trasnfer to investor
        uint256 reward = rewardOf[msg.sender];
        claimedOf[msg.sender] = true; // claim status
        rewardOf[msg.sender] = 0; // clear reward after claim
        IERC20(tokenAddress).transfer(msg.sender, reward);

        emit ClaimReward(msg.sender, reward);
    }

    // refund if it full
    function refund() external {
        require(fundingStage == 3, "Stage is fail");
        require(investOf[msg.sender] > 0, "No invest");

        // refund value
        uint256 investAmount = investOf[msg.sender];

        // clear reward
        investOf[msg.sender] = 0;
        investOf[msg.sender] = 0;
        pool -= investAmount;

        payable(msg.sender).transfer(investAmount);

        emit Refund(msg.sender, investAmount);
    }

    // form chainlink
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory) {
        // when this function is ture will use performUpKeep function'
        // true if funding is full and time is full 7 days
        upkeepNeeded = fundingStage == 1 && block.timestamp >= endTime;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        require(msg.sender == upKeepAddress, "Permission denied");
        if(pool >= goal){
            // success
            fundingStage = 2;
        }
        else{
            // fail
            fundingStage = 3;
        }

    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
}

// SPDX-License-Identifier: MIT
/**
 * @notice This is a deprecated interface. Please use AutomationCompatible directly.
 */
pragma solidity ^0.8.0;
import {AutomationCompatible as KeeperCompatible} from "./AutomationCompatible.sol";
import {AutomationBase as KeeperBase} from "./AutomationBase.sol";
import {AutomationCompatibleInterface as KeeperCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AutomationBase.sol";
import "./interfaces/AutomationCompatibleInterface.sol";

abstract contract AutomationCompatible is AutomationBase, AutomationCompatibleInterface {}

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