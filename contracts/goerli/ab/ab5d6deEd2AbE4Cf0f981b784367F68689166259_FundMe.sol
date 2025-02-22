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

// Pragma
pragma solidity ^0.8.0;

// Import
import "./PriceConverter.sol";

// Error Code
error FundMe__NotOwner();

/** @title A contract for crowd funding */
/** @author Mohammad Alasli  */
/** @notice This contract is to demo a sample funding contract */
/** @dev This implement price feed as our library */

contract FundMe {
    // Type Declarations
    using PriceConverter for uint256;

    // State Variables!
    // mapping: to check how much money each one of these ppl actually sent
    mapping(address => uint256) private s_addressToAmountFunded;
    address[] private s_funders;
    address private immutable i_owner; // create a global variable
    uint256 public constant MINIMUN_USD = 50 * 10 ** 18; //50 * 1e18;
    AggregatorV3Interface private s_priceFeed;

    //keyword "modifier" only owner in the withraw function declaration call the function
    modifier onlyOwner() {
        //require(msg.sender == i_owner, "Sender is not owner");
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        }
        _;
    }

    constructor(address s_priceFeedAdrress) {
        i_owner = msg.sender; //whomever is deploying the contract
        s_priceFeed = AggregatorV3Interface(s_priceFeedAdrress);
    }

    // receive() external payable {
    //     fund();
    // }

    // fallback() external payable {
    //     fund();
    // }

    /** @notice This function fund the contract */
    /** @dev This implement price feed as our library */

    function fund() public payable {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUN_USD,
            "You need to spend more ETH!"
        ); //to get how much value somebody sending

        s_addressToAmountFunded[msg.sender] += msg.value; //when somebody fund our contract
        s_funders.push(msg.sender);
    }

    function withdraw() public payable onlyOwner {
        /* starting index, ending index, step amount*/
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0; //reset the balances of the "mapping"
        }

        s_funders = new address[](0); //now we reset the [array]

        // withdraw the funds with 3 ways (transfer, send, call)
        // payable (msg.sender).transfer(address(this).balance);
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }

    function cheaperWithdraw() public payable onlyOwner {
        // read from memory instade of constently reading from a storage
        address[] memory funders = s_funders;
        // mapping can't be in memory!
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    // View / Pure
    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(
        address funder
    ) public view returns (uint256) {
        return s_addressToAmountFunded[funder];
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// importing from GetHub & NPM package to interact with contract outside of our project
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// libraries can't have state variable and can't send ether / all the function in libraries are "internal"
// we gonna make diffrenet functions we can call on "uint256"
library PriceConverter {
    // create a function to get a price of ETH in term of USD / using chain link data feeds to get the price
    function getPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData(); // "int256" because some data could be negative
        //return the price of ETH in term of USD by converting the msg.value from ETH to terms of USD
        return uint256(price * 1e10);
    }

    // function getVersion() internal view returns (uint256) {
    //     AggregatorV3Interface priceFeed = AggregatorV3Interface(
    //         0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
    //     );
    //     return priceFeed.version(); // call the function on the interface of the contract
    // }

    // create a fuction to convert the rate (how much ETH is in terms of USD)
    function getConversionRate(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmountInUSD = (ethPrice * ethAmount) / 1e18; // always multipli before you divide
        return ethAmountInUSD;
    }
}