// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import './library/UtilLib.sol';

import './interfaces/IPenalty.sol';
import './interfaces/IRatedV1.sol';
import './interfaces/IStaderOracle.sol';
import './interfaces/IStaderConfig.sol';

import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

contract Penalty is IPenalty, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    IStaderConfig public staderConfig;
    address public override ratedOracleAddress;
    uint256 public override mevTheftPenaltyPerStrike;
    uint256 public override missedAttestationPenaltyPerStrike;
    uint256 public override validatorExitPenaltyThreshold;

    /// @inheritdoc IPenalty
    mapping(bytes32 => uint256) public override additionalPenaltyAmount;
    /// @inheritdoc IPenalty
    mapping(bytes => uint256) public override totalPenaltyAmount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _staderConfig,
        address _ratedOracleAddress
    ) external initializer {
        UtilLib.checkNonZeroAddress(_admin);
        UtilLib.checkNonZeroAddress(_staderConfig);
        UtilLib.checkNonZeroAddress(_ratedOracleAddress);
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        staderConfig = IStaderConfig(_staderConfig);
        ratedOracleAddress = _ratedOracleAddress;
        mevTheftPenaltyPerStrike = 1 ether;
        missedAttestationPenaltyPerStrike = 0.2 ether;
        validatorExitPenaltyThreshold = 2 ether;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        emit UpdatedPenaltyOracleAddress(_ratedOracleAddress);
    }

    /// @inheritdoc IPenalty
    function setAdditionalPenaltyAmount(bytes calldata _pubkey, uint256 _amount) external override {
        UtilLib.onlyManagerRole(msg.sender, staderConfig);
        bytes32 pubkeyRoot = UtilLib.getPubkeyRoot(_pubkey);
        additionalPenaltyAmount[pubkeyRoot] += _amount;

        emit UpdatedAdditionalPenaltyAmount(_pubkey, _amount);
    }

    /// @inheritdoc IPenalty
    function updateMEVTheftPenaltyPerStrike(uint256 _mevTheftPenaltyPerStrike) external override {
        UtilLib.onlyManagerRole(msg.sender, staderConfig);
        mevTheftPenaltyPerStrike = _mevTheftPenaltyPerStrike;
        emit UpdatedMEVTheftPenaltyPerStrike(_mevTheftPenaltyPerStrike);
    }

    /// @inheritdoc IPenalty
    function updateMissedAttestationPenaltyPerStrike(uint256 _missedAttestationPenaltyPerStrike) external override {
        UtilLib.onlyManagerRole(msg.sender, staderConfig);
        missedAttestationPenaltyPerStrike = _missedAttestationPenaltyPerStrike;
        emit UpdatedMissedAttestationPenaltyPerStrike(_missedAttestationPenaltyPerStrike);
    }

    /// @inheritdoc IPenalty
    function updateValidatorExitPenaltyThreshold(uint256 _validatorExitPenaltyThreshold) external override {
        UtilLib.onlyManagerRole(msg.sender, staderConfig);
        validatorExitPenaltyThreshold = _validatorExitPenaltyThreshold;
        emit UpdatedValidatorExitPenaltyThreshold(_validatorExitPenaltyThreshold);
    }

    /// @inheritdoc IPenalty
    function updateRatedOracleAddress(address _ratedOracleAddress) external override {
        UtilLib.onlyManagerRole(msg.sender, staderConfig);
        UtilLib.checkNonZeroAddress(_ratedOracleAddress);
        ratedOracleAddress = _ratedOracleAddress;
        emit UpdatedPenaltyOracleAddress(_ratedOracleAddress);
    }

    //update the address of staderConfig
    function updateStaderConfig(address _staderConfig) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_staderConfig);
        staderConfig = IStaderConfig(_staderConfig);
        emit UpdatedStaderConfig(_staderConfig);
    }

    /// @inheritdoc IPenalty
    function updateTotalPenaltyAmount(bytes[] calldata _pubkey) external override nonReentrant {
        uint256 reportedValidatorCount = _pubkey.length;
        for (uint256 i; i < reportedValidatorCount; ) {
            if (UtilLib.getValidatorSettleStatus(_pubkey[i], staderConfig)) {
                revert ValidatorSettled();
            }
            bytes32 pubkeyRoot = UtilLib.getPubkeyRoot(_pubkey[i]);
            // Retrieve the penalty for changing the fee recipient address based on Rated.network data.
            uint256 _mevTheftPenalty = calculateMEVTheftPenalty(pubkeyRoot);
            uint256 _missedAttestationPenalty = calculateMissedAttestationPenalty(pubkeyRoot);

            // Compute the total penalty for the given validator public key,
            // taking into account additional penalties and penalty reversals from the DAO.
            uint256 totalPenalty = _mevTheftPenalty + _missedAttestationPenalty + additionalPenaltyAmount[pubkeyRoot];
            totalPenaltyAmount[_pubkey[i]] = totalPenalty;
            if (totalPenalty >= validatorExitPenaltyThreshold) {
                emit ForceExitValidator(_pubkey[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IPenalty
    function calculateMEVTheftPenalty(bytes32 _pubkeyRoot) public override returns (uint256) {
        // Retrieve the epochs in which the validator violated the fee recipient change rule.
        uint256[] memory violatedEpochs = IRatedV1(ratedOracleAddress).getViolationsForValidator(_pubkeyRoot);

        // each strike attracts `mevTheftPenaltyPerStrike` penalty
        return violatedEpochs.length * mevTheftPenaltyPerStrike;
    }

    /// @inheritdoc IPenalty
    function calculateMissedAttestationPenalty(bytes32 _pubkeyRoot) public view override returns (uint256) {
        return
            IStaderOracle(staderConfig.getStaderOracle()).missedAttestationPenalty(_pubkeyRoot) *
            missedAttestationPenaltyPerStrike;
    }

    /// @inheritdoc IPenalty
    function getAdditionalPenaltyAmount(bytes calldata _pubkey) external view override returns (uint256) {
        return additionalPenaltyAmount[UtilLib.getPubkeyRoot(_pubkey)];
    }

    /// @inheritdoc IPenalty
    function markValidatorSettled(uint8 _poolId, uint256 _validatorId) external override {
        bytes memory pubkey = UtilLib.getPubkeyForValidSender(_poolId, _validatorId, msg.sender, staderConfig);
        totalPenaltyAmount[pubkey] = 0;
        emit ValidatorMarkedAsSettled(pubkey);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

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
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
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
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
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
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

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
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
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
        if (_initialized != type(uint8).max) {
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
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

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
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

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
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
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
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

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
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
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
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
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
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
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
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMathUpgradeable {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";
import "./math/SignedMathUpgradeable.sol";

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
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMathUpgradeable.abs(value))));
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

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import '../library/ValidatorStatus.sol';

struct Validator {
    ValidatorStatus status; // status of validator
    bytes pubkey; //pubkey of the validator
    bytes preDepositSignature; //signature for 1 ETH deposit on beacon chain
    bytes depositSignature; //signature for 31 ETH deposit on beacon chain
    address withdrawVaultAddress; //withdrawal vault address of validator
    uint256 operatorId; // stader network assigned Id
    uint256 depositBlock; // block number of the 31ETH deposit
    uint256 withdrawnBlock; //block number when oracle report validator as withdrawn
}

struct Operator {
    bool active; // operator status
    bool optedForSocializingPool; // operator opted for socializing pool
    string operatorName; // name of the operator
    address payable operatorRewardAddress; //Eth1 address of node for reward
    address operatorAddress; //address of operator to interact with stader
}

// Interface for the NodeRegistry contract
interface INodeRegistry {
    // Errors
    error DuplicatePoolIDOrPoolNotAdded();
    error OperatorAlreadyOnBoardedInProtocol();
    error maxKeyLimitReached();
    error OperatorNotOnBoarded();
    error InvalidKeyCount();
    error InvalidStartAndEndIndex();
    error OperatorIsDeactivate();
    error MisMatchingInputKeysSize();
    error PageNumberIsZero();
    error UNEXPECTED_STATUS();
    error PubkeyAlreadyExist();
    error NotEnoughSDCollateral();
    error TooManyVerifiedKeysReported();
    error TooManyWithdrawnKeysReported();

    // Events
    event AddedValidatorKey(address indexed nodeOperator, bytes pubkey, uint256 validatorId);
    event ValidatorMarkedAsFrontRunned(bytes pubkey, uint256 validatorId);
    event ValidatorWithdrawn(bytes pubkey, uint256 validatorId);
    event ValidatorStatusMarkedAsInvalidSignature(bytes pubkey, uint256 validatorId);
    event UpdatedValidatorDepositBlock(uint256 validatorId, uint256 depositBlock);
    event UpdatedMaxNonTerminalKeyPerOperator(uint64 maxNonTerminalKeyPerOperator);
    event UpdatedInputKeyCountLimit(uint256 batchKeyDepositLimit);
    event UpdatedStaderConfig(address staderConfig);
    event UpdatedOperatorDetails(address indexed nodeOperator, string operatorName, address rewardAddress);
    event IncreasedTotalActiveValidatorCount(uint256 totalActiveValidatorCount);
    event UpdatedVerifiedKeyBatchSize(uint256 verifiedKeysBatchSize);
    event UpdatedWithdrawnKeyBatchSize(uint256 withdrawnKeysBatchSize);
    event DecreasedTotalActiveValidatorCount(uint256 totalActiveValidatorCount);

    function withdrawnValidators(bytes[] calldata _pubkeys) external;

    function markValidatorReadyToDeposit(
        bytes[] calldata _readyToDepositPubkey,
        bytes[] calldata _frontRunPubkey,
        bytes[] calldata _invalidSignaturePubkey
    ) external;

    // return validator struct for a validator Id
    function validatorRegistry(uint256)
        external
        view
        returns (
            ValidatorStatus status,
            bytes calldata pubkey,
            bytes calldata preDepositSignature,
            bytes calldata depositSignature,
            address withdrawVaultAddress,
            uint256 operatorId,
            uint256 depositTime,
            uint256 withdrawnTime
        );

    // returns the operator struct given operator Id
    function operatorStructById(uint256)
        external
        view
        returns (
            bool active,
            bool optedForSocializingPool,
            string calldata operatorName,
            address payable operatorRewardAddress,
            address operatorAddress
        );

    // Returns the last block the operator changed the opt-in status for socializing pool
    function getSocializingPoolStateChangeBlock(uint256 _operatorId) external view returns (uint256);

    function getAllActiveValidators(uint256 _pageNumber, uint256 _pageSize) external view returns (Validator[] memory);

    function getValidatorsByOperator(
        address _operator,
        uint256 _pageNumber,
        uint256 _pageSize
    ) external view returns (Validator[] memory);

    /**
     *
     * @param _nodeOperator @notice operator total non withdrawn keys within a specified validator list
     * @param _startIndex start index in validator queue to start with
     * @param _endIndex  up to end index of validator queue to to count
     */
    function getOperatorTotalNonTerminalKeys(
        address _nodeOperator,
        uint256 _startIndex,
        uint256 _endIndex
    ) external view returns (uint64);

    // returns the total number of queued validators across all operators
    function getTotalQueuedValidatorCount() external view returns (uint256);

    // returns the total number of active validators across all operators
    function getTotalActiveValidatorCount() external view returns (uint256);

    function getCollateralETH() external view returns (uint256);

    function getOperatorTotalKeys(uint256 _operatorId) external view returns (uint256 totalKeys);

    function operatorIDByAddress(address) external view returns (uint256);

    function getOperatorRewardAddress(uint256 _operatorId) external view returns (address payable);

    function isExistingPubkey(bytes calldata _pubkey) external view returns (bool);

    function isExistingOperator(address _operAddr) external view returns (bool);

    function POOL_ID() external view returns (uint8);

    function inputKeyCountLimit() external view returns (uint16);

    function nextOperatorId() external view returns (uint256);

    function nextValidatorId() external view returns (uint256);

    function maxNonTerminalKeyPerOperator() external view returns (uint64);

    function verifiedKeyBatchSize() external view returns (uint256);

    function totalActiveValidatorCount() external view returns (uint256);

    function validatorIdByPubkey(bytes calldata _pubkey) external view returns (uint256);

    function validatorIdsByOperatorId(uint256, uint256) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// Interface for the Penalty contract
interface IPenalty {
    // Errors
    error ValidatorSettled();

    // Events
    event UpdatedAdditionalPenaltyAmount(bytes pubkey, uint256 amount);
    event UpdatedMEVTheftPenaltyPerStrike(uint256 mevTheftPenalty);
    event UpdatedPenaltyOracleAddress(address penaltyOracleAddress);
    event UpdatedMissedAttestationPenaltyPerStrike(uint256 missedAttestationPenalty);
    event UpdatedValidatorExitPenaltyThreshold(uint256 totalPenaltyThreshold);
    event ForceExitValidator(bytes pubkey);
    event UpdatedStaderConfig(address staderConfig);
    event ValidatorMarkedAsSettled(bytes pubkey);

    // returns the address of the Rated.network penalty oracle
    function ratedOracleAddress() external view returns (address);

    // returns the penalty amount for a single violation
    function mevTheftPenaltyPerStrike() external view returns (uint256);

    //returns the penalty amount for missing attestation below a certain threshold
    function missedAttestationPenaltyPerStrike() external view returns (uint256);

    // returns the totalPenalty threshold after which validator is force exited
    function validatorExitPenaltyThreshold() external view returns (uint256);

    // returns the additional penalty amount of a validator given its pubkey root
    function additionalPenaltyAmount(bytes32 _pubkeyRoot) external view returns (uint256);

    // returns the total penalty amount of a validator given its pubkey
    function totalPenaltyAmount(bytes calldata _pubkey) external view returns (uint256);

    // Setters

    // Sets the address of the Rated.network penalty oracle.
    function updateRatedOracleAddress(address _penaltyOracleAddress) external;

    function updateStaderConfig(address _staderConfig) external;

    // Sets the penalty amount for a single violation.
    //This is the amount that will be imposed for each violation after first violation
    function updateMEVTheftPenaltyPerStrike(uint256 _mevTheftPenaltyPerStrike) external;

    // sets the penalty amount for missing attestation below a threshold for a cycle
    function updateMissedAttestationPenaltyPerStrike(uint256 _missedAttestationPenaltyPerStrike) external;

    // update the value of totalPenaltyThreshold
    function updateValidatorExitPenaltyThreshold(uint256 _validatorExitPenaltyThreshold) external;

    /**
     * @notice Sets the additional penalty amount given by the DAO for a given validator public key.
     * @param _pubkey The validator public key for which to set the additional penalty amount.
     * @param _amount The additional penalty amount to set for the given validator public key.
     */
    function setAdditionalPenaltyAmount(bytes calldata _pubkey, uint256 _amount) external;

    // Getters

    // Returns the additional penalty amount given by the DAO for a given public key.
    function getAdditionalPenaltyAmount(bytes calldata _pubkey) external view returns (uint256);

    /**
     * @notice update the total penalty amount for a given public key and store in a map.
     * @param _pubkey The public key of the validator for which to calculate the penalty.
     */
    function updateTotalPenaltyAmount(bytes[] calldata _pubkey) external;

    /**
     * @notice Calculates the penalty for changing the fee recipient address for a given public key
     *         based on data from the Rated.network penalty oracle.
     * @param _pubkeyRoot The public key root for which to calculate the penalty.
     * @return The penalty for changing the fee recipient address.
     */
    function calculateMEVTheftPenalty(bytes32 _pubkeyRoot) external returns (uint256);

    /**
     * @notice calculate penalty for missing attestation below a certain threshold
     * @param _pubkeyRoot The public key root for which to calculate the penalty.
     * @return penalty for missing attestation
     */
    function calculateMissedAttestationPenalty(bytes32 _pubkeyRoot) external returns (uint256);

    /**
     * @notice make the totalPenalty amount as 0 and marked validator as settled
     * @param _poolId pool Id of the validator
     * @param _validatorId validator Id of a validator
     * @dev only validator withdraw vault can call
     */
    function markValidatorSettled(uint8 _poolId, uint256 _validatorId) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import './INodeRegistry.sol';

// Interface for the PoolUtils contract
interface IPoolUtils {
    // Errors
    error EmptyNameString();
    error PoolIdNotPresent();
    error PubkeyDoesNotExit();
    error PubkeyAlreadyExist();
    error NameCrossedMaxLength();
    error InvalidLengthOfPubkey();
    error OperatorIsNotOnboarded();
    error InvalidLengthOfSignature();
    error ExistingOrMismatchingPoolId();

    // Events
    event PoolAdded(uint8 indexed poolId, address poolAddress);
    event PoolAddressUpdated(uint8 indexed poolId, address poolAddress);
    event DeactivatedPool(uint8 indexed poolId, address poolAddress);
    event UpdatedStaderConfig(address staderConfig);
    event ExitValidator(bytes pubkey);

    // returns the details of a specific pool
    function poolAddressById(uint8) external view returns (address poolAddress);

    function poolIdArray(uint256) external view returns (uint8);

    function getPoolIdArray() external view returns (uint8[] memory);

    // Pool functions
    function addNewPool(uint8 _poolId, address _poolAddress) external;

    function updatePoolAddress(uint8 _poolId, address _poolAddress) external;

    function processValidatorExitList(bytes[] calldata _pubkeys) external;

    function getOperatorTotalNonTerminalKeys(
        uint8 _poolId,
        address _nodeOperator,
        uint256 _startIndex,
        uint256 _endIndex
    ) external view returns (uint256);

    function getSocializingPoolAddress(uint8 _poolId) external view returns (address);

    // Pool getters
    function getProtocolFee(uint8 _poolId) external view returns (uint256); // returns the protocol fee (0-10000)

    function getOperatorFee(uint8 _poolId) external view returns (uint256); // returns the operator fee (0-10000)

    function getTotalActiveValidatorCount() external view returns (uint256); //returns total active validators across all pools

    function getActiveValidatorCountByPool(uint8 _poolId) external view returns (uint256); // returns the total number of active validators in a specific pool

    function getQueuedValidatorCountByPool(uint8 _poolId) external view returns (uint256); // returns the total number of queued validators in a specific pool

    function getCollateralETH(uint8 _poolId) external view returns (uint256);

    function getNodeRegistry(uint8 _poolId) external view returns (address);

    // check for duplicate pubkey across all pools
    function isExistingPubkey(bytes calldata _pubkey) external view returns (bool);

    // check for duplicate operator across all pools
    function isExistingOperator(address _operAddr) external view returns (bool);

    function isExistingPoolId(uint8 _poolId) external view returns (bool);

    function getOperatorPoolId(address _operAddr) external view returns (uint8);

    function getValidatorPoolId(bytes calldata _pubkey) external view returns (uint8);

    function onlyValidName(string calldata _name) external;

    function onlyValidKeys(
        bytes calldata _pubkey,
        bytes calldata _preDepositSignature,
        bytes calldata _depositSignature
    ) external;

    function calculateRewardShare(uint8 _poolId, uint256 _totalRewards)
        external
        view
        returns (
            uint256 userShare,
            uint256 operatorShare,
            uint256 protocolShare
        );
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

interface IRatedV1 {
    function getViolationsForValidator(bytes32 _pubKeyRoot) external returns (uint256[] memory violatedEpoch);

    function isValidatorInDispute(bytes32 _pubKeyRoot) external returns (bool _isInUnfinishedDispute);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import './IStaderConfig.sol';

/// @title RewardsData
/// @notice This struct holds rewards merkleRoot and rewards split
struct RewardsData {
    /// @notice The block number when the rewards data was last updated
    uint256 reportingBlockNumber;
    /// @notice The index of merkle tree or rewards cycle
    uint256 index;
    /// @notice The merkle root hash
    bytes32 merkleRoot;
    /// @notice pool id of operators
    uint8 poolId;
    /// @notice operator ETH rewards for index cycle
    uint256 operatorETHRewards;
    /// @notice user ETH rewards for index cycle
    uint256 userETHRewards;
    /// @notice protocol ETH rewards for index cycle
    uint256 protocolETHRewards;
    /// @notice operator SD rewards for index cycle
    uint256 operatorSDRewards;
}

interface ISocializingPool {
    // errors
    error ETHTransferFailed(address recipient, uint256 amount);
    error SDTransferFailed();
    error RewardAlreadyHandled();
    error RewardAlreadyClaimed(address operator, uint256 cycle);
    error InsufficientETHRewards();
    error InsufficientSDRewards();
    error InvalidAmount();
    error InvalidProof(uint256 cycle, address operator);
    error InvalidCycleIndex();
    error FutureCycleIndex();

    // events
    event UpdatedStaderConfig(address indexed staderConfig);
    event ETHReceived(address indexed sender, uint256 amount);
    event UpdatedStaderValidatorRegistry(address indexed staderValidatorRegistry);
    event UpdatedStaderOperatorRegistry(address indexed staderOperatorRegistry);
    event OperatorRewardsClaimed(address indexed recipient, uint256 ethRewards, uint256 sdRewards);
    event OperatorRewardsUpdated(
        uint256 ethRewards,
        uint256 totalETHRewards,
        uint256 sdRewards,
        uint256 totalSDRewards
    );

    event UserETHRewardsTransferred(uint256 ethRewards);
    event ProtocolETHRewardsTransferred(uint256 ethRewards);

    // methods
    function handleRewards(RewardsData calldata _rewardsData) external;

    function claim(
        uint256[] calldata _index,
        uint256[] calldata _amountSD,
        uint256[] calldata _amountETH,
        bytes32[][] calldata _merkleProof
    ) external;

    // setters
    function updateStaderConfig(address _staderConfig) external;

    // getters
    function staderConfig() external view returns (IStaderConfig);

    function claimedRewards(address _user, uint256 _index) external view returns (bool);

    function totalOperatorETHRewardsRemaining() external view returns (uint256);

    function totalOperatorSDRewardsRemaining() external view returns (uint256);

    function initialBlock() external view returns (uint256);

    function verifyProof(
        uint256 _index,
        address _operator,
        uint256 _amountSD,
        uint256 _amountETH,
        bytes32[] calldata _merkleProof
    ) external view returns (bool);

    function getCurrentRewardsIndex() external view returns (uint256 index);

    function getRewardDetails()
        external
        view
        returns (
            uint256 currentIndex,
            uint256 currentStartBlock,
            uint256 currentEndBlock
        );

    function getRewardCycleDetails(uint256 _index) external view returns (uint256 _startBlock, uint256 _endBlock);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IStaderConfig {
    // Errors
    error InvalidLimits();
    error InvalidMinDepositValue();
    error InvalidMaxDepositValue();
    error InvalidMinWithdrawValue();
    error InvalidMaxWithdrawValue();

    // Events
    event SetConstant(bytes32 key, uint256 amount);
    event SetVariable(bytes32 key, uint256 amount);
    event SetAccount(bytes32 key, address newAddress);
    event SetContract(bytes32 key, address newAddress);
    event SetToken(bytes32 key, address newAddress);

    //Contracts
    function POOL_UTILS() external view returns (bytes32);

    function POOL_SELECTOR() external view returns (bytes32);

    function SD_COLLATERAL() external view returns (bytes32);

    function OPERATOR_REWARD_COLLECTOR() external view returns (bytes32);

    function VAULT_FACTORY() external view returns (bytes32);

    function STADER_ORACLE() external view returns (bytes32);

    function AUCTION_CONTRACT() external view returns (bytes32);

    function PENALTY_CONTRACT() external view returns (bytes32);

    function PERMISSIONED_POOL() external view returns (bytes32);

    function STAKE_POOL_MANAGER() external view returns (bytes32);

    function ETH_DEPOSIT_CONTRACT() external view returns (bytes32);

    function PERMISSIONLESS_POOL() external view returns (bytes32);

    function USER_WITHDRAW_MANAGER() external view returns (bytes32);

    function STADER_INSURANCE_FUND() external view returns (bytes32);

    function PERMISSIONED_NODE_REGISTRY() external view returns (bytes32);

    function PERMISSIONLESS_NODE_REGISTRY() external view returns (bytes32);

    function PERMISSIONED_SOCIALIZING_POOL() external view returns (bytes32);

    function PERMISSIONLESS_SOCIALIZING_POOL() external view returns (bytes32);

    function NODE_EL_REWARD_VAULT_IMPLEMENTATION() external view returns (bytes32);

    function VALIDATOR_WITHDRAWAL_VAULT_IMPLEMENTATION() external view returns (bytes32);

    //POR Feed Proxy
    function ETH_BALANCE_POR_FEED() external view returns (bytes32);

    function ETHX_SUPPLY_POR_FEED() external view returns (bytes32);

    //Roles
    function MANAGER() external view returns (bytes32);

    function OPERATOR() external view returns (bytes32);

    // Constants
    function getStakedEthPerNode() external view returns (uint256);

    function getPreDepositSize() external view returns (uint256);

    function getFullDepositSize() external view returns (uint256);

    function getDecimals() external view returns (uint256);

    function getTotalFee() external view returns (uint256);

    function getOperatorMaxNameLength() external view returns (uint256);

    // Variables
    function getSocializingPoolCycleDuration() external view returns (uint256);

    function getSocializingPoolOptInCoolingPeriod() external view returns (uint256);

    function getRewardsThreshold() external view returns (uint256);

    function getMinDepositAmount() external view returns (uint256);

    function getMaxDepositAmount() external view returns (uint256);

    function getMinWithdrawAmount() external view returns (uint256);

    function getMaxWithdrawAmount() external view returns (uint256);

    function getMinBlockDelayToFinalizeWithdrawRequest() external view returns (uint256);

    function getWithdrawnKeyBatchSize() external view returns (uint256);

    // Accounts
    function getAdmin() external view returns (address);

    function getStaderTreasury() external view returns (address);

    // Contracts
    function getPoolUtils() external view returns (address);

    function getPoolSelector() external view returns (address);

    function getSDCollateral() external view returns (address);

    function getOperatorRewardsCollector() external view returns (address);

    function getVaultFactory() external view returns (address);

    function getStaderOracle() external view returns (address);

    function getAuctionContract() external view returns (address);

    function getPenaltyContract() external view returns (address);

    function getPermissionedPool() external view returns (address);

    function getStakePoolManager() external view returns (address);

    function getETHDepositContract() external view returns (address);

    function getPermissionlessPool() external view returns (address);

    function getUserWithdrawManager() external view returns (address);

    function getStaderInsuranceFund() external view returns (address);

    function getPermissionedNodeRegistry() external view returns (address);

    function getPermissionlessNodeRegistry() external view returns (address);

    function getPermissionedSocializingPool() external view returns (address);

    function getPermissionlessSocializingPool() external view returns (address);

    function getNodeELRewardVaultImplementation() external view returns (address);

    function getValidatorWithdrawalVaultImplementation() external view returns (address);

    function getETHBalancePORFeedProxy() external view returns (address);

    function getETHXSupplyPORFeedProxy() external view returns (address);

    // Tokens
    function getStaderToken() external view returns (address);

    function getETHxToken() external view returns (address);

    //checks roles and stader contracts
    function onlyStaderContract(address _addr, bytes32 _contractName) external view returns (bool);

    function onlyManagerRole(address account) external view returns (bool);

    function onlyOperatorRole(address account) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import '../library/ValidatorStatus.sol';

import './ISocializingPool.sol';
import './IStaderConfig.sol';

struct SDPriceData {
    uint256 reportingBlockNumber;
    uint256 sdPriceInETH;
}

/// @title MissedAttestationPenaltyData
/// @notice This struct holds missed attestation penalty data
struct MissedAttestationPenaltyData {
    /// @notice The block number when the missed attestation penalty data is reported
    uint256 reportingBlockNumber;
    /// @notice The index of missed attestation penalty data
    uint256 index;
    /// @notice missed attestation validator pubkeys
    bytes[] sortedPubkeys;
}

struct MissedAttestationReportInfo {
    uint256 index;
    uint256 pageNumber;
}

/// @title ExchangeRate
/// @notice This struct holds data related to the exchange rate between ETH and ETHX.
struct ExchangeRate {
    /// @notice The block number when the exchange rate was last updated.
    uint256 reportingBlockNumber;
    /// @notice The total balance of Ether (ETH) in the system.
    uint256 totalETHBalance;
    /// @notice The total supply of the liquid staking token (ETHX) in the system.
    uint256 totalETHXSupply;
}

/// @title ValidatorStats
/// @notice This struct holds statistics related to validators in the beaconchain.
struct ValidatorStats {
    /// @notice The block number when the validator stats was last updated.
    uint256 reportingBlockNumber;
    /// @notice The total balance of all exiting validators.
    uint128 exitingValidatorsBalance;
    /// @notice The total balance of all exited validators.
    uint128 exitedValidatorsBalance;
    /// @notice The total balance of all slashed validators.
    uint128 slashedValidatorsBalance;
    /// @notice The number of currently exiting validators.
    uint32 exitingValidatorsCount;
    /// @notice The number of validators that have exited.
    uint32 exitedValidatorsCount;
    /// @notice The number of validators that have been slashed.
    uint32 slashedValidatorsCount;
}

struct WithdrawnValidators {
    uint256 reportingBlockNumber;
    address nodeRegistry;
    bytes[] sortedPubkeys;
}

interface IStaderOracle {
    // Error
    error InvalidUpdate();
    error NodeAlreadyTrusted();
    error NodeNotTrusted();
    error ZeroFrequency();
    error FrequencyUnchanged();
    error DuplicateSubmissionFromNode();
    error ReportingFutureBlockData();
    error InvalidMerkleRootIndex();
    error ReportingPreviousCycleData();
    error InvalidMAPDIndex();
    error PageNumberAlreadyReported();
    error NotATrustedNode();
    error InvalidERDataSource();
    error InspectionModeActive();
    error UpdateFrequencyNotSet();
    error InvalidReportingBlock();
    error ERChangeLimitCrossed();
    error ERChangeLimitNotCrossed();
    error ERPermissibleChangeOutofBounds();
    error InsufficientTrustedNodes();
    error CooldownNotComplete();

    // Events
    event ERDataSourceToggled(bool isPORBasedERData);
    event UpdatedERChangeLimit(uint256 erChangeLimit);
    event ERInspectionModeActivated(bool erInspectionMode, uint256 time);
    event ExchangeRateSubmitted(
        address indexed from,
        uint256 block,
        uint256 totalEth,
        uint256 ethxSupply,
        uint256 time
    );
    event ExchangeRateUpdated(uint256 block, uint256 totalEth, uint256 ethxSupply, uint256 time);
    event TrustedNodeAdded(address indexed node);
    event TrustedNodeRemoved(address indexed node);
    event SocializingRewardsMerkleRootSubmitted(
        address indexed node,
        uint256 index,
        bytes32 merkleRoot,
        uint8 poolId,
        uint256 block
    );
    event SocializingRewardsMerkleRootUpdated(uint256 index, bytes32 merkleRoot, uint8 poolId, uint256 block);
    event SDPriceSubmitted(address indexed node, uint256 sdPriceInETH, uint256 reportedBlock, uint256 block);
    event SDPriceUpdated(uint256 sdPriceInETH, uint256 reportedBlock, uint256 block);

    event MissedAttestationPenaltySubmitted(
        address indexed node,
        uint256 index,
        uint256 block,
        uint256 reportingBlockNumber,
        bytes[] pubkeys
    );
    event MissedAttestationPenaltyUpdated(uint256 index, uint256 block, bytes[] pubkeys);
    event UpdateFrequencyUpdated(uint256 updateFrequency);
    event ValidatorStatsSubmitted(
        address indexed from,
        uint256 block,
        uint256 activeValidatorsBalance,
        uint256 exitedValidatorsBalance,
        uint256 slashedValidatorsBalance,
        uint256 activeValidatorsCount,
        uint256 exitedValidatorsCount,
        uint256 slashedValidatorsCount,
        uint256 time
    );
    event ValidatorStatsUpdated(
        uint256 block,
        uint256 activeValidatorsBalance,
        uint256 exitedValidatorsBalance,
        uint256 slashedValidatorsBalance,
        uint256 activeValidatorsCount,
        uint256 exitedValidatorsCount,
        uint256 slashedValidatorsCount,
        uint256 time
    );
    event WithdrawnValidatorsSubmitted(
        address indexed from,
        uint256 block,
        address nodeRegistry,
        bytes[] pubkeys,
        uint256 time
    );
    event WithdrawnValidatorsUpdated(uint256 block, address nodeRegistry, bytes[] pubkeys, uint256 time);
    event SafeModeEnabled();
    event SafeModeDisabled();
    event UpdatedStaderConfig(address staderConfig);
    event TrustedNodeChangeCoolingPeriodUpdated(uint256 trustedNodeChangeCoolingPeriod);

    // methods

    function addTrustedNode(address _nodeAddress) external;

    function removeTrustedNode(address _nodeAddress) external;

    /**
     * @notice submit exchange rate data by trusted oracle nodes
    @dev Submits the given balances for a specified block number.
    @param _exchangeRate The exchange rate to submit.
    */
    function submitExchangeRateData(ExchangeRate calldata _exchangeRate) external;

    //update the exchange rate via POR Feed data
    function updateERFromPORFeed() external;

    //update exchange rate via POR Feed when ER change limit is crossed
    function closeERInspectionMode() external;

    function disableERInspectionMode() external;

    /**
    @notice Submits the root of the merkle tree containing the socializing rewards.
    sends user ETH Rewards to SSPM
    sends protocol ETH Rewards to stader treasury
    @param _rewardsData contains rewards merkleRoot and rewards split
    */
    function submitSocializingRewardsMerkleRoot(RewardsData calldata _rewardsData) external;

    function submitSDPrice(SDPriceData calldata _sdPriceData) external;

    /**
     * @notice Submit validator stats for a specific block.
     * @dev This function can only be called by trusted nodes.
     * @param _validatorStats The validator stats to submit.
     *
     * Function Flow:
     * 1. Validates that the submission is for a past block and not a future one.
     * 2. Validates that the submission is for a block higher than the last block number with updated counts.
     * 3. Generates submission keys using the input parameters.
     * 4. Validates that this is not a duplicate submission from the same node.
     * 5. Updates the submission count for the given counts.
     * 6. Emits a ValidatorCountsSubmitted event with the submitted data.
     * 7. If the submission count reaches a majority (trustedNodesCount / 2 + 1), checks whether the counts are not already updated,
     *    then updates the validator counts, and emits a CountsUpdated event.
     */
    function submitValidatorStats(ValidatorStats calldata _validatorStats) external;

    /// @notice Submit the withdrawn validators list to the oracle.
    /// @dev The function checks if the submitted data is for a valid and newer block,
    ///      and if the submission count reaches the required threshold, it updates the withdrawn validators list (NodeRegistry).
    /// @param _withdrawnValidators The withdrawn validators data, including lastUpdatedBlockNumber and sorted pubkeys.
    function submitWithdrawnValidators(WithdrawnValidators calldata _withdrawnValidators) external;

    /**
     * @notice store the missed attestation penalty strike on validator
     * @dev _missedAttestationPenaltyData.index should not be zero
     * @param _mapd missed attestation penalty data
     */
    function submitMissedAttestationPenalties(MissedAttestationPenaltyData calldata _mapd) external;

    // setters
    // enable the safeMode depending on network and protocol health
    function enableSafeMode() external;

    // disable safe mode
    function disableSafeMode() external;

    function updateStaderConfig(address _staderConfig) external;

    function setERUpdateFrequency(uint256 _updateFrequency) external;

    function setSDPriceUpdateFrequency(uint256 _updateFrequency) external;

    function setValidatorStatsUpdateFrequency(uint256 _updateFrequency) external;

    function setWithdrawnValidatorsUpdateFrequency(uint256 _updateFrequency) external;

    function setMissedAttestationPenaltyUpdateFrequency(uint256 _updateFrequency) external;

    function updateERChangeLimit(uint256 _erChangeLimit) external;

    function togglePORFeedBasedERData() external;

    // getters
    function trustedNodeChangeCoolingPeriod() external view returns (uint256);

    function lastTrustedNodeCountChangeBlock() external view returns (uint256);

    function erInspectionMode() external view returns (bool);

    function isPORFeedBasedERData() external view returns (bool);

    function staderConfig() external view returns (IStaderConfig);

    function erChangeLimit() external view returns (uint256);

    function reportingBlockNumberForWithdrawnValidators() external view returns (uint256);

    // returns the count of trusted nodes
    function trustedNodesCount() external view returns (uint256);

    //returns the latest consensus index for missed attestation penalty data report
    function lastReportedMAPDIndex() external view returns (uint256);

    function erInspectionModeStartBlock() external view returns (uint256);

    function safeMode() external view returns (bool);

    function isTrustedNode(address) external view returns (bool);

    function missedAttestationPenalty(bytes32 _pubkey) external view returns (uint16);

    // The last updated merkle tree index
    function getCurrentRewardsIndexByPoolId(uint8 _poolId) external view returns (uint256);

    function getERReportableBlock() external view returns (uint256);

    function getMerkleRootReportableBlockByPoolId(uint8 _poolId) external view returns (uint256);

    function getSDPriceReportableBlock() external view returns (uint256);

    function getValidatorStatsReportableBlock() external view returns (uint256);

    function getWithdrawnValidatorReportableBlock() external view returns (uint256);

    function getMissedAttestationPenaltyReportableBlock() external view returns (uint256);

    function getExchangeRate() external view returns (ExchangeRate memory);

    function getValidatorStats() external view returns (ValidatorStats memory);

    // returns price of 1 SD in ETH
    function getSDPriceInETH() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import './IStaderConfig.sol';

interface IVaultProxy {
    error CallerNotOwner();
    error AlreadyInitialized();
    event UpdatedOwner(address owner);
    event UpdatedStaderConfig(address staderConfig);

    //Getters
    function vaultSettleStatus() external view returns (bool);

    function isValidatorWithdrawalVault() external view returns (bool);

    function isInitialized() external view returns (bool);

    function poolId() external view returns (uint8);

    function id() external view returns (uint256);

    function owner() external view returns (address);

    function staderConfig() external view returns (IStaderConfig);

    //Setters
    function updateOwner() external;

    function updateStaderConfig(address _staderConfig) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import '../interfaces/IStaderConfig.sol';
import '../interfaces/INodeRegistry.sol';
import '../interfaces/IPoolUtils.sol';
import '../interfaces/IVaultProxy.sol';

library UtilLib {
    error ZeroAddress();
    error InvalidPubkeyLength();
    error CallerNotManager();
    error CallerNotOperator();
    error CallerNotStaderContract();
    error CallerNotWithdrawVault();
    error TransferFailed();

    uint64 private constant VALIDATOR_PUBKEY_LENGTH = 48;

    /// @notice zero address check modifier
    function checkNonZeroAddress(address _address) internal pure {
        if (_address == address(0)) revert ZeroAddress();
    }

    //checks for Manager role in staderConfig
    function onlyManagerRole(address _addr, IStaderConfig _staderConfig) internal view {
        if (!_staderConfig.onlyManagerRole(_addr)) {
            revert CallerNotManager();
        }
    }

    function onlyOperatorRole(address _addr, IStaderConfig _staderConfig) internal view {
        if (!_staderConfig.onlyOperatorRole(_addr)) {
            revert CallerNotOperator();
        }
    }

    //checks if caller is a stader contract address
    function onlyStaderContract(
        address _addr,
        IStaderConfig _staderConfig,
        bytes32 _contractName
    ) internal view {
        if (!_staderConfig.onlyStaderContract(_addr, _contractName)) {
            revert CallerNotStaderContract();
        }
    }

    function getPubkeyForValidSender(
        uint8 _poolId,
        uint256 _validatorId,
        address _addr,
        IStaderConfig _staderConfig
    ) internal view returns (bytes memory) {
        address nodeRegistry = IPoolUtils(_staderConfig.getPoolUtils()).getNodeRegistry(_poolId);
        (, bytes memory pubkey, , , address withdrawVaultAddress, , , ) = INodeRegistry(nodeRegistry).validatorRegistry(
            _validatorId
        );
        if (_addr != withdrawVaultAddress) {
            revert CallerNotWithdrawVault();
        }
        return pubkey;
    }

    function getOperatorForValidSender(
        uint8 _poolId,
        uint256 _validatorId,
        address _addr,
        IStaderConfig _staderConfig
    ) internal view returns (address) {
        address nodeRegistry = IPoolUtils(_staderConfig.getPoolUtils()).getNodeRegistry(_poolId);
        (, , , , address withdrawVaultAddress, uint256 operatorId, , ) = INodeRegistry(nodeRegistry).validatorRegistry(
            _validatorId
        );
        if (_addr != withdrawVaultAddress) {
            revert CallerNotWithdrawVault();
        }
        (, , , , address operator) = INodeRegistry(nodeRegistry).operatorStructById(operatorId);
        return operator;
    }

    function onlyValidatorWithdrawVault(
        uint8 _poolId,
        uint256 _validatorId,
        address _addr,
        IStaderConfig _staderConfig
    ) internal view {
        address nodeRegistry = IPoolUtils(_staderConfig.getPoolUtils()).getNodeRegistry(_poolId);
        (, , , , address withdrawVaultAddress, , , ) = INodeRegistry(nodeRegistry).validatorRegistry(_validatorId);
        if (_addr != withdrawVaultAddress) {
            revert CallerNotWithdrawVault();
        }
    }

    function getOperatorAddressByValidatorId(
        uint8 _poolId,
        uint256 _validatorId,
        IStaderConfig _staderConfig
    ) internal view returns (address) {
        address nodeRegistry = IPoolUtils(_staderConfig.getPoolUtils()).getNodeRegistry(_poolId);
        (, , , , , uint256 operatorId, , ) = INodeRegistry(nodeRegistry).validatorRegistry(_validatorId);
        (, , , , address operatorAddress) = INodeRegistry(nodeRegistry).operatorStructById(operatorId);

        return operatorAddress;
    }

    function getOperatorAddressByOperatorId(
        uint8 _poolId,
        uint256 _operatorId,
        IStaderConfig _staderConfig
    ) internal view returns (address) {
        address nodeRegistry = IPoolUtils(_staderConfig.getPoolUtils()).getNodeRegistry(_poolId);
        (, , , , address operatorAddress) = INodeRegistry(nodeRegistry).operatorStructById(_operatorId);

        return operatorAddress;
    }

    function getOperatorRewardAddress(address _operator, IStaderConfig _staderConfig)
        internal
        view
        returns (address payable)
    {
        uint8 poolId = IPoolUtils(_staderConfig.getPoolUtils()).getOperatorPoolId(_operator);
        address nodeRegistry = IPoolUtils(_staderConfig.getPoolUtils()).getNodeRegistry(poolId);
        uint256 operatorId = INodeRegistry(nodeRegistry).operatorIDByAddress(_operator);
        return INodeRegistry(nodeRegistry).getOperatorRewardAddress(operatorId);
    }

    /**
     * @notice Computes the public key root.
     * @param _pubkey The validator public key for which to compute the root.
     * @return The root of the public key.
     */
    function getPubkeyRoot(bytes calldata _pubkey) internal pure returns (bytes32) {
        if (_pubkey.length != VALIDATOR_PUBKEY_LENGTH) {
            revert InvalidPubkeyLength();
        }

        // Append 16 bytes of zero padding to the pubkey and compute its hash to get the pubkey root.
        return sha256(abi.encodePacked(_pubkey, bytes16(0)));
    }

    function getValidatorSettleStatus(bytes calldata _pubkey, IStaderConfig _staderConfig)
        internal
        view
        returns (bool)
    {
        uint8 poolId = IPoolUtils(_staderConfig.getPoolUtils()).getValidatorPoolId(_pubkey);
        address nodeRegistry = IPoolUtils(_staderConfig.getPoolUtils()).getNodeRegistry(poolId);
        uint256 validatorId = INodeRegistry(nodeRegistry).validatorIdByPubkey(_pubkey);
        (, , , , address withdrawVaultAddress, , , ) = INodeRegistry(nodeRegistry).validatorRegistry(validatorId);
        return IVaultProxy(withdrawVaultAddress).vaultSettleStatus();
    }

    function computeExchangeRate(
        uint256 totalETHBalance,
        uint256 totalETHXSupply,
        IStaderConfig _staderConfig
    ) internal view returns (uint256) {
        uint256 DECIMALS = _staderConfig.getDecimals();
        uint256 newExchangeRate = (totalETHBalance == 0 || totalETHXSupply == 0)
            ? DECIMALS
            : (totalETHBalance * DECIMALS) / totalETHXSupply;
        return newExchangeRate;
    }

    function sendValue(address _receiver, uint256 _amount) internal {
        (bool success, ) = payable(_receiver).call{value: _amount}('');
        if (!success) {
            revert TransferFailed();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

enum ValidatorStatus {
    INITIALIZED,
    INVALID_SIGNATURE,
    FRONT_RUN,
    PRE_DEPOSIT,
    DEPOSITED,
    WITHDRAWN
}