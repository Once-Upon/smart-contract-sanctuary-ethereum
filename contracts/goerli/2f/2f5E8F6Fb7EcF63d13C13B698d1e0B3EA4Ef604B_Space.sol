// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
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
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
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
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
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
            _functionDelegateCall(newImplementation, data);
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
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
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
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
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
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
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
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

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
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

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
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
library StorageSlotUpgradeable {
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

// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

//interfaces
import {ISpace} from "contracts/src/interfaces/ISpace.sol";
import {IEntitlement} from "contracts/src/interfaces/IEntitlement.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

//libraries
import {DataTypes} from "contracts/src/libraries/DataTypes.sol";
import {Utils} from "contracts/src/libraries/Utils.sol";
import {Errors} from "contracts/src/libraries/Errors.sol";
import {Events} from "contracts/src/libraries/Events.sol";
import {Permissions} from "contracts/src/libraries/Permissions.sol";

//contracts
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MultiCaller} from "contracts/src/misc/MultiCaller.sol";

contract Space is
  Initializable,
  ContextUpgradeable,
  UUPSUpgradeable,
  MultiCaller,
  ISpace
{
  string public name;
  string public networkId;
  bool public disabled;
  uint256 public ownerRoleId;
  address public token;
  uint256 public tokenId;

  mapping(address => bool) public hasEntitlement;
  mapping(address => bool) public defaultEntitlements;
  mapping(uint256 => bytes32[]) internal entitlementIdsByRoleId;
  address[] public entitlements;

  uint256 public roleCount;
  mapping(uint256 => DataTypes.Role) public rolesById;
  mapping(uint256 => bytes32[]) internal permissionsByRoleId;

  mapping(bytes32 => DataTypes.Channel) public channelsByHash;
  bytes32[] public channels;

  string internal constant IN_SPACE = "";

  /**
   * @dev Added to allow future versions to add new variables in case this contract becomes
   *      inherited. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[49] private __gap;

  modifier onlySpaceOwner() {
    _isAllowed(IN_SPACE, Permissions.Owner);
    _;
  }

  /// ***** Space Management *****

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc ISpace
  function initialize(
    string memory _name,
    string memory _networkId,
    address[] memory _entitlements,
    address _token,
    uint256 _tokenId
  ) external initializer {
    __UUPSUpgradeable_init();
    __Context_init();

    name = _name;
    networkId = _networkId;
    token = _token;
    tokenId = _tokenId;

    // whitelist modules
    for (uint256 i = 0; i < _entitlements.length; i++) {
      _setEntitlement(_entitlements[i], true);
      defaultEntitlements[_entitlements[i]] = true;
    }
  }

  /// @inheritdoc ISpace
  function owner() public view returns (address) {
    return IERC721(token).ownerOf(tokenId);
  }

  /// @inheritdoc ISpace
  function setSpaceAccess(bool _disabled) external {
    if (!_isOwner()) revert Errors.NotAllowed();
    disabled = _disabled;
  }

  /// @inheritdoc ISpace
  function setOwnerRoleId(uint256 _roleId) external {
    if (!_isOwner()) revert Errors.NotAllowed();
    if (_ownerRoleIsSet()) revert Errors.NotAllowed();

    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    // check the role has the owner permission
    bool hasOwnerPermission = false;
    for (uint256 i = 0; i < permissionsByRoleId[_roleId].length; i++) {
      if (
        permissionsByRoleId[_roleId][i] ==
        bytes32(abi.encodePacked(Permissions.Owner))
      ) {
        hasOwnerPermission = true;
        break;
      }
    }

    if (!hasOwnerPermission) {
      revert Errors.MissingOwnerPermission();
    }

    ownerRoleId = _roleId;
  }

  /// ***** Channel Management *****

  /// @inheritdoc ISpace
  function getChannelByHash(
    bytes32 _channelHash
  ) external view returns (DataTypes.Channel memory) {
    return channelsByHash[_channelHash];
  }

  /// @inheritdoc ISpace
  function setChannelAccess(
    string calldata channelNetworkId,
    bool disableChannel
  ) external {
    _isAllowed(IN_SPACE, Permissions.AddRemoveChannels);

    bytes32 channelHash = keccak256(abi.encodePacked(channelNetworkId));

    if (channelsByHash[channelHash].channelHash == 0) {
      revert Errors.ChannelDoesNotExist();
    }

    channelsByHash[channelHash].disabled = disableChannel;
  }

  function updateChannel(
    string calldata channelNetworkId,
    string calldata channelName
  ) external {
    _isAllowed(IN_SPACE, Permissions.AddRemoveChannels);

    Utils.validateLength(channelName);

    bytes32 channelHash = keccak256(abi.encodePacked(channelNetworkId));

    if (channelsByHash[channelHash].channelHash == 0) {
      revert Errors.ChannelDoesNotExist();
    }

    channelsByHash[channelHash].name = channelName;
  }

  /// @inheritdoc ISpace
  function createChannel(
    string calldata channelName,
    string memory channelNetworkId,
    uint256[] memory roleIds
  ) external returns (bytes32) {
    _isAllowed(IN_SPACE, Permissions.AddRemoveChannels);

    Utils.validateLength(channelName);

    bytes32 channelHash = keccak256(abi.encodePacked(channelNetworkId));

    if (channelsByHash[channelHash].channelHash != 0) {
      revert Errors.ChannelAlreadyRegistered();
    }

    // save channel info
    channelsByHash[channelHash] = DataTypes.Channel({
      name: channelName,
      channelNetworkId: channelNetworkId,
      channelHash: channelHash,
      createdAt: block.timestamp,
      disabled: false
    });

    // keep track of channels
    channels.push(channelHash);

    // Add the owner role to the channel's entitlements
    for (uint256 i = 0; i < entitlements.length; i++) {
      address entitlement = entitlements[i];

      IEntitlement(entitlement).addRoleIdToChannel(
        channelNetworkId,
        ownerRoleId
      );

      // Add extra roles to the channel's entitlements
      for (uint256 j = 0; j < roleIds.length; j++) {
        if (roleIds[j] == ownerRoleId) continue;

        // make sure the role exists
        if (rolesById[roleIds[j]].roleId == 0) {
          revert Errors.RoleDoesNotExist();
        }

        try
          IEntitlement(entitlement).addRoleIdToChannel(
            channelNetworkId,
            roleIds[j]
          )
        {} catch {
          revert Errors.AddRoleFailed();
        }
      }
    }

    return channelHash;
  }

  /// ***** Role Management *****

  /// @inheritdoc ISpace
  function getRoles() external view returns (DataTypes.Role[] memory) {
    DataTypes.Role[] memory roles = new DataTypes.Role[](roleCount);
    for (uint256 i = 0; i < roleCount; i++) {
      roles[i] = rolesById[i + 1];
    }
    return roles;
  }

  /// @inheritdoc ISpace
  function createRole(
    string calldata _roleName,
    string[] memory _permissions,
    DataTypes.Entitlement[] memory _entitlements
  ) external returns (uint256) {
    _isAllowed(IN_SPACE, Permissions.ModifySpaceSettings);

    Utils.validateLength(_roleName);

    uint256 newRoleId = ++roleCount;

    DataTypes.Role memory role = DataTypes.Role(newRoleId, _roleName);
    rolesById[newRoleId] = role;

    for (uint256 i = 0; i < _permissions.length; i++) {
      // only allow contract owner to add permission owner to role
      if (
        _ownerRoleIsSet() && Utils.isEqual(_permissions[i], Permissions.Owner)
      ) {
        revert Errors.NotAllowed();
      }

      bytes32 _permission = bytes32(abi.encodePacked(_permissions[i]));
      permissionsByRoleId[newRoleId].push(_permission);
    }

    // loop through entitlement modules and set entitlement data for role
    for (uint256 i = 0; i < _entitlements.length; i++) {
      address _entitlementModule = _entitlements[i].module;
      bytes memory _entitlementData = _entitlements[i].data;

      // check for empty address or data
      if (_entitlementModule == address(0) || _entitlementData.length == 0) {
        continue;
      }

      // check if entitlement is valid
      if (hasEntitlement[_entitlementModule] == false) {
        revert Errors.EntitlementNotWhitelisted();
      }

      // set entitlement data for role
      _addRoleToEntitlementModule(
        newRoleId,
        _entitlementModule,
        _entitlementData
      );
    }

    emit Events.RoleCreated(_msgSender(), newRoleId, _roleName, networkId);

    return newRoleId;
  }

  /// @inheritdoc ISpace
  function updateRole(uint256 _roleId, string memory _roleName) external {
    _isAllowed(IN_SPACE, Permissions.ModifySpaceSettings);

    Utils.validateLength(_roleName);

    // check not renaming owner role
    if (_roleId == ownerRoleId) {
      revert Errors.NotAllowed();
    }

    // check if role exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    rolesById[_roleId].name = _roleName;

    emit Events.RoleUpdated(_msgSender(), _roleId, _roleName, networkId);
  }

  /// @inheritdoc ISpace
  function removeRole(uint256 _roleId) external {
    _isAllowed(IN_SPACE, Permissions.ModifySpaceSettings);

    // check not removing owner role
    if (_roleId == ownerRoleId) {
      revert Errors.NotAllowed();
    }

    // check if role exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    // check if role is used in entitlements
    if (entitlementIdsByRoleId[_roleId].length > 0) {
      revert Errors.RoleIsAssignedToEntitlement();
    }

    // delete role
    delete rolesById[_roleId];

    // delete permissions of role
    delete permissionsByRoleId[_roleId];

    emit Events.RoleRemoved(_msgSender(), _roleId, networkId);
  }

  /// @inheritdoc ISpace
  function getRoleById(
    uint256 _roleId
  ) external view returns (DataTypes.Role memory) {
    return rolesById[_roleId];
  }

  /// @inheritdoc ISpace
  function addPermissionsToRole(
    uint256 _roleId,
    string[] memory _permissions
  ) external {
    _isAllowed(IN_SPACE, Permissions.ModifySpaceSettings);

    // check if role exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    // cannot add owner permission to role
    for (uint256 i = 0; i < _permissions.length; i++) {
      if (Utils.isEqual(_permissions[i], Permissions.Owner)) {
        revert Errors.NotAllowed();
      }

      bytes32 _permissionHash = bytes32(abi.encodePacked(_permissions[i]));

      // check if permission already exists
      for (uint256 j = 0; j < permissionsByRoleId[_roleId].length; j++) {
        if (permissionsByRoleId[_roleId][j] == _permissionHash) {
          revert Errors.PermissionAlreadyExists();
        }
      }

      // add permission to role
      permissionsByRoleId[_roleId].push(_permissionHash);
    }
  }

  /// @inheritdoc ISpace
  function getPermissionsByRoleId(
    uint256 _roleId
  ) external view override returns (string[] memory) {
    uint256 permissionsLength = permissionsByRoleId[_roleId].length;

    string[] memory _permissions = new string[](permissionsLength);

    for (uint256 i = 0; i < permissionsLength; i++) {
      _permissions[i] = Utils.bytes32ToString(permissionsByRoleId[_roleId][i]);
    }

    return _permissions;
  }

  /// @inheritdoc ISpace
  function removePermissionsFromRole(
    uint256 _roleId,
    string[] memory _permissions
  ) external {
    _isAllowed(IN_SPACE, Permissions.ModifySpaceSettings);

    // check if role exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    for (uint256 i = 0; i < _permissions.length; i++) {
      if (Utils.isEqual(_permissions[i], Permissions.Owner)) {
        revert Errors.NotAllowed();
      }

      bytes32 _permissionHash = bytes32(abi.encodePacked(_permissions[i]));

      // check if permission exists
      for (uint256 j = 0; j < permissionsByRoleId[_roleId].length; j++) {
        if (permissionsByRoleId[_roleId][j] != _permissionHash) continue;

        // remove permission from role
        permissionsByRoleId[_roleId][j] = permissionsByRoleId[_roleId][
          permissionsByRoleId[_roleId].length - 1
        ];
        permissionsByRoleId[_roleId].pop();
        break;
      }
    }
  }

  /// ***** Entitlement Management *****
  function upgradeEntitlement(
    address _entitlement,
    address _newEntitlement
  ) external {
    _isAllowed(IN_SPACE, Permissions.Owner);

    if (_entitlement == address(0) || _newEntitlement == address(0)) {
      revert Errors.InvalidParameters();
    }

    if (!hasEntitlement[_entitlement]) {
      revert Errors.EntitlementNotWhitelisted();
    }

    try UUPSUpgradeable(_entitlement).upgradeTo(_newEntitlement) {} catch {
      revert Errors.InvalidParameters();
    }
  }

  /// @inheritdoc ISpace
  function getEntitlementIdsByRoleId(
    uint256 _roleId
  ) external view returns (bytes32[] memory) {
    return entitlementIdsByRoleId[_roleId];
  }

  /// @inheritdoc ISpace
  function getEntitlementByModuleType(
    string memory _moduleType
  ) external view returns (address) {
    address _entitlement;

    for (uint256 i = 0; i < entitlements.length; i++) {
      if (
        Utils.isEqual(IEntitlement(entitlements[i]).moduleType(), _moduleType)
      ) {
        _entitlement = entitlements[i];
      }
    }

    return _entitlement;
  }

  /// @inheritdoc ISpace
  function isEntitledToChannel(
    string calldata _channelNetworkId,
    address _user,
    string calldata _permission
  ) external view returns (bool _entitled) {
    // check that a _channelNetworkId is not empty
    if (
      bytes(_channelNetworkId).length == 0 ||
      bytes(_permission).length == 0 ||
      _user == address(0)
    ) {
      revert Errors.InvalidParameters();
    }

    bytes32 channelHash = keccak256(abi.encodePacked(_channelNetworkId));

    if (channelsByHash[channelHash].channelHash == 0) {
      revert Errors.ChannelDoesNotExist();
    }

    // check if channel is disabled
    if (channelsByHash[channelHash].disabled) {
      revert Errors.NotAllowed();
    }

    for (uint256 i = 0; i < entitlements.length; i++) {
      if (
        _isEntitled(
          _channelNetworkId,
          _user,
          bytes32(abi.encodePacked(_permission))
        )
      ) {
        _entitled = true;
      }
    }
  }

  /// @inheritdoc ISpace
  function isEntitledToSpace(
    address _user,
    string calldata _permission
  ) external view returns (bool _entitled) {
    for (uint256 i = 0; i < entitlements.length; i++) {
      if (
        _isEntitled(IN_SPACE, _user, bytes32(abi.encodePacked(_permission)))
      ) {
        _entitled = true;
      }
    }
  }

  function getChannels() external view returns (bytes32[] memory) {
    return channels;
  }

  /// @inheritdoc ISpace
  function getEntitlementModules()
    external
    view
    returns (DataTypes.EntitlementModule[] memory _entitlementModules)
  {
    _entitlementModules = new DataTypes.EntitlementModule[](
      entitlements.length
    );

    for (uint256 i = 0; i < entitlements.length; i++) {
      IEntitlement _entitlementModule = IEntitlement(entitlements[i]);

      _entitlementModules[i] = DataTypes.EntitlementModule({
        name: _entitlementModule.name(),
        moduleAddress: entitlements[i],
        moduleType: _entitlementModule.moduleType(),
        enabled: hasEntitlement[entitlements[i]]
      });
    }
  }

  /// @inheritdoc ISpace
  function setEntitlementModule(
    address _entitlementModule,
    bool _whitelist
  ) external {
    _isAllowed(IN_SPACE, Permissions.Owner);

    // validate entitlement interface
    _validateEntitlementInterface(_entitlementModule);

    // check if entitlement already exists
    if (_whitelist && hasEntitlement[_entitlementModule]) {
      revert Errors.EntitlementAlreadyWhitelisted();
    }

    // check if removing a default entitlement
    if (!_whitelist && defaultEntitlements[_entitlementModule]) {
      revert Errors.NotAllowed();
    }

    _setEntitlement(_entitlementModule, _whitelist);
  }

  /// @inheritdoc ISpace
  function removeRoleFromEntitlement(
    uint256 _roleId,
    DataTypes.Entitlement calldata _entitlement
  ) external {
    _isAllowed(IN_SPACE, Permissions.ModifySpaceSettings);

    // check not removing owner role
    if (_roleId == ownerRoleId) {
      revert Errors.NotAllowed();
    }

    // check if entitlement is whitelisted
    if (!hasEntitlement[_entitlement.module]) {
      revert Errors.EntitlementNotWhitelisted();
    }

    // check roleid exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    // create entitlement id
    bytes32 entitlementId = keccak256(
      abi.encodePacked(_roleId, _entitlement.data)
    );

    // remove entitlementId from entitlementIdsByRoleId
    bytes32[] storage entitlementIds = entitlementIdsByRoleId[_roleId];
    for (uint256 i = 0; i < entitlementIds.length; i++) {
      if (entitlementId != entitlementIds[i]) continue;

      entitlementIds[i] = entitlementIds[entitlementIds.length - 1];
      entitlementIds.pop();
      break;
    }

    IEntitlement(_entitlement.module).removeEntitlement(
      _roleId,
      _entitlement.data
    );
  }

  /// @inheritdoc ISpace
  function addRoleToEntitlement(
    uint256 _roleId,
    DataTypes.Entitlement memory _entitlement
  ) external {
    _isAllowed(IN_SPACE, Permissions.ModifySpaceSettings);

    if (!hasEntitlement[_entitlement.module]) {
      revert Errors.EntitlementNotWhitelisted();
    }

    // check that role id exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    // check not adding entitlements to owner role
    if (_roleId == ownerRoleId) {
      revert Errors.NotAllowed();
    }

    _addRoleToEntitlementModule(
      _roleId,
      _entitlement.module,
      _entitlement.data
    );
  }

  /// @inheritdoc ISpace
  function addRoleToChannel(
    string calldata _channelNetworkId,
    address _entitlement,
    uint256 _roleId
  ) external {
    _isAllowed(_channelNetworkId, Permissions.AddRemoveChannels);

    if (!hasEntitlement[_entitlement]) {
      revert Errors.EntitlementNotWhitelisted();
    }

    // check that role id exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    IEntitlement(_entitlement).addRoleIdToChannel(_channelNetworkId, _roleId);
  }

  /// @inheritdoc ISpace
  function removeRoleFromChannel(
    string calldata _channelNetworkId,
    address _entitlement,
    uint256 _roleId
  ) external {
    _isAllowed(_channelNetworkId, Permissions.AddRemoveChannels);

    if (!hasEntitlement[_entitlement]) {
      revert Errors.EntitlementNotWhitelisted();
    }

    // check that role id exists
    if (rolesById[_roleId].roleId == 0) {
      revert Errors.RoleDoesNotExist();
    }

    IEntitlement(_entitlement).removeRoleIdFromChannel(
      _channelNetworkId,
      _roleId
    );
  }

  /// ***** Internal *****
  function _addRoleToEntitlementModule(
    uint256 _roleId,
    address _entitlement,
    bytes memory _entitlementData
  ) internal {
    bytes32 entitlementId = keccak256(
      abi.encodePacked(_roleId, _entitlementData)
    );

    // check that entitlementId does not already exist
    // this is to prevent duplicate entries
    // but could lead to wanting to use the same entitlement data and role id
    // on different entitlement contracts
    bytes32[] memory entitlementIds = entitlementIdsByRoleId[_roleId];
    for (uint256 i = 0; i < entitlementIds.length; i++) {
      if (entitlementIds[i] == entitlementId) {
        revert Errors.EntitlementAlreadyExists();
      }
    }

    // keep track of which entitlements are associated with a role
    entitlementIdsByRoleId[_roleId].push(entitlementId);

    IEntitlement(_entitlement).setEntitlement(_roleId, _entitlementData);
  }

  function _isOwner() internal view returns (bool) {
    return IERC721(token).ownerOf(tokenId) == _msgSender();
  }

  function _isAllowed(
    string memory _channelNetworkId,
    string memory _permission
  ) internal view {
    if (
      _isOwner() ||
      (!disabled &&
        _isEntitled(
          _channelNetworkId,
          _msgSender(),
          bytes32(abi.encodePacked(_permission))
        ))
    ) {
      return;
    } else {
      revert Errors.NotAllowed();
    }
  }

  function _setEntitlement(address _entitlement, bool _whitelist) internal {
    // set entitlement on mapping
    hasEntitlement[_entitlement] = _whitelist;

    // if user wants to whitelist, add to entitlements array
    if (_whitelist) {
      entitlements.push(_entitlement);
    } else {
      // remove from entitlements array
      for (uint256 i = 0; i < entitlements.length; i++) {
        if (_entitlement != entitlements[i]) continue;
        entitlements[i] = entitlements[entitlements.length - 1];
        entitlements.pop();
        break;
      }
    }
  }

  function _isEntitled(
    string memory _channelNetworkId,
    address _user,
    bytes32 _permission
  ) internal view returns (bool _entitled) {
    for (uint256 i = 0; i < entitlements.length; i++) {
      if (
        IEntitlement(entitlements[i]).isEntitled(
          _channelNetworkId,
          _user,
          _permission
        )
      ) {
        _entitled = true;
      }
    }
  }

  function _ownerRoleIsSet() internal view returns (bool) {
    return ownerRoleId != 0;
  }

  function _validateEntitlementInterface(
    address entitlementAddress
  ) internal view {
    if (
      IERC165(entitlementAddress).supportsInterface(
        type(IEntitlement).interfaceId
      ) == false
    ) revert Errors.EntitlementModuleNotSupported();
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlySpaceOwner {}
}

//SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import {DataTypes} from "contracts/src/libraries/DataTypes.sol";

interface IEntitlement {
  /// @notice The name of the entitlement module
  function name() external view returns (string memory);

  /// @notice The type of the entitlement module
  function moduleType() external view returns (string memory);

  /// @notice The description of the entitlement module
  function description() external view returns (string memory);

  function initialize(address _tokenAddress, uint256 _tokenId) external;

  /// @notice sets the address for the space that controls this entitlement
  /// @param _space address of the space
  function setSpace(address _space) external;

  /// @notice sets a new entitlement
  /// @param roleId id of the role to gate
  /// @param entitlementData abi encoded array of data necessary to set the entitlement
  /// @return entitlementId the id that was set
  function setEntitlement(
    uint256 roleId,
    bytes calldata entitlementData
  ) external returns (bytes32);

  /// @notice removes an entitlement
  /// @param roleId id of the role to remove
  /// @param entitlementData abi encoded array of the data associated with that entitlement
  /// @return entitlementId the id that was removed
  function removeEntitlement(
    uint256 roleId,
    bytes calldata entitlementData
  ) external returns (bytes32);

  /// @notice adds a role to a channel
  /// @param channelId id of the channel to add the role to
  /// @param roleId id of the role to add
  function addRoleIdToChannel(
    string calldata channelId,
    uint256 roleId
  ) external;

  /// @notice removes a role from a channel
  /// @param channelId id of the channel to remove the role from
  /// @param roleId id of the role to remove
  function removeRoleIdFromChannel(
    string calldata channelId,
    uint256 roleId
  ) external;

  /// @notice checks whether a user is has a given permission for a channel or a space
  /// @param channelId id of the channel to check, if empty string, checks space
  /// @param user address of the user to check
  /// @param permission the permission to check
  /// @return whether the user is entitled to the permission
  function isEntitled(
    string calldata channelId,
    address user,
    bytes32 permission
  ) external view returns (bool);

  /// @notice fetches the roleIds for a given channel
  /// @param channelId the channel to fetch the roleIds for
  /// @return roleIds array of all the roleIds for the channel
  function getRoleIdsByChannelId(
    string calldata channelId
  ) external view returns (uint256[] memory);

  /// @notice fetches the entitlement data for a roleId
  /// @param roleId the roleId to fetch the entitlement data for
  /// @return entitlementData array for the role
  function getEntitlementDataByRoleId(
    uint256 roleId
  ) external view returns (bytes[] memory);

  /// @notice fetches the roles for a given user in the space
  /// @param user the user to fetch the roles for
  /// @return roles array of all the roles for the user
  function getUserRoles(
    address user
  ) external view returns (DataTypes.Role[] memory);
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/DataTypes.sol";

interface ISpace {
  /// ***** Space Management *****
  /// @notice initializes a new Space
  /// @param name the name of the space
  /// @param networkId the network id of the space linking it to the dendrite/casablanca protocol
  /// @param modules the initial modules to be used by the space for gating
  function initialize(
    string memory name,
    string memory networkId,
    address[] memory modules,
    address token,
    uint256 tokenId
  ) external;

  /// @notice fetches the Space owner
  /// @return the address of the Space owner
  function owner() external view returns (address);

  /// @notice sets whether the space is disabled or not
  /// @param disabled whether to make the space disabled or not
  function setSpaceAccess(bool disabled) external;

  /// @notice sets a created roleId to be the owner role id for the Space
  /// @param roleId the roleId to be set as the owner role id
  function setOwnerRoleId(uint256 roleId) external;

  /// ***** Channel Management *****

  /// @notice fetches the Channel information by the hashed channelId
  /// @param channelHash the hashed channelId
  /// @return the Channel information
  function getChannelByHash(
    bytes32 channelHash
  ) external view returns (DataTypes.Channel memory);

  /// @notice sets whether the channel is disabled or not
  /// @param channelId the channelId to set the access for
  /// @param disabled whether to make the channel disabled or not
  function setChannelAccess(string calldata channelId, bool disabled) external;

  /// @notice creates a new channel for the space
  /// @param channelName the name of the channel
  /// @param channelNetworkId the network id of the channel linking it to the dendrite/casablanca protocol
  /// @param roleIds the roleIds to be set as the initial roles for the channel
  /// @return the channelId of the created channel
  function createChannel(
    string memory channelName,
    string memory channelNetworkId,
    uint256[] memory roleIds
  ) external returns (bytes32);

  /// @notice updates a channel name
  /// @param channelId the channelId to update
  /// @param channelName the new name of the channel
  function updateChannel(
    string calldata channelId,
    string memory channelName
  ) external;

  /// ***** Role Management *****
  /// @notice fetches the all the created roles for the space
  function getRoles() external view returns (DataTypes.Role[] memory);

  /// @notice creates a new role for the space
  /// @param roleName the name of the role
  /// @param permissions the permissions to be set for the role
  /// @param entitlements the initial entitlements to gate the role
  /// @return the roleId of the created role
  function createRole(
    string memory roleName,
    string[] memory permissions,
    DataTypes.Entitlement[] memory entitlements
  ) external returns (uint256);

  /// @notice updates a role name by roleId
  /// @param roleId the roleId to update
  /// @param roleName the new name of the role
  function updateRole(uint256 roleId, string memory roleName) external;

  /// @notice removes a role by roleId
  /// @param roleId the roleId to remove
  function removeRole(uint256 roleId) external;

  /// @notice fetches the role information by roleId
  /// @param roleId the roleId to fetch the role information for
  /// @return the role information
  function getRoleById(
    uint256 roleId
  ) external view returns (DataTypes.Role memory);

  /// ***** Permission Management *****
  /// @notice adds a permission to a role by roleId
  /// @param roleId the roleId to add the permission to
  /// @param permissions the permissions to add to the role
  function addPermissionsToRole(
    uint256 roleId,
    string[] memory permissions
  ) external;

  /// @notice fetches the permissions for a role by roleId
  /// @param roleId the roleId to fetch the permissions for
  /// @return permissions array for the role
  function getPermissionsByRoleId(
    uint256 roleId
  ) external view returns (string[] memory);

  /// @notice upgrades an entitlement module implementation
  /// @param _entitlement the current entitlement address
  /// @param _newEntitlement the new entitlement address
  function upgradeEntitlement(
    address _entitlement,
    address _newEntitlement
  ) external;

  /// @notice removes a permission from a role by roleId
  /// @param roleId the roleId to remove the permission from
  /// @param permissions the permissions to remove from the role
  function removePermissionsFromRole(
    uint256 roleId,
    string[] memory permissions
  ) external;

  /// ***** Entitlement Management *****
  /// @notice gets the entitlements for a given role
  /// @param roleId the roleId to fetch the entitlements for
  /// @return the entitlements for the role
  function getEntitlementIdsByRoleId(
    uint256 roleId
  ) external view returns (bytes32[] memory);

  /// @notice gets an entitlement address by its module type
  /// @param moduleType the module type to fetch the entitlement for
  /// @return the entitlement address
  /// @dev if two entitlements have the same name it will return the last one in the array
  function getEntitlementByModuleType(
    string memory moduleType
  ) external view returns (address);

  /// @notice checks if a user is entitled to a permission in a channel
  /// @param channelId the channelId to check the permission for
  /// @param user the user to check the permission for
  /// @param permission the permission to check
  /// @return whether the user is entitled to the permission in the channel
  function isEntitledToChannel(
    string calldata channelId,
    address user,
    string calldata permission
  ) external view returns (bool);

  /// @notice checks if a user is entitled to a permission in the space
  /// @param user the user to check the permission for
  /// @param permission the permission to check
  /// @return whether the user is entitled to the permission in the space
  function isEntitledToSpace(
    address user,
    string calldata permission
  ) external view returns (bool);

  /// @notice fetches all the channels for the space
  function getChannels() external view returns (bytes32[] memory);

  /// @notice fetches all the entitlements for the space
  /// @return entitlement modules array
  function getEntitlementModules()
    external
    view
    returns (DataTypes.EntitlementModule[] memory);

  /// @notice sets a new entitlement module for the space
  /// @param entitlementModule the address of the new entitlement
  /// @param whitelist whether to set the entitlement as activated or not
  function setEntitlementModule(
    address entitlementModule,
    bool whitelist
  ) external;

  /// @notice removes an entitlement from the space
  /// @param roleId the roleId to remove the entitlement from
  /// @param entitlement the address of the entitlement to remove
  function removeRoleFromEntitlement(
    uint256 roleId,
    DataTypes.Entitlement memory entitlement
  ) external;

  /// @notice adds a role to an entitlement
  /// @param roleId the roleId to add to the entitlement
  /// @param entitlement the address of the entitlement
  function addRoleToEntitlement(
    uint256 roleId,
    DataTypes.Entitlement memory entitlement
  ) external;

  /// @notice adds a role to a channel
  /// @param channelId the channelId to add the role to
  /// @param entitlement the address of the entitlement that we are adding the role to
  /// @param roleId the roleId to add to the channel
  function addRoleToChannel(
    string calldata channelId,
    address entitlement,
    uint256 roleId
  ) external;

  /// @notice removes a role from a channel
  /// @param channelId the channelId to remove the role from
  /// @param entitlement the address of the entitlement that we are removing the role from
  /// @param roleId the roleId to remove from the channel
  function removeRoleFromChannel(
    string calldata channelId,
    address entitlement,
    uint256 roleId
  ) external;
}

//SPDX-License-Identifier: Apache-20
pragma solidity 0.8.19;

/**
 * @title DataTypes
 * @author HNT Labs
 *
 * @notice A standard library of data types used throughout the Zion Space Manager
 */
library DataTypes {
  struct Channel {
    string name;
    string channelNetworkId;
    bytes32 channelHash;
    uint256 createdAt;
    bool disabled;
  }

  struct Role {
    uint256 roleId;
    string name;
  }

  struct Entitlement {
    address module;
    bytes data;
  }

  struct EntitlementModule {
    string name;
    address moduleAddress;
    string moduleType;
    bool enabled;
  }

  struct ExternalToken {
    address contractAddress;
    uint256 quantity;
    bool isSingleToken;
    uint256[] tokenIds;
  }

  /// *********************************
  /// **************DTO****************
  /// *********************************
  /// @notice A struct containing the parameters required for creating a space
  /// @param spaceName The name of the space
  /// @param networkId The network id of the space
  struct CreateSpaceData {
    string spaceName;
    string spaceNetworkId;
    string spaceMetadata;
  }

  /// @notice A struct containing the parameters required for creating a space with a  token entitlement
  struct CreateSpaceExtraEntitlements {
    //The role and permissions to create for the associated users or token entitlements
    string roleName;
    string[] permissions;
    ExternalToken[] tokens;
    address[] users;
  }
}

//SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

library Errors {
  error InvalidParameters();
  error NameLengthInvalid();
  error NameContainsInvalidCharacters();
  error SpaceAlreadyRegistered();
  error ChannelAlreadyRegistered();
  error NotSpaceOwner();
  error NotSpaceManager();
  error EntitlementNotFound();
  error AddressNotFound();
  error QuantityNotFound();
  error EntitlementAlreadyWhitelisted();
  error EntitlementModuleNotSupported();
  error EntitlementNotWhitelisted();
  error EntitlementAlreadyExists();
  error DefaultEntitlementModuleNotSet();
  error SpaceNFTNotSet();
  error RoleIsAssignedToEntitlement();
  error DefaultPermissionsManagerNotSet();
  error SpaceDoesNotExist();
  error ChannelDoesNotExist();
  error PermissionAlreadyExists();
  error NotAllowed();
  error MissingOwnerPermission();
  error RoleDoesNotExist();
  error RoleAlreadyExists();
  error AddRoleFailed();
}

//SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

library Events {
  event SpaceCreated(
    address indexed spaceAddress,
    address indexed ownerAddress,
    string networkId
  );

  event RoleCreated(
    address indexed caller,
    uint256 indexed roleId,
    string roleName,
    string networkId
  );

  event RoleUpdated(
    address indexed caller,
    uint256 indexed roleId,
    string roleName,
    string networkId
  );

  event RoleRemoved(
    address indexed caller,
    uint256 indexed roleId,
    string networkId
  );
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

library Permissions {
  string public constant Read = "Read";
  string public constant Write = "Write";
  string public constant Invite = "Invite";
  string public constant Redact = "Redact";
  string public constant Ban = "Ban";
  string public constant Ping = "Ping";
  string public constant PinMessage = "PinMessage";
  string public constant Owner = "Owner";
  string public constant AddRemoveChannels = "AddRemoveChannels";
  string public constant ModifySpaceSettings = "ModifySpaceSettings";
  string public constant Upgrade = "Upgrade";
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import {Errors} from "./Errors.sol";

library Utils {
  uint8 internal constant MIN_NAME_LENGTH = 2;
  uint8 internal constant MAX_NAME_LENGTH = 32;
  address public constant EVERYONE_ADDRESS =
    0x0000000000000000000000000000000000000001;

  function isEqual(
    string memory s1,
    string memory s2
  ) internal pure returns (bool) {
    return keccak256(abi.encode(s1)) == keccak256(abi.encode(s2));
  }

  function bytes32ToString(
    bytes32 _bytes32
  ) public pure returns (string memory) {
    uint8 i = 0;
    while (i < 32 && _bytes32[i] != 0) {
      i++;
    }
    bytes memory bytesArray = new bytes(i);
    for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
      bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
  }

  function validateLength(string memory name) internal pure {
    bytes memory byteName = bytes(name);
    if (byteName.length < MIN_NAME_LENGTH || byteName.length > MAX_NAME_LENGTH)
      revert Errors.NameLengthInvalid();
  }

  /// @notice validates the name of the space
  /// @param name The name of the space
  function validateName(string calldata name) internal pure {
    bytes memory byteName = bytes(name);

    if (byteName.length < MIN_NAME_LENGTH || byteName.length > MAX_NAME_LENGTH)
      revert Errors.NameLengthInvalid();

    uint256 byteNameLength = byteName.length;
    for (uint256 i = 0; i < byteNameLength; ) {
      if (
        (byteName[i] < "0" ||
          byteName[i] > "z" ||
          (byteName[i] > "9" && byteName[i] < "a")) &&
        byteName[i] != "." &&
        byteName[i] != "-" &&
        byteName[i] != "_" &&
        byteName[i] != " "
      ) revert Errors.NameContainsInvalidCharacters();
      unchecked {
        ++i;
      }
    }
  }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

/// @title MultiCaller
/// @notice Enables calling multiple methods in a single call to the contract
abstract contract MultiCaller {
  function multicall(
    bytes[] calldata data
  ) external returns (bytes[] memory results) {
    results = new bytes[](data.length);
    for (uint256 i = 0; i < data.length; i++) {
      (bool success, bytes memory result) = address(this).delegatecall(data[i]);

      if (!success) {
        revertFromReturnedData(result);
      }

      results[i] = result;
    }
  }

  /// Courtesy of: https://ethereum.stackexchange.com/a/123588/114815
  /// @dev Bubble up the revert from the returnedData (supports Panic, Error & Custom Errors)
  /// @notice This is needed in order to provide some human-readable revert message from a call
  /// @param returnedData Response of the call
  function revertFromReturnedData(bytes memory returnedData) internal pure {
    if (returnedData.length < 4) {
      // case 1: catch all
      revert("unhandled revert");
    } else {
      bytes4 errorSelector;
      assembly {
        errorSelector := mload(add(returnedData, 0x20))
      }
      if (
        errorSelector == bytes4(0x4e487b71) /* `seth sig "Panic(uint256)"` */
      ) {
        // case 2: Panic(uint256) (Defined since 0.8.0)
        // solhint-disable-next-line max-line-length
        // ref: https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require)
        string memory reason = "panicked: 0x__";
        uint errorCode;
        assembly {
          errorCode := mload(add(returnedData, 0x24))
          let reasonWord := mload(add(reason, 0x20))
          // [0..9] is converted to ['0'..'9']
          // [0xa..0xf] is not correctly converted to ['a'..'f']
          // but since panic code doesn't have those cases, we will ignore them for now!
          let e1 := add(and(errorCode, 0xf), 0x30)
          let e2 := shl(8, add(shr(4, and(errorCode, 0xf0)), 0x30))
          reasonWord := or(
            and(
              reasonWord,
              0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000
            ),
            or(e2, e1)
          )
          mstore(add(reason, 0x20), reasonWord)
        }
        revert(reason);
      } else {
        // case 3: Error(string) (Defined at least since 0.7.0)
        // case 4: Custom errors (Defined since 0.8.0)
        uint len = returnedData.length;
        assembly {
          revert(add(returnedData, 32), len)
        }
      }
    }
  }
}