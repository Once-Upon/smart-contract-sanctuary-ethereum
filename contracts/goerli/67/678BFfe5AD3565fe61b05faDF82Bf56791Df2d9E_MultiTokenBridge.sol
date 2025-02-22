// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { IERC20Bridgeable } from "./interfaces/IERC20Bridgeable.sol";
import { IMultiTokenBridge } from "./interfaces/IMultiTokenBridge.sol";
import { MultiTokenBridgeStorage } from "./MultiTokenBridgeStorage.sol";
import { PauseControlUpgradeable } from "./base/PauseControlUpgradeable.sol";
import { RescueControlUpgradeable } from "./base/RescueControlUpgradeable.sol";
import { StoragePlaceholder200 } from "./base/StoragePlaceholder.sol";

/**
 * @title MultiTokenBridgeUpgradeable contract
 * @dev Allows to bridge coins of multiple token contracts between blockchains.
 * See terms in the comments of the {IMultiTokenBridge} interface.
 */
contract MultiTokenBridge is
    AccessControlUpgradeable,
    PauseControlUpgradeable,
    RescueControlUpgradeable,
    StoragePlaceholder200,
    MultiTokenBridgeStorage,
    IMultiTokenBridge
{
    function FakeFunction() external view returns(uint) {
        return block.timestamp;
    }

    /// @dev The contract owner role.
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @dev The role who is allowed to execute bridge operations.
    bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");

    using SafeERC20Upgradeable for IERC20Upgradeable;

    // -------------------- Events -----------------------------------

    /// @dev Emitted when the mode of relocation with specified parameters is changed.
    event SetRelocationMode(
        uint256 indexed chainId, // The destination chain ID of the relocation.
        address indexed token,   // The address of the token contract whose coins are being relocated.
        OperationMode oldMode,   // The old mode of the relocation.
        OperationMode newMode    // The new mode of the relocation.
    );

    /// @dev Emitted when mode of accommodation with specified parameters is changed.
    event SetAccommodationMode(
        uint256 indexed chainId, // The source chain ID of the accommodation.
        address indexed token,   // The address of the token contract whose coins are being accommodated.
        OperationMode oldMode,   // The old mode of the accommodation.
        OperationMode newMode    // The new mode of the accommodation.
    );

    // -------------------- Errors -----------------------------------

    /// @dev The zero address of a token contract has been passed when request a relocation.
    error ZeroRelocationTokenAddress();

    /// @dev The zero amount of tokens has been passed when request a relocation.
    error ZeroRelocationAmount();

    /// @dev Relocation to the provided chain for the provided token is not supported by this bridge.
    error UnsupportedRelocation();

    /// @dev The underlying token contract does not support this bridge to execute needed operations.
    error UnsupportingToken();

    /// @dev The transaction sender is not authorized to execute the requested function with provided arguments.
    error UnauthorizedTransactionSender();

    /// @dev The provided array of relocation nonces as a function argument is empty.
    error EmptyNonceArray();

    /// @dev The zero relocation count has been passed as a function argument.
    error ZeroRelocationCount();

    /// @dev The requested count of relocations to process is greater than the current number of pending relocations.
    error LackOfPendingRelocations();

    /// @dev A token burning failure happened during a bridge operation.
    error TokenBurningFailure();

    /// @dev The zero nonce has been passed to accommodate tokens.
    error ZeroAccommodationNonce();

    /// @dev A nonce mismatch has been found during token accommodation.
    error AccommodationNonceMismatch();

    /// @dev The provided array of relocations as a function argument is empty.
    error EmptyRelocationArray();

    /// @dev Accommodation from the provided chain for the provided token contract is not supported by this bridge.
    error UnsupportedAccommodation();

    /// @dev The zero account address has been passed to accommodate tokens.
    error ZeroAccommodationAccount();

    /// @dev The zero amount of tokens has been passed to accommodate tokens.
    error ZeroAccommodationAmount();

    /// @dev A token minting failure happened during a bridge operation.
    error TokenMintingFailure();

    /// @dev The provided token contract does not support the bridge operations.
    error NonBridgeableToken();

    /// @dev The relocation with the provided nonce is already processed so it cannot be canceled.
    error AlreadyProcessedRelocation();

    /// @dev The relocation with the provided nonce does not exist so it cannot be canceled.
    error NotExistentRelocation();

    /// @dev The relocation with the provided nonce is already canceled.
    error AlreadyCanceledRelocation();

    // -------------------- Functions -----------------------------------

    function initialize() public initializer {
        __MultiTokenBridge_init();
    }

    function __MultiTokenBridge_init() internal onlyInitializing {
        __AccessControl_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __Pausable_init_unchained();
        __PauseControl_init_unchained(OWNER_ROLE);
        __RescueControl_init_unchained(OWNER_ROLE);

        __MultiTokenBridge_init_unchained();
    }

    function __MultiTokenBridge_init_unchained() internal onlyInitializing {
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(BRIDGER_ROLE, OWNER_ROLE);

        _setupRole(OWNER_ROLE, _msgSender());
    }

    /// @dev See {IMultiTokenBridge-getPendingRelocationCounter}.
    function getPendingRelocationCounter(uint256 chainId) external view returns (uint256) {
        return _pendingRelocationCounters[chainId];
    }

    /// @dev See {IMultiTokenBridge-getLastProcessedRelocationNonce}.
    function getLastProcessedRelocationNonce(uint256 chainId) external view returns (uint256) {
        return _lastProcessedRelocationNonces[chainId];
    }

    /// @dev See {IMultiTokenBridge-getRelocationMode}.
    function getRelocationMode(uint256 chainId, address token) external view returns (OperationMode) {
        return _relocationModes[chainId][token];
    }

    /// @dev See {IMultiTokenBridge-getRelocation}.
    function getRelocation(uint256 chainId, uint256 nonce) external view returns (Relocation memory) {
        return _relocations[chainId][nonce];
    }

    /// @dev See {IMultiTokenBridge-getAccommodationMode}.
    function getAccommodationMode(uint256 chainId, address token) external view returns (OperationMode) {
        return _accommodationModes[chainId][token];
    }

    /// @dev See {IMultiTokenBridge-getLastAccommodationNonce}.
    function getLastAccommodationNonce(uint256 chainId) external view returns (uint256) {
        return _lastAccommodationNonces[chainId];
    }

    /// @dev See {IMultiTokenBridge-getRelocations}.
    function getRelocations(
        uint256 chainId,
        uint256 nonce,
        uint256 count
    ) external view returns (Relocation[] memory relocations) {
        relocations = new Relocation[](count);
        for (uint256 i = 0; i < count; i++) {
            relocations[i] = _relocations[chainId][nonce];
            nonce += 1;
        }
    }

    /**
     * @dev See {IMultiTokenBridge-requestRelocation}.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The provided address of the token contract whose coins are being relocated must not be zero.
     * - The provided amount of tokens to relocate must not be zero.
     * - The relocation to the destination chain for the provided token contract must be supported.
     * - If the mode of the relocation is BurnOrMint
     *   the provided token contract must support this bridge to execute needed operation.
     * - The caller must have the provided amount of tokens.
     */
    function requestRelocation(
        uint256 chainId,
        address token,
        uint256 amount
    ) external whenNotPaused returns (uint256 nonce) {
        if (token == address(0)) {
            revert ZeroRelocationTokenAddress();
        }
        if (amount == 0) {
            revert ZeroRelocationAmount();
        }
        OperationMode mode = _relocationModes[chainId][token];
        if (mode == OperationMode.Unsupported) {
            revert UnsupportedRelocation();
        }
        if (mode == OperationMode.BurnOrMint) {
            if (!IERC20Bridgeable(token).isBridgeSupported(address(this))) {
                revert UnsupportingToken();
            }
        }

        uint256 newPendingRelocationCount = _pendingRelocationCounters[chainId] + 1;
        nonce = _lastProcessedRelocationNonces[chainId] + newPendingRelocationCount;
        _pendingRelocationCounters[chainId] = newPendingRelocationCount;
        Relocation storage relocation = _relocations[chainId][nonce];
        relocation.account = _msgSender();
        relocation.token = token;
        relocation.amount = amount;

        IERC20Upgradeable(token).safeTransferFrom(
            _msgSender(),
            address(this),
            amount
        );

        emit RequestRelocation(
            chainId,
            token,
            _msgSender(),
            amount,
            nonce
        );
    }

    /**
     * @dev See {IMultiTokenBridge-cancelRelocation}.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The caller must be the initiator of the relocation that is being canceled.
     * - The relocation for the provided chain ID and nonce must not be already processed.
     * - The relocation for the provided chain ID and nonce must exist.
     * - The relocation for the provided chain ID and nonce must not be already canceled.
     */
    function cancelRelocation(uint256 chainId, uint256 nonce) external whenNotPaused {
        if (_relocations[chainId][nonce].account != _msgSender()) {
            revert UnauthorizedTransactionSender();
        }

        cancelRelocationInternal(chainId, nonce);
    }

    /**
     * @dev See {IMultiTokenBridge-cancelRelocations}.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The caller must have the {BRIDGER_ROLE} role.
     * - The provided array of relocation nonces must not be empty.
     * - All the relocation for the provided chain ID and nonces must not be already processed.
     * - All the relocation for the provided chain ID and nonces must exist.
     * - All the relocation for the provided chain ID and nonces must not be already canceled.
     */
    function cancelRelocations(uint256 chainId, uint256[] memory nonces) external whenNotPaused onlyRole(BRIDGER_ROLE) {
        if (nonces.length == 0) {
            revert EmptyNonceArray();
        }

        for (uint256 i = 0; i < nonces.length; i++) {
            cancelRelocationInternal(chainId, nonces[i]);
        }
    }

    /**
     * @dev See {IMultiTokenBridge-relocate}.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The caller must have the {BRIDGER_ROLE} role.
     * - The provided count of relocations to process must not be zero.
     * - The provided count of relocations to process must not be greater than the number of pending relocations.
     * - For all the relocations that are executed is BurnOrMint operation mode
     *   the related token contracts whose coins are being relocated must support this bridge
     *   and must execute burning operations successfully.
     */
    function relocate(uint256 chainId, uint256 count) external whenNotPaused onlyRole(BRIDGER_ROLE) {
        if (count == 0) {
            revert ZeroRelocationCount();
        }
        uint256 currentPendingRelocationCount = _pendingRelocationCounters[chainId];
        if (count > currentPendingRelocationCount) {
            revert LackOfPendingRelocations();
        }

        uint256 fromNonce = _lastProcessedRelocationNonces[chainId] + 1;
        uint256 toNonce = fromNonce + count - 1;

        _pendingRelocationCounters[chainId] = currentPendingRelocationCount - count;
        _lastProcessedRelocationNonces[chainId] = toNonce;

        for (uint256 nonce = fromNonce; nonce <= toNonce; nonce++) {
            Relocation memory relocation = _relocations[chainId][nonce];
            if (!relocation.canceled) {
                OperationMode mode = _relocationModes[chainId][relocation.token];
                relocateInternal(relocation, mode);
                emit Relocate(
                    chainId,
                    relocation.token,
                    relocation.account,
                    relocation.amount,
                    nonce,
                    mode
                );
            }
        }
    }

    /**
     * @dev See {IMultiTokenBridge-accommodate}.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The caller must have the {BRIDGER_ROLE} role.
     * - The provided nonce of the first relocation must not be zero.
     * - The provided nonce of the first relocation must be one more than the nonce of the last accommodation.
     * - The provided array of relocations must not be empty.
     * - This bridge must support accommodations from the chain with the provided ID and
     *   for all token contracts of the provided array of relocations.
     * - All the provided relocations must have non-zero account address.
     * - All the provided relocations must have non-zero token amount.
     * - For all the accommodations whose mode is BurnAndMint
     *   the related token contracts whose coins are being accommodated must support this bridge
     *   and must execute minting operations successfully.
     */
    function accommodate(
        uint256 chainId,
        uint256 nonce,
        Relocation[] memory relocations
    ) external whenNotPaused onlyRole(BRIDGER_ROLE) {
        if (nonce == 0) {
            revert ZeroAccommodationNonce();
        }
        if (_lastAccommodationNonces[chainId] != (nonce - 1)) {
            revert AccommodationNonceMismatch();
        }
        if (relocations.length == 0) {
            revert EmptyRelocationArray();
        }

        for (uint256 i = 0; i < relocations.length; i++) {
            Relocation memory relocation = relocations[i];
            if (_accommodationModes[chainId][relocation.token] == OperationMode.Unsupported) {
                revert UnsupportedAccommodation();
            }
            if (relocation.account == address(0)) {
                revert ZeroAccommodationAccount();
            }
            if (relocation.amount == 0) {
                revert ZeroAccommodationAmount();
            }
            if (!relocation.canceled) {
                OperationMode mode = _accommodationModes[chainId][relocation.token];
                accommodateInternal(relocation, mode);
                emit Accommodate(
                    chainId,
                    relocation.token,
                    relocation.account,
                    relocation.amount,
                    nonce,
                    mode
                );
            }
            nonce += 1;
        }

        _lastAccommodationNonces[chainId] = nonce - 1;
    }

    /**
     * @dev Sets the mode of relocation to a destination chain for a local token contract.
     *
     * Requirements:
     *
     * - The caller must have the {OWNER_ROLE} role.
     * - The new relocation mode must defer from the current one.
     * - If the new relocation mode is BurnOrMint the underlying token contract must support the bridge operations.
     *
     * Emits a {SetRelocationMode} event.
     *
     * @param chainId The ID of the destination chain to relocate to.
     * @param token The address of the local token contract whose coins are being relocated.
     * @param newMode The new relocation mode.
     */
    function setRelocationMode(
        uint256 chainId,
        address token,
        OperationMode newMode
    ) external onlyRole(OWNER_ROLE) {
        OperationMode oldMode = _relocationModes[chainId][token];
        if (oldMode == newMode) {
            return;
        }
        if (newMode == OperationMode.BurnOrMint) {
            if (!isTokenIERC20BridgeableInternal(token)) {
                revert NonBridgeableToken();
            }
        }
        _relocationModes[chainId][token] = newMode;
        emit SetRelocationMode(chainId, token, oldMode, newMode);
    }

    /**
     * @dev Sets the mode of accommodation from a source chain for a local token contract.
     *
     * Requirements:
     *
     * - The caller must have the {OWNER_ROLE} role.
     * - The new accommodation mode must defer from the current one.
     * - If the new accommodation mode is BurnOrMint the underlying token contract must support the bridge operations.
     *
     * Emits a {SetAccommodationMode} event.
     *
     * @param chainId The ID of the source chain to accommodate from.
     * @param token The address of the local token contract whose coins are being accommodated.
     * @param newMode The new accommodation mode.
     */
    function setAccommodationMode(
        uint256 chainId,
        address token,
        OperationMode newMode
    ) external onlyRole(OWNER_ROLE) {
        OperationMode oldMode = _accommodationModes[chainId][token];
        if (oldMode == newMode) {
            return;
        }
        if (newMode == OperationMode.BurnOrMint) {
            if (!isTokenIERC20BridgeableInternal(token)) {
                revert NonBridgeableToken();
            }
        }
        _accommodationModes[chainId][token] = newMode;
        emit SetAccommodationMode(chainId, token, oldMode, newMode);
    }

    function cancelRelocationInternal(uint256 chainId, uint256 nonce) internal {
        uint256 lastProcessedRelocationNonce = _lastProcessedRelocationNonces[chainId];
        if (nonce <= lastProcessedRelocationNonce) {
            revert AlreadyProcessedRelocation();
        }
        if (nonce > lastProcessedRelocationNonce + _pendingRelocationCounters[chainId]) {
            revert NotExistentRelocation();
        }

        Relocation storage relocation = _relocations[chainId][nonce];

        if (relocation.canceled) {
            revert AlreadyCanceledRelocation();
        }

        relocation.canceled = true;
        IERC20Upgradeable(relocation.token).safeTransfer(relocation.account, relocation.amount);

        emit CancelRelocation(
            chainId,
            relocation.token,
            relocation.account,
            relocation.amount,
            nonce
        );
    }

    function relocateInternal(Relocation memory relocation, OperationMode mode) internal {
        if (mode == OperationMode.BurnOrMint) {
            if (!IERC20Bridgeable(relocation.token).isBridgeSupported(address(this))) {
                revert UnsupportingToken();
            }
            bool burningSuccess = IERC20Bridgeable(relocation.token).burnForBridging(
                relocation.account,
                relocation.amount
            );
            if (!burningSuccess) {
                revert TokenBurningFailure();
            }
        } else {
            // Do nothing, tokens are locked on the bridge account
        }
    }

    function accommodateInternal(Relocation memory relocation, OperationMode mode) internal {
        if (mode == OperationMode.BurnOrMint) {
            if (!IERC20Bridgeable(relocation.token).isBridgeSupported(address(this))) {
                revert UnsupportingToken();
            }
            bool mintingSuccess = IERC20Bridgeable(relocation.token).mintForBridging(
                relocation.account,
                relocation.amount
            );
            if (!mintingSuccess) {
                revert TokenMintingFailure();
            }
        } else {
            IERC20Upgradeable(relocation.token).safeTransfer(relocation.account, relocation.amount);
        }
    }

    // Safely call the appropriate function from the IERC20Bridgeable interface.
    function isTokenIERC20BridgeableInternal(address token) internal virtual returns (bool) {
        (bool success, bytes memory result) = token.staticcall(abi.encodeWithSignature("isIERC20Bridgeable()"));
        if (success && result.length > 0) {
            return abi.decode(result, (bool));
        } else {
            return false;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

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
                        StringsUpgradeable.toHexString(uint160(account), 20),
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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
        IERC20PermitUpgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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

pragma solidity ^0.8.8;

/**
 * @title IERC20Bridgeable interface
 * @dev The interface of a token that supports the bridge operations.
 */
interface IERC20Bridgeable {
    /// @dev Emitted when a minting operation is performed as part of a bridge operation.
    event MintForBridging(address indexed account, uint256 amount);
    /// @dev Emitted when a burning operation is performed as part of a bridge operation.
    event BurnForBridging(address indexed account, uint256 amount);

    /**
     * @dev Mints tokens as part of a bridge operation.
     * It is expected that this function can be called only by a bridge contract.
     *
     * Emits a {MintForBridging} event.
     *
     * @param account The owner of the tokens passing through the bridge.
     * @param amount The amount of tokens passing through the bridge.
     * @return True if the operation was successful.
     */
    function mintForBridging(address account, uint256 amount) external returns (bool);

    /**
     * @dev Burns tokens as part of a bridge operation.
     * It is expected that this function can be called only by a bridge contract.
     *
     * Emits a {BurnForBridging} event.
     *
     * @param account The owner of the tokens passing through the bridge.
     * @param amount The amount of tokens passing through the bridge.
     * @return True if the operation was successful.
     */
    function burnForBridging(address account, uint256 amount) external returns (bool);

    /**
     * @dev Checks whether a bridge is supported by the token or not.
     * @param bridge The address of the bridge to check.
     * @return True if the bridge is supported by the token.
     */
    function isBridgeSupported(address bridge) external view returns (bool);

    /**
     * @dev Checks whether the token supports the bridge operations by implementing this interface.
     * @return True in any case.
     */
    function isIERC20Bridgeable() external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title MultiTokenBridge types interface
 * @dev See terms in the comments of the {IMultiTokenBridge} interface.
 */
interface IMultiTokenBridgeTypes {
    /**
     * @dev Enumeration for bridge operation mode
     */
    enum OperationMode {
        Unsupported,   // 0 Relocation/accommodation with certain parameters is unsupported (the default value).
        BurnOrMint,    // 1 Relocation/accommodation is supported with token burning/minting during the op.
        LockOrTransfer // 2 Relocation/accommodation is supported with token locking/transferring during the op.
    }

    /**
     * @dev Structure with data of a single token relocation.
     */
    struct Relocation {
        address token;   // The address of the token contract whose coins are being relocated.
        address account; // The account who requested the relocation.
        uint256 amount;  // The amount of tokens to relocate.
        bool canceled;   // The state of the relocation.
    }
}

/**
 * @title MultiTokenBridge interface
 * @dev A contract implementing this interface allows to bridge coins of multiple token contracts between blockchains.
 *
 * Terms that are used in relation to bridge contracts:
 *
 * - relocation -- the relocation of tokens from one chain (a source chain) to another one (a destination chain).
                   Unless otherwise stated, the source chain is the current chain.
 * - to relocate -- to move tokens from the current chain to another one.
 * - accommodation -- placing tokens coming from another chain in the current chain.
 * - to accommodate -- to meet a relocation coming from another chain and place its tokens in the current chain.
 */
interface IMultiTokenBridge is IMultiTokenBridgeTypes {
    /// @dev Emitted when a new relocation is requested by an account.
    event RequestRelocation(
        uint256 indexed chainId, // The destination chain ID of the relocation.
        address indexed token,   // The address of the token contract whose coins are being relocated.
        address indexed account, // The account who requested the relocation.
        uint256 amount,          // The amount of tokens to relocate.
        uint256 nonce            // The relocation nonce.
    );

    /// @dev Emitted when a pending relocation is canceled.
    event CancelRelocation(
        uint256 indexed chainId, // The destination chain ID of the relocation.
        address indexed token,   // The address of the token contract whose coins are being relocated.
        address indexed account, // The account who requested the relocation.
        uint256 amount,          // The amount of tokens to relocate.
        uint256 nonce            // The relocation nonce.
    );

    /// @dev Emitted when a previously requested and non-canceled relocation is processed.
    event Relocate(
        uint256 indexed chainId, // The destination chain ID of the relocation.
        address indexed token,   // The address of the token contract whose coins are being relocated.
        address indexed account, // The account who requested the relocation.
        uint256 amount,          // The amount of tokens to relocate.
        uint256 nonce,           // The relocation nonce.
        OperationMode mode       // The mode of the relocation.
    );

    /// @dev Emitted when a new accommodation takes place.
    event Accommodate(
        uint256 indexed chainId, // The source chain ID of the accommodation.
        address indexed token,   // The address of the token contract whose coins are being accommodated.
        address indexed account, // The account who requested the correspondent relocation in the source chain.
        uint256 amount,          // The amount of tokens to relocate.
        uint256 nonce,           // The accommodation nonce.
        OperationMode mode       // The mode of the accommodation.
    );

    /**
     * @dev Returns the counter of pending relocations to a destination chain with a given ID.
     * @param chainId The ID of the destination chain.
     */
    function getPendingRelocationCounter(uint256 chainId) external view returns (uint256);

    /**
     * @dev Returns the nonce of the last processed relocation to a destination chain with a given ID.
     * @param chainId The ID of the destination chain.
     */
    function getLastProcessedRelocationNonce(uint256 chainId) external view returns (uint256);

    /**
     * @dev Returns mode of relocation to a destination chain with a given ID and for a given token.
     * @param chainId The ID of the destination chain.
     * @param token The address of the token contract whose coins are being relocated.
     */
    function getRelocationMode(uint256 chainId, address token) external view returns (OperationMode);

    /**
     * @dev Returns a relocation for a given destination chain ID and nonce.
     * @param chainId The ID of the destination chain.
     * @param nonce The nonce of the relocation to return.
     */
    function getRelocation(uint256 chainId, uint256 nonce) external view returns (Relocation memory);

    /**
     * @dev Returns mode of accommodation from a source chain with a given ID and for a given token.
     * @param chainId The ID of the source chain.
     * @param token The address of the token contract whose coins are being accommodated.
     */
    function getAccommodationMode(uint256 chainId, address token) external view returns (OperationMode);

    /**
     * @dev Returns the last nonce of an accommodation from a source chain with a given ID.
     * @param chainId The ID of the source chain.
     */
    function getLastAccommodationNonce(uint256 chainId) external view returns (uint256);

    /**
     * @dev Returns the relocations for a given destination chain id and a range of nonces.
     * @param chainId The ID of the destination chain.
     * @param nonce The first nonce of the relocation range to return.
     * @param count The number of relocations in the range to return.
     * @return relocations The array of relocations for the requested range.
     */
    function getRelocations(
        uint256 chainId,
        uint256 nonce,
        uint256 count
    ) external view returns (Relocation[] memory relocations);

    /**
     * @dev Requests a new relocation with transferring tokens from an account to the bridge.
     * The new relocation will be pending until it is processed.
     * This function is expected to be called by any account.
     *
     * Emits a {RequestRelocation} event.
     *
     * @param chainId The ID of the destination chain.
     * @param token The address of the token contract whose coins are being relocated.
     * @param amount The amount of tokens to relocate.
     * @return nonce The nonce of the new relocation.
     */
    function requestRelocation(
        uint256 chainId,
        address token,
        uint256 amount
    ) external returns (uint256 nonce);

    /**
     * @dev Cancels a pending relocation with transferring tokens back from the bridge to the account.
     * This function is expected to be called by the same account who request the relocation.
     *
     * Emits a {CancelRelocation} event.
     *
     * @param chainId The destination chain ID of the relocation to cancel.
     * @param nonce The nonce of the pending relocation to cancel.
     */
    function cancelRelocation(uint256 chainId, uint256 nonce) external;

    /**
     * @dev Cancels multiple pending relocations with transferring tokens back from the bridge to the accounts.
     * This function can be called by a limited number of accounts that are allowed to execute bridge operations.
     *
     * Emits a {CancelRelocation} event for each relocation.
     *
     * @param chainId The destination chain ID of the relocations to cancel.
     * @param nonces The array of pending relocation nonces to cancel.
     */
    function cancelRelocations(uint256 chainId, uint256[] memory nonces) external;

    /**
     * @dev Processes several pending relocations.
     * Burns or locks tokens previously received from accounts specified in the pending relocations depending on
     * the operation mode of each relocation.
     * If a relocation is executed in the BurnOrMint operation mode the tokens are burnt.
     * If a relocation is executed in the LockOrTransfer operation mode the tokens are locked on the bridge account.
     * The canceled relocations are skipped during the processing.
     * This function can be called by a limited number of accounts that are allowed to execute bridge operations.
     *
     * Emits a {Relocate} event for each non-canceled relocation.
     *
     * @param chainId The destination chain ID of the pending relocations to process.
     * @param count The number of pending relocations to process.
     */
    function relocate(uint256 chainId, uint256 count) external;

    /**
     * @dev Accommodates tokens of several relocations coming from a source chain.
     * Mints or transfers tokens according to passed relocation structures depending on
     * the operation mode of each accommodation distinguished by the source chain ID and the token contract.
     * If an accommodation is executed in the BurnOrMint operation mode the tokens are minted for
     * the account mentioned in the related relocation structure.
     * If an accommodation is executed in the LockOrTransfer operation mode the tokens are transferred
     * from the bridge account to the account mentioned in the related relocation structure.
     * Tokens will be minted or transferred only for non-canceled relocations.
     * This function can be called by a limited number of accounts that are allowed to execute bridge operations.
     *
     * Emits a {Accommodate} event for each non-canceled relocation.
     *
     * @param chainId The ID of the source chain.
     * @param nonce The nonce of the first relocation to accommodate.
     * @param relocations The array of relocations to accommodate.
     */
    function accommodate(
        uint256 chainId,
        uint256 nonce,
        Relocation[] memory relocations
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IMultiTokenBridgeTypes } from "./interfaces/IMultiTokenBridge.sol";

/**
 * @title MultiTokenBridge storage version 1
 * @dev See terms in the comments of the {IMultiTokenBridge} interface.
 */
abstract contract MultiTokenBridgeStorageV1 is IMultiTokenBridgeTypes {
    /// @dev The mapping: a destination chain ID => the number of pending relocations to that chain.
    mapping(uint256 => uint256) internal _pendingRelocationCounters;

    /// @dev The mapping: a destination chain ID => the nonce of the last processed relocation to that chain.
    mapping(uint256 => uint256) internal _lastProcessedRelocationNonces;

    /**
     * @dev The mapping: a destination chain ID, a token contract address => the mode of relocation
     * to that chain for that token
     */
    mapping(uint256 => mapping(address => OperationMode)) internal _relocationModes;

    /// @dev The mapping: a destination chain ID, a nonce => the relocation structure matching to that chain and nonce.
    mapping(uint256 => mapping(uint256 => Relocation)) internal _relocations;

    /**
     * @dev The mapping: a source chain ID, a token contract address => the mode of accommodation
     * from that chain for that token
     */
    mapping(uint256 => mapping(address => OperationMode)) internal _accommodationModes;

    /// @dev The mapping: a source chain ID => the nonce of the last accommodation from that chain.
    mapping(uint256 => uint256) internal _lastAccommodationNonces;
}

/**
 * @title MultiTokenBridge storage
 * @dev Contains storage variables of the multi token bridge contract.
 *
 * We are following Compound's approach of upgrading new contract implementations.
 * See https://github.com/compound-finance/compound-protocol.
 * When we need to add new storage variables, we create a new version of MultiTokenBridgeStorage
 * e.g. MultiTokenBridgeStorage<versionNumber>, so finally it would look like
 * "contract MultiTokenBridgeStorage is MultiTokenBridgeStorageV1, MultiTokenBridgeStorageV2".
 */
abstract contract MultiTokenBridgeStorage is MultiTokenBridgeStorageV1 {

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title PauseControlUpgradeable base contract
 * @dev Extends OpenZeppelin's PausableUpgradeable contract and AccessControlUpgradeable contract.
 * Introduces the {PAUSER_ROLE} role to control the paused state the contract that is inherited from this one.
 * The admins of the {PAUSER_ROLE} roles are accounts with the role defined in the init() function.
 */
abstract contract PauseControlUpgradeable is AccessControlUpgradeable, PausableUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function __PauseControl_init(bytes32 pauserRoleAdmin) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __Pausable_init_unchained();
        __PauseControl_init_unchained(pauserRoleAdmin);
    }

    function __PauseControl_init_unchained(bytes32 pauserRoleAdmin) internal onlyInitializing {
        _setRoleAdmin(PAUSER_ROLE, pauserRoleAdmin);
    }

    /**
     * @dev Triggers the paused state of the contract.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The caller should have the {PAUSER_ROLE} role.
     *
     * Emits a {Paused} event if it is executed successfully.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Triggers the unpaused state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - The caller should have the {PAUSER_ROLE} role.
     *
     * Emits a {Unpaused} event if it is executed successfully.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title RescueControlUpgradeable base contract
 * @dev Allows to "rescue" tokens locked up in the contract by transferring to a specified address.
 * Only accounts that have the {RESCUER_ROLE} role can execute token transferring operations.
 * The admins of the {RESCUER_ROLE} roles are accounts with the role defined in the init() function.
 */
abstract contract RescueControlUpgradeable is AccessControlUpgradeable {
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");

    using SafeERC20Upgradeable for IERC20Upgradeable;

    function __RescueControl_init(bytes32 rescuerRoleAdmin) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __RescueControl_init_unchained(rescuerRoleAdmin);
    }

    function __RescueControl_init_unchained(bytes32 rescuerRoleAdmin) internal onlyInitializing {
        _setRoleAdmin(RESCUER_ROLE, rescuerRoleAdmin);
    }

    /**
     * @dev Rescue ERC20 tokens locked up in this contract.
     *
     * Requirements:
     *
     * - The caller must have the {RESCUER_ROLE} role.
     *
     * @param tokenContract The ERC20 token contract address.
     * @param to The recipient address.
     * @param amount The amount to withdraw.
     */
    function rescueERC20(
        IERC20Upgradeable tokenContract,
        address to,
        uint256 amount
    ) external onlyRole(RESCUER_ROLE) {
        tokenContract.safeTransfer(to, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

/**
 * @title StoragePlaceholder150 abstract contract
 * @dev Reserves 200 storage slots.
 * Such a storage placeholder contract allows future replacement of it with other contracts
 * without shifting down storage in the inheritance chain.
 *
 * E.g. the following code:
 * ```
 * abstract contract StoragePlaceholder200 {
 *     uint256[200] private __gap;
 * }
 *
 * contract A is B, StoragePlaceholder200, C {
 *     //Some implementation
 * }
 * ```
 * can be replaced with the following code without a storage shifting issue:
 * ```
 * abstract contract StoragePlaceholder150 {
 *     uint256[150] private __gap;
 * }
 *
 * abstract contract X {
 *     uint256[50] public values;
 *     // No more storage variables. Some set of functions should be here.
 * }
 *
 * contract A is B, X, StoragePlaceholder150, C {
 *     //Some implementation
 * }
 * ```
 */
abstract contract StoragePlaceholder200 {
    uint256[200] private __gap;
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
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
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

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
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
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
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
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
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
interface IERC20PermitUpgradeable {
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
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}