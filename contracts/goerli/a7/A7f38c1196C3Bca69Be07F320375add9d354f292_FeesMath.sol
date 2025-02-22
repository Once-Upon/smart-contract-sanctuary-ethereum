// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import '@dex/lib/Structs.sol';
import '@dex/lib/FinMath.sol';

import '@dex/perp/interfaces/IConfig.sol';

import {PriceData} from '@dex/oracles/interfaces/IOracle.sol';

library FeesMath {
    using FinMath for uint;
    using FinMath for uint24;
    using FinMath for int24;

    // @dev External function used in engine to compute premium and premium fee
    function premium(
        Order storage o,
        PriceData memory p,
        int24 premiumBps,
        IConfig config,
        uint8 minPremiumFeeDiscountPerc
    ) public view returns (int premium_, uint premiumFee) {
        uint notional = o.amount.wmul(p.price);
        premium_ = premiumBps.bps(notional);
        int fee = config.premiumFeeBps().bps(premium_);
        int _minPremiumFee = int(
            (config.getAmounts().minPremiumFee *
                uint((minPremiumFeeDiscountPerc))) / 100
        );
        premiumFee = uint((fee > _minPremiumFee) ? fee : _minPremiumFee);
    }

    // @dev External function used in engine.
    function traderFees(
        Order storage o,
        PriceData memory p,
        IConfig config
    ) external view returns (uint) {
        uint notional = o.amount.wmul(p.price);
        int fee = config.traderFeeBps().bps(int(notional));
        return uint(fee);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import '@dex/lib/SafeCast.sol';

// Percentage using BPS
// https://stackoverflow.com/questions/3730019/why-not-use-double-or-float-to-represent-currency/3730040#3730040
// Ranges:
// int(x): -2^(x-1) to [2^(x-1)]-1
// uint(x): 0 to [2^(x)]-1

// @notice Simple multiplication with native overflow protection for uint when
// using solidity above 0.8.17.
library FinMath {
    using SafeCast for uint;
    using SafeCast for int;

    // Bps
    int public constant iBPS = 10 ** 4; // basis points [TODO: move to 10**4]
    uint public constant uBPS = 10 ** 4; // basis points [TODO: move to 10**4]

    // Fixed Point arithimetic
    uint constant WAD = 10 ** 18;
    int constant iWAD = 10 ** 18;
    uint constant LIMIT = 2 ** 255;

    int internal constant iMAX_128 = 0x100000000000000000000000000000000; // 2^128
    int internal constant iMIN_128 = -0x100000000000000000000000000000000; // 2^128
    uint internal constant uMAX_128 = 0x100000000000000000000000000000000; // 2^128

    // --- SIGNED CAST FREE

    function mul(int x, int y) internal pure returns (int z) {
        z = x * y;
    }

    function div(int a, int b) internal pure returns (int z) {
        z = a / b;
    }

    function sub(int a, int b) internal pure returns (int z) {
        z = a - b;
    }

    function add(int a, int b) internal pure returns (int z) {
        z = a + b;
    }

    // --- UNSIGNED CAST FREE

    function mul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
    }

    function div(uint a, uint b) internal pure returns (uint z) {
        z = a / b;
    }

    function add(uint a, uint b) internal pure returns (uint z) {
        z = a + b;
    }

    function sub(uint a, uint b) internal pure returns (uint z) {
        z = a - b;
    }

    // --- MIXED TYPES SAFE CAST
    function mul(uint x, int y) internal pure returns (int z) {
        z = x.i256() * y;
    }

    function div(int a, uint b) internal pure returns (int z) {
        z = a / b.i256();
    }

    function add(uint x, int y) internal pure returns (uint z) {
        bool flip = y < 0 ? true : false;
        z = flip ? x - (-y).u256() : x + y.u256();
    }

    function add(int x, uint y) internal pure returns (int z) {
        z = x + y.i256();
    }

    function sub(uint x, int y) internal pure returns (uint z) {
        bool flip = y < 0 ? true : false;
        z = flip ? x + (-y).u256() : x - y.u256();
    }

    function sub(int x, uint y) internal pure returns (int z) {
        z = x - y.i256();
    }

    function isub(uint x, uint y) internal pure returns (int z) {
        int x1 = x.i256();
        int y1 = y.i256();
        z = x1 - y1;
    }

    // --- FIXED POINT [1e18 precision]

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wmul(int x, int y) internal pure returns (int z) {
        z = add(mul(x, y), iWAD / 2) / iWAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function wdiv(int x, int y) internal pure returns (int z) {
        z = add(mul(x, iWAD), y / 2) / y;
    }

    // --- FIXED POINT BPS [1e4 precision]

    // @notice Calculate percentage using BPS precision
    // @param bps input in base points
    // @param x the number we want to calculate percentage
    // @return the % of the x including fixed-point arithimetic
    function bps(int bp, uint x) internal pure returns (int z) {
        require(bp < iMAX_128, 'bps-x-overflow');
        z = (mul(x.i256(), bp)) / iBPS;
    }

    function bps(uint bp, uint x) internal pure returns (uint z) {
        require(bp < uMAX_128, 'bps-x-overflow');
        z = mul(x, bp) / uBPS;
    }

    function bps(uint bp, int x) internal pure returns (int z) {
        require(bp < uMAX_128, 'bps-x-overflow');
        z = mul(x, bp.i256()) / iBPS;
    }

    function bps(int bp, int x) internal pure returns (int z) {
        require(bp < iMAX_128, 'bps-x-overflow');
        z = mul(x, bp) / iBPS;
    }

    function ibps(uint bp, uint x) internal pure returns (int z) {
        require(bp < uMAX_128, 'bps-x-overflow');
        z = (mul(x, bp) / uBPS).i256();
    }

    // @dev Transform to BPS precision
    function bps(uint x) internal pure returns (uint) {
        return mul(x, uBPS);
    }

    // @notice Return the positive number of an int256 or zero if it was negative
    // @parame x the number we want to normalize
    // @return zero or a positive number
    function pos(int a) internal pure returns (uint) {
        return (a >= 0) ? uint(a) : 0;
    }

    // @notice somethimes we need to print int but cast them to uint befor
    function inv(int x) internal pure returns (uint z) {
        z = x < 0 ? uint(-x) : uint(x);
    }

    // @notice Copied from open-zeppelin SignedMath
    // @dev must be unchecked in order to support `n = type(int256).min`
    function abs(int x) internal pure returns (uint) {
        unchecked {
            return uint(x >= 0 ? x : -x);
        }
    }

    // --- MINIMUM and MAXIMUM

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }

    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }

    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }

    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Uniswap lib
pragma solidity 0.8.17;

// @title Safe casting methods
// @notice Contains methods for safely casting between types
library SafeCast {
    // @notice Cast a uint256 to a uint160, revert on overflow
    // @param y The uint256 to be downcasted
    // @return z The downcasted integer, now type uint160
    function u160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y, 'cast-u160');
    }

    // @notice Cast a int256 to a int128, revert on overflow or underflow
    // @param y The int256 to be downcasted
    // @return z The downcasted integer, now type int128
    function i128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y, 'cast-i128');
    }

    // @notice Cast a uint256 to a int256, revert on overflow
    // @param y The uint256 to be casted
    // @return z The casted integer, now type int256
    function i256(uint256 y) internal pure returns (int256 z) {
        require(y < 2 ** 255, 'cast-i256');
        z = int256(y);
    }

    // @notice Cast an int256, check if it's not negative
    // @param y The uint256 to be downcasted
    // @return z The downcasted integer, now type uint160
    function u256(int256 y) internal pure returns (uint256 z) {
        require(y >= 0, 'cast-u256');
        z = uint256(y);
    }
}

pragma solidity ^0.8.17;

struct Match {
    int8 pos; // If maker is short = true
    int24 premiumBps; // In percent of the amount
    uint24 frPerYear;
    uint24 fmfrPerYear; // The fair market funding rate when the match was done
    uint maker; // maker vault token-id
    uint trader; // trader vault token-id
    uint amount;
    uint start; // timestamp of the match starting
    uint entryPrice;
    uint collateralM; // Maker  collateral
    uint collateralT; // Trader collateral
    // uint256 nextMatchId; // Next match id, in case of split, used by the automatic rerooting
    uint8 minPremiumFeeDiscountPerc; // To track what perc of minPreomiumFee to pay, used when the order is split
    bool close; // A close request for this match is pending
}

struct Order {
    bool canceled;
    int8 pos;
    address owner; // trader address
    uint tokenId;
    uint matchId; // trader selected matchid
    uint amount;
    uint collateral;
    uint collateralAdd;
    // NOTE: Used to apply the check for the Oracle Latency Protection
    uint timestamp;
    // NOTE: In this case, we give trader the max full control on the price for matching: no assumption it is symmetric and we do not compute any percentage so introducing some approximations, the trader writes the desired prices
    uint slippageMinPrice;
    uint slippageMaxPrice;
    uint maxTimestamp;
}

struct CloseOrder {
    uint matchId;
    uint timestamp;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

struct PriceData {
    // wad
    uint256 price;
    uint256 timestamp;
}

interface IOracle {
    event NewValue(uint256 value, uint256 timestamp);

    function setPrice(uint256 _value) external;

    function decimals() external view returns (uint8);

    function getPrice() external view returns (PriceData memory);
}

pragma solidity ^0.8.17;

struct Bips {
    uint24 bufferTraderBps;
    uint24 bufferMakerBps;
    uint24 openInterestCap; // 4 decimals (bips)
    uint24 fmfrPerYear; // 4 decimals (bips)
    uint24 frPerYearModulo; // 4 decimals (bips)
    uint24 premiumFeeBps; // % of the premium that protocol collects
    uint24 minFRPerYear; // 4 decimals (bips)
    uint24 traderFeeBps; // 4 decimals (bips)
    uint24 makerFRFeeBps; // 4 decimals (bips)
}

struct Amounts {
    uint bufferTrader;
    uint bufferMaker;
    uint128 minPremiumFee;
    uint128 orderMinAmount;
}

// @dev Leverage is defined by the formula:
// (units * openingPrice) / (collateral + accruedFR)
// maxLeverage is a market-specific governance parameter that
// determines maximum leverage for traders and makers.
// Like in PerpV2, we have 2 max leverages: one for when the position is opened and
// the other for the position ongoing. Leverage [lev] is defined by:
// if (FR < FMFR) {
//     lev = s.mul(b).mul(365).div(T-t).div(FMFR-FR+f0);
//     lev = lev < maxLev ? lev : maxLev;
// } else { lev = maxLeverage; }
// s  = scaling factor (governance parameter)
// b  = buffer (fraction, so ultimately affects denominator)
// T  = expiry (i.e. 180 days)
// t  = elapsed time since contract created
// FR = funding rate set by maker creating offer
// f0 = linear shift (governance parameter)
// FMFR = fair market funding rate (market-specific governance risk parameter)
// Atm we do not support negative FR

struct Leverage {
    uint24 maxLeverageOpen;
    uint24 maxLeverageOngoing;
    uint24 minGuaranteedLeverage;
    uint s;
    uint b;
    uint f0;
    uint maxTimeGuarantee; // Example 180 days
    uint FRTemporalBasis; // In case the above is measured in days then it is 365 days
}

interface IConfig {
    function maxTimeGuarantee() external view returns (uint);

    function fmfrPerYear() external view returns (uint24);

    function premiumFeeBps() external view returns (uint24);

    function openInterestCap() external view returns (uint24);

    function frPerYearModulo() external view returns (uint24);

    function minFRPerYear() external view returns (uint24);

    function traderFeeBps() external view returns (uint24);

    function bufferTraderBps() external view returns (uint24);

    function bufferMakerBps() external view returns (uint24);

    function makerFRFeeBps() external view returns (uint24);

    function bufferTrader() external view returns (uint);

    function bufferMaker() external view returns (uint);

    function getLeverage() external view returns (Leverage memory);

    function getBips() external view returns (Bips memory);

    function getAmounts() external view returns (Amounts memory);

    function setLeverage(Leverage calldata leverage) external;

    function setBips(Bips calldata) external;

    function setAmounts(Amounts calldata) external;

    function initialize(address owner) external;
}