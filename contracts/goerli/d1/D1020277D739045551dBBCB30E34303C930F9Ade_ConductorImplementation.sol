// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../utils/Address.sol";
import "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallSecure(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        address oldImplementation = _getImplementation();

        // Initial upgrade and setup call
        _setImplementation(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }

        // Perform rollback test if not already in progress
        StorageSlot.BooleanSlot storage rollbackTesting = StorageSlot.getBooleanSlot(_ROLLBACK_SLOT);
        if (!rollbackTesting.value) {
            // Trigger rollback using upgradeTo from the new implementation
            rollbackTesting.value = true;
            Address.functionDelegateCall(
                newImplementation,
                abi.encodeWithSignature("upgradeTo(address)", oldImplementation)
            );
            rollbackTesting.value = false;
            // Check rollback was effective
            require(oldImplementation == _getImplementation(), "ERC1967Upgrade: upgrade breaks further upgrades");
            // Finally reset to the new implementation and log the upgrade
            _upgradeTo(newImplementation);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT

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
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
}

// contracts/Conductor.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../../libraries/external/BytesLib.sol";

import "./ConductorGetters.sol";
import "./ConductorSetters.sol";
import "./ConductorStructs.sol";
import "./ConductorGovernance.sol";

import "../shared/ICCOStructs.sol";

/** 
 * @title A cross-chain token sale conductor
 * @notice This contract manages cross-chain token sales. It uses the wormhole 
 * core messaging layer to communicate token sale information to linked Contributor 
 * contracts. For successful sales, it uses the wormhole token bridge to 
 * send the sale token to Contributor contracts in exchange for contributed funds. 
 * For unsuccessful sales, this contract will return the sale tokens to a 
 * specified recipient address.
 */ 
contract Conductor is ConductorGovernance, ConductorEvents, ReentrancyGuard {
    /// @dev create dynamic storage for accepted solana tokens
    ICCOStructs.SolanaToken[] solanaAcceptedTokens;

    /**
     * @dev receiveSaleToken serves to take custody of the sale token and 
     * returns information about the token on the Conductor chain.
     * - it transfers the sale tokens to this contract
     * - it finds the address of the token on the Conductor chain
     * - it finds the ERC20 token decimals of the token on the Conductor chain
     */
    function receiveSaleToken(
        ICCOStructs.Raise memory raise
    ) public returns (address, uint8) {
        /// @dev grab the local token address (address of sale token on conductor chain)
        address localTokenAddress;
        if (raise.tokenChain == chainId()) {
            localTokenAddress = address(uint160(uint256(raise.token)));
        } else {
            /// identify wormhole token bridge wrapper
            localTokenAddress = tokenBridge().wrappedAsset(raise.tokenChain, raise.token);  
            require(localTokenAddress != address(0), "wrapped address not found on this chain"); 
        }

        /** 
         * @dev Fetch the sale token decimals on this chain.
         * The Contributors need to know this to scale allocations on non-evm chains.            
         */ 
        (,bytes memory queriedDecimals) = localTokenAddress.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        uint8 localTokenDecimals = abi.decode(queriedDecimals, (uint8));

        /// query own token balance before transfer
        (,bytes memory queriedBalanceBefore) = localTokenAddress.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, 
            address(this))
        );
        uint256 balanceBefore = abi.decode(queriedBalanceBefore, (uint256));

        /// deposit sale tokens
        SafeERC20.safeTransferFrom(
            IERC20(localTokenAddress), 
            msg.sender, 
            address(this), 
            raise.tokenAmount
        );

        /// query own token balance after transfer
        (,bytes memory queriedBalanceAfter) = localTokenAddress.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, 
            address(this))
        );
        uint256 balanceAfter = abi.decode(queriedBalanceAfter, (uint256));

        /// revert if token has fee
        require(raise.tokenAmount == balanceAfter - balanceBefore, "fee-on-transfer tokens are not supported");

        return (localTokenAddress, localTokenDecimals);
    }

    /**
     * @dev createSale serves to initialize a cross-chain token sale and disseminate 
     * information about the sale to registered Contributor contracts.
     * - it validates sale parameters passed in by the client
     * - it saves a copy of the sale in contract storage
     * - it encodes and disseminates sale information to Contributor contracts via wormhole
     */
    function createSale(
        ICCOStructs.Raise memory raise,
        ICCOStructs.Token[] memory acceptedTokens   
    ) public payable nonReentrant returns (
        uint256 saleId,
        uint256 wormholeSequence,
        uint256 wormholeSequence2
    ) {
        /// validate sale parameters from client
        require(block.timestamp < raise.saleStart, "sale start must be in the future");
        require(raise.saleStart < raise.saleEnd, "sale end must be after sale start");
        require(raise.unlockTimestamp >= raise.saleEnd, "unlock timestamp should be >= saleEnd");
        /// set timestamp cap for non-evm Contributor contracts
        require(raise.saleStart <= 2**63-1, "saleStart too far in the future");
        require(raise.tokenAmount > 0, "amount must be > 0");
        require(acceptedTokens.length > 0, "must accept at least one token");
        require(acceptedTokens.length < 255, "too many tokens");
        require(raise.maxRaise >= raise.minRaise, "maxRaise must be >= minRaise");

        /// @dev take custody of sale token and fetch decimal/address info for the sale token
        (address localTokenAddress, uint8 localTokenDecimals) = receiveSaleToken(raise);
        
        /// create Sale struct for Conductor's view of the sale
        saleId = useSaleId();
        ConductorStructs.Sale memory sale = ConductorStructs.Sale({
            saleID : saleId,
            /// client sale parameters
            tokenAddress : raise.token,
            tokenChain : raise.tokenChain,
            localTokenDecimals: localTokenDecimals,
            localTokenAddress: localTokenAddress,    
            solanaTokenAccount: raise.solanaTokenAccount,
            tokenAmount : raise.tokenAmount,
            minRaise: raise.minRaise,
            maxRaise: raise.maxRaise,
            saleStart : raise.saleStart,
            saleEnd : raise.saleEnd,
            unlockTimestamp : raise.unlockTimestamp,
            /// save accepted token info
            acceptedTokensChains : new uint16[](acceptedTokens.length),
            acceptedTokensAddresses : new bytes32[](acceptedTokens.length),
            acceptedTokensConversionRates : new uint128[](acceptedTokens.length),
            solanaAcceptedTokensCount: 0,
            contributions : new uint256[](acceptedTokens.length),
            contributionsCollected : new bool[](acceptedTokens.length),
            /// sale wallet management 
            initiator : msg.sender, 
            recipient : bytes32(uint256(uint160(raise.recipient))),
            refundRecipient : bytes32(uint256(uint160(raise.refundRecipient))),
            /// public key of kyc authority 
            authority: raise.authority,
            /// sale identifiers
            isSealed :  false,
            isAborted : false,
            isFixedPrice : raise.isFixedPrice
        });

        /// populate the accepted token arrays
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            require(acceptedTokens[i].conversionRate > 0, "conversion rate cannot be zero");
            sale.acceptedTokensChains[i] = acceptedTokens[i].tokenChain;
            sale.acceptedTokensAddresses[i] = acceptedTokens[i].tokenAddress;
            sale.acceptedTokensConversionRates[i] = acceptedTokens[i].conversionRate;

            /// store the accepted tokens for the SolanaSaleInit VAA
            if (acceptedTokens[i].tokenChain == 1) {
                ICCOStructs.SolanaToken memory solanaToken = ICCOStructs.SolanaToken({
                    tokenIndex: uint8(i),
                    tokenAddress: acceptedTokens[i].tokenAddress
                });
                /// only allow 8 accepted tokens for the Solana Contributor
                require(solanaAcceptedTokens.length < 8, "too many solana tokens");
                /// save in contract storage
                solanaAcceptedTokens.push(solanaToken);
            }
        }

        /// save number of accepted solana tokens in the sale
        sale.solanaAcceptedTokensCount = uint8(solanaAcceptedTokens.length);

        /// store sale info
        setSale(saleId, sale);

        /// cache wormhole instance
        IWormhole wormhole = wormhole();
        uint256 messageFee = wormhole.messageFee();

        /// create SaleInit struct to disseminate to Contributors
        ICCOStructs.SaleInit memory saleInit = ICCOStructs.SaleInit({
            payloadID : 1,
            /// sale ID
            saleID : saleId,
            /// address of the token, left-zero-padded if shorter than 32 bytes
            tokenAddress : raise.token,
            /// chain ID of the token
            tokenChain : raise.tokenChain,
            /// token decimals
            tokenDecimals: localTokenDecimals,
            /// timestamp raise start
            saleStart : raise.saleStart,
            /// timestamp raise end
            saleEnd : raise.saleEnd,
            /// accepted Tokens
            acceptedTokens : acceptedTokens,
            /// recipient of proceeds
            recipient : bytes32(uint256(uint160(raise.recipient))),
            /// public key of kyc authority 
            authority : raise.authority,
            /// lock timestamp (when tokens can be claimed)
            unlockTimestamp : raise.unlockTimestamp
        }); 

        /// @dev send encoded SaleInit struct to Contributors via wormhole.        
        wormholeSequence = wormhole.publishMessage{
            value : messageFee
        }(0, ICCOStructs.encodeSaleInit(saleInit), consistencyLevel());

        /// see if the sale accepts any Solana tokens
        if (solanaAcceptedTokens.length > 0) {
            /// create SolanaSaleInit struct to disseminate to the Solana Contributor
            ICCOStructs.SolanaSaleInit memory solanaSaleInit = ICCOStructs.SolanaSaleInit({
                payloadID : 5,
                /// sale ID
                saleID : saleId,
                /// sale token ATA for solana 
                solanaTokenAccount: raise.solanaTokenAccount,
                /// chain ID of the token
                tokenChain : raise.tokenChain,
                /// token decimals
                tokenDecimals: localTokenDecimals,
                /// timestamp raise start
                saleStart : raise.saleStart,
                /// timestamp raise end
                saleEnd : raise.saleEnd,
                /// accepted Tokens
                acceptedTokens : solanaAcceptedTokens,
                /// recipient of proceeds
                recipient : bytes32(uint256(uint160(raise.recipient))),
                /// public key of kyc authority 
                authority: raise.authority,
                /// lock timestamp (when tokens can be claimed)
                unlockTimestamp : raise.unlockTimestamp
            });

            /// @dev send encoded SolanaSaleInit struct to the solana Contributor
            wormholeSequence2 = wormhole.publishMessage{
                value : messageFee
            }(0, ICCOStructs.encodeSolanaSaleInit(solanaSaleInit), consistencyLevel());    

            /// @dev garbage collection to save on gas fees
            delete solanaAcceptedTokens;
        }

        /// emit EventCreateSale event.
        emit EventCreateSale(saleInit.saleID, msg.sender);
    }

    /**
     * @dev abortSaleBeforeStartTime serves to allow the sale initiator to 
     * cancel the sale before the saleStart time.
     * - it confirms that the sale has not started
     * - it only allows the sale initiator to invoke the method
     * - it encodes and disseminates a saleAborted message to the Contributor contracts
     * - it refunds the sale tokens to the refundRecipient
     */    
    function abortSaleBeforeStartTime(uint256 saleId) public payable returns (uint256 wormholeSequence) {
        require(saleExists(saleId), "sale not initiated");

        ConductorStructs.Sale memory sale = sales(saleId);

        /// confirm that caller is the sale initiator
        require(sale.initiator == msg.sender, "only initiator can abort the sale early");

        /// make sure that the sale is still valid and hasn't started yet
        require(!sale.isSealed && !sale.isAborted, "already sealed / aborted");
        require(block.timestamp < sale.saleStart, "sale cannot be aborted once it has started");

        /// set saleAborted
        setSaleAborted(sale.saleID);   

        /// @dev send encoded SaleAborted struct to Contributor contracts
        IWormhole wormhole = wormhole();
        wormholeSequence = wormhole.publishMessage{
            value : msg.value
        }(0, ICCOStructs.encodeSaleAborted(ICCOStructs.SaleAborted({
            payloadID : 4,
            saleID : saleId
        })), consistencyLevel());

        /// @dev refund the sale tokens to refund recipient
        SafeERC20.safeTransfer(
            IERC20(sale.localTokenAddress), 
            address(uint160(uint256(sale.refundRecipient))), 
            sale.tokenAmount 
        );

        /// emit EventAbortSaleBeforeStart event.
        emit EventAbortSaleBeforeStart(saleId);
    }

    /**
     * @dev collectContribution serves to accept contribution information
     * disseminated by each registered Contributor contract.
     */ 
    function collectContribution(bytes memory encodedVm) public {
        /// validate encodedVm and emitter
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(encodedVm);

        require(valid, reason);
        require(verifyContributorVM(vm), "invalid emitter");

        /// parse the ContributionsSealed struct emitted by a Contributor contract
        ICCOStructs.ContributionsSealed memory conSealed = ICCOStructs.parseContributionsSealed(vm.payload);

        require(conSealed.chainID == vm.emitterChainId, "contribution from wrong chain id");

        /// make sure the sale has ended before accepting contribution information
        ConductorStructs.Sale memory sale = sales(conSealed.saleID);

        require(!sale.isAborted, "sale was aborted");
        require(block.timestamp > sale.saleEnd, "sale has not ended yet");

        /// confirm that contribution information is valid and that it hasn't been collected for this Contributor
        require(conSealed.contributions.length > 0, "no contributions");
        require(!saleContributionIsCollected(
            conSealed.saleID, conSealed.contributions[0].tokenIndex), 
            "already collected contribution"
        );

        /// save the total contribution amount for each accepted token 
        for (uint256 i = 0; i < conSealed.contributions.length; i++) {
            setSaleContribution(
                conSealed.saleID,
                conSealed.contributions[i].tokenIndex,
                conSealed.contributions[i].contributed
            );
        }
    } 

    /**
     * @dev sealSale serves to determine if a sale was successful or not. 
     * - it calculates the total amount raised in the sale
     * - it determines if the sale was a success by comparing the total to minRaise
     * - it calculates allocations and excess contributions for each accepted token
     * - it disseminates a saleSealed or saleAborted message to Contributors via wormhole
     */
    function sealSale(uint256 saleId) public payable returns (uint256 wormholeSequence, uint256 wormholeSequence2) {
        require(saleExists(saleId), "sale not initiated");

        ConductorStructs.Sale memory sale = sales(saleId);

        /// make sure the sale hasn't been aborted or sealed already
        require(!sale.isSealed && !sale.isAborted, "already sealed / aborted");

        ConductorStructs.InternalAccounting memory accounting;        

        for (uint256 i = 0; i < sale.contributionsCollected.length; i++) {
            require(saleContributionIsCollected(saleId, i), "missing contribution info");
            /**
             * @dev This calculates the total contribution for each accepted token.
             * - it uses the conversion rate to convert contributions into the minRaise denomination
             */
            accounting.totalContribution += sale.contributions[i] * sale.acceptedTokensConversionRates[i] / 1e18;
        }

        IWormhole wormhole = wormhole();

        /// check to see if the sale was successful
        if (accounting.totalContribution >= sale.minRaise) {
            ITokenBridge tknBridge = tokenBridge();

            /// set the messageFee and valueSent values 
            accounting.messageFee = wormhole.messageFee();
            accounting.valueSent = msg.value;   

            /**
             * @dev This determines if contributors (or the sale initiator) qualify for refund payments.
             * - the default value for accounting.excessContribution is zero
             * - if totalContribution > maxRaise, the difference between maxRaise and totalContribution 
             * is the total reward due to contributors
             * - if the totalContribution < maxRaise or the isFixedPrice flag is set to true, 
             * the saleRecipient will receive a partial refund of the sale token
             */

            accounting.adjustedSaleTokenAmount = sale.tokenAmount; 
            if (accounting.totalContribution > sale.maxRaise) {
                accounting.totalExcessContribution = accounting.totalContribution - sale.maxRaise;
            } else if (sale.isFixedPrice) {
                accounting.adjustedSaleTokenAmount = sale.tokenAmount * accounting.totalContribution / sale.maxRaise;
            }

            /// @dev This is a successful sale struct that saves sale token allocation information
            ICCOStructs.SaleSealed memory saleSealed = ICCOStructs.SaleSealed({
                payloadID : 3,
                saleID : saleId,
                allocations : new ICCOStructs.Allocation[](sale.acceptedTokensAddresses.length)
            });

            /// calculate allocations and excessContributions for each accepted token 
            for (uint256 i = 0; i < sale.acceptedTokensAddresses.length; i++) {
                uint256 allocation = accounting.adjustedSaleTokenAmount * (sale.contributions[i] * sale.acceptedTokensConversionRates[i] / 1e18) / accounting.totalContribution;
                uint256 excessContribution = accounting.totalExcessContribution * sale.contributions[i] / accounting.totalContribution;

                if (allocation > 0) {
                    /// send allocations to Contributor contracts
                    if (sale.acceptedTokensChains[i] == chainId()) {
                        /// simple transfer on same chain
                        /// @dev use saleID from sale struct to bypass stack too deep
                        SafeERC20.safeTransfer(
                            IERC20(sale.localTokenAddress), 
                            address(uint160(uint256(contributorWallets(sale.saleID, sale.acceptedTokensChains[i])))),
                            allocation
                        );
                    } else {
                        /// adjust allocation for dust after token bridge transfer
                        allocation = ICCOStructs.deNormalizeAmount(
                            ICCOStructs.normalizeAmount(allocation, sale.localTokenDecimals), 
                            sale.localTokenDecimals
                        );

                        /// transfer over wormhole token bridge to foreign Contributor contract
                        SafeERC20.safeApprove(
                            IERC20(sale.localTokenAddress), 
                            address(tknBridge), 
                            allocation
                        );

                        require(accounting.valueSent >= accounting.messageFee, "insufficient wormhole messaging fees");
                        accounting.valueSent -= accounting.messageFee;

                        tknBridge.transferTokens{
                            value : accounting.messageFee
                        }(
                            sale.localTokenAddress,
                            allocation,
                            sale.acceptedTokensChains[i],
                            contributorWallets(sale.saleID, sale.acceptedTokensChains[i]),
                            0,
                            0
                        );
                    }
                    accounting.totalAllocated += allocation;
                }

                /// allocation information that is encoded in the SaleSealed struct
                saleSealed.allocations[i] = ICCOStructs.Allocation({
                    tokenIndex : uint8(i),
                    allocation : allocation,
                    excessContribution : excessContribution
                });
            }

            /// @dev transfer dust partial refund (if applicable) back to refund recipient
            accounting.saleTokenRefund = sale.tokenAmount - accounting.totalAllocated;

            if (accounting.saleTokenRefund > 0) {
                SafeERC20.safeTransfer(
                    IERC20(sale.localTokenAddress), 
                    address(uint160(uint256(sale.refundRecipient))), 
                    accounting.saleTokenRefund
                );
            }

            require(accounting.valueSent >= accounting.messageFee, "insufficient wormhole messaging fees");
            accounting.valueSent -= accounting.messageFee;

            /// set saleSealed
            setSaleSealed(saleId);

            /// @dev send encoded SaleSealed message to Contributor contracts
            wormholeSequence = wormhole.publishMessage{
                value : accounting.messageFee
            }(0, ICCOStructs.encodeSaleSealed(saleSealed), consistencyLevel()); 

            { /// scope to make code more readable
                /// @dev send separate SaleSealed VAA if accepting Solana tokens
                if (sale.solanaAcceptedTokensCount > 0) {
                    // make sure we still have enough gas to send the Solana message  
                    require(accounting.valueSent >= accounting.messageFee, "insufficient wormhole messaging fees");

                    /// create new array to handle solana allocations 
                    ICCOStructs.Allocation[] memory solanaAllocations = new ICCOStructs.Allocation[](sale.solanaAcceptedTokensCount);

                    /// remove non-solana allocations in SaleSealed VAA
                    uint8 solanaAllocationIndex;
                    for (uint256 i = 0; i < sale.acceptedTokensAddresses.length; i++) {
                        if (sale.acceptedTokensChains[i] == 1) {
                            solanaAllocations[solanaAllocationIndex] = saleSealed.allocations[i];
                            solanaAllocationIndex += 1;
                        }
                    }
                    /// @dev replace allocations in the saleSealed struct with Solana only allocations
                    saleSealed.allocations = solanaAllocations;

                    /// @dev send encoded SaleSealed message to Solana Contributor
                    wormholeSequence2 = wormhole.publishMessage{
                        value : accounting.messageFee
                    }(0, ICCOStructs.encodeSaleSealed(saleSealed), consistencyLevel());
                }
            }

            /// emit EventSealSale event.
            emit EventSealSale(saleId); 
        } else {
            /// set saleAborted
            setSaleAborted(sale.saleID);

            /// @dev send encoded SaleAborted message to Contributor contracts
            wormholeSequence = wormhole.publishMessage{
                value : msg.value
            }(0, ICCOStructs.encodeSaleAborted(ICCOStructs.SaleAborted({
                payloadID : 4,
                saleID : saleId
            })), consistencyLevel());

            /// @dev refund the sale tokens to refund recipient
            SafeERC20.safeTransfer(
                IERC20(sale.localTokenAddress), 
                address(uint160(uint256(sale.refundRecipient))), 
                sale.tokenAmount 
            );

            /// emit EventAbortSale event.
            emit EventAbortSale(saleId);
        }
    } 
 
    /// @dev useSaleId serves to update the current saleId in the Conductor state
    function useSaleId() internal returns(uint256 saleId) {
        saleId = getNextSaleId();
        setNextSaleId(saleId + 1);
    }

    /// @dev verifyContributorVM serves to validate VMs by checking against known Contributor contracts    
    function verifyContributorVM(IWormhole.VM memory vm) internal view returns (bool){
        if (contributorContracts(vm.emitterChainId) == vm.emitterAddress) {
            return true;
        }

        return false;
    }

    /// @dev saleExists serves to check if a sale exists
    function saleExists(uint256 saleId) public view returns (bool exists) {
        exists = (saleId < getNextSaleId());
    }
}

// contracts/Getters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/IWormhole.sol";
import "../../interfaces/ITokenBridge.sol";

import "./ConductorState.sol";

contract ConductorGetters is ConductorState {
    function owner() public view returns (address) {
        return _state.owner;
    } 

    function isInitialized(address impl) public view returns (bool) {
        return _state.initializedImplementations[impl];
    }

    function wormhole() public view returns (IWormhole) {
        return IWormhole(_state.provider.wormhole);
    }

    function tokenBridge() public view returns (ITokenBridge) {
        return ITokenBridge(payable(_state.provider.tokenBridge));
    }

    function chainId() public view returns (uint16){
        return _state.provider.chainId;
    }

    function consistencyLevel() public view returns (uint8) {
        return _state.consistencyLevel;
    }

    function contributorContracts(uint16 chainId_) public view returns (bytes32) {
        return _state.contributorImplementations[chainId_];
    }

    function solanaWallet(uint256 saleId_) public view returns (bytes32) {
        return _state.sales[saleId_].solanaTokenAccount;
    }

    function contributorWallets(uint256 saleId_, uint16 chainId_) public view returns (bytes32) {
        /// @dev Solana chainID == 1
        if (chainId_ == 1) {
            return solanaWallet(saleId_); 
        } else {
            return contributorContracts(chainId_);
        }
    }

    function sales(uint256 saleId_) public view returns (ConductorStructs.Sale memory sale) {
        return _state.sales[saleId_];
    }

    function getNextSaleId() public view returns (uint256) {
        return _state.nextSaleId;
    }

    function saleContributionIsCollected(uint256 saleId_, uint256 tokenIndex) public view returns (bool) {
        return _state.sales[saleId_].contributionsCollected[tokenIndex];
    }

    function saleContributions(uint256 saleId_) public view returns (uint256[] memory) {
        return _state.sales[saleId_].contributions;
    }
}

// contracts/Conductor.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

import "../../libraries/external/BytesLib.sol";

import "./ConductorGetters.sol";
import "./ConductorSetters.sol";
import "./ConductorStructs.sol";

import "../../interfaces/IWormhole.sol";

contract ConductorGovernance is ConductorGetters, ConductorSetters, ERC1967Upgrade {
    event ContractUpgraded(address indexed oldContract, address indexed newContract);
    event ConsistencyLevelUpdated(uint8 indexed oldLevel, uint8 indexed newLevel);
    event OwnershipTransfered(address indexed oldOwner, address indexed newOwner);

    /// @dev registerChain serves to save Contributor contract addresses in Conductor state
    function registerChain(uint16 contributorChainId, bytes32 contributorAddress) public onlyOwner {
        require(contributorContracts(contributorChainId) == bytes32(0), "chain already registered");
        setContributor(contributorChainId, contributorAddress);
    }   

    /// @dev upgrade serves to upgrade contract implementations
    function upgrade(uint16 conductorChainId, address newImplementation) public onlyOwner {
        require(conductorChainId == chainId(), "wrong chain id");

        address currentImplementation = _getImplementation();

        _upgradeTo(newImplementation);

        /// @dev call initialize function of the new implementation
        (bool success, bytes memory reason) = newImplementation.delegatecall(abi.encodeWithSignature("initialize()"));

        require(success, string(reason));

        emit ContractUpgraded(currentImplementation, newImplementation);
    }

    /// @dev updateConsisencyLevel serves to change the wormhole messaging consistencyLevel
    function updateConsistencyLevel(uint16 conductorChainId, uint8 newConsistencyLevel) public onlyOwner {
        require(conductorChainId == chainId(), "wrong chain id");
        require(newConsistencyLevel > 0, "newConsistencyLevel must be > 0");

        uint8 currentConsistencyLevel = consistencyLevel();

        setConsistencyLevel(newConsistencyLevel);    

        emit ConsistencyLevelUpdated(currentConsistencyLevel, newConsistencyLevel);
    }

    /// @dev transferOwnership serves to change the ownership of the Conductor contract
    function transferOwnership(uint16 conductorChainId, address newOwner) public onlyOwner {
        require(conductorChainId == chainId(), "wrong chain id"); 
        require(newOwner != address(0), "new owner cannot be the zero address");

        address currentOwner = owner();
        
        setOwner(newOwner);

        emit OwnershipTransfered(currentOwner, newOwner);
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "caller is not the owner");
        _;
    }
}

// contracts/Implementation.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

import "./Conductor.sol";


contract ConductorImplementation is Conductor {
    function initialize() initializer public virtual {
        /// @dev this function needs to be exposed for an upgrade to pass
    }

    modifier initializer() {
        address impl = ERC1967Upgrade._getImplementation();

        require(
            !isInitialized(impl),
            "already initialized"
        );

        setInitialized(impl);

        _;
    }
}

// contracts/Setters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./ConductorState.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract ConductorSetters is ConductorState, Context {
    function setOwner(address owner_) internal {
        _state.owner = owner_;
    }

    function setContributor(uint16 chainId, bytes32 emitter) internal {
        _state.contributorImplementations[chainId] = emitter;
    }

    function setInitialized(address implementatiom) internal {
        _state.initializedImplementations[implementatiom] = true;
    }

    function setChainId(uint16 chainId) internal {
        _state.provider.chainId = chainId;
    }

    function setWormhole(address wh) internal {
        _state.provider.wormhole = payable(wh);
    }

    function setTokenBridge(address tb) internal {
        _state.provider.tokenBridge = payable(tb);
    }

    function setConsistencyLevel(uint8 level) internal {
        _state.consistencyLevel = level;
    }

    function setSale(uint256 saleId, ConductorStructs.Sale memory sale) internal {
        _state.sales[saleId] = sale;
    }

    function setSaleContribution(uint256 saleId, uint256 tokenIndex, uint256 contribution) internal {
        _state.sales[saleId].contributions[tokenIndex] = contribution;
        _state.sales[saleId].contributionsCollected[tokenIndex] = true;
    }

    function setSaleSealed(uint256 saleId) internal {
        _state.sales[saleId].isSealed = true;
    }

    function setSaleAborted(uint256 saleId) internal {
        _state.sales[saleId].isAborted = true;
    }

    function setNextSaleId(uint256 nextSaleId) internal {
        _state.nextSaleId = nextSaleId;
    }
}

// contracts/State.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./ConductorStructs.sol";

contract ConductorEvents {
    event EventCreateSale (
        uint256 saleId,
        address creatorAddress
    );

    event EventAbortSaleBeforeStart (
        uint256 saleId
    );

    event EventSealSale (
        uint256 saleId
    );

    event EventAbortSale (
        uint256 saleId
    );
}

contract ConductorStorage {
    struct Provider {
        uint16 chainId;
        address payable wormhole;
        address tokenBridge;
    }

    struct State {
        Provider provider;

        /// contract deployer
        address owner;
        
        /// number of confirmations for wormhole messages
        uint8 consistencyLevel; 

        /// mapping of initialized implementations
        mapping(address => bool) initializedImplementations;

        /// mapping of Conductor contracts on other chains
        mapping(uint16 => bytes32) contributorImplementations;

        /// mapping of Sales
        mapping(uint256 => ConductorStructs.Sale) sales;

        /// next sale id
        uint256 nextSaleId;
    }
}

contract ConductorState {
    ConductorStorage.State _state;
}

// contracts/Structs.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

contract ConductorStructs {
    struct Sale {
        /// sale ID
        uint256 saleID;
        /// native address of the token - left-zero-padded if shorter than 32 bytes
        bytes32 tokenAddress;
        /// native chain ID of the token
        uint16 tokenChain;
        /// decimals of token on conductor chain
        uint8 localTokenDecimals;
        /// address of token on conductor chain
        address localTokenAddress;
        /// sale token ATA for Solana
        bytes32 solanaTokenAccount;
        /// token amount being sold
        uint256 tokenAmount;
        /// min raise amount
        uint256 minRaise;
        /// max raise amount
        uint256 maxRaise;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// lock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;
        /// accepted Tokens
        uint16[] acceptedTokensChains;
        bytes32[] acceptedTokensAddresses;
        uint128[] acceptedTokensConversionRates;
        uint8 solanaAcceptedTokensCount;
        /// contributions
        uint256[] contributions;
        bool[] contributionsCollected;
        /// sale initiator - can abort the sale before saleStart
        address initiator;
        /// recipient of proceeds
        bytes32 recipient;
        /// refund recipient in case the sale is aborted
        bytes32 refundRecipient;
        /// public key of kyc authority 
        address authority;
        bool isSealed;
        bool isAborted;
        bool isFixedPrice;
    }

    struct InternalAccounting {
        /// fees
        uint256 messageFee;
        uint256 valueSent;
        /// token allocation
        uint256 totalContribution;
        uint256 totalAllocated;
        uint256 adjustedSaleTokenAmount;
        uint256 saleTokenRefund; 
        uint256 totalExcessContribution;
    }
}

// contracts/Structs.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "../../libraries/external/BytesLib.sol";

library ICCOStructs {
    using BytesLib for bytes;

    struct Token {
        uint16 tokenChain;
        bytes32 tokenAddress;
        uint128 conversionRate;
    }

    struct SolanaToken {
        uint8 tokenIndex;
        bytes32 tokenAddress;
    }

    struct Contribution {
        /// index in acceptedTokens array
        uint8 tokenIndex;
        uint256 contributed;
    }

    struct Allocation {
        /// index in acceptedTokens array
        uint8 tokenIndex;
        /// amount of sold tokens allocated to contributors on this chain
        uint256 allocation;
        /// excess contributions refunded to contributors on this chain
        uint256 excessContribution;
    }

    struct Raise {
        /// fixed-price sale boolean
        bool isFixedPrice;
        /// sale token address
        bytes32 token;
        /// sale token chainId
        uint16 tokenChain;
        /// token amount being sold
        uint256 tokenAmount;
        /// min raise amount
        uint256 minRaise;
        /// max token amount
        uint256 maxRaise;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// unlock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;
        /// recipient of proceeds
        address recipient;
        /// refund recipient in cse the sale is aborted
        address refundRecipient;
        /// sale token ATA for Solana
        bytes32 solanaTokenAccount;
        /// public key of kyc authority 
        address authority; 
    }

    struct SaleInit {
        /// payloadID uint8 = 1
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// address of the token - left-zero-padded if shorter than 32 bytes
        bytes32 tokenAddress;
        /// chain ID of the token
        uint16 tokenChain;
        /// token decimals 
        uint8 tokenDecimals;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// accepted Tokens
        Token[] acceptedTokens;
        /// recipient of proceeds
        bytes32 recipient;
        /// public key of kyc authority 
        address authority;
        /// unlock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;
    }

    struct SolanaSaleInit {
        /// payloadID uint8 = 5
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// sale token ATA for solana
        bytes32 solanaTokenAccount;
        /// chain ID of the token
        uint16 tokenChain;
        /// token decimals 
        uint8 tokenDecimals;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// accepted Tokens
        SolanaToken[] acceptedTokens;  
        /// recipient of proceeds
        bytes32 recipient;
        /// public key of kyc authority 
        address authority;
        /// unlock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;
    }

    struct ContributionsSealed {
        /// payloadID uint8 = 2
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// chain ID
        uint16 chainID;
        /// sealed contributions for this sale
        Contribution[] contributions;
    }

    struct SaleSealed {
        /// payloadID uint8 = 3
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// allocations
        Allocation[] allocations;
    }

    struct SaleAborted {
        /// payloadID uint8 = 4
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
    }

    function normalizeAmount(uint256 amount, uint8 decimals) public pure returns(uint256){
        if (decimals > 8) {
            amount /= 10 ** (decimals - 8);
        }
        return amount;
    }

    function deNormalizeAmount(uint256 amount, uint8 decimals) public pure returns(uint256){
        if (decimals > 8) {
            amount *= 10 ** (decimals - 8);
        }
        return amount;
    }

    function encodeSaleInit(SaleInit memory saleInit) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(1),
            saleInit.saleID,
            saleInit.tokenAddress,
            saleInit.tokenChain,
            saleInit.tokenDecimals,
            saleInit.saleStart,
            saleInit.saleEnd,
            encodeTokens(saleInit.acceptedTokens),
            saleInit.recipient,
            saleInit.authority,
            saleInit.unlockTimestamp
        );
    }

    function encodeSolanaSaleInit(SolanaSaleInit memory solanaSaleInit) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(5),
            solanaSaleInit.saleID,
            solanaSaleInit.solanaTokenAccount,
            solanaSaleInit.tokenChain,
            solanaSaleInit.tokenDecimals,
            solanaSaleInit.saleStart,
            solanaSaleInit.saleEnd,
            encodeSolanaTokens(solanaSaleInit.acceptedTokens),
            solanaSaleInit.recipient,
            solanaSaleInit.authority,
            solanaSaleInit.unlockTimestamp
        );
    }

    function parseSaleInit(bytes memory encoded) public pure returns (SaleInit memory saleInit) {
        uint256 index = 0;

        saleInit.payloadID = encoded.toUint8(index);
        index += 1;

        require(saleInit.payloadID == 1, "invalid payloadID");

        saleInit.saleID = encoded.toUint256(index);
        index += 32;

        saleInit.tokenAddress = encoded.toBytes32(index);
        index += 32;

        saleInit.tokenChain = encoded.toUint16(index);
        index += 2;

        saleInit.tokenDecimals = encoded.toUint8(index);
        index += 1;

        saleInit.saleStart = encoded.toUint256(index);
        index += 32;

        saleInit.saleEnd = encoded.toUint256(index);
        index += 32;

        uint256 len = 1 + 50 * uint256(uint8(encoded[index]));
        saleInit.acceptedTokens = parseTokens(encoded.slice(index, len));
        index += len;

        saleInit.recipient = encoded.toBytes32(index);
        index += 32;

        saleInit.authority = encoded.toAddress(index);
        index += 20;

        saleInit.unlockTimestamp = encoded.toUint256(index);
        index += 32;

        require(encoded.length == index, "invalid SaleInit");
    }

    function encodeTokens(Token[] memory tokens) public pure returns (bytes memory encoded) {
        encoded = abi.encodePacked(uint8(tokens.length));
        for (uint256 i = 0; i < tokens.length; i++) {
            encoded = abi.encodePacked(
                encoded,
                tokens[i].tokenAddress,
                tokens[i].tokenChain,
                tokens[i].conversionRate
            );
        }
    }

    function encodeSolanaTokens(SolanaToken[] memory tokens) public pure returns (bytes memory encoded) {
        encoded = abi.encodePacked(uint8(tokens.length));
        for (uint256 i = 0; i < tokens.length; i++) {
            encoded = abi.encodePacked(
                encoded,
                tokens[i].tokenIndex,
                tokens[i].tokenAddress
            );
        }
    }

    function parseTokens(bytes memory encoded) public pure returns (Token[] memory tokens) {
        require(encoded.length % 50 == 1, "invalid Token[]");

        uint8 len = uint8(encoded[0]);

        tokens = new Token[](len);

        for (uint256 i = 0; i < len; i++) {
            tokens[i].tokenAddress   = encoded.toBytes32( 1 + i * 50);
            tokens[i].tokenChain     = encoded.toUint16( 33 + i * 50);
            tokens[i].conversionRate = encoded.toUint128(35 + i * 50);
        }
    }

    function encodeContributionsSealed(ContributionsSealed memory cs) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(2),
            cs.saleID,
            cs.chainID,
            encodeContributions(cs.contributions)
        );
    }

    function parseContributionsSealed(bytes memory encoded) public pure returns (ContributionsSealed memory consSealed) {
        uint256 index = 0;

        consSealed.payloadID = encoded.toUint8(index);
        index += 1;

        require(consSealed.payloadID == 2, "invalid payloadID");

        consSealed.saleID = encoded.toUint256(index);
        index += 32;

        consSealed.chainID = encoded.toUint16(index);
        index += 2;

        uint256 len = 1 + 33 * uint256(uint8(encoded[index]));
        consSealed.contributions = parseContributions(encoded.slice(index, len));
        index += len;

        require(encoded.length == index, "invalid ContributionsSealed");
    }

    function encodeContributions(Contribution[] memory contributions) public pure returns (bytes memory encoded) {
        encoded = abi.encodePacked(uint8(contributions.length));
        for (uint256 i = 0; i < contributions.length; i++) {
            encoded = abi.encodePacked(
                encoded,
                contributions[i].tokenIndex,
                contributions[i].contributed
            );
        }
    }

    function parseContributions(bytes memory encoded) public pure returns (Contribution[] memory cons) {
        require(encoded.length % 33 == 1, "invalid Contribution[]");

        uint8 len = uint8(encoded[0]);

        cons = new Contribution[](len);

        for (uint256 i = 0; i < len; i++) {
            cons[i].tokenIndex  = encoded.toUint8(1 + i * 33);
            cons[i].contributed = encoded.toUint256(2 + i * 33);
        }
    }

    function encodeSaleSealed(SaleSealed memory ss) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(3),
            ss.saleID,
            encodeAllocations(ss.allocations)
        );
    }

    function parseSaleSealed(bytes memory encoded) public pure returns (SaleSealed memory ss) {
        uint256 index = 0;
        ss.payloadID = encoded.toUint8(index);
        index += 1;

        require(ss.payloadID == 3, "invalid payloadID");

        ss.saleID = encoded.toUint256(index);
        index += 32;

        uint256 len = 1 + 65 * uint256(uint8(encoded[index]));
        ss.allocations = parseAllocations(encoded.slice(index, len));
        index += len;

        require(encoded.length == index, "invalid SaleSealed");
    }

    function encodeAllocations(Allocation[] memory allocations) public pure returns (bytes memory encoded) {
        encoded = abi.encodePacked(uint8(allocations.length));
        for (uint256 i = 0; i < allocations.length; i++) {
            encoded = abi.encodePacked(
                encoded,
                allocations[i].tokenIndex,
                allocations[i].allocation,
                allocations[i].excessContribution
            );
        }
    }

    function parseAllocations(bytes memory encoded) public pure returns (Allocation[] memory allos) {
        require(encoded.length % 65 == 1, "invalid Allocation[]");

        uint8 len = uint8(encoded[0]);

        allos = new Allocation[](len);

        for (uint256 i = 0; i < len; i++) {
            allos[i].tokenIndex = encoded.toUint8(1 + i * 65);
            allos[i].allocation = encoded.toUint256(2 + i * 65);
            allos[i].excessContribution = encoded.toUint256(34 + i * 65);
        }
    }

    function encodeSaleAborted(SaleAborted memory ca) public pure returns (bytes memory encoded) {
        return abi.encodePacked(uint8(4), ca.saleID);
    }

    function parseSaleAborted(bytes memory encoded) public pure returns (SaleAborted memory sa) {
        uint256 index = 0;
        sa.payloadID = encoded.toUint8(index);
        index += 1;

        require(sa.payloadID == 4, "invalid payloadID");

        sa.saleID = encoded.toUint256(index);
        index += 32;

        require(encoded.length == index, "invalid SaleAborted");
    }
}

// contracts/Bridge.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;


interface ITokenBridge {
    function transferTokens(address token, uint256 amount, uint16 recipientChain, bytes32 recipient, uint256 arbiterFee, uint32 nonce) external payable returns (uint64 sequence);

    function wrappedAsset(uint16 tokenChainId, bytes32 tokenAddress) external view returns (address);
}

// contracts/Messages.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

interface IWormhole {
    struct Provider {
		uint16 chainId;
		uint16 governanceChainId;
		bytes32 governanceContract;
	}

	struct GuardianSet {
		address[] keys;
		uint32 expirationTime;
	}

	struct Signature {
		bytes32 r;
		bytes32 s;
		uint8 v;
		uint8 guardianIndex;
	}

	struct VM {
		uint8 version;
		uint32 timestamp;
		uint32 nonce;
		uint16 emitterChainId;
		bytes32 emitterAddress;
		uint64 sequence;
		uint8 consistencyLevel;
		bytes payload;

		uint32 guardianSetIndex;
		Signature[] signatures;

		bytes32 hash;
	}

    event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel);

    function publishMessage(
        uint32 nonce,
        bytes memory payload,
        uint8 consistencyLevel
    ) external payable returns (uint64 sequence);

    function parseAndVerifyVM(bytes calldata encodedVM) external view returns (VM memory vm, bool valid, string memory reason);

    function verifyVM(VM memory vm) external view returns (bool valid, string memory reason);

    function verifySignatures(bytes32 hash, Signature[] memory signatures, GuardianSet memory guardianSet) external pure returns (bool valid, string memory reason) ;

    function parseVM(bytes memory encodedVM) external pure returns (VM memory vm);

    function getGuardianSet(uint32 index) external view returns (GuardianSet memory) ;

    function getCurrentGuardianSetIndex() external view returns (uint32) ;

    function getGuardianSetExpiry() external view returns (uint32) ;

    function governanceActionIsConsumed(bytes32 hash) external view returns (bool) ;

    function isInitialized(address impl) external view returns (bool) ;

    function chainId() external view returns (uint16) ;

    function governanceChainId() external view returns (uint16);

    function governanceContract() external view returns (bytes32);

    function messageFee() external view returns (uint256) ;
}

// SPDX-License-Identifier: Unlicense
/*
 * @title Solidity Bytes Arrays Utils
 * @author Gonçalo Sá <[email protected]>
 *
 * @dev Bytes tightly packed arrays utility library for ethereum contracts written in Solidity.
 *      The library lets you concatenate, slice and type cast bytes arrays both in memory and storage.
 */
pragma solidity >=0.8.0 <0.9.0;


library BytesLib {
    function concat(
        bytes memory _preBytes,
        bytes memory _postBytes
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory tempBytes;

        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(tempBytes, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, length)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                // Write the _preBytes data into the tempBytes memory 32 bytes
                // at a time.
                mstore(mc, mload(cc))
            }

            // Add the length of _postBytes to the current length of tempBytes
            // and store it as the new length in the first 32 bytes of the
            // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            // Move the memory counter back from a multiple of 0x20 to the
            // actual end of the _preBytes data.
            mc := end
            // Stop copying when the memory counter reaches the new combined
            // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            // Update the free-memory pointer by padding our last write location
            // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
            // next 32 byte block, then round down to the nearest multiple of
            // 32. If the sum of the length of the two arrays is zero then add
            // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(0x40, and(
              add(add(end, iszero(add(length, mload(_preBytes)))), 31),
              not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }

    function concatStorage(bytes storage _preBytes, bytes memory _postBytes) internal {
        assembly {
            // Read the first 32 bytes of _preBytes storage, which is the length
            // of the array. (We don't need to use the offset into the slot
            // because arrays use the entire slot.)
            let fslot := sload(_preBytes.slot)
            // Arrays of 31 bytes or less have an even value in their slot,
            // while longer arrays have an odd value. The actual length is
            // the slot divided by two for odd values, and the lowest order
            // byte divided by two for even values.
            // If the slot is even, bitwise and the slot with 255 and divide by
            // two to get the length. If the slot is odd, bitwise and the slot
            // with -1 and divide by two.
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)
            let newlength := add(slength, mlength)
            // slength can contain both the length and contents of the array
            // if length < 32 bytes so let's prepare for that
            // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
            switch add(lt(slength, 32), lt(newlength, 32))
            case 2 {
                // Since the new array still fits in the slot, we just need to
                // update the contents of the slot.
                // uint256(bytes_storage) = uint256(bytes_storage) + uint256(bytes_memory) + new_length
                sstore(
                    _preBytes.slot,
                    // all the modifications to the slot are inside this
                    // next block
                    add(
                        // we can just add to the slot contents because the
                        // bytes we want to change are the LSBs
                        fslot,
                        add(
                            mul(
                                div(
                                    // load the bytes from memory
                                    mload(add(_postBytes, 0x20)),
                                    // zero all bytes to the right
                                    exp(0x100, sub(32, mlength))
                                ),
                                // and now shift left the number of bytes to
                                // leave space for the length in the slot
                                exp(0x100, sub(32, newlength))
                            ),
                            // increase length by the double of the memory
                            // bytes length
                            mul(mlength, 2)
                        )
                    )
                )
            }
            case 1 {
                // The stored value fits in the slot, but the combined value
                // will exceed it.
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // The contents of the _postBytes array start 32 bytes into
                // the structure. Our first read should obtain the `submod`
                // bytes that can fit into the unused space in the last word
                // of the stored array. To get this, we read 32 bytes starting
                // from `submod`, so the data we read overlaps with the array
                // contents by `submod` bytes. Masking the lowest-order
                // `submod` bytes allows us to add that value directly to the
                // stored value.

                let submod := sub(32, slength)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(
                    sc,
                    add(
                        and(
                            fslot,
                            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00
                        ),
                        and(mload(mc), mask)
                    )
                )

                for {
                    mc := add(mc, 0x20)
                    sc := add(sc, 1)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
            default {
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                // Start copying to the last used word of the stored array.
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // Copy over the first `submod` bytes of the new data as in
                // case 1 above.
                let slengthmod := mod(slength, 32)
                let mlengthmod := mod(mlength, 32)
                let submod := sub(32, slengthmod)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(sc, add(sload(sc), and(mload(mc), mask)))

                for {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
        }
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    )
        internal
        pure
        returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
        require(_bytes.length >= _start + 1 , "toUint8_outOfBounds");
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    function toUint16(bytes memory _bytes, uint256 _start) internal pure returns (uint16) {
        require(_bytes.length >= _start + 2, "toUint16_outOfBounds");
        uint16 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }

        return tempUint;
    }

    function toUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32) {
        require(_bytes.length >= _start + 4, "toUint32_outOfBounds");
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function toUint64(bytes memory _bytes, uint256 _start) internal pure returns (uint64) {
        require(_bytes.length >= _start + 8, "toUint64_outOfBounds");
        uint64 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x8), _start))
        }

        return tempUint;
    }

    function toUint96(bytes memory _bytes, uint256 _start) internal pure returns (uint96) {
        require(_bytes.length >= _start + 12, "toUint96_outOfBounds");
        uint96 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0xc), _start))
        }

        return tempUint;
    }

    function toUint128(bytes memory _bytes, uint256 _start) internal pure returns (uint128) {
        require(_bytes.length >= _start + 16, "toUint128_outOfBounds");
        uint128 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x10), _start))
        }

        return tempUint;
    }

    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function toBytes32(bytes memory _bytes, uint256 _start) internal pure returns (bytes32) {
        require(_bytes.length >= _start + 32, "toBytes32_outOfBounds");
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bool) {
        bool success = true;

        assembly {
            let length := mload(_preBytes)

            // if lengths don't match the arrays are not equal
            switch eq(length, mload(_postBytes))
            case 1 {
                // cb is a circuit breaker in the for loop since there's
                //  no said feature for inline assembly loops
                // cb = 1 - don't breaker
                // cb = 0 - break
                let cb := 1

                let mc := add(_preBytes, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(_postBytes, 0x20)
                // the next line is the loop condition:
                // while(uint256(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                        // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }

    function equalStorage(
        bytes storage _preBytes,
        bytes memory _postBytes
    )
        internal
        view
        returns (bool)
    {
        bool success = true;

        assembly {
            // we know _preBytes_offset is 0
            let fslot := sload(_preBytes.slot)
            // Decode the length of the stored array like in concatStorage().
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)

            // if lengths don't match the arrays are not equal
            switch eq(slength, mlength)
            case 1 {
                // slength can contain both the length and contents of the array
                // if length < 32 bytes so let's prepare for that
                // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
                if iszero(iszero(slength)) {
                    switch lt(slength, 32)
                    case 1 {
                        // blank the last byte which is the length
                        fslot := mul(div(fslot, 0x100), 0x100)

                        if iszero(eq(fslot, mload(add(_postBytes, 0x20)))) {
                            // unsuccess:
                            success := 0
                        }
                    }
                    default {
                        // cb is a circuit breaker in the for loop since there's
                        //  no said feature for inline assembly loops
                        // cb = 1 - don't breaker
                        // cb = 0 - break
                        let cb := 1

                        // get the keccak hash to get the contents of the array
                        mstore(0x0, _preBytes.slot)
                        let sc := keccak256(0x0, 0x20)

                        let mc := add(_postBytes, 0x20)
                        let end := add(mc, mlength)

                        // the next line is the loop condition:
                        // while(uint256(mc < end) + cb == 2)
                        for {} eq(add(lt(mc, end), cb), 2) {
                            sc := add(sc, 1)
                            mc := add(mc, 0x20)
                        } {
                            if iszero(eq(sload(sc), mload(mc))) {
                                // unsuccess:
                                success := 0
                                cb := 0
                            }
                        }
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }
}