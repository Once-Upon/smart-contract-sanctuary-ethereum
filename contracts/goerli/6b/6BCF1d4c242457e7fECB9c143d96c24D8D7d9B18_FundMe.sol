// SPDX-License-Identifier: MIT
// Pragma
pragma solidity ^0.8.8;
// Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";
// import "../node_modules/hardhat/console.sol";
//Error codes
error FundMe__NotOwner();
error FundMe__SpendMoreEth();

//Interfaces
//Libraries

//Contracts

/**@title A contract for crowd funding
 * @author Patrick Collins
 * @notice This contract is to demo a simple funding contracts
 * @dev This implements price feeds as our library
 */
contract FundMe {
     // Type Declarations
     using PriceConverter for uint256;
     //State Varriables
     mapping(address => uint256) private s_addressToAmountFunded;
     address[] private s_funders;
     // Could we make this constant?  /* hint: no! We should make it immutable! */
     address private immutable i_owner;
     uint256 public constant MINIMUM_USD = 50 * 10**18;
     AggregatorV3Interface private s_priceFeed;
     //Events
     //Modifiers
     modifier onlyOwner() {
          // require(msg.sender == owner);
          if (msg.sender != i_owner) revert FundMe__NotOwner();
          _;
     }
     modifier spendMoreEth() {
          // require(msg.sender == owner);
          if (msg.value.getConversionRate(s_priceFeed) < MINIMUM_USD)
               revert FundMe__SpendMoreEth();
          _;
     }

     //Functions
     constructor(address s_priceFeedAddress) {
          i_owner = msg.sender;
          s_priceFeed = AggregatorV3Interface(s_priceFeedAddress);
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
     receive() external payable {
          fund();
     }

     fallback() external payable {
          fund();
     }

     /**@notice This function funds this contract
      *  @dev This implements price feeds as our library
      */
     function fund() public payable spendMoreEth {
          //   console.log("MINIMUM_USD: ", MINIMUM_USD);
          //   require(
          //        msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
          //        "You need to spend more ETH!"
          //   );
          // require(PriceConverter.getConversionRate(msg.value) >= MINIMUM_USD, "You need to spend more ETH!");
          s_addressToAmountFunded[msg.sender] += msg.value;
          s_funders.push(msg.sender);
     }

     /**@notice This function withdraws the funds and transfer it to the owner of the contract
      */
     function withdraw() public payable onlyOwner {
          for (
               uint256 funderIndex = 0;
               funderIndex < s_funders.length;
               funderIndex++
          ) {
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
          (bool callSuccess, ) = payable(msg.sender).call{
               value: address(this).balance
          }("");
          require(callSuccess, "Call failed");
     }

     function cheaperWithdraw() public payable onlyOwner {
          address[] memory funders = s_funders;
          // mappings can't be in memory
          for (
               uint256 funderIndex = 0;
               funderIndex < funders.length;
               funderIndex++
          ) {
               address funder = funders[funderIndex];
               s_addressToAmountFunded[funder] = 0;
          }
          s_funders = new address[](0);
          // // transfer
          // payable(msg.sender).transfer(address(this).balance);
          // // send
          // bool sendSuccess = payable(msg.sender).send(address(this).balance);
          // require(sendSuccess, "Send failed");
          // call
          (bool callSuccess, ) = i_owner.call{value: address(this).balance}("");
          require(callSuccess, "Call failed");
     }

     function getOwner() public view returns (address) {
          return i_owner;
     }

     function getFunder(uint256 index) public view returns (address) {
          return s_funders[index];
     }

     function getAddressToAmountFunded(address funder)
          public
          view
          returns (uint256)
     {
          return s_addressToAmountFunded[funder];
     }

     function getPriceFeed() public view returns (AggregatorV3Interface) {
          return s_priceFeed;
     }
}

// Concepts we didn't cover yet (will cover in later sections)
// 1. Enum
// 2. Events
// 3. Try / Catch
// 4. Function Selector
// 5. abi.encode / decode
// 6. Hash with keccak256
// 7. Yul / Assembly

//Functions Order
//// constructor
//// receive
//// fallback
//// external
//// public
//// internal
//// private
//// view / pure

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// import "../node_modules/hardhat/console.sol";

// Why is this a library and not abstract?
// Why not an interface?
library PriceConverter {
     // We could make this public, but then we'd have to deploy it
     function getPrice(AggregatorV3Interface priceFeed)
          internal
          view
          returns (uint256)
     {
          // Goerli ETH / USD Address
          // https://docs.chain.link/docs/ethereum-addresses/
          // AggregatorV3Interface priceFeed = AggregatorV3Interface(
          //      0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
          // );
          (, int256 answer, , , ) = priceFeed.latestRoundData();
          // ETH/USD rate in 18 digit
          return uint256(answer * 10000000000);
     }

     // 1000000000
     function getConversionRate(
          uint256 ethAmount,
          AggregatorV3Interface priceFeed
     ) internal view returns (uint256) {
          uint256 ethPrice = getPrice(priceFeed);
          // console.log("EthPrice: ", ethPrice);
          uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
          // console.log("ethAmountInUsd: ", ethAmountInUsd);
          // the actual ETH/USD conversion rate, after adjusting the extra 0s.
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