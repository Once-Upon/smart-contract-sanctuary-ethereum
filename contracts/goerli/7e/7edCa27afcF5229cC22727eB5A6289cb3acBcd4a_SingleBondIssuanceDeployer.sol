// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (access/AccessControl.sol)

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
        _checkRole(role);
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

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
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
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
        }
        _balances[to] += amount;

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

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
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

/**
 * @title CustodianStorage
 * @author Atlendis Labs
 */
contract CustodianStorage {
    // constants
    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;

    // addresses
    ERC20 public token; // Custodian token
    address public adapter; // Current adapter
    address public yieldProvider; // Current yield provider

    // balances
    uint256 public depositedBalance; // Original token balance deposited to custodian
    uint256 public pendingRewards; // Yield provider rewards to be withdrawn
    uint256 public generatedRewards; // Yield provider rewards to be withdrawn

    // below variable usage are yield provider specific
    uint256 public yieldProviderBalance; // Yield provider specific balance
    uint256 public lastYieldFactor; // Yield provider specific ratio to be used to compute rewards
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/access/AccessControl.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

import '../interfaces/IAdapter.sol';
import '../interfaces/IPoolCustodian.sol';
import './CustodianStorage.sol';

/**
 * @title PoolCustodian
 * @author Atlendis Labs
 * @dev CustodianStorage should be imported first, storage layout is important
 * for adapters delegatecall to work as intended
 */
contract PoolCustodian is CustodianStorage, AccessControl, IPoolCustodian {
    using SafeERC20 for ERC20;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant POOL_ROLE = keccak256('POOL_ROLE');
    bytes32 public constant REWARDS_ROLE = keccak256('REWARDS_ROLE');

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Constructor
     * @param _token ERC20 contract of the token
     * @param _adapter Address of the adapter
     * @param _yieldProvider Address of the yield provider
     * @param governance Address of the governance
     */
    constructor(
        ERC20 _token,
        address _adapter,
        address _yieldProvider,
        address governance
    ) {
        token = _token;
        adapter = _adapter;
        yieldProvider = _yieldProvider;

        if (!IAdapter(_adapter).supportsInterface(type(IAdapter).interfaceId)) revert ADAPTER_NOT_SUPPORTED();
        bytes memory returnData = adapterDelegateCall(
            _adapter,
            abi.encodeWithSignature('supportsToken(address)', _yieldProvider)
        );
        if (!abi.decode(returnData, (bool))) revert TOKEN_NOT_SUPPORTED();

        _setupRole(DEFAULT_ADMIN_ROLE, governance);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPoolCustodian
     */
    function getAssetDecimals() external view returns (uint256) {
        return token.decimals();
    }

    /**
     * @inheritdoc IPoolCustodian
     */
    function getRewards() external view returns (uint256) {
        return pendingRewards;
    }

    /**
     * @inheritdoc IPoolCustodian
     */
    function getGeneratedRewards() external view returns (uint256) {
        return generatedRewards;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IPoolCustodian).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPoolCustodian
     */
    function deposit(uint256 amount, address from) public onlyRole(POOL_ROLE) {
        collectRewards();

        depositedBalance += amount;

        token.safeTransferFrom(from, address(this), amount);
        token.approve(yieldProvider, amount);
        bytes memory returnData = adapterDelegateCall(adapter, abi.encodeWithSignature('deposit(uint256)', amount));
        if (!abi.decode(returnData, (bool))) revert DELEGATE_CALL_FAIL();

        emit Deposit(amount, from, adapter, yieldProvider);
    }

    /**
     * @inheritdoc IPoolCustodian
     */
    function withdraw(uint256 amount, address to) public onlyRole(POOL_ROLE) {
        collectRewards();

        if (amount == type(uint256).max) amount = depositedBalance;
        depositedBalance -= amount;

        bytes memory returnData = adapterDelegateCall(adapter, abi.encodeWithSignature('withdraw(uint256)', amount));
        if (!abi.decode(returnData, (bool))) revert DELEGATE_CALL_FAIL();
        token.safeTransfer(to, amount);

        emit Withdraw(amount, to, adapter, yieldProvider);
    }

    /*//////////////////////////////////////////////////////////////
                          REWARDS MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPoolCustodian
     */
    function collectRewards() public returns (uint256) {
        bytes memory returnData = adapterDelegateCall(
            adapter,
            abi.encodeWithSignature('collectRewards()', yieldProvider)
        );
        uint256 collectedAmount = abi.decode(returnData, (uint256));

        pendingRewards += collectedAmount;
        generatedRewards += collectedAmount;

        emit RewardsCollected(collectedAmount);

        return collectedAmount;
    }

    /**
     * @inheritdoc IPoolCustodian
     */
    function withdrawRewards(uint256 amount, address to) external onlyRole(REWARDS_ROLE) {
        collectRewards();

        if (amount == type(uint256).max) amount = pendingRewards;
        pendingRewards -= amount;

        bytes memory returnData = adapterDelegateCall(adapter, abi.encodeWithSignature('withdraw(uint256)', amount));
        if (!abi.decode(returnData, (bool))) revert DELEGATE_CALL_FAIL();

        token.safeTransfer(to, amount);

        emit RewardsWithdrawn(amount);
    }

    /*//////////////////////////////////////////////////////////////
                      YIELD PROVIDER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPoolCustodian
     */
    function switchYieldProvider(address newAdapter, address newYieldProvider) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!IAdapter(newAdapter).supportsInterface(type(IAdapter).interfaceId)) revert ADAPTER_NOT_SUPPORTED();
        bytes memory returnData = adapterDelegateCall(
            newAdapter,
            abi.encodeWithSignature('supportsToken(address)', newYieldProvider)
        );
        if (!abi.decode(returnData, (bool))) revert TOKEN_NOT_SUPPORTED();

        collectRewards();
        returnData = adapterDelegateCall(adapter, abi.encodeWithSignature('empty()'));
        if (!abi.decode(returnData, (bool))) revert DELEGATE_CALL_FAIL();

        uint256 balanceToSwitch = token.balanceOf(address(this));
        adapter = newAdapter;
        yieldProvider = newYieldProvider;

        collectRewards();
        token.approve(newYieldProvider, balanceToSwitch);
        returnData = adapterDelegateCall(adapter, abi.encodeWithSignature('deposit(uint256)', balanceToSwitch));
        if (!abi.decode(returnData, (bool))) revert DELEGATE_CALL_FAIL();

        emit YieldProviderSwitched(adapter, yieldProvider);
    }

    function adapterDelegateCall(address _adapter, bytes memory data) private returns (bytes memory) {
        (bool success, bytes memory returnData) = _adapter.delegatecall(data);
        if (!success || returnData.length == 0) revert DELEGATE_CALL_FAIL();
        return returnData;
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';

/**
 * @notice IAdapter
 * @author Atlendis Labs
 * @notice Interface Adapter contract
 *         An Adapter is associated to a yield provider.
 *         It implement the logic necessary to deposit, withdraw and compute rewards
 *         the custodian will get when managing its holdings
 */
interface IAdapter is IERC165 {
    /**
     * @notice Verifies that the yield provider associated with the adapter supports the custodian token
     * @return _ True if the token is supported, false otherwise
     **/
    function supportsToken(address yieldProvider) external returns (bool);

    /**
     * @notice Deposit tokens to the yield provider
     * @param amount Amount to deposit
     * @return success Success boolean, required as additional safely for delegate call handling
     **/
    function deposit(uint256 amount) external returns (bool success);

    /**
     * @notice Withdraw tokens from the yield provider
     * @param amount Amount to withdraw
     * @return success Success boolean, required as additional safely for delegate call handling
     **/
    function withdraw(uint256 amount) external returns (bool success);

    /**
     * @notice Withdraws all deposits from the yield provider
     * Only called when switching yield providers
     * @return success Success boolean, required as additional safely for delegate call handling
     **/
    function empty() external returns (bool success);

    /**
     * @notice Updates the pending rewards accrued by the deposits
     * @return _ The collected amount of rewards
     **/
    function collectRewards() external returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';

/**
 * @notice IPoolCustodian
 * @author Atlendis Labs
 * @notice Interface of the Custodian contract
 *         A custodian contract is associated to a product contract.
 *         It receives funds by the associated product contract.
 *         A yield strategy is chosen in order to generate rewards based on the deposited funds.
 */
interface IPoolCustodian is IERC165 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when an internal delegate call fails
     */
    error DELEGATE_CALL_FAIL();

    /**
     * @notice Thrown when given yield provider does not support the token
     */
    error TOKEN_NOT_SUPPORTED();

    /**
     * @notice Thrown when the given address does not support the adapter interface
     */
    error ADAPTER_NOT_SUPPORTED();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when tokens have been deposited to the custodian using current adapter and yield provider
     * @param amount Deposited amount of tokens
     * @param adapter Address of the adapter
     * @param yieldProvider Address of the yield provider
     **/
    event Deposit(uint256 amount, address from, address adapter, address yieldProvider);

    /**
     * @notice Emitted when tokens have been withdrawn from the custodian using current adapter and yield provider
     * @param amount Withdrawn amount of tokens
     * @param to Recipient address
     * @param adapter Address of the adapter
     * @param yieldProvider Address of the yield provider
     **/
    event Withdraw(uint256 amount, address to, address adapter, address yieldProvider);

    /**
     * @notice Emitted when the yield provider has been switched
     * @param adapter Address of the new adapter
     * @param yieldProvider Address of the new yield provider
     **/
    event YieldProviderSwitched(address adapter, address yieldProvider);

    /**
     * @notice Emitted when the rewards have been collected
     * @param amount Amount of collected rewards
     **/
    event RewardsCollected(uint256 amount);

    /**
     * @notice Emitted when rewards have been withdrawn
     * @param amount Amount of withdrawn rewards
     **/
    event RewardsWithdrawn(uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieve the current stored amount of rewards generated by the custodian
     * @return rewards Amount of rewards
     */
    function getRewards() external view returns (uint256 rewards);

    /**
     * @notice Retrieve the all time amount of generated rewards by the custodian
     * @return generatedRewards All time amount of rewards
     */
    function getGeneratedRewards() external view returns (uint256 generatedRewards);

    /**
     * @notice Retrieve the decimals of the underlying asset
     & @return decimals Decimals of the underlying asset
     */
    function getAssetDecimals() external view returns (uint256 decimals);

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit tokens to the yield provider
     * Collects pending rewards before depositing
     * @param amount Amount to deposit
     *
     * Emits a {Deposit} event
     **/
    function deposit(uint256 amount, address from) external;

    /**
     * @notice Withdraw tokens from the yield provider
     * Collects pending rewards before withdrawing
     * @param amount Amount to withdraw
     * @param to Recipient address
     *
     * Emits a {Withdraw} event
     **/
    function withdraw(uint256 amount, address to) external;

    /*//////////////////////////////////////////////////////////////
                          REWARDS MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw an amount of rewards
     * @param amount The amount of rewards to be withdrawn
     * @param to Address that will receive the rewards
     *
     * Emits a {RewardsWithdrawn} event
     **/
    function withdrawRewards(uint256 amount, address to) external;

    /**
     * @notice Updates the pending rewards accrued by the deposits
     * @return rewardsCollected The collected amount of rewards
     *
     * Emits a {RewardsCollected} event
     **/
    function collectRewards() external returns (uint256);

    /*//////////////////////////////////////////////////////////////
                      YIELD PROVIDER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Changes the yield provider used by the custodian
     * @param newAdapter New adapter used to manage yield provider interaction
     * @param newYieldProvider New yield provider address
     *
     * Emits a {YieldProviderSwitched} event
     **/
    function switchYieldProvider(address newAdapter, address newYieldProvider) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

enum PositionStatus {
    AVAILABLE,
    BORROWED,
    UNAVAILABLE
}

/**
 * @title IPositionManager
 * @author Atlendis Labs
 * @notice Interface of a Position Manager
 */
interface IPositionManager is IERC721 {
    /**
     * @notice Retrieve a position
     * @param positionId ID of the position
     * @return owner Address of the position owner
     * @return rate Value of the position rate
     * @return depositedAmount Deposited amount of the position
     * @return status Status of the position
     */
    function getPosition(uint256 positionId)
        external
        returns (
            address owner,
            uint256 rate,
            uint256 depositedAmount,
            PositionStatus status
        );

    /**
     * @notice Update a position rate
     * @param positionId The ID of the position
     * @param rate The new rate of the position
     */
    function updateRate(uint256 positionId, uint256 rate) external;

    /**
     * @notice Retrieve the current maturity
     * @return maturity The current maturity
     */
    function getMaturity() external view returns (uint256 maturity);

    /**
     * @notice Retrieve the loan duration
     * @return loanDuration The loan duration
     */
    function LOAN_DURATION() external view returns (uint256 loanDuration);

    /**
     * @notice Retrieve one in the pool token precision
     * @return one One in the pool token precision
     */
    function ONE() external view returns (uint256 one);

    /**
     * @notice Retrieve the address of the custodian
     * @return custodian Address of the custodian
     */
    function CUSTODIAN() external view returns (address custodian);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import {FixedPointMathLib as SolmateFixedPointMathLib} from 'lib/solmate/src/utils/FixedPointMathLib.sol';

/**
 * @title FixedPointMathLib library
 * @author Atlendis Labs
 * @dev Overlay over Solmate FixedPointMathLib
 *      Results of multiplications and divisions are always rounded down
 */
library FixedPointMathLib {
    using SolmateFixedPointMathLib for uint256;

    struct LibStorage {
        uint256 denominator;
    }

    function libStorage() internal pure returns (LibStorage storage ls) {
        bytes32 position = keccak256('diamond.standard.library.storage');
        assembly {
            ls.slot := position
        }
    }

    function setDenominator(uint256 denominator) internal {
        LibStorage storage ls = libStorage();
        ls.denominator = denominator;
    }

    function mul(uint256 x, uint256 y) internal view returns (uint256) {
        return x.mulDivDown(y, libStorage().denominator);
    }

    function div(uint256 x, uint256 y) internal view returns (uint256) {
        return x.mulDivDown(libStorage().denominator, y);
    }

    // TODO to be removed once denominator is set at SBI deployment
    function mul(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256) {
        return x.mulDivDown(y, denominator);
    }

    // TODO to be removed once denominator is set at SBI deployment
    function div(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256) {
        return x.mulDivDown(denominator, y);
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import './FixedPointMathLib.sol';

/**
 * @title TimeValue library
 * @author Atlendis Labs
 * @dev Contains the utilitaries methods associated to time computation in the Atlendis Protocol
 */
library TimeValue {
    using FixedPointMathLib for uint256;
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /**
     * @dev Compute the discount factor given a rate and a time delta with respect to the time at which the bonds have been emitted
     *      Exact computation is defined as 1 / (1 + rate)^deltaTime
     *      The approximation uses up to the first order of the Taylor series, i.e. 1 / (1 + deltaTime * rate)
     * @param rate Rate
     * @param timeDelta Time difference since the the time at which the bonds have been emitted
     * @param denominator The denominator value
     * @return discountFactor The discount factor
     */
    function getDiscountFactor(
        uint256 rate,
        uint256 timeDelta,
        uint256 denominator
    ) internal pure returns (uint256 discountFactor) {
        uint256 timeInYears = (timeDelta * denominator).div(SECONDS_PER_YEAR * denominator, denominator);
        /// TODO: #92 Higher order Taylor series
        return
            denominator.div(
                denominator + rate.mul(timeInYears, denominator), //+
                // (rate.mul(rate, denominator).mul(timeInYears.mul(timeInYears - 1, denominator), denominator)) /
                // 2 +
                // (rate.mul(rate, denominator).mul(rate, denominator)).mul(
                //     timeInYears.mul(timeInYears - 1, denominator).mul(timeInYears - 2, denominator),
                //     denominator
                // ) /
                // 6,
                denominator
            );
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import './../modules/interfaces/ISBIPool.sol';
import './../modules/interfaces/ISBIGovernance.sol';
import './../modules/interfaces/ISBIBorrowers.sol';
import './../modules/interfaces/ISBILenders.sol';

/**
 * @title ISingleBondIssuance
 * @author Atlendis Labs
 * @notice Interface of the Single Bond Issuance product
 *         The product allows permissionless deposit of tokens at a chosen rate in a pool.
 *         These funds can then be borrowed at the specified rate.
 *         The loan can be repaid by repaying the borrowed amound and the interests.
 *         A lender can withdraw its funds when it has not been borrowed or when repaid.
 *         This product allows for a single loan to be made.
 *         If the loan never happens, a cancellation fee if parametrized, is applied.
 *         The interface is defined as a union of its modules
 */
interface ISingleBondIssuance is ISBIPool, ISBIGovernance, ISBIBorrowers, ISBILenders {

}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

/**
 * @title PoolDataTypes library
 * @dev Defines the structs and enums related to the pool
 */
library PoolDataTypes {
    struct Tick {
        uint256 depositedAmount;
        uint256 borrowedAmount;
        uint256 repaidAmount;
    }

    enum PoolPhase {
        INACTIVE,
        BOOK_BUILDING,
        ISSUANCE,
        ISSUED,
        REPAID,
        PARTIAL_DEFAULT,
        DEFAULT,
        CANCELLED
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

/**
 * @title PoolDataTypes library
 * @dev Defines the structs related to the positions
 */
library PositionDataTypes {
    struct Position {
        uint256 depositedAmount;
        uint256 rate;
        uint256 depositBlockNumber;
        bool hasWithdrawPartially;
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import '../SingleBondIssuance.sol';
import '../../../custodian/PoolCustodian.sol';

/**
 * @title SingleBondIssuanceDeployer
 * @author Atlendis Labs
 * @notice Library created in order to isolate SingleBondIssuance deployment for contract size reason
 */
library SingleBondIssuanceDeployer {
    function deploy(
        address governance,
        PoolCustodian custodian,
        bytes memory feeConfigs,
        bytes memory parametersConfig,
        string memory name,
        string memory symbol
    ) external returns (address) {
        address instance = address(
            new SingleBondIssuance(governance, custodian, feeConfigs, parametersConfig, name, symbol)
        );
        return instance;
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import './PoolDataTypes.sol';

/**
 * @title SingleBondIssuanceErrors library
 * @dev Defines the errors used in the Single Bond Issuance product
 */
library SingleBondIssuanceErrors {
    error SBI_INVALID_RATE_BOUNDARIES(); // "Invalid rate boundaries parameters"
    error SBI_INVALID_ZERO_RATE_SPACING(); // "Can not have rate spacing to zero"
    error SBI_INVALID_RATE_PARAMETERS(); // "Invalid rate parameters"
    error SBI_INVALID_PERCENTAGE_VALUE(); // "Invalid percentage value"

    error SBI_OUT_OF_BOUND_MIN_RATE(); // "Input rate is below min rate"
    error SBI_OUT_OF_BOUND_MAX_RATE(); // "Input rate is above max rate"
    error SBI_INVALID_RATE_SPACING(); // "Input rate is invalid with respect to rate spacing"

    error SBI_INVALID_PHASE(PoolDataTypes.PoolPhase expectedPhase, PoolDataTypes.PoolPhase actualPhase); // "Phase is invalid for this operation"
    error SBI_ZERO_AMOUNT(); // "Cannot deposit zero amount";
    error SBI_MGMT_ONLY_OWNER(); // "Only the owner of the position token can manage it (update rate, withdraw)";
    error SBI_TIMELOCK(); // "Cannot withdraw or update rate in the same block as deposit";
    error SBI_BOOK_BUILDING_TIME_NOT_OVER(); // "Book building time window is not over";
    error SBI_ALLOWED_ONLY_BOOK_BUILDING_PHASE(); // "Action only allowed during the book building phase";
    error SBI_EARLY_REPAY_NOT_ALLOWED(); // "Bond is not callable";
    error SBI_EARLY_PARTIAL_REPAY_NOT_ALLOWED(); // "Partial repays are not allowed before maturity or during not allowed phases";
    error SBI_NOT_ENOUGH_FUNDS_AVAILABLE(); // "Not enough funds available in pool"
    error SBI_NO_WITHDRAWALS_ISSUANCE_PHASE(); // "No withdrawals during issuance phase"
    error SBI_WITHDRAW_AMOUNT_TOO_LARGE(); // "Partial withdraws are allowed for withdrawals of less hten 100% of a position"
    error SBI_PARTIAL_WITHDRAW_NOT_ALLOWED(); // "Partial withdraws are allowed during the book building phase"
    error SBI_WITHDRAWAL_NOT_ALLOWED(PoolDataTypes.PoolPhase poolPhase); // "Withdrawal not possible"
    error SBI_ZERO_BORROW_AMOUNT_NOT_ALLOWED(); // "Borrowing from an empty pool is not allowed"
    error SBI_ISSUANCE_PHASE_EXPIRED(); // "Issuance phase has expired"
    error SBI_ISSUANCE_PERIOD_STILL_ACTIVE(); // "Issuance period not expired yet"
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import '../../../libraries/FixedPointMathLib.sol';

import '../../../libraries/TimeValue.sol';
import './PoolDataTypes.sol';
import './SingleBondIssuanceErrors.sol';

/**
 * @title SingleBondIssuanceLogic library
 * @dev Collection of methods used in the SingleBondIssuance contract
 */
library SingleBondIssuanceLogic {
    using FixedPointMathLib for uint256;

    /**
     * @dev Deposit amount to tick
     * @param tick The tick
     * @param amount The amount
     */
    function depositToTick(PoolDataTypes.Tick storage tick, uint256 amount) external {
        tick.depositedAmount += amount;
    }

    /**
     * @dev Transfer an amount from one tick to another
     * @param currentTick Tick for which the deposited amount will decrease
     * @param newTick Tick for which the deposited amount will increase
     * @param amount The transferred amount
     */
    function updateTicksDeposit(
        PoolDataTypes.Tick storage currentTick,
        PoolDataTypes.Tick storage newTick,
        uint256 amount
    ) external {
        currentTick.depositedAmount -= amount;
        newTick.depositedAmount += amount;
    }

    /**
     * @dev Derive the allowed amount to be withdrawn
     *      The sequence of conditional branches is relevant for correct logic
     *      Decrease tick deposited amount if the contract is in the Book Building phase
     * @param tick The tick
     * @param issuancePhase The current issuance phase
     * @param depositedAmount The original deposited amount in the position
     * @param didPartiallyWithdraw True if the position has already been partially withdrawn
     * @param denominator The denominator value
     * @return amountToWithdraw The allowed amount to be withdrawn
     * @return partialWithdrawPartialFilledTick True if it is a partial withdraw
     */
    function withdrawFromTick(
        PoolDataTypes.Tick storage tick,
        PoolDataTypes.PoolPhase issuancePhase,
        uint256 depositedAmount,
        bool didPartiallyWithdraw,
        uint256 denominator
    ) external returns (uint256 amountToWithdraw, bool partialWithdrawPartialFilledTick) {
        /// @dev The order of conditional statements in this function is relevant to the correctness of the logic
        if (issuancePhase == PoolDataTypes.PoolPhase.BOOK_BUILDING) {
            amountToWithdraw = depositedAmount;
            tick.depositedAmount -= amountToWithdraw;
            return (amountToWithdraw, false);
        }

        // partial withdraw during borrow before repay
        if (
            !didPartiallyWithdraw &&
            tick.borrowedAmount > 0 &&
            tick.borrowedAmount < tick.depositedAmount &&
            (issuancePhase == PoolDataTypes.PoolPhase.ISSUED || issuancePhase == PoolDataTypes.PoolPhase.DEFAULT)
        ) {
            amountToWithdraw = depositedAmount.mul(tick.depositedAmount - tick.borrowedAmount, denominator).div(
                tick.depositedAmount,
                denominator
            );
            return (amountToWithdraw, true);
        }

        // if tick was not matched
        if (tick.borrowedAmount == 0 && issuancePhase != PoolDataTypes.PoolPhase.CANCELLED) {
            return (depositedAmount, false);
        }

        // If bond has been paid in full, partially or issuance was cancelled
        if (
            (tick.depositedAmount == tick.borrowedAmount && tick.repaidAmount > 0) ||
            issuancePhase == PoolDataTypes.PoolPhase.CANCELLED
        ) {
            amountToWithdraw = depositedAmount.mul(tick.repaidAmount, denominator).div(
                tick.depositedAmount,
                denominator
            );
            return (amountToWithdraw, false);
        }

        // If bond has been paid back partially or fully and the tick was partially filled
        if (tick.depositedAmount > tick.borrowedAmount && tick.repaidAmount != 0) {
            uint256 noneBorrowedAmountToWithdraw = didPartiallyWithdraw
                ? 0
                : depositedAmount.mul(tick.depositedAmount - tick.borrowedAmount, denominator).div(
                    tick.depositedAmount,
                    denominator
                );
            amountToWithdraw =
                depositedAmount.mul(tick.repaidAmount, denominator).div(tick.depositedAmount, denominator) +
                noneBorrowedAmountToWithdraw;
            return (amountToWithdraw, false);
        }

        revert SingleBondIssuanceErrors.SBI_WITHDRAWAL_NOT_ALLOWED(issuancePhase);
    }

    /**
     * @dev Register borrowed amount in tick and compute the value of emitted bonds at maturity
     * @param amountToBorrow The amount to borrow
     * @param tick The tick
     * @param rate The rate of the tick
     * @param maturity The maturity of the loan
     * @param denominator The denominator value
     * @return borrowComplete True if the deposited amount of the tick is larger than the amount to borrow
     * @return remainingAmount Remaining amount to borrow
     * @return deltaTheoreticalPoolNotional The value of emitted bonds at maturity
     */
    function borrowFromTick(
        uint256 amountToBorrow,
        PoolDataTypes.Tick storage tick,
        uint256 rate,
        uint256 maturity,
        uint256 denominator
    )
        external
        returns (
            bool borrowComplete,
            uint256 remainingAmount,
            uint256 deltaTheoreticalPoolNotional
        )
    {
        if (tick.depositedAmount == 0) return (false, amountToBorrow, 0);

        if (tick.depositedAmount < amountToBorrow) {
            amountToBorrow -= tick.depositedAmount;
            tick.borrowedAmount += tick.depositedAmount;
            deltaTheoreticalPoolNotional = tick.depositedAmount.div(
                TimeValue.getDiscountFactor(rate, maturity, denominator),
                denominator
            );
            return (false, amountToBorrow, deltaTheoreticalPoolNotional);
        }

        if (tick.depositedAmount >= amountToBorrow) {
            tick.borrowedAmount += amountToBorrow;
            deltaTheoreticalPoolNotional = amountToBorrow.div(
                TimeValue.getDiscountFactor(rate, maturity, denominator),
                denominator
            );
            return (true, 0, deltaTheoreticalPoolNotional);
        }
    }

    /**
     * @dev Register repaid amount in tick
     * @param tick The tick
     * @param rate The rate of the tick
     * @param borrowTimeStamp The borrow timestamp
     * @param timeDeltaIntoLateRepay Time since late repay threshold
     * @param timeDeltaStandardAccruals Time during which standard accrual is applied
     * @param lateRepaymentRate Late repayment rate
     * @param denominator The denominator value
     * @return amountToRepayForTick Amount to be repaid
     * @return yieldPayed Payed yield
     */
    function repayForTick(
        PoolDataTypes.Tick storage tick,
        uint256 rate,
        uint256 borrowTimeStamp,
        uint256 timeDeltaIntoLateRepay,
        uint256 timeDeltaStandardAccruals,
        uint256 lateRepaymentRate,
        uint256 denominator
    ) external returns (uint256 amountToRepayForTick, uint256 yieldPayed) {
        if (timeDeltaIntoLateRepay > 0) {
            amountToRepayForTick = tick
                .borrowedAmount
                .div(TimeValue.getDiscountFactor(rate, timeDeltaStandardAccruals, denominator), denominator)
                .div(TimeValue.getDiscountFactor(lateRepaymentRate, timeDeltaIntoLateRepay, denominator), denominator);
        } else {
            amountToRepayForTick = tick.borrowedAmount.div(
                TimeValue.getDiscountFactor(rate, block.timestamp - borrowTimeStamp, denominator),
                denominator
            );
        }

        yieldPayed = amountToRepayForTick - tick.borrowedAmount;
        tick.repaidAmount = amountToRepayForTick;
    }

    /**
     * @dev Register repaid amount in tick in the case of a partial repay
     * @param tick The tick
     * @param rate The rate of the tick
     * @param borrowTimeStamp The borrow timestamp
     * @param totalRepaidAmount Amount to be repaid
     * @param poolNotional The value of emitted bonds at maturity
     * @param denominator The denominator value
     */
    function partialRepayForTick(
        PoolDataTypes.Tick storage tick,
        uint256 rate,
        uint256 borrowTimeStamp,
        uint256 totalRepaidAmount,
        uint256 poolNotional,
        uint256 denominator
    ) external {
        uint256 amountToRepayForTick = tick.borrowedAmount.div(
            TimeValue.getDiscountFactor(rate, block.timestamp - borrowTimeStamp, denominator),
            denominator
        );
        tick.repaidAmount = amountToRepayForTick.div(poolNotional, denominator).mul(totalRepaidAmount, denominator);
    }

    /**
     * @dev Distributes escrowed cancellation fee to tick
     * @param tick The tick
     * @param cancellationFeeRate The cancelation fee rate
     * @param remainingEscrow The remaining amount in escrow
     * @param denominator The denominator value
     */
    function repayCancelFeeForTick(
        PoolDataTypes.Tick storage tick,
        uint256 cancellationFeeRate,
        uint256 remainingEscrow,
        uint256 denominator
    ) external returns (uint256 cancelFeeForTick) {
        if (cancellationFeeRate.mul(tick.depositedAmount, denominator) > remainingEscrow) {
            cancelFeeForTick = remainingEscrow;
        } else {
            cancelFeeForTick = cancellationFeeRate.mul(tick.depositedAmount, denominator);
        }
        tick.repaidAmount = tick.depositedAmount + cancelFeeForTick;
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

/**
 * @title ISBIBorrowers
 * @author Atlendis Labs
 * @notice Interface of the Single Bond Issuance Borrowers module contract
 *         It exposes the available methods for permissioned borrowers.
 */
interface ISBIBorrowers {
    /**
     * @notice Emitted when a borrow has been made
     *         The transferred amount is given by borrowedAmount + cancellationFeeEscrow - issuanceFee
     * @param borrower Address of the borrower
     * @param contractAddress Address of the contract
     * @param borrowedAmount Borrowed amount
     * @param issuanceFee Issuance fee
     * @param cancellationFeeEscrow Cancelation fee at borrow time
     */
    event Borrowed(
        address indexed borrower,
        address contractAddress,
        uint256 borrowedAmount,
        uint256 issuanceFee,
        uint256 cancellationFeeEscrow
    );

    /**
     * @notice Emitted when a loan has been partially repaid
     * @param borrower Address of the borrower
     * @param contractAddress Address of the contract
     * @param repaidAmount Repaid amount
     */
    event PartiallyRepaid(address indexed borrower, address contractAddress, uint256 repaidAmount);

    /**
     * @notice Emitted when a loan has been repaid
     *         Total paid amount by borrower is given by repaidAmount + atlendisFee
     * @param borrower Address of the borrower
     * @param contractAddress Address of the contract
     * @param repaidAmount Repaid amount
     * @param atlendisFee Repayment fee
     */
    event Repaid(address indexed borrower, address contractAddress, uint256 repaidAmount, uint256 atlendisFee);

    /**
     * @notice Emitted when the remaining cancellation fee has been withdrawn
     * @param contractAddress Address of the contract
     * @param amount Withdrawn remaining cancellation fee amount
     */
    event EscrowWithdrawn(address indexed contractAddress, uint256 amount);

    /**
     * @notice Retrieve the current maturity
     * @return maturity The current maturity
     */
    function getMaturity() external view returns (uint256 maturity);

    /**
     * Borrow up to a maximum of the parametrised target issuance amount
     * @param to Address to which the borrowed amount is transferred
     *
     * Emits a {Borrowed} event
     */
    function borrow(address to) external;

    /**
     * @notice Repay a loan
     *
     * Emits a {Repaid} event
     */
    function repay() external;

    /**
     * @notice Partially repay a loan
     * @param amount The repaid amount
     *
     * Emits a {PartiallyRepaid} event
     */
    function partialRepay(uint256 amount) external;

    /**
     * @notice Enable the book building phase by depositing in escrow the cancellation fee amount of tokens
     *
     * Emits a {BookBuildingPhaseEnabled} event
     */
    function enableBookBuildingPhase() external;

    /**
     * @notice Withdraw the remaining escrow
     * @param to Address to which the remaining escrow amount is transferred
     *
     * Emits a {EscrowWithdrawn} event
     */
    function withdrawRemainingEscrow(address to) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

/**
 * @title ISBIGovernance
 * @author Atlendis Labs
 * @notice Interface of the Single Bond Issuance Governance module contract
 *         It is in charge of the governance part of the contract
 *         In details:
 *           - manage borrowers,
 *           - enable issuance phase,
 *           - able to cancel bond issuance or default.
 *          Extended by the SingleBondIssuance product contract
 */
interface ISBIGovernance {
    /**
     * @notice Emitted when the issuance phase has started
     * @param contractAddress Address of the contract
     */
    event IssuancePhaseEnabled(address contractAddress);

    /**
     * @notice Cancel the bond issuance and consume the escrow in fees
     * @param contractAddress Address of the contract
     * @param remainingEscrow Remaining amount in escrow after fees distribution
     */
    event BondIssuanceCanceled(address contractAddress, uint256 remainingEscrow);

    /**
     * @notice Emitted when the default is declared
     * @param contractAddress Address of the contractpool has been marked as default
     */
    event Default(address contractAddress);

    /**
     * @notice Enable the issuance phase
     *
     * Emits a {IssuancePhaseEnabled} event
     */
    function enableIssuancePhase() external;

    /**
     * @notice Cancel the bond issuance
     *
     * Emits a {BondIssuanceCanceled} event
     */
    function cancelBondIssuance() external;

    /**
     * @notice Set the pool as defaulted
     *
     * Emits a {Default} event
     */
    function markPoolAsDefaulted() external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

/**
 * @title ISBILenders
 * @author Atlendis Labs
 * @notice Interface of the Single Bond Issuance Lenders module contract
 *         It exposes the available methods for the lenders
 */
interface ISBILenders {
    /**
     * @notice Emitted when a deposit has been made
     * @param positionId ID of the position associated to the deposit
     * @param owner Address of the position owner
     * @param contractAddress Address of the contract
     * @param rate Chosen rate at which the funds can be borrowed
     * @param amount Deposited amount
     */
    event Deposited(
        uint256 indexed positionId,
        address indexed owner,
        address contractAddress,
        uint256 rate,
        uint256 amount
    );

    /**
     * @notice Emitted when a rate has been updated
     * @param positionId ID of the position
     * @param owner Address of the position owner
     * @param contractAddress Address of the contract
     * @param oldRate Previous rate
     * @param newRate Updated rate
     */
    event RateUpdated(
        uint256 indexed positionId,
        address indexed owner,
        address contractAddress,
        uint256 oldRate,
        uint256 newRate
    );

    /**
     * @notice Emitted when a withdraw has been made
     * @param positionId ID of the position
     * @param owner Address of the position owner
     * @param contractAddress Address of the contract
     * @param amount Withdrawn amount
     */
    event Withdrawn(uint256 indexed positionId, address indexed owner, address contractAddress, uint256 amount);

    /**
     * @notice Emitted when a partial withdraw has been made
     * @param positionId ID of the position
     * @param owner Address of the position owner
     * @param contractAddress Address of the contract
     * @param amount Withdrawn amount
     */
    event PartiallyWithdrawn(
        uint256 indexed positionId,
        address indexed owner,
        address contractAddress,
        uint256 amount
    );

    /**
     * @notice Deposit amount of tokens at a chosen rate
     * @param rate Chosen rate at which the funds can be borrowed
     * @param amount Deposited amount of tokens
     * @param to Recipient address for the position associated to the deposit
     * @return positionId ID of the position
     *
     * Emits a {Deposited} event
     */
    function deposit(
        uint256 rate,
        uint256 amount,
        address to
    ) external returns (uint256 positionId);

    /**
     * @notice Update a position rate
     * @param positionId The ID of the position
     * @param newRate The new rate of the position
     *
     * Emits a {RateUpdated} event
     */
    function updateRate(uint256 positionId, uint256 newRate) external;

    /**
     * @notice Withdraw the maximum amount from a position
     * @param positionId ID of the position
     *
     * Emits a {Withdrawn} event
     */
    function withdraw(uint256 positionId) external;

    /**
     * @notice Withdraw any amount up to the full position deposited amount
     * @param positionId ID of the position
     * @param amount Amount to withdraw
     *
     * Emits a {PartiallyWithdrawn} event
     */
    function withdraw(uint256 positionId, uint256 amount) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

/**
 * @title ISBIPool
 * @author Atlendis Labs
 * @notice Interface of the Single Bond Issuance core Pool module contract
 *         It exposes the available methods for all the modules
 */
interface ISBIPool {
    /**
     * @notice Emitted when the book building phase has started
     * @param contractAddress Address of the contract
     */
    event BookBuildingPhaseEnabled(address contractAddress, uint256 cancellationFeeEscrow);

    /**
     * @notice Get the timestamp of the end of the book building phase
     * @return bookBuildingPhaseEndTimestamp The timestamp of the end of the book building phase
     */
    function getBookBuildingPhaseEndTimestamp() external view returns (uint256 bookBuildingPhaseEndTimestamp);

    /**
     * @notice Retrieve the loan duration
     * @return loanDuration The loan duration
     */
    function LOAN_DURATION() external view returns (uint256 loanDuration);

    /**
     * @notice Retrieve the book building period duration
     * @return bookBuildingPeriodDuration The book building period duration
     */
    function BOOK_BUILDING_PERIOD_DURATION() external view returns (uint256 bookBuildingPeriodDuration);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';

import '../../../libraries/FixedPointMathLib.sol';
import './../libraries/PoolDataTypes.sol';
import './../libraries/PositionDataTypes.sol';
import './../libraries/SingleBondIssuanceLogic.sol';
import './interfaces/ISBIBorrowers.sol';
import './SBIPool.sol';

/**
 * @title SBIBorrowers
 * @author Atlendis Labs
 * @notice Implementation of the ISBIBorrowers
 */
abstract contract SBIBorrowers is ISBIBorrowers, SBIPool {
    /*//////////////////////////////////////////////////////////////
                                LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public borrowTimestamp;
    uint256 public atlendisRevenue;
    uint256 public theoreticalPoolNotional;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Restrict the sender of the message to a borrower allowed address
     */
    modifier onlyBorrower() {
        require(permissionedBorrowers[msg.sender], 'Only permissioned borrower allowed');
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ISBIBorrowers
     */
    function getMaturity() external view returns (uint256 maturity) {
        if (poolPhase != PoolDataTypes.PoolPhase.ISSUED) return 0;
        return borrowTimestamp + LOAN_DURATION;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ISBIBorrowers
     */
    function borrow(address to) external onlyBorrower onlyInPhase(PoolDataTypes.PoolPhase.ISSUANCE) {
        if (block.timestamp > ISSUANCE_PHASE_START_TIMESTAMP + ISSUANCE_PERIOD_DURATION) {
            revert SingleBondIssuanceErrors.SBI_ISSUANCE_PHASE_EXPIRED();
        }
        uint256 borrowedAmount = deposits < TARGET_ISSUANCE_AMOUNT ? deposits : TARGET_ISSUANCE_AMOUNT;
        if (borrowedAmount == 0) {
            revert SingleBondIssuanceErrors.SBI_ZERO_BORROW_AMOUNT_NOT_ALLOWED();
        }
        poolPhase = PoolDataTypes.PoolPhase.ISSUED;
        uint256 issuanceFee = ISSUANCE_FEE_PC.mul(borrowedAmount, ONE);
        atlendisRevenue += issuanceFee;
        bool borrowComplete = false;
        uint256 currentInterestRate = MIN_RATE;
        uint256 deltaTheoreticalPoolNotional;
        uint256 remainingAmount = borrowedAmount;
        while (remainingAmount > 0 && currentInterestRate <= MAX_RATE && !borrowComplete) {
            if (ticks[currentInterestRate].depositedAmount > 0) {
                (borrowComplete, remainingAmount, deltaTheoreticalPoolNotional) = SingleBondIssuanceLogic
                    .borrowFromTick(
                        remainingAmount,
                        ticks[currentInterestRate],
                        currentInterestRate,
                        LOAN_DURATION,
                        ONE
                    );
                theoreticalPoolNotional += deltaTheoreticalPoolNotional;
            }
            currentInterestRate += RATE_SPACING;
        }
        if (remainingAmount > 0) {
            revert SingleBondIssuanceErrors.SBI_NOT_ENOUGH_FUNDS_AVAILABLE();
        }

        borrowTimestamp = block.timestamp;
        CUSTODIAN.withdraw(borrowedAmount - issuanceFee + cancellationFeeEscrow, to);

        emit Borrowed(msg.sender, address(this), borrowedAmount, issuanceFee, cancellationFeeEscrow);
    }

    /**
     * @inheritdoc ISBIBorrowers
     */
    function repay() external onlyBorrower onlyInPhase(PoolDataTypes.PoolPhase.ISSUED) {
        if (block.timestamp < borrowTimestamp + LOAN_DURATION) {
            revert SingleBondIssuanceErrors.SBI_EARLY_REPAY_NOT_ALLOWED();
        }
        uint256 lateRepaymentThreshold = borrowTimestamp + LOAN_DURATION + REPAYMENT_PERIOD_DURATION;
        uint256 timeDeltaIntoLateRepay = (block.timestamp > lateRepaymentThreshold)
            ? block.timestamp - lateRepaymentThreshold
            : 0;
        uint256 currentInterestRate = MIN_RATE;
        uint256 repaidAmount;
        uint256 interestToRepay;
        while (currentInterestRate <= MAX_RATE) {
            PoolDataTypes.Tick storage tick = ticks[currentInterestRate];
            if (tick.borrowedAmount > 0) {
                (uint256 amountToRepayForTick, uint256 interestRepayedForTick) = SingleBondIssuanceLogic.repayForTick(
                    tick,
                    currentInterestRate,
                    borrowTimestamp,
                    timeDeltaIntoLateRepay,
                    LOAN_DURATION + REPAYMENT_PERIOD_DURATION,
                    LATE_REPAYMENT_FEE_RATE,
                    ONE
                );
                interestToRepay += interestRepayedForTick;
                repaidAmount += amountToRepayForTick;
            }
            currentInterestRate += RATE_SPACING;
        }
        uint256 atlendisFee = interestToRepay.mul(REPAYMENT_FEE_PC, ONE);
        atlendisRevenue += atlendisFee;
        poolPhase = PoolDataTypes.PoolPhase.REPAID;

        CUSTODIAN.deposit(repaidAmount + atlendisFee, msg.sender);

        emit Repaid(msg.sender, address(this), repaidAmount, atlendisFee);
    }

    /**
     * @inheritdoc ISBIBorrowers
     */
    function partialRepay(uint256 amount) external onlyBorrower onlyInPhase(PoolDataTypes.PoolPhase.ISSUED) {
        if (block.timestamp < borrowTimestamp + LOAN_DURATION) {
            revert SingleBondIssuanceErrors.SBI_EARLY_PARTIAL_REPAY_NOT_ALLOWED();
        }
        uint256 currentInterestRate = MIN_RATE;
        while (currentInterestRate <= MAX_RATE) {
            PoolDataTypes.Tick storage tick = ticks[currentInterestRate];
            if (tick.borrowedAmount > 0) {
                SingleBondIssuanceLogic.partialRepayForTick(
                    tick,
                    currentInterestRate,
                    borrowTimestamp,
                    amount,
                    theoreticalPoolNotional,
                    ONE
                );
            }
            currentInterestRate += RATE_SPACING;
        }
        poolPhase = PoolDataTypes.PoolPhase.PARTIAL_DEFAULT;

        CUSTODIAN.deposit(amount, msg.sender);

        emit PartiallyRepaid(msg.sender, address(this), amount);
    }

    /**
     * @inheritdoc ISBIBorrowers
     */
    function enableBookBuildingPhase() external onlyBorrower onlyInPhase(PoolDataTypes.PoolPhase.INACTIVE) {
        cancellationFeeEscrow = CANCELLATION_FEE_PC.mul(TARGET_ISSUANCE_AMOUNT, ONE);

        CUSTODIAN.deposit(cancellationFeeEscrow, msg.sender);
        poolPhase = PoolDataTypes.PoolPhase.BOOK_BUILDING;

        emit BookBuildingPhaseEnabled(address(this), cancellationFeeEscrow);
    }

    /**
     * @inheritdoc ISBIBorrowers
     */
    function withdrawRemainingEscrow(address to) external onlyBorrower onlyInPhase(PoolDataTypes.PoolPhase.CANCELLED) {
        CUSTODIAN.withdraw(cancellationFeeEscrow, to);
        emit EscrowWithdrawn(address(this), cancellationFeeEscrow);
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import './../libraries/PoolDataTypes.sol';
import './../libraries/SingleBondIssuanceErrors.sol';
import './../libraries/SingleBondIssuanceLogic.sol';
import './interfaces/ISBIGovernance.sol';
import './SBIPool.sol';
import 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';

/**
 * @title SBIGovernance
 * @author Atlendis Labs
 * @notice Implementation of the ISBIGovernance
 *         Governance module of the SBI product
 */
abstract contract SBIGovernance is ISBIGovernance, SBIPool, Ownable {
    /**
     * @dev Constructor - register creation timestamp and grant the default admin role to the governance address
     * @param governance Address of the governance
     */
    constructor(address governance) {
        _transferOwnership(governance);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ISBIGovernance
     */
    function enableIssuancePhase() external onlyOwner onlyInPhase(PoolDataTypes.PoolPhase.BOOK_BUILDING) {
        if (block.timestamp <= CREATION_TIMESTAMP + BOOK_BUILDING_PERIOD_DURATION) {
            revert SingleBondIssuanceErrors.SBI_BOOK_BUILDING_TIME_NOT_OVER();
        }
        poolPhase = PoolDataTypes.PoolPhase.ISSUANCE;
        ISSUANCE_PHASE_START_TIMESTAMP = block.timestamp;
        emit IssuancePhaseEnabled(address(this));
    }

    /**
     * @inheritdoc ISBIGovernance
     */
    function markPoolAsDefaulted() external onlyOwner onlyInPhase(PoolDataTypes.PoolPhase.ISSUED) {
        poolPhase = PoolDataTypes.PoolPhase.DEFAULT;
        emit Default(address(this));
    }

    // TODO: #251
    function allowBorrower(address borrower) external onlyOwner {
        permissionedBorrowers[borrower] = true;
    }

    /**
     * @inheritdoc ISBIGovernance
     */
    function cancelBondIssuance() external onlyOwner onlyInPhase(PoolDataTypes.PoolPhase.ISSUANCE) {
        if (block.timestamp < ISSUANCE_PHASE_START_TIMESTAMP + ISSUANCE_PERIOD_DURATION) {
            revert SingleBondIssuanceErrors.SBI_ISSUANCE_PERIOD_STILL_ACTIVE();
        }
        uint256 remainingEscrow = cancellationFeeEscrow;
        for (
            uint256 currentInterestRate = MIN_RATE;
            currentInterestRate <= MAX_RATE;
            currentInterestRate += RATE_SPACING
        ) {
            PoolDataTypes.Tick storage tick = ticks[currentInterestRate];
            uint256 cancelFeeForTick = SingleBondIssuanceLogic.repayCancelFeeForTick(
                tick,
                CANCELLATION_FEE_PC,
                remainingEscrow,
                ONE
            );
            remainingEscrow -= cancelFeeForTick;
        }
        cancellationFeeEscrow = remainingEscrow;
        poolPhase = PoolDataTypes.PoolPhase.CANCELLED;

        emit BondIssuanceCanceled(address(this), remainingEscrow);
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import './../libraries/PoolDataTypes.sol';
import './../libraries/PositionDataTypes.sol';
import './../libraries/SingleBondIssuanceLogic.sol';
import './interfaces/ISBILenders.sol';
import './SBIPool.sol';

/**
 * @title SBILenders
 * @author Atlendis Labs
 * @notice Implementation of the ISBILenders
 *         Lenders module of the SBI product
 *         Positions are created according to associated ERC721 token
 */
abstract contract SBILenders is ISBILenders, SBIPool, ERC721 {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    // position ID -> Position details
    mapping(uint256 => PositionDataTypes.Position) public positions;
    uint256 public nextPositionId;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Constructor - Transit to `book building` phase if no cancellation fee are needed
     * @param name ERC721 name of the positions
     * @param symbol ERC721 symbol of the positions
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ISBILenders
     */
    function deposit(
        uint256 rate,
        uint256 amount,
        address to
    ) external returns (uint256 positionId) {
        if (
            poolPhase != PoolDataTypes.PoolPhase.BOOK_BUILDING ||
            block.timestamp > CREATION_TIMESTAMP + BOOK_BUILDING_PERIOD_DURATION
        ) {
            revert SingleBondIssuanceErrors.SBI_ALLOWED_ONLY_BOOK_BUILDING_PHASE();
        }

        if (amount == 0) revert SingleBondIssuanceErrors.SBI_ZERO_AMOUNT();

        validateRate(rate);

        CUSTODIAN.deposit(amount, msg.sender);
        SingleBondIssuanceLogic.depositToTick(ticks[rate], amount);
        positionId = nextPositionId++;
        deposits += amount;
        _safeMint(to, positionId);
        positions[positionId] = PositionDataTypes.Position({
            depositedAmount: amount,
            rate: rate,
            depositBlockNumber: block.number,
            hasWithdrawPartially: false
        });
        emit Deposited(positionId, to, address(this), rate, amount);
    }

    /**
     * @inheritdoc ISBILenders
     */
    function updateRate(uint256 positionId, uint256 newRate) external {
        if (
            poolPhase != PoolDataTypes.PoolPhase.BOOK_BUILDING ||
            block.timestamp > CREATION_TIMESTAMP + BOOK_BUILDING_PERIOD_DURATION
        ) {
            revert SingleBondIssuanceErrors.SBI_ALLOWED_ONLY_BOOK_BUILDING_PHASE();
        }

        if (ownerOf(positionId) != msg.sender) {
            revert SingleBondIssuanceErrors.SBI_MGMT_ONLY_OWNER();
        }

        validateRate(newRate);

        uint256 oldRate = positions[positionId].rate;

        SingleBondIssuanceLogic.updateTicksDeposit(
            ticks[oldRate],
            ticks[newRate],
            positions[positionId].depositedAmount
        );
        positions[positionId].rate = newRate;
        emit RateUpdated(positionId, msg.sender, address(this), oldRate, newRate);
    }

    /**
     * @inheritdoc ISBILenders
     */
    function withdraw(uint256 positionId) external {
        if (ownerOf(positionId) != msg.sender) {
            revert SingleBondIssuanceErrors.SBI_MGMT_ONLY_OWNER();
        }

        if (positions[positionId].depositBlockNumber == block.number) {
            revert SingleBondIssuanceErrors.SBI_TIMELOCK();
        }

        if (poolPhase == PoolDataTypes.PoolPhase.ISSUANCE) {
            revert SingleBondIssuanceErrors.SBI_NO_WITHDRAWALS_ISSUANCE_PHASE();
        }

        (uint256 withdrawnAmount, bool partialWithdrawPartialFilledTick) = SingleBondIssuanceLogic.withdrawFromTick(
            ticks[positions[positionId].rate],
            poolPhase,
            positions[positionId].depositedAmount,
            positions[positionId].hasWithdrawPartially,
            ONE
        );

        if (poolPhase == PoolDataTypes.PoolPhase.BOOK_BUILDING) {
            deposits -= withdrawnAmount;
        }

        if (partialWithdrawPartialFilledTick) {
            positions[positionId].hasWithdrawPartially = true;
        } else {
            _burn(positionId);
            delete positions[positionId];
        }

        CUSTODIAN.withdraw(withdrawnAmount, msg.sender);

        emit Withdrawn(positionId, msg.sender, address(this), withdrawnAmount);
    }

    /**
     * @inheritdoc ISBILenders
     */
    function withdraw(uint256 positionId, uint256 amount) external {
        if (ownerOf(positionId) != msg.sender) {
            revert SingleBondIssuanceErrors.SBI_MGMT_ONLY_OWNER();
        }

        if (positions[positionId].depositBlockNumber == block.number) {
            revert SingleBondIssuanceErrors.SBI_TIMELOCK();
        }

        if (poolPhase != PoolDataTypes.PoolPhase.BOOK_BUILDING) {
            revert SingleBondIssuanceErrors.SBI_PARTIAL_WITHDRAW_NOT_ALLOWED();
        }

        if (amount > positions[positionId].depositedAmount) {
            revert SingleBondIssuanceErrors.SBI_WITHDRAW_AMOUNT_TOO_LARGE();
        }
        ticks[positions[positionId].rate].depositedAmount -= amount;
        if (positions[positionId].depositedAmount == amount) {
            _burn(positionId);
            delete positions[positionId];
        } else {
            positions[positionId].depositedAmount -= amount;
        }
        deposits -= amount;

        CUSTODIAN.withdraw(amount, msg.sender);

        emit PartiallyWithdrawn(positionId, msg.sender, address(this), amount);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function validateRate(uint256 newRate) private view {
        if (newRate < MIN_RATE) {
            revert SingleBondIssuanceErrors.SBI_OUT_OF_BOUND_MIN_RATE();
        }
        if (newRate > MAX_RATE) {
            revert SingleBondIssuanceErrors.SBI_OUT_OF_BOUND_MAX_RATE();
        }
        if ((newRate - MIN_RATE) % RATE_SPACING != 0) {
            revert SingleBondIssuanceErrors.SBI_INVALID_RATE_SPACING();
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import './../libraries/PoolDataTypes.sol';
import './../libraries/SingleBondIssuanceErrors.sol';
import '../../../interfaces/IPoolCustodian.sol';
import './interfaces/ISBIPool.sol';

/**
 * @title SBIPool
 * @author Atlendis Labs
 * @notice Implementation of the ISBIPool
 *         Contains the core storage of the pool and shared methods accross the modules
 */
abstract contract SBIPool is ISBIPool {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    IPoolCustodian public immutable CUSTODIAN;

    uint256 public immutable CREATION_TIMESTAMP;
    uint256 public ISSUANCE_PHASE_START_TIMESTAMP;

    uint256 public immutable ONE;
    uint256 public immutable MIN_RATE;
    uint256 public immutable MAX_RATE;
    uint256 public immutable RATE_SPACING;
    uint256 public immutable LOAN_DURATION;
    uint256 public immutable TARGET_ISSUANCE_AMOUNT;
    uint256 public immutable BOOK_BUILDING_PERIOD_DURATION;
    uint256 public immutable ISSUANCE_PERIOD_DURATION;
    uint256 public immutable REPAYMENT_PERIOD_DURATION;
    uint256 public immutable ISSUANCE_FEE_PC; // value for the percentage of the borrowed amount which is taken as a fee at borrow time
    uint256 public immutable REPAYMENT_FEE_PC; // value for the percentage of the interests amount which is taken as a fee at repay time
    uint256 public immutable LATE_REPAYMENT_FEE_RATE;
    uint256 public immutable CANCELLATION_FEE_PC; // value for the percentage of the target issuance amount which is needed in escrow in order to enable the book building phase

    PoolDataTypes.PoolPhase public poolPhase;
    // rate -> Tick
    mapping(uint256 => PoolDataTypes.Tick) public ticks;
    // address -> is borrower
    mapping(address => bool) public permissionedBorrowers;

    uint256 public deposits;

    uint256 public cancellationFeeEscrow;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Constructor
     * @param custodian Address of the custodian contract
     * @param feeConfigs Configurations of fees
     * @param parametersConfig Other Configurations
     */
    constructor(
        IPoolCustodian custodian,
        bytes memory feeConfigs,
        bytes memory parametersConfig
    ) {
        (LATE_REPAYMENT_FEE_RATE, ISSUANCE_FEE_PC, REPAYMENT_FEE_PC, CANCELLATION_FEE_PC) = abi.decode(
            feeConfigs,
            (uint256, uint256, uint256, uint256)
        );

        (
            MIN_RATE,
            MAX_RATE,
            RATE_SPACING,
            LOAN_DURATION,
            REPAYMENT_PERIOD_DURATION,
            ISSUANCE_PERIOD_DURATION,
            BOOK_BUILDING_PERIOD_DURATION,
            TARGET_ISSUANCE_AMOUNT
        ) = abi.decode(parametersConfig, (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256));

        ONE = 10**custodian.getAssetDecimals();

        if (MIN_RATE >= MAX_RATE) revert SingleBondIssuanceErrors.SBI_INVALID_RATE_BOUNDARIES();
        if (RATE_SPACING == 0) revert SingleBondIssuanceErrors.SBI_INVALID_ZERO_RATE_SPACING();
        if ((MAX_RATE - MIN_RATE) % RATE_SPACING != 0) revert SingleBondIssuanceErrors.SBI_INVALID_RATE_PARAMETERS();
        if (ISSUANCE_FEE_PC >= ONE || REPAYMENT_FEE_PC >= ONE || CANCELLATION_FEE_PC >= ONE)
            revert SingleBondIssuanceErrors.SBI_INVALID_PERCENTAGE_VALUE();

        if (CANCELLATION_FEE_PC > 0) {
            poolPhase = PoolDataTypes.PoolPhase.INACTIVE;
        } else {
            poolPhase = PoolDataTypes.PoolPhase.BOOK_BUILDING;
            emit BookBuildingPhaseEnabled(address(this), 0);
        }
        CREATION_TIMESTAMP = block.timestamp;

        CUSTODIAN = custodian;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Allow only if the pool phase is the expected one
     * @param expectedPhase Expected phase
     */
    modifier onlyInPhase(PoolDataTypes.PoolPhase expectedPhase) {
        if (poolPhase != expectedPhase) revert SingleBondIssuanceErrors.SBI_INVALID_PHASE(expectedPhase, poolPhase);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ISBIPool
     */
    function getBookBuildingPhaseEndTimestamp() external view returns (uint256 bookBuildingPhaseEndTimestamp) {
        return CREATION_TIMESTAMP + BOOK_BUILDING_PERIOD_DURATION;
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import 'lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';

import '../../interfaces/IPositionManager.sol';
import './libraries/PoolDataTypes.sol';
import './libraries/PositionDataTypes.sol';
import './interfaces/ISingleBondIssuance.sol';
import './modules/SBIGovernance.sol';
import './modules/SBIPool.sol';
import './modules/SBILenders.sol';
import './modules/SBIBorrowers.sol';

/**
 * @title SingleBondIssuance
 * @author Atlendis Labs
 * @notice Implementation of the ISingleBondIssuance
 */
contract SingleBondIssuance is SBIPool, SBIGovernance, SBIBorrowers, SBILenders {
    /*//////////////////////////////////////////////////////////////
                                LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Constructor - pass parameters to modules
     * @param governance Address of the governance
     * @param custodian Address of the custodian
     * @param feeConfigs Fees-specific configurations
     * @param parametersConfig Parameters-specific configurations
     * @param name ERC721 name of the positions
     * @param symbol ERC721 symbol of the positions
     */
    constructor(
        address governance,
        IPoolCustodian custodian,
        bytes memory feeConfigs,
        bytes memory parametersConfig,
        string memory name,
        string memory symbol
    ) SBILenders(name, symbol) SBIGovernance(governance) SBIPool(custodian, feeConfigs, parametersConfig) {}

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPositionComposition(uint256 positionId)
        public
        view
        returns (
            uint256 depositedAmount,
            uint256 borrowedAmount,
            uint256 theoreticalBondValue,
            uint256 noneBorrowedAvailableAmount
        )
    {
        PositionDataTypes.Position memory position = positions[positionId];
        PoolDataTypes.Tick storage tick = ticks[position.rate];

        if (tick.borrowedAmount == 0) {
            return (position.depositedAmount, 0, 0, position.depositedAmount);
        }

        if (tick.depositedAmount == tick.borrowedAmount) {
            return (
                position.depositedAmount,
                position.depositedAmount,
                position.depositedAmount.mul(TimeValue.getDiscountFactor(position.rate, LOAN_DURATION, ONE), ONE),
                0
            );
        }

        if (tick.depositedAmount > tick.borrowedAmount) {
            uint256 noneFilledDeposit = position.depositedAmount.div(tick.depositedAmount, ONE).mul(
                tick.depositedAmount - tick.borrowedAmount,
                ONE
            );
            return (
                position.depositedAmount,
                position.depositedAmount - noneFilledDeposit,
                position.depositedAmount.div(tick.depositedAmount, ONE).mul(
                    tick.borrowedAmount.div(TimeValue.getDiscountFactor(position.rate, LOAN_DURATION, ONE), ONE),
                    ONE
                ),
                position.hasWithdrawPartially ? 0 : noneFilledDeposit
            );
        }
    }

    function getPosition(uint256 positionId)
        public
        view
        returns (
            address owner,
            uint256 rate,
            uint256 depositedAmount,
            PositionStatus status
        )
    {
        PositionDataTypes.Position memory position = positions[positionId];
        PoolDataTypes.Tick storage tick = ticks[position.rate];

        address positionOwner = ownerOf(positionId);

        if (poolPhase == PoolDataTypes.PoolPhase.BOOK_BUILDING) {
            return (positionOwner, position.rate, position.depositedAmount, PositionStatus.AVAILABLE);
        }

        if (poolPhase == PoolDataTypes.PoolPhase.ISSUED) {
            if (tick.borrowedAmount == 0) {
                return (positionOwner, position.rate, position.depositedAmount, PositionStatus.UNAVAILABLE);
            }

            return (positionOwner, position.rate, position.depositedAmount, PositionStatus.BORROWED);
        }

        return (positionOwner, position.rate, position.depositedAmount, PositionStatus.UNAVAILABLE);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISingleBondIssuance).interfaceId || super.supportsInterface(interfaceId);
    }
}