//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PriceConverter.sol";

error NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    event Funded(address indexed from, uint256 ammount);

    address[] public funders;
    mapping(address => uint256) public addressToAmountFunded;
    address public immutable i_owner;
    uint256 public constant MINIMUM_USD = 1 * 1e18;

    AggregatorV3Interface public priceFeed;

    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    function fund() public payable {
        //msg.value is the first parameter for library functions
        require(msg.value.getConversionRate(priceFeed) >= MINIMUM_USD);
        //require(getConversionRate(msg.value) >= minimumUsd, "Didn't send enough"); //value in wei
        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] = msg.value;
    }

    function withdraw() public OnlyOwner {
        for (
            uint256 fundersIndex = 0;
            fundersIndex < funders.length;
            fundersIndex++
        ) {
            address tempAdd = funders[fundersIndex];
            addressToAmountFunded[tempAdd] = 0;
        }
        //reset the array
        funders = new address[](0);

        ///withdraw the funds
        //transfer
        // msg.sender = address.  payable(msg.sender) = payable address
        //payable(msg.sender).transfer(address(this).balance);
        //send
        //bool sendSuccess = payable(msg.sender).send(address(this).balance);
        //require(sendSuccess, "send failed");
        //call
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "call failed");
    }

    modifier OnlyOwner() {
        //require(msg.sender == i_owner, "sender is not owner!");
        if (msg.sender != i_owner) {
            revert NotOwner();
        }
        _;
    }

    //receive()
    receive() external payable {
        fund();
    }

    //fallback()
    fallback() external payable {
        fund();
    }
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice(AggregatorV3Interface priceFeed)
        internal
        view
        returns (uint256)
    {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // ETH/USD rate in 18 digits
        return uint256(price) * 1e10;
    }

    function getConversionRate(
        uint256 ethAmmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmmountInUsd = (ethPrice * ethAmmount) / 1e18;
        return ethAmmountInUsd;
    }
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