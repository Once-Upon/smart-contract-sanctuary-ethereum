// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

// Common interface for the Trove Manager.
interface IBorrowerOperations {
    enum BorrowerOperation {
        openTrove,
        closeTrove,
        adjustTrove
    }

    // --- Functions ---

    function setAddresses(
        address _troveManagerAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _governanceAddress,
        address _sortedTrovesAddress,
        address _arthTokenAddress
    ) external;

    function registerFrontEnd() external;

    function openTrove(
        uint256 _maxFee,
        uint256 _ARTHAmount,
        address _upperHint,
        address _lowerHint,
        address _frontEndTag
    ) external payable;

    function addColl(address _upperHint, address _lowerHint) external payable;

    function moveETHGainToTrove(
        address _user,
        address _upperHint,
        address _lowerHint
    ) external payable;

    function withdrawColl(
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawARTH(
        uint256 _maxFee,
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    function repayARTH(
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    function closeTrove() external;

    function adjustTrove(
        uint256 _maxFee,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable;

    function claimCollateral() external;

    function getCompositeDebt(uint256 _debt) external pure returns (uint256);

    function activePool() external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

library DataTypes {
    struct EModeCategory {
        // each eMode category has a custom ltv and liquidation threshold
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        // each eMode category may or may not have a custom oracle to override the individual assets price oracles
        address priceSource;
        string label;
    }

    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //aToken address
        address aTokenAddress;
        //stableDebtToken address
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        //the outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    struct UserConfigurationMap {
        /**
         * @dev Bitmap of the users collaterals and borrows. It is divided in pairs of bits, one pair per asset.
         * The first bit indicates if an asset is used as collateral by the user, the second whether an
         * asset is borrowed by the user.
         */
        uint256 data;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60: asset is paused
        //bit 61: borrowing in isolation mode is enabled
        //bit 62-63: reserved
        //bit 64-79: reserve factor
        //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
        //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
        //bit 152-167 liquidation protocol fee
        //bit 168-175 eMode category
        //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
        //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
        //bit 252-255 unused

        uint256 data;
    }
}

/**
 * @title ILendingPool
 * @author Aave
 * @notice Defines the basic interface for an Aave Pool.
 **/
interface ILendingPool {
    /**
     * @dev Emitted on mintUnbacked()
     * @param reserve The address of the underlying asset of the reserve
     * @param user The address initiating the supply
     * @param onBehalfOf The beneficiary of the supplied assets, receiving the aTokens
     * @param amount The amount of supplied assets
     * @param referralCode The referral code used
     */
    event MintUnbacked(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        uint16 indexed referralCode
    );

    /**
     * @dev Emitted on backUnbacked()
     * @param reserve The address of the underlying asset of the reserve
     * @param backer The address paying for the backing
     * @param amount The amount added as backing
     * @param fee The amount paid in fees
     */
    event BackUnbacked(address indexed reserve, address indexed backer, uint256 amount, uint256 fee);

    /**
     * @dev Emitted on supply()
     * @param reserve The address of the underlying asset of the reserve
     * @param user The address initiating the supply
     * @param onBehalfOf The beneficiary of the supply, receiving the aTokens
     * @param amount The amount supplied
     * @param referralCode The referral code used
     */
    event Supply(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        uint16 indexed referralCode
    );

    /**
     * @dev Emitted on withdraw()
     * @param reserve The address of the underlying asset being withdrawn
     * @param user The address initiating the withdrawal, owner of aTokens
     * @param to The address that will receive the underlying
     * @param amount The amount to be withdrawn
     */
    event Withdraw(
        address indexed reserve,
        address indexed user,
        address indexed to,
        uint256 amount
    );

    /**
     * @dev Emitted on repay()
     * @param reserve The address of the underlying asset of the reserve
     * @param user The beneficiary of the repayment, getting his debt reduced
     * @param repayer The address of the user initiating the repay(), providing the funds
     * @param amount The amount repaid
     * @param useATokens True if the repayment is done using aTokens, `false` if done with underlying asset directly
     */
    event Repay(
        address indexed reserve,
        address indexed user,
        address indexed repayer,
        uint256 amount,
        bool useATokens
    );

    /**
     * @notice Mints an `amount` of aTokens to the `onBehalfOf`
     * @param asset The address of the underlying asset to mint
     * @param amount The amount to mint
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     */
    function mintUnbacked(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Back the current unbacked underlying with `amount` and pay `fee`.
     * @param asset The address of the underlying asset to back
     * @param amount The amount to back
     * @param fee The amount paid in fees
     * @return The backed amount
     */
    function backUnbacked(
        address asset,
        uint256 amount,
        uint256 fee
    ) external returns (uint256);

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Supply with transfer approval of asset to be supplied done via permit function
     * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param deadline The deadline timestamp that the permit is valid
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     * @param permitV The V parameter of ERC712 permit sig
     * @param permitR The R parameter of ERC712 permit sig
     * @param permitS The S parameter of ERC712 permit sig
     */
    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to The address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @notice Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
     * already supplied enough collateral, or he was given enough allowance by a credit delegator on the
     * corresponding debt token (StableDebtToken or VariableDebtToken)
     * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
     *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
     * @param asset The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
     * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     * @param onBehalfOf The address of the user who will receive the debt. Should be the address of the borrower itself
     * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
     * if he has been given credit delegation allowance
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
     * @param asset The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
     * @param onBehalfOf The address of the user who will get his debt reduced/removed. Should be the address of the
     * user calling the function if he wants to reduce/remove his own debt, or the address of any other
     * other borrower whose debt should be removed
     * @return The final amount repaid
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    /**
     * @notice Repay with transfer approval of asset to be repaid done via permit function
     * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
     * @param asset The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
     * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
     * user calling the function if he wants to reduce/remove his own debt, or the address of any other
     * other borrower whose debt should be removed
     * @param deadline The deadline timestamp that the permit is valid
     * @param permitV The V parameter of ERC712 permit sig
     * @param permitR The R parameter of ERC712 permit sig
     * @param permitS The S parameter of ERC712 permit sig
     * @return The final amount repaid
     */
    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external returns (uint256);

    /**
     * @notice Repays a borrowed `amount` on a specific reserve using the reserve aTokens, burning the
     * equivalent debt tokens
     * - E.g. User repays 100 USDC using 100 aUSDC, burning 100 variable/stable debt tokens
     * @dev  Passing uint256.max as amount will clean up any residual aToken dust balance, if the user aToken
     * balance is not enough to cover the whole debt
     * @param asset The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
     * @return The final amount repaid
     */
    function repayWithATokens(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external returns (uint256);

    /**
     * @notice Allows a borrower to swap his debt between stable and variable mode, or vice versa
     * @param asset The address of the underlying asset borrowed
     * @param interestRateMode The current interest rate mode of the position being swapped: 1 for Stable, 2 for Variable
     */
    function swapBorrowRateMode(address asset, uint256 interestRateMode) external;

    /**
     * @notice Rebalances the stable interest rate of a user to the current stable rate defined on the reserve.
     * - Users can be rebalanced if the following conditions are satisfied:
     *     1. Usage ratio is above 95%
     *     2. the current supply APY is below REBALANCE_UP_THRESHOLD * maxVariableBorrowRate, which means that too
     *        much has been borrowed at a stable rate and suppliers are not earning enough
     * @param asset The address of the underlying asset borrowed
     * @param user The address of the user to be rebalanced
     */
    function rebalanceStableBorrowRate(address asset, address user) external;

    /**
     * @notice Allows suppliers to enable/disable a specific supplied asset as collateral
     * @param asset The address of the underlying asset supplied
     * @param useAsCollateral True if the user wants to use the supply as collateral, false otherwise
     */
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    /**
     * @notice Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
     *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken True if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     */
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
     * as long as the amount taken plus a fee is returned.
     * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
     * into consideration. For further details please visit https://developers.aave.com
     * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanReceiver interface
     * @param assets The addresses of the assets being flash-borrowed
     * @param amounts The amounts of the assets being flash-borrowed
     * @param interestRateModes Types of the debt to open if the flash loan is not returned:
     *   0 -> Don't open any debt, just revert if funds can't be transferred from the receiver
     *   1 -> Open debt at stable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
     *   2 -> Open debt at variable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
     * @param onBehalfOf The address  that will receive the debt in the case of using on `modes` 1 or 2
     * @param params Variadic packed params to pass to the receiver as extra information
     * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
     * as long as the amount taken plus a fee is returned.
     * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
     * into consideration. For further details please visit https://developers.aave.com
     * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanSimpleReceiver interface
     * @param asset The address of the asset being flash-borrowed
     * @param amount The amount of the asset being flash-borrowed
     * @param params Variadic packed params to pass to the receiver as extra information
     * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     */
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
     * @return totalDebtBase The total debt of the user in the base currency used by the price feed
     * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
     * @return currentLiquidationThreshold The liquidation threshold of the user
     * @return ltv The loan to value of The user
     * @return healthFactor The current health factor of the user
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    /**
     * @notice Initializes a reserve, activating it, assigning an aToken and debt tokens and an
     * interest rate strategy
     * @dev Only callable by the PoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     * @param aTokenAddress The address of the aToken that will be assigned to the reserve
     * @param stableDebtAddress The address of the StableDebtToken that will be assigned to the reserve
     * @param variableDebtAddress The address of the VariableDebtToken that will be assigned to the reserve
     * @param interestRateStrategyAddress The address of the interest rate strategy contract
     */
    function initReserve(
        address asset,
        address aTokenAddress,
        address stableDebtAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external;

    /**
     * @notice Drop a reserve
     * @dev Only callable by the PoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     */
    function dropReserve(address asset) external;

    /**
     * @notice Updates the address of the interest rate strategy contract
     * @dev Only callable by the PoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     * @param rateStrategyAddress The address of the interest rate strategy contract
     */
    function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress)
        external;

    /**
     * @notice Sets the configuration bitmap of the reserve as a whole
     * @dev Only callable by the PoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     * @param configuration The new configuration bitmap
     */
    function setConfiguration(
        address asset,
        DataTypes.ReserveConfigurationMap calldata configuration
    ) external;

    /**
     * @notice Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     */
    function getConfiguration(address asset)
        external
        view
        returns (DataTypes.ReserveConfigurationMap memory);

    /**
     * @notice Returns the configuration of the user across all the reserves
     * @param user The user address
     * @return The configuration of the user
     */
    function getUserConfiguration(address user)
        external
        view
        returns (DataTypes.UserConfigurationMap memory);

    /**
     * @notice Returns the normalized income of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve's normalized income
     */
    function getReserveNormalizedIncome(address asset) external view returns (uint256);

    /**
     * @notice Returns the normalized variable debt per unit of asset
     * @dev WARNING: This function is intended to be used primarily by the protocol itself to get a
     * "dynamic" variable index based on time, current stored index and virtual rate at the current
     * moment (approx. a borrower would get if opening a position). This means that is always used in
     * combination with variable debt supply/balances.
     * If using this function externally, consider that is possible to have an increasing normalized
     * variable debt that is not equivalent to how the variable debt index would be updated in storage
     * (e.g. only updates with non-zero variable debt supply)
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve normalized variable debt
     */
    function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

    /**
     * @notice Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state and configuration data of the reserve
     */
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

    /**
     * @notice Validates and finalizes an aToken transfer
     * @dev Only callable by the overlying aToken of the `asset`
     * @param asset The address of the underlying asset of the aToken
     * @param from The user from which the aTokens are transferred
     * @param to The user receiving the aTokens
     * @param amount The amount being transferred/withdrawn
     * @param balanceFromBefore The aToken balance of the `from` user before the transfer
     * @param balanceToBefore The aToken balance of the `to` user before the transfer
     */
    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external;

    /**
     * @notice Returns the list of the underlying assets of all the initialized reserves
     * @dev It does not include dropped reserves
     * @return The addresses of the underlying assets of the initialized reserves
     */
    function getReservesList() external view returns (address[] memory);

    /**
     * @notice Returns the address of the underlying asset of a reserve by the reserve id as stored in the DataTypes.ReserveData struct
     * @param id The id of the reserve as stored in the DataTypes.ReserveData struct
     * @return The address of the reserve associated with id
     */
    function getReserveAddressById(uint16 id) external view returns (address);

    /**
     * @notice Updates the protocol fee on the bridging
     * @param bridgeProtocolFee The part of the premium sent to the protocol treasury
     */
    function updateBridgeProtocolFee(uint256 bridgeProtocolFee) external;

    /**
     * @notice Updates flash loan premiums. Flash loan premium consists of two parts:
     * - A part is sent to aToken holders as extra, one time accumulated interest
     * - A part is collected by the protocol treasury
     * @dev The total premium is calculated on the total borrowed amount
     * @dev The premium to protocol is calculated on the total premium, being a percentage of `flashLoanPremiumTotal`
     * @dev Only callable by the PoolConfigurator contract
     * @param flashLoanPremiumTotal The total premium, expressed in bps
     * @param flashLoanPremiumToProtocol The part of the premium sent to the protocol treasury, expressed in bps
     */
    function updateFlashloanPremiums(
        uint128 flashLoanPremiumTotal,
        uint128 flashLoanPremiumToProtocol
    ) external;

    /**
     * @notice Configures a new category for the eMode.
     * @dev In eMode, the protocol allows very high borrowing power to borrow assets of the same category.
     * The category 0 is reserved as it's the default for volatile assets
     * @param id The id of the category
     * @param config The configuration of the category
     */
    function configureEModeCategory(uint8 id, DataTypes.EModeCategory memory config) external;

    /**
     * @notice Returns the data of an eMode category
     * @param id The id of the category
     * @return The configuration data of the category
     */
    function getEModeCategoryData(uint8 id) external view returns (DataTypes.EModeCategory memory);

    /**
     * @notice Allows a user to use the protocol in eMode
     * @param categoryId The id of the category
     */
    function setUserEMode(uint8 categoryId) external;

    /**
     * @notice Returns the eMode the user is using
     * @param user The address of the user
     * @return The eMode id
     */
    function getUserEMode(address user) external view returns (uint256);

    /**
     * @notice Resets the isolation mode total debt of the given asset to zero
     * @dev It requires the given asset has zero debt ceiling
     * @param asset The address of the underlying asset to reset the isolationModeTotalDebt
     */
    function resetIsolationModeTotalDebt(address asset) external;

    /**
     * @notice Returns the percentage of available liquidity that can be borrowed at once at stable rate
     * @return The percentage of available liquidity to borrow, expressed in bps
     */
    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external view returns (uint256);

    /**
     * @notice Returns the total fee on flash loans
     * @return The total fee on flashloans
     */
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

    /**
     * @notice Returns the part of the bridge fees sent to protocol
     * @return The bridge fee sent to the protocol treasury
     */
    function BRIDGE_PROTOCOL_FEE() external view returns (uint256);

    /**
     * @notice Returns the part of the flashloan fees sent to protocol
     * @return The flashloan fee sent to the protocol treasury
     */
    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);

    /**
     * @notice Returns the maximum number of reserves supported to be listed in this Pool
     * @return The maximum number of reserves supported
     */
    function MAX_NUMBER_RESERVES() external view returns (uint16);

    /**
     * @notice Mints the assets accrued through the reserve factor to the treasury in the form of aTokens
     * @param assets The list of reserves for which the minting needs to be executed
     */
    function mintToTreasury(address[] calldata assets) external;

    /**
     * @notice Rescue and transfer tokens locked in this contract
     * @param token The address of the token
     * @param to The address of the recipient
     * @param amount The amount of token to transfer
     */
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external;

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
     * @dev Deprecated: Use the `supply` function instead
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     */
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceFeed {
    // --- Function ---
    function fetchPrice() external returns (uint256);

    function lastGoodPrice() external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

/**
 * @title VersionedInitializable
 * @author Aave, inspired by the OpenZeppelin Initializable contract
 * @notice Helper contract to implement initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * @dev WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
abstract contract VersionedInitializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to use in the initializer function of a contract.
     */
    modifier initializer() {
        uint256 revision = getRevision();

        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(canInitialize(), "Initializable: contract is already initialized");
        _setStoredVersion(revision);

        bool isTopLevelCall = !_initializing;

        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @notice Returns the revision number of the contract
     * @dev Needs to be defined in the inherited class as a constant.
     * @return The revision number
     **/
    function getRevision() public pure virtual returns (uint256);

    /**
     * @notice Returns true if and only if the function is running in the constructor
     * @return True if the function is running in the constructor
     **/
    function isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        uint256 cs;
        //solium-disable-next-line
        assembly {
            cs := extcodesize(address())
        }
        return cs == 0;
    }

    function canInitialize() public view returns (bool) {
        uint256 revision = getRevision();
        return !_initialized || isConstructor() || revision > _getStoredVersion();
    }

    function _getStoredVersion() internal view returns (uint256) {
        // keccak-256(eip1967.proxy.version)
        // = 0x460994c355dbc8229336897ed9def5884fb6b26b0a995b156780d056c758577e
        // bytes32 _slot = 0x460994c355dbc8229336897ed9def5884fb6b26b0a995b156780d056c758577d;
        return
            StorageSlot
                .getUint256Slot(0x460994c355dbc8229336897ed9def5884fb6b26b0a995b156780d056c758577d)
                .value;
    }

    function _setStoredVersion(uint256 val) internal {
        // keccak-256(eip1967.proxy.version) - 1
        // bytes32 _slot = 0x460994c355dbc8229336897ed9def5884fb6b26b0a995b156780d056c758577d;
        StorageSlot
            .getUint256Slot(0x460994c355dbc8229336897ed9def5884fb6b26b0a995b156780d056c758577d)
            .value = val;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Operator} from "../utils/Operator.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title StakingRewardsChild
 * @author MahaDAO
 *
 * @notice A staking contract that properly attributes rewards to a user based on how much
 * they've staked. This contract is based out of Set Protocol's staking contract.
 **/
abstract contract StakingRewardsChild is Operator, ReentrancyGuard {
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public rewardsDuration;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function _stakingRewardsChildInit(
        address _rewardsToken,
        uint256 _rewardsDuration,
        address _operator
    ) internal {
        rewardsToken = IERC20(_rewardsToken);
        rewardsDuration = _rewardsDuration;
        _transferOperator(_operator);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(
                    _totalSupply
                )
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            _balances[account]
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _stake(address who, uint256 amount) internal updateReward(who) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[who] = _balances[who].add(amount);
        emit Staked(who, amount);
    }

    function _withdraw(address who, uint256 amount) internal updateReward(who) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[who] = _balances[who].sub(amount);
        emit Withdrawn(who, amount);
    }

    function _getReward() internal updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function getReward() external nonReentrant {
        _getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward) external onlyOperator updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VersionedInitializable} from "../../proxy/VersionedInitializable.sol";
import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {StakingRewardsChild} from "../../staking/StakingRewardsChild.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";

// import "hardhat/console.sol";

/**
 * @title ETHTroveStrategy
 * @author MahaDAO
 *
 * @notice A ETH staking contract that takes in ETH and uses it to mint ARTH and provide liquidity to MahaLend.
 * This strategy is a low risk strategy albeit some risks such as ETH price fluctuation and smart-contract bugs.
 * Most liquidity providers who participate in this strategy will be able to withdraw the
 * same amount of ETH that they provided.
 **/
contract ETHTroveStrategyW is VersionedInitializable, StakingRewardsChild {
    event PauseToggled(bool val);
    event Withdrawal(address indexed dst, uint256 wad, uint256 arthWad);
    event RevenueClaimed(uint256 wad);

    struct Position {
        bool isActive;
        uint256 ethForLoan; // ETH deposited
        uint256 arthFromLoan; // ARTH minted
        uint256 arthInLendingPool; // mARTH contributed
    }

    uint256 public minCollateralRatio;
    address private me;
    address private _arth;
    mapping(address => Position) public positions;

    IERC20 public arth;

    /// @dev the MahaLend lending pool
    ILendingPool public pool;

    /// @dev the ARTH price feed
    IPriceFeed public priceFeed;

    /// @dev Borrower operations for minting ARTH
    IBorrowerOperations public borrowerOperations;

    /// @dev the MahaLend aToken for ARTH.
    IERC20 public mArth;

    /// @dev for collection of revenue
    address public treasury;

    /// @dev to track how much interest this pool has earned.
    uint256 public totalmArthSupplied;

    /// @dev is the contract paused?
    bool public paused;

    function initialize(
        address _borrowerOperations,
        address __arth,
        address __maha,
        address _priceFeed,
        address _pool,
        uint256 _rewardsDuration,
        address _owner,
        address _treasury,
        uint256 _minCr
    ) external initializer {
        arth = IERC20(__arth);
        _arth = __arth;
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        priceFeed = IPriceFeed(_priceFeed);
        pool = ILendingPool(_pool);

        arth.approve(_pool, type(uint256).max);
        arth.approve(_borrowerOperations, type(uint256).max);

        me = address(this);

        mArth = IERC20((pool.getReserveData(__arth)).aTokenAddress);
        minCollateralRatio = _minCr;
        treasury = _treasury;

        totalmArthSupplied = mArth.balanceOf(me);

        _stakingRewardsChildInit(__maha, _rewardsDuration, _owner);
        _transferOwnership(_owner);
    }

    function withdraw(
        uint256 maxFee,
        address upperHint,
        address lowerHint
    ) external nonReentrant {
        _withdraw(msg.sender, positions[msg.sender].ethForLoan);
        totalmArthSupplied -= positions[msg.sender].arthFromLoan;

        // 1. Remove the position and withdraw the stake for stopping further rewards.
        Position memory p = positions[msg.sender];
        require(p.isActive, "Position not open");

        // 2. Withdraw from the lending pool.
        // 3. Ensure that we received correct amount of arth
        require(
            pool.withdraw(_arth, p.arthFromLoan, me) == p.arthFromLoan,
            "arth withdrawn != loan position"
        );

        // // 4. Adjust the trove, remove ETH on behalf of the user and burn the
        // // ARTH that was minted.
        // params.borrowerOperations.adjustTrove(
        //     params.maxFee,
        //     p.ethForLoan,
        //     p.arthFromLoan,
        //     false,
        //     params.upperHint, // calculated from the frontend
        //     params.lowerHint // calculated from the frontend
        // );

        // 5. The contract now has eth inside it. Send it back to the user
        payable(msg.sender).transfer(p.ethForLoan);
        emit Withdrawal(msg.sender, p.ethForLoan, p.arthFromLoan);

        delete positions[msg.sender];
    }

    /// @notice Send the revenue the strategy has generated to the treasury <3
    function collectRevenue() public nonReentrant {
        uint256 revenue = revenueMArth();
        pool.withdraw(_arth, revenue, me);
        arth.transfer(treasury, revenue);
        emit RevenueClaimed(revenue);
    }

    /// --- Admin only functions

    /// @notice admin-only function in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }

    /// @notice Emergency function to modify a position in case it has been corrupted.
    function modifyPosition(address who, Position memory position) external onlyOwner {
        positions[who] = position;
    }

    /// @notice Toggle pausing the contract in the event of any bugs
    function togglePause() external onlyOwner {
        paused = !paused;
        emit PauseToggled(paused);
    }

    // --- View functions

    /// @notice Version number for upgradability
    function getRevision() public pure virtual override returns (uint256) {
        return 2;
    }

    /// @notice Returns how much mARTH revenue we have generated so far.
    function revenueMArth() public view returns (uint256 revenue) {
        // Since mARTH.balanceOf is always an increasing number,
        // this will always be positive.
        revenue = mArth.balanceOf(me) - totalmArthSupplied;
    }

    /// @notice Returns the CR of the given user
    function getPositionCR(address who) public returns (uint256 cr) {
        uint256 price = priceFeed.fetchPrice();
        return (price * positions[who].ethForLoan) / (positions[who].arthFromLoan);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context, Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Operator is Context, Ownable {
    address private _operator;

    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    constructor() {
        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);
    }

    function operator() public view returns (address) {
        return _operator;
    }

    modifier onlyOperator() {
        require(_operator == _msgSender(), "operator: caller is not the operator");
        _;
    }

    function isOperator() public view returns (bool) {
        return _msgSender() == _operator;
    }

    function transferOperator(address newOperator_) public onlyOwner {
        _transferOperator(newOperator_);
    }

    function _transferOperator(address newOperator_) internal {
        require(newOperator_ != address(0), "operator: zero address given for new operator");
        emit OperatorTransferred(address(0), newOperator_);
        _operator = newOperator_;
    }
}