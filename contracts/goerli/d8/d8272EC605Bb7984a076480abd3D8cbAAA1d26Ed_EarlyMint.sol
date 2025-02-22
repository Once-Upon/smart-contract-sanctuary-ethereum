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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IERC721Contract {
    function earlyMint(address to, uint8 quantity, uint batchId) external payable;
}

contract EarlyMint is ReentrancyGuard, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;
    bool public contractPaused = false;
    uint256 public batchCounter = 0;
    uint256 public priceToCreateBatch = 0.05 ether;
    uint256 public pricePerSpot = 0.003 ether;
    uint8 public defaultOwnerPercentage = 10;
    address authorizerAddress;
    mapping (uint => Batch) public batchesList;
    mapping (uint => mapping (address => bool)) public managers;
    mapping (uint => mapping (address => uint8)) public paidSpots;
    mapping (uint => address[]) public paidSpotsAddresses;

    struct Batch {
        uint256 id;
        address creator; // msg.sender
        address nftContractAddress;
        bool paused; // this can pause and unpause the addition of paid spots for this batch
        bool minted; // this means it is complete and the NFTs have been minted
        string externalId; // external id of the batch
        uint8 fee; // % of premint sale amount that gets paid to this contract
        uint256 price; // cost to premint
        uint256 maxSpots; // max number of spots available on this batch
        uint256 spotsTaken; // number of spots taken on this batch
        uint256 spotsPerWallet; // number of paidSpots spots available per wallet
        uint256 batchBalance; // amount of wei paid to this batch
    }

    struct Spot {
        uint256 batchId;
        address purchaserAddress;
        uint8 quantity;
        uint256 spotsTakenTotal; // The new value of taken spots after this spot is added
        uint256 spotsTakenByWallet; // The new value of taken spots by this address after this spot is added
        string externalId; // same value as the batch external id
    }

    event BatchCreated(Batch batch);
    event SpotReserved(Spot spot);

    constructor() {
        authorizerAddress = msg.sender;
    }

    modifier isManager(uint256 _batchId) {
        require(managers[_batchId][msg.sender] == true || batchesList[_batchId].creator == msg.sender || msg.sender == owner(), "You are not a manager of this batch");
        _;
    }

    modifier isValidMessage(bytes memory _signature, string memory _batchId, string memory _function){
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(this), msg.sender, _batchId, _function)
        );
        address signer = messageHash.toEthSignedMessageHash().recover(
            _signature
        );
        require(signer == authorizerAddress, "Invalid signature");
        _;
    }

    modifier ensureUniqueBatchExternalId(string memory _externalId) {
        for (uint i = 0; i < batchCounter; i++) {
            require(keccak256(abi.encodePacked(batchesList[i].externalId)) != keccak256(abi.encodePacked(_externalId)), "External ID already exists");
        }
        _;
    }

    function updateAuthorizerAddress(address _authorizerAddress) public onlyOwner {
        authorizerAddress = _authorizerAddress;
    }

    function unpauseContract() public onlyOwner {
        contractPaused = false;
    }

    function pauseContract() public onlyOwner {
        contractPaused = true;
    }

    function updateDefaultOwnerPercentage(uint8 _newPercentage) public onlyOwner {
        require(_newPercentage <= 100, "Percentage cannot be greater than 100");
        require(_newPercentage >= 0, "Percentage cannot be less than 0");
        defaultOwnerPercentage = _newPercentage;
    }

    function updatePriceToCreateBatch(uint256 _price) public onlyOwner {
        priceToCreateBatch = _price;
    }

    function updatePricePerSpot(uint256 _price) public onlyOwner {
        pricePerSpot = _price;
    }

    function requestRefund(uint256 _batchId) public nonReentrant {
        require(batchesList[_batchId].minted == false, "This batch has already been minted");
        uint quantity = paidSpots[_batchId][msg.sender];
        uint price = batchesList[_batchId].price;
        payable(msg.sender).transfer(quantity * price);
        batchesList[_batchId].spotsTaken -= quantity;
        batchesList[_batchId].batchBalance -= quantity * price;
    }

    function getPriceToCreateBatch(uint256 _maxSpots) public view returns (uint256) {
        return priceToCreateBatch + (_maxSpots * pricePerSpot);
    }

    function createBatch(string memory _externalId, uint256 _price, uint256 _maxSpots, uint256 _spotsPerWallet, address _nftContractAddress, address _creator, bytes memory _signature) public payable isValidMessage(_signature, _externalId, "create") ensureUniqueBatchExternalId(_externalId) nonReentrant returns (uint) {
        require(contractPaused == false, "Contract is paused");
        require(_spotsPerWallet > 0, "You must allow at least 1 spot per wallet");
        require(_maxSpots > 0, "You must allow at least 1 spot");
        require(_nftContractAddress != address(0), "Contract address cannot be 0");
        require(msg.value >= priceToCreateBatch + (pricePerSpot * _maxSpots), "Not enough ETH sent");

        batchesList[batchCounter] = Batch({
            id: batchCounter,
            externalId: _externalId,
            creator: _creator,
            nftContractAddress: _nftContractAddress,
            paused: true,
            minted: false,
            fee: defaultOwnerPercentage,
            price: _price,
            maxSpots: _maxSpots,
            spotsTaken: 0,
            spotsPerWallet: _spotsPerWallet,
            batchBalance: 0
        });
        emit BatchCreated(batchesList[batchCounter]);
        batchCounter++;
        return batchCounter - 1;
    }

    function getBatchByExternalId(string memory _externalId) public view returns (Batch memory) {
        for (uint i = 0; i < batchCounter; i++) {
            if (keccak256(abi.encodePacked(batchesList[i].externalId)) == keccak256(abi.encodePacked(_externalId))) {
                return batchesList[i];
            }
        }
        revert("Batch not found");
    }

    function deleteBatch(uint256 _batchId) public nonReentrant onlyOwner {
        delete batchesList[_batchId];
    }

    function addManager(uint256 _batchId, address _manager) public nonReentrant isManager(_batchId) {
        managers[_batchId][_manager] = true;
    }

    function removeManager(uint256 _batchId, address _manager) public nonReentrant isManager(_batchId) {
        delete managers[_batchId][_manager];
    }

    function checkIfAddressIsManager(uint256 _batchId, address _address) public view returns (bool) {
        return managers[_batchId][_address];
    }

    function setUnMinted(uint256 _batchId) public nonReentrant onlyOwner {
        batchesList[_batchId].minted = false;
    }

    function updateNftContractAddress(uint256 _batchId, address _nftContractAddress) public {
        require(_nftContractAddress != address(0), "Contract address cannot be 0");
        require(batchesList[_batchId].creator == msg.sender || msg.sender == owner(), "You must be the creator of this batch to update the address");
        batchesList[_batchId].nftContractAddress = _nftContractAddress;
    }

    function getNftContractAddress(uint256 _batchId) public view returns (address) {
        return batchesList[_batchId].nftContractAddress;
    }

    function executeMintForBatch(uint256 _batchId) public {
        require(batchesList[_batchId].creator == msg.sender || msg.sender == owner(), "You must be the creator of this batch to update the address");
        for (uint i = 0; i < paidSpotsAddresses[_batchId].length; i++) {
            address key = paidSpotsAddresses[_batchId][i];
            uint8 spots = paidSpots[_batchId][key];
            IERC721Contract(batchesList[_batchId].nftContractAddress).earlyMint{value: batchesList[_batchId].price * spots}(key, spots, _batchId);
        }
        batchesList[_batchId].minted = true;
    }

    function pauseBatch(uint256 _batchId) public isManager(_batchId) {
        batchesList[_batchId].paused = true;
    }

    function unpauseBatch(uint256 _batchId) public isManager(_batchId) {
        batchesList[_batchId].paused = false;
    }

    function getBatchById(uint256 _batchId) public view returns (Batch memory) {
        return batchesList[_batchId];
    }

    function getPaidSpotsByBatchId(uint256 _batchId) public view returns (address[] memory) {
        return paidSpotsAddresses[_batchId];
    }

    function getMyBatchIDs() public view returns (uint256[] memory) {
        uint256[] memory batches = new uint256[](batchCounter);
        uint256 counter = 0;
        for (uint256 i = 0; i < batchCounter; i++) {
            if (managers[i][msg.sender] == true) {
                batches[counter] = i;
                counter++;
            }else if(batchesList[i].creator == msg.sender) {
                batches[counter] = i;
                counter++;
            }
        }
        return batches;
    }

    function getBatchesManagedByAddress(address _manager) public view returns (uint256[] memory) {
        uint256[] memory batches = new uint256[](batchCounter);
        uint256 counter = 0;
        for (uint256 i = 0; i < batchCounter; i++) {
            if (managers[i][_manager] == true) {
                batches[counter] = i;
                counter++;
            }else if(batchesList[i].creator == _manager) {
                batches[counter] = i;
                counter++;
            }
        }
        return batches;
    }

    function addPaidSpotsAddress(uint256 _batchId, address _paidSpotsAddress) internal {
        bool exists = false;
        for (uint i = 0; i < paidSpotsAddresses[_batchId].length; i++) {
            if (paidSpotsAddresses[_batchId][i] == _paidSpotsAddress) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            paidSpotsAddresses[_batchId].push(_paidSpotsAddress);
        }
    }

    function costPerSpot(uint256 _batchId) public view returns (uint256) {
        return batchesList[_batchId].price + (batchesList[_batchId].price * batchesList[_batchId].fee / 100);
    }

    function reserveSpot(uint256 _batchId, uint8 _requestedSpotQuantity) public payable nonReentrant {
        uint256 ownedAndRequested = paidSpots[_batchId][msg.sender] + _requestedSpotQuantity;
        uint256 totalCostPerSpot = costPerSpot(_batchId);
        require(batchesList[_batchId].paused == false, "This batch is paused");
        require(msg.value >= totalCostPerSpot * _requestedSpotQuantity, "Not enough ETH sent");
        require(ownedAndRequested <= batchesList[_batchId].spotsPerWallet, "You cannot own more than the max spots per wallet");
        require(batchesList[_batchId].maxSpots >= batchesList[_batchId].spotsTaken + _requestedSpotQuantity, "No more spots available");
        paidSpots[_batchId][msg.sender] += _requestedSpotQuantity;
        addPaidSpotsAddress(_batchId, msg.sender);
        batchesList[_batchId].spotsTaken += _requestedSpotQuantity;
        batchesList[_batchId].batchBalance += batchesList[_batchId].price * _requestedSpotQuantity;
        emit SpotReserved(Spot({
            batchId: _batchId,
            purchaserAddress: msg.sender,
            quantity: _requestedSpotQuantity,
            spotsTakenTotal: batchesList[_batchId].spotsTaken,
            spotsTakenByWallet: paidSpots[_batchId][msg.sender],
            externalId: batchesList[_batchId].externalId
        }));
    }

    function checkPaidSpots(uint256 _batchId) public view returns (uint256) {
        return paidSpots[_batchId][msg.sender];
    }

    function checkPaidSpotsForAddress(uint256 _batchId, address _address) public view returns (uint256) {
        return paidSpots[_batchId][_address];
    }

    function updateWalletAddress(uint256 _batchId, address _newAddress) public nonReentrant {
        require(paidSpots[_batchId][msg.sender] > 0, "You must own at least 1 spot to update your address");
        paidSpots[_batchId][_newAddress] = paidSpots[_batchId][msg.sender];
        delete paidSpots[_batchId][msg.sender];
    }

    function withdraw() public onlyOwner nonReentrant{
        (bool owner, ) = payable(owner()).call{value: address(this).balance}("");
        require(owner);
    }

    function withdrawAmount(uint256 _amount) public onlyOwner nonReentrant{
        require(_amount <= address(this).balance, "Not enough funds");
        (bool owner, ) = payable(owner()).call{value: _amount}("");
        require(owner);
    }
}