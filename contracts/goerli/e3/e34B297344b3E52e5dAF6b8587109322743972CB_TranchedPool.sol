pragma solidity ^0.6.0;
import "../Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract ContextUpgradeSafe is Initializable {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.

    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {


    }


    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }

    uint256[50] private __gap;
}

pragma solidity >=0.4.24 <0.7.0;


/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }

    _;

    if (isTopLevelCall) {
      initializing = false;
    }
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    address self = address(this);
    uint256 cs;
    assembly { cs := extcodesize(self) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

pragma solidity ^0.6.0;

import "../utils/EnumerableSet.sol";
import "../utils/Address.sol";
import "../GSN/Context.sol";
import "../Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms.
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
 *     require(hasRole(MY_ROLE, _msgSender()));
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
 */
abstract contract AccessControlUpgradeSafe is Initializable, ContextUpgradeSafe {
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {


    }

    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    struct RoleData {
        EnumerableSet.AddressSet members;
        bytes32 adminRole;
    }

    mapping (bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {_setupRole}.
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
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members.contains(account);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roles[role].members.length();
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view returns (address) {
        return _roles[role].members.at(index);
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
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
    function grantRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to grant");

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
    function revokeRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to revoke");

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
    function renounceRole(bytes32 role, address account) public virtual {
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
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (_roles[role].members.add(account)) {
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (_roles[role].members.remove(account)) {
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    uint256[49] private __gap;
}

pragma solidity ^0.6.0;

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
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

pragma solidity ^0.6.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

pragma solidity ^0.6.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int256 constant private _INT256_MIN = -2**255;

    /**
     * @dev Multiplies two signed integers, reverts on overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Integer division of two signed integers truncating the quotient, reverts on division by zero.
     */
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Subtracts two signed integers, reverts on overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Adds two signed integers, reverts on overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}

pragma solidity ^0.6.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity ^0.6.2;

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
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

pragma solidity ^0.6.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.0.0, only sets of type `address` (`AddressSet`) and `uint256`
 * (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint256(_at(set._inner, index)));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

pragma solidity ^0.6.0;

import "../GSN/Context.sol";
import "../Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
contract PausableUpgradeSafe is Initializable, ContextUpgradeSafe {
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
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    uint256[49] private __gap;
}

pragma solidity ^0.6.0;
import "../Initializable.sol";

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
contract ReentrancyGuardUpgradeSafe is Initializable {
    bool private _notEntered;


    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {


        // Storing an initial non-zero value makes deployment a bit more
        // expensive, but in exchange the refund on every call to nonReentrant
        // will be lower in amount. Since refunds are capped to a percetange of
        // the total transaction's gas, it is best to keep them low in cases
        // like this one, to increase the likelihood of the full refund coming
        // into effect.
        _notEntered = true;

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
        require(_notEntered, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _notEntered = false;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _notEntered = true;
    }

    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
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
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for `permit`, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

// SPDX-License-Identifier: AGPL-3.0-only
// solhint-disable
// Imported from https://github.com/UMAprotocol/protocol/blob/4d1c8cc47a4df5e79f978cb05647a7432e111a3d/packages/core/contracts/common/implementation/FixedPoint.sol
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SignedSafeMath.sol";

/**
 * @title Library for fixed point arithmetic on uints
 */
library FixedPoint {
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  // Supports 18 decimals. E.g., 1e18 represents "1", 5e17 represents "0.5".
  // For unsigned values:
  //   This can represent a value up to (2^256 - 1)/10^18 = ~10^59. 10^59 will be stored internally as uint256 10^77.
  uint256 private constant FP_SCALING_FACTOR = 10 ** 18;

  // --------------------------------------- UNSIGNED -----------------------------------------------------------------------------
  struct Unsigned {
    uint256 rawValue;
  }

  /**
   * @notice Constructs an `Unsigned` from an unscaled uint, e.g., `b=5` gets stored internally as `5**18`.
   * @param a uint to convert into a FixedPoint.
   * @return the converted FixedPoint.
   */
  function fromUnscaledUint(uint256 a) internal pure returns (Unsigned memory) {
    return Unsigned(a.mul(FP_SCALING_FACTOR));
  }

  /**
   * @notice Whether `a` is equal to `b`.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return True if equal, or False.
   */
  function isEqual(Unsigned memory a, uint256 b) internal pure returns (bool) {
    return a.rawValue == fromUnscaledUint(b).rawValue;
  }

  /**
   * @notice Whether `a` is equal to `b`.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return True if equal, or False.
   */
  function isEqual(Unsigned memory a, Unsigned memory b) internal pure returns (bool) {
    return a.rawValue == b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than `b`.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return True if `a > b`, or False.
   */
  function isGreaterThan(Unsigned memory a, Unsigned memory b) internal pure returns (bool) {
    return a.rawValue > b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than `b`.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return True if `a > b`, or False.
   */
  function isGreaterThan(Unsigned memory a, uint256 b) internal pure returns (bool) {
    return a.rawValue > fromUnscaledUint(b).rawValue;
  }

  /**
   * @notice Whether `a` is greater than `b`.
   * @param a a uint256.
   * @param b a FixedPoint.
   * @return True if `a > b`, or False.
   */
  function isGreaterThan(uint256 a, Unsigned memory b) internal pure returns (bool) {
    return fromUnscaledUint(a).rawValue > b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than or equal to `b`.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return True if `a >= b`, or False.
   */
  function isGreaterThanOrEqual(Unsigned memory a, Unsigned memory b) internal pure returns (bool) {
    return a.rawValue >= b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than or equal to `b`.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return True if `a >= b`, or False.
   */
  function isGreaterThanOrEqual(Unsigned memory a, uint256 b) internal pure returns (bool) {
    return a.rawValue >= fromUnscaledUint(b).rawValue;
  }

  /**
   * @notice Whether `a` is greater than or equal to `b`.
   * @param a a uint256.
   * @param b a FixedPoint.
   * @return True if `a >= b`, or False.
   */
  function isGreaterThanOrEqual(uint256 a, Unsigned memory b) internal pure returns (bool) {
    return fromUnscaledUint(a).rawValue >= b.rawValue;
  }

  /**
   * @notice Whether `a` is less than `b`.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return True if `a < b`, or False.
   */
  function isLessThan(Unsigned memory a, Unsigned memory b) internal pure returns (bool) {
    return a.rawValue < b.rawValue;
  }

  /**
   * @notice Whether `a` is less than `b`.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return True if `a < b`, or False.
   */
  function isLessThan(Unsigned memory a, uint256 b) internal pure returns (bool) {
    return a.rawValue < fromUnscaledUint(b).rawValue;
  }

  /**
   * @notice Whether `a` is less than `b`.
   * @param a a uint256.
   * @param b a FixedPoint.
   * @return True if `a < b`, or False.
   */
  function isLessThan(uint256 a, Unsigned memory b) internal pure returns (bool) {
    return fromUnscaledUint(a).rawValue < b.rawValue;
  }

  /**
   * @notice Whether `a` is less than or equal to `b`.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return True if `a <= b`, or False.
   */
  function isLessThanOrEqual(Unsigned memory a, Unsigned memory b) internal pure returns (bool) {
    return a.rawValue <= b.rawValue;
  }

  /**
   * @notice Whether `a` is less than or equal to `b`.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return True if `a <= b`, or False.
   */
  function isLessThanOrEqual(Unsigned memory a, uint256 b) internal pure returns (bool) {
    return a.rawValue <= fromUnscaledUint(b).rawValue;
  }

  /**
   * @notice Whether `a` is less than or equal to `b`.
   * @param a a uint256.
   * @param b a FixedPoint.
   * @return True if `a <= b`, or False.
   */
  function isLessThanOrEqual(uint256 a, Unsigned memory b) internal pure returns (bool) {
    return fromUnscaledUint(a).rawValue <= b.rawValue;
  }

  /**
   * @notice The minimum of `a` and `b`.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return the minimum of `a` and `b`.
   */
  function min(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    return a.rawValue < b.rawValue ? a : b;
  }

  /**
   * @notice The maximum of `a` and `b`.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return the maximum of `a` and `b`.
   */
  function max(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    return a.rawValue > b.rawValue ? a : b;
  }

  /**
   * @notice Adds two `Unsigned`s, reverting on overflow.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return the sum of `a` and `b`.
   */
  function add(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    return Unsigned(a.rawValue.add(b.rawValue));
  }

  /**
   * @notice Adds an `Unsigned` to an unscaled uint, reverting on overflow.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return the sum of `a` and `b`.
   */
  function add(Unsigned memory a, uint256 b) internal pure returns (Unsigned memory) {
    return add(a, fromUnscaledUint(b));
  }

  /**
   * @notice Subtracts two `Unsigned`s, reverting on overflow.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return the difference of `a` and `b`.
   */
  function sub(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    return Unsigned(a.rawValue.sub(b.rawValue));
  }

  /**
   * @notice Subtracts an unscaled uint256 from an `Unsigned`, reverting on overflow.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return the difference of `a` and `b`.
   */
  function sub(Unsigned memory a, uint256 b) internal pure returns (Unsigned memory) {
    return sub(a, fromUnscaledUint(b));
  }

  /**
   * @notice Subtracts an `Unsigned` from an unscaled uint256, reverting on overflow.
   * @param a a uint256.
   * @param b a FixedPoint.
   * @return the difference of `a` and `b`.
   */
  function sub(uint256 a, Unsigned memory b) internal pure returns (Unsigned memory) {
    return sub(fromUnscaledUint(a), b);
  }

  /**
   * @notice Multiplies two `Unsigned`s, reverting on overflow.
   * @dev This will "floor" the product.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return the product of `a` and `b`.
   */
  function mul(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    // There are two caveats with this computation:
    // 1. Max output for the represented number is ~10^41, otherwise an intermediate value overflows. 10^41 is
    // stored internally as a uint256 ~10^59.
    // 2. Results that can't be represented exactly are truncated not rounded. E.g., 1.4 * 2e-18 = 2.8e-18, which
    // would round to 3, but this computation produces the result 2.
    // No need to use SafeMath because FP_SCALING_FACTOR != 0.
    return Unsigned(a.rawValue.mul(b.rawValue) / FP_SCALING_FACTOR);
  }

  /**
   * @notice Multiplies an `Unsigned` and an unscaled uint256, reverting on overflow.
   * @dev This will "floor" the product.
   * @param a a FixedPoint.
   * @param b a uint256.
   * @return the product of `a` and `b`.
   */
  function mul(Unsigned memory a, uint256 b) internal pure returns (Unsigned memory) {
    return Unsigned(a.rawValue.mul(b));
  }

  /**
   * @notice Multiplies two `Unsigned`s and "ceil's" the product, reverting on overflow.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return the product of `a` and `b`.
   */
  function mulCeil(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    uint256 mulRaw = a.rawValue.mul(b.rawValue);
    uint256 mulFloor = mulRaw / FP_SCALING_FACTOR;
    uint256 mod = mulRaw.mod(FP_SCALING_FACTOR);
    if (mod != 0) {
      return Unsigned(mulFloor.add(1));
    } else {
      return Unsigned(mulFloor);
    }
  }

  /**
   * @notice Multiplies an `Unsigned` and an unscaled uint256 and "ceil's" the product, reverting on overflow.
   * @param a a FixedPoint.
   * @param b a FixedPoint.
   * @return the product of `a` and `b`.
   */
  function mulCeil(Unsigned memory a, uint256 b) internal pure returns (Unsigned memory) {
    // Since b is an int, there is no risk of truncation and we can just mul it normally
    return Unsigned(a.rawValue.mul(b));
  }

  /**
   * @notice Divides one `Unsigned` by an `Unsigned`, reverting on overflow or division by 0.
   * @dev This will "floor" the quotient.
   * @param a a FixedPoint numerator.
   * @param b a FixedPoint denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function div(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    // There are two caveats with this computation:
    // 1. Max value for the number dividend `a` represents is ~10^41, otherwise an intermediate value overflows.
    // 10^41 is stored internally as a uint256 10^59.
    // 2. Results that can't be represented exactly are truncated not rounded. E.g., 2 / 3 = 0.6 repeating, which
    // would round to 0.666666666666666667, but this computation produces the result 0.666666666666666666.
    return Unsigned(a.rawValue.mul(FP_SCALING_FACTOR).div(b.rawValue));
  }

  /**
   * @notice Divides one `Unsigned` by an unscaled uint256, reverting on overflow or division by 0.
   * @dev This will "floor" the quotient.
   * @param a a FixedPoint numerator.
   * @param b a uint256 denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function div(Unsigned memory a, uint256 b) internal pure returns (Unsigned memory) {
    return Unsigned(a.rawValue.div(b));
  }

  /**
   * @notice Divides one unscaled uint256 by an `Unsigned`, reverting on overflow or division by 0.
   * @dev This will "floor" the quotient.
   * @param a a uint256 numerator.
   * @param b a FixedPoint denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function div(uint256 a, Unsigned memory b) internal pure returns (Unsigned memory) {
    return div(fromUnscaledUint(a), b);
  }

  /**
   * @notice Divides one `Unsigned` by an `Unsigned` and "ceil's" the quotient, reverting on overflow or division by 0.
   * @param a a FixedPoint numerator.
   * @param b a FixedPoint denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function divCeil(Unsigned memory a, Unsigned memory b) internal pure returns (Unsigned memory) {
    uint256 aScaled = a.rawValue.mul(FP_SCALING_FACTOR);
    uint256 divFloor = aScaled.div(b.rawValue);
    uint256 mod = aScaled.mod(b.rawValue);
    if (mod != 0) {
      return Unsigned(divFloor.add(1));
    } else {
      return Unsigned(divFloor);
    }
  }

  /**
   * @notice Divides one `Unsigned` by an unscaled uint256 and "ceil's" the quotient, reverting on overflow or division by 0.
   * @param a a FixedPoint numerator.
   * @param b a uint256 denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function divCeil(Unsigned memory a, uint256 b) internal pure returns (Unsigned memory) {
    // Because it is possible that a quotient gets truncated, we can't just call "Unsigned(a.rawValue.div(b))"
    // similarly to mulCeil with a uint256 as the second parameter. Therefore we need to convert b into an Unsigned.
    // This creates the possibility of overflow if b is very large.
    return divCeil(a, fromUnscaledUint(b));
  }

  /**
   * @notice Raises an `Unsigned` to the power of an unscaled uint256, reverting on overflow. E.g., `b=2` squares `a`.
   * @dev This will "floor" the result.
   * @param a a FixedPoint numerator.
   * @param b a uint256 denominator.
   * @return output is `a` to the power of `b`.
   */
  function pow(Unsigned memory a, uint256 b) internal pure returns (Unsigned memory output) {
    output = fromUnscaledUint(1);
    for (uint256 i = 0; i < b; i = i.add(1)) {
      output = mul(output, a);
    }
  }

  // ------------------------------------------------- SIGNED -------------------------------------------------------------
  // Supports 18 decimals. E.g., 1e18 represents "1", 5e17 represents "0.5".
  // For signed values:
  //   This can represent a value up (or down) to +-(2^255 - 1)/10^18 = ~10^58. 10^58 will be stored internally as int256 10^76.
  int256 private constant SFP_SCALING_FACTOR = 10 ** 18;

  struct Signed {
    int256 rawValue;
  }

  function fromSigned(Signed memory a) internal pure returns (Unsigned memory) {
    require(a.rawValue >= 0, "Negative value provided");
    return Unsigned(uint256(a.rawValue));
  }

  function fromUnsigned(Unsigned memory a) internal pure returns (Signed memory) {
    require(a.rawValue <= uint256(type(int256).max), "Unsigned too large");
    return Signed(int256(a.rawValue));
  }

  /**
   * @notice Constructs a `Signed` from an unscaled int, e.g., `b=5` gets stored internally as `5**18`.
   * @param a int to convert into a FixedPoint.Signed.
   * @return the converted FixedPoint.Signed.
   */
  function fromUnscaledInt(int256 a) internal pure returns (Signed memory) {
    return Signed(a.mul(SFP_SCALING_FACTOR));
  }

  /**
   * @notice Whether `a` is equal to `b`.
   * @param a a FixedPoint.Signed.
   * @param b a int256.
   * @return True if equal, or False.
   */
  function isEqual(Signed memory a, int256 b) internal pure returns (bool) {
    return a.rawValue == fromUnscaledInt(b).rawValue;
  }

  /**
   * @notice Whether `a` is equal to `b`.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return True if equal, or False.
   */
  function isEqual(Signed memory a, Signed memory b) internal pure returns (bool) {
    return a.rawValue == b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than `b`.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return True if `a > b`, or False.
   */
  function isGreaterThan(Signed memory a, Signed memory b) internal pure returns (bool) {
    return a.rawValue > b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than `b`.
   * @param a a FixedPoint.Signed.
   * @param b an int256.
   * @return True if `a > b`, or False.
   */
  function isGreaterThan(Signed memory a, int256 b) internal pure returns (bool) {
    return a.rawValue > fromUnscaledInt(b).rawValue;
  }

  /**
   * @notice Whether `a` is greater than `b`.
   * @param a an int256.
   * @param b a FixedPoint.Signed.
   * @return True if `a > b`, or False.
   */
  function isGreaterThan(int256 a, Signed memory b) internal pure returns (bool) {
    return fromUnscaledInt(a).rawValue > b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than or equal to `b`.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return True if `a >= b`, or False.
   */
  function isGreaterThanOrEqual(Signed memory a, Signed memory b) internal pure returns (bool) {
    return a.rawValue >= b.rawValue;
  }

  /**
   * @notice Whether `a` is greater than or equal to `b`.
   * @param a a FixedPoint.Signed.
   * @param b an int256.
   * @return True if `a >= b`, or False.
   */
  function isGreaterThanOrEqual(Signed memory a, int256 b) internal pure returns (bool) {
    return a.rawValue >= fromUnscaledInt(b).rawValue;
  }

  /**
   * @notice Whether `a` is greater than or equal to `b`.
   * @param a an int256.
   * @param b a FixedPoint.Signed.
   * @return True if `a >= b`, or False.
   */
  function isGreaterThanOrEqual(int256 a, Signed memory b) internal pure returns (bool) {
    return fromUnscaledInt(a).rawValue >= b.rawValue;
  }

  /**
   * @notice Whether `a` is less than `b`.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return True if `a < b`, or False.
   */
  function isLessThan(Signed memory a, Signed memory b) internal pure returns (bool) {
    return a.rawValue < b.rawValue;
  }

  /**
   * @notice Whether `a` is less than `b`.
   * @param a a FixedPoint.Signed.
   * @param b an int256.
   * @return True if `a < b`, or False.
   */
  function isLessThan(Signed memory a, int256 b) internal pure returns (bool) {
    return a.rawValue < fromUnscaledInt(b).rawValue;
  }

  /**
   * @notice Whether `a` is less than `b`.
   * @param a an int256.
   * @param b a FixedPoint.Signed.
   * @return True if `a < b`, or False.
   */
  function isLessThan(int256 a, Signed memory b) internal pure returns (bool) {
    return fromUnscaledInt(a).rawValue < b.rawValue;
  }

  /**
   * @notice Whether `a` is less than or equal to `b`.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return True if `a <= b`, or False.
   */
  function isLessThanOrEqual(Signed memory a, Signed memory b) internal pure returns (bool) {
    return a.rawValue <= b.rawValue;
  }

  /**
   * @notice Whether `a` is less than or equal to `b`.
   * @param a a FixedPoint.Signed.
   * @param b an int256.
   * @return True if `a <= b`, or False.
   */
  function isLessThanOrEqual(Signed memory a, int256 b) internal pure returns (bool) {
    return a.rawValue <= fromUnscaledInt(b).rawValue;
  }

  /**
   * @notice Whether `a` is less than or equal to `b`.
   * @param a an int256.
   * @param b a FixedPoint.Signed.
   * @return True if `a <= b`, or False.
   */
  function isLessThanOrEqual(int256 a, Signed memory b) internal pure returns (bool) {
    return fromUnscaledInt(a).rawValue <= b.rawValue;
  }

  /**
   * @notice The minimum of `a` and `b`.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return the minimum of `a` and `b`.
   */
  function min(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    return a.rawValue < b.rawValue ? a : b;
  }

  /**
   * @notice The maximum of `a` and `b`.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return the maximum of `a` and `b`.
   */
  function max(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    return a.rawValue > b.rawValue ? a : b;
  }

  /**
   * @notice Adds two `Signed`s, reverting on overflow.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return the sum of `a` and `b`.
   */
  function add(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    return Signed(a.rawValue.add(b.rawValue));
  }

  /**
   * @notice Adds an `Signed` to an unscaled int, reverting on overflow.
   * @param a a FixedPoint.Signed.
   * @param b an int256.
   * @return the sum of `a` and `b`.
   */
  function add(Signed memory a, int256 b) internal pure returns (Signed memory) {
    return add(a, fromUnscaledInt(b));
  }

  /**
   * @notice Subtracts two `Signed`s, reverting on overflow.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return the difference of `a` and `b`.
   */
  function sub(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    return Signed(a.rawValue.sub(b.rawValue));
  }

  /**
   * @notice Subtracts an unscaled int256 from an `Signed`, reverting on overflow.
   * @param a a FixedPoint.Signed.
   * @param b an int256.
   * @return the difference of `a` and `b`.
   */
  function sub(Signed memory a, int256 b) internal pure returns (Signed memory) {
    return sub(a, fromUnscaledInt(b));
  }

  /**
   * @notice Subtracts an `Signed` from an unscaled int256, reverting on overflow.
   * @param a an int256.
   * @param b a FixedPoint.Signed.
   * @return the difference of `a` and `b`.
   */
  function sub(int256 a, Signed memory b) internal pure returns (Signed memory) {
    return sub(fromUnscaledInt(a), b);
  }

  /**
   * @notice Multiplies two `Signed`s, reverting on overflow.
   * @dev This will "floor" the product.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return the product of `a` and `b`.
   */
  function mul(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    // There are two caveats with this computation:
    // 1. Max output for the represented number is ~10^41, otherwise an intermediate value overflows. 10^41 is
    // stored internally as an int256 ~10^59.
    // 2. Results that can't be represented exactly are truncated not rounded. E.g., 1.4 * 2e-18 = 2.8e-18, which
    // would round to 3, but this computation produces the result 2.
    // No need to use SafeMath because SFP_SCALING_FACTOR != 0.
    return Signed(a.rawValue.mul(b.rawValue) / SFP_SCALING_FACTOR);
  }

  /**
   * @notice Multiplies an `Signed` and an unscaled int256, reverting on overflow.
   * @dev This will "floor" the product.
   * @param a a FixedPoint.Signed.
   * @param b an int256.
   * @return the product of `a` and `b`.
   */
  function mul(Signed memory a, int256 b) internal pure returns (Signed memory) {
    return Signed(a.rawValue.mul(b));
  }

  /**
   * @notice Multiplies two `Signed`s and "ceil's" the product, reverting on overflow.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return the product of `a` and `b`.
   */
  function mulAwayFromZero(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    int256 mulRaw = a.rawValue.mul(b.rawValue);
    int256 mulTowardsZero = mulRaw / SFP_SCALING_FACTOR;
    // Manual mod because SignedSafeMath doesn't support it.
    int256 mod = mulRaw % SFP_SCALING_FACTOR;
    if (mod != 0) {
      bool isResultPositive = isLessThan(a, 0) == isLessThan(b, 0);
      int256 valueToAdd = isResultPositive ? int256(1) : int256(-1);
      return Signed(mulTowardsZero.add(valueToAdd));
    } else {
      return Signed(mulTowardsZero);
    }
  }

  /**
   * @notice Multiplies an `Signed` and an unscaled int256 and "ceil's" the product, reverting on overflow.
   * @param a a FixedPoint.Signed.
   * @param b a FixedPoint.Signed.
   * @return the product of `a` and `b`.
   */
  function mulAwayFromZero(Signed memory a, int256 b) internal pure returns (Signed memory) {
    // Since b is an int, there is no risk of truncation and we can just mul it normally
    return Signed(a.rawValue.mul(b));
  }

  /**
   * @notice Divides one `Signed` by an `Signed`, reverting on overflow or division by 0.
   * @dev This will "floor" the quotient.
   * @param a a FixedPoint numerator.
   * @param b a FixedPoint denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function div(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    // There are two caveats with this computation:
    // 1. Max value for the number dividend `a` represents is ~10^41, otherwise an intermediate value overflows.
    // 10^41 is stored internally as an int256 10^59.
    // 2. Results that can't be represented exactly are truncated not rounded. E.g., 2 / 3 = 0.6 repeating, which
    // would round to 0.666666666666666667, but this computation produces the result 0.666666666666666666.
    return Signed(a.rawValue.mul(SFP_SCALING_FACTOR).div(b.rawValue));
  }

  /**
   * @notice Divides one `Signed` by an unscaled int256, reverting on overflow or division by 0.
   * @dev This will "floor" the quotient.
   * @param a a FixedPoint numerator.
   * @param b an int256 denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function div(Signed memory a, int256 b) internal pure returns (Signed memory) {
    return Signed(a.rawValue.div(b));
  }

  /**
   * @notice Divides one unscaled int256 by an `Signed`, reverting on overflow or division by 0.
   * @dev This will "floor" the quotient.
   * @param a an int256 numerator.
   * @param b a FixedPoint denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function div(int256 a, Signed memory b) internal pure returns (Signed memory) {
    return div(fromUnscaledInt(a), b);
  }

  /**
   * @notice Divides one `Signed` by an `Signed` and "ceil's" the quotient, reverting on overflow or division by 0.
   * @param a a FixedPoint numerator.
   * @param b a FixedPoint denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function divAwayFromZero(Signed memory a, Signed memory b) internal pure returns (Signed memory) {
    int256 aScaled = a.rawValue.mul(SFP_SCALING_FACTOR);
    int256 divTowardsZero = aScaled.div(b.rawValue);
    // Manual mod because SignedSafeMath doesn't support it.
    int256 mod = aScaled % b.rawValue;
    if (mod != 0) {
      bool isResultPositive = isLessThan(a, 0) == isLessThan(b, 0);
      int256 valueToAdd = isResultPositive ? int256(1) : int256(-1);
      return Signed(divTowardsZero.add(valueToAdd));
    } else {
      return Signed(divTowardsZero);
    }
  }

  /**
   * @notice Divides one `Signed` by an unscaled int256 and "ceil's" the quotient, reverting on overflow or division by 0.
   * @param a a FixedPoint numerator.
   * @param b an int256 denominator.
   * @return the quotient of `a` divided by `b`.
   */
  function divAwayFromZero(Signed memory a, int256 b) internal pure returns (Signed memory) {
    // Because it is possible that a quotient gets truncated, we can't just call "Signed(a.rawValue.div(b))"
    // similarly to mulCeil with an int256 as the second parameter. Therefore we need to convert b into an Signed.
    // This creates the possibility of overflow if b is very large.
    return divAwayFromZero(a, fromUnscaledInt(b));
  }

  /**
   * @notice Raises an `Signed` to the power of an unscaled uint256, reverting on overflow. E.g., `b=2` squares `a`.
   * @dev This will "floor" the result.
   * @param a a FixedPoint.Signed.
   * @param b a uint256 (negative exponents are not allowed).
   * @return output is `a` to the power of `b`.
   */
  function pow(Signed memory a, uint256 b) internal pure returns (Signed memory output) {
    output = fromUnscaledInt(1);
    for (uint256 i = 0; i < b; i = i.add(1)) {
      output = mul(output, a);
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

pragma experimental ABIEncoderV2;

interface IBackerRewards {
  function allocateRewards(uint256 _interestPaymentAmount) external;

  function onTranchedPoolDrawdown(uint256 sliceIndex) external;

  function setPoolTokenAccRewardsPerPrincipalDollarAtMint(address poolAddress, uint256 tokenId) external;
}

// SPDX-License-Identifier: MIT
// Taken from https://github.com/compound-finance/compound-protocol/blob/master/contracts/CTokenInterfaces.sol
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./IERC20withDec.sol";

interface ICUSDCContract is IERC20withDec {
  /*** User Interface ***/

  function mint(uint256 mintAmount) external returns (uint256);

  function redeem(uint256 redeemTokens) external returns (uint256);

  function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

  function borrow(uint256 borrowAmount) external returns (uint256);

  function repayBorrow(uint256 repayAmount) external returns (uint256);

  function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

  function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral) external returns (uint256);

  function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

  function balanceOfUnderlying(address owner) external returns (uint256);

  function exchangeRateCurrent() external returns (uint256);

  /*** Admin Functions ***/

  function _addReserves(uint256 addAmount) external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

interface IConfig {
  function getNumber(uint256 index) external returns (uint256);

  function getAddress(uint256 index) external returns (address);

  function setAddress(uint256 index, address newAddress) external returns (address);

  function setNumber(uint256 index, uint256 newNumber) external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

interface ICreditLine {
  function borrower() external view returns (address);

  function limit() external view returns (uint256);

  function maxLimit() external view returns (uint256);

  function interestApr() external view returns (uint256);

  function paymentPeriodInDays() external view returns (uint256);

  function principalGracePeriodInDays() external view returns (uint256);

  function termInDays() external view returns (uint256);

  function lateFeeApr() external view returns (uint256);

  function isLate() external view returns (bool);

  function withinPrincipalGracePeriod() external view returns (bool);

  // Accounting variables
  function balance() external view returns (uint256);

  function interestOwed() external view returns (uint256);

  function principalOwed() external view returns (uint256);

  function termEndTime() external view returns (uint256);

  function nextDueTime() external view returns (uint256);

  function interestAccruedAsOf() external view returns (uint256);

  function lastFullPaymentTime() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// Taken from https://github.com/compound-finance/compound-protocol/blob/master/contracts/CTokenInterfaces.sol
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

interface ICurveLP {
  function coins(uint256) external view returns (address);

  function token() external view returns (address);

  function calc_token_amount(uint256[2] calldata amounts) external view returns (uint256);

  function lp_price() external view returns (uint256);

  function add_liquidity(
    uint256[2] calldata amounts,
    uint256 min_mint_amount,
    bool use_eth,
    address receiver
  ) external returns (uint256);

  function remove_liquidity(uint256 _amount, uint256[2] calldata min_amounts) external returns (uint256);

  function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount) external returns (uint256);

  function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);

  function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (uint256);

  function balances(uint256 arg0) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

/*
Only addition is the `decimals` function, which we need, and which both our Fidu and USDC use, along with most ERC20's.
*/

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20withDec is IERC20 {
  /**
   * @dev Returns the number of decimals used for the token
   */
  function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

interface IFactory {
  function createCreditLine() external returns (address);

  function createBorrower(address owner) external returns (address);

  function createPool(
    address _borrower,
    uint256 _juniorFeePercent,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256[] calldata _allowedUIDTypes
  ) external returns (address);

  function createMigratedPool(
    address _borrower,
    uint256 _juniorFeePercent,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256[] calldata _allowedUIDTypes
  ) external returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./IERC20withDec.sol";

interface IFidu is IERC20withDec {
  function mintTo(address to, uint256 amount) external;

  function burnFrom(address to, uint256 amount) external;

  function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

abstract contract IGo {
  uint256 public constant ID_TYPE_0 = 0;
  uint256 public constant ID_TYPE_1 = 1;
  uint256 public constant ID_TYPE_2 = 2;
  uint256 public constant ID_TYPE_3 = 3;
  uint256 public constant ID_TYPE_4 = 4;
  uint256 public constant ID_TYPE_5 = 5;
  uint256 public constant ID_TYPE_6 = 6;
  uint256 public constant ID_TYPE_7 = 7;
  uint256 public constant ID_TYPE_8 = 8;
  uint256 public constant ID_TYPE_9 = 9;
  uint256 public constant ID_TYPE_10 = 10;

  /// @notice Returns the address of the UniqueIdentity contract.
  function uniqueIdentity() external virtual returns (address);

  function go(address account) public view virtual returns (bool);

  function goOnlyIdTypes(address account, uint256[] calldata onlyIdTypes) public view virtual returns (bool);

  /**
   * @notice Returns whether the provided account is go-listed for use of the SeniorPool on the Goldfinch protocol.
   * @param account The account whose go status to obtain
   * @return true if `account` is go listed
   */
  function goSeniorPool(address account) public view virtual returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./openzeppelin/IERC721.sol";

interface IPoolTokens is IERC721 {
  event TokenMinted(
    address indexed owner,
    address indexed pool,
    uint256 indexed tokenId,
    uint256 amount,
    uint256 tranche
  );

  event TokenRedeemed(
    address indexed owner,
    address indexed pool,
    uint256 indexed tokenId,
    uint256 principalRedeemed,
    uint256 interestRedeemed,
    uint256 tranche
  );
  event TokenBurned(address indexed owner, address indexed pool, uint256 indexed tokenId);

  struct TokenInfo {
    address pool;
    uint256 tranche;
    uint256 principalAmount;
    uint256 principalRedeemed;
    uint256 interestRedeemed;
  }

  struct MintParams {
    uint256 principalAmount;
    uint256 tranche;
  }

  function mint(MintParams calldata params, address to) external returns (uint256);

  function redeem(uint256 tokenId, uint256 principalRedeemed, uint256 interestRedeemed) external;

  function withdrawPrincipal(uint256 tokenId, uint256 principalAmount) external;

  function burn(uint256 tokenId) external;

  function onPoolCreated(address newPool) external;

  function getTokenInfo(uint256 tokenId) external view returns (TokenInfo memory);

  function validPool(address sender) external view returns (bool);

  function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

interface IRequiresUID {
  function hasAllowedUID(address sender) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./ITranchedPool.sol";

abstract contract ISeniorPool {
  uint256 public sharePrice;
  uint256 public totalLoansOutstanding;
  uint256 public totalWritedowns;

  function deposit(uint256 amount) external virtual returns (uint256 depositShares);

  function depositWithPermit(
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual returns (uint256 depositShares);

  function withdraw(uint256 usdcAmount) external virtual returns (uint256 amount);

  function withdrawInFidu(uint256 fiduAmount) external virtual returns (uint256 amount);

  function sweepToCompound() public virtual;

  function sweepFromCompound() public virtual;

  function invest(ITranchedPool pool) public virtual;

  function estimateInvestment(ITranchedPool pool) public view virtual returns (uint256);

  function redeem(uint256 tokenId) public virtual;

  function writedown(uint256 tokenId) public virtual;

  function calculateWritedown(uint256 tokenId) public view virtual returns (uint256 writedownAmount);

  function assets() public view virtual returns (uint256);

  function getNumShares(uint256 amount) public view virtual returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./ISeniorPool.sol";
import "./ITranchedPool.sol";

abstract contract ISeniorPoolStrategy {
  function getLeverageRatio(ITranchedPool pool) public view virtual returns (uint256);

  function invest(ISeniorPool seniorPool, ITranchedPool pool) public view virtual returns (uint256 amount);

  function estimateInvestment(ISeniorPool seniorPool, ITranchedPool pool) public view virtual returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

pragma experimental ABIEncoderV2;

import { IERC721 } from "./openzeppelin/IERC721.sol";
import { IERC721Metadata } from "./openzeppelin/IERC721Metadata.sol";
import { IERC721Enumerable } from "./openzeppelin/IERC721Enumerable.sol";

interface IStakingRewards is IERC721, IERC721Metadata, IERC721Enumerable {
  function getPosition(uint256 tokenId) external view returns (StakedPosition memory position);

  function unstake(uint256 tokenId, uint256 amount) external;

  function addToStake(uint256 tokenId, uint256 amount) external;

  function stakedBalanceOf(uint256 tokenId) external view returns (uint256);

  function depositToCurveAndStakeFrom(address nftRecipient, uint256 fiduAmount, uint256 usdcAmount) external;

  function kick(uint256 tokenId) external;

  function accumulatedRewardsPerToken() external view returns (uint256);

  function lastUpdateTime() external view returns (uint256);

  /* ========== EVENTS ========== */

  event RewardAdded(uint256 reward);
  event Staked(
    address indexed user,
    uint256 indexed tokenId,
    uint256 amount,
    StakedPositionType positionType,
    uint256 baseTokenExchangeRate
  );
  event DepositedAndStaked(address indexed user, uint256 depositedAmount, uint256 indexed tokenId, uint256 amount);
  event DepositedToCurve(address indexed user, uint256 fiduAmount, uint256 usdcAmount, uint256 tokensReceived);
  event DepositedToCurveAndStaked(
    address indexed user,
    uint256 fiduAmount,
    uint256 usdcAmount,
    uint256 indexed tokenId,
    uint256 amount
  );
  event Unstaked(address indexed user, uint256 indexed tokenId, uint256 amount, StakedPositionType positionType);
  event UnstakedMultiple(address indexed user, uint256[] tokenIds, uint256[] amounts);
  event UnstakedAndWithdrew(address indexed user, uint256 usdcReceivedAmount, uint256 indexed tokenId, uint256 amount);
  event UnstakedAndWithdrewMultiple(
    address indexed user,
    uint256 usdcReceivedAmount,
    uint256[] tokenIds,
    uint256[] amounts
  );
  event RewardPaid(address indexed user, uint256 indexed tokenId, uint256 reward);
  event RewardsParametersUpdated(
    address indexed who,
    uint256 targetCapacity,
    uint256 minRate,
    uint256 maxRate,
    uint256 minRateAtPercent,
    uint256 maxRateAtPercent
  );
  event EffectiveMultiplierUpdated(address indexed who, StakedPositionType positionType, uint256 multiplier);
}

/// @notice Indicates which ERC20 is staked
enum StakedPositionType {
  Fidu,
  CurveLP
}

struct Rewards {
  uint256 totalUnvested;
  uint256 totalVested;
  // @dev DEPRECATED (definition kept for storage slot)
  //   For legacy vesting positions, this was used in the case of slashing.
  //   For non-vesting positions, this is unused.
  uint256 totalPreviouslyVested;
  uint256 totalClaimed;
  uint256 startTime;
  // @dev DEPRECATED (definition kept for storage slot)
  //   For legacy vesting positions, this is the endTime of the vesting.
  //   For non-vesting positions, this is 0.
  uint256 endTime;
}

struct StakedPosition {
  // @notice Staked amount denominated in `stakingToken().decimals()`
  uint256 amount;
  // @notice Struct describing rewards owed with vesting
  Rewards rewards;
  // @notice Multiplier applied to staked amount when locking up position
  uint256 leverageMultiplier;
  // @notice Time in seconds after which position can be unstaked
  uint256 lockedUntil;
  // @notice Type of the staked position
  StakedPositionType positionType;
  // @notice Multiplier applied to staked amount to denominate in `baseStakingToken().decimals()`
  // @dev This field should not be used directly; it may be 0 for staked positions created prior to GIP-1.
  //  If you need this field, use `safeEffectiveMultiplier()`, which correctly handles old staked positions.
  uint256 unsafeEffectiveMultiplier;
  // @notice Exchange rate applied to staked amount to denominate in `baseStakingToken().decimals()`
  // @dev This field should not be used directly; it may be 0 for staked positions created prior to GIP-1.
  //  If you need this field, use `safeBaseTokenExchangeRate()`, which correctly handles old staked positions.
  uint256 unsafeBaseTokenExchangeRate;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import { IV2CreditLine } from "./IV2CreditLine.sol";

abstract contract ITranchedPool {
  IV2CreditLine public creditLine;
  uint256 public createdAt;
  enum Tranches {
    Reserved,
    Senior,
    Junior
  }

  struct TrancheInfo {
    uint256 id;
    uint256 principalDeposited;
    uint256 principalSharePrice;
    uint256 interestSharePrice;
    uint256 lockedUntil;
  }

  struct PoolSlice {
    TrancheInfo seniorTranche;
    TrancheInfo juniorTranche;
    uint256 totalInterestAccrued;
    uint256 principalDeployed;
  }

  function initialize(
    address _config,
    address _borrower,
    uint256 _juniorFeePercent,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256 _principalGracePeriodInDays,
    uint256 _fundableAt,
    uint256[] calldata _allowedUIDTypes
  ) public virtual;

  function getTranche(uint256 tranche) external view virtual returns (TrancheInfo memory);

  function pay(uint256 amount) external virtual;

  function poolSlices(uint256 index) external view virtual returns (PoolSlice memory);

  function lockJuniorCapital() external virtual;

  function lockPool() external virtual;

  function initializeNextSlice(uint256 _fundableAt) external virtual;

  function totalJuniorDeposits() external view virtual returns (uint256);

  function drawdown(uint256 amount) external virtual;

  function setFundableAt(uint256 timestamp) external virtual;

  function deposit(uint256 tranche, uint256 amount) external virtual returns (uint256 tokenId);

  function assess() external virtual;

  function depositWithPermit(
    uint256 tranche,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual returns (uint256 tokenId);

  function availableToWithdraw(
    uint256 tokenId
  ) external view virtual returns (uint256 interestRedeemable, uint256 principalRedeemable);

  function withdraw(
    uint256 tokenId,
    uint256 amount
  ) external virtual returns (uint256 interestWithdrawn, uint256 principalWithdrawn);

  function withdrawMax(
    uint256 tokenId
  ) external virtual returns (uint256 interestWithdrawn, uint256 principalWithdrawn);

  function withdrawMultiple(uint256[] calldata tokenIds, uint256[] calldata amounts) external virtual;

  function numSlices() external view virtual returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./ICreditLine.sol";

abstract contract IV2CreditLine is ICreditLine {
  function principal() external view virtual returns (uint256);

  function totalInterestAccrued() external view virtual returns (uint256);

  function termStartTime() external view virtual returns (uint256);

  function setLimit(uint256 newAmount) external virtual;

  function setMaxLimit(uint256 newAmount) external virtual;

  function setBalance(uint256 newBalance) external virtual;

  function setPrincipal(uint256 _principal) external virtual;

  function setTotalInterestAccrued(uint256 _interestAccrued) external virtual;

  function drawdown(uint256 amount) external virtual;

  function assess() external virtual returns (uint256, uint256, uint256);

  function initialize(
    address _config,
    address owner,
    address _borrower,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256 _principalGracePeriodInDays
  ) public virtual;

  function setTermEndTime(uint256 newTermEndTime) external virtual;

  function setNextDueTime(uint256 newNextDueTime) external virtual;

  function setInterestOwed(uint256 newInterestOwed) external virtual;

  function setPrincipalOwed(uint256 newPrincipalOwed) external virtual;

  function setInterestAccruedAsOf(uint256 newInterestAccruedAsOf) external virtual;

  function setWritedownAmount(uint256 newWritedownAmount) external virtual;

  function setLastFullPaymentTime(uint256 newLastFullPaymentTime) external virtual;

  function setLateFeeApr(uint256 newLateFeeApr) external virtual;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

/// @title interface for implementers that have an arbitrary associated tag
interface IVersioned {
  /// @notice Returns the version triplet `[major, minor, patch]`
  function getVersion() external pure returns (uint8[3] memory);
}

pragma solidity >=0.6.0;

// This file copied from OZ, but with the version pragma updated to use >=.

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

pragma solidity >=0.6.2;

// This file copied from OZ, but with the version pragma updated to use >= & reference other >= pragma interfaces.
// NOTE: Modified to reference our updated pragma version of IERC165
import "./IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  /**
   * @dev Returns the number of NFTs in ``owner``'s account.
   */
  function balanceOf(address owner) external view returns (uint256 balance);

  /**
   * @dev Returns the owner of the NFT specified by `tokenId`.
   */
  function ownerOf(uint256 tokenId) external view returns (address owner);

  /**
   * @dev Transfers a specific NFT (`tokenId`) from one account (`from`) to
   * another (`to`).
   *
   *
   *
   * Requirements:
   * - `from`, `to` cannot be zero.
   * - `tokenId` must be owned by `from`.
   * - If the caller is not `from`, it must be have been allowed to move this
   * NFT by either {approve} or {setApprovalForAll}.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId) external;

  /**
   * @dev Transfers a specific NFT (`tokenId`) from one account (`from`) to
   * another (`to`).
   *
   * Requirements:
   * - If the caller is not `from`, it must be approved to move this NFT by
   * either {approve} or {setApprovalForAll}.
   */
  function transferFrom(address from, address to, uint256 tokenId) external;

  function approve(address to, uint256 tokenId) external;

  function getApproved(uint256 tokenId) external view returns (address operator);

  function setApprovalForAll(address operator, bool _approved) external;

  function isApprovedForAll(address owner, address operator) external view returns (bool);

  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

pragma solidity >=0.6.2;

// This file copied from OZ, but with the version pragma updated to use >=.

import "./IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
  function totalSupply() external view returns (uint256);

  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

  function tokenByIndex(uint256 index) external view returns (uint256);
}

pragma solidity >=0.6.2;

// This file copied from OZ, but with the version pragma updated to use >=.

import "./IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

/**
 * @title Safe ERC20 Transfer
 * @notice Reverts when transfer is not successful
 * @author Goldfinch
 */
library SafeERC20Transfer {
  function safeERC20Transfer(IERC20 erc20, address to, uint256 amount, string memory message) internal {
    /// @dev ZERO address
    require(to != address(0), "ZERO");
    bool success = erc20.transfer(to, amount);
    require(success, message);
  }

  function safeERC20Transfer(IERC20 erc20, address to, uint256 amount) internal {
    safeERC20Transfer(erc20, to, amount, "");
  }

  function safeERC20TransferFrom(
    IERC20 erc20,
    address from,
    address to,
    uint256 amount,
    string memory message
  ) internal {
    require(to != address(0), "ZERO");
    bool success = erc20.transferFrom(from, to, amount);
    require(success, message);
  }

  function safeERC20TransferFrom(IERC20 erc20, address from, address to, uint256 amount) internal {
    safeERC20TransferFrom(erc20, from, to, amount, "");
  }

  function safeERC20Approve(IERC20 erc20, address spender, uint256 allowance, string memory message) internal {
    bool success = erc20.approve(spender, allowance);
    require(success, message);
  }

  function safeERC20Approve(IERC20 erc20, address spender, uint256 allowance) internal {
    safeERC20Approve(erc20, spender, allowance, "");
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./PauserPausable.sol";

/**
 * @title BaseUpgradeablePausable contract
 * @notice This is our Base contract that most other contracts inherit from. It includes many standard
 *  useful abilities like upgradeability, pausability, access control, and re-entrancy guards.
 * @author Goldfinch
 */

contract BaseUpgradeablePausable is
  Initializable,
  AccessControlUpgradeSafe,
  PauserPausable,
  ReentrancyGuardUpgradeSafe
{
  bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
  using SafeMath for uint256;
  // Pre-reserving a few slots in the base contract in case we need to add things in the future.
  // This does not actually take up gas cost or storage cost, but it does reserve the storage slots.
  // See OpenZeppelin's use of this pattern here:
  // https://github.com/OpenZeppelin/openzeppelin-contracts-ethereum-package/blob/master/contracts/GSN/Context.sol#L37
  uint256[50] private __gap1;
  uint256[50] private __gap2;
  uint256[50] private __gap3;
  uint256[50] private __gap4;

  // solhint-disable-next-line func-name-mixedcase
  function __BaseUpgradeablePausable__init(address owner) public initializer {
    require(owner != address(0), "Owner cannot be the zero address");
    __AccessControl_init_unchained();
    __Pausable_init_unchained();
    __ReentrancyGuard_init_unchained();

    _setupRole(OWNER_ROLE, owner);
    _setupRole(PAUSER_ROLE, owner);

    _setRoleAdmin(PAUSER_ROLE, OWNER_ROLE);
    _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
  }

  function isAdmin() public view returns (bool) {
    return hasRole(OWNER_ROLE, _msgSender());
  }

  modifier onlyAdmin() {
    require(isAdmin(), "Must have admin role to perform this action");
    _;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeablePausable.sol";
import "../../interfaces/IConfig.sol";
import "./ConfigOptions.sol";

/**
 * @title Config
 * @notice This contract stores mappings of useful "protocol config state", giving a central place
 *  for all other contracts to access it. For example, the TransactionLimit, or the PoolAddress. These config vars
 *  are enumerated in the `ConfigOptions` library, and can only be changed by admins of the protocol.
 *  Note: While this inherits from BaseUpgradeablePausable, it is not deployed as an upgradeable contract (this
 *    is mostly to save gas costs of having each call go through a proxy)
 * @author Goldfinch
 */

contract Config is BaseUpgradeablePausable {
  bytes32 public constant GO_LISTER_ROLE = keccak256("GO_LISTER_ROLE");

  mapping(uint256 => address) public addresses;
  mapping(uint256 => uint256) public numbers;
  mapping(address => bool) public goList;

  event AddressUpdated(address owner, uint256 index, address oldValue, address newValue);
  event NumberUpdated(address owner, uint256 index, uint256 oldValue, uint256 newValue);

  event GoListed(address indexed member);
  event NoListed(address indexed member);

  bool public valuesInitialized;

  function initialize(address owner) public initializer {
    require(owner != address(0), "Owner address cannot be empty");

    __BaseUpgradeablePausable__init(owner);

    _setupRole(GO_LISTER_ROLE, owner);

    _setRoleAdmin(GO_LISTER_ROLE, OWNER_ROLE);
  }

  function setAddress(uint256 addressIndex, address newAddress) public onlyAdmin {
    require(addresses[addressIndex] == address(0), "Address has already been initialized");

    emit AddressUpdated(msg.sender, addressIndex, addresses[addressIndex], newAddress);
    addresses[addressIndex] = newAddress;
  }

  function setNumber(uint256 index, uint256 newNumber) public onlyAdmin {
    emit NumberUpdated(msg.sender, index, numbers[index], newNumber);
    numbers[index] = newNumber;
  }

  function setTreasuryReserve(address newTreasuryReserve) public onlyAdmin {
    uint256 key = uint256(ConfigOptions.Addresses.TreasuryReserve);
    emit AddressUpdated(msg.sender, key, addresses[key], newTreasuryReserve);
    addresses[key] = newTreasuryReserve;
  }

  function setSeniorPoolStrategy(address newStrategy) public onlyAdmin {
    uint256 key = uint256(ConfigOptions.Addresses.SeniorPoolStrategy);
    emit AddressUpdated(msg.sender, key, addresses[key], newStrategy);
    addresses[key] = newStrategy;
  }

  function setCreditLineImplementation(address newAddress) public onlyAdmin {
    uint256 key = uint256(ConfigOptions.Addresses.CreditLineImplementation);
    emit AddressUpdated(msg.sender, key, addresses[key], newAddress);
    addresses[key] = newAddress;
  }

  function setTranchedPoolImplementation(address newAddress) public onlyAdmin {
    uint256 key = uint256(ConfigOptions.Addresses.TranchedPoolImplementation);
    emit AddressUpdated(msg.sender, key, addresses[key], newAddress);
    addresses[key] = newAddress;
  }

  function setBorrowerImplementation(address newAddress) public onlyAdmin {
    uint256 key = uint256(ConfigOptions.Addresses.BorrowerImplementation);
    emit AddressUpdated(msg.sender, key, addresses[key], newAddress);
    addresses[key] = newAddress;
  }

  function setConfig(address newAddress) public onlyAdmin {
    uint256 key = uint256(ConfigOptions.Addresses.Config);
    emit AddressUpdated(msg.sender, key, addresses[key], newAddress);
    addresses[key] = newAddress;
  }

  function initializeFromOtherConfig(
    address _initialConfig,
    uint256 numbersLength,
    uint256 addressesLength
  ) public onlyAdmin {
    require(!valuesInitialized, "Already initialized values");
    IConfig initialConfig = IConfig(_initialConfig);
    for (uint256 i = 0; i < numbersLength; i++) {
      setNumber(i, initialConfig.getNumber(i));
    }

    for (uint256 i = 0; i < addressesLength; i++) {
      if (getAddress(i) == address(0)) {
        setAddress(i, initialConfig.getAddress(i));
      }
    }
    valuesInitialized = true;
  }

  /**
   * @dev Adds a user to go-list
   * @param _member address to add to go-list
   */
  function addToGoList(address _member) public onlyGoListerRole {
    goList[_member] = true;
    emit GoListed(_member);
  }

  /**
   * @dev removes a user from go-list
   * @param _member address to remove from go-list
   */
  function removeFromGoList(address _member) public onlyGoListerRole {
    goList[_member] = false;
    emit NoListed(_member);
  }

  /**
   * @dev adds many users to go-list at once
   * @param _members addresses to ad to go-list
   */
  function bulkAddToGoList(address[] calldata _members) external onlyGoListerRole {
    for (uint256 i = 0; i < _members.length; i++) {
      addToGoList(_members[i]);
    }
  }

  /**
   * @dev removes many users from go-list at once
   * @param _members addresses to remove from go-list
   */
  function bulkRemoveFromGoList(address[] calldata _members) external onlyGoListerRole {
    for (uint256 i = 0; i < _members.length; i++) {
      removeFromGoList(_members[i]);
    }
  }

  /*
    Using custom getters in case we want to change underlying implementation later,
    or add checks or validations later on.
  */
  function getAddress(uint256 index) public view returns (address) {
    return addresses[index];
  }

  function getNumber(uint256 index) public view returns (uint256) {
    return numbers[index];
  }

  modifier onlyGoListerRole() {
    require(hasRole(GO_LISTER_ROLE, _msgSender()), "Must have go-lister role to perform this action");
    _;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { ImplementationRepository } from "./proxy/ImplementationRepository.sol";
import { ConfigOptions } from "./ConfigOptions.sol";
import { Config } from "./Config.sol";
import { IFidu } from "../../interfaces/IFidu.sol";
import { ISeniorPool } from "../../interfaces/ISeniorPool.sol";
import { ISeniorPoolStrategy } from "../../interfaces/ISeniorPoolStrategy.sol";
import { IERC20withDec } from "../../interfaces/IERC20withDec.sol";
import { ICUSDCContract } from "../../interfaces/ICUSDCContract.sol";
import { IPoolTokens } from "../../interfaces/IPoolTokens.sol";
import { IBackerRewards } from "../../interfaces/IBackerRewards.sol";
import { IFactory } from "../../interfaces/IFactory.sol";
import { IGo } from "../../interfaces/IGo.sol";
import { IStakingRewards } from "../../interfaces/IStakingRewards.sol";
import { ICurveLP } from "../../interfaces/ICurveLP.sol";

/**
 * @title ConfigHelper
 * @notice A convenience library for getting easy access to other contracts and constants within the
 *  protocol, through the use of the Config contract
 * @author Goldfinch
 */

library ConfigHelper {
  function getSeniorPool(Config config) internal view returns (ISeniorPool) {
    return ISeniorPool(seniorPoolAddress(config));
  }

  function getSeniorPoolStrategy(Config config) internal view returns (ISeniorPoolStrategy) {
    return ISeniorPoolStrategy(seniorPoolStrategyAddress(config));
  }

  function getUSDC(Config config) internal view returns (IERC20withDec) {
    return IERC20withDec(usdcAddress(config));
  }

  function getFidu(Config config) internal view returns (IFidu) {
    return IFidu(fiduAddress(config));
  }

  function getFiduUSDCCurveLP(Config config) internal view returns (ICurveLP) {
    return ICurveLP(fiduUSDCCurveLPAddress(config));
  }

  function getCUSDCContract(Config config) internal view returns (ICUSDCContract) {
    return ICUSDCContract(cusdcContractAddress(config));
  }

  function getPoolTokens(Config config) internal view returns (IPoolTokens) {
    return IPoolTokens(poolTokensAddress(config));
  }

  function getBackerRewards(Config config) internal view returns (IBackerRewards) {
    return IBackerRewards(backerRewardsAddress(config));
  }

  function getFactory(Config config) internal view returns (IFactory) {
    return IFactory(factoryAddress(config));
  }

  function getGFI(Config config) internal view returns (IERC20withDec) {
    return IERC20withDec(gfiAddress(config));
  }

  function getGo(Config config) internal view returns (IGo) {
    return IGo(goAddress(config));
  }

  function getStakingRewards(Config config) internal view returns (IStakingRewards) {
    return IStakingRewards(stakingRewardsAddress(config));
  }

  function getTranchedPoolImplementationRepository(Config config) internal view returns (ImplementationRepository) {
    return
      ImplementationRepository(
        config.getAddress(uint256(ConfigOptions.Addresses.TranchedPoolImplementationRepository))
      );
  }

  function oneInchAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.OneInch));
  }

  function creditLineImplementationAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.CreditLineImplementation));
  }

  /// @dev deprecated because we no longer use GSN
  function trustedForwarderAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.TrustedForwarder));
  }

  function configAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.Config));
  }

  function poolTokensAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.PoolTokens));
  }

  function backerRewardsAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.BackerRewards));
  }

  function seniorPoolAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.SeniorPool));
  }

  function seniorPoolStrategyAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.SeniorPoolStrategy));
  }

  function factoryAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.Factory));
  }

  function gfiAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.GFI));
  }

  function fiduAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.Fidu));
  }

  function fiduUSDCCurveLPAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.FiduUSDCCurveLP));
  }

  function cusdcContractAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.CUSDCContract));
  }

  function usdcAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.USDC));
  }

  function tranchedPoolAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.TranchedPoolImplementation));
  }

  function reserveAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.TreasuryReserve));
  }

  function protocolAdminAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.ProtocolAdmin));
  }

  function borrowerImplementationAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.BorrowerImplementation));
  }

  function goAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.Go));
  }

  function stakingRewardsAddress(Config config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.StakingRewards));
  }

  function getReserveDenominator(Config config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.ReserveDenominator));
  }

  function getWithdrawFeeDenominator(Config config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.WithdrawFeeDenominator));
  }

  function getLatenessGracePeriodInDays(Config config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.LatenessGracePeriodInDays));
  }

  function getLatenessMaxDays(Config config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.LatenessMaxDays));
  }

  function getDrawdownPeriodInSeconds(Config config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.DrawdownPeriodInSeconds));
  }

  function getTransferRestrictionPeriodInDays(Config config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.TransferRestrictionPeriodInDays));
  }

  function getLeverageRatio(Config config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.LeverageRatio));
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title ConfigOptions
 * @notice A central place for enumerating the configurable options of our Config contract
 * @author Goldfinch
 */

library ConfigOptions {
  // NEVER EVER CHANGE THE ORDER OF THESE!
  // You can rename or append. But NEVER change the order.
  enum Numbers {
    TransactionLimit,
    /// @dev: TotalFundsLimit used to represent a total cap on senior pool deposits
    /// but is now deprecated
    TotalFundsLimit,
    MaxUnderwriterLimit,
    ReserveDenominator,
    WithdrawFeeDenominator,
    LatenessGracePeriodInDays,
    LatenessMaxDays,
    DrawdownPeriodInSeconds,
    TransferRestrictionPeriodInDays,
    LeverageRatio
  }
  /// @dev TrustedForwarder is deprecated because we no longer use GSN. CreditDesk
  ///   and Pool are deprecated because they are no longer used in the protocol.
  enum Addresses {
    Pool, // deprecated
    CreditLineImplementation,
    Factory,
    CreditDesk, // deprecated
    Fidu,
    USDC,
    TreasuryReserve,
    ProtocolAdmin,
    OneInch,
    TrustedForwarder, // deprecated
    CUSDCContract,
    Config,
    PoolTokens,
    TranchedPoolImplementation, // deprecated
    SeniorPool,
    SeniorPoolStrategy,
    MigratedTranchedPoolImplementation,
    BorrowerImplementation,
    GFI,
    Go,
    BackerRewards,
    StakingRewards,
    FiduUSDCCurveLP,
    TranchedPoolImplementationRepository
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";

/**
 * @title PauserPausable
 * @notice Inheriting from OpenZeppelin's Pausable contract, this does small
 *  augmentations to make it work with a PAUSER_ROLE, leveraging the AccessControl contract.
 *  It is meant to be inherited.
 * @author Goldfinch
 */

contract PauserPausable is AccessControlUpgradeSafe, PausableUpgradeSafe {
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  // solhint-disable-next-line func-name-mixedcase
  function __PauserPausable__init() public initializer {
    __Pausable_init_unchained();
  }

  /**
   * @dev Pauses all functions guarded by Pause
   *
   * See {Pausable-_pause}.
   *
   * Requirements:
   *
   * - the caller must have the PAUSER_ROLE.
   */

  function pause() public onlyPauserRole {
    _pause();
  }

  /**
   * @dev Unpauses the contract
   *
   * See {Pausable-_unpause}.
   *
   * Requirements:
   *
   * - the caller must have the Pauser role
   */
  function unpause() public onlyPauserRole {
    _unpause();
  }

  modifier onlyPauserRole() {
    /// @dev NA: not authorized
    require(hasRole(PAUSER_ROLE, _msgSender()), "NA");
    _;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { IERC20Permit } from "@openzeppelin/contracts/drafts/IERC20Permit.sol";
import { Math } from "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import { SafeMath } from "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import { ITranchedPool } from "../../interfaces/ITranchedPool.sol";
import { IRequiresUID } from "../../interfaces/IRequiresUID.sol";
import { IERC20withDec } from "../../interfaces/IERC20withDec.sol";
import { IV2CreditLine } from "../../interfaces/IV2CreditLine.sol";
import { IBackerRewards } from "../../interfaces/IBackerRewards.sol";
import { IPoolTokens } from "../../interfaces/IPoolTokens.sol";
import { IVersioned } from "../../interfaces/IVersioned.sol";
import { Config } from "./Config.sol";
import { BaseUpgradeablePausable } from "./BaseUpgradeablePausable.sol";
import { ConfigHelper } from "./ConfigHelper.sol";
import { SafeERC20Transfer } from "../../library/SafeERC20Transfer.sol";
import { TranchingLogic } from "./TranchingLogic.sol";

contract TranchedPool is BaseUpgradeablePausable, ITranchedPool, IVersioned {
  Config public config;
  using ConfigHelper for Config;
  using TranchingLogic for PoolSlice;
  using TranchingLogic for TrancheInfo;
  using SafeERC20Transfer for IERC20withDec;

  bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
  bytes32 public constant SENIOR_ROLE = keccak256("SENIOR_ROLE");
  uint8 internal constant MAJOR_VERSION = 0;
  uint8 internal constant MINOR_VERSION = 1;
  uint8 internal constant PATCH_VERSION = 0;
  uint256 public juniorFeePercent;
  bool public drawdownsPaused;
  uint256 public totalDeployed;
  uint256 public fundableAt;

  mapping(uint256 => PoolSlice) internal _poolSlices;
  uint256 public override numSlices;

  function initialize(
    address _config,
    address _borrower,
    uint256 _juniorFeePercent,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256 _principalGracePeriodInDays,
    uint256 _fundableAt,
    uint256[] calldata _allowedUIDTypes
  ) public override initializer {
    require(address(_config) != address(0) && address(_borrower) != address(0), "ZERO");

    config = Config(_config);
    address owner = config.protocolAdminAddress();
    __BaseUpgradeablePausable__init(owner);
    _initializeNextSlice(_fundableAt);
    _createAndSetCreditLine(
      _borrower,
      _limit,
      _interestApr,
      _paymentPeriodInDays,
      _termInDays,
      _lateFeeApr,
      _principalGracePeriodInDays
    );

    createdAt = block.timestamp;
    juniorFeePercent = _juniorFeePercent;

    _setupRole(LOCKER_ROLE, _borrower);
    _setupRole(LOCKER_ROLE, owner);
    _setRoleAdmin(LOCKER_ROLE, OWNER_ROLE);
    _setRoleAdmin(SENIOR_ROLE, OWNER_ROLE);

    // Unlock self for infinite amount
    require(config.getUSDC().approve(address(this), uint256(-1)));
  }

  /**
   * @notice Deposit a USDC amount into the pool for a tranche. Mints an NFT to the caller representing the position
   * @param tranche The number representing the tranche to deposit into
   * @param amount The USDC amount to tranfer from the caller to the pool
   * @return tokenId The tokenId of the NFT
   */
  function deposit(uint256 tranche, uint256 amount) public override nonReentrant whenNotPaused returns (uint256) {
    TrancheInfo storage trancheInfo = _getTrancheInfo(tranche);
    /// @dev TL: tranche locked
    require(trancheInfo.lockedUntil == 0, "TL");
    /// @dev IA: invalid amount
    require(amount > 0, "IA");
    /// @dev NA: not authorized. Must have correct UID or be go listed
    // require(hasAllowedUID(msg.sender), "NA");
    require(block.timestamp > fundableAt, "Not open");
    // senior tranche ids are always odd numbered
    // if (TranchingLogic.isSeniorTrancheId(trancheInfo.id)) {
    //   require(hasRole(SENIOR_ROLE, _msgSender()), "NA");
    // }

    trancheInfo.principalDeposited = trancheInfo.principalDeposited.add(amount);
    uint256 tokenId = config.getPoolTokens().mint(
      IPoolTokens.MintParams({ tranche: tranche, principalAmount: amount }),
      msg.sender
    );

    config.getUSDC().safeERC20TransferFrom(msg.sender, address(this), amount);
    emit DepositMade(msg.sender, tranche, tokenId, amount);
    return tokenId;
  }

  function depositWithPermit(
    uint256 tranche,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public override returns (uint256 tokenId) {
    IERC20Permit(config.usdcAddress()).permit(msg.sender, address(this), amount, deadline, v, r, s);
    return deposit(tranche, amount);
  }

  /**
   * @notice Withdraw an already deposited amount if the funds are available
   * @param tokenId The NFT representing the position
   * @param amount The amount to withdraw (must be <= interest+principal currently available to withdraw)
   * @return interestWithdrawn The interest amount that was withdrawn
   * @return principalWithdrawn The principal amount that was withdrawn
   */
  function withdraw(
    uint256 tokenId,
    uint256 amount
  ) public override nonReentrant whenNotPaused returns (uint256, uint256) {
    IPoolTokens.TokenInfo memory tokenInfo = config.getPoolTokens().getTokenInfo(tokenId);
    TrancheInfo storage trancheInfo = _getTrancheInfo(tokenInfo.tranche);

    return _withdraw(trancheInfo, tokenInfo, tokenId, amount);
  }

  /**
   * @notice Withdraw from many tokens (that the sender owns) in a single transaction
   * @param tokenIds An array of tokens ids representing the position
   * @param amounts An array of amounts to withdraw from the corresponding tokenIds
   */
  function withdrawMultiple(uint256[] calldata tokenIds, uint256[] calldata amounts) public override {
    require(tokenIds.length == amounts.length, "LEN");

    for (uint256 i = 0; i < amounts.length; i++) {
      withdraw(tokenIds[i], amounts[i]);
    }
  }

  /**
   * @notice Similar to withdraw but will withdraw all available funds
   * @param tokenId The NFT representing the position
   * @return interestWithdrawn The interest amount that was withdrawn
   * @return principalWithdrawn The principal amount that was withdrawn
   */
  function withdrawMax(
    uint256 tokenId
  ) external override nonReentrant whenNotPaused returns (uint256 interestWithdrawn, uint256 principalWithdrawn) {
    IPoolTokens.TokenInfo memory tokenInfo = config.getPoolTokens().getTokenInfo(tokenId);
    TrancheInfo storage trancheInfo = _getTrancheInfo(tokenInfo.tranche);

    (uint256 interestRedeemable, uint256 principalRedeemable) = TranchingLogic.redeemableInterestAndPrincipal(
      trancheInfo,
      tokenInfo
    );

    uint256 amount = interestRedeemable.add(principalRedeemable);

    return _withdraw(trancheInfo, tokenInfo, tokenId, amount);
  }

  /**
   * @notice Draws down the funds (and locks the pool) to the borrower address. Can only be called by the borrower
   * @param amount The amount to drawdown from the creditline (must be < limit)
   */
  function drawdown(uint256 amount) external override onlyLocker whenNotPaused {
    /// @dev DP: drawdowns paused
    require(!drawdownsPaused, "DP");
    if (!_locked()) {
      // Assumes the senior pool has invested already (saves the borrower a separate transaction to lock the pool)
      _lockPool();
    }
    // Drawdown only draws down from the current slice for simplicity. It's harder to account for how much
    // money is available from previous slices since depositors can redeem after unlock.
    PoolSlice storage currentSlice = _poolSlices[numSlices - 1];
    uint256 amountAvailable = TranchingLogic.sharePriceToUsdc(
      currentSlice.juniorTranche.principalSharePrice,
      currentSlice.juniorTranche.principalDeposited
    );
    amountAvailable = amountAvailable.add(
      TranchingLogic.sharePriceToUsdc(
        currentSlice.seniorTranche.principalSharePrice,
        currentSlice.seniorTranche.principalDeposited
      )
    );

    /// @dev IF: insufficient funds
    require(amount <= amountAvailable, "IF");

    creditLine.drawdown(amount);

    // Update the share price to reflect the amount remaining in the pool
    uint256 amountRemaining = amountAvailable.sub(amount);
    uint256 oldJuniorPrincipalSharePrice = currentSlice.juniorTranche.principalSharePrice;
    uint256 oldSeniorPrincipalSharePrice = currentSlice.seniorTranche.principalSharePrice;
    currentSlice.juniorTranche.principalSharePrice = currentSlice.juniorTranche.calculateExpectedSharePrice(
      amountRemaining,
      currentSlice
    );
    currentSlice.seniorTranche.principalSharePrice = currentSlice.seniorTranche.calculateExpectedSharePrice(
      amountRemaining,
      currentSlice
    );
    currentSlice.principalDeployed = currentSlice.principalDeployed.add(amount);
    totalDeployed = totalDeployed.add(amount);

    address borrower = creditLine.borrower();
    // IBackerRewards backerRewards = IBackerRewards(config.backerRewardsAddress());
    // backerRewards.onTranchedPoolDrawdown(numSlices - 1);
    config.getUSDC().safeERC20TransferFrom(address(this), borrower, amount);
    emit DrawdownMade(borrower, amount);
    emit SharePriceUpdated(
      address(this),
      currentSlice.juniorTranche.id,
      currentSlice.juniorTranche.principalSharePrice,
      int256(oldJuniorPrincipalSharePrice.sub(currentSlice.juniorTranche.principalSharePrice)) * -1,
      currentSlice.juniorTranche.interestSharePrice,
      0
    );
    emit SharePriceUpdated(
      address(this),
      currentSlice.seniorTranche.id,
      currentSlice.seniorTranche.principalSharePrice,
      int256(oldSeniorPrincipalSharePrice.sub(currentSlice.seniorTranche.principalSharePrice)) * -1,
      currentSlice.seniorTranche.interestSharePrice,
      0
    );
  }

  function NUM_TRANCHES_PER_SLICE() external pure returns (uint256) {
    return TranchingLogic.NUM_TRANCHES_PER_SLICE;
  }

  /**
   * @notice Locks the junior tranche, preventing more junior deposits. Gives time for the senior to determine how
   * much to invest (ensure leverage ratio cannot change for the period)
   */
  function lockJuniorCapital() external override onlyLocker whenNotPaused {
    _lockJuniorCapital(numSlices.sub(1));
  }

  /**
   * @notice Locks the pool (locks both senior and junior tranches and starts the drawdown period). Beyond the drawdown
   * period, any unused capital is available to withdraw by all depositors
   */
  function lockPool() external override onlyLocker whenNotPaused {
    _lockPool();
  }

  function setFundableAt(uint256 newFundableAt) external override onlyLocker {
    fundableAt = newFundableAt;
  }

  function initializeNextSlice(uint256 _fundableAt) external override onlyLocker whenNotPaused {
    /// @dev NL: not locked
    require(_locked(), "NL");
    /// @dev LP: late payment
    require(!creditLine.isLate(), "LP");
    /// @dev GP: beyond principal grace period
    require(creditLine.withinPrincipalGracePeriod(), "GP");
    _initializeNextSlice(_fundableAt);
    emit SliceCreated(address(this), numSlices.sub(1));
  }

  /**
   * @notice Triggers an assessment of the creditline and the applies the payments according the tranche waterfall
   */
  function assess() external override whenNotPaused {
    _assess();
  }

  /**
   * @notice Allows repaying the creditline. Collects the USDC amount from the sender and triggers an assess
   * @param amount The amount to repay
   */
  function pay(uint256 amount) external override whenNotPaused {
    /// @dev  IA: cannot pay 0
    require(amount > 0, "IA");
    config.getUSDC().safeERC20TransferFrom(msg.sender, address(creditLine), amount);
    _assess();
  }

  /**
   * @notice Pauses the pool and sweeps any remaining funds to the treasury reserve.
   */
  function emergencyShutdown() public onlyAdmin {
    if (!paused()) {
      pause();
    }

    IERC20withDec usdc = config.getUSDC();
    address reserveAddress = config.reserveAddress();
    // Sweep any funds to community reserve
    uint256 poolBalance = usdc.balanceOf(address(this));
    if (poolBalance > 0) {
      config.getUSDC().safeERC20Transfer(reserveAddress, poolBalance);
    }

    uint256 clBalance = usdc.balanceOf(address(creditLine));
    if (clBalance > 0) {
      usdc.safeERC20TransferFrom(address(creditLine), reserveAddress, clBalance);
    }
    emit EmergencyShutdown(address(this));
  }

  /**
   * @notice Pauses all drawdowns (but not deposits/withdraws)
   */
  function pauseDrawdowns() public onlyAdmin {
    drawdownsPaused = true;
    emit DrawdownsPaused(address(this));
  }

  /**
   * @notice Unpause drawdowns
   */
  function unpauseDrawdowns() public onlyAdmin {
    drawdownsPaused = false;
    emit DrawdownsUnpaused(address(this));
  }

  /**
   * @notice Migrates the accounting variables from the current creditline to a brand new one
   * @param _borrower The borrower address
   * @param _maxLimit The new max limit
   * @param _interestApr The new interest APR
   * @param _paymentPeriodInDays The new payment period in days
   * @param _termInDays The new term in days
   * @param _lateFeeApr The new late fee APR
   */
  function migrateCreditLine(
    address _borrower,
    uint256 _maxLimit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256 _principalGracePeriodInDays
  ) public onlyAdmin {
    require(_borrower != address(0) && _paymentPeriodInDays != 0 && _termInDays != 0, "ZERO");

    IV2CreditLine originalCl = creditLine;

    _createAndSetCreditLine(
      _borrower,
      _maxLimit,
      _interestApr,
      _paymentPeriodInDays,
      _termInDays,
      _lateFeeApr,
      _principalGracePeriodInDays
    );

    TranchingLogic.migrateAccountingVariables(originalCl, creditLine);
    TranchingLogic.closeCreditLine(originalCl);
    address originalBorrower = originalCl.borrower();
    address newBorrower = creditLine.borrower();

    // Ensure Roles
    if (originalBorrower != newBorrower) {
      revokeRole(LOCKER_ROLE, originalBorrower);
      grantRole(LOCKER_ROLE, newBorrower);
    }
    // Transfer any funds to new CL
    uint256 clBalance = config.getUSDC().balanceOf(address(originalCl));
    if (clBalance > 0) {
      config.getUSDC().safeERC20TransferFrom(address(originalCl), address(creditLine), clBalance);
    }
    emit CreditLineMigrated(originalCl, creditLine);
  }

  // CreditLine proxy method
  function setLimit(uint256 newAmount) external onlyAdmin {
    return creditLine.setLimit(newAmount);
  }

  function setMaxLimit(uint256 newAmount) external onlyAdmin {
    return creditLine.setMaxLimit(newAmount);
  }

  function getTranche(uint256 tranche) public view override returns (TrancheInfo memory) {
    return _getTrancheInfo(tranche);
  }

  function poolSlices(uint256 index) external view override returns (PoolSlice memory) {
    return _poolSlices[index];
  }

  /**
   * @notice Returns the total junior capital deposited
   * @return The total USDC amount deposited into all junior tranches
   */
  function totalJuniorDeposits() external view override returns (uint256) {
    uint256 total;
    for (uint256 i = 0; i < numSlices; i++) {
      total = total.add(_poolSlices[i].juniorTranche.principalDeposited);
    }
    return total;
  }

  /**
   * @notice Determines the amount of interest and principal redeemable by a particular tokenId
   * @param tokenId The token representing the position
   * @return interestRedeemable The interest available to redeem
   * @return principalRedeemable The principal available to redeem
   */
  function availableToWithdraw(uint256 tokenId) public view override returns (uint256, uint256) {
    IPoolTokens.TokenInfo memory tokenInfo = config.getPoolTokens().getTokenInfo(tokenId);
    TrancheInfo storage trancheInfo = _getTrancheInfo(tokenInfo.tranche);

    if (block.timestamp > trancheInfo.lockedUntil) {
      return TranchingLogic.redeemableInterestAndPrincipal(trancheInfo, tokenInfo);
    } else {
      return (0, 0);
    }
  }

  /* Internal functions  */

  function _collectInterestAndPrincipal(address from, uint256 interest, uint256 principal) internal returns (uint256) {
    uint256 totalReserveAmount = TranchingLogic.applyToAllSlices(
      _poolSlices,
      numSlices,
      interest,
      principal,
      uint256(100).div(config.getReserveDenominator()), // Convert the denonminator to percent
      totalDeployed,
      creditLine,
      juniorFeePercent
    );

    config.getUSDC().safeERC20TransferFrom(from, address(this), principal.add(interest));
    config.getUSDC().safeERC20TransferFrom(address(this), config.reserveAddress(), totalReserveAmount);

    emit ReserveFundsCollected(address(this), totalReserveAmount);

    return totalReserveAmount;
  }

  function _createAndSetCreditLine(
    address _borrower,
    uint256 _maxLimit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256 _principalGracePeriodInDays
  ) internal {
    creditLine = IV2CreditLine(config.getFactory().createCreditLine());
    creditLine.initialize(
      address(config),
      address(this), // Set self as the owner
      _borrower,
      _maxLimit,
      _interestApr,
      _paymentPeriodInDays,
      _termInDays,
      _lateFeeApr,
      _principalGracePeriodInDays
    );
  }

  // // Internal //////////////////////////////////////////////////////////////////

  function _withdraw(
    TrancheInfo storage trancheInfo,
    IPoolTokens.TokenInfo memory tokenInfo,
    uint256 tokenId,
    uint256 amount
  ) internal returns (uint256, uint256) {
    /// @dev NA: not authorized
    require(config.getPoolTokens().isApprovedOrOwner(msg.sender, tokenId), "NA");
    /// @dev IA: invalid amount. Cannot withdraw 0
    require(amount > 0, "IA");
    (uint256 interestRedeemable, uint256 principalRedeemable) = TranchingLogic.redeemableInterestAndPrincipal(
      trancheInfo,
      tokenInfo
    );
    uint256 netRedeemable = interestRedeemable.add(principalRedeemable);

    /// @dev IA: invalid amount. User does not have enough available to redeem
    require(amount <= netRedeemable, "IA");
    /// @dev TL: Tranched Locked
    require(block.timestamp > trancheInfo.lockedUntil, "TL");

    uint256 interestToRedeem = 0;
    uint256 principalToRedeem = 0;

    // If the tranche has not been locked, ensure the deposited amount is correct
    if (trancheInfo.lockedUntil == 0) {
      trancheInfo.principalDeposited = trancheInfo.principalDeposited.sub(amount);

      principalToRedeem = amount;

      config.getPoolTokens().withdrawPrincipal(tokenId, principalToRedeem);
    } else {
      interestToRedeem = Math.min(interestRedeemable, amount);
      principalToRedeem = Math.min(principalRedeemable, amount.sub(interestToRedeem));

      config.getPoolTokens().redeem(tokenId, principalToRedeem, interestToRedeem);
    }

    config.getUSDC().safeERC20TransferFrom(address(this), msg.sender, principalToRedeem.add(interestToRedeem));

    emit WithdrawalMade(msg.sender, tokenInfo.tranche, tokenId, interestToRedeem, principalToRedeem);

    return (interestToRedeem, principalToRedeem);
  }

  function _lockJuniorCapital(uint256 sliceId) internal {
    /// @dev TL: tranch locked
    require(!_locked() && _poolSlices[sliceId].juniorTranche.lockedUntil == 0, "TL");

    TranchingLogic.lockTranche(_poolSlices[sliceId].juniorTranche, config);
  }

  function _lockPool() internal {
    PoolSlice storage slice = _poolSlices[numSlices.sub(1)];
    /// @dev NL: Not locked
    require(slice.juniorTranche.lockedUntil > 0, "NL");
    // Allow locking the pool only once; do not allow extending the lock of an
    // already-locked pool. Otherwise the locker could keep the pool locked
    // indefinitely, preventing withdrawals.
    /// @dev TL: tranche locked. The senior pool has already been locked.
    require(slice.seniorTranche.lockedUntil == 0, "TL");

    uint256 currentTotal = slice.juniorTranche.principalDeposited.add(slice.seniorTranche.principalDeposited);
    creditLine.setLimit(Math.min(creditLine.limit().add(currentTotal), creditLine.maxLimit()));

    // We start the drawdown period, so backers can withdraw unused capital after borrower draws down
    TranchingLogic.lockTranche(slice.juniorTranche, config);
    TranchingLogic.lockTranche(slice.seniorTranche, config);
  }

  function _initializeNextSlice(uint256 newFundableAt) internal {
    /// @dev SL: slice limit
    require(numSlices < 5, "SL");
    TranchingLogic.initializeNextSlice(_poolSlices, numSlices);
    numSlices = numSlices.add(1);
    fundableAt = newFundableAt;
  }

  // If the senior tranche of the current slice is locked, then the pool is not open to any more deposits
  // (could throw off leverage ratio)
  function _locked() internal view returns (bool) {
    return numSlices == 0 || _poolSlices[numSlices - 1].seniorTranche.lockedUntil > 0;
  }

  function _getTrancheInfo(uint256 trancheId) internal view returns (TrancheInfo storage) {
    require(trancheId > 0 && trancheId <= numSlices.mul(TranchingLogic.NUM_TRANCHES_PER_SLICE), "invalid tranche");
    uint256 sliceId = TranchingLogic.trancheIdToSliceIndex(trancheId);
    PoolSlice storage slice = _poolSlices[sliceId];
    TrancheInfo storage trancheInfo = TranchingLogic.isSeniorTrancheId(trancheId)
      ? slice.seniorTranche
      : slice.juniorTranche;
    return trancheInfo;
  }

  function _assess() internal {
    // We need to make sure the pool is locked before we allocate rewards to ensure it's not
    // possible to game rewards by sandwiching an interest payment to an unlocked pool
    // It also causes issues trying to allocate payments to an empty slice (divide by zero)
    /// @dev NL: not locked
    require(_locked(), "NL");

    uint256 interestAccrued = creditLine.totalInterestAccrued();
    (uint256 paymentRemaining, uint256 interestPayment, uint256 principalPayment) = creditLine.assess();
    interestAccrued = creditLine.totalInterestAccrued().sub(interestAccrued);

    // Split the interest accrued proportionally across slices so we know how much interest goes to each slice
    // We need this because the slice start at different times, so we cannot retroactively allocate the interest
    // linearly
    uint256[] memory principalPaymentsPerSlice = new uint256[](numSlices);
    for (uint256 i = 0; i < numSlices; i++) {
      uint256 interestForSlice = TranchingLogic.scaleByFraction(
        interestAccrued,
        _poolSlices[i].principalDeployed,
        totalDeployed
      );
      principalPaymentsPerSlice[i] = TranchingLogic.scaleByFraction(
        principalPayment,
        _poolSlices[i].principalDeployed,
        totalDeployed
      );
      _poolSlices[i].totalInterestAccrued = _poolSlices[i].totalInterestAccrued.add(interestForSlice);
    }

    if (interestPayment > 0 || principalPayment > 0) {
      uint256 reserveAmount = _collectInterestAndPrincipal(
        address(creditLine),
        interestPayment,
        principalPayment.add(paymentRemaining)
      );

      for (uint256 i = 0; i < numSlices; i++) {
        _poolSlices[i].principalDeployed = _poolSlices[i].principalDeployed.sub(principalPaymentsPerSlice[i]);
        totalDeployed = totalDeployed.sub(principalPaymentsPerSlice[i]);
      }

      emit PaymentApplied(
        creditLine.borrower(),
        address(this),
        interestPayment,
        principalPayment,
        paymentRemaining,
        reserveAmount
      );
    }
    emit TranchedPoolAssessed(address(this));
  }

  // // Events ////////////////////////////////////////////////////////////////////

  event DepositMade(address indexed owner, uint256 indexed tranche, uint256 indexed tokenId, uint256 amount);
  event WithdrawalMade(
    address indexed owner,
    uint256 indexed tranche,
    uint256 indexed tokenId,
    uint256 interestWithdrawn,
    uint256 principalWithdrawn
  );

  event TranchedPoolAssessed(address indexed pool);
  event PaymentApplied(
    address indexed payer,
    address indexed pool,
    uint256 interestAmount,
    uint256 principalAmount,
    uint256 remainingAmount,
    uint256 reserveAmount
  );
  // Note: This has to exactly match the even in the TranchingLogic library for events to be emitted
  // correctly
  event SharePriceUpdated(
    address indexed pool,
    uint256 indexed tranche,
    uint256 principalSharePrice,
    int256 principalDelta,
    uint256 interestSharePrice,
    int256 interestDelta
  );
  event ReserveFundsCollected(address indexed from, uint256 amount);
  event CreditLineMigrated(IV2CreditLine indexed oldCreditLine, IV2CreditLine indexed newCreditLine);
  event DrawdownMade(address indexed borrower, uint256 amount);
  event DrawdownsPaused(address indexed pool);
  event DrawdownsUnpaused(address indexed pool);
  event EmergencyShutdown(address indexed pool);
  event TrancheLocked(address indexed pool, uint256 trancheId, uint256 lockedUntil);
  event SliceCreated(address indexed pool, uint256 sliceId);

  // // Modifiers /////////////////////////////////////////////////////////////////

  /// @inheritdoc IVersioned
  function getVersion() external pure override returns (uint8[3] memory version) {
    (version[0], version[1], version[2]) = (MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION);
  }

  modifier onlyLocker() {
    /// @dev NA: not authorized. not locker
    require(hasRole(LOCKER_ROLE, msg.sender), "NA");
    _;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { IV2CreditLine } from "../../interfaces/IV2CreditLine.sol";
import { ITranchedPool } from "../../interfaces/ITranchedPool.sol";
import { IPoolTokens } from "../../interfaces/IPoolTokens.sol";
import { Config } from "./Config.sol";
import { ConfigHelper } from "./ConfigHelper.sol";
import { FixedPoint } from "../../external/FixedPoint.sol";
import { Math } from "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import { SafeMath } from "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

/**
 * @title TranchingLogic
 * @notice Library for handling the payments waterfall
 * @author Goldfinch
 */

library TranchingLogic {
  using SafeMath for uint256;
  using FixedPoint for FixedPoint.Unsigned;
  using FixedPoint for uint256;
  using ConfigHelper for Config;

  struct SliceInfo {
    uint256 reserveFeePercent;
    uint256 interestAccrued;
    uint256 principalAccrued;
  }

  struct ApplyResult {
    uint256 interestRemaining;
    uint256 principalRemaining;
    uint256 reserveDeduction;
    uint256 oldInterestSharePrice;
    uint256 oldPrincipalSharePrice;
  }

  uint256 internal constant FP_SCALING_FACTOR = 1e18;
  uint256 public constant NUM_TRANCHES_PER_SLICE = 2;

  function usdcToSharePrice(uint256 amount, uint256 totalShares) public pure returns (uint256) {
    return totalShares == 0 ? 0 : amount.mul(FP_SCALING_FACTOR).div(totalShares);
  }

  function sharePriceToUsdc(uint256 sharePrice, uint256 totalShares) public pure returns (uint256) {
    return sharePrice.mul(totalShares).div(FP_SCALING_FACTOR);
  }

  function lockTranche(ITranchedPool.TrancheInfo storage tranche, Config config) external {
    tranche.lockedUntil = block.timestamp.add(config.getDrawdownPeriodInSeconds());
    emit TrancheLocked(address(this), tranche.id, tranche.lockedUntil);
  }

  function redeemableInterestAndPrincipal(
    ITranchedPool.TrancheInfo storage trancheInfo,
    IPoolTokens.TokenInfo memory tokenInfo
  ) public view returns (uint256, uint256) {
    // This supports withdrawing before or after locking because principal share price starts at 1
    // and is set to 0 on lock. Interest share price is always 0 until interest payments come back, when it increases
    uint256 maxPrincipalRedeemable = sharePriceToUsdc(trancheInfo.principalSharePrice, tokenInfo.principalAmount);
    // The principalAmount is used as the totalShares because we want the interestSharePrice to be expressed as a
    // percent of total loan value e.g. if the interest is 10% APR, the interestSharePrice should approach a max of 0.1.
    uint256 maxInterestRedeemable = sharePriceToUsdc(trancheInfo.interestSharePrice, tokenInfo.principalAmount);

    uint256 interestRedeemable = maxInterestRedeemable.sub(tokenInfo.interestRedeemed);
    uint256 principalRedeemable = maxPrincipalRedeemable.sub(tokenInfo.principalRedeemed);

    return (interestRedeemable, principalRedeemable);
  }

  function calculateExpectedSharePrice(
    ITranchedPool.TrancheInfo memory tranche,
    uint256 amount,
    ITranchedPool.PoolSlice memory slice
  ) public pure returns (uint256) {
    uint256 sharePrice = usdcToSharePrice(amount, tranche.principalDeposited);
    return _scaleByPercentOwnership(tranche, sharePrice, slice);
  }

  function scaleForSlice(
    ITranchedPool.PoolSlice memory slice,
    uint256 amount,
    uint256 totalDeployed
  ) public pure returns (uint256) {
    return scaleByFraction(amount, slice.principalDeployed, totalDeployed);
  }

  // We need to create this struct so we don't run into a stack too deep error due to too many variables
  function getSliceInfo(
    ITranchedPool.PoolSlice memory slice,
    IV2CreditLine creditLine,
    uint256 totalDeployed,
    uint256 reserveFeePercent
  ) public view returns (SliceInfo memory) {
    (uint256 interestAccrued, uint256 principalAccrued) = getTotalInterestAndPrincipal(
      slice,
      creditLine,
      totalDeployed
    );
    return
      SliceInfo({
        reserveFeePercent: reserveFeePercent,
        interestAccrued: interestAccrued,
        principalAccrued: principalAccrued
      });
  }

  function getTotalInterestAndPrincipal(
    ITranchedPool.PoolSlice memory slice,
    IV2CreditLine creditLine,
    uint256 totalDeployed
  ) public view returns (uint256, uint256) {
    uint256 principalAccrued = creditLine.principalOwed();
    // In addition to principal actually owed, we need to account for early principal payments
    // If the borrower pays back 5K early on a 10K loan, the actual principal accrued should be
    // 5K (balance- deployed) + 0 (principal owed)
    principalAccrued = totalDeployed.sub(creditLine.balance()).add(principalAccrued);
    // Now we need to scale that correctly for the slice we're interested in
    principalAccrued = scaleForSlice(slice, principalAccrued, totalDeployed);
    // Finally, we need to account for partial drawdowns. e.g. If 20K was deposited, and only 10K was drawn down,
    // Then principal accrued should start at 10K (total deposited - principal deployed), not 0. This is because
    // share price starts at 1, and is decremented by what was drawn down.
    uint256 totalDeposited = slice.seniorTranche.principalDeposited.add(slice.juniorTranche.principalDeposited);
    principalAccrued = totalDeposited.sub(slice.principalDeployed).add(principalAccrued);
    return (slice.totalInterestAccrued, principalAccrued);
  }

  function scaleByFraction(uint256 amount, uint256 fraction, uint256 total) public pure returns (uint256) {
    FixedPoint.Unsigned memory totalAsFixedPoint = FixedPoint.fromUnscaledUint(total);
    FixedPoint.Unsigned memory fractionAsFixedPoint = FixedPoint.fromUnscaledUint(fraction);
    return fractionAsFixedPoint.div(totalAsFixedPoint).mul(amount).div(FP_SCALING_FACTOR).rawValue;
  }

  /// @notice apply a payment to all slices
  /// @param poolSlices slices to apply to
  /// @param numSlices number of slices
  /// @param interest amount of interest to apply
  /// @param principal amount of principal to apply
  /// @param reserveFeePercent percentage that protocol will take for reserves
  /// @param totalDeployed total amount of principal deployed
  /// @param creditLine creditline to account for
  /// @param juniorFeePercent percentage the junior tranche will take
  /// @return total amount that will be sent to reserves
  function applyToAllSlices(
    mapping(uint256 => ITranchedPool.PoolSlice) storage poolSlices,
    uint256 numSlices,
    uint256 interest,
    uint256 principal,
    uint256 reserveFeePercent,
    uint256 totalDeployed,
    IV2CreditLine creditLine,
    uint256 juniorFeePercent
  ) external returns (uint256) {
    ApplyResult memory result = TranchingLogic.applyToAllSeniorTranches(
      poolSlices,
      numSlices,
      interest,
      principal,
      reserveFeePercent,
      totalDeployed,
      creditLine,
      juniorFeePercent
    );

    return
      result.reserveDeduction.add(
        TranchingLogic.applyToAllJuniorTranches(
          poolSlices,
          numSlices,
          result.interestRemaining,
          result.principalRemaining,
          reserveFeePercent,
          totalDeployed,
          creditLine
        )
      );
  }

  function applyToAllSeniorTranches(
    mapping(uint256 => ITranchedPool.PoolSlice) storage poolSlices,
    uint256 numSlices,
    uint256 interest,
    uint256 principal,
    uint256 reserveFeePercent,
    uint256 totalDeployed,
    IV2CreditLine creditLine,
    uint256 juniorFeePercent
  ) internal returns (ApplyResult memory) {
    ApplyResult memory seniorApplyResult;
    for (uint256 i = 0; i < numSlices; i++) {
      ITranchedPool.PoolSlice storage slice = poolSlices[i];

      SliceInfo memory sliceInfo = getSliceInfo(slice, creditLine, totalDeployed, reserveFeePercent);

      // Since slices cannot be created when the loan is late, all interest collected can be assumed to split
      // pro-rata across the slices. So we scale the interest and principal to the slice
      ApplyResult memory applyResult = applyToSeniorTranche(
        slice,
        scaleForSlice(slice, interest, totalDeployed),
        scaleForSlice(slice, principal, totalDeployed),
        juniorFeePercent,
        sliceInfo
      );
      emitSharePriceUpdatedEvent(slice.seniorTranche, applyResult);
      seniorApplyResult.interestRemaining = seniorApplyResult.interestRemaining.add(applyResult.interestRemaining);
      seniorApplyResult.principalRemaining = seniorApplyResult.principalRemaining.add(applyResult.principalRemaining);
      seniorApplyResult.reserveDeduction = seniorApplyResult.reserveDeduction.add(applyResult.reserveDeduction);
    }
    return seniorApplyResult;
  }

  function applyToAllJuniorTranches(
    mapping(uint256 => ITranchedPool.PoolSlice) storage poolSlices,
    uint256 numSlices,
    uint256 interest,
    uint256 principal,
    uint256 reserveFeePercent,
    uint256 totalDeployed,
    IV2CreditLine creditLine
  ) internal returns (uint256 totalReserveAmount) {
    for (uint256 i = 0; i < numSlices; i++) {
      SliceInfo memory sliceInfo = getSliceInfo(poolSlices[i], creditLine, totalDeployed, reserveFeePercent);
      // Any remaining interest and principal is then shared pro-rata with the junior slices
      ApplyResult memory applyResult = applyToJuniorTranche(
        poolSlices[i],
        scaleForSlice(poolSlices[i], interest, totalDeployed),
        scaleForSlice(poolSlices[i], principal, totalDeployed),
        sliceInfo
      );
      emitSharePriceUpdatedEvent(poolSlices[i].juniorTranche, applyResult);
      totalReserveAmount = totalReserveAmount.add(applyResult.reserveDeduction);
    }
    return totalReserveAmount;
  }

  function emitSharePriceUpdatedEvent(
    ITranchedPool.TrancheInfo memory tranche,
    ApplyResult memory applyResult
  ) internal {
    emit SharePriceUpdated(
      address(this),
      tranche.id,
      tranche.principalSharePrice,
      int256(tranche.principalSharePrice.sub(applyResult.oldPrincipalSharePrice)),
      tranche.interestSharePrice,
      int256(tranche.interestSharePrice.sub(applyResult.oldInterestSharePrice))
    );
  }

  function applyToSeniorTranche(
    ITranchedPool.PoolSlice storage slice,
    uint256 interestRemaining,
    uint256 principalRemaining,
    uint256 juniorFeePercent,
    SliceInfo memory sliceInfo
  ) internal returns (ApplyResult memory) {
    // First determine the expected share price for the senior tranche. This is the gross amount the senior
    // tranche should receive.
    uint256 expectedInterestSharePrice = calculateExpectedSharePrice(
      slice.seniorTranche,
      sliceInfo.interestAccrued,
      slice
    );
    uint256 expectedPrincipalSharePrice = calculateExpectedSharePrice(
      slice.seniorTranche,
      sliceInfo.principalAccrued,
      slice
    );

    // Deduct the junior fee and the protocol reserve
    uint256 desiredNetInterestSharePrice = scaleByFraction(
      expectedInterestSharePrice,
      uint256(100).sub(juniorFeePercent.add(sliceInfo.reserveFeePercent)),
      uint256(100)
    );
    // Collect protocol fee interest received (we've subtracted this from the senior portion above)
    uint256 reserveDeduction = scaleByFraction(interestRemaining, sliceInfo.reserveFeePercent, uint256(100));
    interestRemaining = interestRemaining.sub(reserveDeduction);
    uint256 oldInterestSharePrice = slice.seniorTranche.interestSharePrice;
    uint256 oldPrincipalSharePrice = slice.seniorTranche.principalSharePrice;
    // Apply the interest remaining so we get up to the netInterestSharePrice
    (interestRemaining, principalRemaining) = _applyBySharePrice(
      slice.seniorTranche,
      interestRemaining,
      principalRemaining,
      desiredNetInterestSharePrice,
      expectedPrincipalSharePrice
    );
    return
      ApplyResult({
        interestRemaining: interestRemaining,
        principalRemaining: principalRemaining,
        reserveDeduction: reserveDeduction,
        oldInterestSharePrice: oldInterestSharePrice,
        oldPrincipalSharePrice: oldPrincipalSharePrice
      });
  }

  function applyToJuniorTranche(
    ITranchedPool.PoolSlice storage slice,
    uint256 interestRemaining,
    uint256 principalRemaining,
    SliceInfo memory sliceInfo
  ) public returns (ApplyResult memory) {
    // Then fill up the junior tranche with all the interest remaining, upto the principal share price
    uint256 expectedInterestSharePrice = slice.juniorTranche.interestSharePrice.add(
      usdcToSharePrice(interestRemaining, slice.juniorTranche.principalDeposited)
    );
    uint256 expectedPrincipalSharePrice = calculateExpectedSharePrice(
      slice.juniorTranche,
      sliceInfo.principalAccrued,
      slice
    );
    uint256 oldInterestSharePrice = slice.juniorTranche.interestSharePrice;
    uint256 oldPrincipalSharePrice = slice.juniorTranche.principalSharePrice;
    (interestRemaining, principalRemaining) = _applyBySharePrice(
      slice.juniorTranche,
      interestRemaining,
      principalRemaining,
      expectedInterestSharePrice,
      expectedPrincipalSharePrice
    );

    // All remaining interest and principal is applied towards the junior tranche as interest
    interestRemaining = interestRemaining.add(principalRemaining);
    // Since any principal remaining is treated as interest (there is "extra" interest to be distributed)
    // we need to make sure to collect the protocol fee on the additional interest (we only deducted the
    // fee on the original interest portion)
    uint256 reserveDeduction = scaleByFraction(principalRemaining, sliceInfo.reserveFeePercent, uint256(100));
    interestRemaining = interestRemaining.sub(reserveDeduction);
    principalRemaining = 0;

    (interestRemaining, principalRemaining) = _applyByAmount(
      slice.juniorTranche,
      interestRemaining.add(principalRemaining),
      0,
      interestRemaining.add(principalRemaining),
      0
    );
    return
      ApplyResult({
        interestRemaining: interestRemaining,
        principalRemaining: principalRemaining,
        reserveDeduction: reserveDeduction,
        oldInterestSharePrice: oldInterestSharePrice,
        oldPrincipalSharePrice: oldPrincipalSharePrice
      });
  }

  function migrateAccountingVariables(IV2CreditLine originalCl, IV2CreditLine newCl) external {
    // Copy over all accounting variables
    newCl.setBalance(originalCl.balance());
    newCl.setLimit(originalCl.limit());
    newCl.setInterestOwed(originalCl.interestOwed());
    newCl.setPrincipalOwed(originalCl.principalOwed());
    newCl.setTermEndTime(originalCl.termEndTime());
    newCl.setNextDueTime(originalCl.nextDueTime());
    newCl.setInterestAccruedAsOf(originalCl.interestAccruedAsOf());
    newCl.setLastFullPaymentTime(originalCl.lastFullPaymentTime());
    newCl.setTotalInterestAccrued(originalCl.totalInterestAccrued());
  }

  function closeCreditLine(IV2CreditLine cl) external {
    // Close out old CL
    cl.setBalance(0);
    cl.setLimit(0);
    cl.setMaxLimit(0);
  }

  function trancheIdToSliceIndex(uint256 trancheId) external pure returns (uint256) {
    return trancheId.sub(1).div(NUM_TRANCHES_PER_SLICE);
  }

  function initializeNextSlice(
    mapping(uint256 => ITranchedPool.PoolSlice) storage poolSlices,
    uint256 sliceIndex
  ) external {
    poolSlices[sliceIndex] = ITranchedPool.PoolSlice({
      seniorTranche: ITranchedPool.TrancheInfo({
        id: sliceIndexToSeniorTrancheId(sliceIndex),
        principalSharePrice: usdcToSharePrice(1, 1),
        interestSharePrice: 0,
        principalDeposited: 0,
        lockedUntil: 0
      }),
      juniorTranche: ITranchedPool.TrancheInfo({
        id: sliceIndexToJuniorTrancheId(sliceIndex),
        principalSharePrice: usdcToSharePrice(1, 1),
        interestSharePrice: 0,
        principalDeposited: 0,
        lockedUntil: 0
      }),
      totalInterestAccrued: 0,
      principalDeployed: 0
    });
  }

  function sliceIndexToJuniorTrancheId(uint256 sliceIndex) public pure returns (uint256) {
    // 0 -> 2
    // 1 -> 4
    return sliceIndex.mul(NUM_TRANCHES_PER_SLICE).add(2);
  }

  function sliceIndexToSeniorTrancheId(uint256 sliceIndex) public pure returns (uint256) {
    // 0 -> 1
    // 1 -> 3
    return sliceIndex.mul(NUM_TRANCHES_PER_SLICE).add(1);
  }

  function isSeniorTrancheId(uint256 trancheId) external pure returns (bool) {
    return trancheId.mod(TranchingLogic.NUM_TRANCHES_PER_SLICE) == 1;
  }

  function isJuniorTrancheId(uint256 trancheId) external pure returns (bool) {
    return trancheId != 0 && trancheId.mod(TranchingLogic.NUM_TRANCHES_PER_SLICE) == 0;
  }

  // // INTERNAL //////////////////////////////////////////////////////////////////

  function _applyToSharePrice(
    uint256 amountRemaining,
    uint256 currentSharePrice,
    uint256 desiredAmount,
    uint256 totalShares
  ) internal pure returns (uint256, uint256) {
    // If no money left to apply, or don't need any changes, return the original amounts
    if (amountRemaining == 0 || desiredAmount == 0) {
      return (amountRemaining, currentSharePrice);
    }
    if (amountRemaining < desiredAmount) {
      // We don't have enough money to adjust share price to the desired level. So just use whatever amount is left
      desiredAmount = amountRemaining;
    }
    uint256 sharePriceDifference = usdcToSharePrice(desiredAmount, totalShares);
    return (amountRemaining.sub(desiredAmount), currentSharePrice.add(sharePriceDifference));
  }

  function _scaleByPercentOwnership(
    ITranchedPool.TrancheInfo memory tranche,
    uint256 amount,
    ITranchedPool.PoolSlice memory slice
  ) internal pure returns (uint256) {
    uint256 totalDeposited = slice.juniorTranche.principalDeposited.add(slice.seniorTranche.principalDeposited);
    return scaleByFraction(amount, tranche.principalDeposited, totalDeposited);
  }

  function _desiredAmountFromSharePrice(
    uint256 desiredSharePrice,
    uint256 actualSharePrice,
    uint256 totalShares
  ) internal pure returns (uint256) {
    // If the desired share price is lower, then ignore it, and leave it unchanged
    if (desiredSharePrice < actualSharePrice) {
      desiredSharePrice = actualSharePrice;
    }
    uint256 sharePriceDifference = desiredSharePrice.sub(actualSharePrice);
    return sharePriceToUsdc(sharePriceDifference, totalShares);
  }

  function _applyByAmount(
    ITranchedPool.TrancheInfo storage tranche,
    uint256 interestRemaining,
    uint256 principalRemaining,
    uint256 desiredInterestAmount,
    uint256 desiredPrincipalAmount
  ) internal returns (uint256, uint256) {
    uint256 totalShares = tranche.principalDeposited;
    uint256 newSharePrice;

    (interestRemaining, newSharePrice) = _applyToSharePrice(
      interestRemaining,
      tranche.interestSharePrice,
      desiredInterestAmount,
      totalShares
    );
    tranche.interestSharePrice = newSharePrice;

    (principalRemaining, newSharePrice) = _applyToSharePrice(
      principalRemaining,
      tranche.principalSharePrice,
      desiredPrincipalAmount,
      totalShares
    );
    tranche.principalSharePrice = newSharePrice;
    return (interestRemaining, principalRemaining);
  }

  function _applyBySharePrice(
    ITranchedPool.TrancheInfo storage tranche,
    uint256 interestRemaining,
    uint256 principalRemaining,
    uint256 desiredInterestSharePrice,
    uint256 desiredPrincipalSharePrice
  ) internal returns (uint256, uint256) {
    uint256 desiredInterestAmount = _desiredAmountFromSharePrice(
      desiredInterestSharePrice,
      tranche.interestSharePrice,
      tranche.principalDeposited
    );
    uint256 desiredPrincipalAmount = _desiredAmountFromSharePrice(
      desiredPrincipalSharePrice,
      tranche.principalSharePrice,
      tranche.principalDeposited
    );
    return
      _applyByAmount(tranche, interestRemaining, principalRemaining, desiredInterestAmount, desiredPrincipalAmount);
  }

  // // Events /////////////////////////////////////////////////////////////////////

  // NOTE: this needs to match the event in TranchedPool
  event TrancheLocked(address indexed pool, uint256 trancheId, uint256 lockedUntil);

  event SharePriceUpdated(
    address indexed pool,
    uint256 indexed tranche,
    uint256 principalSharePrice,
    int256 principalDelta,
    uint256 interestSharePrice,
    int256 interestDelta
  );
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { BaseUpgradeablePausable } from "../BaseUpgradeablePausable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/// @title User Controlled Upgrades (UCU) Proxy Repository
/// A repository maintaing a collection of "lineages" of implementation contracts
///
/// Lineages are a sequence of implementations each lineage can be thought of as
/// a "major" revision of implementations. Implementations between lineages are
/// considered incompatible.
contract ImplementationRepository is BaseUpgradeablePausable {
  address internal constant INVALID_IMPL = address(0);
  uint256 internal constant INVALID_LINEAGE_ID = 0;

  /// @notice returns data that will be delegatedCalled when the given implementation
  ///           is upgraded to
  mapping(address => bytes) public upgradeDataFor;

  /// @dev mapping from one implementation to the succeeding implementation
  mapping(address => address) internal _nextImplementationOf;

  /// @notice Returns the id of the lineage a given implementation belongs to
  mapping(address => uint256) public lineageIdOf;

  /// @dev internal because we expose this through the `currentImplementation(uint256)` api
  mapping(uint256 => address) internal _currentOfLineage;

  /// @notice Returns the id of the most recently created lineage
  uint256 public currentLineageId;

  // //////// External ////////////////////////////////////////////////////////////

  /// @notice initialize the repository's state
  /// @dev reverts if `_owner` is the null address
  /// @dev reverts if `implementation` is not a contract
  /// @param _owner owner of the repository
  /// @param implementation initial implementation in the repository
  function initialize(address _owner, address implementation) external initializer {
    __BaseUpgradeablePausable__init(_owner);
    _createLineage(implementation);
    require(currentLineageId != INVALID_LINEAGE_ID);
  }

  /// @notice set data that will be delegate called when a proxy upgrades to the given `implementation`
  /// @dev reverts when caller is not an admin
  /// @dev reverts when the contract is paused
  /// @dev reverts if the given implementation isn't registered
  function setUpgradeDataFor(address implementation, bytes calldata data) external onlyAdmin whenNotPaused {
    _setUpgradeDataFor(implementation, data);
  }

  /// @notice Create a new lineage of implementations.
  ///
  /// This creates a new "root" of a new lineage
  /// @dev reverts if `implementation` is not a contract
  /// @param implementation implementation that will be the first implementation in the lineage
  /// @return newly created lineage's id
  function createLineage(address implementation) external onlyAdmin whenNotPaused returns (uint256) {
    return _createLineage(implementation);
  }

  /// @notice add a new implementation and set it as the current implementation
  /// @dev reverts if the sender is not an owner
  /// @dev reverts if the contract is paused
  /// @dev reverts if `implementation` is not a contract
  /// @param implementation implementation to append
  function append(address implementation) external onlyAdmin whenNotPaused {
    _append(implementation, currentLineageId);
  }

  /// @notice Append an implementation to a specified lineage
  /// @dev reverts if the contract is paused
  /// @dev reverts if the sender is not an owner
  /// @dev reverts if `implementation` is not a contract
  /// @param implementation implementation to append
  /// @param lineageId id of lineage to append to
  function append(address implementation, uint256 lineageId) external onlyAdmin whenNotPaused {
    _append(implementation, lineageId);
  }

  /// @notice Remove an implementation from the chain and "stitch" together its neighbors
  /// @dev If you have a chain of `A -> B -> C` and I call `remove(B, C)` it will result in `A -> C`
  /// @dev reverts if `previos` is not the ancestor of `toRemove`
  /// @dev we need to provide the previous implementation here to be able to successfully "stitch"
  ///       the chain back together. Because this is an admin action, we can source what the previous
  ///       version is from events.
  /// @param toRemove Implementation to remove
  /// @param previous Implementation that currently has `toRemove` as its successor
  function remove(address toRemove, address previous) external onlyAdmin whenNotPaused {
    _remove(toRemove, previous);
  }

  // //////// External view ////////////////////////////////////////////////////////////

  /// @notice Returns `true` if an implementation has a next implementation set
  /// @param implementation implementation to check
  /// @return The implementation following the given implementation
  function hasNext(address implementation) external view returns (bool) {
    return _nextImplementationOf[implementation] != INVALID_IMPL;
  }

  /// @notice Returns `true` if an implementation has already been added
  /// @param implementation Implementation to check existence of
  /// @return `true` if the implementation has already been added
  function has(address implementation) external view returns (bool) {
    return _has(implementation);
  }

  /// @notice Get the next implementation for a given implementation or
  ///           `address(0)` if it doesn't exist
  /// @dev reverts when contract is paused
  /// @param implementation implementation to get the upgraded implementation for
  /// @return Next Implementation
  function nextImplementationOf(address implementation) external view whenNotPaused returns (address) {
    return _nextImplementationOf[implementation];
  }

  /// @notice Returns `true` if a given lineageId exists
  function lineageExists(uint256 lineageId) external view returns (bool) {
    return _lineageExists(lineageId);
  }

  /// @notice Return the current implementation of a lineage with the given `lineageId`
  function currentImplementation(uint256 lineageId) external view whenNotPaused returns (address) {
    return _currentImplementation(lineageId);
  }

  /// @notice return current implementaton of the current lineage
  function currentImplementation() external view whenNotPaused returns (address) {
    return _currentImplementation(currentLineageId);
  }

  // //////// Internal ////////////////////////////////////////////////////////////

  function _setUpgradeDataFor(address implementation, bytes memory data) internal {
    require(_has(implementation), "unknown impl");
    upgradeDataFor[implementation] = data;
    emit UpgradeDataSet(implementation, data);
  }

  function _createLineage(address implementation) internal virtual returns (uint256) {
    require(Address.isContract(implementation), "not a contract");
    // NOTE: impractical to overflow
    currentLineageId += 1;

    _currentOfLineage[currentLineageId] = implementation;
    lineageIdOf[implementation] = currentLineageId;

    emit Added(currentLineageId, implementation, address(0));
    return currentLineageId;
  }

  function _currentImplementation(uint256 lineageId) internal view returns (address) {
    return _currentOfLineage[lineageId];
  }

  /// @notice Returns `true` if an implementation has already been added
  /// @param implementation implementation to check for
  /// @return `true` if the implementation has already been added
  function _has(address implementation) internal view virtual returns (bool) {
    return lineageIdOf[implementation] != INVALID_LINEAGE_ID;
  }

  /// @notice Set an implementation to the current implementation
  /// @param implementation implementation to set as current implementation
  /// @param lineageId id of lineage to append to
  function _append(address implementation, uint256 lineageId) internal virtual {
    require(Address.isContract(implementation), "not a contract");
    require(!_has(implementation), "exists");
    require(_lineageExists(lineageId), "invalid lineageId");
    require(_currentOfLineage[lineageId] != INVALID_IMPL, "empty lineage");

    address oldImplementation = _currentOfLineage[lineageId];
    _currentOfLineage[lineageId] = implementation;
    lineageIdOf[implementation] = lineageId;
    _nextImplementationOf[oldImplementation] = implementation;

    emit Added(lineageId, implementation, oldImplementation);
  }

  function _remove(address toRemove, address previous) internal virtual {
    require(toRemove != INVALID_IMPL && previous != INVALID_IMPL, "ZERO");
    require(_nextImplementationOf[previous] == toRemove, "Not prev");

    uint256 lineageId = lineageIdOf[toRemove];

    // need to reset the head pointer to the previous version if we remove the head
    if (toRemove == _currentOfLineage[lineageId]) {
      _currentOfLineage[lineageId] = previous;
    }

    _setUpgradeDataFor(toRemove, ""); // reset upgrade data
    _nextImplementationOf[previous] = _nextImplementationOf[toRemove];
    _nextImplementationOf[toRemove] = INVALID_IMPL;
    lineageIdOf[toRemove] = INVALID_LINEAGE_ID;
    emit Removed(lineageId, toRemove);
  }

  function _lineageExists(uint256 lineageId) internal view returns (bool) {
    return lineageId != INVALID_LINEAGE_ID && lineageId <= currentLineageId;
  }

  // //////// Events //////////////////////////////////////////////////////////////
  event Added(uint256 indexed lineageId, address indexed newImplementation, address indexed oldImplementation);
  event Removed(uint256 indexed lineageId, address indexed implementation);
  event UpgradeDataSet(address indexed implementation, bytes data);
}