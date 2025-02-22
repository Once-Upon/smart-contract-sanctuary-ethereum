// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "AggregatorV3Interface.sol";
import "SafeMathChainlink.sol";

contract FundMe {
    using SafeMathChainlink for uint256; // for solidity version 

    mapping(address => uint256) public addressToAmountFunded;

    address[] public funders;
    
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    /// allow takes in coin to this contract
    function fund() public payable {
        // set minimum amount to receive
        uint256 minimum = 10 * (10 ** 18);
        // if (msg.value < minimum) { revert; } 
        // use this syntax instead
        require(getConversionRate(msg.value) >= minimum, "You need to spend more ETH!"); // second argument is error message

        // msg.sender to the "from" address of the transaction
        // msg.value is the amount of coin sent
        addressToAmountFunded[msg.sender] += msg.value;

        funders.push(msg.sender);

    }

    function getVersion() public view returns(uint256) {
        // the address is the priceFeed contract address, it is on the testnet, so cannot use VM
        // https://docs.chain.link/data-feeds/price-feeds/addresses/
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        return priceFeed.version();
    }

    /// get the latest USD price of 1 eth
    function getPrice() public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        ( ,int256 answer, , , ) = priceFeed.latestRoundData(); // the comma indicates unused variable
        return uint256(answer * 10000000000); // the value is in wei, needs to be converted later
    }

    /// get the USD value for the amount of eth
    function getConversionRate(uint256 ethAmount) public view returns(uint256) {
        uint256 ethPrice = getPrice();
        uint256 ethInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        return ethInUsd;
    }

    /// a middleware that imbeds to function
    /// check whether the function caller is the owner
    modifier onlyOwner {
        require(msg.sender == owner, "you are not the owner of this smart contract");
        _; // the rest of the code for the caller function, to indicate the position of the injected code.
    }

    /// transfer all the coin in this contract to the caller
    function withdraw() payable onlyOwner public {
        msg.sender.transfer(address(this).balance);

        // update data structure
        for (uint256 i = 0; i < funders.length ; i++) {
            addressToAmountFunded[funders[i]] = 0;
        }
        funders = new address[](0); // new keyword used to create new array
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

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
pragma solidity ^0.6.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathChainlink {
  /**
    * @dev Returns the addition of two unsigned integers, reverting on
    * overflow.
    *
    * Counterpart to Solidity's `+` operator.
    *
    * Requirements:
    * - Addition cannot overflow.
    */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");

    return c;
  }

  /**
    * @dev Returns the subtraction of two unsigned integers, reverting on
    * overflow (when the result is negative).
    *
    * Counterpart to Solidity's `-` operator.
    *
    * Requirements:
    * - Subtraction cannot overflow.
    */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "SafeMath: subtraction overflow");
    uint256 c = a - b;

    return c;
  }

  /**
    * @dev Returns the multiplication of two unsigned integers, reverting on
    * overflow.
    *
    * Counterpart to Solidity's `*` operator.
    *
    * Requirements:
    * - Multiplication cannot overflow.
    */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  /**
    * @dev Returns the integer division of two unsigned integers. Reverts on
    * division by zero. The result is rounded towards zero.
    *
    * Counterpart to Solidity's `/` operator. Note: this function uses a
    * `revert` opcode (which leaves remaining gas untouched) while Solidity
    * uses an invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, "SafeMath: division by zero");
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
    * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
    * Reverts when dividing by zero.
    *
    * Counterpart to Solidity's `%` operator. This function uses a `revert`
    * opcode (which leaves remaining gas untouched) while Solidity uses an
    * invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "SafeMath: modulo by zero");
    return a % b;
  }
}