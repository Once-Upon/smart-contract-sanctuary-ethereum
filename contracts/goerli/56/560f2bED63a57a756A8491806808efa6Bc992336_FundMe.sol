//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "AggregatorV3Interface.sol";
contract FundMe{
    mapping(address => uint256) public addressToAmountFunded;
    address public owner;
    address[] public funders;
    constructor() {
        owner = msg.sender;
    }
    function fund() public payable{ 
        uint256 minimumUSD = 1*10**18;
        require(getConverionRate(msg.value) >= minimumUSD, "You need to spend more ETH!");
        addressToAmountFunded[msg.sender] += msg.value;
        //What the ETH --> USD conversion rate is?
    }
    function getVersion() public view returns(uint256){
        AggregatorV3Interface Version = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        return Version.version();
    }
    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        );
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        // ETH/USD rate in 18 digit
        // 1 ETH = 1000000000 GWEI
        return uint256(answer*1000000000);
    }
    function getConverionRate(uint256 ethAmount) public view returns(uint256){
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = ((ethPrice*ethAmount)/100000000000000000);
        return ethAmountInUsd;
    }
    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
    function withdraw() public onlyOwner payable{
        payable(msg.sender).transfer(address(this).balance);
        for(uint funderIndex=0; funderIndex <= funders.length; funderIndex++){
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
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