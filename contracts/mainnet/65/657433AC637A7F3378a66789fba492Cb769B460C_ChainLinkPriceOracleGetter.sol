// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../interfaces/chainLink/IFeedRegistry.sol";
import "../interfaces/IPriceOracleGetter.sol";

contract ChainLinkPriceOracleGetter is IPriceOracleGetter {
    uint256 public constant VERSION = 1;

    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WBTC_ADDR = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant BTC_ADDR = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

    address public constant CHAINLINK_FEED_REGISTRY = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;

    IFeedRegistry public feedRegistry;

    constructor() {
        feedRegistry = IFeedRegistry(CHAINLINK_FEED_REGISTRY);
    }

    /**
     * @notice Get an asset's price
     * @param asset Underlying asset address
     * @return price Price of the asset
     * @return decimals Decimals of the returned price
     **/
    function getAssetPrice(address asset) external view override returns (uint256, uint256) {
        if (asset == WETH_ADDR) {
            asset = ETH_ADDR;
        } else if (asset == WBTC_ADDR) {
            asset = BTC_ADDR;
        }

        // Fiat currencies follow https://en.wikipedia.org/wiki/ISO_4217
        (, int256 price, , , ) = feedRegistry.latestRoundData(asset, address(840));
        uint8 decimals = feedRegistry.decimals(asset, address(840));

        return (uint256(price), uint256(decimals));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IFeedRegistry {
    struct Phase {
        uint16 phaseId;
        uint80 startingAggregatorRoundId;
        uint80 endingAggregatorRoundId;
    }

    event FeedProposed(
        address indexed asset,
        address indexed denomination,
        address indexed proposedAggregator,
        address currentAggregator,
        address sender
    );
    event FeedConfirmed(
        address indexed asset,
        address indexed denomination,
        address indexed latestAggregator,
        address previousAggregator,
        uint16 nextPhaseId,
        address sender
    );

    // V3 AggregatorV3Interface

    function decimals(
        address base,
        address quote
    )
    external
    view
    returns (
        uint8
    );

    function description(
        address base,
        address quote
    )
    external
    view
    returns (
        string memory
    );

    function version(
        address base,
        address quote
    )
    external
    view
    returns (
        uint256
    );

    function latestRoundData(
        address base,
        address quote
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

    function getRoundData(
        address base,
        address quote,
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

    // V2 AggregatorInterface

    function latestAnswer(
        address base,
        address quote
    )
    external
    view
    returns (
        int256 answer
    );

    function latestTimestamp(
        address base,
        address quote
    )
    external
    view
    returns (
        uint256 timestamp
    );

    function latestRound(
        address base,
        address quote
    )
    external
    view
    returns (
        uint256 roundId
    );

    function getAnswer(
        address base,
        address quote,
        uint256 roundId
    )
    external
    view
    returns (
        int256 answer
    );

    function getTimestamp(
        address base,
        address quote,
        uint256 roundId
    )
    external
    view
    returns (
        uint256 timestamp
    );


    function isFeedEnabled(
        address aggregator
    )
    external
    view
    returns (
        bool
    );

    function getPhase(
        address base,
        address quote,
        uint16 phaseId
    )
    external
    view
    returns (
        Phase memory phase
    );

    // Round helpers


    function getPhaseRange(
        address base,
        address quote,
        uint16 phaseId
    )
    external
    view
    returns (
        uint80 startingRoundId,
        uint80 endingRoundId
    );

    function getPreviousRoundId(
        address base,
        address quote,
        uint80 roundId
    ) external
    view
    returns (
        uint80 previousRoundId
    );

    function getNextRoundId(
        address base,
        address quote,
        uint80 roundId
    ) external
    view
    returns (
        uint80 nextRoundId
    );

    // Feed management

    function proposeFeed(
        address base,
        address quote,
        address aggregator
    ) external;

    function confirmFeed(
        address base,
        address quote,
        address aggregator
    ) external;

    // Proposed aggregator

    function proposedGetRoundData(
        address base,
        address quote,
        uint80 roundId
    )
    external
    view
    returns (
        uint80 id,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function proposedLatestRoundData(
        address base,
        address quote
    )
    external
    view
    returns (
        uint80 id,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    // Phases
    function getCurrentPhaseId(
        address base,
        address quote
    )
    external
    view
    returns (
        uint16 currentPhaseId
    );
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPriceOracleGetter {
    function getAssetPrice(address asset) external view returns (uint256, uint256);
}