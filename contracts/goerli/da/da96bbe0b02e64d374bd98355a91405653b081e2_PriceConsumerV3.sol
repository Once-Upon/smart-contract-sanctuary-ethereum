// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./chainlinkInterface.sol";

contract PriceConsumerV3 {

    AggregatorV3Interface internal BTCpriceFeed;
    AggregatorV3Interface internal ETHpriceFeed;
    AggregatorV3Interface internal LinkpriceFeed;

    /**
     * Network: Mumbai Testnet

     * BTC/USD Address: 0xA39434A63A52E749F02807ae27335515BA4b07F7
     * ETH/USD Address: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
     * LINK/USD Address:0x48731cF7e84dc94C5f84577882c14Be11a5B7456
     */

    constructor() {
        BTCpriceFeed = AggregatorV3Interface(0xA39434A63A52E749F02807ae27335515BA4b07F7);
        ETHpriceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        LinkpriceFeed = AggregatorV3Interface(0x48731cF7e84dc94C5f84577882c14Be11a5B7456);
    }

    /**
     * Returns the latest prices
     */
    function LatestBTCprice() public view returns (uint80,int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = BTCpriceFeed.latestRoundData();
        return (roundID,price);
    }

    function LatestETHprice() public view returns (uint80,int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = ETHpriceFeed.latestRoundData();
        return (roundID,price);
}

 function LatestLinkprice() public view returns (uint80,int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = LinkpriceFeed.latestRoundData();
        return (roundID,price);
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