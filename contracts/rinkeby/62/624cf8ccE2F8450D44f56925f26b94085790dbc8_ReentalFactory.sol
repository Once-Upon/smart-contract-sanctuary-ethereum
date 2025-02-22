// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IAccessControlProxyPausable {

    function config (  ) external view returns (address);

    function DEFAULT_ADMIN_ROLE (  ) external view returns (bytes32);

    function PAUSER_ROLE (  ) external view returns (bytes32);

    function hasRole(bytes32 role, address account) external view returns (bool);

    function pause() external;

    function unpause() external;

    function updateConfig(address config_) external;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "contracts/utils/OwnableUpgradeable.sol";
import "contracts/lib/Msg.sol";
import "contracts/utils/MasterableUpgradeable.sol";
import "contracts/ReentalDIDStorage.sol";
import "contracts/interfaces/IReentalDID.sol";
import "contracts/interfaces/IReentalDIDFactory.sol";
import "contracts/interfaces/IReentalManager.sol";
import "contracts/interfaces/IAccessControlProxyPausable.sol";

contract ReentalDID is 
    Initializable, 
    OwnableUpgradeable, 
    MasterableUpgradeable, 
    PausableUpgradeable, 
    ERC721HolderUpgradeable, 
    ERC1155HolderUpgradeable, 
    IReentalDID, 
    ReentalDIDStorage 
{

    /***************************************************************/
    // EVENTS
    /***************************************************************/

    event Forward(address indexed destination, bytes data, uint value, uint gas, bytes result);

    /***************************************************************/
    // MODIFIERS
    /***************************************************************/

    modifier forwardChecks(address destination_) {
        require(canForward(destination_), "ReentalDID: verificationCheck");
        _;
    }

    modifier onlyMasterOrReental {
        require(_isMaster(msg.sender), "ReentalDID: onlyMasterOrReental");
        _;
    }

    modifier onlyOwnerOrMaster {
        require(msg.sender == owner() || _isMaster(msg.sender), "ReentalDID: onlyOwnerOrMaster");
        _;
    }

    /***************************************************************/
    // PUBLIC/EXTERNAL FUNCTIONS
    /***************************************************************/

    function version() external pure returns(string memory) {
        return "0.0.1";
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    /// @notice Resend a call to another contract function
    /// @dev Make a call to function encoded in _data and address in _destination 
    /// @param destination_ Address of the contract 
    /// @param data_ Function signature and params encoded
    /// @param value_ Msg.value to be sent in call
    /// @param gas_ Gas limit sent in call
    /// @return encoded result of function call
    function forward(
        address destination_, 
        bytes calldata data_, 
        uint value_, 
        uint gas_
    ) 
        external
        returns(bytes memory) 
    {
        bytes memory result_ = _forward(destination_, data_, value_, gas_);
        
        emit Forward(destination_, data_, value_, gas_, result_);
        
        return result_;
    }

    function forwardBatch(
        address[]  calldata destination_, 
        bytes[]  calldata data_, 
        uint[]  calldata value_, 
        uint[] calldata gas_
    ) 
        external
        returns(bytes[] memory) 
    {
        require(
            destination_.length == data_.length &&
            data_.length == value_.length &&
            value_.length == gas_.length,
            "ReentalDID: arrays length mismatch"
        );

        bytes[] memory results_ = new bytes[](destination_.length);

        for (uint i = 0; i < results_.length; i++) {
            results_[i] = _forward(destination_[i], data_[i], value_[i], gas_[i]);

            emit Forward(destination_[i], data_[i], value_[i], gas_[i], results_[i]);
        }

        return results_;
    }

    function transferOwnership(address newOwner)  public override onlyOwnerOrMaster {
        _transferOwnership(newOwner);
    }

    function transferMastership(address newMaster)  public override onlyMasterOrReental {
        _transferMastership(newMaster);
    }

    function pause() public onlyOwnerOrMaster {
        _pause();
    }
    
    function unpause() public onlyMasterOrReental {
        _unpause();
    }

    function toggleOnlyVerifiedCalls() public onlyMasterOrReental {
        onlyVerifiedCalls = !onlyVerifiedCalls;
    }

    function canForward(address destination_) public view whenNotPaused returns(bool) {
        return _verificationCheck(destination_);
    }

    /***************************************************************/
    // INTERNAL FUNCTIONS
    /***************************************************************/

    function _forward(
        address destination_, 
        bytes memory data_, 
        uint value_, 
        uint gas_
    ) 
        internal
        onlyOwner
        whenNotPaused
        forwardChecks(destination_) 
        returns (bytes memory) 
    {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success_, bytes memory result_) = destination_.call{value: value_, gas: gas_}(data_);
        
        if (!success_) {
            revert(Msg.getRevertMsg(result_));
        }
        
        return result_;
    }

    function _transferOwnership(address newOwner) internal override {
        require(newOwner != address(0), "ReentalDID: new owner is the zero address");
        super._transferOwnership(newOwner);
    }

    function _transferMastership(address newMaster) internal override {
        require(newMaster != address(0), "ReentalDID: new master is the zero address");
        super._transferMastership(newMaster);
    }

    function _verificationCheck(address destination_) internal view returns(bool) {
        if (onlyVerifiedCalls || IReentalDIDFactory(factory).onlyVerifiedCalls()) {
            return IReentalManager(IAccessControlProxyPausable(factory).config()).isVerified(destination_);
        }
        return true;
    }

    function _isMaster(address account) internal view returns(bool) {
        if (account == master()) return true;
        return IAccessControlProxyPausable(factory).hasRole(REENTAL_DID_MASTER_ROLE, account);
    }

    /***************************************************************/
    // INIT FUNCTIONS
    /***************************************************************/

    function initialize(address owner_, address master_) public initializer {
        __ERC721Holder_init();
        __Ownable_init();
        __Masterable_init();
        _transferOwnership(owner_);
        _transferMastership(master_);
        factory = msg.sender;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

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
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

import "../IERC721ReceiverUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721HolderUpgradeable is Initializable, IERC721ReceiverUpgradeable {
    function __ERC721Holder_init() internal initializer {
        __ERC721Holder_init_unchained();
    }

    function __ERC721Holder_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1155ReceiverUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev _Available since v3.1._
 */
contract ERC1155HolderUpgradeable is Initializable, ERC1155ReceiverUpgradeable {
    function __ERC1155Holder_init() internal initializer {
        __ERC165_init_unchained();
        __ERC1155Receiver_init_unchained();
        __ERC1155Holder_init_unchained();
    }

    function __ERC1155Holder_init_unchained() internal initializer {
    }
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

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
    function __Pausable_init() internal initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal initializer {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
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
        require(paused(), "Pausable: not paused");
        _;
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (access/Ownable.sol)

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        _transferOwnership(_msgSender());
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

library Msg {

    function sliceUint(bytes memory bs, uint start) internal pure returns (uint)
    {
        require(bs.length >= start + 32, "slicing out of range");
        uint x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return x;
    }

    function getRevertMsg(bytes memory returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string)); // All that remains is the revert string
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (access/Ownable.sol)

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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
abstract contract MasterableUpgradeable is Initializable, ContextUpgradeable {
    address private _master;

    event MastershipTransferred(address indexed previousMaster, address indexed newMaster);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Masterable_init() internal initializer {
        __Context_init_unchained();
        __Masterable_init_unchained();
    }

    function __Masterable_init_unchained() internal initializer {
        _transferMastership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function master() public view virtual returns (address) {
        return _master;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyMaster() {
        require(master() == _msgSender(), "Masterable: caller is not the master");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceMastership() public virtual onlyMaster {
        _transferMastership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferMastership(address newMaster) public virtual onlyMaster {
        require(newMaster != address(0), "Masterable: new owner is the zero address");
        _transferMastership(newMaster);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferMastership(address newMaster) internal virtual {
        address oldMaster = _master;
        _master = newMaster;
        emit MastershipTransferred(oldMaster, newMaster);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract ReentalDIDStorage {
    bytes32 public constant REENTAL_DID_MASTER_ROLE = keccak256("REENTAL_DID_MASTER_ROLE");
    bytes32 public constant REENTAL_CONFIG = keccak256("REENTAL_CONFIG");

    address public factory;
    bool public onlyVerifiedCalls;
    uint256[50] private __gap;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IReentalDID {
    
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

interface IReentalDIDFactory  {
    function beacon() external view returns (address);
    function createProxy(bytes calldata initializeCalldata) external returns (address);
    function createProxyWithSignature(bytes calldata initializeCalldata, uint deadline, address signer, bytes memory signature) external returns (address);
    function onlyVerifiedCalls() external view returns (bool);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IReentalManager {
    function get(bytes32) external view returns(address);
    function name(address) external view returns(bytes32);
    function setId(bytes32, address) external;
    function deployProxyWithImplementation(bytes32, address, bytes memory) external;
    function deploy(bytes32, bytes memory, bytes memory) external returns(address);
    function isVerified (address) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC1155ReceiverUpgradeable.sol";
import "../../../utils/introspection/ERC165Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155ReceiverUpgradeable is Initializable, ERC165Upgradeable, IERC1155ReceiverUpgradeable {
    function __ERC1155Receiver_init() internal initializer {
        __ERC165_init_unchained();
        __ERC1155Receiver_init_unchained();
    }

    function __ERC1155Receiver_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

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
    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

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
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import "contracts/utils/BeaconFactory.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "contracts/utils/UUPSUpgradeableByRole.sol";
import "contracts/utils/RefundableUpgradeable.sol";
import "contracts/interfaces/IReentalManager.sol";
import "contracts/ReentalDID.sol";

contract ReentalDIDFactory is UUPSUpgradeableByRole, BeaconFactory, EIP712Upgradeable, RefundableUpgradeable {

    mapping(address => address[]) public didByOwner;
    mapping(address => address) public ownerByDid;

    bool public onlyVerifiedCalls;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _DID_FACTORY_TYPEHASH =
        keccak256("CreateProxy(address owner,address master,uint256 deadline)");

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _DID_FACTORY_UPGRADER_ROLE =
        keccak256("DID_FACTORY_UPGRADER_ROLE");

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _DID_FACTORY_ADMIN_ROLE =
        keccak256("DID_FACTORY_ADMIN_ROLE");

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _DID_CREATOR_ROLE =
        keccak256("DID_CREATOR_ROLE");

    event NewDID(address proxy, address owner, address master, address creator);

    function initialize () public initializer {
        
        __AccessControlProxyPausable_init(msg.sender);
        __EIP712_init("REENTAL_DID_FACTORY", "1");
        _upgradeByImplementation(address(new ReentalDID()));
    }

    function setOnlyVerifiedCalls (bool value) public onlyRole(_DID_FACTORY_ADMIN_ROLE) {
        onlyVerifiedCalls = value;
    }

    function createProxy(bytes calldata initializeCalldata) public onlyRole(_DID_CREATOR_ROLE) isBeaconSet returns(address proxy) {
        (proxy) = _createProxy(initializeCalldata);
    }

    function createProxyWithSignature(
        bytes calldata initializeCalldata, 
        uint deadline,
        address signer,
        bytes memory signature
    ) 
        public isBeaconSet
        returns(address proxy) 
    {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "ReentalDIDFactory: expired deadline");
        require(hasRole(_DID_CREATOR_ROLE, signer), "ReentalDIDFactory: role cant createProxy");

        (address owner,address master) = abi.decode(initializeCalldata[4:], (address, address));
        bytes32 structHash = keccak256(abi.encode(_DID_FACTORY_TYPEHASH, owner, master, deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        bool validation = SignatureChecker.isValidSignatureNow(signer, hash, signature);
        require(validation, "ReentalDIDFactory: invalid signature");
        
        (proxy) = _createProxy(initializeCalldata);
    }

    function _createProxy(bytes calldata initializeCalldata) private whenNotPaused() returns (address proxyAddress){
        BeaconProxy proxy = new BeaconProxy(
            beacon,
            initializeCalldata
        );

        proxyAddress = address(proxy);

        (address owner,address master) = abi.decode(initializeCalldata[4:], (address, address));

        _registerDID(owner, proxyAddress);

        emit NewDID(proxyAddress, owner, master, msg.sender);
    }

    function upgrade(bytes memory bytecode) public onlyRole(_DID_FACTORY_UPGRADER_ROLE) returns (address implementation) {
        return _upgradeByBytecode(bytecode);
    }

    function upgradeWithImplementation(address implementation) public onlyRole(_DID_FACTORY_UPGRADER_ROLE) {
        _upgradeByImplementation(implementation);
    }

    function _registerDID(address owner_, address did_) private {
        didByOwner[owner_].push(did_);
        ownerByDid[did_] = owner_;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "contracts/lib/Contracts.sol";
import "contracts/lib/Msg.sol";

abstract contract BeaconFactory {

    address public beacon;

    modifier isBeaconSet {
        require(_beaconSet(), "ReentalFactory: beacon is not set yet");
        _;
    }

    function _beaconSet () internal view returns (bool) {
        return Contracts.isContract(beacon);
    }

    function _upgradeByBytecode(bytes memory bytecode) internal returns (address implementation) {
        implementation = Contracts.deploy(bytecode);
        _upgradeByImplementation(implementation);
    }

    function _upgradeByImplementation(address implementation) internal {
        if (_beaconSet()) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory result) = beacon.call(abi.encodeWithSignature("upgradeTo(address)", implementation));
            require(success, Msg.getRevertMsg(result));
        } else {
            beacon = address(new UpgradeableBeacon(implementation));
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IBeacon.sol";
import "../Proxy.sol";
import "../ERC1967/ERC1967Upgrade.sol";

/**
 * @dev This contract implements a proxy that gets the implementation address for each call from a {UpgradeableBeacon}.
 *
 * The beacon address is stored in storage slot `uint256(keccak256('eip1967.proxy.beacon')) - 1`, so that it doesn't
 * conflict with the storage layout of the implementation behind the proxy.
 *
 * _Available since v3.4._
 */
contract BeaconProxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the proxy with `beacon`.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon. This
     * will typically be an encoded function call, and allows initializating the storage of the proxy like a Solidity
     * constructor.
     *
     * Requirements:
     *
     * - `beacon` must be a contract with the interface {IBeacon}.
     */
    constructor(address beacon, bytes memory data) payable {
        assert(_BEACON_SLOT == bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1));
        _upgradeBeaconToAndCall(beacon, data, false);
    }

    /**
     * @dev Returns the current beacon address.
     */
    function _beacon() internal view virtual returns (address) {
        return _getBeacon();
    }

    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /**
     * @dev Changes the proxy to use a new beacon. Deprecated: see {_upgradeBeaconToAndCall}.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon.
     *
     * Requirements:
     *
     * - `beacon` must be a contract.
     * - The implementation returned by `beacon` must be a contract.
     */
    function _setBeacon(address beacon, bytes memory data) internal virtual {
        _upgradeBeaconToAndCall(beacon, data, false);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ECDSA.sol";
import "../Address.sol";
import "../../interfaces/IERC1271.sol";

/**
 * @dev Signature verification helper: Provide a single mechanism to verify both private-key (EOA) ECDSA signature and
 * ERC1271 contract sigantures. Using this instead of ECDSA.recover in your contract will make them compatible with
 * smart contract wallets such as Argent and Gnosis.
 *
 * Note: unlike ECDSA signatures, contract signature's are revocable, and the outcome of this function can thus change
 * through time. It could return true at block N and false at block N+1 (or the opposite).
 *
 * _Available since v4.1._
 */
library SignatureChecker {
    function isValidSignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        if (error == ECDSA.RecoverError.NoError && recovered == signer) {
            return true;
        }

        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature)
        );
        return (success && result.length == 32 && abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ECDSAUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712Upgradeable is Initializable {
    /* solhint-disable var-name-mixedcase */
    bytes32 private _HASHED_NAME;
    bytes32 private _HASHED_VERSION;
    bytes32 private constant _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    function __EIP712_init(string memory name, string memory version) internal initializer {
        __EIP712_init_unchained(name, version);
    }

    function __EIP712_init_unchained(string memory name, string memory version) internal initializer {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash());
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash
    ) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return ECDSAUpgradeable.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev The hash of the name parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712NameHash() internal virtual view returns (bytes32) {
        return _HASHED_NAME;
    }

    /**
     * @dev The hash of the version parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712VersionHash() internal virtual view returns (bytes32) {
        return _HASHED_VERSION;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./AccessControlProxyPausable.sol";

contract UUPSUpgradeableByRole is AccessControlProxyPausable, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(keccak256("UPGRADER_ROLE")) {}
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./AccessControlProxyPausable.sol";
import "contracts/lib/Msg.sol";

contract RefundableUpgradeable is AccessControlProxyPausable {

  mapping(address=>uint256) public refunded;
  uint256 public refundedETH;

  receive() external payable {}

  fallback() external payable {}

  function __Refundable_init() internal initializer {
    __AccessControlProxyPausable_init(msg.sender);
    __Refundable_init_unchained();
  }

  function __Refundable_init_unchained() internal initializer {
  }

  function refundTokens(address token, address recipient) public onlyRole(DEFAULT_ADMIN_ROLE) {

    (bool success1, bytes memory result1) = token.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
    uint256 balance = uint256(Msg.sliceUint(result1, 0));

    require(success1 && balance > 0, "RefundableUpgradeable: cannot transfer funds");

    refunded[token] += balance;

    (bool success2, bytes memory result2) = token.call(abi.encodeWithSignature("transfer(address,uint256)", recipient, balance));
    
    if (!success2) {
      revert(Msg.getRevertMsg(result2));
    }
  }
  
  function refundETH(address recipient) public onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 balance = address(this).balance;

    require(balance > 0, "RefundableUpgradeable: cannot transfer funds");

    refundedETH += balance;

    payable(recipient).transfer(balance);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IBeacon.sol";
import "../../access/Ownable.sol";
import "../../utils/Address.sol";

/**
 * @dev This contract is used in conjunction with one or more instances of {BeaconProxy} to determine their
 * implementation contract, which is where they will delegate all function calls.
 *
 * An owner is able to change the implementation the beacon points to, thus upgrading the proxies that use this beacon.
 */
contract UpgradeableBeacon is IBeacon, Ownable {
    address private _implementation;

    /**
     * @dev Emitted when the implementation returned by the beacon is changed.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Sets the address of the initial implementation, and the deployer account as the owner who can upgrade the
     * beacon.
     */
    constructor(address implementation_) {
        _setImplementation(implementation_);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view virtual override returns (address) {
        return _implementation;
    }

    /**
     * @dev Upgrades the beacon to a new implementation.
     *
     * Emits an {Upgraded} event.
     *
     * Requirements:
     *
     * - msg.sender must be the owner of the contract.
     * - `newImplementation` must be a contract.
     */
    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Sets the implementation contract address for this beacon
     *
     * Requirements:
     *
     * - `newImplementation` must be a contract.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "UpgradeableBeacon: implementation is not a contract");
        _implementation = newImplementation;
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

library Contracts {
    function deploy(bytes memory bytecode) internal returns (address implementation) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            implementation := create(0, add(bytecode, 32), mload(bytecode))
        }
        require(isContract(implementation), "Could not deploy implementation");
    }
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overriden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

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
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
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
abstract contract UUPSUpgradeable is ERC1967Upgrade {
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
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallSecure(newImplementation, new bytes(0), false);
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
        _upgradeToAndCallSecure(newImplementation, data, true);
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

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

abstract contract AccessControlProxyPausable is PausableUpgradeable {

    address public config;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    modifier onlyRole(bytes32 role) {
        address account = msg.sender;
        require(hasRole(role, account), string(
                    abi.encodePacked(
                        "AccessControlProxyPausable: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                ));
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        IAccessControlUpgradeable configInterface = IAccessControlUpgradeable(config);
        return configInterface.hasRole(role, account);
    }

    function __AccessControlProxyPausable_init(address config_) internal initializer {
        __Pausable_init();
        __AccessControlProxyPausable_init_unchained(config_);
    }

    function __AccessControlProxyPausable_init_unchained(address config_) internal initializer {
        config = config_;
    }

    function pause() public onlyRole(PAUSER_ROLE){
        _pause();
    }
    
    function unpause() public onlyRole(PAUSER_ROLE){
        _unpause();
    }

    function updateConfig(address config_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IAccessControlUpgradeable configInterface = IAccessControlUpgradeable(config_);
        require(configInterface.hasRole(DEFAULT_ADMIN_ROLE, msg.sender), string(
                    abi.encodePacked(
                        "AccessControlProxyPausable: account ",
                        StringsUpgradeable.toHexString(uint160(msg.sender), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
                    )
                ));
        config = config_;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
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

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/utils/UUPSUpgradeableByRole.sol";
import "contracts/utils/RefundableUpgradeable.sol";
import "contracts/interfaces/IReentalDIDFactory.sol";
import "contracts/interfaces/IReentalManager.sol";

contract ReentalWhitelist is UUPSUpgradeableByRole, EIP712Upgradeable, RefundableUpgradeable {

  bool public disabled;

  mapping(address => bool) private _whitelisted;
  mapping(address => uint256) public retentionPercent;

  bytes32 private constant _WHITELIST_ADMIN_ROLE =
        keccak256("WHITELIST_ADMIN_ROLE");

  // solhint-disable-next-line var-name-mixedcase
  bytes32 private immutable _REENTAL_ADD_TYPEHASH =
        keccak256("Add(address account,uint256 retention,uint256 deadline)");

  // solhint-disable-next-line var-name-mixedcase
  bytes32 private immutable _REENTAL_ADD_DID_TYPEHASH =
        keccak256("AddDID(address owner,address master,uint256 retention,uint256 deadline)");

  event Added(address account, uint256 retentionPercent);
  event Removed(address account);
  event RetentionUpdated(address account, uint256 retentionPercent);
  event ToggleDisabled(bool state);

  function initialize () public initializer {
      __AccessControlProxyPausable_init(msg.sender);
      __EIP712_init("REENTAL_WHITELIST", "1");
  }

  function add(address account, uint256 retention) public onlyRole(_WHITELIST_ADMIN_ROLE) {
    _add(account, retention);
  }

  function addWithSignature(
    address account,
    uint256 retention,
    uint256 deadline,
    address signer,
    bytes memory signature
  ) public {
    require(block.timestamp <= deadline, "ReentalWhitelist: expired deadline");
    require(hasRole(_WHITELIST_ADMIN_ROLE, signer), "ReentalWhitelist: wrong signer role");

    bytes32 structHash = keccak256(abi.encode(_REENTAL_ADD_TYPEHASH, account, retention, deadline));
    bytes32 hash = _hashTypedDataV4(structHash);
    bool validation = SignatureChecker.isValidSignatureNow(signer, hash, signature);
    require(validation, "ReentalWhitelist: invalid signature");
    _add(account, retention);
  }

  function addDID(
    bytes calldata initializeCalldata, 
    uint256 retention
  ) 
    public 
    onlyRole(_WHITELIST_ADMIN_ROLE) 
    returns(address proxy) 
  {
    proxy = _createProxy(initializeCalldata);
    _add(proxy, retention);
  }

  function addDIDWithSignature(
    bytes calldata initializeCalldata, 
    uint256 retention, 
    uint deadline,
    address signer,
    bytes memory signature
  ) 
    public 
    returns(address proxy) 
  {
    require(block.timestamp <= deadline, "ReentalWhitelist: expired deadline");
    require(hasRole(_WHITELIST_ADMIN_ROLE, signer), "ReentalWhitelist: wrong signer role");

    (address owner,address master) = abi.decode(initializeCalldata[4:], (address, address));
    bytes32 structHash = keccak256(abi.encode(_REENTAL_ADD_DID_TYPEHASH, owner, master, retention, deadline));
    bytes32 hash = _hashTypedDataV4(structHash);
    bool validation = SignatureChecker.isValidSignatureNow(signer, hash, signature);
    require(validation, "ReentalWhitelist: invalid signature");
    
    proxy = _createProxy(initializeCalldata);
    _add(proxy, retention);
  }

  function remove(address account) public onlyRole(_WHITELIST_ADMIN_ROLE){
      require(_whitelisted[account], "ReentalWhitelist: account not whitelisted");
      _whitelisted[account] = false;
      emit Removed(account);
  }

  function toggleDisabled() public onlyRole(_WHITELIST_ADMIN_ROLE){
    disabled = !disabled;
    emit ToggleDisabled(disabled);
  }

  function whitelisted(address account) public view returns(bool) {
    return disabled ? true : _whitelisted[account];
  }

  function updateRetention(address account, uint256 retention) public onlyRole(_WHITELIST_ADMIN_ROLE) {
    require(_whitelisted[account], "ReentalWhitelist: account not whitelisted");
    _updateRetention(account, retention);
    emit RetentionUpdated(account, retention);
  }

  function _add(address account, uint256 retention) internal whenNotPaused {
    require(!_whitelisted[account], "ReentalWhitelist: account already whitelisted");
    _whitelisted[account] = true;
    _updateRetention(account, retention);
    emit Added(account, retention);
  }

  function _updateRetention(address account, uint256 retention) internal {
    require(retention < 100 ether, "ReentalWhitelist: retention cant exceed 100 percent");
    retentionPercent[account] = retention;
  }

  function _createProxy(bytes calldata initializeCalldata) internal returns(address proxy) {
    IReentalDIDFactory factoryDID = IReentalDIDFactory(IReentalManager(config).get(keccak256("REENTAL_DID_FACTORY")));
    proxy = factoryDID.createProxy(initializeCalldata);
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

// Inspired on https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/presets/ERC20PresetMinterPauserUpgradeable.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "contracts/interfaces/IReentalWhitelist.sol";
import "contracts/interfaces/IReentalFactory.sol";
import "contracts/interfaces/IReentalManager.sol";
import "contracts/utils/UUPSUpgradeableByRole.sol";
import "contracts/utils/RefundableUpgradeable.sol";

contract ReentalToken is ERC20CappedUpgradeable, UUPSUpgradeableByRole, RefundableUpgradeable {

  event Swap(address from, address to, uint256 amount);

  address public factory;

  function initialize(string memory name, string memory symbol, uint256 supply) public initializer {
    factory = msg.sender;
    __AccessControlProxyPausable_init(IReentalFactory(factory).config());
    __ERC20_init(name, symbol);
    __ERC20Capped_init_unchained(supply);
  }

  // Mints tokens, callable by minter
  function mint(address account, uint256 amount) external onlyRole(keccak256("MINTER_ROLE")) {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external onlyRole(keccak256("MINTER_ROLE")) {
    _burn(account, amount);
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused {
    IReentalWhitelist whitelistInterface = IReentalWhitelist(IReentalManager(config).get(keccak256("REENTAL_WHITELIST")));
    require(whitelistInterface.whitelisted(to) || to == address(0), "ReentalToken: address not whitelisted");

    if(to != address(0) && balanceOf(to) == 0) {
      IReentalFactory factoryInterface = IReentalFactory(factory);
      factoryInterface.addToken(to);
    }

    super._beforeTokenTransfer(from, to, amount);
  }

  function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {

    if(from != address(0) && balanceOf(from) == 0) {
      IReentalFactory factoryInterface = IReentalFactory(factory);
      factoryInterface.removeToken(from);
    }

    super._beforeTokenTransfer(from, to, amount);
  }

  // Swaps tokens from one address to other
  function _swap(address from, address to, uint256 amount) internal onlyRole(keccak256("MINTER_ROLE")) {
    require(from != address(0), "ReentalToken: sender address is the zero address");
    require(to != address(0), "ReentalToken: receiver address is the zero address");
    require(balanceOf(from) > 0, "ReentalToken: no tokens to transfer");

    _transfer(from, to, amount);

    emit Swap(from, to, amount);
  }

  // Executes _swap, callable by admin
  function swap(address from, address to, uint256 amount) public {
    _swap(from, to, amount);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC20Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Extension of {ERC20} that adds a cap to the supply of tokens.
 */
abstract contract ERC20CappedUpgradeable is Initializable, ERC20Upgradeable {
    uint256 private _cap;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    function __ERC20Capped_init(uint256 cap_) internal initializer {
        __Context_init_unchained();
        __ERC20Capped_init_unchained(cap_);
    }

    function __ERC20Capped_init_unchained(uint256 cap_) internal initializer {
        require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        require(ERC20Upgradeable.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IReentalWhitelist {
  function pause() external;
  function unpause() external;
  function add(address account, uint256 retention) external;
  function remove(address account) external;
  function toggleDisabled() external;
  function whitelisted(address account) external view returns(bool);
  function retentionPercent(address account) external view returns(uint256);
  function disabled() external view returns(bool);
  function config() external view returns (address);
  function initialize(address config_) external;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

interface IReentalFactory  {
    function beacon() external view returns (address);
    function createToken(bytes calldata initializeCalldata) external returns (address);
    function config() external view returns (address);
    function isReentalToken(address token) external view returns (bool);
    function addToken(address account) external;
    function removeToken(address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./extensions/IERC20MetadataUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
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
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
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
    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
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
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
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
        _balances[account] += amount;
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
        }
        _totalSupply -= amount;

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
    uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import "./UUPSUpgradeableByRole.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract SubgraphTokenEvent is UUPSUpgradeableByRole {
    event NewToken(address token, string name, string symbol, uint8 decimals, uint256 totalSupply);

    function initialize() public initializer {
        __AccessControlProxyPausable_init(msg.sender);
    }

    function newToken(address token_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20MetadataUpgradeable token = IERC20MetadataUpgradeable(token_);
        emit NewToken(token_, token.name(), token.symbol(), token.decimals(), token.totalSupply());
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "contracts/interfaces/IReentalWhitelist.sol";
import "contracts/interfaces/IReentalToken.sol";
import "contracts/interfaces/IReentalFactory.sol";
import "contracts/interfaces/IReentalManager.sol";

import "contracts/utils/UUPSUpgradeableByRole.sol";
import "contracts/utils/RefundableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract ReentalTerminator is UUPSUpgradeableByRole, RefundableUpgradeable {

  mapping(address=>uint256) public amounts;
  mapping(address=>bool) public terminated;

  event Claim(address token, address account, uint256 amount);
  
  function initialize () public initializer {
    __AccessControlProxyPausable_init(msg.sender);
  }

  function terminate(address token, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
    require(IReentalFactory(IReentalManager(config).get(keccak256("REENTAL_FACTORY"))).isReentalToken(token), "ReentalTerminator: token not listed");
    amounts[token] += amount;
    terminated[token] = true;
  }

  function claim(address token, address account) public {
    require(terminated[token], "ReentalTerminator: token not terminated");
    uint256 amount = claimable(token, account);
    require(amount > 0, "ReentalTerminator: nothing to claim");
    amounts[token] -= amount;
    IReentalToken tokenInterface = IReentalToken(token);
    tokenInterface.burn(
      account,
      tokenInterface.balanceOf(account)
    );
    address vault = IReentalManager(config).get(keccak256("REENTAL_VAULT"));
    IERC20Upgradeable(IReentalManager(config).get(keccak256("USDT"))).transferFrom(vault, account, amount);
    emit Claim(token, account, amount);
  }

  function claimable(address token, address account) public view returns (uint256) {
    IReentalToken tokenInterface = IReentalToken(token);
    uint256 totalSupply = tokenInterface.totalSupply();
    if (terminated[token] && totalSupply > 0) {
      return amounts[token] * tokenInterface.balanceOf(account) / totalSupply;
    } else {
      return 0;
    }
  }
}

// Inspired on https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/presets/ERC20PresetMinterPauserUpgradeable.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IReentalToken {
  function initialize(string memory name, string memory symbol, uint256 supply, address config_) external;
  function swap(address from, address to, uint256 amount) external;
  function mint(address account, uint256 amount) external;
  function burn(address account, uint256 amount) external;
  function pause() external;
  function unpause() external;
  function totalSupply() external view returns(uint256);
  function balanceOf(address account) external view returns(uint256);
  function cap() external view returns(uint256);
  function allowance(address owner, address spender) external view returns(uint256);
  function config() external view returns (address);
  function transfer(address account, uint256 amount) external returns(bool);
  function transferFrom(address sender, address recipient, uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 */
library MerkleProofUpgradeable {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "contracts/interfaces/IReentalManager.sol";
import "contracts/interfaces/IReentalWhitelist.sol";
import "contracts/interfaces/IReentalToken.sol";
import "contracts/utils/UUPSUpgradeableByRole.sol";
import "contracts/utils/RefundableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract ReentalDividends is UUPSUpgradeableByRole, RefundableUpgradeable {

  mapping(address=>uint256) public distributed;
  mapping(address=>address) public isAuth;

  bytes32 public merkleRoot;
  string public uri;
  
  event Paid(bytes32 merkleRoot, string uri);
  event Distributed(address account, address to, uint256 amount, bool reinvest, uint256 retention);

  function initialize () public initializer {
    __AccessControlProxyPausable_init(msg.sender);
  }

  // Pays dividends using merkleRoot
  function payDividends(bytes32 merkleRoot_, string memory uri_) public onlyRole(keccak256("DIVIDENDS_PAYER_ROLE")){
    merkleRoot = merkleRoot_;
    uri = uri_;
    emit Paid(merkleRoot, uri);
  }

  // Verifies the claimable dividends for an account
  function claimable(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) public view returns(uint256){
    bytes32 node = keccak256(abi.encodePacked(index, account, amount));
    require(MerkleProofUpgradeable.verify(merkleProof, merkleRoot, node), "ReentalDividends: invalid proof");
    uint256 distributed_ = distributed[account];
    return amount > distributed_ ? (amount - distributed_) : 0;
  }

  // Distributes tokens to the selected address
  function _distribute(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof, address to, uint256 distribution) internal whenNotPaused {
    uint256 distributable = claimable(index, account, amount, merkleProof);
    require(distributable > 0, "ReentalDividends: nothing to distribute");
    require(distribution <= distributable, "ReentalDividends: amount to distribute exceeds dividends balance claimable");

    IERC20 dividendsInterface = IERC20(IReentalManager(config).get(keccak256("USDT")));
    address vault = IReentalManager(config).get(keccak256("REENTAL_VAULT"));
    distributed[account] += distribution;
    if (account != to){
      dividendsInterface.transferFrom(vault, to, distribution);
      emit Distributed(account, to, distribution, true, 0);
    }else{
      uint256 retention = retention(account, distribution);
      uint256 claimed = distribution - retention;
      dividendsInterface.transferFrom(vault, account, claimed);
      emit Distributed(account, to, claimed, false, retention);
    }
  }

  // Gets retention for an amount
  function retention(address account, uint256 amount) public view returns(uint256){
    IReentalWhitelist whitelistInterface = IReentalWhitelist(IReentalManager(config).get(keccak256("REENTAL_WHITELIST")));
    return (amount * whitelistInterface.retentionPercent(account)) / 100 ether;
  }

  // Claims dividends not distributed yet
  function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) public {
    require(account == msg.sender || isAuth[account] == msg.sender, "ReentalDividends: claimer not authorized");
    uint256 claimable_ = claimable(index, account, amount, merkleProof);
    _distribute(index, account, amount, merkleProof, account, claimable_);
  }

  // Reinvests dividends for a new crowdsale
  function reinvest(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof, address to, uint256 distribution) public {
    require(msg.sender == IReentalManager(config).get(keccak256("REENTAL_CROWDSALE")), "ReentalDividends: only crowdsale can reinvest dividends");
    _distribute(index, account, amount, merkleProof, to, distribution);
  }

  function authClaimer(address account) public {
    isAuth[msg.sender] = account;
  }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./AccessControlProxyPausable.sol";

contract UUPSNotUpgradeable is AccessControlProxyPausable, UUPSUpgradeable {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // function endUpgradeability() public onlyRole(UPGRADER_ROLE) {
    //     StorageSlot.getBooleanSlot(bytes32(uint256(keccak256("eip1967.proxy.upgradeabilityEnded")) - 1)).value = true;
    // }

    // function upgradeabilityEnded() public view returns(bool) {
    //     return StorageSlot.getBooleanSlot(bytes32(uint256(keccak256("eip1967.proxy.upgradeabilityEnded")) - 1)).value;
    // }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {
        // require(!upgradeabilityEnded(), "UUPSNotUpgradeable: not upgradeable anymore");
        require(StorageSlot.getBooleanSlot(bytes32(uint256(keccak256("eip1967.proxy.rollback")) - 1)).value, "UUPSNotUpgradeable: not upgradeable anymore");
    }

        function implementation () public view returns (address) {
        return _getImplementation();
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "contracts/lib/Contracts.sol";

contract ReentalManager is AccessControlUpgradeable {
    
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    mapping(bytes32=>address) public get;
    mapping(address=>bytes32) public name;
    mapping(bytes32=>bool) public locked;
    mapping(address => bool) public isVerified;
    mapping(address=>address) public implementationByProxy;

    event NewId(bytes32 indexed id, address addr);
    event Deployment(bytes32 indexed id, address indexed proxy, address implementation, bool upgrade);
    event Locked(bytes32 indexed id, address addr);
    event SetVerification(address addr, bool verified, address sender);

    modifier checkLocked (bytes32 id) {
        require(!locked[id], "TutellusManager: id locked");
        _;
    }

    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, address(this));
        _setupRole(UPGRADER_ROLE, address(this));
    }

    function setId(bytes32 id, address addr) public onlyRole(DEFAULT_ADMIN_ROLE) checkLocked(id) {
        get[id] = addr;
        name[addr] = id;
        setVerification(addr, true);

        emit NewId(id, addr);
    }

    function setVerification(address addr, bool verified) public onlyRole(DEFAULT_ADMIN_ROLE) {
        isVerified[addr] = verified;
        emit SetVerification(addr, verified, msg.sender);
    }

    function deployProxyWithImplementation(bytes32 id, address implementation, bytes memory initializeCalldata) public onlyRole(DEFAULT_ADMIN_ROLE) checkLocked(id) {
        _deployProxy(id, implementation, initializeCalldata);

        emit Deployment(id, get[id], implementation, false);
    }

    function deploy(bytes32 id, bytes memory bytecode, bytes memory initializeCalldata) public onlyRole(DEFAULT_ADMIN_ROLE) checkLocked(id) returns(address implementation) {

        implementation = Contracts.deploy(bytecode);

        address proxyAddress = get[id];

        if (proxyAddress != address(0)) {
            upgrade(id, implementation, initializeCalldata);
            emit Deployment(id, get[id], implementation, true);
        } else {
            _deployProxy(id, implementation, initializeCalldata);
            emit Deployment(id, get[id], implementation, false);
        }
    }

    function upgrade(bytes32 id, address implementation, bytes memory initializeCalldata) public onlyRole(DEFAULT_ADMIN_ROLE) checkLocked(id) {
        UUPSUpgradeable proxy = UUPSUpgradeable(payable(get[id]));
        if (initializeCalldata.length > 0) {
            proxy.upgradeToAndCall(implementation, initializeCalldata);
        } else {
            proxy.upgradeTo(implementation);
        }
        implementationByProxy[address(proxy)] = implementation;
    }

    function _deployProxy(bytes32 id, address implementation, bytes memory initializeCalldata) private {
        address proxy = address(new ERC1967Proxy(
            implementation,
            initializeCalldata
        ));
        get[id] = proxy;
        name[proxy] = id;
        isVerified[proxy] = true;
        implementationByProxy[proxy] = implementation;
    }

    function lock(bytes32 id) public onlyRole(DEFAULT_ADMIN_ROLE) {
        locked[id] = true;
        emit Locked(id, get[id]);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Proxy.sol";
import "./ERC1967Upgrade.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializating the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) payable {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        _upgradeToAndCall(_logic, _data, false);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        return ERC1967Upgrade._getImplementation();
    }
}

// SPDX-License-Identifier: MIT

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
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {
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
        _checkRole(role, _msgSender());
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
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
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
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
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
     * If the calling account had been granted `role`, emits a {RoleRevoked}
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

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "contracts/utils/RefundableUpgradeable.sol";
import "contracts/utils/UUPSUpgradeableByRole.sol";
import "contracts/utils/BeaconFactory.sol";
import "contracts/lib/Contracts.sol";

contract ReentalFactory is UUPSUpgradeableByRole, BeaconFactory, RefundableUpgradeable {

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");
    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _FACTORY_UPGRADER_ROLE = keccak256("FACTORY_UPGRADER_ROLE");

    event NewToken(address proxy, string name, string symbol, uint8 decimals, uint256 totalSupply);

    mapping(address=>bool) public isReentalToken;

    mapping(address=>mapping(uint256=>address)) public tokenOfAccount;
    mapping(address=>uint256) public tokensOf;

    mapping(address=>mapping(uint256=>address)) public accountOfToken;
    mapping(address=>uint256) public accountsOf;

    mapping(address=>mapping(address=>uint256)) public idOfTokenByAccount;
    mapping(address=>mapping(address=>uint256)) public idOfAccountByToken;

    modifier onlyReentalToken {
        require(isReentalToken[msg.sender], "ReentalFactory: only Reental token");
        _;
    }

    function initialize() public initializer {
        __AccessControlProxyPausable_init(msg.sender);
    }

    function createToken(bytes calldata initializeCalldata) public isBeaconSet onlyRole(_FACTORY_ADMIN_ROLE)  returns(address) {
        BeaconProxy proxy = new BeaconProxy(
            beacon,
            initializeCalldata
        );

        address proxyAddress = address(proxy);

        isReentalToken[proxyAddress] = true;

        (string memory name, string memory symbol, uint256 totalSupply) = abi.decode(initializeCalldata[4:], (string, string, uint256));

        emit NewToken(proxyAddress, name, symbol, 18, totalSupply);
        
        return proxyAddress;
    }

    function addToken(address account) public isBeaconSet onlyReentalToken {
        tokensOf[account]++;
        accountsOf[msg.sender]++;
        idOfTokenByAccount[account][msg.sender] = tokensOf[account];
        idOfAccountByToken[msg.sender][account] = accountsOf[msg.sender];
        tokenOfAccount[account][tokensOf[account]] = msg.sender;
        accountOfToken[msg.sender][accountsOf[msg.sender]] = account;
    }

    function removeToken(address account) public isBeaconSet onlyReentalToken {
        
        address lastToken = tokenOfAccount[account][tokensOf[account]];
        address lastAccount = accountOfToken[msg.sender][accountsOf[msg.sender]];
        uint256 tokenId = idOfTokenByAccount[account][msg.sender];
        uint256 accountId = idOfAccountByToken[msg.sender][account];

        tokenOfAccount[account][tokenId] = lastToken;
        accountOfToken[msg.sender][accountId] = lastAccount;

        tokenOfAccount[account][tokensOf[account]] = address(0);
        accountOfToken[msg.sender][accountsOf[msg.sender]] = address(0);

        tokensOf[account]--;
        accountsOf[msg.sender]--;

        idOfTokenByAccount[account][msg.sender] = 0;
        idOfAccountByToken[msg.sender][account] = 0;
        
    }

    function upgrade(bytes memory bytecode) public onlyRole(_FACTORY_UPGRADER_ROLE) returns (address implementation) {
        return _upgradeByBytecode(bytecode);
    }

    function upgradeWithImplementation(address implementation) public onlyRole(_FACTORY_UPGRADER_ROLE) {
        _upgradeByImplementation(implementation);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract UntransferableToken is ERC20Upgradeable {

    address public owner;

    constructor (string memory name_, string memory symbol_) {
        initialize(name_, symbol_);
    }

    function initialize (string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        owner = msg.sender;
        _mint(owner, 1e26);
    }

    function mint(address account, uint256 amount) public {
        require(msg.sender == owner, "UntransferableToken: only owner can mint");
        _mint(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        require(from == address(0) || to == address(0), "UntransferableToken: untransferable");
        super._beforeTokenTransfer(from, to, amount);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract Token is ERC20Upgradeable {

    address public owner;

    constructor (string memory name_, string memory symbol_) {
        initialize(name_, symbol_);
    }

    function initialize (string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        owner = msg.sender;
        _mint(owner, 1e26);
    }

    function mint(address account, uint256 amount) public {
        require(msg.sender == owner, "Token: only owner can mint");
        _mint(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "contracts/utils/OwnableUpgradeable.sol";
import "contracts/utils/MasterableUpgradeable.sol";
import "../ReentalDIDStorage.sol";
import "contracts/interfaces/IReentalDID.sol";

contract ReentalDIDV2Mock is 
    Initializable, 
    OwnableUpgradeable, 
    MasterableUpgradeable, 
    PausableUpgradeable, 
    ERC721HolderUpgradeable, 
    ERC1155HolderUpgradeable, 
    IReentalDID, 
    ReentalDIDStorage 
{
    function version() external pure returns(string memory) {
        return "0.0.2";
    }

    /***************************************************************/
    // INIT FUNCTIONS
    /***************************************************************/

    function initialize(address owner_, address master_) public initializer {
        __ERC721Holder_init();
        __Ownable_init();
        _transferOwnership(owner_);
        __Masterable_init();
        _transferMastership(master_);
        factory = msg.sender;
    }
}

// SPDX-License-Identifier: MIT

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
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ERC20Mock is ERC20Upgradeable, OwnableUpgradeable {
  function initialize(string memory name, string memory symbol) public initializer{
    __ERC20_init(name, symbol);
    __Ownable_init();
  }
  function mint(address account, uint256 amount) public onlyOwner{
    _mint(account, amount);
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AggregatorMock is AggregatorV3Interface, Initializable {
    uint80 private _round = 0;
    uint256 private _time = 0;
    string private _description = "mock";
    uint8 private _decimals;
    int256 private _answer;

    function initialize(uint8 decimals, int256 answer) public {
        __AggregatorMock_init(decimals, answer);
    }

    function __AggregatorMock_init(uint8 decimals, int256 answer) internal initializer {
        _decimals = decimals;
        _answer = answer;
    }

    function decimals() override external view returns (uint8){
        return _decimals;
    }

    function description() override external view returns (string memory){
      return _description;
    }

    function version() override external view returns (uint256){
      return _time;
    }

    function latestRoundData() override external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
      return (
        _round,
        _answer,
        _time,
        _time,
        _round
      );
    }

    function getRoundData(uint80 _roundId) override external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
      return (
        _roundId,
        _answer,
        _time,
        _time,
        _round
      );
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "contracts/interfaces/IReentalToken.sol";
import "contracts/interfaces/IReentalManager.sol";
import "contracts/interfaces/IReentalDividends.sol";
import "contracts/interfaces/IReentalFactory.sol";
import "contracts/interfaces/IWETH.sol";
import "contracts/utils/UUPSUpgradeableByRole.sol";
import "contracts/utils/RefundableUpgradeable.sol";
import "contracts/interfaces/IUniswapV2Router01.sol";

contract ReentalCrowdsale is UUPSUpgradeableByRole, RefundableUpgradeable {

  uint8 private _decimals; // ETH decimals
  uint256 public minimum;

  struct TokenInfo {
      bool enabled;
      uint256 price;
      uint256 poolPercent;
  }

  mapping(address => TokenInfo) public tokenInfo;

  event EnabledToken(address token, uint256 price, uint256 poolPercent);
  event Contribution(address token, address entryToken, address account, uint256 tokens, uint256 payback, bool reinvest);
  event Destroyed();

  // solhint-disable-next-line var-name-mixedcase
  bytes32 private immutable _CROWDSALE_ADMIN_ROLE = keccak256("CROWDSALE_ADMIN_ROLE");

  function initialize () public initializer {
    __AccessControlProxyPausable_init(msg.sender);
    _decimals = 18;
    minimum = 1 ether; // 1 token
  }

  function setMinimum(uint256 min) public onlyRole(_CROWDSALE_ADMIN_ROLE) {
    minimum = min;
  }

  function _getRate(address aggregator) internal view returns(uint256) {
    AggregatorV3Interface aggregatorInterface = AggregatorV3Interface(aggregator);
    (,int256 answer,,,) = aggregatorInterface.latestRoundData();
    uint8 decimals = aggregatorInterface.decimals();
    uint div = uint256(10**uint256(_decimals - decimals));
    return uint256(answer) * div;
  }

  // Gets rates EUR/USD, USDT/USD
  function getRates() public view returns(uint256 usdtRate, uint256 eurRate) {
    return (_getRate(IReentalManager(config).get(keccak256("USDT_USD_FEED"))), _getRate(IReentalManager(config).get(keccak256("EUR_USD_FEED"))));
  }

  function _contribute(address account, address token, uint256 amountIn) internal returns (uint256, uint256) {

    (uint256 tokens, uint256 payback) = getTokensByContribution(token, amountIn);

    require(tokens > minimum, "ReentalCrowdsale: contribution failed, not enough tokens");

    if(payback > 0){
      IERC20Upgradeable(IReentalManager(config).get(keccak256("USDT"))).transfer(account, payback);
    }

    IReentalToken tokenInterface = IReentalToken(token);
    tokenInterface.mint(account, tokens);

    return (tokens, payback);
  }

  function contributionETH(address token, uint256 amountOutMin, address[] calldata path, uint256 deadline) public payable whenNotPaused {
    address account = _msgSender();
    address router = IReentalManager(config).get(keccak256("ROUTER"));
    address weth = IUniswapV2Router01(router).WETH();

    require(path[0] == weth, "ReentalCrowdsale: WETH must be the beginning of the path");

    uint256[] memory amounts = IUniswapV2Router01(router).swapExactETHForTokens{ value: msg.value }(amountOutMin, path, address(this), deadline);
  
    (uint256 tokens, uint256 payback) = _contribute(account, token, amounts[amounts.length - 1]);
    emit Contribution(token, weth, account, tokens, payback, false);
  }

  function contributionTokens(address token, uint256 amountIn, uint256 amountOutMin, address[] calldata path, uint256 deadline) public whenNotPaused {
    address account = _msgSender();
    address entryToken = path[0];
    address router = IReentalManager(config).get(keccak256("ROUTER"));

    IERC20Upgradeable(entryToken).transferFrom(account, address(this), amountIn);

    if (entryToken == IReentalManager(config).get(keccak256("USDT"))) {
      (uint256 tokens, uint256 payback) = _contribute(account, token, amountIn);
      emit Contribution(token, entryToken, account, tokens, payback, false);
    } else {
      require(path[path.length - 1] == IReentalManager(config).get(keccak256("USDT")), "ReentalCrowdsale: USDT must be the end of the path");
      IERC20Upgradeable(entryToken).approve(router, amountIn);

      uint256[] memory amounts = IUniswapV2Router01(router).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);
      (uint256 tokens, uint256 payback) = _contribute(account, token, amounts[amounts.length - 1]);
      emit Contribution(token, entryToken, account, tokens, payback, false);
    }    
  }

  function contributionDividends(address token, uint256 index, uint256 amount, bytes32[] calldata merkleProof, uint256 amountIn) public whenNotPaused {
    address account = _msgSender();
    IReentalDividends dividends = IReentalDividends(IReentalManager(config).get(keccak256("REENTAL_DIVIDENDS")));
    dividends.reinvest(index, account, amount, merkleProof, address(this), amountIn);

    (uint256 tokens, uint256 payback) = _contribute(account, token, amountIn);
    emit Contribution(token, IReentalManager(config).get(keccak256("USDT")), account, tokens, payback, true);
  }

  // Gets tokens left to sell
  function getTokensLeft(address token) public view returns(uint256){
    TokenInfo memory tokenData = tokenInfo[token];
    IReentalToken tokenInterface = IReentalToken(token);
    return tokenInterface.cap() - (tokenInterface.totalSupply() + ((tokenInterface.cap() * tokenData.poolPercent) / 1e20));
  }

  function getTokens(address token, uint256 amount) public view returns(uint256){
    TokenInfo memory tokenData = tokenInfo[token];
    (uint256 usdtRate, uint256 eurRate) = getRates();
    return amount * 1 ether * usdtRate / tokenData.price / eurRate;
  }
  
  function getPayback(address token, uint256 amount) public view returns(uint256){
    TokenInfo memory tokenData = tokenInfo[token];
    (uint256 usdtRate, uint256 eurRate) = getRates();
    return amount * eurRate * tokenData.price / usdtRate / 1 ether;
  }

  // Gets tokens and payback by contribution by dividends
  function getTokensByContribution(address token, uint256 amount) public view returns (uint256, uint256) {
    TokenInfo memory tokenData = tokenInfo[token];

    if (!tokenData.enabled) {
      return (0, 0);
    }

    uint256 left = getTokensLeft(token);
    uint256 tokens = getTokens(token, amount);

    return tokens > left ? (left, getPayback(token, tokens-left)) : (tokens, 0);
  }

  // Enables a token to be used in ReentalCrowdsale
  function enableToken(address token, uint256 price, uint256 poolPercent) public onlyRole(_CROWDSALE_ADMIN_ROLE) {
    require(token != address(0), "ReentalCrowdsale: token address is the zero address");
    address factory = IReentalManager(config).get(keccak256("REENTAL_FACTORY"));
    require(factory != address(0), "ReentalCrowdsale: factory not created yet");
    require(IReentalFactory(factory).isReentalToken(token), "ReentalCrowdsale: cannot enable not-ReentalToken");
    require(!isEnabledToken(token), "ReentalCrowdsale: token already enabled");
    require(poolPercent <= 1e20, "ReentalCrowdsale: pool percentage must be under 100 ETH");
    require(price > 0, "ReentalCrowdsale: price must be over zero");
    

    TokenInfo storage tokenData = tokenInfo[token];
    tokenData.enabled = true;
    tokenData.price = price;
    tokenData.poolPercent = poolPercent;

    emit EnabledToken(token, price, poolPercent);
  }

  // Gets whether a token is enabled or not
  function isEnabledToken(address token) public view returns(bool) {
    return tokenInfo[token].enabled;
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IReentalDividends {

  // Initializes the contract
  function initialize(address config_) external;

  // Updates the contract
  function update(address config_) external;

  // Pauses the contract
  function pause() external;

  // Unpauses the contract
  function unpause() external;

  // Adds a token to the dividends contract
  function addToken(address token) external;

  // Removes a token from the dividends contract
  function removeToken(address token) external;

  // Pays dividends to the dividends contract
  function payDividends(address token, uint256 amount, bytes32 merkleRoot, string memory uri) external;

  // Claims dividends (tax retention is executed)
  function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof, uint256 distribution) external;

  // Claims all dividends (tax retention is executed)
  function claimAll(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;

  // Reinvests dividends for a new crowdsale
  function reinvest(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof, address to, uint256 distribution) external;

  // Gets whether a token is listed or not
  function listed(address token) external view returns(bool);

  // Gets paid dividends for a token
  function paid(address token) external view returns(uint256);

  // Grants pauser role to an account
  function grantPauserRole(address account) external;

  // Grants admin role to an account
  function grantAdminRole(address account) external;

  // Destroys the contract
  function destroy() external;

  // Gets the pool of selected token in the AMM against dividends Token
  function getPool(address token) external view returns(address);

  // Gets amount claimable for an account
  function claimable(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external view returns(uint256);

  // Gets dividends already distributed
  function distributed(address account) external view returns(uint256);
  
  function config() external view returns (address);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "contracts/interfaces/IReentalDividends.sol";
import "contracts/interfaces/IReentalConfig.sol";

contract CrowdsaleMock {
  address public owner;
  event Contribution(address account, uint256 amount, bool reinvest);
  constructor(){
    owner = msg.sender;
  }
  modifier onlyOwner(){
    require(msg.sender == owner, "CrowdsaleMock: sender is not owner");
    _;
  }
  function reinvestAll(address config, uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) public onlyOwner{
    IReentalConfig configInterface = IReentalConfig(config);
    IReentalDividends dividendsInterface = IReentalDividends(configInterface.dividends());
    uint256 distribution = dividendsInterface.claimable(index, account, amount, merkleProof);
    dividendsInterface.reinvest(index, account, amount, merkleProof, owner, distribution);
    emit Contribution(account, amount, true);
  }
  function reinvest(address config, uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof, uint256 distribution) public onlyOwner{
    IReentalConfig configInterface = IReentalConfig(config);
    IReentalDividends dividendsInterface = IReentalDividends(configInterface.dividends());
    dividendsInterface.reinvest(index, account, amount, merkleProof, owner, distribution);
    emit Contribution(account, amount, true);
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IReentalConfig {

    function initialize(address whitelist_, address tokenFactory_, address crowdsale_, address dividends_, address usdt_, address usdtUsdFeed_, address eurUsdFeed_, address router_, address vault_) external;

    function whitelist() external view returns(address);

    function crowdsale() external view returns(address);

    function dividends() external view returns(address);

    function usdt() external view returns(address);

    function usdtUsdFeed() external view returns(address);

    function eurUsdFeed() external view returns(address);

    function factory() external view returns(address);

    function router() external view returns(address);

    function vault() external view returns(address);

    function updateWhitelist(address whitelist_) external;

    function updateCrowdsale(address crowdsale_) external;

    function updateDividends(address dividends_) external;

    function updateUsdtUsdFeed(address usdtUsdFeed_) external;

    function updateEurUsdFeed(address eurUsdFeed_) external;

    function updateVault(address vault_) external;

    function updateTokenFactory(address tokenFactory_) external;

    function updateRouter(address router_) external;

    function updateAll(address whitelist_, address tokenFactory_, address crowdsale_, address dividends_, address usdt_, address usdtUsdFeed_, address router_) external;

    function grantAdminRole(address account) external;

    function grantPauserRole(address account) external;

    function grantMinterRole(address account) external;

    function grantDividendsPayerRole(address account) external;

    function grantDIDCreatorRole(address account) external;
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "contracts/utils/AccessControlProxyPausable.sol";

contract AccessControlProxyPausableMock is AccessControlProxyPausable {
    function initialize () public initializer {
        __AccessControlProxyPausable_init(msg.sender);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "contracts/utils/RefundableUpgradeable.sol";

contract RefundableMock is RefundableUpgradeable {
    function initialize () public initializer {
        __Refundable_init();
    }
}