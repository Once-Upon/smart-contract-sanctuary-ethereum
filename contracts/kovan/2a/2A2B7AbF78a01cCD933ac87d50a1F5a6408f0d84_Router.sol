/**
 *Submitted for verification at Etherscan.io on 2021-09-13
*/

// SPDX-License-Identifier: NONE

pragma solidity 0.7.5;



// Part: IFactory

/// @title Aastra Vault Factory
/// @author 0xKal1
/// @notice Aastra Vault Factory deploys and manages Aastra Vaults. 
/// @dev Provides an interface to the Aastra Vault Factory
interface IFactory {

    /// @notice Emitted when new vault created by factory
    /// @param strategyManager Address of strategyManager allocated to the vault
    /// @param uniswapPool Address of uniswap pool tied to the vault
    /// @param vaultAddress Address of the newly created vault
    event VaultCreation(
        address indexed strategyManager,
        address indexed uniswapPool,
        address indexed vaultAddress
    );

    /// @notice Returns manager address of a given vault address
    /// @param _vault Address of Aastra vault
    /// @return _manager Address of vault manager
    function vaultManager(address _vault)
        external
        view
        returns (address _manager);

    /// @notice Returns vault address of a given manager address
    /// @param _manager Address of vault manager
    /// @return _vault Address of Aastra vault
    function managerVault(address _manager)
        external
        view
        returns (address _vault);

    /// @notice Creates a new Aastra vault
    /// @param _uniswapPool Address of Uniswap V3 Pool
    /// @param _strategyManager Address of strategy manager managing the vault
    /// @param _protocolFee Fee charged by strategy manager for the new vault
    /// @param _strategyFee Fee charged by protocol for the new vault
    /// @param _maxCappedLimit Max limit of TVL of the vault
    function createVault(
        address _uniswapPool,
        address _strategyManager,
        uint256 _protocolFee,
        uint256 _strategyFee,
        uint256 _maxCappedLimit
    ) external;

    /// @notice Sets a new manager for an existing vault
    /// @param _newManager Address of the new manager for the vault
    /// @param _vault Address of the Aastra vault
    function updateManager(address _newManager, address _vault) external;

    /// @notice Returns the address of Router contract
    /// @return _router Address of Router contract
    function router() external view returns (address _router);

    /// @notice Returns the address of protocol governance
    /// @return _governance Address of protocol governance
    function governance() external view returns (address _governance);


    /// @notice Returns the address of pending protocol governance
    /// @return _pendingGovernance Address of pending protocol governance
    function pendingGovernance()
        external
        view
        returns (address _pendingGovernance);

    /// @notice Allows to upgrade the router contract to a new one
    /// @param _router Address of the new router contract
    function setRouter(address _router) external;

    /// @notice Allows to set a new governance address
    /// @param _governance Address of the new protocol governance
    function setGovernance(address _governance) external;

    /// @notice Function to be called by new governance method to accept the role
    function acceptGovernance() external;
}

// Part: OpenZeppelin/[email protected]/IERC20

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

// Part: OpenZeppelin/[email protected]/ReentrancyGuard

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// Part: OpenZeppelin/[email protected]/SafeMath

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// Part: Uniswap/[email protected]/IUniswapV3PoolActions

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

// Part: Uniswap/[email protected]/IUniswapV3PoolDerivedState

/// @title Pool state that is not stored
/// @notice Contains view functions to provide information about the pool that is computed rather than stored on the
/// blockchain. The functions here may have variable gas costs.
interface IUniswapV3PoolDerivedState {
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice Returns a snapshot of the tick cumulative, seconds per liquidity and seconds inside a tick range
    /// @dev Snapshots must only be compared to other snapshots, taken over a period for which a position existed.
    /// I.e., snapshots cannot be compared if a position is not held for the entire period between when the first
    /// snapshot is taken and the second snapshot is taken.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @return tickCumulativeInside The snapshot of the tick accumulator for the range
    /// @return secondsPerLiquidityInsideX128 The snapshot of seconds per liquidity for the range
    /// @return secondsInside The snapshot of seconds per liquidity for the range
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}

// Part: Uniswap/[email protected]/IUniswapV3PoolEvents

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface IUniswapV3PoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @dev Collect events may be emitted with zero amount0 and amount1 when the caller chooses not to collect fees
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pool
    /// @param feeProtocol0Old The previous value of the token0 protocol fee
    /// @param feeProtocol1Old The previous value of the token1 protocol fee
    /// @param feeProtocol0New The updated value of the token0 protocol fee
    /// @param feeProtocol1New The updated value of the token1 protocol fee
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender The address that collects the protocol fees
    /// @param recipient The address that receives the collected protocol fees
    /// @param amount0 The amount of token0 protocol fees that is withdrawn
    /// @param amount0 The amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}

// Part: Uniswap/[email protected]/IUniswapV3PoolImmutables

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

// Part: Uniswap/[email protected]/IUniswapV3PoolOwnerActions

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
interface IUniswapV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// @param feeProtocol0 new protocol fee for token0 of the pool
    /// @param feeProtocol1 new protocol fee for token1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    /// @return amount0 The protocol fee collected in token0
    /// @return amount1 The protocol fee collected in token1
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}

// Part: Uniswap/[email protected]/IUniswapV3PoolState

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

// Part: IERC20Metadata

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// Part: IRouter

/// @title Aastra Router
/// @author 0xKal1
/// @notice Aastra Router provides simple interface for SM to interact with vault
interface IRouter {

    /// @notice Emitted on successfull rebalance of base liquidity of vault
    /// @param vault Address of aastra vault
    /// @param baseLower Lower tick of new rebalanced liquidity
    /// @param baseUpper Upper tick of new rebalanced liquidity
    /// @param percentage Percentage of funds to be used for rebalance
    event RebalanceBaseLiqudity(
        address indexed vault,
        int24 baseLower,
        int24 baseUpper,
        uint8 percentage
    );

    /// @notice Emitted on successfull rebalance of base liquidity of vault
    /// @param vault Address of aastra vault
    /// @param limitLower Lower tick of new rebalanced liquidity
    /// @param limitUpper Upper tick of new rebalanced liquidity
    /// @param percentage Percentage of funds to be used for rebalance
    event RebalanceLimitLiqudity(
        address indexed vault,
        int24 limitLower,
        int24 limitUpper,
        uint8 percentage
    );
    
    /// @notice returns address of Aastra factory contract
    /// @return IFactory Address of aastra factory contract
    function factory() external returns (IFactory);

    /// @notice Retrieve amounts present in base position
    /// @param vault Address of the vault
    /// @return liquidity Liquidity amount of the position
    /// @return amount0 Amount of token0 present in the position after last poke
    /// @return amount1 Amount of token1 present in the position after last poke
    function getBaseAmounts(address vault)
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Retrieve amounts present in limit position
    /// @param vault Address of the vault
    /// @return liquidity Liquidity amount of the position
    /// @return amount0 Amount of token0 present in the position after last poke
    /// @return amount1 Amount of token1 present in the position after last poke
    function getLimitAmounts(address vault)
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Used to create a new base liquidity position on uniswap. This will burn and remove any existing position held by the vault 
    /// @param _baseLower The lower limit of the liquidity position
    /// @param _baseUpper The upper limit of the liquidity position
    /// @param _percentage The percentage of funds of the vault to be used for liquidity position
    /// @param swapEnabled Enable/disable the automatic swapping for optimal liqudity minting
    function newBaseLiquidity(
        int24 _baseLower,
        int24 _baseUpper,
        uint8 _percentage,
        bool swapEnabled
    ) external;

    /// @notice Used to create a new limit liquidity position on uniswap. This will burn and remove any existing position held by the vault 
    /// @param _limitLower The lower limit of the liquidity position
    /// @param _limitUpper The upper limit of the liquidity position
    /// @param _percentage The percentage of funds of the vault to be used for liquidity position
    function newLimitLiquidity(
        int24 _limitLower,
        int24 _limitUpper,
        uint8 _percentage, 
        bool swapEnabled
    ) external;

    /// @notice Used to collect and compound fee for a specific vault
    /// @param _vault Address of the vault
    function compoundFee(address _vault) external;

    /// @notice Retrieve lower and upper ticks of vault\'s base position
    /// @param vault Address of the vault
    /// @return lowerTick Lower limit of the vault\'s base position
    /// @return upperTick Upper limit of the vault\'s base position
    function getBaseTicks(address vault)
        external
        returns (int24 lowerTick, int24 upperTick);

    /// @notice Retrieve lower and upper ticks of vault\'s limit position
    /// @param vault Address of the vault
    /// @return lowerTick Lower limit of the vault\'s limit position
    /// @return upperTick Upper limit of the vault\'s limit position
    function getLimitTicks(address vault)
        external
        returns (int24 lowerTick, int24 upperTick);
}

// Part: Uniswap/[email protected]/IUniswapV3Pool

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is
    IUniswapV3PoolImmutables,
    IUniswapV3PoolState,
    IUniswapV3PoolDerivedState,
    IUniswapV3PoolActions,
    IUniswapV3PoolOwnerActions,
    IUniswapV3PoolEvents
{

}

// Part: IVault

/// @title Aastra Vault
/// @author 0xKal1
/// @notice Aastra Vault is a Uniswap V3 liquidity management vault enabling you to automate yield generation on your idle funds
/// @dev Provides an interface to the Aastra Vault
interface IVault is IERC20 {

    /// @notice Emitted when a deposit made to a vault
    /// @param sender The sender of the deposit transaction
    /// @param to The recipient of LP tokens
    /// @param shares Amount of LP tokens paid to recipient
    /// @param amount0 Amount of token0 deposited
    /// @param amount1 Amount of token1 deposited
    event Deposit(
        address indexed sender,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when a withdraw made to a vault
    /// @param sender The sender of the withdraw transaction
    /// @param to The recipient of withdrawn amounts
    /// @param shares Amount of LP tokens paid back to vault
    /// @param amount0 Amount of token0 withdrawn
    /// @param amount1 Amount of token1 withdrawn
    event Withdraw(
        address indexed sender,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees collected from uniswap
    /// @param feesToVault0 Amount of token0 earned as fee by protocol
    /// @param feesToVault1 Amount of token1 earned as fee by protocol
    /// @param feesToStrategy0 Amount of token0 earned as fee by strategy manager
    /// @param feesToStrategy1 Amount of token1 earned as fee by strategy manager
    event CollectFees(
        uint256 feesToVault0,
        uint256 feesToVault1,
        uint256 feesToStrategy0,
        uint256 feesToStrategy1
    );

    /// @notice Retrieve first token of Uniswap V3 pool
    /// @return IERC20Metadata token address
    function token0() external view returns (IERC20Metadata);

    /// @notice Retrieve second token of Uniswap V3 pool
    /// @return IERC20Metadata token address
    function token1() external view returns (IERC20Metadata);

    /// @notice Retrieve usable amount of token0 available in the vault
    /// @return amount0 Amount of token0
    function getBalance0() external view returns (uint256);

    /// @notice Retrieve usable amount of token1 available in the vault
    /// @return amount1 Amount of token0
    function getBalance1() external view returns (uint256);

    /// @notice Retrieve tickSpacing of Pool used in the vault
    /// @return tickSpacing tickSpacing of the Uniswap V3 pool
    function tickSpacing() external view returns (int24);

    /// @notice Retrieve lower tick of base position of Pool used in the vault
    /// @return baseLower of the Uniswap V3 pool
    function baseLower() external view returns (int24);

    /// @notice Retrieve upper tick of base position of Pool used in the vault
    /// @return baseUpper of the Uniswap V3 pool
    function baseUpper() external view returns (int24);

    /// @notice Retrieve lower tick of limit position of Pool used in the vault
    /// @return limitLower of the Uniswap V3 pool
    function limitLower() external view returns (int24);

    /// @notice Retrieve upper tick of limit position of Pool used in the vault
    /// @return limitUpper of the Uniswap V3 pool
    function limitUpper() external view returns (int24);

    /// @notice Retrieve address of Uni V3 Pool used in the vault
    /// @return IUniswapV3Pool address of Uniswap V3 Pool
    function pool() external view returns (IUniswapV3Pool);

    /// @notice Retrieve address of Factory used to create the vault
    /// @return IFactory address of Aastra factory contract
    function factory() external view returns (IFactory);

    /// @notice Retrieve address of current router in Aastra
    /// @return router address of Aastra router contract
    function router() external view returns (address);

    /// @notice Retrieve address of strategy manager used to manage the vault
    /// @return manager address of vault manager
    function strategy() external view returns (address);

    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     * @return total0 Total token0 holdings of the vault
     * @return total1 Total token1 holdings of the vault
     */
    function getTotalAmounts() external view returns (uint256, uint256);

    /// @dev Wrapper around `IUniswapV3Pool.positions()`.
    /// @notice Provides the current data on a position in the vault according to lower and upper tick
    /// @param tickLower Lower tick of the vault's position
    /// @param tickUpper Upper tick of the vault's position
    function position(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        );

    /**
     * @notice Amounts of token0 and token1 held in vault's position. Includes owed fees but excludes the proportion of fees that will be paid to the protocol. Doesn't include fees accrued since last poke.
     * @param tickLower Lower tick of the vault's position
     * @param tickUpper Upper tick of the vault's position
     * @return amount0 Amount of token0 held in the vault's position
     * @return amount1 Amount of token1 held in the vault's position
     */
    function getPositionAmounts(int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    /// ------------- Router Functions ------------- ///

    /// @notice Updates due amount in uniswap owed for a tick range
    /// @dev Do zero-burns to poke a position on Uniswap so earned fees are updated. Should be called if total amounts needs to include up-to-date fees.
    /// @param tickLower Lower bound of the tick range
    /// @param tickUpper Upper bound of the tick range
    function poke(int24 tickLower, int24 tickUpper) external;

    /// @notice Used to update the new base position ticks of the vault
    /// @param _baseLower The new lower tick of the vault
    /// @param _baseUpper The new upper tick of the vault
    function setBaseTicks(int24 _baseLower, int24 _baseUpper) external;

    /// @notice Used to update the new limit position ticks of the vault
    /// @param _limitLower The new lower tick of the vault
    /// @param _limitUpper The new upper tick of the vault
    function setLimitTicks(int24 _limitLower, int24 _limitUpper) external;

    /// @notice Withdraws all liquidity from a range and collects all the fees in the process
    /// @param tickLower Lower bound of the tick range
    /// @param tickUpper Upper bound of the tick range
    /// @param liquidity Liquidity to be withdrawn from the range
    /// @return burned0 Amount of token0 that was burned
    /// @return burned1 Amount of token1 that was burned
    /// @return feesToVault0 Amount of token0 fees vault earned
    /// @return feesToVault1 Amount of token1 fees vault earned
    function burnAndCollect(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        external
        returns (
            uint256 burned0,
            uint256 burned1,
            uint256 feesToVault0,
            uint256 feesToVault1
        );

    /// @notice This method will optimally use all the funds provided in argument to mint the maximum possible liquidity
    /// @param _lowerTick Lower bound of the tick range
    /// @param _upperTick Upper bound of the tick range
    /// @param amount0 Amount of token0 to be used for minting liquidity
    /// @param amount1 Amount of token1 to be used for minting liquidity
    function mintOptimalLiquidity(
        int24 _lowerTick,
        int24 _upperTick,
        uint256 amount0,
        uint256 amount1,
        bool swapEnabled
    ) external;

    /// @notice Swaps tokens from the pool
    /// @param direction The direction of the swap, true for token0 to token1, false for reverse
    /// @param amountInToSwap Desired amount of token0 or token1 wished to swap
    /// @return amountOut Amount of token0 or token1 received from the swap
    function swapTokensFromPool(bool direction, uint256 amountInToSwap)
        external
        returns (uint256 amountOut);

    /// @notice Collects liquidity fee earned from both positions of vault and reinvests them back into the same position
    function compoundFee() external;

    /// @notice Used to collect accumulated strategy fees.
    /// @param amount0 Amount of token0 to collect
    /// @param amount1 Amount of token1 to collect
    /// @param to Address to send collected fees to
    function collectStrategy(
        uint256 amount0,
        uint256 amount1,
        address to
    ) external;

    /// ------------- GOV Functions ------------- ///

    /**
     * @notice Emergency method to freeze actions performed by a strategy
     * @param value To be set to true in case of active freeze
     */
    function freezeStrategy(bool value) external;

    /**
     * @notice Emergency method to freeze actions performed by a vault user
     * @param value To be set to true in case of active freeze
     */
    function freezeUser(bool value) external;


    /// @notice Used to collect accumulated protocol fees.
    /// @param amount0 Amount of token0 to collect
    /// @param amount1 Amount of token1 to collect
    /// @param to Address to send collected fees to
    function collectProtocol(
        uint256 amount0,
        uint256 amount1,
        address to
    ) external;

    /**
     * @notice Used to change deposit cap for a guarded launch or to ensure
     * vault doesn't grow too large relative to the pool. Cap is on total
     * supply rather than amounts of token0 and token1 as those amounts
     * fluctuate naturally over time.
     * @param _maxTotalSupply The new max total cap of the vault
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply) external;

    /**
     * @notice Removes liquidity in case of emergency.
     * @param to Address to withdraw funds to
     */
    function emergencyBurnAndCollect(address to) external;

    /// ------------- User Functions ------------- ///

    /**
     * @notice Deposits tokens in proportion to the vault's current holdings.
     * @param amount0Desired Max amount of token0 to deposit
     * @param amount1Desired Max amount of token1 to deposit
     * @param amount0Min Revert if resulting `amount0` is less than this
     * @param amount1Min Revert if resulting `amount1` is less than this
     * @param to Recipient of shares
     * @return shares Number of shares minted
     * @return amount0 Amount of token0 deposited
     * @return amount1 Amount of token1 deposited
     */
    function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    )
        external
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        );

    /**
     * @notice Withdraws tokens in proportion to the vault's holdings.
     * @param shares Shares burned by sender
     * @param amount0Min Revert if resulting `amount0` is smaller than this
     * @param amount1Min Revert if resulting `amount1` is smaller than this
     * @param to Recipient of tokens
     * @return amount0 Amount of token0 sent to recipient
     * @return amount1 Amount of token1 sent to recipient
     */
    function withdraw(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external returns (uint256 amount0, uint256 amount1);
}

// File: Router.sol

contract Router is IRouter, ReentrancyGuard {
    using SafeMath for uint256;

    IFactory public override factory;

    constructor(address _factory) {
        factory = IFactory(_factory);
    }

    /// @inheritdoc IRouter
    function newBaseLiquidity(
        int24 _baseLower,
        int24 _baseUpper,
        uint8 _percentage,
        bool swapEnabled
    ) external override nonReentrant {
        IVault vault = _getVault(msg.sender);
        newLiquidity(
            vault,
            _baseLower,
            _baseUpper,
            vault.baseLower(),
            vault.baseUpper(),
            _percentage,
            swapEnabled
        );
        vault.setBaseTicks(_baseLower, _baseUpper);

        emit RebalanceBaseLiqudity(address(vault), _baseLower, _baseUpper, _percentage);
    }

    /// @inheritdoc IRouter
    function newLimitLiquidity(
        int24 _limitLower,
        int24 _limitUpper,
        uint8 _percentage,
        bool swapEnabled
    ) external override nonReentrant {
        IVault vault = _getVault(msg.sender);
        newLiquidity(
            vault,
            _limitLower,
            _limitUpper,
            vault.limitLower(),
            vault.limitUpper(),
            _percentage,
            swapEnabled
        );
        vault.setLimitTicks(_limitLower, _limitUpper);

        emit RebalanceLimitLiqudity(address(vault), _limitLower, _limitUpper, _percentage);
    }

    function newLiquidity(
        IVault vault,
        int24 tickLower,
        int24 tickUpper,
        int24 oldTickLower,
        int24 oldTickUpper,
        uint8 percentage,
        bool swapEnabled
    ) internal {
        require(percentage <= 100, "percentage");
        vault.poke(oldTickLower, oldTickUpper);
        (uint128 oldLiquidity, , , , ) = vault.position(
            oldTickLower,
            oldTickUpper
        );
        if (oldLiquidity > 0) {
            vault.burnAndCollect(oldTickLower, oldTickUpper, oldLiquidity);
        }
        if (percentage > 0) {
            uint256 balance0 = vault.getBalance0();
            uint256 balance1 = vault.getBalance1();

            vault.mintOptimalLiquidity(
                tickLower,
                tickUpper,
                balance0.mul(percentage).div(100),
                balance1.mul(percentage).div(100),
                swapEnabled
            );
        }
    }

    /// @inheritdoc IRouter
    function getBaseAmounts(address _vault)
        public
        view
        override
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        IVault vault = IVault(_vault);
        (liquidity, , , , ) = vault.position(
            vault.baseLower(),
            vault.baseUpper()
        );

        (amount0, amount1) = vault.getPositionAmounts(
            vault.baseLower(),
            vault.baseUpper()
        );
    }

    /// @inheritdoc IRouter
    function getLimitAmounts(address _vault)
        public
        view
        override
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        IVault vault = IVault(_vault);
        (liquidity, , , , ) = vault.position(
            vault.limitLower(),
            vault.limitUpper()
        );

        (amount0, amount1) = vault.getPositionAmounts(
            vault.limitLower(),
            vault.limitUpper()
        );
    }

    /// @inheritdoc IRouter
    function getBaseTicks(address _vault)
        external
        view
        override
        returns (int24, int24)
    {
        IVault vault = IVault(_vault);
        return (vault.baseLower(), vault.baseUpper());
    }

    /// @inheritdoc IRouter
    function getLimitTicks(address _vault)
        external
        view
        override
        returns (int24, int24)
    {
        IVault vault = IVault(_vault);
        return (vault.limitLower(), vault.limitUpper());
    }

    /// @inheritdoc IRouter
    function compoundFee(address _vault) public override {
        IVault vault = IVault(_vault);
        vault.compoundFee();
    }

    // modifier onlyStrategy(address _manager) {
    //     require(
    //         factory.managerVault(_manager) != address(0),
    //         "Router : onlyStrategy :: tx sender needs to be a valid strategy manager"
    //     );
    //     _;
    // }

    /// @dev Retrieves the vault for msg.sender by fetching from factory
    function _getVault(address _manager) internal view returns (IVault vault) {
        address _vault = factory.managerVault(_manager);

        // This should never fail, but just in case
        require(
            _vault != address(0),
            "Router : _getVault :: PANIC! SM has no valid vault"
        );
        return IVault(_vault);
    }
}