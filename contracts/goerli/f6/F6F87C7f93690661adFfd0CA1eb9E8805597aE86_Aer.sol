/**
 *Submitted for verification at Etherscan.io on 2022-03-07
*/

// Verified using https://dapp.tools

// hevm: flattened sources of lib/fiat/src/Aer.sol
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later AND Unlicensed
pragma solidity >=0.8.0 <0.9.0 >=0.8.4 <0.9.0;

////// lib/fiat/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

/* pragma solidity ^0.8.0; */

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
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

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

////// lib/fiat/src/interfaces/ICodex.sol
/* pragma solidity ^0.8.4; */

interface ICodex {
    function init(address vault) external;

    function setParam(bytes32 param, uint256 data) external;

    function setParam(
        address,
        bytes32,
        uint256
    ) external;

    function credit(address) external view returns (uint256);

    function unbackedDebt(address) external view returns (uint256);

    function balances(
        address,
        uint256,
        address
    ) external view returns (uint256);

    function vaults(address vault)
        external
        view
        returns (
            uint256 totalNormalDebt,
            uint256 rate,
            uint256 debtCeiling,
            uint256 debtFloor
        );

    function positions(
        address vault,
        uint256 tokenId,
        address position
    ) external view returns (uint256 collateral, uint256 normalDebt);

    function globalDebt() external view returns (uint256);

    function globalUnbackedDebt() external view returns (uint256);

    function globalDebtCeiling() external view returns (uint256);

    function delegates(address, address) external view returns (uint256);

    function grantDelegate(address) external;

    function revokeDelegate(address) external;

    function modifyBalance(
        address,
        uint256,
        address,
        int256
    ) external;

    function transferBalance(
        address vault,
        uint256 tokenId,
        address src,
        address dst,
        uint256 amount
    ) external;

    function transferCredit(
        address src,
        address dst,
        uint256 amount
    ) external;

    function modifyCollateralAndDebt(
        address vault,
        uint256 tokenId,
        address user,
        address collateralizer,
        address debtor,
        int256 deltaCollateral,
        int256 deltaNormalDebt
    ) external;

    function transferCollateralAndDebt(
        address vault,
        uint256 tokenId,
        address src,
        address dst,
        int256 deltaCollateral,
        int256 deltaNormalDebt
    ) external;

    function confiscateCollateralAndDebt(
        address vault,
        uint256 tokenId,
        address user,
        address collateralizer,
        address debtor,
        int256 deltaCollateral,
        int256 deltaNormalDebt
    ) external;

    function settleUnbackedDebt(uint256 debt) external;

    function createUnbackedDebt(
        address debtor,
        address creditor,
        uint256 debt
    ) external;

    function modifyRate(
        address vault,
        address creditor,
        int256 rate
    ) external;

    function lock() external;
}

////// lib/fiat/src/interfaces/IDebtAuction.sol
/* pragma solidity ^0.8.4; */

/* import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol"; */

/* import {ICodex} from "./ICodex.sol"; */

interface IDebtAuction {
    function auctions(uint256)
        external
        view
        returns (
            uint256,
            uint256,
            address,
            uint48,
            uint48
        );

    function codex() external view returns (ICodex);

    function token() external view returns (IERC20);

    function minBidBump() external view returns (uint256);

    function tokenToSellBump() external view returns (uint256);

    function bidDuration() external view returns (uint48);

    function auctionDuration() external view returns (uint48);

    function auctionCounter() external view returns (uint256);

    function live() external view returns (uint256);

    function aer() external view returns (address);

    function setParam(bytes32 param, uint256 data) external;

    function startAuction(
        address recipient,
        uint256 tokensToSell,
        uint256 bid
    ) external returns (uint256 id);

    function redoAuction(uint256 id) external;

    function submitBid(
        uint256 id,
        uint256 tokensToSell,
        uint256 bid
    ) external;

    function closeAuction(uint256 id) external;

    function lock() external;

    function cancelAuction(uint256 id) external;
}

////// lib/fiat/src/interfaces/ISurplusAuction.sol
/* pragma solidity ^0.8.4; */

/* import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol"; */

/* import {ICodex} from "./ICodex.sol"; */

interface ISurplusAuction {
    function auctions(uint256)
        external
        view
        returns (
            uint256,
            uint256,
            address,
            uint48,
            uint48
        );

    function codex() external view returns (ICodex);

    function token() external view returns (IERC20);

    function minBidBump() external view returns (uint256);

    function bidDuration() external view returns (uint48);

    function auctionDuration() external view returns (uint48);

    function auctionCounter() external view returns (uint256);

    function live() external view returns (uint256);

    function setParam(bytes32 param, uint256 data) external;

    function startAuction(uint256 creditToSell, uint256 bid) external returns (uint256 id);

    function redoAuction(uint256 id) external;

    function submitBid(
        uint256 id,
        uint256 creditToSell,
        uint256 bid
    ) external;

    function closeAuction(uint256 id) external;

    function lock(uint256 credit) external;

    function cancelAuction(uint256 id) external;
}

////// lib/fiat/src/interfaces/IAer.sol
/* pragma solidity ^0.8.4; */

/* import {ICodex} from "./ICodex.sol"; */
/* import {IDebtAuction} from "./IDebtAuction.sol"; */
/* import {ISurplusAuction} from "./ISurplusAuction.sol"; */

interface IAer {
    function codex() external view returns (ICodex);

    function surplusAuction() external view returns (ISurplusAuction);

    function debtAuction() external view returns (IDebtAuction);

    function debtQueue(uint256) external view returns (uint256);

    function queuedDebt() external view returns (uint256);

    function debtOnAuction() external view returns (uint256);

    function auctionDelay() external view returns (uint256);

    function debtAuctionSellSize() external view returns (uint256);

    function debtAuctionBidSize() external view returns (uint256);

    function surplusAuctionSellSize() external view returns (uint256);

    function surplusBuffer() external view returns (uint256);

    function live() external view returns (uint256);

    function setParam(bytes32 param, uint256 data) external;

    function setParam(bytes32 param, address data) external;

    function queueDebt(uint256 debt) external;

    function unqueueDebt(uint256 queuedAt) external;

    function settleDebtWithSurplus(uint256 debt) external;

    function settleAuctionedDebt(uint256 debt) external;

    function startDebtAuction() external returns (uint256 auctionId);

    function startSurplusAuction() external returns (uint256 auctionId);

    function transferCredit(address to, uint256 credit) external;

    function lock() external;
}

////// lib/fiat/src/interfaces/IGuarded.sol
/* pragma solidity ^0.8.4; */

interface IGuarded {
    function ANY_SIG() external view returns (bytes32);

    function ANY_CALLER() external view returns (address);

    function allowCaller(bytes32 sig, address who) external;

    function blockCaller(bytes32 sig, address who) external;

    function canCall(bytes32 sig, address who) external view returns (bool);
}

////// lib/fiat/src/utils/Guarded.sol
/* pragma solidity ^0.8.4; */

/* import {IGuarded} from "../interfaces/IGuarded.sol"; */

/// @title Guarded
/// @notice Mixin implementing an authentication scheme on a method level
abstract contract Guarded is IGuarded {
    /// ======== Custom Errors ======== ///

    error Guarded__notRoot();
    error Guarded__notGranted();

    /// ======== Storage ======== ///

    /// @notice Wildcard for granting a caller to call every guarded method
    bytes32 public constant override ANY_SIG = keccak256("ANY_SIG");
    /// @notice Wildcard for granting a caller to call every guarded method
    address public constant override ANY_CALLER = address(uint160(uint256(bytes32(keccak256("ANY_CALLER")))));

    /// @notice Mapping storing who is granted to which method
    /// @dev Method Signature => Caller => Bool
    mapping(bytes32 => mapping(address => bool)) private _canCall;

    /// ======== Events ======== ///

    event AllowCaller(bytes32 sig, address who);
    event BlockCaller(bytes32 sig, address who);

    constructor() {
        // set root
        _setRoot(msg.sender);
    }

    /// ======== Auth ======== ///

    modifier callerIsRoot() {
        if (_canCall[ANY_SIG][msg.sender]) {
            _;
        } else revert Guarded__notRoot();
    }

    modifier checkCaller() {
        if (canCall(msg.sig, msg.sender)) {
            _;
        } else revert Guarded__notGranted();
    }

    /// @notice Grant the right to call method `sig` to `who`
    /// @dev Only the root user (granted `ANY_SIG`) is able to call this method
    /// @param sig Method signature (4Byte)
    /// @param who Address of who should be able to call `sig`
    function allowCaller(bytes32 sig, address who) public override callerIsRoot {
        _canCall[sig][who] = true;
        emit AllowCaller(sig, who);
    }

    /// @notice Revoke the right to call method `sig` from `who`
    /// @dev Only the root user (granted `ANY_SIG`) is able to call this method
    /// @param sig Method signature (4Byte)
    /// @param who Address of who should not be able to call `sig` anymore
    function blockCaller(bytes32 sig, address who) public override callerIsRoot {
        _canCall[sig][who] = false;
        emit BlockCaller(sig, who);
    }

    /// @notice Returns if `who` can call `sig`
    /// @param sig Method signature (4Byte)
    /// @param who Address of who should be able to call `sig`
    function canCall(bytes32 sig, address who) public view override returns (bool) {
        return (_canCall[sig][who] || _canCall[ANY_SIG][who] || _canCall[sig][ANY_CALLER]);
    }

    /// @notice Sets the root user (granted `ANY_SIG`)
    /// @param root Address of who should be set as root
    function _setRoot(address root) internal {
        _canCall[ANY_SIG][root] = true;
        emit AllowCaller(ANY_SIG, root);
    }

    /// @notice Unsets the root user (granted `ANY_SIG`)
    /// @param root Address of who should be unset as root
    function _unsetRoot(address root) internal {
        _canCall[ANY_SIG][root] = false;
        emit AllowCaller(ANY_SIG, root);
    }
}

////// lib/fiat/src/utils/Math.sol
// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC.
/* pragma solidity ^0.8.4; */

uint256 constant MLN = 10**6;
uint256 constant BLN = 10**9;
uint256 constant WAD = 10**18;
uint256 constant RAY = 10**18;
uint256 constant RAD = 10**18;

/* solhint-disable func-visibility, no-inline-assembly */

error Math__toInt256_overflow(uint256 x);

function toInt256(uint256 x) pure returns (int256) {
    if (x > uint256(type(int256).max)) revert Math__toInt256_overflow(x);
    return int256(x);
}

function min(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        z = x <= y ? x : y;
    }
}

function max(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        z = x >= y ? x : y;
    }
}

error Math__diff_overflow(uint256 x, uint256 y);

function diff(uint256 x, uint256 y) pure returns (int256 z) {
    unchecked {
        z = int256(x) - int256(y);
        if (!(int256(x) >= 0 && int256(y) >= 0)) revert Math__diff_overflow(x, y);
    }
}

error Math__add_overflow(uint256 x, uint256 y);

function add(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        if ((z = x + y) < x) revert Math__add_overflow(x, y);
    }
}

error Math__add48_overflow(uint256 x, uint256 y);

function add48(uint48 x, uint48 y) pure returns (uint48 z) {
    unchecked {
        if ((z = x + y) < x) revert Math__add48_overflow(x, y);
    }
}

error Math__add_overflow_signed(uint256 x, int256 y);

function add(uint256 x, int256 y) pure returns (uint256 z) {
    unchecked {
        z = x + uint256(y);
        if (!(y >= 0 || z <= x)) revert Math__add_overflow_signed(x, y);
        if (!(y <= 0 || z >= x)) revert Math__add_overflow_signed(x, y);
    }
}

error Math__sub_overflow(uint256 x, uint256 y);

function sub(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        if ((z = x - y) > x) revert Math__sub_overflow(x, y);
    }
}

error Math__sub_overflow_signed(uint256 x, int256 y);

function sub(uint256 x, int256 y) pure returns (uint256 z) {
    unchecked {
        z = x - uint256(y);
        if (!(y <= 0 || z <= x)) revert Math__sub_overflow_signed(x, y);
        if (!(y >= 0 || z >= x)) revert Math__sub_overflow_signed(x, y);
    }
}

error Math__mul_overflow(uint256 x, uint256 y);

function mul(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        if (!(y == 0 || (z = x * y) / y == x)) revert Math__mul_overflow(x, y);
    }
}

error Math__mul_overflow_signed(uint256 x, int256 y);

function mul(uint256 x, int256 y) pure returns (int256 z) {
    unchecked {
        z = int256(x) * y;
        if (int256(x) < 0) revert Math__mul_overflow_signed(x, y);
        if (!(y == 0 || z / y == int256(x))) revert Math__mul_overflow_signed(x, y);
    }
}

function wmul(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        z = mul(x, y) / WAD;
    }
}

function wmul(uint256 x, int256 y) pure returns (int256 z) {
    unchecked {
        z = mul(x, y) / int256(WAD);
    }
}

error Math__div_overflow(uint256 x, uint256 y);

function div(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        if (y == 0) revert Math__div_overflow(x, y);
        return x / y;
    }
}

function wdiv(uint256 x, uint256 y) pure returns (uint256 z) {
    unchecked {
        z = mul(x, WAD) / y;
    }
}

// optimized version from dss PR #78
function wpow(
    uint256 x,
    uint256 n,
    uint256 b
) pure returns (uint256 z) {
    unchecked {
        assembly {
            switch n
            case 0 {
                z := b
            }
            default {
                switch x
                case 0 {
                    z := 0
                }
                default {
                    switch mod(n, 2)
                    case 0 {
                        z := b
                    }
                    default {
                        z := x
                    }
                    let half := div(b, 2) // for rounding.
                    for {
                        n := div(n, 2)
                    } n {
                        n := div(n, 2)
                    } {
                        let xx := mul(x, x)
                        if shr(128, x) {
                            revert(0, 0)
                        }
                        let xxRound := add(xx, half)
                        if lt(xxRound, xx) {
                            revert(0, 0)
                        }
                        x := div(xxRound, b)
                        if mod(n, 2) {
                            let zx := mul(z, x)
                            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                                revert(0, 0)
                            }
                            let zxRound := add(zx, half)
                            if lt(zxRound, zx) {
                                revert(0, 0)
                            }
                            z := div(zxRound, b)
                        }
                    }
                }
            }
        }
    }
}

/* solhint-disable func-visibility, no-inline-assembly */

////// lib/fiat/src/Aer.sol
// Copyright (C) 2018 Rain <[email protected]>
/* pragma solidity ^0.8.4; */

/* import {ICodex} from "./interfaces/ICodex.sol"; */
/* import {IDebtAuction} from "./interfaces/IDebtAuction.sol"; */
/* import {IAer} from "./interfaces/IAer.sol"; */
/* import {ISurplusAuction} from "./interfaces/ISurplusAuction.sol"; */

/* import {Guarded} from "./utils/Guarded.sol"; */
/* import {WAD, min, add, sub} from "./utils/Math.sol"; */

/// @title Aer (short for Aerarium)
/// @notice `Aer` is used for managing the protocol's debt and surplus balances via the DebtAuction and
/// SurplusAuction contracts.
/// Uses Vow.sol from DSS (MakerDAO) / AccountingEngine.sol from GEB (Reflexer Labs) as a blueprint
/// Changes from Vow.sol / AccountingEngine.sol:
/// - only WAD precision is used (no RAD and RAY)
/// - uses a method signature based authentication scheme
contract Aer is Guarded, IAer {
    /// ======== Custom Errors ======== ///

    error Aer__setParam_unrecognizedParam();
    error Aer__unqueueDebt_auctionDelayNotPassed();
    error Aer__settleDebtWithSurplus_insufficientSurplus();
    error Aer__settleDebtWithSurplus_insufficientDebt();
    error Aer__settleAuctionedDebt_notEnoughDebtOnAuction();
    error Aer__settleAuctionedDebt_insufficientSurplus();
    error Aer__startDebtAuction_insufficientDebt();
    error Aer__startDebtAuction_surplusNotZero();
    error Aer__startSurplusAuction_insufficientSurplus();
    error Aer__startSurplusAuction_debtNotZero();
    error Aer__transferCredit_insufficientCredit();
    error Aer__lock_notLive();

    /// ======== Storage ======== ///

    /// @notice Codex
    ICodex public immutable override codex;
    /// @notice SurplusAuction
    ISurplusAuction public override surplusAuction;
    /// @notice DebtAuction
    IDebtAuction public override debtAuction;

    /// @notice List of debt amounts to be auctioned sorted by the time at which they where queued
    /// @dev Queued at timestamp => Debt [wad]
    mapping(uint256 => uint256) public override debtQueue;
    /// @notice Queued debt amount [wad]
    uint256 public override queuedDebt;
    /// @notice Amount of debt currently on auction [wad]
    uint256 public override debtOnAuction;

    /// @notice Time after which queued debt can be put up for auction [seconds]
    uint256 public override auctionDelay;
    /// @notice Amount of tokens to sell in each debt auction [wad]
    uint256 public override debtAuctionSellSize;
    /// @notice Min. amount of (credit to bid or debt to sell) for tokens [wad]
    uint256 public override debtAuctionBidSize;

    /// @notice Amount of credit to sell in each surplus auction [wad]
    uint256 public override surplusAuctionSellSize;
    /// @notice Amount of credit required for starting a surplus auction [wad]
    uint256 public override surplusBuffer;

    /// @notice Boolean indicating if this contract is live (0 - not live, 1 - live)
    uint256 public override live;

    /// ======== Events ======== ///
    event SetParam(bytes32 indexed param, uint256 data);
    event SetParam(bytes32 indexed param, address indexed data);
    event QueueDebt(uint256 indexed queuedAt, uint256 debtQueue, uint256 queuedDebt);
    event UnqueueDebt(uint256 indexed queuedAt, uint256 queuedDebt);
    event StartDebtAuction(uint256 debtOnAuction, uint256 indexed auctionId);
    event SettleAuctionedDebt(uint256 debtOnAuction);
    event StartSurplusAuction(uint256 indexed auctionId);
    event SettleDebtWithSurplus(uint256 debt);
    event Lock();

    constructor(
        address codex_,
        address surplusAuction_,
        address debtAuction_
    ) Guarded() {
        codex = ICodex(codex_);
        surplusAuction = ISurplusAuction(surplusAuction_);
        debtAuction = IDebtAuction(debtAuction_);
        ICodex(codex_).grantDelegate(surplusAuction_);
        live = 1;
    }

    /// ======== Configuration ======== ///

    /// @notice Sets various variables for this contract
    /// @dev Sender has to be allowed to call this method
    /// @param param Name of the variable to set
    /// @param data New value to set for the variable [wad]
    function setParam(bytes32 param, uint256 data) external override checkCaller {
        if (param == "auctionDelay") auctionDelay = data;
        else if (param == "surplusAuctionSellSize") surplusAuctionSellSize = data;
        else if (param == "debtAuctionBidSize") debtAuctionBidSize = data;
        else if (param == "debtAuctionSellSize") debtAuctionSellSize = data;
        else if (param == "surplusBuffer") surplusBuffer = data;
        else revert Aer__setParam_unrecognizedParam();
        emit SetParam(param, data);
    }

    /// @notice Sets various variables for this contract
    /// @dev Sender has to be allowed to call this method
    /// @param param Name of the variable to set
    /// @param data New value to set for the variable [address]
    function setParam(bytes32 param, address data) external override checkCaller {
        if (param == "surplusAuction") {
            codex.revokeDelegate(address(surplusAuction));
            surplusAuction = ISurplusAuction(data);
            codex.grantDelegate(data);
        } else if (param == "debtAuction") debtAuction = IDebtAuction(data);
        else revert Aer__setParam_unrecognizedParam();
        emit SetParam(param, data);
    }

    /// ======== Debt Auction ======== ///

    /// @notice Pushes new debt to the debt queue
    /// @dev Sender has to be allowed to call this method
    /// @param debt Amount of debt [wad]
    function queueDebt(uint256 debt) external override checkCaller {
        debtQueue[block.timestamp] = add(debtQueue[block.timestamp], debt);
        queuedDebt = add(queuedDebt, debt);
        emit QueueDebt(block.timestamp, debtQueue[block.timestamp], queuedDebt);
    }

    /// @notice Pops debt from the debt queue
    /// @param queuedAt Timestamp at which the debt has been queued [seconds]
    function unqueueDebt(uint256 queuedAt) external override {
        if (add(queuedAt, auctionDelay) > block.timestamp) revert Aer__unqueueDebt_auctionDelayNotPassed();
        queuedDebt = sub(queuedDebt, debtQueue[queuedAt]);
        debtQueue[queuedAt] = 0;
        emit UnqueueDebt(queuedAt, queuedDebt);
    }

    /// @notice Starts a debt auction
    /// @dev Sender has to be allowed to call this method
    /// Checks if enough debt exists to be put up for auction
    /// debtAuctionBidSize > (unbackedDebt - queuedDebt - debtOnAuction)
    /// @return auctionId Id of the debt auction
    function startDebtAuction() external override checkCaller returns (uint256 auctionId) {
        if (debtAuctionBidSize > sub(sub(codex.unbackedDebt(address(this)), queuedDebt), debtOnAuction))
            revert Aer__startDebtAuction_insufficientDebt();
        if (codex.credit(address(this)) != 0) revert Aer__startDebtAuction_surplusNotZero();
        debtOnAuction = add(debtOnAuction, debtAuctionBidSize);
        auctionId = debtAuction.startAuction(address(this), debtAuctionSellSize, debtAuctionBidSize);
        emit StartDebtAuction(debtOnAuction, auctionId);
    }

    /// @notice Settles debt collected from debt auctions
    /// @dev Cannot settle debt with accrued surplus (only from debt auctions)
    /// @param debt Amount of debt to settle [wad]
    function settleAuctionedDebt(uint256 debt) external override {
        if (debt > debtOnAuction) revert Aer__settleAuctionedDebt_notEnoughDebtOnAuction();
        if (debt > codex.credit(address(this))) revert Aer__settleAuctionedDebt_insufficientSurplus();
        debtOnAuction = sub(debtOnAuction, debt);
        codex.settleUnbackedDebt(debt);
        emit SettleAuctionedDebt(debtOnAuction);
    }

    /// ======== Surplus Auction ======== ///

    /// @notice Starts a surplus auction
    /// @dev Sender has to be allowed to call this method
    /// Checks if enough surplus has accrued (surplusAuctionSellSize + surplusBuffer) and there's
    /// no queued debt to be put up for a debt auction
    /// @return auctionId Id of the surplus auction
    function startSurplusAuction() external override checkCaller returns (uint256 auctionId) {
        if (
            codex.credit(address(this)) <
            add(add(codex.unbackedDebt(address(this)), surplusAuctionSellSize), surplusBuffer)
        ) revert Aer__startSurplusAuction_insufficientSurplus();
        if (sub(sub(codex.unbackedDebt(address(this)), queuedDebt), debtOnAuction) != 0)
            revert Aer__startSurplusAuction_debtNotZero();
        auctionId = surplusAuction.startAuction(surplusAuctionSellSize, 0);
        emit StartSurplusAuction(auctionId);
    }

    /// @notice Settles debt with the accrued surplus
    /// @dev Sender has to be allowed to call this method
    /// Can not settle more debt than there's unbacked debt and which is not expected
    /// to be settled via debt auctions (queuedDebt + debtOnAuction)
    /// @param debt Amount of debt to settle [wad]
    function settleDebtWithSurplus(uint256 debt) external override checkCaller {
        if (debt > codex.credit(address(this))) revert Aer__settleDebtWithSurplus_insufficientSurplus();
        if (debt > sub(sub(codex.unbackedDebt(address(this)), queuedDebt), debtOnAuction))
            revert Aer__settleDebtWithSurplus_insufficientDebt();
        codex.settleUnbackedDebt(debt);
        emit SettleDebtWithSurplus(debt);
    }

    /// @notice Transfer accrued credit surplus to another account
    /// @dev Can only transfer backed credit out of Aer
    /// @param credit Amount of debt to settle [wad]
    function transferCredit(address to, uint256 credit) external override checkCaller {
        if (credit > sub(codex.credit(address(this)), codex.unbackedDebt(address(this))))
            revert Aer__transferCredit_insufficientCredit();
        codex.transferCredit(address(this), to, credit);
    }

    /// ======== Shutdown ======== ///

    /// @notice Locks the contract
    /// @dev Sender has to be allowed to call this method
    /// Wipes queued debt and debt on auction, locks DebtAuction and SurplusAuction and
    /// settles debt with what it has available
    function lock() external override checkCaller {
        if (live == 0) revert Aer__lock_notLive();
        live = 0;
        queuedDebt = 0;
        debtOnAuction = 0;
        surplusAuction.lock(codex.credit(address(surplusAuction)));
        debtAuction.lock();
        codex.settleUnbackedDebt(min(codex.credit(address(this)), codex.unbackedDebt(address(this))));
        emit Lock();
    }
}