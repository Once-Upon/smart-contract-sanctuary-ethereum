// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";

error FundMe__NotOwner();

/**
 * @title A contract for crowdfunding
 * @author Megh Gupte
 * @notice This contract is to demo a sample funding contract
 * @dev This implements price feeds as our library
 */


contract FundMe {
//type declarations

    using PriceConverter for uint256;
//State variables

    mapping(address => uint256) private s_addressToAmountFunded;
    address[]private s_funders;

    // Could we make this constant?  /* hint: no! We should make it immutable! */
    address private/* immutable */ i_owner;
    uint256 public constant MINIMUM_USD = 50 * 10 ** 18;
    
AggregatorV3Interface private s_priceFeed;

 modifier onlyOwner {
        // require(msg.sender == owner);
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    constructor(address s_priceFeedAddress) {
        i_owner = msg.sender;
       s_priceFeed= AggregatorV3Interface(s_priceFeedAddress);
    }
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

/**
 * 
 * @notice This function is to fund this contract
 * @dev This implements price feeds as our library
 */

    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed)
        >= MINIMUM_USD, "You need to spend more ETH!");
        // require(PriceConverter.getConversionRate(msg.value) >= MINIMUM_USD, "You need to spend more ETH!");
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }
    
    
    
   
    
    function withdraw() payable onlyOwner public {
        for (uint256 funderIndex=0; funderIndex < s_funders.length; funderIndex++){
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // // transfer
        // payable(msg.sender).transfer(address(this).balance);
        // // send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");
        // call
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

function cheaperWithdraw() public payable onlyOwner{
    address[]memory funders= s_funders;
    //mappings cannot be in memory
    for (uint256 funderIndex=0; funderIndex<funders.length; funderIndex++){
        address funder= funders[funderIndex];
        s_addressToAmountFunded[funder]=0; 
    }
    s_funders= new address[](0);
    (bool success,)= i_owner.call{value:address(this).balance}("");
    require(success);
}



    // Explainer from: https://solidity-by-example.org/fallback/
    // Ether is sent to contract
    //      is msg.data empty?
    //          /   \ 
    //         yes  no
    //         /     \
    //    receive()?  fallback() 
    //     /   \ 
    //   yes   no
    //  /        \
    //receive()  fallback()

    function getOwner() public view returns(address){
        return i_owner;
    }
    function getFunder ( uint256 index ) public view returns ( address ) {
    return s_funders [index];
    }
function getAddressToAmountFunded ( address funder)
    public
    view
    returns ( uint256 )
{
    return s_addressToAmountFunded [ funder ] ;
}
function getPriceFeed ( ) public view returns ( AggregatorV3Interface ) 
{
    return s_priceFeed ;
}

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice(AggregatorV3Interface priceFeed)
        internal
        view
        returns (uint256)
    {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        // ETH/USD rate in 18 digit
        return uint256(answer * 10000000000);
    }

    // 1000000000
    // call it get fiatConversionRate, since it assumes something about decimals
    // It wouldn't work for every aggregator
    function getConversionRate(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        // the actual ETH/USD conversation rate, after adjusting the extra 0s.
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