// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
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
    function transferFrom(
        address sender,
        address recipient,
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

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
        InvalidSignatureV
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
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
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
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
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
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
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
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
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

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
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
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./IERC20WithPermit.sol";
import "./IReceiveApproval.sol";

/// @title  ERC20WithPermit
/// @notice Burnable ERC20 token with EIP2612 permit functionality. User can
///         authorize a transfer of their token with a signature conforming
///         EIP712 standard instead of an on-chain transaction from their
///         address. Anyone can submit this signature on the user's behalf by
///         calling the permit function, as specified in EIP2612 standard,
///         paying gas fees, and possibly performing other actions in the same
///         transaction.
contract ERC20WithPermit is IERC20WithPermit, Ownable {
    /// @notice The amount of tokens owned by the given account.
    mapping(address => uint256) public override balanceOf;

    /// @notice The remaining number of tokens that spender will be
    ///         allowed to spend on behalf of owner through `transferFrom` and
    ///         `burnFrom`. This is zero by default.
    mapping(address => mapping(address => uint256)) public override allowance;

    /// @notice Returns the current nonce for EIP2612 permission for the
    ///         provided token owner for a replay protection. Used to construct
    ///         EIP2612 signature provided to `permit` function.
    mapping(address => uint256) public override nonce;

    uint256 public immutable cachedChainId;
    bytes32 public immutable cachedDomainSeparator;

    /// @notice Returns EIP2612 Permit message hash. Used to construct EIP2612
    ///         signature provided to `permit` function.
    bytes32 public constant override PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /// @notice The amount of tokens in existence.
    uint256 public override totalSupply;

    /// @notice The name of the token.
    string public override name;

    /// @notice The symbol of the token.
    string public override symbol;

    /// @notice The decimals places of the token.
    uint8 public constant override decimals = 18;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;

        cachedChainId = block.chainid;
        cachedDomainSeparator = buildDomainSeparator();
    }

    /// @notice Moves `amount` tokens from the caller's account to `recipient`.
    /// @return True if the operation succeeded, reverts otherwise.
    /// @dev Requirements:
    ///       - `recipient` cannot be the zero address,
    ///       - the caller must have a balance of at least `amount`.
    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /// @notice Moves `amount` tokens from `spender` to `recipient` using the
    ///         allowance mechanism. `amount` is then deducted from the caller's
    ///         allowance unless the allowance was made for `type(uint256).max`.
    /// @return True if the operation succeeded, reverts otherwise.
    /// @dev Requirements:
    ///      - `spender` and `recipient` cannot be the zero address,
    ///      - `spender` must have a balance of at least `amount`,
    ///      - the caller must have allowance for `spender`'s tokens of at least
    ///        `amount`.
    function transferFrom(
        address spender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint256 currentAllowance = allowance[spender][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "Transfer amount exceeds allowance"
            );
            _approve(spender, msg.sender, currentAllowance - amount);
        }
        _transfer(spender, recipient, amount);
        return true;
    }

    /// @notice EIP2612 approval made with secp256k1 signature.
    ///         Users can authorize a transfer of their tokens with a signature
    ///         conforming EIP712 standard, rather than an on-chain transaction
    ///         from their address. Anyone can submit this signature on the
    ///         user's behalf by calling the permit function, paying gas fees,
    ///         and possibly performing other actions in the same transaction.
    /// @dev    The deadline argument can be set to `type(uint256).max to create
    ///         permits that effectively never expire.  If the `amount` is set
    ///         to `type(uint256).max` then `transferFrom` and `burnFrom` will
    ///         not reduce an allowance.
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        /* solhint-disable-next-line not-rely-on-time */
        require(deadline >= block.timestamp, "Permission expired");

        // Validate `s` and `v` values for a malleability concern described in EIP2.
        // Only signatures with `s` value in the lower half of the secp256k1
        // curve's order and `v` value of 27 or 28 are considered valid.
        require(
            uint256(s) <=
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "Invalid signature 's' value"
        );
        require(v == 27 || v == 28, "Invalid signature 'v' value");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        amount,
                        nonce[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "Invalid signature"
        );
        _approve(owner, spender, amount);
    }

    /// @notice Creates `amount` tokens and assigns them to `account`,
    ///         increasing the total supply.
    /// @dev Requirements:
    ///      - `recipient` cannot be the zero address.
    function mint(address recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Mint to the zero address");

        beforeTokenTransfer(address(0), recipient, amount);

        totalSupply += amount;
        balanceOf[recipient] += amount;
        emit Transfer(address(0), recipient, amount);
    }

    /// @notice Destroys `amount` tokens from the caller.
    /// @dev Requirements:
    ///       - the caller must have a balance of at least `amount`.
    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    /// @notice Destroys `amount` of tokens from `account` using the allowance
    ///         mechanism. `amount` is then deducted from the caller's allowance
    ///         unless the allowance was made for `type(uint256).max`.
    /// @dev Requirements:
    ///      - `account` must have a balance of at least `amount`,
    ///      - the caller must have allowance for `account`'s tokens of at least
    ///        `amount`.
    function burnFrom(address account, uint256 amount) external override {
        uint256 currentAllowance = allowance[account][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "Burn amount exceeds allowance"
            );
            _approve(account, msg.sender, currentAllowance - amount);
        }
        _burn(account, amount);
    }

    /// @notice Calls `receiveApproval` function on spender previously approving
    ///         the spender to withdraw from the caller multiple times, up to
    ///         the `amount` amount. If this function is called again, it
    ///         overwrites the current allowance with `amount`. Reverts if the
    ///         approval reverted or if `receiveApproval` call on the spender
    ///         reverted.
    /// @return True if both approval and `receiveApproval` calls succeeded.
    /// @dev If the `amount` is set to `type(uint256).max` then
    ///      `transferFrom` and `burnFrom` will not reduce an allowance.
    function approveAndCall(
        address spender,
        uint256 amount,
        bytes memory extraData
    ) external override returns (bool) {
        if (approve(spender, amount)) {
            IReceiveApproval(spender).receiveApproval(
                msg.sender,
                amount,
                address(this),
                extraData
            );
            return true;
        }
        return false;
    }

    /// @notice Sets `amount` as the allowance of `spender` over the caller's
    ///         tokens.
    /// @return True if the operation succeeded.
    /// @dev If the `amount` is set to `type(uint256).max` then
    ///      `transferFrom` and `burnFrom` will not reduce an allowance.
    ///      Beware that changing an allowance with this method brings the risk
    ///      that someone may use both the old and the new allowance by
    ///      unfortunate transaction ordering. One possible solution to mitigate
    ///      this race condition is to first reduce the spender's allowance to 0
    ///      and set the desired value afterwards:
    ///      https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @notice Returns hash of EIP712 Domain struct with the token name as
    ///         a signing domain and token contract as a verifying contract.
    ///         Used to construct EIP2612 signature provided to `permit`
    ///         function.
    /* solhint-disable-next-line func-name-mixedcase */
    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        // As explained in EIP-2612, if the DOMAIN_SEPARATOR contains the
        // chainId and is defined at contract deployment instead of
        // reconstructed for every signature, there is a risk of possible replay
        // attacks between chains in the event of a future chain split.
        // To address this issue, we check the cached chain ID against the
        // current one and in case they are different, we build domain separator
        // from scratch.
        if (block.chainid == cachedChainId) {
            return cachedDomainSeparator;
        } else {
            return buildDomainSeparator();
        }
    }

    /// @dev Hook that is called before any transfer of tokens. This includes
    ///      minting and burning.
    ///
    /// Calling conditions:
    /// - when `from` and `to` are both non-zero, `amount` of `from`'s tokens
    ///   will be to transferred to `to`.
    /// - when `from` is zero, `amount` tokens will be minted for `to`.
    /// - when `to` is zero, `amount` of ``from``'s tokens will be burned.
    /// - `from` and `to` are never both zero.
    // slither-disable-next-line dead-code
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _burn(address account, uint256 amount) internal {
        uint256 currentBalance = balanceOf[account];
        require(currentBalance >= amount, "Burn amount exceeds balance");

        beforeTokenTransfer(account, address(0), amount);

        balanceOf[account] = currentBalance - amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _transfer(
        address spender,
        address recipient,
        uint256 amount
    ) private {
        require(spender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(recipient != address(this), "Transfer to the token address");

        beforeTokenTransfer(spender, recipient, amount);

        uint256 spenderBalance = balanceOf[spender];
        require(spenderBalance >= amount, "Transfer amount exceeds balance");
        balanceOf[spender] = spenderBalance - amount;
        balanceOf[recipient] += amount;
        emit Transfer(spender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function buildDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(this)
                )
            );
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/// @notice An interface that should be implemented by tokens supporting
///         `approveAndCall`/`receiveApproval` pattern.
interface IApproveAndCall {
    /// @notice Executes `receiveApproval` function on spender as specified in
    ///         `IReceiveApproval` interface. Approves spender to withdraw from
    ///         the caller multiple times, up to the `amount`. If this
    ///         function is called again, it overwrites the current allowance
    ///         with `amount`. Reverts if the approval reverted or if
    ///         `receiveApproval` call on the spender reverted.
    function approveAndCall(
        address spender,
        uint256 amount,
        bytes memory extraData
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./IApproveAndCall.sol";

/// @title  IERC20WithPermit
/// @notice Burnable ERC20 token with EIP2612 permit functionality. User can
///         authorize a transfer of their token with a signature conforming
///         EIP712 standard instead of an on-chain transaction from their
///         address. Anyone can submit this signature on the user's behalf by
///         calling the permit function, as specified in EIP2612 standard,
///         paying gas fees, and possibly performing other actions in the same
///         transaction.
interface IERC20WithPermit is IERC20, IERC20Metadata, IApproveAndCall {
    /// @notice EIP2612 approval made with secp256k1 signature.
    ///         Users can authorize a transfer of their tokens with a signature
    ///         conforming EIP712 standard, rather than an on-chain transaction
    ///         from their address. Anyone can submit this signature on the
    ///         user's behalf by calling the permit function, paying gas fees,
    ///         and possibly performing other actions in the same transaction.
    /// @dev    The deadline argument can be set to `type(uint256).max to create
    ///         permits that effectively never expire.
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Destroys `amount` tokens from the caller.
    function burn(uint256 amount) external;

    /// @notice Destroys `amount` of tokens from `account`, deducting the amount
    ///         from caller's allowance.
    function burnFrom(address account, uint256 amount) external;

    /// @notice Returns hash of EIP712 Domain struct with the token name as
    ///         a signing domain and token contract as a verifying contract.
    ///         Used to construct EIP2612 signature provided to `permit`
    ///         function.
    /* solhint-disable-next-line func-name-mixedcase */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Returns the current nonce for EIP2612 permission for the
    ///         provided token owner for a replay protection. Used to construct
    ///         EIP2612 signature provided to `permit` function.
    function nonce(address owner) external view returns (uint256);

    /// @notice Returns EIP2612 Permit message hash. Used to construct EIP2612
    ///         signature provided to `permit` function.
    /* solhint-disable-next-line func-name-mixedcase */
    function PERMIT_TYPEHASH() external pure returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/// @notice An interface that should be implemented by contracts supporting
///         `approveAndCall`/`receiveApproval` pattern.
interface IReceiveApproval {
    /// @notice Receives approval to spend tokens. Called as a result of
    ///         `approveAndCall` call on the token.
    function receiveApproval(
        address from,
        uint256 amount,
        address token,
        bytes calldata extraData
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title Checkpoints
/// @dev Abstract contract to support checkpoints for Compound-like voting and
///      delegation. This implementation supports token supply up to 2^96 - 1.
///      This contract keeps a history (checkpoints) of each account's vote
///      power. Vote power can be delegated either by calling the {delegate}
///      function directly, or by providing a signature to be used with
///      {delegateBySig}. Voting power can be publicly queried through
///      {getVotes} and {getPastVotes}.
///      NOTE: Extracted from OpenZeppelin ERCVotes.sol.
abstract contract Checkpoints {
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    mapping(address => address) internal _delegates;
    mapping(address => uint128[]) internal _checkpoints;
    uint128[] internal _totalSupplyCheckpoints;

    /// @notice Emitted when an account changes their delegate.
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice Emitted when a balance or delegate change results in changes
    ///         to an account's voting power.
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    function checkpoints(address account, uint32 pos)
        public
        view
        virtual
        returns (Checkpoint memory checkpoint)
    {
        (uint32 fromBlock, uint96 votes) = decodeCheckpoint(
            _checkpoints[account][pos]
        );
        checkpoint = Checkpoint(fromBlock, votes);
    }

    /// @notice Get number of checkpoints for `account`.
    function numCheckpoints(address account)
        public
        view
        virtual
        returns (uint32)
    {
        return SafeCast.toUint32(_checkpoints[account].length);
    }

    /// @notice Get the address `account` is currently delegating to.
    function delegates(address account) public view virtual returns (address) {
        return _delegates[account];
    }

    /// @notice Gets the current votes balance for `account`.
    /// @param account The address to get votes balance
    /// @return The number of current votes for `account`
    function getVotes(address account) public view returns (uint96) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : decodeValue(_checkpoints[account][pos - 1]);
    }

    /// @notice Determine the prior number of votes for an account as of
    ///         a block number.
    /// @dev Block number must be a finalized block or else this function will
    ///      revert to prevent misinformation.
    /// @param account The address of the account to check
    /// @param blockNumber The block number to get the vote balance at
    /// @return The number of votes the account had as of the given block
    function getPastVotes(address account, uint256 blockNumber)
        public
        view
        returns (uint96)
    {
        return lookupCheckpoint(_checkpoints[account], blockNumber);
    }

    /// @notice Retrieve the `totalSupply` at the end of `blockNumber`.
    ///         Note, this value is the sum of all balances, but it is NOT the
    ///         sum of all the delegated votes!
    /// @param blockNumber The block number to get the total supply at
    /// @dev `blockNumber` must have been already mined
    function getPastTotalSupply(uint256 blockNumber)
        public
        view
        returns (uint96)
    {
        return lookupCheckpoint(_totalSupplyCheckpoints, blockNumber);
    }

    /// @notice Change delegation for `delegator` to `delegatee`.
    // slither-disable-next-line dead-code
    function delegate(address delegator, address delegatee) internal virtual;

    /// @notice Moves voting power from one delegate to another
    /// @param src Address of old delegate
    /// @param dst Address of new delegate
    /// @param amount Voting power amount to transfer between delegates
    function moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) internal {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                // https://github.com/crytic/slither/issues/960
                // slither-disable-next-line variable-scope
                (uint256 oldWeight, uint256 newWeight) = writeCheckpoint(
                    _checkpoints[src],
                    subtract,
                    amount
                );
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                // https://github.com/crytic/slither/issues/959
                // slither-disable-next-line uninitialized-local
                (uint256 oldWeight, uint256 newWeight) = writeCheckpoint(
                    _checkpoints[dst],
                    add,
                    amount
                );
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    /// @notice Writes a new checkpoint based on operating last stored value
    ///         with a `delta`. Usually, said operation is the `add` or
    ///         `subtract` functions from this contract, but more complex
    ///         functions can be passed as parameters.
    /// @param ckpts The checkpoints array to use
    /// @param op The function to apply over the last value and the `delta`
    /// @param delta Variation with respect to last stored value to be used
    ///              for new checkpoint
    function writeCheckpoint(
        uint128[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) internal returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;
        oldWeight = pos == 0 ? 0 : decodeValue(ckpts[pos - 1]);
        newWeight = op(oldWeight, delta);

        if (pos > 0) {
            uint32 fromBlock = decodeBlockNumber(ckpts[pos - 1]);
            // slither-disable-next-line incorrect-equality
            if (fromBlock == block.number) {
                ckpts[pos - 1] = encodeCheckpoint(
                    fromBlock,
                    SafeCast.toUint96(newWeight)
                );
                return (oldWeight, newWeight);
            }
        }

        ckpts.push(
            encodeCheckpoint(
                SafeCast.toUint32(block.number),
                SafeCast.toUint96(newWeight)
            )
        );
    }

    /// @notice Lookup a value in a list of (sorted) checkpoints.
    /// @param ckpts The checkpoints array to use
    /// @param blockNumber Block number when we want to get the checkpoint at
    function lookupCheckpoint(uint128[] storage ckpts, uint256 blockNumber)
        internal
        view
        returns (uint96)
    {
        // We run a binary search to look for the earliest checkpoint taken
        // after `blockNumber`. During the loop, the index of the wanted
        // checkpoint remains in the range [low-1, high). With each iteration,
        // either `low` or `high` is moved towards the middle of the range to
        // maintain the invariant.
        // - If the middle checkpoint is after `blockNumber`,
        //   we look in [low, mid)
        // - If the middle checkpoint is before or equal to `blockNumber`,
        //   we look in [mid+1, high)
        // Once we reach a single value (when low == high), we've found the
        // right checkpoint at the index high-1, if not out of bounds (in that
        // case we're looking too far in the past and the result is 0).
        // Note that if the latest checkpoint available is exactly for
        // `blockNumber`, we end up with an index that is past the end of the
        // array, so we technically don't find a checkpoint after
        // `blockNumber`, but it works out the same.
        require(blockNumber < block.number, "Block not yet determined");

        uint256 high = ckpts.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            uint32 midBlock = decodeBlockNumber(ckpts[mid]);
            if (midBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : decodeValue(ckpts[high - 1]);
    }

    /// @notice Maximum token supply. Defaults to `type(uint96).max` (2^96 - 1)
    // slither-disable-next-line dead-code
    function maxSupply() internal view virtual returns (uint96) {
        return type(uint96).max;
    }

    /// @notice Encodes a `blockNumber` and `value` into a single `uint128`
    ///         checkpoint.
    /// @dev `blockNumber` is stored in the first 32 bits, while `value` in the
    ///      remaining 96 bits.
    function encodeCheckpoint(uint32 blockNumber, uint96 value)
        internal
        pure
        returns (uint128)
    {
        return (uint128(blockNumber) << 96) | uint128(value);
    }

    /// @notice Decodes a block number from a `uint128` `checkpoint`.
    function decodeBlockNumber(uint128 checkpoint)
        internal
        pure
        returns (uint32)
    {
        return uint32(bytes4(bytes16(checkpoint)));
    }

    /// @notice Decodes a voting value from a `uint128` `checkpoint`.
    function decodeValue(uint128 checkpoint) internal pure returns (uint96) {
        return uint96(checkpoint);
    }

    /// @notice Decodes a block number and voting value from a `uint128`
    ///         `checkpoint`.
    function decodeCheckpoint(uint128 checkpoint)
        internal
        pure
        returns (uint32 blockNumber, uint96 value)
    {
        blockNumber = decodeBlockNumber(checkpoint);
        value = decodeValue(checkpoint);
    }

    // slither-disable-next-line dead-code
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    // slither-disable-next-line dead-code
    function subtract(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

import "./interfaces/IAssetPool.sol";
import "./interfaces/IAssetPoolUpgrade.sol";
import "./RewardsPool.sol";
import "./UnderwriterToken.sol";
import "./GovernanceUtils.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Asset Pool
/// @notice Asset pool is a component of a Coverage Pool. Asset Pool
///         accepts a single ERC20 token as collateral, and returns an
///         underwriter token. For example, an asset pool might accept deposits
///         in KEEP in return for covKEEP underwriter tokens. Underwriter tokens
///         represent an ownership share in the underlying collateral of the
///         Asset Pool. Asset Pool accepts no more than 2^96-1 collateral tokens
///         as a deposit. It means that the total supply of the collateral token
///         can not be greater than 2^96-1 or, if that supply is greater, it is
///         acceptable that not all tokens can be deposited into the pool.
contract AssetPool is Ownable, IAssetPool {
    using SafeERC20 for IERC20;
    using SafeERC20 for UnderwriterToken;

    IERC20 public immutable collateralToken;
    UnderwriterToken public immutable underwriterToken;

    RewardsPool public immutable rewardsPool;

    IAssetPoolUpgrade public newAssetPool;

    /// @notice The time it takes the underwriter to withdraw their collateral
    ///         and rewards from the pool. This is the time that needs to pass
    ///         between initiating and completing the withdrawal. During that
    ///         time, underwriter is still earning rewards and their share of
    ///         the pool is still a subject of a possible coverage claim.
    uint256 public withdrawalDelay = 2 minutes;
    uint256 public newWithdrawalDelay;
    uint256 public withdrawalDelayChangeInitiated;

    /// @notice The time the underwriter has after the withdrawal delay passed
    ///         to complete the withdrawal. During that time, underwriter is
    ///         still earning rewards and their share of the pool is still
    ///         a subject of a possible coverage claim.
    ///         After the withdrawal timeout elapses, tokens stay in the pool
    ///         and the underwriter has to initiate the withdrawal again and
    ///         wait for the full withdrawal delay to complete the withdrawal.
    uint256 public withdrawalTimeout = 20 minutes;
    uint256 public newWithdrawalTimeout;
    uint256 public withdrawalTimeoutChangeInitiated;

    mapping(address => uint256) public withdrawalInitiatedTimestamp;
    mapping(address => uint256) public pendingWithdrawal;

    event Deposited(
        address indexed underwriter,
        uint256 amount,
        uint256 covAmount
    );

    event CoverageClaimed(
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    event WithdrawalInitiated(
        address indexed underwriter,
        uint256 covAmount,
        uint256 timestamp
    );
    event WithdrawalCompleted(
        address indexed underwriter,
        uint256 amount,
        uint256 covAmount,
        uint256 timestamp
    );

    event ApprovedAssetPoolUpgrade(address newAssetPool);
    event CancelledAssetPoolUpgrade(address cancelledAssetPool);
    event AssetPoolUpgraded(
        address indexed underwriter,
        uint256 collateralAmount,
        uint256 covAmount,
        uint256 timestamp
    );

    event WithdrawalDelayUpdateStarted(
        uint256 withdrawalDelay,
        uint256 timestamp
    );
    event WithdrawalDelayUpdated(uint256 withdrawalDelay);
    event WithdrawalTimeoutUpdateStarted(
        uint256 withdrawalTimeout,
        uint256 timestamp
    );
    event WithdrawalTimeoutUpdated(uint256 withdrawalTimeout);

    /// @notice Reverts if the withdrawal governance delay has not passed yet or
    ///         if the change was not yet initiated.
    /// @param changeInitiatedTimestamp The timestamp at which the change has
    ///        been initiated
    modifier onlyAfterWithdrawalGovernanceDelay(
        uint256 changeInitiatedTimestamp
    ) {
        require(changeInitiatedTimestamp > 0, "Change not initiated");
        require(
            /* solhint-disable-next-line not-rely-on-time */
            block.timestamp - changeInitiatedTimestamp >=
                withdrawalGovernanceDelay(),
            "Governance delay has not elapsed"
        );
        _;
    }

    constructor(
        IERC20 _collateralToken,
        UnderwriterToken _underwriterToken,
        address rewardsManager
    ) {
        collateralToken = _collateralToken;
        underwriterToken = _underwriterToken;

        rewardsPool = new RewardsPool(
            _collateralToken,
            address(this),
            rewardsManager
        );
    }

    /// @notice Accepts the given amount of collateral token as a deposit and
    ///         mints underwriter tokens representing pool's ownership. The
    ///         amount must be smaller or equal to 2^96-1.
    ///         Optional data in extraData may include a minimal amount of
    ///         underwriter tokens expected to be minted for a depositor. There
    ///         are cases when an amount of minted tokens matters for a
    ///         depositor, as tokens might be used in third party exchanges.
    /// @dev This function is a shortcut for approve + deposit.
    function receiveApproval(
        address from,
        uint256 amount,
        address token,
        bytes calldata extraData
    ) external {
        require(
            amount <= type(uint96).max,
            "deposited amount must be <= 2^96 - 1"
        );
        require(msg.sender == token, "Only token caller allowed");
        require(
            token == address(collateralToken),
            "Unsupported collateral token"
        );

        uint256 toMint = _calculateTokensToMint(amount);
        if (extraData.length != 0) {
            require(extraData.length == 32, "Unexpected data length");
            uint256 minAmountToMint = abi.decode(extraData, (uint256));
            require(
                minAmountToMint <= toMint,
                "Amount to mint is smaller than the required minimum"
            );
        }

        _deposit(from, amount, toMint);
    }

    /// @notice Accepts the given amount of collateral token as a deposit and
    ///         mints underwriter tokens representing pool's ownership.
    /// @dev Before calling this function, collateral token needs to have the
    ///      required amount accepted to transfer to the asset pool.
    /// @param amountToDeposit Collateral tokens amount that a user deposits to
    ///                        the asset pool; must be smaller or equal to
    ///                        2^96-1
    /// @return The amount of minted underwriter tokens
    function deposit(uint256 amountToDeposit)
        external
        override
        returns (uint256)
    {
        require(
            amountToDeposit <= type(uint96).max,
            "deposited amount must be <= 2^96 - 1"
        );
        uint256 toMint = _calculateTokensToMint(amountToDeposit);
        _deposit(msg.sender, amountToDeposit, toMint);
        return toMint;
    }

    /// @notice Accepts the given amount of collateral token as a deposit and
    ///         mints at least a minAmountToMint underwriter tokens representing
    ///         pool's ownership.
    /// @dev Before calling this function, collateral token needs to have the
    ///      required amount accepted to transfer to the asset pool.
    /// @param amountToDeposit Collateral tokens amount that a user deposits to
    ///                        the asset pool; must be smaller or equal
    ///                        to 2^96-1
    /// @param minAmountToMint Underwriter minimal tokens amount that a user
    ///                        expects to receive in exchange for the deposited
    ///                        collateral tokens
    /// @return The amount of minted underwriter tokens
    function depositWithMin(uint256 amountToDeposit, uint256 minAmountToMint)
        external
        override
        returns (uint256)
    {
        require(
            amountToDeposit <= type(uint96).max,
            "deposited amount must be <= 2^96 - 1"
        );
        uint256 toMint = _calculateTokensToMint(amountToDeposit);

        require(
            minAmountToMint <= toMint,
            "Amount to mint is smaller than the required minimum"
        );

        _deposit(msg.sender, amountToDeposit, toMint);
        return toMint;
    }

    /// @notice Initiates the withdrawal of collateral and rewards from the
    ///         pool. Must be followed with completeWithdrawal call after the
    ///         withdrawal delay passes. Accepts the amount of underwriter
    ///         tokens representing the share of the pool that should be
    ///         withdrawn. Can be called multiple times increasing the pool share
    ///         to withdraw and resetting the withdrawal initiated timestamp for
    ///         each call. Can be called with 0 covAmount to reset the
    ///         withdrawal initiated timestamp if the underwriter has a pending
    ///         withdrawal. In practice 0 covAmount should be used only to
    ///         initiate the withdrawal again in case one did not complete the
    ///         withdrawal before the withdrawal timeout elapsed.
    /// @dev Before calling this function, underwriter token needs to have the
    ///      required amount accepted to transfer to the asset pool.
    function initiateWithdrawal(uint256 covAmount) external override {
        uint256 pending = pendingWithdrawal[msg.sender];
        require(
            covAmount > 0 || pending > 0,
            "Underwriter token amount must be greater than 0"
        );

        pending += covAmount;
        pendingWithdrawal[msg.sender] = pending;
        /* solhint-disable not-rely-on-time */
        withdrawalInitiatedTimestamp[msg.sender] = block.timestamp;

        emit WithdrawalInitiated(msg.sender, pending, block.timestamp);
        /* solhint-enable not-rely-on-time */

        if (covAmount > 0) {
            underwriterToken.safeTransferFrom(
                msg.sender,
                address(this),
                covAmount
            );
        }
    }

    /// @notice Completes the previously initiated withdrawal for the
    ///         underwriter. Anyone can complete the withdrawal for the
    ///         underwriter. The withdrawal has to be completed before the
    ///         withdrawal timeout elapses. Otherwise, the withdrawal has to
    ///         be initiated again and the underwriter has to wait for the
    ///         entire withdrawal delay again before being able to complete
    ///         the withdrawal.
    /// @return The amount of collateral withdrawn
    function completeWithdrawal(address underwriter)
        external
        override
        returns (uint256)
    {
        /* solhint-disable not-rely-on-time */
        uint256 initiatedAt = withdrawalInitiatedTimestamp[underwriter];
        require(initiatedAt > 0, "No withdrawal initiated for the underwriter");

        uint256 withdrawalDelayEndTimestamp = initiatedAt + withdrawalDelay;
        require(
            withdrawalDelayEndTimestamp < block.timestamp,
            "Withdrawal delay has not elapsed"
        );

        require(
            withdrawalDelayEndTimestamp + withdrawalTimeout >= block.timestamp,
            "Withdrawal timeout elapsed"
        );

        uint256 covAmount = pendingWithdrawal[underwriter];
        uint256 covSupply = underwriterToken.totalSupply();
        delete withdrawalInitiatedTimestamp[underwriter];
        delete pendingWithdrawal[underwriter];

        // slither-disable-next-line reentrancy-events
        rewardsPool.withdraw();

        uint256 collateralBalance = collateralToken.balanceOf(address(this));

        uint256 amountToWithdraw = (covAmount * collateralBalance) / covSupply;

        emit WithdrawalCompleted(
            underwriter,
            amountToWithdraw,
            covAmount,
            block.timestamp
        );
        collateralToken.safeTransfer(underwriter, amountToWithdraw);

        /* solhint-enable not-rely-on-time */
        underwriterToken.burn(covAmount);

        return amountToWithdraw;
    }

    /// @notice Transfers collateral tokens to a new Asset Pool which previously
    ///         was approved by the governance. Upgrade does not have to obey
    ///         withdrawal delay.
    ///         Old underwriter tokens are burned in favor of new tokens minted
    ///         in a new Asset Pool. New tokens are sent directly to the
    ///         underwriter from a new Asset Pool.
    /// @param covAmount Amount of underwriter tokens used to calculate collateral
    ///                  tokens which are transferred to a new asset pool
    /// @param _newAssetPool New Asset Pool address to check validity with the one
    ///                      that was approved by the governance
    function upgradeToNewAssetPool(uint256 covAmount, address _newAssetPool)
        external
    {
        /* solhint-disable not-rely-on-time */
        require(
            address(newAssetPool) != address(0),
            "New asset pool must be assigned"
        );

        require(
            address(newAssetPool) == _newAssetPool,
            "Addresses of a new asset pool must match"
        );

        require(
            covAmount > 0,
            "Underwriter token amount must be greater than 0"
        );

        uint256 covSupply = underwriterToken.totalSupply();

        // slither-disable-next-line reentrancy-events
        rewardsPool.withdraw();

        uint256 collateralBalance = collateralToken.balanceOf(address(this));

        uint256 collateralToTransfer = (covAmount * collateralBalance) /
            covSupply;

        collateralToken.safeApprove(
            address(newAssetPool),
            collateralToTransfer
        );
        // old underwriter tokens are burned in favor of new minted in a new
        // asset pool
        underwriterToken.burnFrom(msg.sender, covAmount);
        // collateralToTransfer will be sent to a new AssetPool and new
        // underwriter tokens will be minted and transferred back to the underwriter
        newAssetPool.depositFor(msg.sender, collateralToTransfer);

        emit AssetPoolUpgraded(
            msg.sender,
            collateralToTransfer,
            covAmount,
            block.timestamp
        );
    }

    /// @notice Allows governance to set a new asset pool so the underwriters
    ///         can move their collateral tokens to a new asset pool without
    ///         having to wait for the withdrawal delay.
    function approveNewAssetPoolUpgrade(IAssetPoolUpgrade _newAssetPool)
        external
        onlyOwner
    {
        require(
            address(_newAssetPool) != address(0),
            "New asset pool can't be zero address"
        );

        newAssetPool = _newAssetPool;

        emit ApprovedAssetPoolUpgrade(address(_newAssetPool));
    }

    /// @notice Allows governance to cancel already approved new asset pool
    ///         in case of some misconfiguration.
    function cancelNewAssetPoolUpgrade() external onlyOwner {
        emit CancelledAssetPoolUpgrade(address(newAssetPool));

        newAssetPool = IAssetPoolUpgrade(address(0));
    }

    /// @notice Allows the coverage pool to demand coverage from the asset hold
    ///         by this pool and send it to the provided recipient address.
    function claim(address recipient, uint256 amount) external onlyOwner {
        emit CoverageClaimed(recipient, amount, block.timestamp);
        rewardsPool.withdraw();
        collateralToken.safeTransfer(recipient, amount);
    }

    /// @notice Lets the contract owner to begin an update of withdrawal delay
    ///         parameter value. Withdrawal delay is the time it takes the
    ///         underwriter to withdraw their collateral and rewards from the
    ///         pool. This is the time that needs to pass between initiating and
    ///         completing the withdrawal. The change needs to be finalized with
    ///         a call to finalizeWithdrawalDelayUpdate after the required
    ///         governance delay passes. It is up to the contract owner to
    ///         decide what the withdrawal delay value should be but it should
    ///         be long enough so that the possibility of having free-riding
    ///         underwriters escaping from a potential coverage claim by
    ///         withdrawing their positions from the pool is negligible.
    /// @param _newWithdrawalDelay The new value of withdrawal delay
    function beginWithdrawalDelayUpdate(uint256 _newWithdrawalDelay)
        external
        onlyOwner
    {
        newWithdrawalDelay = _newWithdrawalDelay;
        withdrawalDelayChangeInitiated = block.timestamp;
        emit WithdrawalDelayUpdateStarted(_newWithdrawalDelay, block.timestamp);
    }

    /// @notice Lets the contract owner to finalize an update of withdrawal
    ///         delay parameter value. This call has to be preceded with
    ///         a call to beginWithdrawalDelayUpdate and the governance delay
    ///         has to pass.
    function finalizeWithdrawalDelayUpdate()
        external
        onlyOwner
        onlyAfterWithdrawalGovernanceDelay(withdrawalDelayChangeInitiated)
    {
        withdrawalDelay = newWithdrawalDelay;
        emit WithdrawalDelayUpdated(withdrawalDelay);
        newWithdrawalDelay = 0;
        withdrawalDelayChangeInitiated = 0;
    }

    /// @notice Lets the contract owner to begin an update of withdrawal timeout
    ///         parameter value. The withdrawal timeout is the time the
    ///         underwriter has - after the withdrawal delay passed - to
    ///         complete the withdrawal. The change needs to be finalized with
    ///         a call to finalizeWithdrawalTimeoutUpdate after the required
    ///         governance delay passes. It is up to the contract owner to
    ///         decide what the withdrawal timeout value should be but it should
    ///         be short enough so that the time of free-riding by being able to
    ///         immediately escape from the claim is minimal and long enough so
    ///         that honest underwriters have a possibility to finalize the
    ///         withdrawal. It is all about the right proportions with
    ///         a relation to withdrawal delay value.
    /// @param  _newWithdrawalTimeout The new value of the withdrawal timeout
    function beginWithdrawalTimeoutUpdate(uint256 _newWithdrawalTimeout)
        external
        onlyOwner
    {
        newWithdrawalTimeout = _newWithdrawalTimeout;
        withdrawalTimeoutChangeInitiated = block.timestamp;
        emit WithdrawalTimeoutUpdateStarted(
            _newWithdrawalTimeout,
            block.timestamp
        );
    }

    /// @notice Lets the contract owner to finalize an update of withdrawal
    ///         timeout parameter value. This call has to be preceded with
    ///         a call to beginWithdrawalTimeoutUpdate and the governance delay
    ///         has to pass.
    function finalizeWithdrawalTimeoutUpdate()
        external
        onlyOwner
        onlyAfterWithdrawalGovernanceDelay(withdrawalTimeoutChangeInitiated)
    {
        withdrawalTimeout = newWithdrawalTimeout;
        emit WithdrawalTimeoutUpdated(withdrawalTimeout);
        newWithdrawalTimeout = 0;
        withdrawalTimeoutChangeInitiated = 0;
    }

    /// @notice Grants pool shares by minting a given amount of the underwriter
    ///         tokens for the recipient address. In result, the recipient
    ///         obtains part of the pool ownership without depositing any
    ///         collateral tokens. Shares are usually granted for notifiers
    ///         reporting about various contract state changes.
    /// @dev Can be called only by the contract owner.
    /// @param recipient Address of the underwriter tokens recipient
    /// @param covAmount Amount of the underwriter tokens which should be minted
    function grantShares(address recipient, uint256 covAmount)
        external
        onlyOwner
    {
        rewardsPool.withdraw();
        underwriterToken.mint(recipient, covAmount);
    }

    /// @notice Returns the remaining time that has to pass before the contract
    ///         owner will be able to finalize withdrawal delay update.
    ///         Bear in mind the contract owner may decide to wait longer and
    ///         this value is just an absolute minimum.
    /// @return The time left until withdrawal delay update can be finalized
    function getRemainingWithdrawalDelayUpdateTime()
        external
        view
        returns (uint256)
    {
        return
            GovernanceUtils.getRemainingChangeTime(
                withdrawalDelayChangeInitiated,
                withdrawalGovernanceDelay()
            );
    }

    /// @notice Returns the remaining time that has to pass before the contract
    ///         owner will be able to finalize withdrawal timeout update.
    ///         Bear in mind the contract owner may decide to wait longer and
    ///         this value is just an absolute minimum.
    /// @return The time left until withdrawal timeout update can be finalized
    function getRemainingWithdrawalTimeoutUpdateTime()
        external
        view
        returns (uint256)
    {
        return
            GovernanceUtils.getRemainingChangeTime(
                withdrawalTimeoutChangeInitiated,
                withdrawalGovernanceDelay()
            );
    }

    /// @notice Returns the current collateral token balance of the asset pool
    ///         plus the reward amount (in collateral token) earned by the asset
    ///         pool and not yet withdrawn to the asset pool.
    /// @return The total value of asset pool in collateral token.
    function totalValue() external view returns (uint256) {
        return collateralToken.balanceOf(address(this)) + rewardsPool.earned();
    }

    /// @notice The time it takes to initiate and complete the withdrawal from
    ///         the pool plus 2 days to make a decision. This governance delay
    ///         should be used for all changes directly affecting underwriter
    ///         positions. This time is a minimum and the governance may choose
    ///         to wait longer before finalizing the update.
    /// @return The withdrawal governance delay in seconds
    function withdrawalGovernanceDelay() public view returns (uint256) {
        return withdrawalDelay + withdrawalTimeout + 2 days;
    }

    /// @dev Calculates underwriter tokens to mint.
    function _calculateTokensToMint(uint256 amountToDeposit)
        internal
        returns (uint256)
    {
        rewardsPool.withdraw();

        uint256 covSupply = underwriterToken.totalSupply();
        uint256 collateralBalance = collateralToken.balanceOf(address(this));

        if (covSupply == 0) {
            return amountToDeposit;
        }

        uint256 tokensToMint = (amountToDeposit * covSupply) /
            collateralBalance;

        // The total supply of underwriter tokens cannot exceed `type(uint96).max`,
        // because the maximum voting power in the underwriter token is
        // `type(uint96).max`. Therefore the asset pool should not allow to mint
        // more than `type(uint96).max` either. The amount of tokens to mint is
        // stored in `uint256` just for gas efficiency.
        require(
            tokensToMint <= type(uint96).max,
            "Minted tokens amount must be <= 2^96 - 1"
        );

        return tokensToMint;
    }

    function _deposit(
        address depositor,
        uint256 amountToDeposit,
        uint256 amountToMint
    ) internal {
        require(depositor != address(this), "Self-deposit not allowed");

        require(
            amountToMint > 0,
            "Minted tokens amount must be greater than 0"
        );

        emit Deposited(depositor, amountToDeposit, amountToMint);

        underwriterToken.mint(depositor, amountToMint);
        collateralToken.safeTransferFrom(
            depositor,
            address(this),
            amountToDeposit
        );
    }
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

import "./interfaces/IAssetPoolUpgrade.sol";
import "./AssetPool.sol";
import "./CoveragePoolConstants.sol";
import "./GovernanceUtils.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Coverage Pool
/// @notice A contract that manages a single asset pool. Handles approving and
///         unapproving of risk managers and allows them to seize funds from the
///         asset pool if they are approved.
/// @dev Coverage pool contract is owned by the governance. Coverage pool is the
///      owner of the asset pool contract.
contract CoveragePool is Ownable {
    AssetPool public immutable assetPool;
    IERC20 public immutable collateralToken;

    bool public firstRiskManagerApproved = false;

    // Currently approved risk managers
    mapping(address => bool) public approvedRiskManagers;
    // Timestamps of risk managers whose approvals have been initiated
    mapping(address => uint256) public riskManagerApprovalTimestamps;

    event RiskManagerApprovalStarted(address riskManager, uint256 timestamp);
    event RiskManagerApprovalCompleted(address riskManager, uint256 timestamp);
    event RiskManagerUnapproved(address riskManager, uint256 timestamp);

    /// @notice Reverts if called by a risk manager that is not approved
    modifier onlyApprovedRiskManager() {
        require(approvedRiskManagers[msg.sender], "Risk manager not approved");
        _;
    }

    constructor(AssetPool _assetPool) {
        assetPool = _assetPool;
        collateralToken = _assetPool.collateralToken();
    }

    /// @notice Approves the first risk manager
    /// @dev Can be called only by the contract owner. Can be called only once.
    ///      Does not require any further calls to any functions.
    /// @param riskManager Risk manager that will be approved
    function approveFirstRiskManager(address riskManager) external onlyOwner {
        require(
            !firstRiskManagerApproved,
            "The first risk manager was approved"
        );
        approvedRiskManagers[riskManager] = true;
        firstRiskManagerApproved = true;
    }

    /// @notice Begins risk manager approval process.
    /// @dev Can be called only by the contract owner and only when the first
    ///      risk manager is already approved. For a risk manager to be
    ///      approved, a call to `finalizeRiskManagerApproval` must follow
    ///      (after a governance delay).
    /// @param riskManager Risk manager that will be approved
    function beginRiskManagerApproval(address riskManager) external onlyOwner {
        require(
            firstRiskManagerApproved,
            "The first risk manager is not yet approved; Please use "
            "approveFirstRiskManager instead"
        );

        require(
            !approvedRiskManagers[riskManager],
            "Risk manager already approved"
        );

        /* solhint-disable-next-line not-rely-on-time */
        riskManagerApprovalTimestamps[riskManager] = block.timestamp;
        /* solhint-disable-next-line not-rely-on-time */
        emit RiskManagerApprovalStarted(riskManager, block.timestamp);
    }

    /// @notice Finalizes risk manager approval process.
    /// @dev Can be called only by the contract owner. Must be preceded with a
    ///      call to beginRiskManagerApproval and a governance delay must elapse.
    /// @param riskManager Risk manager that will be approved
    function finalizeRiskManagerApproval(address riskManager)
        external
        onlyOwner
    {
        require(
            riskManagerApprovalTimestamps[riskManager] > 0,
            "Risk manager approval not initiated"
        );
        require(
            /* solhint-disable-next-line not-rely-on-time */
            block.timestamp - riskManagerApprovalTimestamps[riskManager] >=
                assetPool.withdrawalGovernanceDelay(),
            "Risk manager governance delay has not elapsed"
        );
        approvedRiskManagers[riskManager] = true;
        /* solhint-disable-next-line not-rely-on-time */
        emit RiskManagerApprovalCompleted(riskManager, block.timestamp);
        delete riskManagerApprovalTimestamps[riskManager];
    }

    /// @notice Unapproves an already approved risk manager or cancels the
    ///         approval process of a risk manager (the latter happens if called
    ///         between `beginRiskManagerApproval` and `finalizeRiskManagerApproval`).
    ///         The change takes effect immediately.
    /// @dev Can be called only by the contract owner.
    /// @param riskManager Risk manager that will be unapproved
    function unapproveRiskManager(address riskManager) external onlyOwner {
        require(
            riskManagerApprovalTimestamps[riskManager] > 0 ||
                approvedRiskManagers[riskManager],
            "Risk manager is neither approved nor with a pending approval"
        );
        delete riskManagerApprovalTimestamps[riskManager];
        delete approvedRiskManagers[riskManager];
        /* solhint-disable-next-line not-rely-on-time */
        emit RiskManagerUnapproved(riskManager, block.timestamp);
    }

    /// @notice Approves upgradeability to the new asset pool.
    ///         Allows governance to set a new asset pool so the underwriters
    ///         can move their collateral tokens to a new asset pool without
    ///         having to wait for the withdrawal delay.
    /// @param _newAssetPool New asset pool
    function approveNewAssetPoolUpgrade(IAssetPoolUpgrade _newAssetPool)
        external
        onlyOwner
    {
        assetPool.approveNewAssetPoolUpgrade(_newAssetPool);
    }

    /// @notice Lets the governance to begin an update of withdrawal delay
    ///         parameter value. Withdrawal delay is the time it takes the
    ///         underwriter to withdraw their collateral and rewards from the
    ///         pool. This is the time that needs to pass between initiating and
    ///         completing the withdrawal. The change needs to be finalized with
    ///         a call to finalizeWithdrawalDelayUpdate after the required
    ///         governance delay passes. It is up to the governance to
    ///         decide what the withdrawal delay value should be but it should
    ///         be long enough so that the possibility of having free-riding
    ///         underwriters escaping from a potential coverage claim by
    ///         withdrawing their positions from the pool is negligible.
    /// @param newWithdrawalDelay The new value of withdrawal delay
    function beginWithdrawalDelayUpdate(uint256 newWithdrawalDelay)
        external
        onlyOwner
    {
        assetPool.beginWithdrawalDelayUpdate(newWithdrawalDelay);
    }

    /// @notice Lets the governance to finalize an update of withdrawal
    ///         delay parameter value. This call has to be preceded with
    ///         a call to beginWithdrawalDelayUpdate and the governance delay
    ///         has to pass.
    function finalizeWithdrawalDelayUpdate() external onlyOwner {
        assetPool.finalizeWithdrawalDelayUpdate();
    }

    /// @notice Lets the governance to begin an update of withdrawal timeout
    ///         parameter value. The withdrawal timeout is the time the
    ///         underwriter has - after the withdrawal delay passed - to
    ///         complete the withdrawal. The change needs to be finalized with
    ///         a call to finalizeWithdrawalTimeoutUpdate after the required
    ///         governance delay passes. It is up to the governance to
    ///         decide what the withdrawal timeout value should be but it should
    ///         be short enough so that the time of free-riding by being able to
    ///         immediately escape from the claim is minimal and long enough so
    ///         that honest underwriters have a possibility to finalize the
    ///         withdrawal. It is all about the right proportions with
    ///         a relation to withdrawal delay value.
    /// @param  newWithdrawalTimeout The new value of the withdrawal timeout
    function beginWithdrawalTimeoutUpdate(uint256 newWithdrawalTimeout)
        external
        onlyOwner
    {
        assetPool.beginWithdrawalTimeoutUpdate(newWithdrawalTimeout);
    }

    /// @notice Lets the governance to finalize an update of withdrawal
    ///         timeout parameter value. This call has to be preceded with
    ///         a call to beginWithdrawalTimeoutUpdate and the governance delay
    ///         has to pass.
    function finalizeWithdrawalTimeoutUpdate() external onlyOwner {
        assetPool.finalizeWithdrawalTimeoutUpdate();
    }

    /// @notice Seizes funds from the coverage pool and puts them aside for the
    ///         recipient to withdraw.
    /// @dev `portionToSeize` value was multiplied by `FLOATING_POINT_DIVISOR`
    ///      for calculation precision purposes. Further calculations in this
    ///      function will need to take this divisor into account.
    /// @param recipient Address that will receive the pool's seized funds
    /// @param portionToSeize Portion of the pool to seize in the range (0, 1]
    ///        multiplied by `FLOATING_POINT_DIVISOR`
    function seizeFunds(address recipient, uint256 portionToSeize)
        external
        onlyApprovedRiskManager
    {
        require(
            portionToSeize > 0 &&
                portionToSeize <= CoveragePoolConstants.FLOATING_POINT_DIVISOR,
            "Portion to seize is not within the range (0, 1]"
        );

        assetPool.claim(recipient, amountToSeize(portionToSeize));
    }

    /// @notice Grants asset pool shares by minting a given amount of the
    ///         underwriter tokens for the recipient address. In result, the
    ///         recipient obtains part of the pool ownership without depositing
    ///         any collateral tokens. Shares are usually granted for notifiers
    ///         reporting about various contract state changes.
    /// @dev Can be called only by an approved risk manager.
    /// @param recipient Address of the underwriter tokens recipient
    /// @param covAmount Amount of the underwriter tokens which should be minted
    function grantAssetPoolShares(address recipient, uint256 covAmount)
        external
        onlyApprovedRiskManager
    {
        assetPool.grantShares(recipient, covAmount);
    }

    /// @notice Returns the time remaining until the risk manager approval
    ///         process can be finalized
    /// @param riskManager Risk manager in the process of approval
    /// @return Remaining time in seconds.
    function getRemainingRiskManagerApprovalTime(address riskManager)
        external
        view
        returns (uint256)
    {
        return
            GovernanceUtils.getRemainingChangeTime(
                riskManagerApprovalTimestamps[riskManager],
                assetPool.withdrawalGovernanceDelay()
            );
    }

    /// @notice Calculates amount of tokens to be seized from the coverage pool.
    /// @param portionToSeize Portion of the pool to seize in the range (0, 1]
    ///        multiplied by FLOATING_POINT_DIVISOR
    function amountToSeize(uint256 portionToSeize)
        public
        view
        returns (uint256)
    {
        return
            (collateralToken.balanceOf(address(assetPool)) * portionToSeize) /
            CoveragePoolConstants.FLOATING_POINT_DIVISOR;
    }
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

library CoveragePoolConstants {
    // This divisor is for precision purposes only. We use this divisor around
    // auction related code to get the precise values without rounding it down
    // when dealing with floating numbers.
    uint256 public constant FLOATING_POINT_DIVISOR = 1e18;
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

library GovernanceUtils {
    /// @notice Gets the time remaining until the governable parameter update
    ///         can be committed.
    /// @param changeTimestamp Timestamp indicating the beginning of the change.
    /// @param delay Governance delay.
    /// @return Remaining time in seconds.
    function getRemainingChangeTime(uint256 changeTimestamp, uint256 delay)
        internal
        view
        returns (uint256)
    {
        require(changeTimestamp > 0, "Change not initiated");
        /* solhint-disable-next-line not-rely-on-time */
        uint256 elapsed = block.timestamp - changeTimestamp;
        if (elapsed >= delay) {
            return 0;
        } else {
            return delay - elapsed;
        }
    }
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Rewards Pool
/// @notice RewardsPool accepts a single reward token and releases it to the
///         AssetPool over time in one week reward intervals. The owner of this
///         contract is the reward distribution address funding it with reward
///         tokens.
contract RewardsPool is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant DURATION = 7 days;

    IERC20 public immutable rewardToken;
    address public immutable assetPool;

    // timestamp of the current reward interval end or the timestamp of the
    // last interval end in case a new reward interval has not been allocated
    uint256 public intervalFinish = 0;
    // rate per second with which reward tokens are unlocked
    uint256 public rewardRate = 0;
    // amount of rewards accumulated and not yet withdrawn from the previous
    // reward interval(s)
    uint256 public rewardAccumulated = 0;
    // the last time information in this contract was updated
    uint256 public lastUpdateTime = 0;

    event RewardToppedUp(uint256 amount);
    event RewardWithdrawn(uint256 amount);

    constructor(
        IERC20 _rewardToken,
        address _assetPool,
        address owner
    ) {
        rewardToken = _rewardToken;
        // slither-disable-next-line missing-zero-check
        assetPool = _assetPool;
        transferOwnership(owner);
    }

    /// @notice Transfers the provided reward amount into RewardsPool and
    ///         creates a new, one-week reward interval starting from now.
    ///         Reward tokens from the previous reward interval that unlocked
    ///         over the time will be available for withdrawal immediately.
    ///         Reward tokens from the previous interval that has not been yet
    ///         unlocked, are added to the new interval being created.
    /// @dev This function can be called only by the owner given that it creates
    ///      a new interval with one week length, starting from now.
    function topUpReward(uint256 reward) external onlyOwner {
        rewardAccumulated = earned();

        /* solhint-disable not-rely-on-time */
        if (block.timestamp >= intervalFinish) {
            // see https://github.com/crytic/slither/issues/844
            // slither-disable-next-line divide-before-multiply
            rewardRate = reward / DURATION;
        } else {
            uint256 remaining = intervalFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / DURATION;
        }
        intervalFinish = block.timestamp + DURATION;
        lastUpdateTime = block.timestamp;
        /* solhint-enable avoid-low-level-calls */

        emit RewardToppedUp(reward);
        rewardToken.safeTransferFrom(msg.sender, address(this), reward);
    }

    /// @notice Withdraws all unlocked reward tokens to the AssetPool.
    function withdraw() external {
        uint256 amount = earned();
        rewardAccumulated = 0;
        lastUpdateTime = lastTimeRewardApplicable();
        emit RewardWithdrawn(amount);
        rewardToken.safeTransfer(assetPool, amount);
    }

    /// @notice Returns the amount of earned and not yet withdrawn reward
    /// tokens.
    function earned() public view returns (uint256) {
        return
            rewardAccumulated +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate);
    }

    /// @notice Returns the timestamp at which a reward was last time applicable.
    ///         When reward interval is pending, returns current block's
    ///         timestamp. If the last reward interval ended and no other reward
    ///         interval had been allocated, returns the last reward interval's
    ///         end timestamp.
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, intervalFinish);
    }
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

import "@thesis/solidity-contracts/contracts/token/ERC20WithPermit.sol";
import "@threshold-network/solidity-contracts/contracts/governance/Checkpoints.sol";

/// @title  UnderwriterToken
/// @notice Underwriter tokens represent an ownership share in the underlying
///         collateral of the asset-specific pool. Underwriter tokens are minted
///         when a user deposits ERC20 tokens into asset-specific pool and they
///         are burned when a user exits the position. Underwriter tokens
///         natively support meta transactions. Users can authorize a transfer
///         of their underwriter tokens with a signature conforming EIP712
///         standard instead of an on-chain transaction from their address.
///         Anyone can submit this signature on the user's behalf by calling the
///         permit function, as specified in EIP2612 standard, paying gas fees,
///         and possibly performing other actions in the same transaction.
contract UnderwriterToken is ERC20WithPermit, Checkpoints {
    /// @notice The EIP-712 typehash for the delegation struct used by
    ///         `delegateBySig`.
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256(
            "Delegation(address delegatee,uint256 nonce,uint256 deadline)"
        );

    constructor(string memory _name, string memory _symbol)
        ERC20WithPermit(_name, _symbol)
    {}

    /// @notice Delegates votes from signatory to `delegatee`
    /// @param delegatee The address to delegate votes to
    /// @param deadline The time at which to expire the signature
    /// @param v The recovery byte of the signature
    /// @param r Half of the ECDSA signature pair
    /// @param s Half of the ECDSA signature pair
    function delegateBySig(
        address signatory,
        address delegatee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        /* solhint-disable-next-line not-rely-on-time */
        require(deadline >= block.timestamp, "Delegation expired");

        // Validate `s` and `v` values for a malleability concern described in EIP2.
        // Only signatures with `s` value in the lower half of the secp256k1
        // curve's order and `v` value of 27 or 28 are considered valid.
        require(
            uint256(s) <=
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "Invalid signature 's' value"
        );
        require(v == 27 || v == 28, "Invalid signature 'v' value");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        DELEGATION_TYPEHASH,
                        delegatee,
                        nonce[signatory]++,
                        deadline
                    )
                )
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == signatory,
            "Invalid signature"
        );

        return delegate(signatory, delegatee);
    }

    /// @notice Delegate votes from `msg.sender` to `delegatee`.
    /// @param delegatee The address to delegate votes to
    function delegate(address delegatee) public virtual {
        return delegate(msg.sender, delegatee);
    }

    /// @notice Moves voting power when tokens are minted, burned or transferred.
    /// @dev Overrides the empty function from the parent contract.
    /// @param from The address that loses tokens and voting power
    /// @param to The address that gains tokens and voting power
    /// @param amount The amount of tokens and voting power that is transferred
    // slither-disable-next-line dead-code
    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint96 safeAmount = SafeCast.toUint96(amount);

        // When minting:
        if (from == address(0)) {
            // Does not allow to mint more than uint96 can fit. Otherwise, the
            // Checkpoint might not fit the balance.
            require(
                totalSupply + amount <= maxSupply(),
                "Maximum total supply exceeded"
            );
            writeCheckpoint(_totalSupplyCheckpoints, add, safeAmount);
        }

        // When burning:
        if (to == address(0)) {
            writeCheckpoint(_totalSupplyCheckpoints, subtract, safeAmount);
        }

        moveVotingPower(delegates(from), delegates(to), safeAmount);
    }

    /// @notice Delegate votes from `delegator` to `delegatee`.
    /// @param delegator The address to delegate votes from
    /// @param delegatee The address to delegate votes to
    function delegate(address delegator, address delegatee) internal override {
        address currentDelegate = delegates(delegator);
        uint96 delegatorBalance = SafeCast.toUint96(balanceOf[delegator]);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

/// @title Asset Pool interface
/// @notice Asset Pool accepts a single ERC20 token as collateral, and returns
///         an underwriter token. For example, an asset pool might accept deposits
///         in KEEP in return for covKEEP underwriter tokens. Underwriter tokens
///         represent an ownership share in the underlying collateral of the
///         Asset Pool.
interface IAssetPool {
    /// @notice Accepts the given amount of collateral token as a deposit and
    ///         mints underwriter tokens representing pool's ownership.
    /// @dev Before calling this function, collateral token needs to have the
    ///      required amount accepted to transfer to the asset pool.
    /// @return The amount of minted underwriter tokens
    function deposit(uint256 amount) external returns (uint256);

    /// @notice Accepts the given amount of collateral token as a deposit and
    ///         mints at least a minAmountToMint underwriter tokens representing
    ///         pool's ownership.
    /// @dev Before calling this function, collateral token needs to have the
    ///      required amount accepted to transfer to the asset pool.
    /// @return The amount of minted underwriter tokens
    function depositWithMin(uint256 amountToDeposit, uint256 minAmountToMint)
        external
        returns (uint256);

    /// @notice Initiates the withdrawal of collateral and rewards from the pool.
    /// @dev Before calling this function, underwriter token needs to have the
    ///      required amount accepted to transfer to the asset pool.
    function initiateWithdrawal(uint256 covAmount) external;

    /// @notice Completes the previously initiated withdrawal for the
    ///         underwriter.
    /// @return The amount of collateral withdrawn
    function completeWithdrawal(address underwriter) external returns (uint256);
}

// ▓▓▌ ▓▓ ▐▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▌▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓    ▓▓▓▓▓▓▓▀    ▐▓▓▓▓▓▓    ▐▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▄▄▓▓▓▓▓▓▓▀      ▐▓▓▓▓▓▓▄▄▄▄         ▓▓▓▓▓▓▄▄▄▄         ▐▓▓▓▓▓▌   ▐▓▓▓▓▓▓
//   ▓▓▓▓▓▓▓▓▓▓▓▓▓▀        ▐▓▓▓▓▓▓▓▓▓▓         ▓▓▓▓▓▓▓▓▓▓         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//   ▓▓▓▓▓▓▀▀▓▓▓▓▓▓▄       ▐▓▓▓▓▓▓▀▀▀▀         ▓▓▓▓▓▓▀▀▀▀         ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
//   ▓▓▓▓▓▓   ▀▓▓▓▓▓▓▄     ▐▓▓▓▓▓▓     ▓▓▓▓▓   ▓▓▓▓▓▓     ▓▓▓▓▓   ▐▓▓▓▓▓▌
// ▓▓▓▓▓▓▓▓▓▓ █▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
// ▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓ ▐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓
//
//                           Trust math, not hardware.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

/// @title Asset Pool upgrade interface
/// @notice Interface that has to be implemented by an Asset Pool accepting
///         upgrades from another asset pool.
interface IAssetPoolUpgrade {
    /// @notice Accepts the given underwriter with collateral tokens amount as a
    ///         deposit. In exchange new underwriter tokens will be calculated,
    ///         minted and then transferred back to the underwriter.
    function depositFor(address underwriter, uint256 amount) external;
}