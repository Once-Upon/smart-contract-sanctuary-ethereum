// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import { NightClubGuardBase } from "../NightClubGuardBase.sol";

/**
 * @notice Transition guard functions
 *
 * - Machine: Nightclub
 * - State: Restroom
 */
contract RestroomGuards is NightClubGuardBase {

    // Enter the Restroom
    // Valid prior states: Dancefloor, Bar, VIP Lounge, and Foyer
    function NightClub_Restroom_Enter(address _user, string calldata _action, string calldata _priorStateName)
    external
    pure
    returns(string memory message)
    {
        if (compare(_priorStateName, BAR)) {
            message = "You chug the rest of your beer, wave the empty bottle menacingly at a Daft Punk poster for no reason, then enter the restroom.";
        } else if (compare(_priorStateName, DANCEFLOOR)) {
            message = "Your boogie shoes are full of sweat and the squishing sounds echo loudly off the tiles. Washing your face and drenching your hair in cold water completes the effect. The mirror reflects a fully walking mer-creature.";
        } else if (compare(_priorStateName, VIP_LOUNGE)) {
            message = "Leaving those questionably elite layabouts behind, you join a line of your compatriots in rhythm, waiting for your turn at the facilities.";
        } else if (compare(_priorStateName, FOYER)) {
            message = "The night is young and restroom is still fairly unsullied.";
        }
    }

    // Exit the Restroom
    // Valid next states: Dancefloor, Bar, VIP Lounge, and Foyer
    function NightClub_Restroom_Exit(address _user, string calldata _action, string calldata _nextStateName)
    external
    pure
    returns(string memory message)
    {
        if (compare(_nextStateName, BAR)) {
            message = "As you head back toward the bar, you get an odd feeling that you're perpetuating a cycle.";
        } else if (compare(_nextStateName, DANCEFLOOR)) {
            message = "Whaaaaaat? Is that a Sea of Arrows track? Thump, thump, thump, zzzzzrrrooooowwwww... Lol, no. But still, it slaps.";
        } else if (compare(_nextStateName, VIP_LOUNGE)) {
            message = "Aight, time to chillax. Wasn't it the Dali Lama who once said that deep beats like these are best pondered on an equally deep and comfy sofa?";
        } else if (compare(_nextStateName, FOYER)) {
            message = "Leaving so soon? It's not the break of dawn yet...";
        }
    }

}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import { NightClubLib } from "./NightClubLib.sol";
import { NightClubConstants } from "./NightClubConstants.sol";
import "./NightClubOperator.sol";

/**
 * @notice Base functions for guards
 */
contract NightClubGuardBase is NightClubConstants {

    /**
     * Does the given user have the VIP role?
     *
     * @param _user - the address to check
     * @return isVIP - true if _user has VIP role
     */
    function isVIP(address _user)
    internal
    view
    returns (bool)
    {
        // N.B. msg.sender is NightClubOperator, which implements IAccessControl
        return IAccessControl(msg.sender).hasRole(VIP, _user);
    }

    /**
     * @notice Compare two strings
     */
    function compare(string memory a, string memory b)
    internal
    pure
    returns
    (bool)
    {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import { NightClubConstants } from "./NightClubConstants.sol";

/**
 * @title NightClubLib
 *
 * @notice NightClub Machine storage
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
library NightClubLib {

    bytes32 internal constant NIGHTCLUB_SLOT = keccak256("fismo.example.nightclub.storage.slot");

    struct NightClubSlot {

        //  user wallet => TODO: What are we storing here?
        mapping(address => string) userStuff;

    }

    /**
     * @notice Get the NightClub storage slot
     *
     * @return nightClubStorage - NightClub storage slot
     */
    function nightClubSlot()
    internal
    pure
    returns (NightClubSlot storage nightClubStorage)
    {
        bytes32 position = NIGHTCLUB_SLOT;
        assembly {
            nightClubStorage.slot := position
        }
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title NightClubConstants
 *
 * @notice Constants used by the NightClub example
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
contract NightClubConstants {

    // Access Control Roles
    bytes32 internal constant ADMIN = keccak256("ADMIN");    // Deployer and any other admins as needed
    bytes32 internal constant VIP = keccak256("VIP");        // VIP clubbers get in free

    // Door Fee for the plebs
    uint256 internal constant DOOR_FEE = 0.005 ether;

    // States
    string internal constant HOME = "Home";
    string internal constant CAB = "Cab";
    string internal constant STREET = "Street";
    string internal constant FOYER = "Foyer";
    string internal constant BAR = "Bar";
    string internal constant DANCEFLOOR = "Dancefloor";
    string internal constant RESTROOM = "Restroom";
    string internal constant VIP_LOUNGE = "VIP_Lounge";

}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import { IFismoOperate } from "../../interfaces/IFismoOperate.sol";
import { NightClubConstants } from "./NightClubConstants.sol";
import { FismoTypes } from "../../domain/FismoTypes.sol";

/**
 * @title NightClubOperator
 *
 * N.B. This is only an example a few ways that a Operator can control access
 * to Fismo machines.
 *
 * In this example, the user is either
 * - A VIP, who gets in the door for free
 * - A pleb, who has to pay a fee at the door
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
contract NightClubOperator is NightClubConstants, AccessControl {

    IFismoOperate internal fismo;

    /**
     * @notice Constructor
     *
     * Grants ADMIN role to deployer.
     * Sets ADMIN as role admin for all other roles.
     */
    constructor(address _fismo) {
        fismo = IFismoOperate(_fismo);
        _setupRole(ADMIN, msg.sender);
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(VIP, ADMIN);
    }

    /**
     * Invoke a Fismo action, only if they have VIP role.
     *
     * Reverts if caller does not have the VIP role.
     *
     * @param _machineId - the id of the target machine
     * @param _actionId - the id of the action to invoke
     */
    function invokeActionVIP(bytes4 _machineId, bytes4 _actionId)
    external
    onlyRole(VIP)
    returns(FismoTypes.ActionResponse memory response) {
        response = fismo.invokeAction(msg.sender, _machineId, _actionId);
    }

    /**
     * Invoke an action on a configured machine
     *
     * Reverts if caller hasn't sent the fee
     *
     * @param _machineId - the id of the target machine
     * @param _actionId - the id of the action to invoke
     */
    function invokeActionPleb(bytes4 _machineId, bytes4 _actionId)
    external
    payable
    returns(FismoTypes.ActionResponse memory response) {
        require(msg.value == DOOR_FEE, "Send the fee");
        response = fismo.invokeAction(msg.sender, _machineId, _actionId);
    }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

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
abstract contract AccessControl is Context, IAccessControl, ERC165 {
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
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
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
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
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
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import { FismoTypes } from "../domain/FismoTypes.sol";

/**
 * @title FismoOperate
 *
 * @notice Operate Fismo state machines
 * The ERC-165 identifier for this interface is 0xcad6b576
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface IFismoOperate {

    /// Emitted when a user transitions from one State to another.
    event UserTransitioned(
        address indexed user,
        bytes4 indexed machineId,
        bytes4 indexed newStateId,
        FismoTypes.ActionResponse response
    );

    /**
     * Invoke an action on a configured Machine.
     *
     * Reverts if
     * - Caller is not the machine's operator (contract or EOA)
     * - Machine does not exist
     * - Action is not valid for the user's current State in the given Machine
     * - Any invoked Guard logic reverts
     *
     * @param _user - the address of the user
     * @param _machineId - the id of the target machine
     * @param _actionId - the id of the action to invoke
     *
     * @return response - the response from the action. See {FismoTypes.ActionResponse}
     */
    function invokeAction(
        address _user,
        bytes4 _machineId,
        bytes4 _actionId
    )
    external
    returns(
        FismoTypes.ActionResponse memory response
    );

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title FismoTypes
 *
 * @notice Enums and structs used by Fismo
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
contract FismoTypes {

    enum Guard {
        Enter,
        Exit,
        Filter
    }

    struct Machine {
        address operator;         // address of approved operator (can be contract or EOA)
        bytes4 id;                // keccak256 hash of machine name
        bytes4 initialStateId;    // keccak256 hash of initial state
        string name;              // name of machine
        string uri;               // off-chain URI of metadata describing the machine
        State[] states;           // all of the valid states for this machine
    }

    struct State {
        bytes4 id;                // keccak256 hash of state name
        string name;              // name of state. begin with letter, no spaces, a-z, A-Z, 0-9, and _
        bool exitGuarded;         // is there an exit guard?
        bool enterGuarded;        // is there an enter guard?
        address guardLogic;       // address of guard logic contract
        Transition[] transitions; // all of the valid transitions from this state
    }

    struct Position {
        bytes4 machineId;         // keccak256 hash of machine name
        bytes4 stateId;           // keccak256 hash of state name
    }

    struct Transition {
        bytes4 actionId;          // keccak256 hash of action name
        bytes4 targetStateId;     // keccak256 hash of target state name
        string action;            // Action name. no spaces, only a-z, A-Z, 0-9, and _
        string targetStateName;   // Target State name. begin with letter, no spaces, a-z, A-Z, 0-9, and _
    }

    struct ActionResponse {
        string machineName;        // name of machine
        string action;             // name of action that triggered the transition
        string priorStateName;     // name of prior state
        string nextStateName;      // name of new state
        string exitMessage;        // response from the prior state's exit guard
        string enterMessage;       // response from the new state's enter guard
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
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
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