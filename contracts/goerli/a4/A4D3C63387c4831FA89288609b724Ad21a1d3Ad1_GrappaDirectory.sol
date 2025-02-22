// SPDX-License-Identifier: MIT
// solhint-disable no-inline-assembly
pragma solidity >=0.6.9;

import "./interfaces/IERC2771Recipient.sol";

/**
 * @title The ERC-2771 Recipient Base Abstract Class - Implementation
 *
 * @notice Note that this contract was called `BaseRelayRecipient` in the previous revision of the GSN.
 *
 * @notice A base contract to be inherited by any contract that want to receive relayed transactions.
 *
 * @notice A subclass must use `_msgSender()` instead of `msg.sender`.
 */
abstract contract ERC2771Recipient is IERC2771Recipient {

    /*
     * Forwarder singleton we accept calls from
     */
    address private _trustedForwarder;

    /**
     * :warning: **Warning** :warning: The Forwarder can have a full control over your Recipient. Only trust verified Forwarder.
     * @notice Method is not a required method to allow Recipients to trust multiple Forwarders. Not recommended yet.
     * @return forwarder The address of the Forwarder contract that is being used.
     */
    function getTrustedForwarder() public virtual view returns (address forwarder){
        return _trustedForwarder;
    }

    function _setTrustedForwarder(address _forwarder) internal {
        _trustedForwarder = _forwarder;
    }

    /// @inheritdoc IERC2771Recipient
    function isTrustedForwarder(address forwarder) public virtual override view returns(bool) {
        return forwarder == _trustedForwarder;
    }

    /// @inheritdoc IERC2771Recipient
    function _msgSender() internal override virtual view returns (address ret) {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            ret = msg.sender;
        }
    }

    /// @inheritdoc IERC2771Recipient
    function _msgData() internal override virtual view returns (bytes calldata ret) {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            return msg.data[0:msg.data.length-20];
        } else {
            return msg.data;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

/**
 * @title The ERC-2771 Recipient Base Abstract Class - Declarations
 *
 * @notice A contract must implement this interface in order to support relayed transaction.
 *
 * @notice It is recommended that your contract inherits from the ERC2771Recipient contract.
 */
abstract contract IERC2771Recipient {

    /**
     * :warning: **Warning** :warning: The Forwarder can have a full control over your Recipient. Only trust verified Forwarder.
     * @param forwarder The address of the Forwarder contract that is being used.
     * @return isTrustedForwarder `true` if the Forwarder is trusted to forward relayed transactions by this Recipient.
     */
    function isTrustedForwarder(address forwarder) public virtual view returns(bool);

    /**
     * @notice Use this method the contract anywhere instead of msg.sender to support relayed transactions.
     * @return sender The real sender of this call.
     * For a call that came through the Forwarder the real sender is extracted from the last 20 bytes of the `msg.data`.
     * Otherwise simply returns `msg.sender`.
     */
    function _msgSender() internal virtual view returns (address);

    /**
     * @notice Use this method in the contract instead of `msg.data` when difference matters (hashing, signature, etc.)
     * @return data The real `msg.data` of this call.
     * For a call that came through the Forwarder, the real sender address was appended as the last 20 bytes
     * of the `msg.data` - so this method will strip those 20 bytes off.
     * Otherwise (if the call was made directly and not through the forwarder) simply returns `msg.data`.
     */
    function _msgData() internal virtual view returns (bytes calldata);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

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
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

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
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../interfaces/draft-IERC1822.sol";
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
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
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
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822.sol";
import "../ERC1967/ERC1967Upgrade.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable, ERC1967Upgrade {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
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

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
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

pragma solidity ^0.8.0;

import {Poseidon5} from './lib/Hash.sol';

import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import './lib/SparseMerkleTreeWithHistory.sol';
import './verifiers/LoadTokensVerifier.sol';
import './verifiers/SendMsgVerifier.sol';
import './verifiers/AckMsgVerifier.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './verifiers/ExtractTokensVerifier.sol';
import './interfaces/IGrappaDirectory.sol';
import './GrappaUserPriceCalculator.sol';
import './GrappaToken.sol';
import './interfaces/IGrappaRewardDistributionModel.sol';
import './storage/GrappaDirectoryStorage.sol';
import '@opengsn/contracts/src/ERC2771Recipient.sol';


contract GrappaDirectory is
    IGrappaDirectory,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC2771Recipient,
    GrappaDirectoryStorage
{
    using SparseMerkleTreeWithHistory for SparseTreeWithHistoryData;
    event IDUpdated(uint256 indexed key, uint256 value);

    modifier onlyController() {
        require(msg.sender == _controller, 'GDE1');
        _;
    }

    function initialize(
        address __trustedForwarder,
        uint256 __userInitialPrice,
        DataTypes.TreeParams calldata idTreeParams,
        DataTypes.UserKeys calldata keys
    ) public initializer {
        __Ownable_init();
        _setTrustedForwarder(__trustedForwarder);
        SparseMerkleTreeWithHistory.init(
            _idTree,
            idTreeParams.depth,
            0,
            idTreeParams.historySize
        );

        _nextUserId = 1000;
        _userInitialPrice = __userInitialPrice;
        _enroll(
            msg.sender,
            1,
            keys.metaPublicKey,
            keys.tokenPublicKey,
            keys.msgPublicKey,
            keys.balancePublicKey
        );
    }

    function setController(address controller) external onlyOwner {
        require(_controller == address(0), 'GDE0'); // can only be set once
        _controller = controller;
    }

    function verifyAuthorizedUserAndGetId(
        address sender
    ) external view returns (uint32) {
        return _verifyAuthorizedUserAndGetId(sender);
    }

    function enroll(
        DataTypes.BasePoint calldata metaPublicKey,
        DataTypes.BasePoint calldata tokenPublicKey,
        DataTypes.BasePoint calldata msgPublicKey,
        DataTypes.BasePoint calldata balancePublicKey
    ) external returns (uint32) {
        address sender = _msgSender();
        require(_blacklist[sender] == false, 'GDE2'); // GDE2: User is blacklisted
        require(_walletUserId[sender] == 0, 'GDE4'); // GDE4: User is already registered
        require(
            !isEmptyKey(metaPublicKey) &&
                !isEmptyKey(tokenPublicKey) &&
                !isEmptyKey(msgPublicKey) &&
                !isEmptyKey(balancePublicKey),
            'GCE03'
        ); // GCE03: Invalid public keys
        uint32 newUserId = _nextUserId;
        _enroll(
            sender,
            newUserId,
            metaPublicKey,
            tokenPublicKey,
            msgPublicKey,
            balancePublicKey
        );
        _nextUserId++;
        return newUserId;
    }

    function updateUserData(
        uint32 userId,
        address userAddress,
        DataTypes.UserData memory userData
    ) external onlyController {
        _usersData[userId] = userData;
        _updateIDTree(
            userId,
            userAddress,
            userData.metaPublicKey.x,
            userData.tokenPublicKey.x,
            userData.price,
            userData.lastUpdateBlock
        );
    }

    function updateKeys(
        DataTypes.BasePoint calldata metaPublicKey,
        DataTypes.BasePoint calldata tokenPublicKey,
        DataTypes.BasePoint calldata msgPublicKey
    ) external {
        address sender = _msgSender();
        uint32 userId = _verifyAuthorizedUserAndGetId(sender);
        require(
            !isEmptyKey(metaPublicKey) &&
                !isEmptyKey(tokenPublicKey) &&
                !isEmptyKey(msgPublicKey),
            'GCE03'
        ); // GCE03: Invalid public keys
        DataTypes.UserData storage currentUserData = _usersData[userId];
        _updateIDTree(
            userId,
            sender,
            metaPublicKey.x,
            tokenPublicKey.x,
            currentUserData.price,
            block.number
        );
        currentUserData.lastUpdateBlock = block.number;
        currentUserData.metaPublicKey = metaPublicKey;
        currentUserData.tokenPublicKey = tokenPublicKey;
        currentUserData.msgPublicKey = msgPublicKey;
    }

    function setUserInitialPrice(
        uint256 __userInitialPrice
    ) external onlyOwner {
        _userInitialPrice = __userInitialPrice;
    }

    function getIDTreeRoot() external view returns (uint256) {
        return _idTree.getLastRoot();
    }

    function getUserIdAndData(
        address userAddress
    ) external view returns (DataTypes.UserIdAndData memory) {
        uint32 userId = _verifyAuthorizedUserAndGetId(userAddress);
        return DataTypes.UserIdAndData(userId, _usersData[userId]);
    }

    function isKnownIDTreeRoot(uint256 root) external view returns (bool) {
        return _idTree.isKnownRoot(root);
    }

    function usersData(
        uint32 userId
    ) external view returns (DataTypes.UserData memory) {
        return _usersData[userId];
    }

    function walletUserId(address wallet) external view returns (uint32) {
        return _walletUserId[wallet];
    }

    function blacklist(address user) external view returns (bool) {
        return _blacklist[user];
    }

    function nextUserId() external view returns (uint32) {
        return _nextUserId;
    }

    function userInitialPrice() external view returns (uint256) {
        return _userInitialPrice;
    }

    function setBlacklist(
        address _address,
        bool isBlacklisted
    ) external onlyOwner {
        _blacklist[_address] = isBlacklisted;
    }

    function setTrustedForwarder(address _forwarder) external onlyOwner {
        _setTrustedForwarder(_forwarder);
    }

    function _updateIDTree(
        uint32 userId,
        address userAddress,
        uint256 metaPublicKeyX,
        uint256 tokenPublicKeyX,
        uint256 price,
        uint256 updateBlock
    ) internal {
        uint256 _value = Poseidon5.poseidon(
            [
                uint160(userAddress),
                metaPublicKeyX,
                tokenPublicKeyX,
                price,
                updateBlock
            ]
        );
        _idTree.update(userId, _value);
        emit IDUpdated(userId, _value);
    }

    function _verifyAuthorizedUserAndGetId(
        address sender
    ) internal view returns (uint32) {
        require(_blacklist[sender] == false, 'GDE2'); // GDE2: User is blacklisted
        require(_walletUserId[sender] != 0, 'GDE3'); // GDE3: User is not registered
        return _walletUserId[sender];
    }

    function _enroll(
        address sender,
        uint32 newUserId,
        DataTypes.BasePoint calldata metaPublicKey,
        DataTypes.BasePoint calldata tokenPublicKey,
        DataTypes.BasePoint calldata msgPublicKey,
        DataTypes.BasePoint calldata balancePublicKey
    ) internal {
        _walletUserId[sender] = newUserId;
        DataTypes.UserData memory userData = DataTypes.UserData(
            metaPublicKey,
            tokenPublicKey,
            msgPublicKey,
            balancePublicKey,
            _userInitialPrice,
            block.number
        );
        _usersData[newUserId] = userData;
        _updateIDTree(
            newUserId,
            sender,
            metaPublicKey.x,
            tokenPublicKey.x,
            _userInitialPrice,
            block.number
        );
    }

    function isEmptyKey(
        DataTypes.BasePoint calldata key
    ) internal pure returns (bool) {
        return key.x == 0 && key.y == 0;
    }

    /// @inheritdoc IERC2771Recipient
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771Recipient)
        returns (address ret)
    {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            ret = msg.sender;
        }
    }

    /// @inheritdoc IERC2771Recipient
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771Recipient)
        returns (bytes calldata ret)
    {
        if (
            msg.data.length >= 20 &&
            getTrustedForwarder() != address(0) &&
            isTrustedForwarder(msg.sender)
        ) {
            return msg.data[0:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract GrappaToken is ERC20, Ownable {
    constructor() ERC20('GrappaToken', 'GRP') {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IGrappaUserPriceCalculator.sol';

contract GrappaUserPriceCalculator is Ownable, IGrappaUserPriceCalculator {
    uint8 public c1;
    uint8 public c2;
    uint32 public stepSize;

    constructor(uint8 _c1, uint8 _c2, uint32 _stepSize) Ownable() {
        c1 = _c1;
        c2 = _c2;
        stepSize = _stepSize;
    }

    function calcNewPrice(
        uint256 currentPrice,
        uint256 lastUpdateBlock,
        uint256 priceIncrease
    ) external view returns (uint256) {
        uint256 blockPassed = (block.number - lastUpdateBlock) / stepSize;
        uint256 newPrice = currentPrice;
        for (; blockPassed > 0; blockPassed--) {
            newPrice = (currentPrice * c1) / c2;
        }
        newPrice += priceIncrease;
        return newPrice;
    }

    function setParams(
        uint8 _c1,
        uint8 _c2,
        uint32 _stepSize
    ) public onlyOwner {
        c1 = _c1;
        c2 = _c2;
        stepSize = _stepSize;
    }

    function getPriceCalcParams() external view returns (uint8, uint8, uint32) {
        return (c1, c2, stepSize);
    }
}

/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import '../lib/DataTypes.sol';

interface IGrappaDirectory {
    function usersData(
        uint32 userId
    ) external view returns (DataTypes.UserData memory);

    function walletUserId(address wallet) external view returns (uint32);

    function blacklist(address user) external view returns (bool);

    function nextUserId() external view returns (uint32);

    function userInitialPrice() external view returns (uint256);

    function verifyAuthorizedUserAndGetId(
        address sender
    ) external view returns (uint32);

    function enroll(
        DataTypes.BasePoint calldata metaPublicKey,
        DataTypes.BasePoint calldata tokenPublicKey,
        DataTypes.BasePoint calldata msgPublicKey,
        DataTypes.BasePoint calldata balancePublicKey
    ) external returns (uint32);

    function updateUserData(
        uint32 userId,
        address userAddress,
        DataTypes.UserData calldata userData
    ) external;

    function updateKeys(
        DataTypes.BasePoint calldata metaPublicKey,
        DataTypes.BasePoint calldata tokenPublicKey,
        DataTypes.BasePoint calldata msgPublicKey
    ) external;

    function isKnownIDTreeRoot(uint256 root) external view returns (bool);

    function getIDTreeRoot() external view returns (uint256);

    function getUserIdAndData(
        address userAddress
    ) external view returns (DataTypes.UserIdAndData memory);

    function setBlacklist(address _address, bool isBlacklisted) external;

    function setTrustedForwarder(address _forwarder) external;
}

pragma solidity ^0.8.0;
import '../lib/DataTypes.sol';

interface IGrappaRewardDistributionModel {
    function calcIssuersReward(
        address recipient,
        uint256 totalAmount
    ) external view returns (DataTypes.UserReward[] memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGrappaUserPriceCalculator  {
    
    
    function calcNewPrice(
        uint256 currentPrice,
        uint256 lastUpdateBlock,
        uint256 priceIncrease
    ) external view returns (uint256);
}

pragma solidity ^0.8.0;

library DataTypes {
    struct UserReward {
        uint32 userId;
        uint256 reward;
    }
    struct TreeParams {
        uint256 depth;
        uint8 historySize;
    }
    struct BasePoint {
        uint256 x;
        uint256 y;
    }
    struct UserKeys {
        BasePoint metaPublicKey;
        BasePoint tokenPublicKey;
        BasePoint msgPublicKey;
        BasePoint balancePublicKey;
    }

    struct UserData {
        BasePoint metaPublicKey;
        BasePoint tokenPublicKey;
        BasePoint msgPublicKey;
        BasePoint balancePublicKey;
        uint256 price;
        uint256 lastUpdateBlock;
    }
    struct UserBalanceInfo {
        bool initialized;
        uint256 balanceEncXl;
        uint256 balanceEncXr;
        BasePoint balanceRandomKey;
        uint256 balanceHash;
    }
    struct UserIdAndData {
        uint32 userId;
        UserData userData;
    }
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }
    struct ControllerVerifiers {
        address sendMsgVerifier;
        address ackMsgVerifier;
    }
    struct TokenSystemVerifiers {
        address loadTokensVerifier;
        address extractTokensVerifier;
    }
    struct RewardDist {
        uint256 userPortion; // between 0 and 10000000000
        uint256 burnPortion; // between 0 and 10000000000
    }

    enum AckMsgInputs {
        nullifierHashOut,
        priceIncreaseCalc,
        newRandomPublicKey_x,
        newRandomPublicKey_y,
        newBalanceEnc_xL,
        newBalanceEnc_xR,
        newBalanceHash,
        contractShare,
        addressTo,
        commitRoot,
        ackBlockHeight,
        oldBalanceEnc_xL,
        oldBalanceEnc_xR,
        oldBalanceHash,
        oldRandomPublicKey_x,
        oldRandomPublicKey_y,
        userID,
        pubkeyBalance_x,
        pubkeyBalance_y,
        isNewUser,
        userPortion
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Poseidon2 {
    function poseidon(uint256[2] memory) public pure returns (uint256) {}
}

library Poseidon3 {
    function poseidon(uint256[3] memory) public pure returns (uint256) {}
}

library Poseidon4 {
    function poseidon(uint256[4] memory) public pure returns (uint256) {}
}

library Poseidon5 {
    function poseidon(uint256[5] memory) public pure returns (uint256) {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Poseidon2} from './Hash.sol';

struct IncrementalSparseTreeData {
    uint256 depth;
    uint256 nextIndex;
    uint256 currentRootIndex;
    mapping(uint256 => uint256) roots;
    uint8 rootHistorySize;
    // depth to zero node
    mapping(uint256 => uint256) zeroes;
    // depth to index to leaf
    mapping(uint256 => mapping(uint256 => uint256)) leaves;
}

library IncrementalSparseMerkleTree {
    uint8 public constant MAX_DEPTH = 255;
    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function init(
        IncrementalSparseTreeData storage self,
        uint256 depth,
        uint256 _zero,
        uint8 _rootHistorySize
    ) public {
        require(_zero < SNARK_SCALAR_FIELD);
        require(depth > 0 && depth <= MAX_DEPTH);
        require(_rootHistorySize > 0 && _rootHistorySize <= 32);

        self.currentRootIndex = 0;
        self.rootHistorySize = _rootHistorySize;

        self.nextIndex = 0;
        self.depth = depth;
        self.zeroes[0] = _zero;

        for (uint8 i = 1; i < depth; i++) {
            self.zeroes[i] = Poseidon2.poseidon(
                [self.zeroes[i - 1], self.zeroes[i - 1]]
            );
        }
        self.nextIndex = 0;
        self.roots[0] = Poseidon2.poseidon(
            [self.zeroes[depth - 1], self.zeroes[depth - 1]]
        );
    }

    function insert(
        IncrementalSparseTreeData storage self,
        uint256 leaf
    ) public returns (uint256) {
        uint256 depth = self.depth;
        require(leaf < SNARK_SCALAR_FIELD, 'field too big');

        uint256 lastLeftElement;
        uint256 lastRightElement;

        uint256 _nextIndex = self.nextIndex;
        require(
            _nextIndex != uint256(2) ** self.depth,
            'Merkle tree is full. No more leaves can be added'
        );
        uint256 currentIndex = _nextIndex;
        uint256 hash = leaf;

        for (uint8 i = 0; i < depth; ) {
            self.leaves[i][currentIndex] = hash;
            if (currentIndex & 1 == 0) {
                uint256 siblingLeaf = self.leaves[i][currentIndex + 1];
                if (siblingLeaf == 0) siblingLeaf = self.zeroes[i];
                lastLeftElement = hash;
                lastRightElement = siblingLeaf;
            } else {
                uint256 siblingLeaf = self.leaves[i][currentIndex - 1];
                if (siblingLeaf == 0) siblingLeaf = self.zeroes[i];
                lastLeftElement = siblingLeaf;
                lastRightElement = hash;
            }

            hash = Poseidon2.poseidon([lastLeftElement, lastRightElement]);
            currentIndex >>= 1;

            unchecked {
                i++;
            }
        }
        uint256 newRootIndex = (self.currentRootIndex + 1) %
            self.rootHistorySize;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = hash;
        self.nextIndex = _nextIndex + 1;
        return _nextIndex;
    }

    function isKnownRoot(
        IncrementalSparseTreeData storage self,
        uint256 _root
    ) public view returns (bool) {
        if (_root == 0) {
            return false;
        }
        uint256 _currentRootIndex = self.currentRootIndex;
        uint256 i = _currentRootIndex;
        do {
            if (_root == self.roots[i]) {
                return true;
            }
            if (i == 0) {
                i = self.rootHistorySize;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    /**
        @dev Returns the last root
    */
    function getLastRoot(
        IncrementalSparseTreeData storage self
    ) public view returns (uint256) {
        return self.roots[self.currentRootIndex];
    }

    function validate(
        IncrementalSparseTreeData storage self,
        uint256[] memory proofs,
        uint256 index,
        uint256 leaf,
        uint256 expectedRoot
    ) public view returns (bool) {
        return (compute(self, proofs, index, leaf) == expectedRoot);
    }

    function compute(
        IncrementalSparseTreeData storage self,
        uint256[] memory proofs,
        uint256 index,
        uint256 leaf
    ) internal view returns (uint256) {
        uint256 depth = self.depth;
        require(index < 2 ** depth);
        require(proofs.length == depth, 'Invalid _proofs length');
        uint256 computedHash = leaf;
        for (uint256 d = 0; d < depth; d++) {
            if (d > 0) {
                if (index & 1 == 0) {
                    //left
                    computedHash = Poseidon2.poseidon(
                        [computedHash, proofs[d]]
                    );
                } else {
                    //right
                    computedHash = Poseidon2.poseidon(
                        [proofs[d], computedHash]
                    );
                }
            }
            index >>= 1;
        }
        return computedHash;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Poseidon2} from './Hash.sol';
struct SparseTreeWithHistoryData {
    uint256 depth;
    uint8 rootHistorySize;
    mapping(uint256 => uint256) roots;
    uint256 currentRootIndex;
    // depth to zero node
    mapping(uint256 => uint256) zeroes;
    // depth to index to leaf
    mapping(uint256 => mapping(uint256 => uint256)) leaves;
}

library SparseMerkleTreeWithHistory {
    uint8 public constant MAX_DEPTH = 255;
    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function init(
        SparseTreeWithHistoryData storage self,
        uint256 depth,
        uint256 _zero,
        uint8 _rootHistorySize
    ) public {
        require(_zero < SNARK_SCALAR_FIELD);
        require(depth > 0 && depth <= MAX_DEPTH);
        require(_rootHistorySize > 0 && _rootHistorySize <= 32);
        self.depth = depth;
        self.rootHistorySize = _rootHistorySize;
        self.zeroes[0] = _zero;
        for (uint8 i = 1; i < depth; i++) {
            self.zeroes[i] = Poseidon2.poseidon(
                [self.zeroes[i - 1], self.zeroes[i - 1]]
            );
        }
        self.roots[0] = Poseidon2.poseidon(
            [self.zeroes[depth - 1], self.zeroes[depth - 1]]
        );
    }

    function update(
        SparseTreeWithHistoryData storage self,
        uint256 index,
        uint256 leaf
    ) public {
        uint256 depth = self.depth;
        require(leaf < SNARK_SCALAR_FIELD, 'field too big');
        require(index < 2 ** depth, 'index too big');
        uint256 hash = leaf;
        uint256 lastLeftElement;
        uint256 lastRightElement;

        for (uint8 i = 0; i < depth; ) {
            self.leaves[i][index] = hash;
            if (index & 1 == 0) {
                uint256 siblingLeaf = self.leaves[i][index + 1];
                if (siblingLeaf == 0) siblingLeaf = self.zeroes[i];
                lastLeftElement = hash;
                lastRightElement = siblingLeaf;
            } else {
                uint256 siblingLeaf = self.leaves[i][index - 1];
                if (siblingLeaf == 0) siblingLeaf = self.zeroes[i];
                lastLeftElement = siblingLeaf;
                lastRightElement = hash;
            }

            hash = Poseidon2.poseidon([lastLeftElement, lastRightElement]);
            index >>= 1;

            unchecked {
                i++;
            }
        }
        uint256 newRootIndex = (self.currentRootIndex + 1) %
            self.rootHistorySize;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = hash;
    }

    function isKnownRoot(
        SparseTreeWithHistoryData storage self,
        uint256 _root
    ) public view returns (bool) {
        if (_root == 0) {
            return false;
        }
        uint256 _currentRootIndex = self.currentRootIndex;
        uint256 i = _currentRootIndex;
        do {
            if (_root == self.roots[i]) {
                return true;
            }
            if (i == 0) {
                i = self.rootHistorySize;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    /**
        @dev Returns the last root
    */
    function getLastRoot(
        SparseTreeWithHistoryData storage self
    ) public view returns (uint256) {
        return self.roots[self.currentRootIndex];
    }

    function generateProof(
        SparseTreeWithHistoryData storage self,
        uint256 index
    ) public view returns (uint256[] memory) {
        require(index < 2 ** self.depth);
        uint256[] memory proof = new uint256[](self.depth);
        for (uint8 i = 0; i < self.depth; ) {
            if (index & 1 == 0) {
                uint256 siblingLeaf = self.leaves[i][index + 1];
                if (siblingLeaf == 0) siblingLeaf = self.zeroes[i];
                proof[i] = siblingLeaf;
            } else {
                uint256 siblingLeaf = self.leaves[i][index - 1];
                if (siblingLeaf == 0) siblingLeaf = self.zeroes[i];
                proof[i] = siblingLeaf;
            }
            index >>= 1;
            unchecked {
                i++;
            }
        }
        return proof;
    }

    function computeRoot(
        SparseTreeWithHistoryData storage self,
        uint256 index,
        uint256 leaf
    ) public view returns (uint256) {
        uint256 depth = self.depth;
        require(leaf < SNARK_SCALAR_FIELD);
        require(index < 2 ** depth);

        uint256 hash = leaf;
        uint256 lastLeftElement;
        uint256 lastRightElement;

        for (uint8 i = 0; i < depth; ) {
            if (index & 1 == 0) {
                uint256 siblingLeaf = self.zeroes[i];
                lastLeftElement = hash;
                lastRightElement = siblingLeaf;
            } else {
                uint256 siblingLeaf = self.zeroes[i];
                lastLeftElement = siblingLeaf;
                lastRightElement = hash;
            }

            hash = Poseidon2.poseidon([lastLeftElement, lastRightElement]);
            index >>= 1;

            unchecked {
                i++;
            }
        }

        return hash;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import '../lib/SparseMerkleTreeWithHistory.sol';
import '../lib/IncrementalSparseMerkleTree.sol';
import '../lib/DataTypes.sol';

abstract contract ControllableStorage {
    address internal _controller;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import '../lib/SparseMerkleTreeWithHistory.sol';
import '../lib/IncrementalSparseMerkleTree.sol';
import '../lib/DataTypes.sol';
import './ControllableStorage.sol';

abstract contract GrappaDirectoryStorage is ControllableStorage {
    mapping(uint32 => DataTypes.UserData) internal _usersData;
    mapping(address => uint32) internal _walletUserId;
    mapping(address => bool) internal _blacklist;
    SparseTreeWithHistoryData internal _idTree;
    uint32 internal _nextUserId;
    uint256 internal _userInitialPrice;
}

//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

library AckMsgVerifierPairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }

    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return
            G2Point(
                [
                    11559732032986387107991004021392285783925812861821192530917403151452391805634,
                    10857046999023057135944570762232829481370756359578518086990519993285655852781
                ],
                [
                    4082367875863433681332203403145435568316851327593401208105741076214120093531,
                    8495653923123431417604973247489272438418190587263600148770280649306958101930
                ]
            );

        /*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }

    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }

    /// @return r the sum of two points of G1
    function addition(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-add-failed');
    }

    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(
        G1Point memory p,
        uint s
    ) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-mul-failed');
    }

    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(
        G1Point[] memory p1,
        G2Point[] memory p2
    ) internal view returns (bool) {
        require(p1.length == p2.length, 'pairing-lengths-failed');
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(
                sub(gas(), 2000),
                8,
                add(input, 0x20),
                mul(inputSize, 0x20),
                out,
                0x20
            )
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-opcode-failed');
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract AckMsgVerifier {
    using AckMsgVerifierPairing for *;
    struct VerifyingKey {
        AckMsgVerifierPairing.G1Point alfa1;
        AckMsgVerifierPairing.G2Point beta2;
        AckMsgVerifierPairing.G2Point gamma2;
        AckMsgVerifierPairing.G2Point delta2;
        AckMsgVerifierPairing.G1Point[] IC;
    }
    struct Proof {
        AckMsgVerifierPairing.G1Point A;
        AckMsgVerifierPairing.G2Point B;
        AckMsgVerifierPairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = AckMsgVerifierPairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = AckMsgVerifierPairing.G2Point(
            [
                4252822878758300859123897981450591353533073413197771768651442665752259397132,
                6375614351688725206403948262868962793625744043794305715222011528459656738731
            ],
            [
                21847035105528745403288232691147584728191162732299865338377159692350059136679,
                10505242626370262277552901082094356697409835680220590971873171140371331206856
            ]
        );
        vk.gamma2 = AckMsgVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.delta2 = AckMsgVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.IC = new AckMsgVerifierPairing.G1Point[](22);

        vk.IC[0] = AckMsgVerifierPairing.G1Point(
            4939368111430544121738799024336572637862764720673194656609647924610241014512,
            12177107194533206480755420459700162266227051583493940209940781367255310638379
        );

        vk.IC[1] = AckMsgVerifierPairing.G1Point(
            378992330487334238255353244384195243268815701127078283070773739133377579054,
            5282695652281410376628534214914955176965023878895784346427070856319921420571
        );

        vk.IC[2] = AckMsgVerifierPairing.G1Point(
            18514179503480894310141254514700126305124262773624269428199505693248631025853,
            9914949486304610276302919498284626953264487416434554532385025832320176786595
        );

        vk.IC[3] = AckMsgVerifierPairing.G1Point(
            947928842993239884459421877433622115791797766190696917332077969057622295860,
            13858401136511106093355048192407080640989050175827724495875871004493097250199
        );

        vk.IC[4] = AckMsgVerifierPairing.G1Point(
            2493138086802449317495041368460409771192596124949057727308788830648215074006,
            2703472940483980325337260122896136551664502045400588499215691940360940623382
        );

        vk.IC[5] = AckMsgVerifierPairing.G1Point(
            15538320721275210799441645426635371933426730880564756968816578864027864509823,
            4282515202291575843892823077661490762978492502627169786682697633661869697391
        );

        vk.IC[6] = AckMsgVerifierPairing.G1Point(
            17054196686141985088822596319972052780396577289964709985846485811310135812254,
            15934636286747214646169915835689961956816096046891951051140557769592754842159
        );

        vk.IC[7] = AckMsgVerifierPairing.G1Point(
            18057930364796896380280584081912058829732517835180817456393778073929295292862,
            14948719392474352199898945013329293941320045812909274922213310949094311622567
        );

        vk.IC[8] = AckMsgVerifierPairing.G1Point(
            19158410220947400222606397938063744241529781118444100099157720743981842341435,
            10066317676754235699642935194880924720336822882504488175119906381608953615964
        );

        vk.IC[9] = AckMsgVerifierPairing.G1Point(
            10263910547493848005593810535109071160379860026246427944427924355874745237309,
            19643910500149160539728907468317214752266371893744333449159070741306964148467
        );

        vk.IC[10] = AckMsgVerifierPairing.G1Point(
            5290097764770794370860742673768903669273347342403972103440586001412150301409,
            3339057649799133602122760404199626442035640920584496744288008739947957524663
        );

        vk.IC[11] = AckMsgVerifierPairing.G1Point(
            14795586192986815967796938220537516048674404824054827559704415548041430940384,
            13376391141065073313550521764854213464689956637983841028061364243424888339409
        );

        vk.IC[12] = AckMsgVerifierPairing.G1Point(
            15310262206738715407014655185225927413265683020101383538269492778109509275965,
            18398647136443048261899685084521441083155940746206919057122900080686901194127
        );

        vk.IC[13] = AckMsgVerifierPairing.G1Point(
            20599868197973420583374352167927158140626434094203572953764386504047401489749,
            21775968298284932708146472140219716291412142579013665401299950281830406712193
        );

        vk.IC[14] = AckMsgVerifierPairing.G1Point(
            1529461878915842529881892023719900406340668563949107995005207603881029799776,
            19064198171325222646446932690628941387351112270398790668739926050358383747011
        );

        vk.IC[15] = AckMsgVerifierPairing.G1Point(
            18865841239945263785801374436997779586654717481581348143477886802191081906324,
            4048118924448358807844379991239523580374381546574585428174924593097496659896
        );

        vk.IC[16] = AckMsgVerifierPairing.G1Point(
            3470823266029242439189360851938421225295703736450410459959598827904032006573,
            10946830485095850696034668236454277236315771073522533234834080818827688126998
        );

        vk.IC[17] = AckMsgVerifierPairing.G1Point(
            12344429552940305092145261945165603233364083794397097222237310914590163132988,
            20827483975690952217668468804760729198700023511009725422991252831101385283917
        );

        vk.IC[18] = AckMsgVerifierPairing.G1Point(
            12875560787777400333547342234591084561537463097293504208266962179045365219742,
            13550909162792575088614252081769191456139626732992066843714570649208347531481
        );

        vk.IC[19] = AckMsgVerifierPairing.G1Point(
            2393509960983121017023504572056102854650501945843315514970504489727944278478,
            24225235230371766620740010371422011833559172169204307031391295578137224840
        );

        vk.IC[20] = AckMsgVerifierPairing.G1Point(
            20815747740294330238853522787778567000510189902078611274704034450665614458147,
            12837725313344018735708359328651903398448160759625337792503176683438191829597
        );

        vk.IC[21] = AckMsgVerifierPairing.G1Point(
            12290883976384787443538227699110078815168912561216300309459508798980347960374,
            13666287802447548525768909018537729407066718638501085112136327197683584162268
        );
    }

    function verify(
        uint[] memory input,
        Proof memory proof
    ) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length, 'verifier-bad-input');
        // Compute the linear combination vk_x
        AckMsgVerifierPairing.G1Point memory vk_x = AckMsgVerifierPairing
            .G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(
                input[i] < snark_scalar_field,
                'verifier-gte-snark-scalar-field'
            );
            vk_x = AckMsgVerifierPairing.addition(
                vk_x,
                AckMsgVerifierPairing.scalar_mul(vk.IC[i + 1], input[i])
            );
        }
        vk_x = AckMsgVerifierPairing.addition(vk_x, vk.IC[0]);
        if (
            !AckMsgVerifierPairing.pairingProd4(
                AckMsgVerifierPairing.negate(proof.A),
                proof.B,
                vk.alfa1,
                vk.beta2,
                vk_x,
                vk.gamma2,
                proof.C,
                vk.delta2
            )
        ) return 1;
        return 0;
    }

    /// @return r  bool true if proof is valid
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[21] memory input
    ) public view returns (bool r) {
        Proof memory proof;
        proof.A = AckMsgVerifierPairing.G1Point(a[0], a[1]);
        proof.B = AckMsgVerifierPairing.G2Point(
            [b[0][0], b[0][1]],
            [b[1][0], b[1][1]]
        );
        proof.C = AckMsgVerifierPairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for (uint i = 0; i < input.length; i++) {
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}

//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

library ExtractTokensVerifierPairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }

    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return
            G2Point(
                [
                    11559732032986387107991004021392285783925812861821192530917403151452391805634,
                    10857046999023057135944570762232829481370756359578518086990519993285655852781
                ],
                [
                    4082367875863433681332203403145435568316851327593401208105741076214120093531,
                    8495653923123431417604973247489272438418190587263600148770280649306958101930
                ]
            );

        /*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }

    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }

    /// @return r the sum of two points of G1
    function addition(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-add-failed');
    }

    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(
        G1Point memory p,
        uint s
    ) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-mul-failed');
    }

    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(
        G1Point[] memory p1,
        G2Point[] memory p2
    ) internal view returns (bool) {
        require(p1.length == p2.length, 'pairing-lengths-failed');
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(
                sub(gas(), 2000),
                8,
                add(input, 0x20),
                mul(inputSize, 0x20),
                out,
                0x20
            )
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-opcode-failed');
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract ExtractTokensVerifier {
    using ExtractTokensVerifierPairing for *;
    struct VerifyingKey {
        ExtractTokensVerifierPairing.G1Point alfa1;
        ExtractTokensVerifierPairing.G2Point beta2;
        ExtractTokensVerifierPairing.G2Point gamma2;
        ExtractTokensVerifierPairing.G2Point delta2;
        ExtractTokensVerifierPairing.G1Point[] IC;
    }
    struct Proof {
        ExtractTokensVerifierPairing.G1Point A;
        ExtractTokensVerifierPairing.G2Point B;
        ExtractTokensVerifierPairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = ExtractTokensVerifierPairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = ExtractTokensVerifierPairing.G2Point(
            [
                4252822878758300859123897981450591353533073413197771768651442665752259397132,
                6375614351688725206403948262868962793625744043794305715222011528459656738731
            ],
            [
                21847035105528745403288232691147584728191162732299865338377159692350059136679,
                10505242626370262277552901082094356697409835680220590971873171140371331206856
            ]
        );
        vk.gamma2 = ExtractTokensVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.delta2 = ExtractTokensVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.IC = new ExtractTokensVerifierPairing.G1Point[](18);

        vk.IC[0] = ExtractTokensVerifierPairing.G1Point(
            17193944408729488295578385958536230420844699629457288517914613180203100225153,
            10636685035270204254579552739306012152770346874701491311553203921443575612776
        );

        vk.IC[1] = ExtractTokensVerifierPairing.G1Point(
            7672452742904893081197067833274258209244100929105071361838642655772533289678,
            18921839942371988239467940904550758932502848655857765727873139159789533295937
        );

        vk.IC[2] = ExtractTokensVerifierPairing.G1Point(
            5503283663982438952378667536163373516642265143971678645011475977024161649278,
            21234362538940833901869944369846454577124715067390193719445711065931240190464
        );

        vk.IC[3] = ExtractTokensVerifierPairing.G1Point(
            1773291601871128858435768339110287994177361313237175067901644184638745788400,
            9828638383063559940481389778881875192291926274132287724642865211965275998506
        );

        vk.IC[4] = ExtractTokensVerifierPairing.G1Point(
            12828856020179171619893698378705440918126408198530703286666580579274558600423,
            11155349150654217779283370688342673802680499656173500330736686937868085629978
        );

        vk.IC[5] = ExtractTokensVerifierPairing.G1Point(
            2143413837982271562814732934633719464495545449989098516093858678715742183040,
            15105965130342356424204089812670041652597319978239476715465869274944434010868
        );

        vk.IC[6] = ExtractTokensVerifierPairing.G1Point(
            1896780512748942616611793420557523469470291930137416626080711946661492656690,
            14461944754886918381107914854324857228536713094718628887297586515874033234955
        );

        vk.IC[7] = ExtractTokensVerifierPairing.G1Point(
            14510314524912130689750955160044070780581428030486360607771681906962444824292,
            5735924305773615546324045484373844797840879818411810152063213150483971966932
        );

        vk.IC[8] = ExtractTokensVerifierPairing.G1Point(
            1891842670489852891326528780475098273246490334934153956647633721970809482122,
            19829008349541316910794487507460219422591300957485623117092450444274040729227
        );

        vk.IC[9] = ExtractTokensVerifierPairing.G1Point(
            21405072992204011199330867179699651727690164304725174172103560894058959021338,
            512328126605521666835344841973919249034773281075094737826808550187661589216
        );

        vk.IC[10] = ExtractTokensVerifierPairing.G1Point(
            7014518605846360372609295386055690056073466223768374956845234948533298772725,
            13439303555653713759716131289248024812674056616824996967306680316297877177278
        );

        vk.IC[11] = ExtractTokensVerifierPairing.G1Point(
            1359442949146487032586791269733405249024695788013309332651398477553372582872,
            6173143261450855312191748229940741221845968879132965518461762327131453503544
        );

        vk.IC[12] = ExtractTokensVerifierPairing.G1Point(
            12051500943789907182623633855387008101506086891424429215190089277471237078806,
            869705397275510580653817296713402346952971717532006118642236245432022990616
        );

        vk.IC[13] = ExtractTokensVerifierPairing.G1Point(
            11026213686287950394538176882648292486294011840181958913888778808908103391723,
            9939120309295537811184378510587326218435165421667559168342656356473637453845
        );

        vk.IC[14] = ExtractTokensVerifierPairing.G1Point(
            13616583999870617245636426527489786372558384190787807610569675665213960363617,
            9966817088363549537689496083875914987382565798264229837289339720081783734072
        );

        vk.IC[15] = ExtractTokensVerifierPairing.G1Point(
            6022705233839073926621051706399346424724916281785436790704013595760855350258,
            7988157589434717237903175244217649842445134667992197580070860233849241573680
        );

        vk.IC[16] = ExtractTokensVerifierPairing.G1Point(
            2455013494937029059667759317783849233086272189461163431066970908197585725297,
            8541634128267091080170312820888246982980558586384099520209254972395563808704
        );

        vk.IC[17] = ExtractTokensVerifierPairing.G1Point(
            10978761624581448843533462758336084513674486007087230448461382607699393592032,
            4448795489168407470458879234501749050667132351402690216420114741673946325288
        );
    }

    function verify(
        uint[] memory input,
        Proof memory proof
    ) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length, 'verifier-bad-input');
        // Compute the linear combination vk_x
        ExtractTokensVerifierPairing.G1Point
            memory vk_x = ExtractTokensVerifierPairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(
                input[i] < snark_scalar_field,
                'verifier-gte-snark-scalar-field'
            );
            vk_x = ExtractTokensVerifierPairing.addition(
                vk_x,
                ExtractTokensVerifierPairing.scalar_mul(vk.IC[i + 1], input[i])
            );
        }
        vk_x = ExtractTokensVerifierPairing.addition(vk_x, vk.IC[0]);
        if (
            !ExtractTokensVerifierPairing.pairingProd4(
                ExtractTokensVerifierPairing.negate(proof.A),
                proof.B,
                vk.alfa1,
                vk.beta2,
                vk_x,
                vk.gamma2,
                proof.C,
                vk.delta2
            )
        ) return 1;
        return 0;
    }

    /// @return r  bool true if proof is valid
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[17] memory input
    ) public view returns (bool r) {
        Proof memory proof;
        proof.A = ExtractTokensVerifierPairing.G1Point(a[0], a[1]);
        proof.B = ExtractTokensVerifierPairing.G2Point(
            [b[0][0], b[0][1]],
            [b[1][0], b[1][1]]
        );
        proof.C = ExtractTokensVerifierPairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for (uint i = 0; i < input.length; i++) {
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}

//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

library LoadTokensVerifierPairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }

    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return
            G2Point(
                [
                    11559732032986387107991004021392285783925812861821192530917403151452391805634,
                    10857046999023057135944570762232829481370756359578518086990519993285655852781
                ],
                [
                    4082367875863433681332203403145435568316851327593401208105741076214120093531,
                    8495653923123431417604973247489272438418190587263600148770280649306958101930
                ]
            );

        /*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }

    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }

    /// @return r the sum of two points of G1
    function addition(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-add-failed');
    }

    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(
        G1Point memory p,
        uint s
    ) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-mul-failed');
    }

    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(
        G1Point[] memory p1,
        G2Point[] memory p2
    ) internal view returns (bool) {
        require(p1.length == p2.length, 'pairing-lengths-failed');
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(
                sub(gas(), 2000),
                8,
                add(input, 0x20),
                mul(inputSize, 0x20),
                out,
                0x20
            )
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-opcode-failed');
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract LoadTokensVerifier {
    using LoadTokensVerifierPairing for *;
    struct VerifyingKey {
        LoadTokensVerifierPairing.G1Point alfa1;
        LoadTokensVerifierPairing.G2Point beta2;
        LoadTokensVerifierPairing.G2Point gamma2;
        LoadTokensVerifierPairing.G2Point delta2;
        LoadTokensVerifierPairing.G1Point[] IC;
    }
    struct Proof {
        LoadTokensVerifierPairing.G1Point A;
        LoadTokensVerifierPairing.G2Point B;
        LoadTokensVerifierPairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = LoadTokensVerifierPairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = LoadTokensVerifierPairing.G2Point(
            [
                4252822878758300859123897981450591353533073413197771768651442665752259397132,
                6375614351688725206403948262868962793625744043794305715222011528459656738731
            ],
            [
                21847035105528745403288232691147584728191162732299865338377159692350059136679,
                10505242626370262277552901082094356697409835680220590971873171140371331206856
            ]
        );
        vk.gamma2 = LoadTokensVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.delta2 = LoadTokensVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.IC = new LoadTokensVerifierPairing.G1Point[](18);

        vk.IC[0] = LoadTokensVerifierPairing.G1Point(
            11638917480947402386259325574135369752369591338890837637660481155539593925404,
            2357058090082114599878476212979049817107808725304958049460549539110565784128
        );

        vk.IC[1] = LoadTokensVerifierPairing.G1Point(
            8893557619554938237024995137845720757211627826093669982838788768037226547725,
            16562931028265260431180978212679536600419013911610252551022185966614711806720
        );

        vk.IC[2] = LoadTokensVerifierPairing.G1Point(
            13322615423024125497593060492980985423246028431661351871966580202879988797809,
            11291392339092635410654936862239545484846709452169809707707076119476340173076
        );

        vk.IC[3] = LoadTokensVerifierPairing.G1Point(
            8891819415305920517462816914369112253592336482682649209145158588874852363089,
            9192827223941645914021293786742649089601395695711618611693412298277849254915
        );

        vk.IC[4] = LoadTokensVerifierPairing.G1Point(
            13979543862447886832071179270879735077896694855681316632716132594453414207618,
            10544637873223148720653273808517957588726945428510682859317146526011410860161
        );

        vk.IC[5] = LoadTokensVerifierPairing.G1Point(
            16881337571772818730158350480493575708154668775096495693477338619812295691440,
            16435320247965336332855964500657216240636418129765860646872128938785708171758
        );

        vk.IC[6] = LoadTokensVerifierPairing.G1Point(
            5212967678731679721457715980396597917347280961526145685442766871765472171452,
            17463017044646785801509672779230478451922483380081785030888506099886504940132
        );

        vk.IC[7] = LoadTokensVerifierPairing.G1Point(
            11315770477935521513496179079287230360893387831365475551723528896027900633827,
            16936009377981016695269918779884627882022338369317909746021009560980670157083
        );

        vk.IC[8] = LoadTokensVerifierPairing.G1Point(
            15529251677724800450917000226709432833483370976578822763919801647924324870764,
            14334236815028246767666933343800068649962410328559196641888985970720742560056
        );

        vk.IC[9] = LoadTokensVerifierPairing.G1Point(
            4618383860726625158589828503136453488340249612462281941304478379197555932708,
            21506569391120832852469334963445806060614468401171686127072032047755727791116
        );

        vk.IC[10] = LoadTokensVerifierPairing.G1Point(
            7354953456504629502764998850329608218744174658193518338668750372439591520975,
            2067549816266526791584030965570410441370595262671971927243511681289071764932
        );

        vk.IC[11] = LoadTokensVerifierPairing.G1Point(
            10367698802686560210275673603998528270520882570354862526385336612750775015513,
            20738163221257312283174638758044100314231286952426942163029873831130686481032
        );

        vk.IC[12] = LoadTokensVerifierPairing.G1Point(
            16864264842451100928970099479770945209970459843094978366376381837768174015780,
            7918458553443682615919028490757741828375124228292665647757221040427231087003
        );

        vk.IC[13] = LoadTokensVerifierPairing.G1Point(
            16325817017152491902384185485216566992017734480445701824816307882288643155882,
            2282871890201684803066692820539790425233299070989930441236367410525062483987
        );

        vk.IC[14] = LoadTokensVerifierPairing.G1Point(
            18014903782393944896042859913312411274182202597006965496871768468314519476690,
            10805082045966248887214902593319576762103915597216861232607363643788980209170
        );

        vk.IC[15] = LoadTokensVerifierPairing.G1Point(
            10337566838399853859075981413958530983445192311469599556709895930287494798405,
            15645853620079184044636741774473359052841901926833312968147447967504838955131
        );

        vk.IC[16] = LoadTokensVerifierPairing.G1Point(
            8805326341250384894916067600869074018325292211530399517595658413446382318929,
            12981032334246843808073860208662293557562203006085831934460932524737285949223
        );

        vk.IC[17] = LoadTokensVerifierPairing.G1Point(
            14399769596883487578152439405644560492568656788846603319312398255283469479406,
            7483580948394347715972924189211101330709249461570384150708142017694107727679
        );
    }

    function verify(
        uint[] memory input,
        Proof memory proof
    ) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length, 'verifier-bad-input');
        // Compute the linear combination vk_x
        LoadTokensVerifierPairing.G1Point
            memory vk_x = LoadTokensVerifierPairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(
                input[i] < snark_scalar_field,
                'verifier-gte-snark-scalar-field'
            );
            vk_x = LoadTokensVerifierPairing.addition(
                vk_x,
                LoadTokensVerifierPairing.scalar_mul(vk.IC[i + 1], input[i])
            );
        }
        vk_x = LoadTokensVerifierPairing.addition(vk_x, vk.IC[0]);
        if (
            !LoadTokensVerifierPairing.pairingProd4(
                LoadTokensVerifierPairing.negate(proof.A),
                proof.B,
                vk.alfa1,
                vk.beta2,
                vk_x,
                vk.gamma2,
                proof.C,
                vk.delta2
            )
        ) return 1;
        return 0;
    }

    /// @return r  bool true if proof is valid
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[17] memory input
    ) public view returns (bool r) {
        Proof memory proof;
        proof.A = LoadTokensVerifierPairing.G1Point(a[0], a[1]);
        proof.B = LoadTokensVerifierPairing.G2Point(
            [b[0][0], b[0][1]],
            [b[1][0], b[1][1]]
        );
        proof.C = LoadTokensVerifierPairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for (uint i = 0; i < input.length; i++) {
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}

//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

library SendMsgVerifierPairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }

    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return
            G2Point(
                [
                    11559732032986387107991004021392285783925812861821192530917403151452391805634,
                    10857046999023057135944570762232829481370756359578518086990519993285655852781
                ],
                [
                    4082367875863433681332203403145435568316851327593401208105741076214120093531,
                    8495653923123431417604973247489272438418190587263600148770280649306958101930
                ]
            );

        /*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }

    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }

    /// @return r the sum of two points of G1
    function addition(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-add-failed');
    }

    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(
        G1Point memory p,
        uint s
    ) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-mul-failed');
    }

    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(
        G1Point[] memory p1,
        G2Point[] memory p2
    ) internal view returns (bool) {
        require(p1.length == p2.length, 'pairing-lengths-failed');
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(
                sub(gas(), 2000),
                8,
                add(input, 0x20),
                mul(inputSize, 0x20),
                out,
                0x20
            )
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, 'pairing-opcode-failed');
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }

    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract SendMsgVerifier {
    using SendMsgVerifierPairing for *;
    struct VerifyingKey {
        SendMsgVerifierPairing.G1Point alfa1;
        SendMsgVerifierPairing.G2Point beta2;
        SendMsgVerifierPairing.G2Point gamma2;
        SendMsgVerifierPairing.G2Point delta2;
        SendMsgVerifierPairing.G1Point[] IC;
    }
    struct Proof {
        SendMsgVerifierPairing.G1Point A;
        SendMsgVerifierPairing.G2Point B;
        SendMsgVerifierPairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = SendMsgVerifierPairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = SendMsgVerifierPairing.G2Point(
            [
                4252822878758300859123897981450591353533073413197771768651442665752259397132,
                6375614351688725206403948262868962793625744043794305715222011528459656738731
            ],
            [
                21847035105528745403288232691147584728191162732299865338377159692350059136679,
                10505242626370262277552901082094356697409835680220590971873171140371331206856
            ]
        );
        vk.gamma2 = SendMsgVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.delta2 = SendMsgVerifierPairing.G2Point(
            [
                11559732032986387107991004021392285783925812861821192530917403151452391805634,
                10857046999023057135944570762232829481370756359578518086990519993285655852781
            ],
            [
                4082367875863433681332203403145435568316851327593401208105741076214120093531,
                8495653923123431417604973247489272438418190587263600148770280649306958101930
            ]
        );
        vk.IC = new SendMsgVerifierPairing.G1Point[](27);

        vk.IC[0] = SendMsgVerifierPairing.G1Point(
            3138260094250051954325244249597069210910652544908094647199385946672814426391,
            8057454535573625339410115432095647041194631482776937891450441659064068359942
        );

        vk.IC[1] = SendMsgVerifierPairing.G1Point(
            19923092849917777225254201111279500505181680658678923674384209621503873077455,
            9385069099391590602410832290237771614855780664075155197380800417447674050390
        );

        vk.IC[2] = SendMsgVerifierPairing.G1Point(
            6323945557652449394926137999149372797860021580377560287491398836759862660175,
            14290500241751106968068237012060511718130335742328310473573984446400821419491
        );

        vk.IC[3] = SendMsgVerifierPairing.G1Point(
            4017042119406284148598972450780939680610760678583269092830245651064229432249,
            7725674391374707010882149023955137902742272426844445447791639378767873773982
        );

        vk.IC[4] = SendMsgVerifierPairing.G1Point(
            10831577814084075026538986627517778751204345466399938148897548475537555407284,
            1703637532291783487324502477879996122390499105598164188593634160402156384653
        );

        vk.IC[5] = SendMsgVerifierPairing.G1Point(
            4543691846536418469370296522494517975286675391804267383439273406955676330628,
            21488061638083053401401244871607998434863671631434980341990611743653994137351
        );

        vk.IC[6] = SendMsgVerifierPairing.G1Point(
            11157732327184692369397468197785211668651291116509533533740086714147689589226,
            7755837875282577373678364502030374255434429031186850362066048399187835287653
        );

        vk.IC[7] = SendMsgVerifierPairing.G1Point(
            4559078668818796532420897111726241504216859693885685534223772481658111287972,
            445858533378251905453766913652973135426846190557970377329147851834964006894
        );

        vk.IC[8] = SendMsgVerifierPairing.G1Point(
            20545063619186756307714247870892818709442475460216664124004038266195045177799,
            11778326401322278356776371314303477026726103632776669540801718053402085169905
        );

        vk.IC[9] = SendMsgVerifierPairing.G1Point(
            14615347155148251745604796346843756078530394937674547409905297668418956567641,
            8463767929241742044025698558886928527608385746707719747741944498568215213925
        );

        vk.IC[10] = SendMsgVerifierPairing.G1Point(
            3309295197678278174745190425326700818334230126803889509794409296979173300012,
            7402747100803835497579304227714687103208056137547009727596821918100620160468
        );

        vk.IC[11] = SendMsgVerifierPairing.G1Point(
            8073400567900996521281638497441430393578567294625170161085074493826595427860,
            3239164493136395243925529019826142937679099451598236551375325174531758001531
        );

        vk.IC[12] = SendMsgVerifierPairing.G1Point(
            11480227006433185549418395774416460192349143171970651708169467101974383066173,
            13734163411966716237645594056621410773608054957499761319551152243991471511989
        );

        vk.IC[13] = SendMsgVerifierPairing.G1Point(
            15825626971614108784397893286584737074302748463665042738862209024679394844146,
            15232077415234418227560216936370793620660711355668777171520122158458391584477
        );

        vk.IC[14] = SendMsgVerifierPairing.G1Point(
            4404791860281255199758567099059300090832905401106487744648440388980846355576,
            14544360517967521911417826148382451878735378388910966120385859994462622076677
        );

        vk.IC[15] = SendMsgVerifierPairing.G1Point(
            4150239678545802906758227688648740741975162575182115765520387868321480556371,
            11156093541062595987353577861829582827555983704444405059067859606284485583210
        );

        vk.IC[16] = SendMsgVerifierPairing.G1Point(
            16738116835866956317687444871659157132835476758335422124555919640504088764250,
            6909630912199838036342686783478178909906491087076951443902281199428128660979
        );

        vk.IC[17] = SendMsgVerifierPairing.G1Point(
            1229944605427486697378779419965060776637624949921527890474151787714405546825,
            4832570697107146833054590406274015524138775842803682501791182859738203035862
        );

        vk.IC[18] = SendMsgVerifierPairing.G1Point(
            10728331195927577501207677863752355901625337958315128660616664217491756310037,
            12040556988668905214529068158659957333930396875168322348410112452035136088531
        );

        vk.IC[19] = SendMsgVerifierPairing.G1Point(
            11734692924978406212512977794317361138720649301299141195241597061301203596287,
            15842976581051204871683125610462080271564647684347688811422996309921880252899
        );

        vk.IC[20] = SendMsgVerifierPairing.G1Point(
            1571352466848695968240438540535342416296868478124610761815306580505935428525,
            18496217280328617154206601290583232941891242845673720188729409139159006855854
        );

        vk.IC[21] = SendMsgVerifierPairing.G1Point(
            12477352469062576039774143302779949515376109844792486565546571899929087767892,
            14372168455255668714682303576690921505553898460355915888397561149962612376254
        );

        vk.IC[22] = SendMsgVerifierPairing.G1Point(
            12550258901923662229245318636634059216529467039321075229104773128616020049168,
            8649346414531024665725754657824561979786355090900992582226314801101218901438
        );

        vk.IC[23] = SendMsgVerifierPairing.G1Point(
            18352166276129733812878673896811760162159757451907782063825006417002307161291,
            659252760502580696113512786729508332674147516908725353158483809745983720076
        );

        vk.IC[24] = SendMsgVerifierPairing.G1Point(
            19381371463207824263252659092276385993203605877636984469543188035086743720862,
            15516596554446978849580744459110165378015147086433170670912519800963594299767
        );

        vk.IC[25] = SendMsgVerifierPairing.G1Point(
            2060534723511715484457016153163274699388010669760128716945645211957944439751,
            10508035559882333433340053537712008022945867681635456966136159933054222961692
        );

        vk.IC[26] = SendMsgVerifierPairing.G1Point(
            17320565126198021564028526248776226485676135838416510514948043088632241862916,
            10693233006212606838126683215290969353763225466634175527950813435643001874964
        );
    }

    function verify(
        uint[] memory input,
        Proof memory proof
    ) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length, 'verifier-bad-input');
        // Compute the linear combination vk_x
        SendMsgVerifierPairing.G1Point memory vk_x = SendMsgVerifierPairing
            .G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(
                input[i] < snark_scalar_field,
                'verifier-gte-snark-scalar-field'
            );
            vk_x = SendMsgVerifierPairing.addition(
                vk_x,
                SendMsgVerifierPairing.scalar_mul(vk.IC[i + 1], input[i])
            );
        }
        vk_x = SendMsgVerifierPairing.addition(vk_x, vk.IC[0]);
        if (
            !SendMsgVerifierPairing.pairingProd4(
                SendMsgVerifierPairing.negate(proof.A),
                proof.B,
                vk.alfa1,
                vk.beta2,
                vk_x,
                vk.gamma2,
                proof.C,
                vk.delta2
            )
        ) return 1;
        return 0;
    }

    /// @return r  bool true if proof is valid
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[26] memory input
    ) public view returns (bool r) {
        Proof memory proof;
        proof.A = SendMsgVerifierPairing.G1Point(a[0], a[1]);
        proof.B = SendMsgVerifierPairing.G2Point(
            [b[0][0], b[0][1]],
            [b[1][0], b[1][1]]
        );
        proof.C = SendMsgVerifierPairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for (uint i = 0; i < input.length; i++) {
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}