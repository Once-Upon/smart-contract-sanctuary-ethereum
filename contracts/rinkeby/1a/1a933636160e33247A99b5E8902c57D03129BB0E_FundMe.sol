// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./PriceConverter.sol";

error FundMe_NotOwner();

contract FundMe{
//Type Declarations 
using PriceConverter for uint256;


uint256 public constant MINIMUM_USD = 0.50 * 10**18;

   address[] public s_funders;
   mapping(address => uint256) public s_addressToAmountFunded;
   // link addreses with amount sent 

   address public immutable i_owner;

   AggregatorV3Interface public s_priceFeed;

   constructor(address priceFeedAddress){
     s_priceFeed = AggregatorV3Interface(priceFeedAddress);
     i_owner = msg.sender ;
   }

    function fund() public payable{

      require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "you need to spend more Eth"
      ); // 1e18 == 1 * 10 ** 18 === 1000000000000000000
      

      s_addressToAmountFunded[msg.sender] += msg.value;
      s_funders.push(msg.sender);
        // link addreses with amount sent 

    }

    function withdraw() public onlyOwner {
      
      for(uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++){

         address funder = s_funders[funderIndex];
         s_addressToAmountFunded[funder] = 0;
      }
      // reset the array 

     s_funders = new address[](0);

    // withdrawimg all ether 

    // using transfer 
    // payable(msg.sender).transfer(address(this).balance);
    // using send 
    // bool = sendSucess= payable(msg.sender).send(address(this).balance);
    // require(sendSucess, "Send failed");
     (bool callSuccess, ) = payable(msg.sender).call{value : address(this).balance}("");
     require(callSuccess , "Call failed");

    }


    function cheaperWithdraw() public onlyOwner {
        address[] memory funders = s_funders;
        // mappings can't be in memory, sorry!
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // payable(msg.sender).transfer(address(this).balance);
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }


    modifier onlyOwner {
     if (msg.sender != i_owner ) revert FundMe_NotOwner();
      _;
    }

    receive () external payable{
      fund();
    }

    fallback () external payable{
      fund();
    }


     function getAddressToAmountFunded(address fundingAddress)
        public
        view
        returns (uint256)
    {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {

    
    function getPrice(AggregatorV3Interface priceFeed) internal  view returns(uint256){
      
      (,int256 price,,,) = priceFeed.latestRoundData();
      // eth in terms of USD
      return uint256(price * 1e10);
    }

    function getConversionRate(uint256 ethAmount , AggregatorV3Interface priceFeed) internal view returns(uint256){

      uint256 ethPrice = getPrice(priceFeed);
      uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
      return ethAmountInUsd;
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