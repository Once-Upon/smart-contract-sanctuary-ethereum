// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
interface IERC165Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
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

import "./math/MathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
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
            return toHexString(value, MathUpgradeable.log256(value) + 1);
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

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

/// @notice An error used to indicate that an action could not be completed because either the `msg.sender` or
///         `msg.origin` is not authorized.
error Unauthorized();

/// @notice An error used to indicate that an action could not be completed because the contract either already existed
///         or entered an illegal condition which is not recoverable from.
error IllegalState();

/// @notice An error used to indicate that an action could not be completed because of an illegal argument was passed
///         to the function.
error IllegalArgument();

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "./IERC20Minimal.sol";

/// @title  IERC20Burnable
/// @author Mellow Finance
interface IERC20Burnable is IERC20Minimal {
    /// @notice Burns `amount` tokens from the balance of `msg.sender`.
    ///
    /// @param amount The amount of tokens to burn.
    ///
    /// @return If burning the tokens was successful.
    function burn(uint256 amount) external returns (bool);

    /// @notice Burns `amount` tokens from `owner`'s balance.
    ///
    /// @param owner  The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    ///
    /// @return If burning the tokens was successful.
    function burnFrom(address owner, uint256 amount) external returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IERC20Metadata
/// @author Mellow Finance
interface IERC20Metadata {
    /// @notice Gets the name of the token.
    ///
    /// @return The name.
    function name() external view returns (string memory);

    /// @notice Gets the symbol of the token.
    ///
    /// @return The symbol.
    function symbol() external view returns (string memory);

    /// @notice Gets the number of decimals that the token has.
    ///
    /// @return The number of decimals.
    function decimals() external view returns (uint8);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IERC20Minimal
/// @author Mellow Finance
interface IERC20Minimal {
    /// @notice An event which is emitted when tokens are transferred between two parties.
    ///
    /// @param owner     The owner of the tokens from which the tokens were transferred.
    /// @param recipient The recipient of the tokens to which the tokens were transferred.
    /// @param amount    The amount of tokens which were transferred.
    event Transfer(address indexed owner, address indexed recipient, uint256 amount);

    /// @notice An event which is emitted when an approval is made.
    ///
    /// @param owner   The address which made the approval.
    /// @param spender The address which is allowed to transfer tokens on behalf of `owner`.
    /// @param amount  The amount of tokens that `spender` is allowed to transfer.
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @notice Gets the current total supply of tokens.
    ///
    /// @return The total supply.
    function totalSupply() external view returns (uint256);

    /// @notice Gets the balance of tokens that an account holds.
    ///
    /// @param account The account address.
    ///
    /// @return The balance of the account.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Gets the allowance that an owner has allotted for a spender.
    ///
    /// @param owner   The owner address.
    /// @param spender The spender address.
    ///
    /// @return The number of tokens that `spender` is allowed to transfer on behalf of `owner`.
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Transfers `amount` tokens from `msg.sender` to `recipient`.
    ///
    /// @notice Emits a {Transfer} event.
    ///
    /// @param recipient The address which will receive the tokens.
    /// @param amount    The amount of tokens to transfer.
    ///
    /// @return If the transfer was successful.
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Approves `spender` to transfer `amount` tokens on behalf of `msg.sender`.
    ///
    /// @notice Emits a {Approval} event.
    ///
    /// @param spender The address which is allowed to transfer tokens on behalf of `msg.sender`.
    /// @param amount  The amount of tokens that `spender` is allowed to transfer.
    ///
    /// @return If the approval was successful.
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers `amount` tokens from `owner` to `recipient` using an approval that `owner` gave to `msg.sender`.
    ///
    /// @notice Emits a {Approval} event.
    /// @notice Emits a {Transfer} event.
    ///
    /// @param owner     The address to transfer tokens from.
    /// @param recipient The address that will receive the tokens.
    /// @param amount    The amount of tokens to transfer.
    ///
    /// @return If the transfer was successful.
    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "./IERC20Minimal.sol";

/// @title  IERC20Mintable
/// @author Mellow Finance
interface IERC20Mintable is IERC20Minimal {
    /// @notice Mints `amount` tokens to `recipient`.
    ///
    /// @param recipient The address which will receive the minted tokens.
    /// @param amount    The amount of tokens to mint.
    ///
    /// @return If minting the tokens was successful.
    function mint(address recipient, uint256 amount) external returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IERC20TokenReceiver
/// @author Mellow Finance
interface IERC20TokenReceiver {
    /// @notice Informs implementors of this interface that an ERC20 token has been transferred.
    ///
    /// @param token The token that was transferred.
    /// @param value The amount of the token that was transferred.
    function onERC20Received(address token, uint256 value) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./IInterswapV1.sol";
import "../IRefineryV1.sol";
import "../IERC20TokenReceiver.sol";

/// @title  IInterswapBuffer
/// @author Mellow Finance
interface IInterswapBuffer is IERC20TokenReceiver {
  /// @notice Parameters used to define a given weighting schema.
  ///
  /// Weighting schemas can be used to generally weight assets in relation to an action or actions that will be taken.
  /// In the InterswapBuffer, there are 2 actions that require weighting schemas: `burnCredit` and `depositFunds`.
  ///
  /// `burnCredit` uses a weighting schema that determines which yield-tokens are targeted when burning credit from
  /// the `Account` controlled by the InterswapBuffer, via the `Refinery.donate` function.
  ///
  /// `depositFunds` uses a weighting schema that determines which yield-tokens are targeted when depositing
  /// underlying-tokens into the Refinery.
  struct Weighting {
    // The weights of the tokens used by the schema.
    mapping(address => uint256) weights;
    // The tokens used by the schema.
    address[] tokens;
    // The total weight of the schema (sum of the token weights).
    uint256 totalWeight;
  }

  /// @notice Emitted when the refinery is set.
  ///
  /// @param refinery The address of the refinery.
  event SetRefinery(address refinery);

  /// @notice Emitted when the amo is set.
  ///
  /// @param underlyingToken The address of the underlying token.
  /// @param amo             The address of the amo.
  event SetAmo(address underlyingToken, address amo);

  /// @notice Emitted when the the status of diverting to the amo is set for a given underlying token.
  ///
  /// @param underlyingToken The address of the underlying token.
  /// @param divert          Whether or not to divert funds to the amo.
  event SetDivertToAmo(address underlyingToken, bool divert);

  /// @notice Emitted when an underlying token is registered.
  ///
  /// @param underlyingToken The address of the underlying token.
  /// @param interswap      The address of the interswap for the underlying token.
  event RegisterAsset(address underlyingToken, address interswap);

  /// @notice Emitted when an underlying token's flow rate is updated.
  ///
  /// @param underlyingToken The underlying token.
  /// @param flowRate        The flow rate for the underlying token.
  event SetFlowRate(address underlyingToken, uint256 flowRate);

  /// @notice Emitted when the strategies are refreshed.
  event RefreshStrategies();

  /// @notice Emitted when a source is set.
  event SetSource(address source, bool flag);

  /// @notice Emitted when a interswap is updated.
  event SetInterswap(address underlyingToken, address interswap);

  /// @notice Gets the current version.
  ///
  /// @return The version.
  function version() external view returns (string memory);

  /// @notice Gets the total credit held by the InterswapBuffer.
  ///
  /// @return The total credit.
  function getTotalCredit() external view returns (uint256);

  /// @notice Gets the total amount of underlying token that the InterswapBuffer controls in the Refinery.
  ///
  /// @param underlyingToken The underlying token to query.
  ///
  /// @return totalBuffered The total buffered.
  function getTotalUnderlyingBuffered(address underlyingToken) external view returns (uint256 totalBuffered);

  /// @notice Gets the total available flow for the underlying token
  ///
  /// The total available flow will be the lesser of `flowAvailable[token]` and `getTotalUnderlyingBuffered`.
  ///
  /// @param underlyingToken The underlying token to query.
  ///
  /// @return availableFlow The available flow.
  function getAvailableFlow(address underlyingToken) external view returns (uint256 availableFlow);

  /// @notice Gets the weight of the given weight type and token
  ///
  /// @param weightToken The type of weight to query.
  /// @param token       The weighted token.
  ///
  /// @return weight The weight of the token for the given weight type.
  function getWeight(address weightToken, address token) external view returns (uint256 weight);

  /// @notice Set a source of funds.
  ///
  /// @param source The target source.
  /// @param flag   The status to set for the target source.
  function setSource(address source, bool flag) external;

  /// @notice Set interswap by admin.
  ///
  /// This function reverts if the caller is not the current admin.
  ///
  /// @param underlyingToken The target underlying token to update.
  /// @param newInterswap   The new interswap for the target `underlyingToken`.
  function setInterswap(address underlyingToken, address newInterswap) external;

  /// @notice Set refinery by admin.
  ///
  /// This function reverts if the caller is not the current admin.
  ///
  /// @param refinery The new refinery whose funds we are handling.
  function setRefinery(address refinery) external;

  /// @notice Set the address of the amo for a target underlying token.
  ///
  /// @param underlyingToken The address of the underlying token to set.
  /// @param amo The address of the underlying token's new amo.
  function setAmo(address underlyingToken, address amo) external;

  /// @notice Set whether or not to divert funds to the amo.
  ///
  /// @param underlyingToken The address of the underlying token to set.
  /// @param divert          Whether or not to divert underlying token to the amo.
  function setDivertToAmo(address underlyingToken, bool divert) external;

  /// @notice Refresh the yield-tokens in the InterswapBuffer.
  ///
  /// This requires a call anytime governance adds a new yield token to the refinery.
  function refreshStrategies() external;

  /// @notice Registers an underlying-token.
  ///
  /// This function reverts if the caller is not the current admin.
  ///
  /// @param underlyingToken The underlying-token being registered.
  /// @param interswap      The interswap for the underlying-token.
  function registerAsset(address underlyingToken, address interswap) external;

  /// @notice Set flow rate of an underlying token.
  ///
  /// This function reverts if the caller is not the current admin.
  ///
  /// @param underlyingToken The underlying-token getting the flow rate set.
  /// @param flowRate        The new flow rate.
  function setFlowRate(address underlyingToken, uint256 flowRate) external;

  /// @notice Sets up a weighting schema.
  ///
  /// @param weightToken The name of the weighting schema.
  /// @param tokens      The yield-tokens to weight.
  /// @param weights     The weights of the yield tokens.
  function setWeights(address weightToken, address[] memory tokens, uint256[] memory weights) external;

  /// @notice Exchanges any available flow into the Interswap.
  ///
  /// This function is a way for the keeper to force funds to be exchanged into the Interswap.
  ///
  /// This function will revert if called by any account that is not a keeper. If there is not enough local balance of
  /// `underlyingToken` held by the InterswapBuffer any additional funds will be withdrawn from the Refinery by
  /// unwrapping `yieldToken`.
  ///
  /// @param underlyingToken The address of the underlying token to exchange.
  function exchange(address underlyingToken) external;

  /// @notice Flushes funds to the amo.
  ///
  /// @param underlyingToken The underlying token to flush.
  /// @param amount          The amount to flush.
  function flushToAmo(address underlyingToken, uint256 amount) external;

  /// @notice Burns available credit in the refinery.
  function burnCredit() external;

  /// @notice Deposits local collateral into the refinery
  ///
  /// @param underlyingToken The collateral to deposit.
  /// @param amount          The amount to deposit.
  function depositFunds(address underlyingToken, uint256 amount) external;

  /// @notice Withdraws collateral from the refinery
  ///
  /// This function reverts if:
  /// - The caller is not the interswap.
  /// - There is not enough flow available to fulfill the request.
  /// - There is not enough underlying collateral in the refinery controlled by the buffer to fulfil the request.
  ///
  /// @param underlyingToken The underlying token to withdraw.
  /// @param amount          The amount to withdraw.
  /// @param recipient       The account receiving the withdrawn funds.
  function withdraw(
    address underlyingToken,
    uint256 amount,
    address recipient
  ) external;

  /// @notice Withdraws collateral from the refinery
  ///
  /// @param yieldToken       The yield token to withdraw.
  /// @param shares           The amount of Refinery shares to withdraw.
  /// @param minimumAmountOut The minimum amount of underlying tokens needed to be recieved as a result of unwrapping the yield tokens.
  function withdrawFromRefinery(
    address yieldToken,
    uint256 shares,
    uint256 minimumAmountOut
  ) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

/// @title IInterswapV1
/// @author Mellow Finance
interface IInterswapV1 {
  /// @notice Emitted when the admin address is updated.
  ///
  /// @param admin The new admin address.
  event AdminUpdated(address admin);

  /// @notice Emitted when the pending admin address is updated.
  ///
  /// @param pendingAdmin The new pending admin address.
  event PendingAdminUpdated(address pendingAdmin);

  /// @notice Emitted when the system is paused or unpaused.
  ///
  /// @param flag `true` if the system has been paused, `false` otherwise.
  event Paused(bool flag);

  /// @dev Emitted when a deposit is performed.
  ///
  /// @param sender The address of the depositor.
  /// @param owner  The address of the account that received the deposit.
  /// @param amount The amount of tokens deposited.
  event Deposit(
    address indexed sender,
    address indexed owner,
    uint256 amount
  );

  /// @dev Emitted when a withdraw is performed.
  ///
  /// @param sender    The address of the `msg.sender` executing the withdraw.
  /// @param recipient The address of the account that received the withdrawn tokens.
  /// @param amount    The amount of tokens withdrawn.
  event Withdraw(
    address indexed sender,
    address indexed recipient,
    uint256 amount
  );

  /// @dev Emitted when a claim is performed.
  ///
  /// @param sender    The address of the claimer / account owner.
  /// @param recipient The address of the account that received the claimed tokens.
  /// @param amount    The amount of tokens claimed.
  event Claim(
    address indexed sender,
    address indexed recipient,
    uint256 amount
  );

  /// @dev Emitted when an exchange is performed.
  ///
  /// @param sender The address that called `exchange()`.
  /// @param amount The amount of tokens exchanged.
  event Exchange(
    address indexed sender,
    uint256 amount
  );

  /// @notice Gets the version.
  ///
  /// @return The version.
  function version() external view returns (string memory);

  /// @dev Gets the supported underlying token.
  ///
  /// @return The underlying token.
  function underlyingToken() external view returns (address);

  /// @notice Gets the address of the whitelist contract.
  ///
  /// @return whitelist The address of the whitelist contract.
  function whitelist() external view returns (address whitelist);

  /// @dev Gets the unexchanged balance of an account.
  ///
  /// @param owner The address of the account owner.
  ///
  /// @return The unexchanged balance.
  function getUnexchangedBalance(address owner) external view returns (uint256);

  /// @dev Gets the exchanged balance of an account, in units of `debtToken`.
  ///
  /// @param owner The address of the account owner.
  ///
  /// @return The exchanged balance.
  function getExchangedBalance(address owner) external view returns (uint256);

  /// @dev Gets the claimable balance of an account, in units of `underlyingToken`.
  ///
  /// @param owner The address of the account owner.
  ///
  /// @return The claimable balance.
  function getClaimableBalance(address owner) external view returns (uint256);

  /// @dev The conversion factor used to convert between underlying token amounts and debt token amounts.
  ///
  /// @return The coversion factor.
  function conversionFactor() external view returns (uint256);

  /// @dev Deposits tokens to be exchanged into an account.
  ///
  /// @param amount The amount of tokens to deposit.
  /// @param owner  The owner of the account to deposit the tokens into.
  function deposit(uint256 amount, address owner) external;

  /// @dev Withdraws tokens from the caller's account that were previously deposited to be exchanged.
  ///
  /// @param amount    The amount of tokens to withdraw.
  /// @param recipient The address which will receive the withdrawn tokens.
  function withdraw(uint256 amount, address recipient) external;

  /// @dev Claims exchanged tokens.
  ///
  /// @param amount    The amount of tokens to claim.
  /// @param recipient The address which will receive the claimed tokens.
  function claim(uint256 amount, address recipient) external;

  /// @dev Exchanges `amount` underlying tokens for `amount` synthetic tokens staked in the system.
  ///
  /// @param amount The amount of tokens to exchange.
  function exchange(uint256 amount) external;
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "./refinery/IRefineryV1Actions.sol";
import "./refinery/IRefineryV1AdminActions.sol";
import "./refinery/IRefineryV1Errors.sol";
import "./refinery/IRefineryV1Immutables.sol";
import "./refinery/IRefineryV1Events.sol";
import "./refinery/IRefineryV1State.sol";

/// @title  IRefineryV1
/// @author Mellow Finance
interface IRefineryV1 is
    IRefineryV1Actions,
    IRefineryV1AdminActions,
    IRefineryV1Errors,
    IRefineryV1Immutables,
    IRefineryV1Events,
    IRefineryV1State
{ }

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../base/Errors.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/Sets.sol";

/// @title  Whitelist
/// @author Mellow Finance
interface IWhitelist {
  /// @dev Emitted when a contract is added to the whitelist.
  ///
  /// @param account The account that was added to the whitelist.
  event AccountAdded(address account);

  /// @dev Emitted when a contract is removed from the whitelist.
  ///
  /// @param account The account that was removed from the whitelist.
  event AccountRemoved(address account);

  /// @dev Emitted when the whitelist is deactivated.
  event WhitelistDisabled();

  /// @dev Returns the list of addresses that are whitelisted for the given contract address.
  ///
  /// @return addresses The addresses that are whitelisted to interact with the given contract.
  function getAddresses() external view returns (address[] memory addresses);

  /// @dev Returns the disabled status of a given whitelist.
  ///
  /// @return disabled A flag denoting if the given whitelist is disabled.
  function disabled() external view returns (bool);

  /// @dev Adds an contract to the whitelist.
  ///
  /// @param caller The address to add to the whitelist.
  function add(address caller) external;

  /// @dev Adds a contract to the whitelist.
  ///
  /// @param caller The address to remove from the whitelist.
  function remove(address caller) external;

  /// @dev Disables the whitelist of the target whitelisted contract.
  ///
  /// This can only occur once. Once the whitelist is disabled, then it cannot be reenabled.
  function disable() external;

  /// @dev Checks that the `msg.sender` is whitelisted when it is not an EOA.
  ///
  /// @param account The account to check.
  ///
  /// @return whitelisted A flag denoting if the given account is whitelisted.
  function isWhitelisted(address account) external view returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IRefineryV1Actions
/// @author Mellow Finance
///
/// @notice Specifies user actions.
interface IRefineryV1Actions {
    /// @notice Approve `spender` to mint `amount` debt tokens.
    ///
    /// **_NOTE:_** This function is WHITELISTED.
    ///
    /// @param spender The address that will be approved to mint.
    /// @param amount  The amount of tokens that `spender` will be allowed to mint.
    function approveMint(address spender, uint256 amount) external;

    /// @notice Approve `spender` to withdraw `amount` shares of `yieldToken`.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @param spender    The address that will be approved to withdraw.
    /// @param yieldToken The address of the yield token that `spender` will be allowed to withdraw.
    /// @param shares     The amount of shares that `spender` will be allowed to withdraw.
    function approveWithdraw(
        address spender,
        address yieldToken,
        uint256 shares
    ) external;

    /// @notice Synchronizes the state of the account owned by `owner`.
    ///
    /// @param owner The owner of the account to synchronize.
    function poke(address owner) external;

    /// @notice Deposit a yield token into a user's account.
    ///
    /// @notice An approval must be set for `yieldToken` which is greater than `amount`.
    ///
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice `yieldToken` must be enabled or this call will revert with a {TokenDisabled} error.
    /// @notice `yieldToken` underlying token must be enabled or this call will revert with a {TokenDisabled} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or the call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {Deposit} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **_NOTE:_** When depositing, the `RefineryV1` contract must have **allowance()** to spend funds on behalf of **msg.sender** for at least **amount** of the **yieldToken** being deposited.  This can be done via the standard `ERC20.approve()` method.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 amount = 50000;
    /// @notice IERC20(ydai).approve(alchemistAddress, amount);
    /// @notice RefineryV1(alchemistAddress).deposit(ydai, amount, msg.sender);
    /// @notice ```
    ///
    /// @param yieldToken The yield-token to deposit.
    /// @param amount     The amount of yield tokens to deposit.
    /// @param recipient  The owner of the account that will receive the resulting shares.
    ///
    /// @return sharesIssued The number of shares issued to `recipient`.
    function deposit(
        address yieldToken,
        uint256 amount,
        address recipient
    ) external returns (uint256 sharesIssued);

    /// @notice Deposit an underlying token into the account of `recipient` as `yieldToken`.
    ///
    /// @notice An approval must be set for the underlying token of `yieldToken` which is greater than `amount`.
    ///
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or the call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {Deposit} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    /// @notice **_NOTE:_** When depositing, the `RefineryV1` contract must have **allowance()** to spend funds on behalf of **msg.sender** for at least **amount** of the **underlyingToken** being deposited.  This can be done via the standard `ERC20.approve()` method.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 amount = 50000;
    /// @notice RefineryV1(alchemistAddress).depositUnderlying(ydai, amount, msg.sender, 1);
    /// @notice ```
    ///
    /// @param yieldToken       The address of the yield token to wrap the underlying tokens into.
    /// @param amount           The amount of the underlying token to deposit.
    /// @param recipient        The address of the recipient.
    /// @param minimumAmountOut The minimum amount of yield tokens that are expected to be deposited to `recipient`.
    ///
    /// @return sharesIssued The number of shares issued to `recipient`.
    function depositUnderlying(
        address yieldToken,
        uint256 amount,
        address recipient,
        uint256 minimumAmountOut
    ) external returns (uint256 sharesIssued);

    /// @notice Withdraw yield tokens to `recipient` by burning `share` shares. The number of yield tokens withdrawn to `recipient` will depend on the value of shares for that yield token at the time of the call.
    ///
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {Withdraw} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 pps = RefineryV1(alchemistAddress).getYieldTokensPerShare(ydai);
    /// @notice uint256 amtYieldTokens = 5000;
    /// @notice RefineryV1(alchemistAddress).withdraw(ydai, amtYieldTokens / pps, msg.sender);
    /// @notice ```
    ///
    /// @param yieldToken The address of the yield token to withdraw.
    /// @param shares     The number of shares to burn.
    /// @param recipient  The address of the recipient.
    ///
    /// @return amountWithdrawn The number of yield tokens that were withdrawn to `recipient`.
    function withdraw(
        address yieldToken,
        uint256 shares,
        address recipient
    ) external returns (uint256 amountWithdrawn);

    /// @notice Withdraw yield tokens to `recipient` by burning `share` shares from the account of `owner`
    ///
    /// @notice `owner` must have an withdrawal allowance which is greater than `amount` for this call to succeed.
    ///
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {Withdraw} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 pps = RefineryV1(alchemistAddress).getYieldTokensPerShare(ydai);
    /// @notice uint256 amtYieldTokens = 5000;
    /// @notice RefineryV1(alchemistAddress).withdrawFrom(msg.sender, ydai, amtYieldTokens / pps, msg.sender);
    /// @notice ```
    ///
    /// @param owner      The address of the account owner to withdraw from.
    /// @param yieldToken The address of the yield token to withdraw.
    /// @param shares     The number of shares to burn.
    /// @param recipient  The address of the recipient.
    ///
    /// @return amountWithdrawn The number of yield tokens that were withdrawn to `recipient`.
    function withdrawFrom(
        address owner,
        address yieldToken,
        uint256 shares,
        address recipient
    ) external returns (uint256 amountWithdrawn);

    /// @notice Withdraw underlying tokens to `recipient` by burning `share` shares and unwrapping the yield tokens that the shares were redeemed for.
    ///
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice The loss in expected value of `yieldToken` must be less than the maximum permitted by the system or this call will revert with a {LossExceeded} error.
    ///
    /// @notice Emits a {Withdraw} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    /// @notice **_NOTE:_** The caller of `withdrawFrom()` must have **withdrawAllowance()** to withdraw funds on behalf of **owner** for at least the amount of `yieldTokens` that **shares** will be converted to.  This can be done via the `approveWithdraw()` or `permitWithdraw()` methods.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 pps = RefineryV1(alchemistAddress).getUnderlyingTokensPerShare(ydai);
    /// @notice uint256 amountUnderlyingTokens = 5000;
    /// @notice RefineryV1(alchemistAddress).withdrawUnderlying(ydai, amountUnderlyingTokens / pps, msg.sender, 1);
    /// @notice ```
    ///
    /// @param yieldToken       The address of the yield token to withdraw.
    /// @param shares           The number of shares to burn.
    /// @param recipient        The address of the recipient.
    /// @param minimumAmountOut The minimum amount of underlying tokens that are expected to be withdrawn to `recipient`.
    ///
    /// @return amountWithdrawn The number of underlying tokens that were withdrawn to `recipient`.
    function withdrawUnderlying(
        address yieldToken,
        uint256 shares,
        address recipient,
        uint256 minimumAmountOut
    ) external returns (uint256 amountWithdrawn);

    /// @notice Withdraw underlying tokens to `recipient` by burning `share` shares from the account of `owner` and unwrapping the yield tokens that the shares were redeemed for.
    ///
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice The loss in expected value of `yieldToken` must be less than the maximum permitted by the system or this call will revert with a {LossExceeded} error.
    ///
    /// @notice Emits a {Withdraw} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    /// @notice **_NOTE:_** The caller of `withdrawFrom()` must have **withdrawAllowance()** to withdraw funds on behalf of **owner** for at least the amount of `yieldTokens` that **shares** will be converted to.  This can be done via the `approveWithdraw()` or `permitWithdraw()` methods.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 pps = RefineryV1(alchemistAddress).getUnderlyingTokensPerShare(ydai);
    /// @notice uint256 amtUnderlyingTokens = 5000 * 10**ydai.decimals();
    /// @notice RefineryV1(alchemistAddress).withdrawUnderlying(msg.sender, ydai, amtUnderlyingTokens / pps, msg.sender, 1);
    /// @notice ```
    ///
    /// @param owner            The address of the account owner to withdraw from.
    /// @param yieldToken       The address of the yield token to withdraw.
    /// @param shares           The number of shares to burn.
    /// @param recipient        The address of the recipient.
    /// @param minimumAmountOut The minimum amount of underlying tokens that are expected to be withdrawn to `recipient`.
    ///
    /// @return amountWithdrawn The number of underlying tokens that were withdrawn to `recipient`.
    function withdrawUnderlyingFrom(
        address owner,
        address yieldToken,
        uint256 shares,
        address recipient,
        uint256 minimumAmountOut
    ) external returns (uint256 amountWithdrawn);

    /// @notice Mint `amount` debt tokens.
    ///
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    ///
    /// @notice Emits a {Mint} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice uint256 amtDebt = 5000;
    /// @notice RefineryV1(alchemistAddress).mint(amtDebt, msg.sender);
    /// @notice ```
    ///
    /// @param amount    The amount of tokens to mint.
    /// @param recipient The address of the recipient.
    function mint(uint256 amount, address recipient) external;

    /// @notice Mint `amount` debt tokens from the account owned by `owner` to `recipient`.
    ///
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    ///
    /// @notice Emits a {Mint} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    /// @notice **_NOTE:_** The caller of `mintFrom()` must have **mintAllowance()** to mint debt from the `Account` controlled by **owner** for at least the amount of **yieldTokens** that **shares** will be converted to.  This can be done via the `approveMint()` or `permitMint()` methods.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice uint256 amtDebt = 5000;
    /// @notice RefineryV1(alchemistAddress).mintFrom(msg.sender, amtDebt, msg.sender);
    /// @notice ```
    ///
    /// @param owner     The address of the owner of the account to mint from.
    /// @param amount    The amount of tokens to mint.
    /// @param recipient The address of the recipient.
    function mintFrom(
        address owner,
        uint256 amount,
        address recipient
    ) external;

    /// @notice Burn `amount` debt tokens to credit the account owned by `recipient`.
    ///
    /// @notice `amount` will be limited up to the amount of debt that `recipient` currently holds.
    ///
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    /// @notice `recipient` must have non-zero debt or this call will revert with an {IllegalState} error.
    ///
    /// @notice Emits a {Burn} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice uint256 amtBurn = 5000;
    /// @notice RefineryV1(alchemistAddress).burn(amtBurn, msg.sender);
    /// @notice ```
    ///
    /// @param amount    The amount of tokens to burn.
    /// @param recipient The address of the recipient.
    ///
    /// @return amountBurned The amount of tokens that were burned.
    function burn(uint256 amount, address recipient) external returns (uint256 amountBurned);

    /// @notice Repay `amount` debt using `underlyingToken` to credit the account owned by `recipient`.
    ///
    /// @notice `amount` will be limited up to the amount of debt that `recipient` currently holds.
    ///
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    /// @notice `recipient` must be non-zero or this call will revert with an {IllegalArgument} error.
    /// @notice `underlyingToken` must be enabled or this call will revert with a {TokenDisabled} error.
    /// @notice `amount` must be less than or equal to the current available repay limit or this call will revert with a {ReplayLimitExceeded} error.
    ///
    /// @notice Emits a {Repay} event.
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address dai = 0x6b175474e89094c44da98b954eedeac495271d0f;
    /// @notice uint256 amtRepay = 5000;
    /// @notice RefineryV1(alchemistAddress).repay(dai, amtRepay, msg.sender);
    /// @notice ```
    ///
    /// @param underlyingToken The address of the underlying token to repay.
    /// @param amount          The amount of the underlying token to repay.
    /// @param recipient       The address of the recipient which will receive credit.
    ///
    /// @return amountRepaid The amount of tokens that were repaid.
    function repay(
        address underlyingToken,
        uint256 amount,
        address recipient
    ) external returns (uint256 amountRepaid);

    /// @notice
    ///
    /// @notice `shares` will be limited up to an equal amount of debt that `recipient` currently holds.
    ///
    /// @notice `shares` must be greater than zero or this call will revert with a {IllegalArgument} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice `yieldToken` must be enabled or this call will revert with a {TokenDisabled} error.
    /// @notice `yieldToken` underlying token must be enabled or this call will revert with a {TokenDisabled} error.
    /// @notice The loss in expected value of `yieldToken` must be less than the maximum permitted by the system or this call will revert with a {LossExceeded} error.
    /// @notice `amount` must be less than or equal to the current available liquidation limit or this call will revert with a {LiquidationLimitExceeded} error.
    ///
    /// @notice Emits a {Liquidate} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 amtSharesLiquidate = 5000 * 10**ydai.decimals();
    /// @notice RefineryV1(alchemistAddress).liquidate(ydai, amtSharesLiquidate, 1);
    /// @notice ```
    ///
    /// @param yieldToken       The address of the yield token to liquidate.
    /// @param shares           The number of shares to burn for credit.
    /// @param minimumAmountOut The minimum amount of underlying tokens that are expected to be liquidated.
    ///
    /// @return sharesLiquidated The amount of shares that were liquidated.
    function liquidate(
        address yieldToken,
        uint256 shares,
        uint256 minimumAmountOut
    ) external returns (uint256 sharesLiquidated);

    /// @notice Burns `amount` debt tokens to credit accounts which have deposited `yieldToken`.
    ///
    /// @notice `amount` must be greater than zero or this call will revert with a {IllegalArgument} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @notice Emits a {Donate} event.
    ///
    /// @notice **_NOTE:_** This function is WHITELISTED.
    ///
    /// @notice **Example:**
    /// @notice ```
    /// @notice address ydai = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    /// @notice uint256 amtSharesLiquidate = 5000;
    /// @notice RefineryV1(alchemistAddress).liquidate(dai, amtSharesLiquidate, 1);
    /// @notice ```
    ///
    /// @param yieldToken The address of the yield token to credit accounts for.
    /// @param amount     The amount of debt tokens to burn.
    function donate(address yieldToken, uint256 amount) external;

    /// @notice Harvests outstanding yield that a yield token has accumulated and distributes it as credit to holders.
    ///
    /// @notice `msg.sender` must be a keeper or this call will revert with an {Unauthorized} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice The amount being harvested must be greater than zero or else this call will revert with an {IllegalState} error.
    ///
    /// @notice Emits a {Harvest} event.
    ///
    /// @param yieldToken       The address of the yield token to harvest.
    /// @param minimumAmountOut The minimum amount of underlying tokens that are expected to be withdrawn to `recipient`.
    function harvest(address yieldToken, uint256 minimumAmountOut) external;
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IRefineryV1AdminActions
/// @author Mellow Finance
///
/// @notice Specifies admin and or sentinel actions.
interface IRefineryV1AdminActions {
    /// @notice Contract initialization parameters.
    struct InitializationParams {
        // The initial admin account.
        address admin;
        // The ERC20 token used to represent debt.
        address debtToken;
        // The initial interswap or interswap buffer.
        address interswap;
        // The minimum collateralization ratio that an account must maintain.
        uint256 minimumCollateralization;
        // The percentage fee taken from each harvest measured in units of basis points.
        uint256 protocolFee;
        // The address that receives protocol fees.
        address protocolFeeReceiver;
        // A limit used to prevent administrators from making minting functionality inoperable.
        uint256 mintingLimitMinimum;
        // The maximum number of tokens that can be minted per period of time.
        uint256 mintingLimitMaximum;
        // The number of blocks that it takes for the minting limit to be refreshed.
        uint256 mintingLimitBlocks;
        // The address of the whitelist.
        address whitelist;
    }

    /// @notice Configuration parameters for an underlying token.
    struct UnderlyingTokenConfig {
        // A limit used to prevent administrators from making repayment functionality inoperable.
        uint256 repayLimitMinimum;
        // The maximum number of underlying tokens that can be repaid per period of time.
        uint256 repayLimitMaximum;
        // The number of blocks that it takes for the repayment limit to be refreshed.
        uint256 repayLimitBlocks;
        // A limit used to prevent administrators from making liquidation functionality inoperable.
        uint256 liquidationLimitMinimum;
        // The maximum number of underlying tokens that can be liquidated per period of time.
        uint256 liquidationLimitMaximum;
        // The number of blocks that it takes for the liquidation limit to be refreshed.
        uint256 liquidationLimitBlocks;
    }

    /// @notice Configuration parameters of a yield token.
    struct YieldTokenConfig {
        // The adapter used by the system to interop with the token.
        address adapter;
        // The maximum percent loss in expected value that can occur before certain actions are disabled measured in
        // units of basis points.
        uint256 maximumLoss;
        // The maximum value that can be held by the system before certain actions are disabled measured in the
        // underlying token.
        uint256 maximumExpectedValue;
        // The number of blocks that credit will be distributed over to depositors.
        uint256 creditUnlockBlocks;
    }

    /// @notice Initialize the contract.
    ///
    /// @notice `params.protocolFee` must be in range or this call will with an {IllegalArgument} error.
    /// @notice The minting growth limiter parameters must be valid or this will revert with an {IllegalArgument} error. For more information, see the {Limiters} library.
    ///
    /// @notice Emits an {AdminUpdated} event.
    /// @notice Emits a {InterswapUpdated} event.
    /// @notice Emits a {MinimumCollateralizationUpdated} event.
    /// @notice Emits a {ProtocolFeeUpdated} event.
    /// @notice Emits a {ProtocolFeeReceiverUpdated} event.
    /// @notice Emits a {MintingLimitUpdated} event.
    ///
    /// @param params The contract initialization parameters.
    function initialize(InitializationParams memory params) external;

    /// @notice Sets the pending administrator.
    ///
    /// @notice `msg.sender` must be the admin or this call will will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {PendingAdminUpdated} event.
    ///
    /// @dev This is the first step in the two-step process of setting a new administrator. After this function is called, the pending administrator will then need to call {acceptAdmin} to complete the process.
    ///
    /// @param value the address to set the pending admin to.
    function setPendingAdmin(address value) external;

    /// @notice Allows for `msg.sender` to accepts the role of administrator.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice The current pending administrator must be non-zero or this call will revert with an {IllegalState} error.
    ///
    /// @dev This is the second step in the two-step process of setting a new administrator. After this function is successfully called, this pending administrator will be reset and the new administrator will be set.
    ///
    /// @notice Emits a {AdminUpdated} event.
    /// @notice Emits a {PendingAdminUpdated} event.
    function acceptAdmin() external;

    /// @notice Sets an address as a sentinel.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @param sentinel The address to set or unset as a sentinel.
    /// @param flag     A flag indicating of the address should be set or unset as a sentinel.
    function setSentinel(address sentinel, bool flag) external;

    /// @notice Sets an address as a keeper.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @param keeper The address to set or unset as a keeper.
    /// @param flag   A flag indicating of the address should be set or unset as a keeper.
    function setKeeper(address keeper, bool flag) external;

    /// @notice Adds an underlying token to the system.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @param underlyingToken The address of the underlying token to add.
    /// @param config          The initial underlying token configuration.
    function addUnderlyingToken(
        address underlyingToken,
        UnderlyingTokenConfig calldata config
    ) external;

    /// @notice Adds a yield token to the system.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {AddYieldToken} event.
    /// @notice Emits a {TokenAdapterUpdated} event.
    /// @notice Emits a {MaximumLossUpdated} event.
    ///
    /// @param yieldToken The address of the yield token to add.
    /// @param config     The initial yield token configuration.
    function addYieldToken(address yieldToken, YieldTokenConfig calldata config)
        external;

    /// @notice Sets an underlying token as either enabled or disabled.
    ///
    /// @notice `msg.sender` must be either the admin or a sentinel or this call will revert with an {Unauthorized} error.
    /// @notice `underlyingToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @notice Emits an {UnderlyingTokenEnabled} event.
    ///
    /// @param underlyingToken The address of the underlying token to enable or disable.
    /// @param enabled         If the underlying token should be enabled or disabled.
    function setUnderlyingTokenEnabled(address underlyingToken, bool enabled)
        external;

    /// @notice Sets a yield token as either enabled or disabled.
    ///
    /// @notice `msg.sender` must be either the admin or a sentinel or this call will revert with an {Unauthorized} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @notice Emits a {YieldTokenEnabled} event.
    ///
    /// @param yieldToken The address of the yield token to enable or disable.
    /// @param enabled    If the underlying token should be enabled or disabled.
    function setYieldTokenEnabled(address yieldToken, bool enabled) external;

    /// @notice Configures the the repay limit of `underlyingToken`.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `underlyingToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @notice Emits a {ReplayLimitUpdated} event.
    ///
    /// @param underlyingToken The address of the underlying token to configure the repay limit of.
    /// @param maximum         The maximum repay limit.
    /// @param blocks          The number of blocks it will take for the maximum repayment limit to be replenished when it is completely exhausted.
    function configureRepayLimit(
        address underlyingToken,
        uint256 maximum,
        uint256 blocks
    ) external;

    /// @notice Configure the liquidation limiter of `underlyingToken`.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `underlyingToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @notice Emits a {LiquidationLimitUpdated} event.
    ///
    /// @param underlyingToken The address of the underlying token to configure the liquidation limit of.
    /// @param maximum         The maximum liquidation limit.
    /// @param blocks          The number of blocks it will take for the maximum liquidation limit to be replenished when it is completely exhausted.
    function configureLiquidationLimit(
        address underlyingToken,
        uint256 maximum,
        uint256 blocks
    ) external;

    /// @notice Set the address of the interswap.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `value` must be non-zero or this call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {InterswapUpdated} event.
    ///
    /// @param value The address of the interswap.
    function setInterswap(address value) external;

    /// @notice Set the minimum collateralization ratio.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {MinimumCollateralizationUpdated} event.
    ///
    /// @param value The new minimum collateralization ratio.
    function setMinimumCollateralization(uint256 value) external;

    /// @notice Sets the fee that the protocol will take from harvests.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `value` must be in range or this call will with an {IllegalArgument} error.
    ///
    /// @notice Emits a {ProtocolFeeUpdated} event.
    ///
    /// @param value The value to set the protocol fee to measured in basis points.
    function setProtocolFee(uint256 value) external;

    /// @notice Sets the address which will receive protocol fees.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `value` must be non-zero or this call will revert with an {IllegalArgument} error.
    ///
    /// @notice Emits a {ProtocolFeeReceiverUpdated} event.
    ///
    /// @param value The address to set the protocol fee receiver to.
    function setProtocolFeeReceiver(address value) external;

    /// @notice Configures the minting limiter.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    ///
    /// @notice Emits a {MintingLimitUpdated} event.
    ///
    /// @param maximum The maximum minting limit.
    /// @param blocks  The number of blocks it will take for the maximum minting limit to be replenished when it is completely exhausted.
    function configureMintingLimit(uint256 maximum, uint256 blocks) external;

    /// @notice Sets the rate at which credit will be completely available to depositors after it is harvested.
    ///
    /// @notice Emits a {CreditUnlockRateUpdated} event.
    ///
    /// @param yieldToken The address of the yield token to set the credit unlock rate for.
    /// @param blocks     The number of blocks that it will take before the credit will be unlocked.
    function configureCreditUnlockRate(address yieldToken, uint256 blocks) external;

    /// @notice Sets the token adapter of a yield token.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    /// @notice The token that `adapter` supports must be `yieldToken` or this call will revert with a {IllegalState} error.
    ///
    /// @notice Emits a {TokenAdapterUpdated} event.
    ///
    /// @param yieldToken The address of the yield token to set the adapter for.
    /// @param adapter    The address to set the token adapter to.
    function setTokenAdapter(address yieldToken, address adapter) external;

    /// @notice Sets the maximum expected value of a yield token that the system can hold.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @param yieldToken The address of the yield token to set the maximum expected value for.
    /// @param value      The maximum expected value of the yield token denoted measured in its underlying token.
    function setMaximumExpectedValue(address yieldToken, uint256 value)
        external;

    /// @notice Sets the maximum loss that a yield bearing token will permit before restricting certain actions.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @dev There are two types of loss of value for yield bearing assets: temporary or permanent. The system will automatically restrict actions which are sensitive to both forms of loss when detected. For example, deposits must be restricted when an excessive loss is encountered to prevent users from having their collateral harvested from them. While the user would receive credit, which then could be exchanged for value equal to the collateral that was harvested from them, it is seen as a negative user experience because the value of their collateral should have been higher than what was originally recorded when they made their deposit.
    ///
    /// @param yieldToken The address of the yield bearing token to set the maximum loss for.
    /// @param value      The value to set the maximum loss to. This is in units of basis points.
    function setMaximumLoss(address yieldToken, uint256 value) external;

    /// @notice Snap the expected value `yieldToken` to the current value.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `yieldToken` must be registered or this call will revert with a {UnsupportedToken} error.
    ///
    /// @dev This function should only be used in the event of a loss in the target yield-token. For example, say a third-party protocol experiences a fifty percent loss. The expected value (amount of underlying tokens) of the yield tokens being held by the system would be two times the real value that those yield tokens could be redeemed for. This function gives governance a way to realize those losses so that users can continue using the token as normal.
    ///
    /// @param yieldToken The address of the yield token to snap.
    function snap(address yieldToken) external;

    /// @notice Sweep all of 'rewardtoken' from the alchemist into the admin.
    ///
    /// @notice `msg.sender` must be the admin or this call will revert with an {Unauthorized} error.
    /// @notice `rewardToken` must not be a yield or underlying token or this call will revert with a {UnsupportedToken} error.
    ///
    /// @param rewardToken The address of the reward token to snap.
    /// @param amount The amount of 'rewardToken' to sweep to the admin.
    function sweepTokens(address rewardToken, uint256 amount) external ;
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IRefineryV1Errors
/// @author Mellow Finance
///
/// @notice Specifies errors.
interface IRefineryV1Errors {
    /// @notice An error which is used to indicate that an operation failed because it tried to operate on a token that the system did not recognize.
    ///
    /// @param token The address of the token.
    error UnsupportedToken(address token);

    /// @notice An error which is used to indicate that an operation failed because it tried to operate on a token that has been disabled.
    ///
    /// @param token The address of the token.
    error TokenDisabled(address token);

    /// @notice An error which is used to indicate that an operation failed because an account became undercollateralized.
    error Undercollateralized();

    /// @notice An error which is used to indicate that an operation failed because the expected value of a yield token in the system exceeds the maximum value permitted.
    ///
    /// @param yieldToken           The address of the yield token.
    /// @param expectedValue        The expected value measured in units of the underlying token.
    /// @param maximumExpectedValue The maximum expected value permitted measured in units of the underlying token.
    error ExpectedValueExceeded(address yieldToken, uint256 expectedValue, uint256 maximumExpectedValue);

    /// @notice An error which is used to indicate that an operation failed because the loss that a yield token in the system exceeds the maximum value permitted.
    ///
    /// @param yieldToken  The address of the yield token.
    /// @param loss        The amount of loss measured in basis points.
    /// @param maximumLoss The maximum amount of loss permitted measured in basis points.
    error LossExceeded(address yieldToken, uint256 loss, uint256 maximumLoss);

    /// @notice An error which is used to indicate that a minting operation failed because the minting limit has been exceeded.
    ///
    /// @param amount    The amount of debt tokens that were requested to be minted.
    /// @param available The amount of debt tokens which are available to mint.
    error MintingLimitExceeded(uint256 amount, uint256 available);

    /// @notice An error which is used to indicate that an repay operation failed because the repay limit for an underlying token has been exceeded.
    ///
    /// @param underlyingToken The address of the underlying token.
    /// @param amount          The amount of underlying tokens that were requested to be repaid.
    /// @param available       The amount of underlying tokens that are available to be repaid.
    error RepayLimitExceeded(address underlyingToken, uint256 amount, uint256 available);

    /// @notice An error which is used to indicate that an repay operation failed because the liquidation limit for an underlying token has been exceeded.
    ///
    /// @param underlyingToken The address of the underlying token.
    /// @param amount          The amount of underlying tokens that were requested to be liquidated.
    /// @param available       The amount of underlying tokens that are available to be liquidated.
    error LiquidationLimitExceeded(address underlyingToken, uint256 amount, uint256 available);

    /// @notice An error which is used to indicate that the slippage of a wrap or unwrap operation was exceeded.
    ///
    /// @param amount           The amount of underlying or yield tokens returned by the operation.
    /// @param minimumAmountOut The minimum amount of the underlying or yield token that was expected when performing
    ///                         the operation.
    error SlippageExceeded(uint256 amount, uint256 minimumAmountOut);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IRefineryV1Events
/// @author Mellow Finance
interface IRefineryV1Events {
    /// @notice Emitted when the pending admin is updated.
    ///
    /// @param pendingAdmin The address of the pending admin.
    event PendingAdminUpdated(address pendingAdmin);

    /// @notice Emitted when the administrator is updated.
    ///
    /// @param admin The address of the administrator.
    event AdminUpdated(address admin);

    /// @notice Emitted when an address is set or unset as a sentinel.
    ///
    /// @param sentinel The address of the sentinel.
    /// @param flag     A flag indicating if `sentinel` was set or unset as a sentinel.
    event SentinelSet(address sentinel, bool flag);

    /// @notice Emitted when an address is set or unset as a keeper.
    ///
    /// @param sentinel The address of the keeper.
    /// @param flag     A flag indicating if `keeper` was set or unset as a sentinel.
    event KeeperSet(address sentinel, bool flag);

    /// @notice Emitted when an underlying token is added.
    ///
    /// @param underlyingToken The address of the underlying token that was added.
    event AddUnderlyingToken(address indexed underlyingToken);

    /// @notice Emitted when a yield token is added.
    ///
    /// @param yieldToken The address of the yield token that was added.
    event AddYieldToken(address indexed yieldToken);

    /// @notice Emitted when an underlying token is enabled or disabled.
    ///
    /// @param underlyingToken The address of the underlying token that was enabled or disabled.
    /// @param enabled         A flag indicating if the underlying token was enabled or disabled.
    event UnderlyingTokenEnabled(address indexed underlyingToken, bool enabled);

    /// @notice Emitted when an yield token is enabled or disabled.
    ///
    /// @param yieldToken The address of the yield token that was enabled or disabled.
    /// @param enabled    A flag indicating if the yield token was enabled or disabled.
    event YieldTokenEnabled(address indexed yieldToken, bool enabled);

    /// @notice Emitted when the repay limit of an underlying token is updated.
    ///
    /// @param underlyingToken The address of the underlying token.
    /// @param maximum         The updated maximum repay limit.
    /// @param blocks          The updated number of blocks it will take for the maximum repayment limit to be replenished when it is completely exhausted.
    event RepayLimitUpdated(address indexed underlyingToken, uint256 maximum, uint256 blocks);

    /// @notice Emitted when the liquidation limit of an underlying token is updated.
    ///
    /// @param underlyingToken The address of the underlying token.
    /// @param maximum         The updated maximum liquidation limit.
    /// @param blocks          The updated number of blocks it will take for the maximum liquidation limit to be replenished when it is completely exhausted.
    event LiquidationLimitUpdated(address indexed underlyingToken, uint256 maximum, uint256 blocks);

    /// @notice Emitted when the interswap is updated.
    ///
    /// @param interswap The updated address of the interswap.
    event InterswapUpdated(address interswap);

    /// @notice Emitted when the minimum collateralization is updated.
    ///
    /// @param minimumCollateralization The updated minimum collateralization.
    event MinimumCollateralizationUpdated(uint256 minimumCollateralization);

    /// @notice Emitted when the protocol fee is updated.
    ///
    /// @param protocolFee The updated protocol fee.
    event ProtocolFeeUpdated(uint256 protocolFee);
    
    /// @notice Emitted when the protocol fee receiver is updated.
    ///
    /// @param protocolFeeReceiver The updated address of the protocol fee receiver.
    event ProtocolFeeReceiverUpdated(address protocolFeeReceiver);

    /// @notice Emitted when the minting limit is updated.
    ///
    /// @param maximum The updated maximum minting limit.
    /// @param blocks  The updated number of blocks it will take for the maximum minting limit to be replenished when it is completely exhausted.
    event MintingLimitUpdated(uint256 maximum, uint256 blocks);

    /// @notice Emitted when the credit unlock rate is updated.
    ///
    /// @param yieldToken The address of the yield token.
    /// @param blocks     The number of blocks that distributed credit will unlock over.
    event CreditUnlockRateUpdated(address yieldToken, uint256 blocks);

    /// @notice Emitted when the adapter of a yield token is updated.
    ///
    /// @param yieldToken   The address of the yield token.
    /// @param tokenAdapter The updated address of the token adapter.
    event TokenAdapterUpdated(address yieldToken, address tokenAdapter);

    /// @notice Emitted when the maximum expected value of a yield token is updated.
    ///
    /// @param yieldToken           The address of the yield token.
    /// @param maximumExpectedValue The updated maximum expected value.
    event MaximumExpectedValueUpdated(address indexed yieldToken, uint256 maximumExpectedValue);

    /// @notice Emitted when the maximum loss of a yield token is updated.
    ///
    /// @param yieldToken  The address of the yield token.
    /// @param maximumLoss The updated maximum loss.
    event MaximumLossUpdated(address indexed yieldToken, uint256 maximumLoss);

    /// @notice Emitted when the expected value of a yield token is snapped to its current value.
    ///
    /// @param yieldToken    The address of the yield token.
    /// @param expectedValue The updated expected value measured in the yield token's underlying token.
    event Snap(address indexed yieldToken, uint256 expectedValue);

    /// @notice Emitted when a the admin sweeps all of one reward token from the Alchemist
    ///
    /// @param rewardToken The address of the reward token.
    /// @param amount      The amount of 'rewardToken' swept into the admin.
    event SweepTokens(address indexed rewardToken, uint256 amount);

    /// @notice Emitted when `owner` grants `spender` the ability to mint debt tokens on its behalf.
    ///
    /// @param owner   The address of the account owner.
    /// @param spender The address which is being permitted to mint tokens on the behalf of `owner`.
    /// @param amount  The amount of debt tokens that `spender` is allowed to mint.
    event ApproveMint(address indexed owner, address indexed spender, uint256 amount);

    /// @notice Emitted when `owner` grants `spender` the ability to withdraw `yieldToken` from its account.
    ///
    /// @param owner      The address of the account owner.
    /// @param spender    The address which is being permitted to mint tokens on the behalf of `owner`.
    /// @param yieldToken The address of the yield token that `spender` is allowed to withdraw.
    /// @param amount     The amount of shares of `yieldToken` that `spender` is allowed to withdraw.
    event ApproveWithdraw(address indexed owner, address indexed spender, address indexed yieldToken, uint256 amount);

    /// @notice Emitted when a user deposits `amount of `yieldToken` to `recipient`.
    ///
    /// @notice This event does not imply that `sender` directly deposited yield tokens. It is possible that the
    ///         underlying tokens were wrapped.
    ///
    /// @param sender       The address of the user which deposited funds.
    /// @param yieldToken   The address of the yield token that was deposited.
    /// @param amount       The amount of yield tokens that were deposited.
    /// @param recipient    The address that received the deposited funds.
    event Deposit(address indexed sender, address indexed yieldToken, uint256 amount, address recipient);

    /// @notice Emitted when `shares` shares of `yieldToken` are burned to withdraw `yieldToken` from the account owned
    ///         by `owner` to `recipient`.
    ///
    /// @notice This event does not imply that `recipient` received yield tokens. It is possible that the yield tokens
    ///         were unwrapped.
    ///
    /// @param owner      The address of the account owner.
    /// @param yieldToken The address of the yield token that was withdrawn.
    /// @param shares     The amount of shares that were burned.
    /// @param recipient  The address that received the withdrawn funds.
    event Withdraw(address indexed owner, address indexed yieldToken, uint256 shares, address recipient);

    /// @notice Emitted when `amount` debt tokens are minted to `recipient` using the account owned by `owner`.
    ///
    /// @param owner     The address of the account owner.
    /// @param amount    The amount of tokens that were minted.
    /// @param recipient The recipient of the minted tokens.
    event Mint(address indexed owner, uint256 amount, address recipient);

    /// @notice Emitted when `sender` burns `amount` debt tokens to grant credit to `recipient`.
    ///
    /// @param sender    The address which is burning tokens.
    /// @param amount    The amount of tokens that were burned.
    /// @param recipient The address that received credit for the burned tokens.
    event Burn(address indexed sender, uint256 amount, address recipient);

    /// @notice Emitted when `amount` of `underlyingToken` are repaid to grant credit to `recipient`.
    ///
    /// @param sender          The address which is repaying tokens.
    /// @param underlyingToken The address of the underlying token that was used to repay debt.
    /// @param amount          The amount of the underlying token that was used to repay debt.
    /// @param recipient       The address that received credit for the repaid tokens.
    /// @param credit          The amount of debt that was paid-off to the account owned by owner.
    event Repay(address indexed sender, address indexed underlyingToken, uint256 amount, address recipient, uint256 credit);

    /// @notice Emitted when `sender` liquidates `share` shares of `yieldToken`.
    ///
    /// @param owner           The address of the account owner liquidating shares.
    /// @param yieldToken      The address of the yield token.
    /// @param underlyingToken The address of the underlying token.
    /// @param shares          The amount of the shares of `yieldToken` that were liquidated.
    /// @param credit          The amount of debt that was paid-off to the account owned by owner.
    event Liquidate(address indexed owner, address indexed yieldToken, address indexed underlyingToken, uint256 shares, uint256 credit);

    /// @notice Emitted when `sender` burns `amount` debt tokens to grant credit to users who have deposited `yieldToken`.
    ///
    /// @param sender     The address which burned debt tokens.
    /// @param yieldToken The address of the yield token.
    /// @param amount     The amount of debt tokens which were burned.
    event Donate(address indexed sender, address indexed yieldToken, uint256 amount);

    /// @notice Emitted when `yieldToken` is harvested.
    ///
    /// @param yieldToken       The address of the yield token that was harvested.
    /// @param minimumAmountOut The maximum amount of loss that is acceptable when unwrapping the underlying tokens into yield tokens, measured in basis points.
    /// @param totalHarvested   The total amount of underlying tokens harvested.
    /// @param credit           The total amount of debt repaid to depositors of `yieldToken`.
    event Harvest(address indexed yieldToken, uint256 minimumAmountOut, uint256 totalHarvested, uint256 credit);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IRefineryV1Immutables
/// @author Mellow Finance
interface IRefineryV1Immutables {
    /// @notice Returns the version of the alchemist.
    ///
    /// @return The version.
    function version() external view returns (string memory);

    /// @notice Returns the address of the debt token used by the system.
    ///
    /// @return The address of the debt token.
    function debtToken() external view returns (address);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title  IRefineryV1State
/// @author Mellow Finance
interface IRefineryV1State {
    /// @notice Defines underlying token parameters.
    struct UnderlyingTokenParams {
        // The number of decimals the token has. This value is cached once upon registering the token so it is important
        // that the decimals of the token are immutable or the system will begin to have computation errors.
        uint8 decimals;
        // A coefficient used to normalize the token to a value comparable to the debt token. For example, if the
        // underlying token is 8 decimals and the debt token is 18 decimals then the conversion factor will be
        // 10^10. One unit of the underlying token will be comparably equal to one unit of the debt token.
        uint256 conversionFactor;
        // A flag to indicate if the token is enabled.
        bool enabled;
    }

    /// @notice Defines yield token parameters.
    struct YieldTokenParams {
        // The number of decimals the token has. This value is cached once upon registering the token so it is important
        // that the decimals of the token are immutable or the system will begin to have computation errors.
        uint8 decimals;
        // The associated underlying token that can be redeemed for the yield-token.
        address underlyingToken;
        // The adapter used by the system to wrap, unwrap, and lookup the conversion rate of this token into its
        // underlying token.
        address adapter;
        // The maximum percentage loss that is acceptable before disabling certain actions.
        uint256 maximumLoss;
        // The maximum value of yield tokens that the system can hold, measured in units of the underlying token.
        uint256 maximumExpectedValue;
        // The percent of credit that will be unlocked per block. The representation of this value is a 18  decimal
        // fixed point integer.
        uint256 creditUnlockRate;
        // The current balance of yield tokens which are held by users.
        uint256 activeBalance;
        // The current balance of yield tokens which are earmarked to be harvested by the system at a later time.
        uint256 harvestableBalance;
        // The total number of shares that have been minted for this token.
        uint256 totalShares;
        // The expected value of the tokens measured in underlying tokens. This value controls how much of the token
        // can be harvested. When users deposit yield tokens, it increases the expected value by how much the tokens
        // are exchangeable for in the underlying token. When users withdraw yield tokens, it decreases the expected
        // value by how much the tokens are exchangeable for in the underlying token.
        uint256 expectedValue;
        // The current amount of credit which is will be distributed over time to depositors.
        uint256 pendingCredit;
        // The amount of the pending credit that has been distributed.
        uint256 distributedCredit;
        // The block number which the last credit distribution occurred.
        uint256 lastDistributionBlock;
        // The total accrued weight. This is used to calculate how much credit a user has been granted over time. The
        // representation of this value is a 18 decimal fixed point integer.
        uint256 accruedWeight;
        // A flag to indicate if the token is enabled.
        bool enabled;
    }

    /// @notice Gets the address of the admin.
    ///
    /// @return admin The admin address.
    function admin() external view returns (address admin);

    /// @notice Gets the address of the pending administrator.
    ///
    /// @return pendingAdmin The pending administrator address.
    function pendingAdmin() external view returns (address pendingAdmin);

    /// @notice Gets if an address is a sentinel.
    ///
    /// @param sentinel The address to check.
    ///
    /// @return isSentinel If the address is a sentinel.
    function sentinels(address sentinel) external view returns (bool isSentinel);

    /// @notice Gets if an address is a keeper.
    ///
    /// @param keeper The address to check.
    ///
    /// @return isKeeper If the address is a keeper
    function keepers(address keeper) external view returns (bool isKeeper);

    /// @notice Gets the address of the interswap.
    ///
    /// @return interswap The interswap address.
    function interswap() external view returns (address interswap);

    /// @notice Gets the minimum collateralization.
    ///
    /// @notice Collateralization is determined by taking the total value of collateral that a user has deposited into their account and dividing it their debt.
    ///
    /// @dev The value returned is a 18 decimal fixed point integer.
    ///
    /// @return minimumCollateralization The minimum collateralization.
    function minimumCollateralization() external view returns (uint256 minimumCollateralization);

    /// @notice Gets the protocol fee.
    ///
    /// @return protocolFee The protocol fee.
    function protocolFee() external view returns (uint256 protocolFee);

    /// @notice Gets the protocol fee receiver.
    ///
    /// @return protocolFeeReceiver The protocol fee receiver.
    function protocolFeeReceiver() external view returns (address protocolFeeReceiver);

    /// @notice Gets the address of the whitelist contract.
    ///
    /// @return whitelist The address of the whitelist contract.
    function whitelist() external view returns (address whitelist);
    
    /// @notice Gets the conversion rate of underlying tokens per share.
    ///
    /// @param yieldToken The address of the yield token to get the conversion rate for.
    ///
    /// @return rate The rate of underlying tokens per share.
    function getUnderlyingTokensPerShare(address yieldToken) external view returns (uint256 rate);

    /// @notice Gets the conversion rate of yield tokens per share.
    ///
    /// @param yieldToken The address of the yield token to get the conversion rate for.
    ///
    /// @return rate The rate of yield tokens per share.
    function getYieldTokensPerShare(address yieldToken) external view returns (uint256 rate);

    /// @notice Gets the supported underlying tokens.
    ///
    /// @dev The order of the entries returned by this function is not guaranteed to be consistent between calls.
    ///
    /// @return tokens The supported underlying tokens.
    function getSupportedUnderlyingTokens() external view returns (address[] memory tokens);

    /// @notice Gets the supported yield tokens.
    ///
    /// @dev The order of the entries returned by this function is not guaranteed to be consistent between calls.
    ///
    /// @return tokens The supported yield tokens.
    function getSupportedYieldTokens() external view returns (address[] memory tokens);

    /// @notice Gets if an underlying token is supported.
    ///
    /// @param underlyingToken The address of the underlying token to check.
    ///
    /// @return isSupported If the underlying token is supported.
    function isSupportedUnderlyingToken(address underlyingToken) external view returns (bool isSupported);

    /// @notice Gets if a yield token is supported.
    ///
    /// @param yieldToken The address of the yield token to check.
    ///
    /// @return isSupported If the yield token is supported.
    function isSupportedYieldToken(address yieldToken) external view returns (bool isSupported);

    /// @notice Gets information about the account owned by `owner`.
    ///
    /// @param owner The address that owns the account.
    ///
    /// @return debt            The unrealized amount of debt that the account had incurred.
    /// @return depositedTokens The yield tokens that the owner has deposited.
    function accounts(address owner) external view returns (int256 debt, address[] memory depositedTokens);

    /// @notice Gets information about a yield token position for the account owned by `owner`.
    ///
    /// @param owner      The address that owns the account.
    /// @param yieldToken The address of the yield token to get the position of.
    ///
    /// @return shares            The amount of shares of that `owner` owns of the yield token.
    /// @return lastAccruedWeight The last recorded accrued weight of the yield token.
    function positions(address owner, address yieldToken)
        external view
        returns (
            uint256 shares,
            uint256 lastAccruedWeight
        );

    /// @notice Gets the amount of debt tokens `spender` is allowed to mint on behalf of `owner`.
    ///
    /// @param owner   The owner of the account.
    /// @param spender The address which is allowed to mint on behalf of `owner`.
    ///
    /// @return allowance The amount of debt tokens that `spender` can mint on behalf of `owner`.
    function mintAllowance(address owner, address spender) external view returns (uint256 allowance);

    /// @notice Gets the amount of shares of `yieldToken` that `spender` is allowed to withdraw on behalf of `owner`.
    ///
    /// @param owner      The owner of the account.
    /// @param spender    The address which is allowed to withdraw on behalf of `owner`.
    /// @param yieldToken The address of the yield token.
    ///
    /// @return allowance The amount of shares that `spender` can withdraw on behalf of `owner`.
    function withdrawAllowance(address owner, address spender, address yieldToken) external view returns (uint256 allowance);

    /// @notice Gets the parameters of an underlying token.
    ///
    /// @param underlyingToken The address of the underlying token.
    ///
    /// @return params The underlying token parameters.
    function getUnderlyingTokenParameters(address underlyingToken)
        external view
        returns (UnderlyingTokenParams memory params);

    /// @notice Get the parameters and state of a yield-token.
    ///
    /// @param yieldToken The address of the yield token.
    ///
    /// @return params The yield token parameters.
    function getYieldTokenParameters(address yieldToken)
        external view
        returns (YieldTokenParams memory params);

    /// @notice Gets current limit, maximum, and rate of the minting limiter.
    ///
    /// @return currentLimit The current amount of debt tokens that can be minted.
    /// @return rate         The maximum possible amount of tokens that can be liquidated at a time.
    /// @return maximum      The highest possible maximum amount of debt tokens that can be minted at a time.
    function getMintLimitInfo()
        external view
        returns (
            uint256 currentLimit,
            uint256 rate,
            uint256 maximum
        );

    /// @notice Gets current limit, maximum, and rate of a repay limiter for `underlyingToken`.
    ///
    /// @param underlyingToken The address of the underlying token.
    ///
    /// @return currentLimit The current amount of underlying tokens that can be repaid.
    /// @return rate         The rate at which the the current limit increases back to its maximum in tokens per block.
    /// @return maximum      The maximum possible amount of tokens that can be repaid at a time.
    function getRepayLimitInfo(address underlyingToken)
        external view
        returns (
            uint256 currentLimit,
            uint256 rate,
            uint256 maximum
        );

    /// @notice Gets current limit, maximum, and rate of the liquidation limiter for `underlyingToken`.
    ///
    /// @param underlyingToken The address of the underlying token.
    ///
    /// @return currentLimit The current amount of underlying tokens that can be liquidated.
    /// @return rate         The rate at which the function increases back to its maximum limit (tokens / block).
    /// @return maximum      The highest possible maximum amount of debt tokens that can be liquidated at a time.
    function getLiquidationLimitInfo(address underlyingToken)
        external view
        returns (
            uint256 currentLimit,
            uint256 rate,
            uint256 maximum
        );
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./base/Errors.sol";

import "./interfaces/IWhitelist.sol";

import "./interfaces/interswap/IInterswapV1.sol";
import "./interfaces/interswap/IInterswapBuffer.sol";

import "./libraries/FixedPointMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/Tick.sol";
import "./libraries/TokenUtils.sol";

/// @title InterswapV1
///
/// @notice A contract which facilitates the exchange of synthetic assets for their underlying
//          asset. This contract guarantees that synthetic assets are exchanged exactly 1:1
//          for the underlying asset.
contract InterswapV1 is IInterswapV1, Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
  using FixedPointMath for FixedPointMath.Number;
  using Tick for Tick.Cache;

  struct Account {
    // The total number of unexchanged tokens that an account has deposited into the system
    uint256 unexchangedBalance;
    // The total number of exchanged tokens that an account has had credited
    uint256 exchangedBalance;
    // The tick that the account has had their deposit associated in
    uint256 occupiedTick;
  }

  struct UpdateAccountParams {
    // The owner address whose account will be modified
    address owner;
    // The amount to change the account's unexchanged balance by
    int256 unexchangedDelta;
    // The amount to change the account's exchanged balance by
    int256 exchangedDelta;
  }

  struct ExchangeCache {
    // The total number of unexchanged tokens that exist at the start of the exchange call
    uint256 totalUnexchanged;
    // The tick which has been satisfied up to at the start of the exchange call
    uint256 satisfiedTick;
    // The head of the active ticks queue at the start of the exchange call
    uint256 ticksHead;
  }

  struct ExchangeState {
    // The position in the buffer of current tick which is being examined
    uint256 examineTick;
    // The total number of unexchanged tokens that currently exist in the system for the current distribution step
    uint256 totalUnexchanged;
    // The tick which has been satisfied up to, inclusive
    uint256 satisfiedTick;
    // The amount of tokens to distribute for the current step
    uint256 distributeAmount;
    // The accumulated weight to write at the new tick after the exchange is completed
    FixedPointMath.Number accumulatedWeight;
    // Reserved for the maximum weight of the current distribution step
    FixedPointMath.Number maximumWeight;
    // Reserved for the dusted weight of the current distribution step
    FixedPointMath.Number dustedWeight;
  }

  struct UpdateAccountCache {
    // The total number of unexchanged tokens that the account held at the start of the update call
    uint256 unexchangedBalance;
    // The total number of exchanged tokens that the account held at the start of the update call
    uint256 exchangedBalance;
    // The tick that the account's deposit occupies at the start of the update call
    uint256 occupiedTick;
    // The total number of unexchanged tokens that exist at the start of the update call
    uint256 totalUnexchanged;
    // The current tick that is being written to
    uint256 currentTick;
  }

  struct UpdateAccountState {
    // The updated unexchanged balance of the account being updated
    uint256 unexchangedBalance;
    // The updated exchanged balance of the account being updated
    uint256 exchangedBalance;
    // The updated total unexchanged balance
    uint256 totalUnexchanged;
  }

  address public constant ZERO_ADDRESS = address(0);

  /// @dev The identifier of the role which maintains other roles.
  bytes32 public constant ADMIN = keccak256("ADMIN");

  /// @dev The identitifer of the sentinel role
  bytes32 public constant SENTINEL = keccak256("SENTINEL");

  /// @inheritdoc IInterswapV1
  string public constant override version = "2.2.0";

  /// @dev the synthetic token to be swapped
  address public syntheticToken;

  /// @dev the underlying token to be received
  address public override underlyingToken;

  /// @dev The total amount of unexchanged tokens which are held by all accounts.
  uint256 public totalUnexchanged;

  /// @dev The total amount of tokens which are in the auxiliary buffer.
  uint256 public totalBuffered;

  /// @dev A mapping specifying all of the accounts.
  mapping(address => Account) private accounts;

  // @dev The tick buffer which stores all of the tick information along with the tick that is
  //      currently being written to. The "current" tick is the tick at the buffer write position.
  Tick.Cache private ticks;

  // The tick which has been satisfied up to, inclusive.
  uint256 private satisfiedTick;

  /// @dev contract pause state
  bool public isPaused;

  /// @dev the source of the exchanged collateral
  address public buffer;

  /// @dev The address of the external whitelist contract.
  address public override whitelist;

  /// @dev The amount of decimal places needed to normalize collateral to debtToken
  uint256 public override conversionFactor;

  constructor() initializer {}

  function initialize(
    address _syntheticToken,
    address _underlyingToken,
    address _buffer,
    address _whitelist
  ) external initializer {
    _setupRole(ADMIN, msg.sender);
    _setRoleAdmin(ADMIN, ADMIN);
    _setRoleAdmin(SENTINEL, ADMIN);

    syntheticToken = _syntheticToken;
    underlyingToken = _underlyingToken;
    uint8 debtTokenDecimals = TokenUtils.expectDecimals(syntheticToken);
    uint8 underlyingTokenDecimals = TokenUtils.expectDecimals(underlyingToken);
    conversionFactor = 10**(debtTokenDecimals - underlyingTokenDecimals);
    buffer = _buffer;
    // Push a blank tick to function as a sentinel value in the active ticks queue.
    ticks.next();

    isPaused = false;
    whitelist = _whitelist;
  }

  /// @dev A modifier which checks if caller is an refinery.
  modifier onlyBuffer() {
    if (msg.sender != buffer) {
      revert Unauthorized();
    }
    _;
  }

  /// @dev A modifier which checks if caller is a sentinel or admin.
  modifier onlySentinelOrAdmin() {
    if (!hasRole(SENTINEL, msg.sender) && !hasRole(ADMIN, msg.sender)) {
      revert Unauthorized();
    }
    _;
  }

  /// @dev A modifier which checks if caller is a sentinel.
  modifier notPaused() {
    if (isPaused) {
      revert IllegalState();
    }
    _;
  }

  function _onlyAdmin() internal view {
    if (!hasRole(ADMIN, msg.sender)) {
      revert Unauthorized();
    }
  }

  function setCollateralSource(address _newCollateralSource) external {
    _onlyAdmin();
    buffer = _newCollateralSource;
  }

  function setPause(bool pauseState) external onlySentinelOrAdmin {
    isPaused = pauseState;
    emit Paused(isPaused);
  }

  /// @inheritdoc IInterswapV1
  function deposit(uint256 amount, address owner) external override nonReentrant {
    _onlyWhitelisted();
    _updateAccount(
      UpdateAccountParams({
        owner: owner,
        unexchangedDelta: SafeCast.toInt256(amount),
        exchangedDelta: 0
      })
    );
    TokenUtils.safeTransferFrom(syntheticToken, msg.sender, address(this), amount);
    emit Deposit(msg.sender, owner, amount);
  }

  /// @inheritdoc IInterswapV1
  function withdraw(uint256 amount, address recipient) external override nonReentrant {
    _onlyWhitelisted();
    _updateAccount(
      UpdateAccountParams({ 
        owner: msg.sender,
        unexchangedDelta: -SafeCast.toInt256(amount),
        exchangedDelta: 0
      })
    );
    TokenUtils.safeTransfer(syntheticToken, recipient, amount);
    emit Withdraw(msg.sender, recipient, amount);
  }

  /// @inheritdoc IInterswapV1
  function claim(uint256 amount, address recipient) external override nonReentrant {
    _onlyWhitelisted();
    _updateAccount(
      UpdateAccountParams({
        owner: msg.sender,
        unexchangedDelta: 0,
        exchangedDelta: -SafeCast.toInt256(_normalizeUnderlyingTokensToDebt(amount))
      })
    );
    TokenUtils.safeBurn(syntheticToken, _normalizeUnderlyingTokensToDebt(amount));
    IInterswapBuffer(buffer).withdraw(underlyingToken, amount, msg.sender);
    emit Claim(msg.sender, recipient, amount);
  }

  /// @inheritdoc IInterswapV1
  function exchange(uint256 amount) external override nonReentrant onlyBuffer notPaused {
    uint256 normaizedAmount = _normalizeUnderlyingTokensToDebt(amount);

    if (totalUnexchanged == 0) {
      totalBuffered += normaizedAmount;
      emit Exchange(msg.sender, amount);
      return;
    }

    // Push a storage reference to the current tick.
    Tick.Info storage current = ticks.current();

    ExchangeCache memory cache = ExchangeCache({
      totalUnexchanged: totalUnexchanged,
      satisfiedTick: satisfiedTick,
      ticksHead: ticks.head
    });

    ExchangeState memory state = ExchangeState({
      examineTick: cache.ticksHead,
      totalUnexchanged: cache.totalUnexchanged,
      satisfiedTick: cache.satisfiedTick,
      distributeAmount: normaizedAmount,
      accumulatedWeight: current.accumulatedWeight,
      maximumWeight: FixedPointMath.encode(0),
      dustedWeight: FixedPointMath.encode(0)
    });

    // Distribute the buffered tokens as part of the exchange.
    state.distributeAmount += totalBuffered;
    totalBuffered = 0;

    // Push a storage reference to the next tick to write to.
    Tick.Info storage next = ticks.next();

    // Only iterate through the active ticks queue when it is not empty.
    while (state.examineTick != 0) {
      // Check if there is anything left to distribute.
      if (state.distributeAmount == 0) {
        break;
      }

      Tick.Info storage examineTickData = ticks.get(state.examineTick);

      // Add the weight for the distribution step to the accumulated weight.
      state.accumulatedWeight = state.accumulatedWeight.add(
        FixedPointMath.rational(state.distributeAmount, state.totalUnexchanged)
      );

      // Clear the distribute amount.
      state.distributeAmount = 0;

      // Calculate the current maximum weight in the system.
      state.maximumWeight = state.accumulatedWeight.sub(examineTickData.accumulatedWeight);

      // Check if there exists at least one account which is completely satisfied..
      if (state.maximumWeight.n < FixedPointMath.ONE) {
        break;
      }

      // Calculate how much weight of the distributed weight is dust.
      state.dustedWeight = FixedPointMath.Number(state.maximumWeight.n - FixedPointMath.ONE);

      // Calculate how many tokens to distribute in the next step. These are tokens from any tokens which
      // were over allocated to accounts occupying the tick with the maximum weight.
      state.distributeAmount = LiquidityMath.calculateProduct(examineTickData.totalBalance, state.dustedWeight);

      // Remove the tokens which were completely exchanged from the total unexchanged balance.
      state.totalUnexchanged -= examineTickData.totalBalance;

      // Write that all ticks up to and including the examined tick have been satisfied.
      state.satisfiedTick = state.examineTick;

      // Visit the next active tick. This is equivalent to popping the head of the active ticks queue.
      state.examineTick = examineTickData.next;
    }

    // Write the accumulated weight to the next tick.
    next.accumulatedWeight = state.accumulatedWeight;

    if (cache.totalUnexchanged != state.totalUnexchanged) {
      totalUnexchanged = state.totalUnexchanged;
    }

    if (cache.satisfiedTick != state.satisfiedTick) {
      satisfiedTick = state.satisfiedTick;
    }

    if (cache.ticksHead != state.examineTick) {
      ticks.head = state.examineTick;
    }

    if (state.distributeAmount > 0) {
      totalBuffered += state.distributeAmount;
    }

    emit Exchange(msg.sender, amount);
  }

  /// @inheritdoc IInterswapV1
  function getUnexchangedBalance(address owner) external view override returns (uint256 unexchangedBalance) {
    Account storage account = accounts[owner];

    if (account.occupiedTick <= satisfiedTick) {
      return 0;
    }

    unexchangedBalance = account.unexchangedBalance;

    uint256 exchanged = LiquidityMath.calculateProduct(
      unexchangedBalance,
      ticks.getWeight(account.occupiedTick, ticks.position)
    );

    unexchangedBalance -= exchanged;

    return unexchangedBalance;
  }

  /// @inheritdoc IInterswapV1
  function getExchangedBalance(address owner) external view override returns (uint256 exchangedBalance) {
    return _getExchangedBalance(owner);
  }

  function getClaimableBalance(address owner) external view override returns (uint256 claimableBalance) {
    return _normalizeDebtTokensToUnderlying(_getExchangedBalance(owner));
  }

  /// @dev Updates an account.
  ///
  /// @param params The call parameters.
  function _updateAccount(UpdateAccountParams memory params) internal {
    Account storage account = accounts[params.owner];

    UpdateAccountCache memory cache = UpdateAccountCache({
      unexchangedBalance: account.unexchangedBalance,
      exchangedBalance: account.exchangedBalance,
      occupiedTick: account.occupiedTick,
      totalUnexchanged: totalUnexchanged,
      currentTick: ticks.position
    });

    UpdateAccountState memory state = UpdateAccountState({
      unexchangedBalance: cache.unexchangedBalance,
      exchangedBalance: cache.exchangedBalance,
      totalUnexchanged: cache.totalUnexchanged
    });

    // Updating an account is broken down into five steps:
    // 1). Synchronize the account if it previously occupied a satisfied tick
    // 2). Update the account balances to account for exchanged tokens, if any
    // 3). Apply the deltas to the account balances
    // 4). Update the previously occupied and or current tick's liquidity
    // 5). Commit changes to the account and global state when needed

    // Step one:
    // ---------
    // Check if the tick that the account was occupying previously was satisfied. If it was, we acknowledge
    // that all of the tokens were exchanged.
    if (state.unexchangedBalance > 0 && satisfiedTick >= cache.occupiedTick) {
      state.unexchangedBalance = 0;
      state.exchangedBalance += cache.unexchangedBalance;
    }

    // Step Two:
    // ---------
    // Calculate how many tokens were exchanged since the last update.
    if (state.unexchangedBalance > 0) {
      uint256 exchanged = LiquidityMath.calculateProduct(
        state.unexchangedBalance,
        ticks.getWeight(cache.occupiedTick, cache.currentTick)
      );

      state.totalUnexchanged -= exchanged;
      state.unexchangedBalance -= exchanged;
      state.exchangedBalance += exchanged;
    }

    // Step Three:
    // -----------
    // Apply the unexchanged and exchanged deltas to the state.
    state.totalUnexchanged = LiquidityMath.addDelta(state.totalUnexchanged, params.unexchangedDelta);
    state.unexchangedBalance = LiquidityMath.addDelta(state.unexchangedBalance, params.unexchangedDelta);
    state.exchangedBalance = LiquidityMath.addDelta(state.exchangedBalance, params.exchangedDelta);

    // Step Four:
    // ----------
    // The following is a truth table relating various values which in combinations specify which logic branches
    // need to be executed in order to update liquidity in the previously occupied and or current tick.
    //
    // Some states are not obtainable and are just discarded by setting all the branches to false.
    //
    // | P | C | M | Modify Liquidity | Add Liquidity | Subtract Liquidity |
    // |---|---|---|------------------|---------------|--------------------|
    // | F | F | F | F                | F             | F                  |
    // | F | F | T | F                | F             | F                  |
    // | F | T | F | F                | T             | F                  |
    // | F | T | T | F                | T             | F                  |
    // | T | F | F | F                | F             | T                  |
    // | T | F | T | F                | F             | T                  |
    // | T | T | F | T                | F             | F                  |
    // | T | T | T | F                | T             | T                  |
    //
    // | Branch             | Reduction |
    // |--------------------|-----------|
    // | Modify Liquidity   | PCM'      |
    // | Add Liquidity      | P'C + CM  |
    // | Subtract Liquidity | PC' + PM  |

    bool previouslyActive = cache.unexchangedBalance > 0;
    bool currentlyActive = state.unexchangedBalance > 0;
    bool migrate = cache.occupiedTick != cache.currentTick;

    bool modifyLiquidity = previouslyActive && currentlyActive && !migrate;

    if (modifyLiquidity) {
      Tick.Info storage tick = ticks.get(cache.occupiedTick);

      // Consolidate writes to save gas.
      uint256 totalBalance = tick.totalBalance;
      totalBalance -= cache.unexchangedBalance;
      totalBalance += state.unexchangedBalance;
      tick.totalBalance = totalBalance;
    } else {
      bool addLiquidity = (!previouslyActive && currentlyActive) || (currentlyActive && migrate);
      bool subLiquidity = (previouslyActive && !currentlyActive) || (previouslyActive && migrate);

      if (addLiquidity) {
        Tick.Info storage tick = ticks.get(cache.currentTick);

        if (tick.totalBalance == 0) {
          ticks.addLast(cache.currentTick);
        }

        tick.totalBalance += state.unexchangedBalance;
      }

      if (subLiquidity) {
        Tick.Info storage tick = ticks.get(cache.occupiedTick);
        tick.totalBalance -= cache.unexchangedBalance;

        if (tick.totalBalance == 0) {
          ticks.remove(cache.occupiedTick);
        }
      }
    }

    // Step Five:
    // ----------
    // Commit the changes to the account.
    if (cache.unexchangedBalance != state.unexchangedBalance) {
      account.unexchangedBalance = state.unexchangedBalance;
    }

    if (cache.exchangedBalance != state.exchangedBalance) {
      account.exchangedBalance = state.exchangedBalance;
    }

    if (cache.totalUnexchanged != state.totalUnexchanged) {
      totalUnexchanged = state.totalUnexchanged;
    }

    if (cache.occupiedTick != cache.currentTick) {
      account.occupiedTick = cache.currentTick;
    }
  }

  /// @dev Checks the whitelist for msg.sender.
  ///
  /// @notice Reverts if msg.sender is not in the whitelist.
  function _onlyWhitelisted() internal view {
    // Check if the message sender is an EOA. In the future, this potentially may break. It is important that
    // functions which rely on the whitelist not be explicitly vulnerable in the situation where this no longer
    // holds true.
    if (tx.origin != msg.sender) {
      // Only check the whitelist for calls from contracts.
      if (!IWhitelist(whitelist).isWhitelisted(msg.sender)) {
        revert Unauthorized();
      }
    }
  }

  /// @dev Normalize `amount` of `underlyingToken` to a value which is comparable to units of the debt token.
  ///
  /// @param amount          The amount of the debt token.
  ///
  /// @return The normalized amount.
  function _normalizeUnderlyingTokensToDebt(uint256 amount) internal view returns (uint256) {
    return amount * conversionFactor;
  }

  /// @dev Normalize `amount` of the debt token to a value which is comparable to units of `underlyingToken`.
  ///
  /// @dev This operation will result in truncation of some of the least significant digits of `amount`. This
  ///      truncation amount will be the least significant N digits where N is the difference in decimals between
  ///      the debt token and the underlying token.
  ///
  /// @param amount          The amount of the debt token.
  ///
  /// @return The normalized amount.
  function _normalizeDebtTokensToUnderlying(uint256 amount) internal view returns (uint256) {
    return amount / conversionFactor;
  }

  function _getExchangedBalance(address owner) internal view returns (uint256 exchangedBalance) {
    Account storage account = accounts[owner];

    if (account.occupiedTick <= satisfiedTick) {
      exchangedBalance = account.exchangedBalance;
      exchangedBalance += account.unexchangedBalance;
      return exchangedBalance;
    }

    exchangedBalance = account.exchangedBalance;

    uint256 exchanged = LiquidityMath.calculateProduct(
      account.unexchangedBalance,
      ticks.getWeight(account.occupiedTick, ticks.position)
    );

    exchangedBalance += exchanged;

    return exchangedBalance;
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.11;

/**
 * @notice A library which implements fixed point decimal math.
 */
library FixedPointMath {
  /** @dev This will give approximately 60 bits of precision */
  uint256 public constant DECIMALS = 18;
  uint256 public constant ONE = 10**DECIMALS;

  /**
   * @notice A struct representing a fixed point decimal.
   */
  struct Number {
    uint256 n;
  }

  /**
   * @notice Encodes a unsigned 256-bit integer into a fixed point decimal.
   *
   * @param value The value to encode.
   * @return      The fixed point decimal representation.
   */
  function encode(uint256 value) internal pure returns (Number memory) {
    return Number(FixedPointMath.encodeRaw(value));
  }

  /**
   * @notice Encodes a unsigned 256-bit integer into a uint256 representation of a
   *         fixed point decimal.
   *
   * @param value The value to encode.
   * @return      The fixed point decimal representation.
   */
  function encodeRaw(uint256 value) internal pure returns (uint256) {
    return value * ONE;
  }

  /**
   * @notice Encodes a uint256 MAX VALUE into a uint256 representation of a
   *         fixed point decimal.
   *
   * @return      The uint256 MAX VALUE fixed point decimal representation.
   */
  function max() internal pure returns (Number memory) {
    return Number(type(uint256).max);
  }

  /**
   * @notice Creates a rational fraction as a Number from 2 uint256 values
   *
   * @param n The numerator.
   * @param d The denominator.
   * @return  The fixed point decimal representation.
   */
  function rational(uint256 n, uint256 d) internal pure returns (Number memory) {
    Number memory numerator = encode(n);
    return FixedPointMath.div(numerator, d);
  }

  /**
   * @notice Adds two fixed point decimal numbers together.
   *
   * @param self  The left hand operand.
   * @param value The right hand operand.
   * @return      The result.
   */
  function add(Number memory self, Number memory value) internal pure returns (Number memory) {
    return Number(self.n + value.n);
  }

  /**
   * @notice Adds a fixed point number to a unsigned 256-bit integer.
   *
   * @param self  The left hand operand.
   * @param value The right hand operand. This will be converted to a fixed point decimal.
   * @return      The result.
   */
  function add(Number memory self, uint256 value) internal pure returns (Number memory) {
    return add(self, FixedPointMath.encode(value));
  }

  /**
   * @notice Subtract a fixed point decimal from another.
   *
   * @param self  The left hand operand.
   * @param value The right hand operand.
   * @return      The result.
   */
  function sub(Number memory self, Number memory value) internal pure returns (Number memory) {
    return Number(self.n - value.n);
  }

  /**
   * @notice Subtract a unsigned 256-bit integer from a fixed point decimal.
   *
   * @param self  The left hand operand.
   * @param value The right hand operand. This will be converted to a fixed point decimal.
   * @return      The result.
   */
  function sub(Number memory self, uint256 value) internal pure returns (Number memory) {
    return sub(self, FixedPointMath.encode(value));
  }

  /**
   * @notice Multiplies a fixed point decimal by another fixed point decimal.
   *
   * @param self  The fixed point decimal to multiply.
   * @param number The fixed point decimal to multiply by.
   * @return      The result.
   */
  function mul(Number memory self, Number memory number) internal pure returns (Number memory) {
    return Number((self.n * number.n) / ONE);
  }

  /**
   * @notice Multiplies a fixed point decimal by an unsigned 256-bit integer.
   *
   * @param self  The fixed point decimal to multiply.
   * @param value The unsigned 256-bit integer to multiply by.
   * @return      The result.
   */
  function mul(Number memory self, uint256 value) internal pure returns (Number memory) {
    return Number(self.n * value);
  }

  /**
   * @notice Divides a fixed point decimal by an unsigned 256-bit integer.
   *
   * @param self  The fixed point decimal to multiply by.
   * @param value The unsigned 256-bit integer to divide by.
   * @return      The result.
   */
  function div(Number memory self, uint256 value) internal pure returns (Number memory) {
    return Number(self.n / value);
  }

  /**
   * @notice Compares two fixed point decimals.
   *
   * @param self  The left hand number to compare.
   * @param value The right hand number to compare.
   * @return      When the left hand number is less than the right hand number this returns -1,
   *              when the left hand number is greater than the right hand number this returns 1,
   *              when they are equal this returns 0.
   */
  function cmp(Number memory self, Number memory value) internal pure returns (int256) {
    if (self.n < value.n) {
      return -1;
    }

    if (self.n > value.n) {
      return 1;
    }

    return 0;
  }

  /**
   * @notice Gets if two fixed point numbers are equal.
   *
   * @param self  the first fixed point number.
   * @param value the second fixed point number.
   *
   * @return if they are equal.
   */
  function equals(Number memory self, Number memory value) internal pure returns (bool) {
    return self.n == value.n;
  }

  /**
   * @notice Truncates a fixed point decimal into an unsigned 256-bit integer.
   *
   * @return The integer portion of the fixed point decimal.
   */
  function truncate(Number memory self) internal pure returns (uint256) {
    return self.n / ONE;
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import { IllegalArgument } from "../base/Errors.sol";

import { FixedPointMath } from "./FixedPointMath.sol";

/// @title  LiquidityMath
/// @author Mellow Finance
library LiquidityMath {
  using FixedPointMath for FixedPointMath.Number;

  /// @dev Adds a signed delta to an unsigned integer.
  ///
  /// @param  x The unsigned value to add the delta to.
  /// @param  y The signed delta value to add.
  /// @return z The result.
  function addDelta(uint256 x, int256 y) internal pure returns (uint256 z) {
    if (y < 0) {
      if ((z = x - uint256(-y)) >= x) {
        revert IllegalArgument();
      }
    } else {
      if ((z = x + uint256(y)) < x) {
        revert IllegalArgument();
      }
    }
  }

  /// @dev Calculate a uint256 representation of x * y using FixedPointMath
  ///
  /// @param  x The first factor
  /// @param  y The second factor (fixed point)
  /// @return z The resulting product, after truncation
  function calculateProduct(uint256 x, FixedPointMath.Number memory y) internal pure returns (uint256 z) {
    z = y.mul(x).truncate();
  }

  /// @notice normalises non 18 digit token values to 18 digits.
  function normalizeValue(uint256 input, uint256 decimals) internal pure returns (uint256) {
    return (input * (10**18)) / (10**decimals);
  }

  /// @notice denormalizes 18 digits back to a token's digits
  function deNormalizeValue(uint256 input, uint256 decimals) internal pure returns (uint256) {
    return (input * (10**decimals)) / (10**18);
  }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IllegalArgument} from "../base/Errors.sol";

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
  /// @notice Cast a uint256 to a int256, revert on overflow
  /// @param y The uint256 to be casted
  /// @return z The casted integer, now type int256
  function toInt256(uint256 y) internal pure returns (int256 z) {
    if (y >= 2**255) {
      revert IllegalArgument();
    }
    z = int256(y);
  }

  /// @notice Cast a int256 to a uint256, revert on underflow
  /// @param y The int256 to be casted
  /// @return z The casted integer, now type uint256
  function toUint256(int256 y) internal pure returns (uint256 z) {
    if (y < 0) {
      revert IllegalArgument();
    }
    z = uint256(y);
  }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

/// @title  Sets
/// @author Mellow Finance
library Sets {
    using Sets for AddressSet;

    /// @notice A data structure holding an array of values with an index mapping for O(1) lookup.
    struct AddressSet {
        address[] values;
        mapping(address => uint256) indexes;
    }

    /// @dev Add a value to a Set
    ///
    /// @param self  The Set.
    /// @param value The value to add.
    ///
    /// @return Whether the operation was successful (unsuccessful if the value is already contained in the Set)
    function add(AddressSet storage self, address value) internal returns (bool) {
        if (self.contains(value)) {
            return false;
        }
        self.values.push(value);
        self.indexes[value] = self.values.length;
        return true;
    }

    /// @dev Remove a value from a Set
    ///
    /// @param self  The Set.
    /// @param value The value to remove.
    ///
    /// @return Whether the operation was successful (unsuccessful if the value was not contained in the Set)
    function remove(AddressSet storage self, address value) internal returns (bool) {
        uint256 index = self.indexes[value];
        if (index == 0) {
            return false;
        }

        // Normalize the index since we know that the element is in the set.
        index--;

        uint256 lastIndex = self.values.length - 1;

        if (index != lastIndex) {
            address lastValue = self.values[lastIndex];
            self.values[index] = lastValue;
            self.indexes[lastValue] = index + 1;
        }

        self.values.pop();

        delete self.indexes[value];

        return true;
    }

    /// @dev Returns true if the value exists in the Set
    ///
    /// @param self  The Set.
    /// @param value The value to check.
    ///
    /// @return True if the value is contained in the Set, False if it is not.
    function contains(AddressSet storage self, address value) internal view returns (bool) {
        return self.indexes[value] != 0;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import {FixedPointMath} from "./FixedPointMath.sol";

library Tick {
  using FixedPointMath for FixedPointMath.Number;

  struct Info {
    // The total number of unexchanged tokens that have been associated with this tick
    uint256 totalBalance;
    // The accumulated weight of the tick which is the sum of the previous ticks accumulated weight plus the weight
    // that added at the time that this tick was created
    FixedPointMath.Number accumulatedWeight;
    // The previous active node. When this value is zero then there is no predecessor
    uint256 prev;
    // The next active node. When this value is zero then there is no successor
    uint256 next;
  }

  struct Cache {
    // The mapping which specifies the ticks in the buffer
    mapping(uint256 => Info) values;
    // The current tick which is being written to
    uint256 position;
    // The first tick which will be examined when iterating through the queue
    uint256 head;
    // The last tick which new nodes will be appended after
    uint256 tail;
  }

  /// @dev Gets the next tick in the buffer.
  ///
  /// This increments the position in the buffer.
  ///
  /// @return The next tick.
  function next(Tick.Cache storage self) internal returns (Tick.Info storage) {
    self.position++;
    return self.values[self.position];
  }

  /// @dev Gets the current tick being written to.
  ///
  /// @return The current tick.
  function current(Tick.Cache storage self) internal view returns (Tick.Info storage) {
    return self.values[self.position];
  }

  /// @dev Gets the nth tick in the buffer.
  ///
  /// @param self The reference to the buffer.
  /// @param n    The nth tick to get.
  function get(Tick.Cache storage self, uint256 n) internal view returns (Tick.Info storage) {
    return self.values[n];
  }

  function getWeight(
    Tick.Cache storage self,
    uint256 from,
    uint256 to
  ) internal view returns (FixedPointMath.Number memory) {
    Tick.Info storage startingTick = self.values[from];
    Tick.Info storage endingTick = self.values[to];

    FixedPointMath.Number memory startingAccumulatedWeight = startingTick.accumulatedWeight;
    FixedPointMath.Number memory endingAccumulatedWeight = endingTick.accumulatedWeight;

    return endingAccumulatedWeight.sub(startingAccumulatedWeight);
  }

  function addLast(Tick.Cache storage self, uint256 id) internal {
    if (self.head == 0) {
      self.head = self.tail = id;
      return;
    }

    // Don't add the tick if it is already the tail. This has to occur after the check if the head
    // is null since the tail may not be updated once the queue is made empty.
    if (self.tail == id) {
      return;
    }

    Tick.Info storage tick = self.values[id];
    Tick.Info storage tail = self.values[self.tail];

    tick.prev = self.tail;
    tail.next = id;
    self.tail = id;
  }

  function remove(Tick.Cache storage self, uint256 id) internal {
    Tick.Info storage tick = self.values[id];

    // Update the head if it is the tick we are removing.
    if (self.head == id) {
      self.head = tick.next;
    }

    // Update the tail if it is the tick we are removing.
    if (self.tail == id) {
      self.tail = tick.prev;
    }

    // Unlink the previously occupied tick from the next tick in the list.
    if (tick.prev != 0) {
      self.values[tick.prev].next = tick.next;
    }

    // Unlink the previously occupied tick from the next tick in the list.
    if (tick.next != 0) {
      self.values[tick.next].prev = tick.prev;
    }

    // Zero out the pointers.
    // NOTE(nomad): This fixes the bug where the current accrued weight would get erased.
    self.values[id].next = 0;
    self.values[id].prev = 0;
  }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../interfaces/IERC20Burnable.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/IERC20Minimal.sol";
import "../interfaces/IERC20Mintable.sol";

/// @title  TokenUtils
/// @author Mellow Finance
library TokenUtils {
    /// @notice An error used to indicate that a call to an ERC20 contract failed.
    ///
    /// @param target  The target address.
    /// @param success If the call to the token was a success.
    /// @param data    The resulting data from the call. This is error data when the call was not a success. Otherwise,
    ///                this is malformed data when the call was a success.
    error ERC20CallFailed(address target, bool success, bytes data);

    /// @dev A safe function to get the decimals of an ERC20 token.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the query fails or returns an unexpected value.
    ///
    /// @param token The target token.
    ///
    /// @return The amount of decimals of the token.
    function expectDecimals(address token) internal view returns (uint8) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(IERC20Metadata.decimals.selector)
        );

        if (!success || data.length < 32) {
            revert ERC20CallFailed(token, success, data);
        }

        return abi.decode(data, (uint8));
    }

    /// @dev Gets the balance of tokens held by an account.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the query fails or returns an unexpected value.
    ///
    /// @param token   The token to check the balance of.
    /// @param account The address of the token holder.
    ///
    /// @return The balance of the tokens held by an account.
    function safeBalanceOf(address token, address account) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, account)
        );

        if (!success || data.length < 32) {
            revert ERC20CallFailed(token, success, data);
        }

        return abi.decode(data, (uint256));
    }

    /// @dev Transfers tokens to another address.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the transfer failed or returns an unexpected value.
    ///
    /// @param token     The token to transfer.
    /// @param recipient The address of the recipient.
    /// @param amount    The amount of tokens to transfer.
    function safeTransfer(address token, address recipient, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transfer.selector, recipient, amount)
        );

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Approves tokens for the smart contract.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the approval fails or returns an unexpected value.
    ///
    /// @param token   The token to approve.
    /// @param spender The contract to spend the tokens.
    /// @param value   The amount of tokens to approve.
    function safeApprove(address token, address spender, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.approve.selector, spender, value)
        );

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Transfer tokens from one address to another address.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the transfer fails or returns an unexpected value.
    ///
    /// @param token     The token to transfer.
    /// @param owner     The address of the owner.
    /// @param recipient The address of the recipient.
    /// @param amount    The amount of tokens to transfer.
    function safeTransferFrom(address token, address owner, address recipient, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, owner, recipient, amount)
        );

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Mints tokens to an address.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the mint fails or returns an unexpected value.
    ///
    /// @param token     The token to mint.
    /// @param recipient The address of the recipient.
    /// @param amount    The amount of tokens to mint.
    function safeMint(address token, address recipient, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Mintable.mint.selector, recipient, amount)
        );

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Burns tokens.
    ///
    /// Reverts with a `CallFailed` error if execution of the burn fails or returns an unexpected value.
    ///
    /// @param token  The token to burn.
    /// @param amount The amount of tokens to burn.
    function safeBurn(address token, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Burnable.burn.selector, amount)
        );

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }

    /// @dev Burns tokens from its total supply.
    ///
    /// @dev Reverts with a {CallFailed} error if execution of the burn fails or returns an unexpected value.
    ///
    /// @param token  The token to burn.
    /// @param owner  The owner of the tokens.
    /// @param amount The amount of tokens to burn.
    function safeBurnFrom(address token, address owner, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Burnable.burnFrom.selector, owner, amount)
        );

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC20CallFailed(token, success, data);
        }
    }
}