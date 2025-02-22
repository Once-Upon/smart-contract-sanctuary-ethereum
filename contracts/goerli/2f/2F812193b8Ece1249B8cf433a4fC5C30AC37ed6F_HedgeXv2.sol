//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;
import "./PythStructs.sol";
import "./HDGXStructs.sol";
import "./Orderbook.sol";
import "./IWETH9.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

interface IHedgexLiqManager {
    function mintNewPosition(uint256 amount0ToAdd, uint256 amount1ToAdd)
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function decreaseLiquidityCurrentRange()
        external
        returns (uint256 amount0, uint256 amount1);
}

contract HedgeXv2 {
    address public owner;
    uint256 public protocol_earnings;
    Orderbook public hdgx_orderbook;
    address public orderbook_address;
    ISwapRouter public immutable swapRouter;
    IERC20 private hdgx;
    IUniswapV3Factory public unifactory;
    address public hedgexLiqManagerAddress;
    IHedgexLiqManager public hedgexLiqManager;
    uint256 initialLiqThreshold = 5 * (10**16);
    bool public initialLiquidityPulled = false;
    bool public initialLiquidityProvided = false;
    address private pool_address;
    address public HEDGEX;
    address public WETH9;
    IWETH9 private weth;
    uint24 private constant poolFee = 3000;

    event NewMakerOrder(address _maker, uint256 _maker_order_ID, uint256 _amt);
    event Taken(
        address _taker,
        uint256 _maker_order_ID,
        uint256 lockUpEnds,
        uint256 _timestamp
    );
    event Settled(
        address _settler,
        uint256 _taker_order_ID,
        uint256 _maker_order_ID,
        uint256 _settler_fee,
        uint256 _maker_fee,
        uint256 _timestamp
    );
    event Received(address, uint256);
    event SwappedForHedgex(
        uint256 amtInput,
        uint256 amtOutput,
        uint256 timestamp
    );
    event SwapFailure(uint256 _timestamp);
    event InitialLiquidityProvided(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    constructor(
        address _liquidityManager, 
        address _hedgexTokenAddress,
        address payable _hdgx_orderbook,
        address _swapRouter,
        address _weth,
        address _uniFactory
    ) {
        unifactory = IUniswapV3Factory(_uniFactory);
        WETH9 = _weth;
        weth = IWETH9(WETH9);
        swapRouter = ISwapRouter(_swapRouter);
        hedgexLiqManagerAddress = _liquidityManager;
        hedgexLiqManager = IHedgexLiqManager(_liquidityManager);
        HEDGEX = _hedgexTokenAddress;
        pool_address = unifactory.getPool(_hedgexTokenAddress, WETH9, 3000);
        hdgx = IERC20(_hedgexTokenAddress);
        orderbook_address = _hdgx_orderbook;
        hdgx_orderbook = Orderbook(_hdgx_orderbook);
        owner = msg.sender;
        protocol_earnings = 0;
    }

    //Create maker order. Earn 1% of match fee for doing so.
    function makeOrder(
        uint256 lockUpPeriod,
        int64 ratio,
        HDGXStructs.Leg[] memory legs
    ) public payable {
        // Minimum lockup in seconds
        require(lockUpPeriod > 100, "E01");

        // Valid lock-up periods: (1 Hour, 1 Day, 1 Month)
        require(
            (lockUpPeriod == 101 ||
                lockUpPeriod == 86400 ||
                lockUpPeriod == 604800),
            "E02"
        );

        // Valid ratios -1250 -> +1250 !( -100 - +100 )
        require(ratio != 0, "E03");
        require((ratio >= 100 || ratio <= -100), "E04");

        // Encode info to be passed to orderbook
        bytes memory gameInfoEncoded = abi.encode(msg.sender,msg.value,lockUpPeriod,ratio);
        bytes memory legsEncoded = abi.encode(legs);

        // Create maker order on orderbook
        (address _sender, uint256 orderID, uint256 valueSent) = hdgx_orderbook
            .orderbook_make_order(
                gameInfoEncoded,
                legsEncoded
            );
        emit NewMakerOrder(_sender, orderID, valueSent);
    }

    //Match an exisiting maker-order.
    function takeOrder(uint256 makerOrderID, bytes[] calldata priceUpdateData)
        public
        payable
    {   
        // Fetch pyth update fee
        uint256 pyth_update_fee = hdgx_orderbook.pyth_update_fee(priceUpdateData);

        // Transfer pyth update fee to orderbook
        payable(orderbook_address).transfer(pyth_update_fee);

        // Encode info to be passed to orderbook
        bytes memory takerInfoEncoded = abi.encode(msg.sender,msg.value,makerOrderID);

        // Create taker order on orderbook
        (
            address sender,
            uint256 order_ID,
            uint256 expiry,
            uint256 time_taken
        ) = hdgx_orderbook.orderbook_take_order(
                takerInfoEncoded,
                priceUpdateData
            );
        emit Taken(sender, order_ID, expiry, time_taken);
    }

    //Settle order with expired lock-up period.
    function settleOrder(
        uint256 takerOrder_ID,
        bytes[] calldata priceUpdateData
    ) public {
        
        // Fetch pyth update fee, transfer eth fee to orderbook where update will occur.
        uint256 pyth_update_fee = hdgx_orderbook.pyth_update_fee(priceUpdateData);
        payable(orderbook_address).transfer(pyth_update_fee);

        // Encode calldata to pass to ordderbook
        bytes memory settleInfo = abi.encode(msg.sender,takerOrder_ID);
        
        // Place order on orderbook contract
        (HDGXStructs.MakerOrder memory maker, HDGXStructs.TakerOrder memory taker,  address winnerAddress, uint256 feesEarned) = hdgx_orderbook
            .orderbook_settle_order(
                settleInfo,
                priceUpdateData
            );

        // Update protocol earnings
        protocol_earnings += (feesEarned - (pyth_update_fee*2));

        // Pay out Winner's Total
        payable(winnerAddress).transfer(
            ((maker.ethPosted + taker.ethPosted) * 975) / 1000
        );

        // Pay out Settler Fee
        payable(msg.sender).transfer(
            ((maker.ethPosted + taker.ethPosted) * 5) / 1000
        );

        // Pay out Maker Fee
        payable(maker.user).transfer(
            ((maker.ethPosted + taker.ethPosted) * 1) / 100
        );

        // LP Provide once protocol earnings >= initial threshold (public)
        if (protocol_earnings >= initialLiqThreshold) {
            if (initialLiquidityProvided == false) {
                provideLiquidity();
            }
        }

        //Token Buyback Handler
        if (initialLiquidityProvided == true) {
            if (hdgx.balanceOf(pool_address) > ((5 * (10**18)))) {
                //Uniswap V3 Swap ETH for HDGX. 1/2 of protocol's fee spent on buyback. 
                uint256 amountOut = swapExactInputSingle(
                    ((((maker.ethPosted + taker.ethPosted) * 1) / 100) * 50) /
                        100
                );
            } else {
                //Halve Liquidity once HDGX balance in pool is less than 5 Tokens.
                if (initialLiquidityPulled == false) {
                    halveLiquidity();
                }
            }
        }
        emit Settled(
            msg.sender,
            takerOrder_ID,
            taker.makerOrder_ID,
            ((maker.ethPosted + taker.ethPosted) * 5) / 1000,
            ((maker.ethPosted + taker.ethPosted) * 1) / 100,
            block.timestamp
        );
    }

    //Uniswap V3 Swap Exact Input Single, HDGX Token Buyback Fuction
    function swapExactInputSingle(uint256 amountIn) internal returns (uint256) {
        // Wrap ether
        weth.deposit{value: amountIn}();

        // Grant approval to Uniswap V3 router
        TransferHelper.safeApprove(WETH9, address(swapRouter), amountIn);

        // Uniswap V3 construct swap paramters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH9,
                tokenOut: HEDGEX,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // Uniswap V3 Router Swap
        uint256 amountOut = swapRouter.exactInputSingle(params);
        emit SwappedForHedgex(amountIn, amountOut, block.timestamp);
        return (amountOut);
    }

    //Uniswap V3 LP Position Halvening Event Function
    function halveLiquidity() internal {
        (uint256 amount0, uint256 amount1) = hedgexLiqManager
            .decreaseLiquidityCurrentRange();
        initialLiquidityPulled = true;
    }

    //Uniswap V3, Initial Liquidity Provide Function
    function provideLiquidity() internal {
        require(initialLiquidityProvided == false, "E17");
        require(protocol_earnings >= initialLiqThreshold, "E18");

        // Deposit and wrap ether
        weth.deposit{value: initialLiqThreshold}();

        // Grant approval to liquidity manager
        TransferHelper.safeApprove(
            WETH9,
            hedgexLiqManagerAddress,
            initialLiqThreshold
        );

        // Transfer WETH to Liquidity Manager to be provided as liquidity on Uniswap V3. Liquidity Manager holds supply of HDGX ERC-20.
        TransferHelper.safeTransferFrom(
            WETH9,
            address(this),
            hedgexLiqManagerAddress,
            initialLiqThreshold
        );

        // Mint LP position on Liquidity Manager.
        hedgexLiqManager.mintNewPosition((50 * (10**18)), initialLiqThreshold);
        initialLiquidityProvided = true;
        // emit InitialLiquidityProvided(tokenId,liquidity,amount0,amount1);
    }

    function ownerpull() public {
        require(msg.sender == owner);
        address payable _owner = payable(owner);
        _owner.transfer(address(this).balance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}

//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;
import "./HDGXStructs.sol";

library Settler {
    //Negate64 Odds Reversal Helper
    function negate64(int64 _i) internal pure returns (uint64) {
        return uint64(-_i);
    }

    function settlement_evaluation(bytes calldata positionInfo)
        public
        pure
        returns (address payable temp_winner)
    {
        (
            HDGXStructs.Leg[] memory legs,
            HDGXStructs.ClosePrice[] memory close_prices,
            HDGXStructs.MakerOrder memory maker,
            HDGXStructs.TakerOrder memory taker
        ) = abi.decode(
                positionInfo,
                (
                    HDGXStructs.Leg[],
                    HDGXStructs.ClosePrice[],
                    HDGXStructs.MakerOrder,
                    HDGXStructs.TakerOrder
                )
            );

        if (maker.num_legs == 1) {
            if (close_prices[0].close_price.price > legs[0].priceTarget) {
                if (legs[0].outlook == true) {
                    temp_winner = payable(maker.user);
                } else if (legs[0].outlook == false) {
                    temp_winner = payable(taker.user);
                }
            } else if (
                close_prices[0].close_price.price < legs[0].priceTarget
            ) {
                if (legs[0].outlook == true) {
                    temp_winner = payable(taker.user);
                } else if (legs[0].outlook == false) {
                    temp_winner = payable(maker.user);
                }
            } else {
                // Handle Tie Scenario
            }
        }
        //Multi Leg Position Statement
        if (maker.num_legs > 1) {
            bool maker_won = true;
            for (uint256 z = 0; z < maker.num_legs; z++) {
                if (close_prices[z].close_price.price > legs[z].priceTarget) {
                    if (legs[z].outlook == true) {} else if (
                        legs[z].outlook == false
                    ) {
                        maker_won = false;
                    }
                } else if (
                    close_prices[z].close_price.price < legs[z].priceTarget
                ) {
                    if (legs[z].outlook == true) {
                        maker_won = false;
                    } else if (legs[z].outlook == false) {}
                } else {
                    // Handle Tie Scenario
                }
            }
            if (maker_won == false) {
                temp_winner = payable(taker.user);
            } else {
                temp_winner = payable(maker.user);
            }
        }
        return (temp_winner);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract PythStructs {

    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/consumers/best-practices for how
    // to how this price safely.
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    // PriceFeed represents a current aggregate price from pyth publisher feeds.
    struct PriceFeed {
        // The price ID.
        bytes32 id;
        // Latest available price
        Price price;
        // Latest available exponentially-weighted moving average price
        Price emaPrice;
    }
}

//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;
import "./HDGXStructs.sol";
import "./IPyth.sol";
import "./Settler.sol";

contract Orderbook {
    IPyth pyth;
    address public HedgeX_V2;
    address owner;

    uint256 makerOrderIDCount;
    uint256 takerOrderIDCount;
    mapping(bytes32 => uint256) public feedBidLiquidity;
    mapping(uint256 => HDGXStructs.MakerOrder) public makerOrdersByID;
    mapping(uint256 => HDGXStructs.TakerOrder) public takerOrdersByID;
    mapping(bytes32 => HDGXStructs.MakerOrder[]) public makerOrdersByFeedID;
    mapping(uint256 => bool) public makerOrderIDMatched;
    mapping(uint256 => bool) public makerOrderCanceled;
    mapping(uint256 => bool) public takerOrderIDSettled;
    mapping(uint256 => HDGXStructs.SettleOrder) public takerSettleOrder;
    mapping(uint256 => uint256) public makers_taker_ID;
    mapping(address => HDGXStructs.MakerOrder[]) public userMakerOrders;
    mapping(address => HDGXStructs.TakerOrder[]) public userTakerOrders;
    mapping(address => uint256) public userSettlerFeesEarned;
    mapping(uint256 => HDGXStructs.ClosePrice[]) public makersClosingPrices;
    mapping(uint256 => HDGXStructs.LockPrice[]) public makersLockPrices;
    mapping(uint256 => HDGXStructs.Leg[]) public makersLegs;

    constructor(address _pyth) {
        owner = msg.sender;
        pyth = IPyth(_pyth);
        makerOrderIDCount = 0;
        takerOrderIDCount = 0;
    }

    modifier onlyVault() {
        require(msg.sender == HedgeX_V2);
        _;
    }

    function owner_set_hedgex(address HDGXV2) public {
        require(msg.sender == owner);
        HedgeX_V2 = HDGXV2;
    }

    function orderbook_make_order(
        bytes calldata maker_info,
        bytes calldata legsEncoded
    )
        external
        onlyVault
        returns (
            address,
            uint256,
            uint256
        )
    {
        // Decode calldata info & calldata legs [].
        (
            address sender,
            uint256 valueSent,
            uint256 lockUpPeriod,
            int64 ratio
        ) = abi.decode(maker_info, (address, uint256, uint256, int64));

        HDGXStructs.Leg[] memory legs = abi.decode(
            legsEncoded,
            (HDGXStructs.Leg[])
        );

        // Construct maker-order struct.
        HDGXStructs.MakerOrder memory newOrder = HDGXStructs.MakerOrder(
            makerOrderIDCount + 1,
            sender,
            valueSent,
            legs.length,
            lockUpPeriod,
            ratio
        );
        makerOrdersByID[makerOrderIDCount + 1] = newOrder;
        userMakerOrders[sender].push(newOrder);

        // Iterate through position's legs.
        for (uint256 x = 0; x < legs.length; x++) {
            // Require lower-bound < upper-bound threshold.
            require(
                legs[x].threshold.lowerBound < legs[x].threshold.upperBound,
                "E05"
            );
            makerOrdersByFeedID[legs[x].feedID].push(newOrder);

            // Increment liquidity per feed.
            feedBidLiquidity[legs[x].feedID] =
                feedBidLiquidity[legs[x].feedID] +
                valueSent;

            // Track maker order's legs.
            makersLegs[makerOrderIDCount + 1].push(legs[x]);
        }
        makerOrderIDCount++;
        return (sender, makerOrderIDCount + 1, valueSent);
        // emit NewMakerOrder(msg.sender, makerOrderIDCount + 1, msg.value);
    }

    function orderbook_take_order(
        bytes calldata takerOrderInfo,
        bytes[] calldata priceUpdateData
    )
        external
        onlyVault
        returns (
            address,
            uint256,
            uint256,
            uint256
        )
    {
        // Decode calldata info & calldata updatedata.
        (address sender, uint256 valueSent, uint256 makerOrderID) = abi.decode(
            takerOrderInfo,
            (address, uint256, uint256)
        );

        // Fetch coorelated maker order to be matched.
        HDGXStructs.MakerOrder memory makerOrder = makerOrdersByID[
            makerOrderID
        ];

        // Valid price update data.
        require(priceUpdateData.length == makerOrder.num_legs, "E06");

        // No wash trading.
        require(sender != makerOrdersByID[makerOrderID].user, "E07");

        // Check to make sure order hasn't already been matched.
        require(makerOrderIDMatched[makerOrderID] == false, "E08");

        // Check to make sure order hasn't been canceled and liquidity already pulled.
        require(makerOrderCanceled[makerOrderID] == false, "E09");

        // Valid value sent required to match order.
        require(
            valueSent == orderbook_amtRequiredToTake(makerOrder.order_ID),
            "E10"
        );

        // Fetch pyth update fee & update all price feeds assosciated with maker order.
        uint256 pyth_fee = pyth.getUpdateFee(priceUpdateData.length);
        pyth.updatePriceFeeds{value: pyth_fee}(priceUpdateData);

        // Iterate maker position's legs
        for (uint256 i = 0; i < makerOrder.num_legs; i++) {
            // Fetch newest price of each leg.
            PythStructs.Price memory priceAssetUSD = pyth.getPrice(
                makersLegs[makerOrder.order_ID][i].feedID
            );

            // Require asset price is currently within take threshold established by the maker. (PriceThreshold.lowerBounds < Current price < PriceThreshold.upperBounds)
            require(
                (makersLegs[makerOrderID][i].threshold.lowerBound <
                    priceAssetUSD.price) &&
                    (priceAssetUSD.price <
                        makersLegs[makerOrderID][i].threshold.upperBound),
                "E12"
            );

            // Store lock-prices @ order-take. (visual verification for maker once order has been matched.)
            makersLockPrices[makerOrder.order_ID].push(
                HDGXStructs.LockPrice(
                    makersLegs[makerOrder.order_ID][i].feedID,
                    priceAssetUSD
                )
            );
        }

        // Initialize taker-order struct.
        HDGXStructs.TakerOrder memory newTakerOrder;
        if (makersLegs[makerOrder.order_ID].length > 1) {
            //Maker orders num_legs > 1, set outlook to false, any wrong outcome of maker order results in positive outcome for taker.
            newTakerOrder = HDGXStructs.TakerOrder(
                takerOrderIDCount + 1,
                sender,
                valueSent,
                block.timestamp,
                makerOrderID,
                false
            );
        } else if (makersLegs[makerOrder.order_ID].length == 1) {
            //else, negate outlook of maker
            newTakerOrder = HDGXStructs.TakerOrder(
                takerOrderIDCount + 1,
                sender,
                valueSent,
                block.timestamp,
                makerOrderID,
                !(makersLegs[makerOrderID][0].outlook)
            );
        }
        takerOrdersByID[takerOrderIDCount + 1] = newTakerOrder;
        userTakerOrders[sender].push(newTakerOrder);

        // Set maker order as matched & taken.
        makerOrderIDMatched[makerOrder.order_ID] = true;

        // Set assosciation between maker-order => taker-order.
        makers_taker_ID[makerOrderID] = takerOrderIDCount + 1;

        // Decrement open-bid liqudiity per feed.
        for (uint256 x = 0; x < makersLegs[makerOrderID].length; x++) {
            feedBidLiquidity[makersLegs[makerOrderID][x].feedID] =
                feedBidLiquidity[makersLegs[makerOrderID][x].feedID] -
                makerOrdersByID[makerOrderID].ethPosted;
        }
        takerOrderIDCount++;
        return (
            sender,
            makerOrder.order_ID,
            block.timestamp + makerOrder.lockUpPeriod,
            block.timestamp
        );
    }

    function orderbook_settle_order(
        bytes calldata settleInfo,
        bytes[] calldata priceUpdateData
    )
        external
        onlyVault
        returns (
            HDGXStructs.MakerOrder memory _maker,
            HDGXStructs.TakerOrder memory _taker,
            address payable _winner,
            uint256 _protocolFee
        )
    {
        // Decode calldata settleInfo & calldata priceUpdateData.
        (address sender, uint256 takerOrder_ID) = abi.decode(
            settleInfo,
            (address, uint256)
        );

        // Fetch assosciated maker & taker orders.
        HDGXStructs.TakerOrder memory taker = takerOrdersByID[takerOrder_ID];
        HDGXStructs.MakerOrder memory maker = makerOrdersByID[
            taker.makerOrder_ID
        ];

        // Require the lock-up period of the position has expired.
        require(
            block.timestamp > (taker.timeStampTaken + maker.lockUpPeriod),
            "E13"
        );

        // Require order isn't already settled.
        require(takerOrderIDSettled[takerOrder_ID] == false, "E14");

        // Require valid price update data.
        require(priceUpdateData.length == maker.num_legs, "E15");

        // Fetch the pyth update fee & update all cooresponding price feeds on-chain.
        uint256 pyth_fee = pyth.getUpdateFee(priceUpdateData.length);
        pyth.updatePriceFeeds{value: pyth_fee}(priceUpdateData);

        address payable winnerAddress;

        // Iterate each of maker order's legs and fetch the latest pyth price of each asset to be stored as "Close Price"
        for (uint256 i = 0; i < maker.num_legs; i++) {
            PythStructs.Price memory closingPrice = pyth.getPrice(
                makersLegs[maker.order_ID][i].feedID
            );
            makersClosingPrices[maker.order_ID].push(
                HDGXStructs.ClosePrice(
                    makersLegs[maker.order_ID][i].feedID,
                    closingPrice
                )
            );
        }

        bytes memory encodedForSettler = abi.encode(
            makersLegs[maker.order_ID],
            makersClosingPrices[maker.order_ID],
            maker,
            taker
        );

        // Pass all relevant position paramaters to be processed w/ Settler Library. Evaluates and returns winner address.
        winnerAddress = Settler.settlement_evaluation(encodedForSettler);

        // Set order as settled & finished.
        takerOrderIDSettled[takerOrder_ID] = true;

        // Construct settle-order struct.
        takerSettleOrder[takerOrder_ID] = HDGXStructs.SettleOrder(
            maker.order_ID,
            taker.order_ID,
            maker.user,
            taker.user,
            winnerAddress,
            sender,
            ((maker.ethPosted + taker.ethPosted) * 1) / 100,
            ((maker.ethPosted + taker.ethPosted) * 5) / 1000,
            ((maker.ethPosted + taker.ethPosted) * 975) / 1000,
            block.timestamp
        );

        // Track user's accumulated fees earned settling orders. Front-end helper mapping.
        userSettlerFeesEarned[sender] +=
            ((maker.ethPosted + taker.ethPosted) * 5) /
            1000;
        return (
            maker,
            taker,
            winnerAddress,
            ((maker.ethPosted + taker.ethPosted) * 1) / 100
        );
        // protocol_earnings += ((maker.ethPosted + taker.ethPosted) * 1) / 100;
    }

    // Public function to query the amount of ether required to match a particular maker-order
    function amt_required_to_take(uint256 makerOrderID)
        public
        view
        returns (uint256)
    {
        uint256 amtRequired = orderbook_amtRequiredToTake(makerOrderID);
        return amtRequired;
    }

    // Internal function to query the amount of ether required to match a particular maker-order
    function orderbook_amtRequiredToTake(uint256 makerOrderID)
        internal
        view
        returns (uint256 amtRequired)
    {
        // Fetch maker-order.
        HDGXStructs.MakerOrder memory makerOrder = makerOrdersByID[
            makerOrderID
        ];
        if (makerOrder.ratio < 0) {
            //i.e. maker ratio is -400, taker amt should be MakerOrder.ethPosted / (400/100)
            amtRequired =
                (makerOrder.ethPosted / Settler.negate64(makerOrder.ratio)) *
                100;
        } else {
            //i.e. maker ratio is +400, taker amt should be MakerOrder.ethPosted / (400/100)
            amtRequired =
                (makerOrder.ethPosted * uint64(makerOrder.ratio)) /
                100;
        }
    }

    function pyth_update_fee(bytes[] calldata priceUpdateData)
        public
        view
        returns (uint256 fee)
    {
        // Call getupdateFee on Pyth contract.
        fee = pyth.getUpdateFee(priceUpdateData.length);
    }

    // Cancel maker-order. Returns stake to msg.sender w/ no penalty fee.
    function cancelMakerOrder(uint256 _makerOrderID) public {
        require(msg.sender == makerOrdersByID[_makerOrderID].user);
        require(makerOrderCanceled[_makerOrderID] == false);
        makerOrderCanceled[_makerOrderID] = true;
        address payable payable_user = payable(msg.sender);
        for (uint256 x = 0; x < makerOrdersByID[_makerOrderID].num_legs; x++) {
            feedBidLiquidity[makersLegs[_makerOrderID][x].feedID] =
                feedBidLiquidity[makersLegs[_makerOrderID][x].feedID] -
                makerOrdersByID[_makerOrderID].ethPosted;
        }
        payable_user.transfer(makerOrdersByID[_makerOrderID].ethPosted);
    }

    function getUserMakerOrdersLength(address _user)
        public
        view
        returns (uint256)
    {
        return userMakerOrders[_user].length;
    }

    function getUserTakerOrdersLength(address _user)
        public
        view
        returns (uint256)
    {
        return userTakerOrders[_user].length;
    }

    function makerOrdersByFeedIDLength(bytes32 feedID)
        public
        view
        returns (uint256)
    {
        return makerOrdersByFeedID[feedID].length;
    }

    receive() external payable {
        // emit Received(msg.sender, msg.value);
    }
}

pragma solidity =0.8.17;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "./PythStructs.sol";

/// @title Consume prices from the Pyth Network (https://pyth.network/).
/// @dev Please refer to the guidance at https://docs.pyth.network/consumers/best-practices for how to consume prices safely.
/// @author Pyth Data Association
interface IPyth {
    /// @dev Emitted when an update for price feed with `id` is processed successfully.
    /// @param id The Pyth Price Feed ID.
    /// @param fresh True if the price update is more recent and stored.
    /// @param chainId ID of the source chain that the batch price update containing this price.
    /// This value comes from Wormhole, and you can find the corresponding chains at https://docs.wormholenetwork.com/wormhole/contracts.
    /// @param sequenceNumber Sequence number of the batch price update containing this price.
    /// @param lastPublishTime Publish time of the previously stored price.
    /// @param publishTime Publish time of the given price update.
    /// @param price Price of the given price update.
    /// @param conf Confidence interval of the given price update.
    event PriceFeedUpdate(bytes32 indexed id, bool indexed fresh, uint16 chainId, uint64 sequenceNumber, uint lastPublishTime, uint publishTime, int64 price, uint64 conf);

    /// @dev Emitted when a batch price update is processed successfully.
    /// @param chainId ID of the source chain that the batch price update comes from.
    /// @param sequenceNumber Sequence number of the batch price update.
    /// @param batchSize Number of prices within the batch price update.
    /// @param freshPricesInBatch Number of prices that were more recent and were stored.
    event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber, uint batchSize, uint freshPricesInBatch);

    /// @dev Emitted when a call to `updatePriceFeeds` is processed successfully.
    /// @param sender Sender of the call (`msg.sender`).
    /// @param batchCount Number of batches that this function processed.
    /// @param fee Amount of paid fee for updating the prices.
    event UpdatePriceFeeds(address indexed sender, uint batchCount, uint fee);

    /// @notice Returns the period (in seconds) that a price feed is considered valid since its publish time
    function getValidTimePeriod() external view returns (uint validTimePeriod);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `getValidTimePeriod()` seconds.
    /// @param id The Pyth Price Feed ID of which to fetch the price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price and confidence interval.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    /// @notice Update price feeds with given update messages.
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    /// Prices will be updated if they are more recent than the current stored prices.
    /// The call will succeed even if the update is not the most recent.
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. A price update is
    /// necessary if the current on-chain publishTime is older than the given publishTime. It relies solely on the
    /// given `publishTimes` for the price feeds and does not read the actual price update publish time within `updateData`.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    /// `priceIds` and `publishTimes` are two arrays with the same size that correspond to senders known publishTime
    /// of each priceId when calling this method. If all of price feeds within `priceIds` have updated and have
    /// a newer or equal publish time than the given publish time, it will reject the transaction to save gas.
    /// Otherwise, it calls updatePriceFeeds method to update the prices.
    ///
    /// @dev Reverts if update is not needed or the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param publishTimes Array of publishTimes. `publishTimes[i]` corresponds to known `publishTime` of `priceIds[i]`
    function updatePriceFeedsIfNecessary(bytes[] calldata updateData, bytes32[] calldata priceIds, uint64[] calldata publishTimes) external payable;

    /// @notice Returns the required fee to update an array of price updates.
    /// @param updateDataSize Number of price updates.
    /// @return feeAmount The required fee in Wei.
    function getUpdateFee(uint updateDataSize) external view returns (uint feeAmount);
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import "./PythStructs.sol";
contract HDGXStructs {

    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/consumers/best-practices for how
    // to how this price safely.
    struct Leg {
        bytes32 feedID;
        bool outlook;
        int64 priceTarget;
        PriceThreshold threshold;
    }
    struct LockPrice {
        bytes32 feedID;
        PythStructs.Price lock_price;
    }
    struct ClosePrice {
        bytes32 feedID;
        PythStructs.Price close_price;
    }
    struct MakerOrder {
        uint256 order_ID;
        address user;
        uint256 ethPosted;
        uint256 num_legs;
        uint256 lockUpPeriod;
        int64 ratio;
    }
    struct TakerOrder {
        uint256 order_ID;
        address user;
        uint256 ethPosted;
        uint256 timeStampTaken;
        uint256 makerOrder_ID;
        bool outlook;
    }
    struct SettleOrder {
        uint256 makerOrderID;
        uint256 takerOrderID;
        address maker;
        address taker;
        address winner;
        address settler;
        uint256 makerFees;
        uint256 settlerFees;
        uint256 winnerPayout;
        uint256 timeStampSettled;
        // ClosePrice[] close_prices;
    }
    struct PriceThreshold {
        int64 lowerBound;
        int64 upperBound;
    }
    
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}