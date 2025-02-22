// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./PriceConverter.sol";


contract FundMe{
    using PriceConverter for uint;
    mapping(address => uint) public addressToAmountFunded;
    address[] public funders;
    address Owner;
    uint public minimumUsd = 20 * 1e18;

    AggregatorV3Interface public priceFeed;

    constructor(address priceFeedAddress){
        Owner = msg.sender; 
        priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    modifier onlyOwner{
        require(msg.sender == Owner, "You are not owner");
        _;
    }

    function fund() public payable{
        require(msg.value.getConverstionRate(priceFeed) >= minimumUsd, "Send more ether");
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function withdraw() public payable onlyOwner{
        for(uint i=0; i<funders.length; i++){
            address funder = funders[i];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "call failed");
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice(AggregatorV3Interface priceFeed) internal view returns (uint) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return uint256(price * 1e10);
    }

    function getConverstionRate(uint _ethAmount, AggregatorV3Interface priceFeed) internal view returns (uint) {
        uint ethPrice = getPrice(priceFeed);
        uint ethAmountInUsd = (ethPrice * _ethAmount) / 1e18;
        return ethAmountInUsd;
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