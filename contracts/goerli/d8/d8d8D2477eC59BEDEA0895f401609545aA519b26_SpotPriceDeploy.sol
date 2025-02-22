/**
 *Submitted for verification at Etherscan.io on 2022-02-14
*/

// Verified using https://dapp.tools

// hevm: flattened sources of src/deploy/SpotPriceDeploy.sol
// SPDX-License-Identifier: MIT AND Unlicense AND Apache-2.0 AND Unlicensed
pragma solidity >=0.8.4 >=0.8.0 <0.9.0;

////// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

/* pragma solidity ^0.8.0; */

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

////// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

/* pragma solidity ^0.8.0; */

/* import "../IERC20.sol"; */

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

////// lib/openzeppelin-contracts/contracts/utils/Context.sol
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/* pragma solidity ^0.8.0; */

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

////// lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

/* pragma solidity ^0.8.0; */

/* import "./IERC20.sol"; */
/* import "./extensions/IERC20Metadata.sol"; */
/* import "../../utils/Context.sol"; */

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
}

////// lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol
// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableSet.sol)

/* pragma solidity ^0.8.0; */

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
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
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
        mapping(bytes32 => uint256) _indexes;
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

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

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
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
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
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
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
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
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
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

////// lib/prb-math/contracts/PRBMath.sol
/* pragma solidity >=0.8.4; */

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivFixedPointOverflow(uint256 prod1);

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivOverflow(uint256 prod1, uint256 denominator);

/// @notice Emitted when one of the inputs is type(int256).min.
error PRBMath__MulDivSignedInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows int256.
error PRBMath__MulDivSignedOverflow(uint256 rAbs);

/// @notice Emitted when the input is MIN_SD59x18.
error PRBMathSD59x18__AbsInputTooSmall();

/// @notice Emitted when ceiling a number overflows SD59x18.
error PRBMathSD59x18__CeilOverflow(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__DivInputTooSmall();

/// @notice Emitted when one of the intermediary unsigned results overflows SD59x18.
error PRBMathSD59x18__DivOverflow(uint256 rAbs);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathSD59x18__ExpInputTooBig(int256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathSD59x18__Exp2InputTooBig(int256 x);

/// @notice Emitted when flooring a number underflows SD59x18.
error PRBMathSD59x18__FloorUnderflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMathSD59x18__FromIntOverflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMathSD59x18__FromIntUnderflow(int256 x);

/// @notice Emitted when the product of the inputs is negative.
error PRBMathSD59x18__GmNegativeProduct(int256 x, int256 y);

/// @notice Emitted when multiplying the inputs overflows SD59x18.
error PRBMathSD59x18__GmOverflow(int256 x, int256 y);

/// @notice Emitted when the input is less than or equal to zero.
error PRBMathSD59x18__LogInputTooSmall(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__MulInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__MulOverflow(uint256 rAbs);

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__PowuOverflow(uint256 rAbs);

/// @notice Emitted when the input is negative.
error PRBMathSD59x18__SqrtNegativeInput(int256 x);

/// @notice Emitted when the calculating the square root overflows SD59x18.
error PRBMathSD59x18__SqrtOverflow(int256 x);

/// @notice Emitted when addition overflows UD60x18.
error PRBMathUD60x18__AddOverflow(uint256 x, uint256 y);

/// @notice Emitted when ceiling a number overflows UD60x18.
error PRBMathUD60x18__CeilOverflow(uint256 x);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathUD60x18__ExpInputTooBig(uint256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathUD60x18__Exp2InputTooBig(uint256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format format overflows UD60x18.
error PRBMathUD60x18__FromUintOverflow(uint256 x);

/// @notice Emitted when multiplying the inputs overflows UD60x18.
error PRBMathUD60x18__GmOverflow(uint256 x, uint256 y);

/// @notice Emitted when the input is less than 1.
error PRBMathUD60x18__LogInputTooSmall(uint256 x);

/// @notice Emitted when the calculating the square root overflows UD60x18.
error PRBMathUD60x18__SqrtOverflow(uint256 x);

/// @notice Emitted when subtraction underflows UD60x18.
error PRBMathUD60x18__SubUnderflow(uint256 x, uint256 y);

/// @dev Common mathematical functions used in both PRBMathSD59x18 and PRBMathUD60x18. Note that this shared library
/// does not always assume the signed 59.18-decimal fixed-point or the unsigned 60.18-decimal fixed-point
/// representation. When it does not, it is explicitly mentioned in the NatSpec documentation.
library PRBMath {
    /// STRUCTS ///

    struct SD59x18 {
        int256 value;
    }

    struct UD60x18 {
        uint256 value;
    }

    /// STORAGE ///

    /// @dev How many trailing decimals can be represented.
    uint256 internal constant SCALE = 1e18;

    /// @dev Largest power of two divisor of SCALE.
    uint256 internal constant SCALE_LPOTD = 262144;

    /// @dev SCALE inverted mod 2^256.
    uint256 internal constant SCALE_INVERSE =
        78156646155174841979727994598816262306175212592076161876661_508869554232690281;

    /// FUNCTIONS ///

    /// @notice Calculates the binary exponent of x using the binary fraction method.
    /// @dev Has to use 192.64-bit fixed-point numbers.
    /// See https://ethereum.stackexchange.com/a/96594/24693.
    /// @param x The exponent as an unsigned 192.64-bit fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function exp2(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            // Start from 0.5 in the 192.64-bit fixed-point format.
            result = 0x800000000000000000000000000000000000000000000000;

            // Multiply the result by root(2, 2^-i) when the bit at position i is 1. None of the intermediary results overflows
            // because the initial result is 2^191 and all magic factors are less than 2^65.
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }

            // We're doing two things at the same time:
            //
            //   1. Multiply the result by 2^n + 1, where "2^n" is the integer part and the one is added to account for
            //      the fact that we initially set the result to 0.5. This is accomplished by subtracting from 191
            //      rather than 192.
            //   2. Convert the result to the unsigned 60.18-decimal fixed-point format.
            //
            // This works because 2^(191-ip) = 2^ip / 2^191, where "ip" is the integer part "2^n".
            result *= SCALE;
            result >>= (191 - (x >> 64));
        }
    }

    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            // No need to shift x any more.
            msb += 1;
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
    ///
    /// Requirements:
    /// - The denominator cannot be zero.
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The multiplicand as an uint256.
    /// @param y The multiplier as an uint256.
    /// @param denominator The divisor as an uint256.
    /// @return result The result as an uint256.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
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
            unchecked {
                result = prod0 / denominator;
            }
            return result;
        }

        // Make sure the result is less than 2^256. Also prevents denominator == 0.
        if (prod1 >= denominator) {
            revert PRBMath__MulDivOverflow(prod1, denominator);
        }

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
        unchecked {
            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 lpotdod = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by lpotdod.
                denominator := div(denominator, lpotdod)

                // Divide [prod1 prod0] by lpotdod.
                prod0 := div(prod0, lpotdod)

                // Flip lpotdod such that it is 2^256 / lpotdod. If lpotdod is zero, then it becomes one.
                lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * lpotdod;

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

    /// @notice Calculates floor(x*y÷1e18) with full precision.
    ///
    /// @dev Variant of "mulDiv" with constant folding, i.e. in which the denominator is always 1e18. Before returning the
    /// final result, we add 1 if (x * y) % SCALE >= HALF_SCALE. Without this, 6.6e-19 would be truncated to 0 instead of
    /// being rounded to 1e-18.  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717.
    ///
    /// Requirements:
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - The body is purposely left uncommented; see the NatSpec comments in "PRBMath.mulDiv" to understand how this works.
    /// - It is assumed that the result can never be type(uint256).max when x and y solve the following two equations:
    ///     1. x * y = type(uint256).max * SCALE
    ///     2. (x * y) % SCALE >= SCALE / 2
    ///
    /// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
    /// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function mulDivFixedPoint(uint256 x, uint256 y) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 >= SCALE) {
            revert PRBMath__MulDivFixedPointOverflow(prod1);
        }

        uint256 remainder;
        uint256 roundUpUnit;
        assembly {
            remainder := mulmod(x, y, SCALE)
            roundUpUnit := gt(remainder, 499999999999999999)
        }

        if (prod1 == 0) {
            unchecked {
                result = (prod0 / SCALE) + roundUpUnit;
                return result;
            }
        }

        assembly {
            result := add(
                mul(
                    or(
                        div(sub(prod0, remainder), SCALE_LPOTD),
                        mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, SCALE_LPOTD), SCALE_LPOTD), 1))
                    ),
                    SCALE_INVERSE
                ),
                roundUpUnit
            )
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev An extension of "mulDiv" for signed numbers. Works by computing the signs and the absolute values separately.
    ///
    /// Requirements:
    /// - None of the inputs can be type(int256).min.
    /// - The result must fit within int256.
    ///
    /// @param x The multiplicand as an int256.
    /// @param y The multiplier as an int256.
    /// @param denominator The divisor as an int256.
    /// @return result The result as an int256.
    function mulDivSigned(
        int256 x,
        int256 y,
        int256 denominator
    ) internal pure returns (int256 result) {
        if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
            revert PRBMath__MulDivSignedInputTooSmall();
        }

        // Get hold of the absolute values of x, y and the denominator.
        uint256 ax;
        uint256 ay;
        uint256 ad;
        unchecked {
            ax = x < 0 ? uint256(-x) : uint256(x);
            ay = y < 0 ? uint256(-y) : uint256(y);
            ad = denominator < 0 ? uint256(-denominator) : uint256(denominator);
        }

        // Compute the absolute value of (x*y)÷denominator. The result must fit within int256.
        uint256 rAbs = mulDiv(ax, ay, ad);
        if (rAbs > uint256(type(int256).max)) {
            revert PRBMath__MulDivSignedOverflow(rAbs);
        }

        // Get the signs of x, y and the denominator.
        uint256 sx;
        uint256 sy;
        uint256 sd;
        assembly {
            sx := sgt(x, sub(0, 1))
            sy := sgt(y, sub(0, 1))
            sd := sgt(denominator, sub(0, 1))
        }

        // XOR over sx, sy and sd. This is checking whether there are one or three negative signs in the inputs.
        // If yes, the result should be negative.
        result = sx ^ sy ^ sd == 0 ? -int256(rAbs) : int256(rAbs);
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }

        // Set the initial guess to the least power of two that is greater than or equal to sqrt(x).
        uint256 xAux = uint256(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }

        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint256 roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }
}

////// lib/prb-math/contracts/PRBMathSD59x18.sol
/* pragma solidity >=0.8.4; */

/* import "./PRBMath.sol"; */

/// @title PRBMathSD59x18
/// @author Paul Razvan Berg
/// @notice Smart contract library for advanced fixed-point math that works with int256 numbers considered to have 18
/// trailing decimals. We call this number representation signed 59.18-decimal fixed-point, since the numbers can have
/// a sign and there can be up to 59 digits in the integer part and up to 18 decimals in the fractional part. The numbers
/// are bound by the minimum and the maximum values permitted by the Solidity type int256.
library PRBMathSD59x18 {
    /// @dev log2(e) as a signed 59.18-decimal fixed-point number.
    int256 internal constant LOG2_E = 1_442695040888963407;

    /// @dev Half the SCALE number.
    int256 internal constant HALF_SCALE = 5e17;

    /// @dev The maximum value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MAX_SD59x18 =
        57896044618658097711785492504343953926634992332820282019728_792003956564819967;

    /// @dev The maximum whole value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MAX_WHOLE_SD59x18 =
        57896044618658097711785492504343953926634992332820282019728_000000000000000000;

    /// @dev The minimum value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MIN_SD59x18 =
        -57896044618658097711785492504343953926634992332820282019728_792003956564819968;

    /// @dev The minimum whole value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MIN_WHOLE_SD59x18 =
        -57896044618658097711785492504343953926634992332820282019728_000000000000000000;

    /// @dev How many trailing decimals can be represented.
    int256 internal constant SCALE = 1e18;

    /// INTERNAL FUNCTIONS ///

    /// @notice Calculate the absolute value of x.
    ///
    /// @dev Requirements:
    /// - x must be greater than MIN_SD59x18.
    ///
    /// @param x The number to calculate the absolute value for.
    /// @param result The absolute value of x.
    function abs(int256 x) internal pure returns (int256 result) {
        unchecked {
            if (x == MIN_SD59x18) {
                revert PRBMathSD59x18__AbsInputTooSmall();
            }
            result = x < 0 ? -x : x;
        }
    }

    /// @notice Calculates the arithmetic average of x and y, rounding down.
    /// @param x The first operand as a signed 59.18-decimal fixed-point number.
    /// @param y The second operand as a signed 59.18-decimal fixed-point number.
    /// @return result The arithmetic average as a signed 59.18-decimal fixed-point number.
    function avg(int256 x, int256 y) internal pure returns (int256 result) {
        // The operations can never overflow.
        unchecked {
            int256 sum = (x >> 1) + (y >> 1);
            if (sum < 0) {
                // If at least one of x and y is odd, we add 1 to the result. This is because shifting negative numbers to the
                // right rounds down to infinity.
                assembly {
                    result := add(sum, and(or(x, y), 1))
                }
            } else {
                // If both x and y are odd, we add 1 to the result. This is because if both numbers are odd, the 0.5
                // remainder gets truncated twice.
                result = sum + (x & y & 1);
            }
        }
    }

    /// @notice Yields the least greatest signed 59.18 decimal fixed-point number greater than or equal to x.
    ///
    /// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
    /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
    ///
    /// Requirements:
    /// - x must be less than or equal to MAX_WHOLE_SD59x18.
    ///
    /// @param x The signed 59.18-decimal fixed-point number to ceil.
    /// @param result The least integer greater than or equal to x, as a signed 58.18-decimal fixed-point number.
    function ceil(int256 x) internal pure returns (int256 result) {
        if (x > MAX_WHOLE_SD59x18) {
            revert PRBMathSD59x18__CeilOverflow(x);
        }
        unchecked {
            int256 remainder = x % SCALE;
            if (remainder == 0) {
                result = x;
            } else {
                // Solidity uses C fmod style, which returns a modulus with the same sign as x.
                result = x - remainder;
                if (x > 0) {
                    result += SCALE;
                }
            }
        }
    }

    /// @notice Divides two signed 59.18-decimal fixed-point numbers, returning a new signed 59.18-decimal fixed-point number.
    ///
    /// @dev Variant of "mulDiv" that works with signed numbers. Works by computing the signs and the absolute values separately.
    ///
    /// Requirements:
    /// - All from "PRBMath.mulDiv".
    /// - None of the inputs can be MIN_SD59x18.
    /// - The denominator cannot be zero.
    /// - The result must fit within int256.
    ///
    /// Caveats:
    /// - All from "PRBMath.mulDiv".
    ///
    /// @param x The numerator as a signed 59.18-decimal fixed-point number.
    /// @param y The denominator as a signed 59.18-decimal fixed-point number.
    /// @param result The quotient as a signed 59.18-decimal fixed-point number.
    function div(int256 x, int256 y) internal pure returns (int256 result) {
        if (x == MIN_SD59x18 || y == MIN_SD59x18) {
            revert PRBMathSD59x18__DivInputTooSmall();
        }

        // Get hold of the absolute values of x and y.
        uint256 ax;
        uint256 ay;
        unchecked {
            ax = x < 0 ? uint256(-x) : uint256(x);
            ay = y < 0 ? uint256(-y) : uint256(y);
        }

        // Compute the absolute value of (x*SCALE)÷y. The result must fit within int256.
        uint256 rAbs = PRBMath.mulDiv(ax, uint256(SCALE), ay);
        if (rAbs > uint256(MAX_SD59x18)) {
            revert PRBMathSD59x18__DivOverflow(rAbs);
        }

        // Get the signs of x and y.
        uint256 sx;
        uint256 sy;
        assembly {
            sx := sgt(x, sub(0, 1))
            sy := sgt(y, sub(0, 1))
        }

        // XOR over sx and sy. This is basically checking whether the inputs have the same sign. If yes, the result
        // should be positive. Otherwise, it should be negative.
        result = sx ^ sy == 1 ? -int256(rAbs) : int256(rAbs);
    }

    /// @notice Returns Euler's number as a signed 59.18-decimal fixed-point number.
    /// @dev See https://en.wikipedia.org/wiki/E_(mathematical_constant).
    function e() internal pure returns (int256 result) {
        result = 2_718281828459045235;
    }

    /// @notice Calculates the natural exponent of x.
    ///
    /// @dev Based on the insight that e^x = 2^(x * log2(e)).
    ///
    /// Requirements:
    /// - All from "log2".
    /// - x must be less than 133.084258667509499441.
    ///
    /// Caveats:
    /// - All from "exp2".
    /// - For any x less than -41.446531673892822322, the result is zero.
    ///
    /// @param x The exponent as a signed 59.18-decimal fixed-point number.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function exp(int256 x) internal pure returns (int256 result) {
        // Without this check, the value passed to "exp2" would be less than -59.794705707972522261.
        if (x < -41_446531673892822322) {
            return 0;
        }

        // Without this check, the value passed to "exp2" would be greater than 192.
        if (x >= 133_084258667509499441) {
            revert PRBMathSD59x18__ExpInputTooBig(x);
        }

        // Do the fixed-point multiplication inline to save gas.
        unchecked {
            int256 doubleScaleProduct = x * LOG2_E;
            result = exp2((doubleScaleProduct + HALF_SCALE) / SCALE);
        }
    }

    /// @notice Calculates the binary exponent of x using the binary fraction method.
    ///
    /// @dev See https://ethereum.stackexchange.com/q/79903/24693.
    ///
    /// Requirements:
    /// - x must be 192 or less.
    /// - The result must fit within MAX_SD59x18.
    ///
    /// Caveats:
    /// - For any x less than -59.794705707972522261, the result is zero.
    ///
    /// @param x The exponent as a signed 59.18-decimal fixed-point number.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function exp2(int256 x) internal pure returns (int256 result) {
        // This works because 2^(-x) = 1/2^x.
        if (x < 0) {
            // 2^59.794705707972522262 is the maximum number whose inverse does not truncate down to zero.
            if (x < -59_794705707972522261) {
                return 0;
            }

            // Do the fixed-point inversion inline to save gas. The numerator is SCALE * SCALE.
            unchecked {
                result = 1e36 / exp2(-x);
            }
        } else {
            // 2^192 doesn't fit within the 192.64-bit format used internally in this function.
            if (x >= 192e18) {
                revert PRBMathSD59x18__Exp2InputTooBig(x);
            }

            unchecked {
                // Convert x to the 192.64-bit fixed-point format.
                uint256 x192x64 = (uint256(x) << 64) / uint256(SCALE);

                // Safe to convert the result to int256 directly because the maximum input allowed is 192.
                result = int256(PRBMath.exp2(x192x64));
            }
        }
    }

    /// @notice Yields the greatest signed 59.18 decimal fixed-point number less than or equal to x.
    ///
    /// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
    /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
    ///
    /// Requirements:
    /// - x must be greater than or equal to MIN_WHOLE_SD59x18.
    ///
    /// @param x The signed 59.18-decimal fixed-point number to floor.
    /// @param result The greatest integer less than or equal to x, as a signed 58.18-decimal fixed-point number.
    function floor(int256 x) internal pure returns (int256 result) {
        if (x < MIN_WHOLE_SD59x18) {
            revert PRBMathSD59x18__FloorUnderflow(x);
        }
        unchecked {
            int256 remainder = x % SCALE;
            if (remainder == 0) {
                result = x;
            } else {
                // Solidity uses C fmod style, which returns a modulus with the same sign as x.
                result = x - remainder;
                if (x < 0) {
                    result -= SCALE;
                }
            }
        }
    }

    /// @notice Yields the excess beyond the floor of x for positive numbers and the part of the number to the right
    /// of the radix point for negative numbers.
    /// @dev Based on the odd function definition. https://en.wikipedia.org/wiki/Fractional_part
    /// @param x The signed 59.18-decimal fixed-point number to get the fractional part of.
    /// @param result The fractional part of x as a signed 59.18-decimal fixed-point number.
    function frac(int256 x) internal pure returns (int256 result) {
        unchecked {
            result = x % SCALE;
        }
    }

    /// @notice Converts a number from basic integer form to signed 59.18-decimal fixed-point representation.
    ///
    /// @dev Requirements:
    /// - x must be greater than or equal to MIN_SD59x18 divided by SCALE.
    /// - x must be less than or equal to MAX_SD59x18 divided by SCALE.
    ///
    /// @param x The basic integer to convert.
    /// @param result The same number in signed 59.18-decimal fixed-point representation.
    function fromInt(int256 x) internal pure returns (int256 result) {
        unchecked {
            if (x < MIN_SD59x18 / SCALE) {
                revert PRBMathSD59x18__FromIntUnderflow(x);
            }
            if (x > MAX_SD59x18 / SCALE) {
                revert PRBMathSD59x18__FromIntOverflow(x);
            }
            result = x * SCALE;
        }
    }

    /// @notice Calculates geometric mean of x and y, i.e. sqrt(x * y), rounding down.
    ///
    /// @dev Requirements:
    /// - x * y must fit within MAX_SD59x18, lest it overflows.
    /// - x * y cannot be negative.
    ///
    /// @param x The first operand as a signed 59.18-decimal fixed-point number.
    /// @param y The second operand as a signed 59.18-decimal fixed-point number.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function gm(int256 x, int256 y) internal pure returns (int256 result) {
        if (x == 0) {
            return 0;
        }

        unchecked {
            // Checking for overflow this way is faster than letting Solidity do it.
            int256 xy = x * y;
            if (xy / x != y) {
                revert PRBMathSD59x18__GmOverflow(x, y);
            }

            // The product cannot be negative.
            if (xy < 0) {
                revert PRBMathSD59x18__GmNegativeProduct(x, y);
            }

            // We don't need to multiply by the SCALE here because the x*y product had already picked up a factor of SCALE
            // during multiplication. See the comments within the "sqrt" function.
            result = int256(PRBMath.sqrt(uint256(xy)));
        }
    }

    /// @notice Calculates 1 / x, rounding toward zero.
    ///
    /// @dev Requirements:
    /// - x cannot be zero.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the inverse.
    /// @return result The inverse as a signed 59.18-decimal fixed-point number.
    function inv(int256 x) internal pure returns (int256 result) {
        unchecked {
            // 1e36 is SCALE * SCALE.
            result = 1e36 / x;
        }
    }

    /// @notice Calculates the natural logarithm of x.
    ///
    /// @dev Based on the insight that ln(x) = log2(x) / log2(e).
    ///
    /// Requirements:
    /// - All from "log2".
    ///
    /// Caveats:
    /// - All from "log2".
    /// - This doesn't return exactly 1 for 2718281828459045235, for that we would need more fine-grained precision.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the natural logarithm.
    /// @return result The natural logarithm as a signed 59.18-decimal fixed-point number.
    function ln(int256 x) internal pure returns (int256 result) {
        // Do the fixed-point multiplication inline to save gas. This is overflow-safe because the maximum value that log2(x)
        // can return is 195205294292027477728.
        unchecked {
            result = (log2(x) * SCALE) / LOG2_E;
        }
    }

    /// @notice Calculates the common logarithm of x.
    ///
    /// @dev First checks if x is an exact power of ten and it stops if yes. If it's not, calculates the common
    /// logarithm based on the insight that log10(x) = log2(x) / log2(10).
    ///
    /// Requirements:
    /// - All from "log2".
    ///
    /// Caveats:
    /// - All from "log2".
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the common logarithm.
    /// @return result The common logarithm as a signed 59.18-decimal fixed-point number.
    function log10(int256 x) internal pure returns (int256 result) {
        if (x <= 0) {
            revert PRBMathSD59x18__LogInputTooSmall(x);
        }

        // Note that the "mul" in this block is the assembly mul operation, not the "mul" function defined in this contract.
        // prettier-ignore
        assembly {
            switch x
            case 1 { result := mul(SCALE, sub(0, 18)) }
            case 10 { result := mul(SCALE, sub(1, 18)) }
            case 100 { result := mul(SCALE, sub(2, 18)) }
            case 1000 { result := mul(SCALE, sub(3, 18)) }
            case 10000 { result := mul(SCALE, sub(4, 18)) }
            case 100000 { result := mul(SCALE, sub(5, 18)) }
            case 1000000 { result := mul(SCALE, sub(6, 18)) }
            case 10000000 { result := mul(SCALE, sub(7, 18)) }
            case 100000000 { result := mul(SCALE, sub(8, 18)) }
            case 1000000000 { result := mul(SCALE, sub(9, 18)) }
            case 10000000000 { result := mul(SCALE, sub(10, 18)) }
            case 100000000000 { result := mul(SCALE, sub(11, 18)) }
            case 1000000000000 { result := mul(SCALE, sub(12, 18)) }
            case 10000000000000 { result := mul(SCALE, sub(13, 18)) }
            case 100000000000000 { result := mul(SCALE, sub(14, 18)) }
            case 1000000000000000 { result := mul(SCALE, sub(15, 18)) }
            case 10000000000000000 { result := mul(SCALE, sub(16, 18)) }
            case 100000000000000000 { result := mul(SCALE, sub(17, 18)) }
            case 1000000000000000000 { result := 0 }
            case 10000000000000000000 { result := SCALE }
            case 100000000000000000000 { result := mul(SCALE, 2) }
            case 1000000000000000000000 { result := mul(SCALE, 3) }
            case 10000000000000000000000 { result := mul(SCALE, 4) }
            case 100000000000000000000000 { result := mul(SCALE, 5) }
            case 1000000000000000000000000 { result := mul(SCALE, 6) }
            case 10000000000000000000000000 { result := mul(SCALE, 7) }
            case 100000000000000000000000000 { result := mul(SCALE, 8) }
            case 1000000000000000000000000000 { result := mul(SCALE, 9) }
            case 10000000000000000000000000000 { result := mul(SCALE, 10) }
            case 100000000000000000000000000000 { result := mul(SCALE, 11) }
            case 1000000000000000000000000000000 { result := mul(SCALE, 12) }
            case 10000000000000000000000000000000 { result := mul(SCALE, 13) }
            case 100000000000000000000000000000000 { result := mul(SCALE, 14) }
            case 1000000000000000000000000000000000 { result := mul(SCALE, 15) }
            case 10000000000000000000000000000000000 { result := mul(SCALE, 16) }
            case 100000000000000000000000000000000000 { result := mul(SCALE, 17) }
            case 1000000000000000000000000000000000000 { result := mul(SCALE, 18) }
            case 10000000000000000000000000000000000000 { result := mul(SCALE, 19) }
            case 100000000000000000000000000000000000000 { result := mul(SCALE, 20) }
            case 1000000000000000000000000000000000000000 { result := mul(SCALE, 21) }
            case 10000000000000000000000000000000000000000 { result := mul(SCALE, 22) }
            case 100000000000000000000000000000000000000000 { result := mul(SCALE, 23) }
            case 1000000000000000000000000000000000000000000 { result := mul(SCALE, 24) }
            case 10000000000000000000000000000000000000000000 { result := mul(SCALE, 25) }
            case 100000000000000000000000000000000000000000000 { result := mul(SCALE, 26) }
            case 1000000000000000000000000000000000000000000000 { result := mul(SCALE, 27) }
            case 10000000000000000000000000000000000000000000000 { result := mul(SCALE, 28) }
            case 100000000000000000000000000000000000000000000000 { result := mul(SCALE, 29) }
            case 1000000000000000000000000000000000000000000000000 { result := mul(SCALE, 30) }
            case 10000000000000000000000000000000000000000000000000 { result := mul(SCALE, 31) }
            case 100000000000000000000000000000000000000000000000000 { result := mul(SCALE, 32) }
            case 1000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 33) }
            case 10000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 34) }
            case 100000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 35) }
            case 1000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 36) }
            case 10000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 37) }
            case 100000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 38) }
            case 1000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 39) }
            case 10000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 40) }
            case 100000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 41) }
            case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 42) }
            case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 43) }
            case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 44) }
            case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 45) }
            case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 46) }
            case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 47) }
            case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 48) }
            case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 49) }
            case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 50) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 51) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 52) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 53) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 54) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 55) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 56) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 57) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 58) }
            default {
                result := MAX_SD59x18
            }
        }

        if (result == MAX_SD59x18) {
            // Do the fixed-point division inline to save gas. The denominator is log2(10).
            unchecked {
                result = (log2(x) * SCALE) / 3_321928094887362347;
            }
        }
    }

    /// @notice Calculates the binary logarithm of x.
    ///
    /// @dev Based on the iterative approximation algorithm.
    /// https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
    ///
    /// Requirements:
    /// - x must be greater than zero.
    ///
    /// Caveats:
    /// - The results are not perfectly accurate to the last decimal, due to the lossy precision of the iterative approximation.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the binary logarithm.
    /// @return result The binary logarithm as a signed 59.18-decimal fixed-point number.
    function log2(int256 x) internal pure returns (int256 result) {
        if (x <= 0) {
            revert PRBMathSD59x18__LogInputTooSmall(x);
        }
        unchecked {
            // This works because log2(x) = -log2(1/x).
            int256 sign;
            if (x >= SCALE) {
                sign = 1;
            } else {
                sign = -1;
                // Do the fixed-point inversion inline to save gas. The numerator is SCALE * SCALE.
                assembly {
                    x := div(1000000000000000000000000000000000000, x)
                }
            }

            // Calculate the integer part of the logarithm and add it to the result and finally calculate y = x * 2^(-n).
            uint256 n = PRBMath.mostSignificantBit(uint256(x / SCALE));

            // The integer part of the logarithm as a signed 59.18-decimal fixed-point number. The operation can't overflow
            // because n is maximum 255, SCALE is 1e18 and sign is either 1 or -1.
            result = int256(n) * SCALE;

            // This is y = x * 2^(-n).
            int256 y = x >> n;

            // If y = 1, the fractional part is zero.
            if (y == SCALE) {
                return result * sign;
            }

            // Calculate the fractional part via the iterative approximation.
            // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
            for (int256 delta = int256(HALF_SCALE); delta > 0; delta >>= 1) {
                y = (y * y) / SCALE;

                // Is y^2 > 2 and so in the range [2,4)?
                if (y >= 2 * SCALE) {
                    // Add the 2^(-m) factor to the logarithm.
                    result += delta;

                    // Corresponds to z/2 on Wikipedia.
                    y >>= 1;
                }
            }
            result *= sign;
        }
    }

    /// @notice Multiplies two signed 59.18-decimal fixed-point numbers together, returning a new signed 59.18-decimal
    /// fixed-point number.
    ///
    /// @dev Variant of "mulDiv" that works with signed numbers and employs constant folding, i.e. the denominator is
    /// always 1e18.
    ///
    /// Requirements:
    /// - All from "PRBMath.mulDivFixedPoint".
    /// - None of the inputs can be MIN_SD59x18
    /// - The result must fit within MAX_SD59x18.
    ///
    /// Caveats:
    /// - The body is purposely left uncommented; see the NatSpec comments in "PRBMath.mulDiv" to understand how this works.
    ///
    /// @param x The multiplicand as a signed 59.18-decimal fixed-point number.
    /// @param y The multiplier as a signed 59.18-decimal fixed-point number.
    /// @return result The product as a signed 59.18-decimal fixed-point number.
    function mul(int256 x, int256 y) internal pure returns (int256 result) {
        if (x == MIN_SD59x18 || y == MIN_SD59x18) {
            revert PRBMathSD59x18__MulInputTooSmall();
        }

        unchecked {
            uint256 ax;
            uint256 ay;
            ax = x < 0 ? uint256(-x) : uint256(x);
            ay = y < 0 ? uint256(-y) : uint256(y);

            uint256 rAbs = PRBMath.mulDivFixedPoint(ax, ay);
            if (rAbs > uint256(MAX_SD59x18)) {
                revert PRBMathSD59x18__MulOverflow(rAbs);
            }

            uint256 sx;
            uint256 sy;
            assembly {
                sx := sgt(x, sub(0, 1))
                sy := sgt(y, sub(0, 1))
            }
            result = sx ^ sy == 1 ? -int256(rAbs) : int256(rAbs);
        }
    }

    /// @notice Returns PI as a signed 59.18-decimal fixed-point number.
    function pi() internal pure returns (int256 result) {
        result = 3_141592653589793238;
    }

    /// @notice Raises x to the power of y.
    ///
    /// @dev Based on the insight that x^y = 2^(log2(x) * y).
    ///
    /// Requirements:
    /// - All from "exp2", "log2" and "mul".
    /// - z cannot be zero.
    ///
    /// Caveats:
    /// - All from "exp2", "log2" and "mul".
    /// - Assumes 0^0 is 1.
    ///
    /// @param x Number to raise to given power y, as a signed 59.18-decimal fixed-point number.
    /// @param y Exponent to raise x to, as a signed 59.18-decimal fixed-point number.
    /// @return result x raised to power y, as a signed 59.18-decimal fixed-point number.
    function pow(int256 x, int256 y) internal pure returns (int256 result) {
        if (x == 0) {
            result = y == 0 ? SCALE : int256(0);
        } else {
            result = exp2(mul(log2(x), y));
        }
    }

    /// @notice Raises x (signed 59.18-decimal fixed-point number) to the power of y (basic unsigned integer) using the
    /// famous algorithm "exponentiation by squaring".
    ///
    /// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring
    ///
    /// Requirements:
    /// - All from "abs" and "PRBMath.mulDivFixedPoint".
    /// - The result must fit within MAX_SD59x18.
    ///
    /// Caveats:
    /// - All from "PRBMath.mulDivFixedPoint".
    /// - Assumes 0^0 is 1.
    ///
    /// @param x The base as a signed 59.18-decimal fixed-point number.
    /// @param y The exponent as an uint256.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function powu(int256 x, uint256 y) internal pure returns (int256 result) {
        uint256 xAbs = uint256(abs(x));

        // Calculate the first iteration of the loop in advance.
        uint256 rAbs = y & 1 > 0 ? xAbs : uint256(SCALE);

        // Equivalent to "for(y /= 2; y > 0; y /= 2)" but faster.
        uint256 yAux = y;
        for (yAux >>= 1; yAux > 0; yAux >>= 1) {
            xAbs = PRBMath.mulDivFixedPoint(xAbs, xAbs);

            // Equivalent to "y % 2 == 1" but faster.
            if (yAux & 1 > 0) {
                rAbs = PRBMath.mulDivFixedPoint(rAbs, xAbs);
            }
        }

        // The result must fit within the 59.18-decimal fixed-point representation.
        if (rAbs > uint256(MAX_SD59x18)) {
            revert PRBMathSD59x18__PowuOverflow(rAbs);
        }

        // Is the base negative and the exponent an odd number?
        bool isNegative = x < 0 && y & 1 == 1;
        result = isNegative ? -int256(rAbs) : int256(rAbs);
    }

    /// @notice Returns 1 as a signed 59.18-decimal fixed-point number.
    function scale() internal pure returns (int256 result) {
        result = SCALE;
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Requirements:
    /// - x cannot be negative.
    /// - x must be less than MAX_SD59x18 / SCALE.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the square root.
    /// @return result The result as a signed 59.18-decimal fixed-point .
    function sqrt(int256 x) internal pure returns (int256 result) {
        unchecked {
            if (x < 0) {
                revert PRBMathSD59x18__SqrtNegativeInput(x);
            }
            if (x > MAX_SD59x18 / SCALE) {
                revert PRBMathSD59x18__SqrtOverflow(x);
            }
            // Multiply x by the SCALE to account for the factor of SCALE that is picked up when multiplying two signed
            // 59.18-decimal fixed-point numbers together (in this case, those two numbers are both the square root).
            result = int256(PRBMath.sqrt(uint256(x * SCALE)));
        }
    }

    /// @notice Converts a signed 59.18-decimal fixed-point number to basic integer form, rounding down in the process.
    /// @param x The signed 59.18-decimal fixed-point number to convert.
    /// @return result The same number in basic integer form.
    function toInt(int256 x) internal pure returns (int256 result) {
        unchecked {
            result = x / SCALE;
        }
    }
}

////// src/aggregator/IAggregatorOracle.sol
/* pragma solidity ^0.8.0; */

interface IAggregatorOracle {
    function oracleExists(address oracle) external view returns (bool);

    function oracleAdd(address oracle) external;

    function oracleRemove(address oracle) external;

    function oracleCount() external view returns (uint256);

    function oracleAt(uint256 index) external view returns (address);

    function setParam(bytes32 param, uint256 value) external;
}

////// src/guarded/Guarded.sol
/* pragma solidity ^0.8.0; */

/// @title Guarded
/// @notice Mixin implementing an authentication scheme on a method level
abstract contract Guarded {
    /// ======== Custom Errors ======== ///

    error Guarded__notRoot();
    error Guarded__notGranted();

    /// ======== Storage ======== ///

    /// @notice Wildcard for granting a caller to call every guarded method
    bytes32 public constant ANY_SIG = keccak256("ANY_SIG");
    /// @notice Wildcard for granting a caller to call every guarded method
    address public constant ANY_CALLER =
        address(uint160(uint256(bytes32(keccak256("ANY_CALLER")))));

    /// @notice Mapping storing who is granted to which method
    /// @dev Method Signature => Caller => Bool
    mapping(bytes32 => mapping(address => bool)) private _canCall;

    /// ======== Events ======== ///

    event AllowCaller(bytes32 sig, address who);
    event BlockCaller(bytes32 sig, address who);

    constructor() {
        // set root
        _setRoot(msg.sender);
    }

    /// ======== Auth ======== ///

    modifier callerIsRoot() {
        if (_canCall[ANY_SIG][msg.sender]) {
            _;
        } else revert Guarded__notRoot();
    }

    modifier checkCaller() {
        if (canCall(msg.sig, msg.sender)) {
            _;
        } else revert Guarded__notGranted();
    }

    /// @notice Grant the right to call method `sig` to `who`
    /// @dev Only the root user (granted `ANY_SIG`) is able to call this method
    /// @param sig Method signature (4Byte)
    /// @param who Address of who should be able to call `sig`
    function allowCaller(bytes32 sig, address who) public callerIsRoot {
        _canCall[sig][who] = true;
        emit AllowCaller(sig, who);
    }

    /// @notice Revoke the right to call method `sig` from `who`
    /// @dev Only the root user (granted `ANY_SIG`) is able to call this method
    /// @param sig Method signature (4Byte)
    /// @param who Address of who should not be able to call `sig` anymore
    function blockCaller(bytes32 sig, address who) public callerIsRoot {
        _canCall[sig][who] = false;
        emit BlockCaller(sig, who);
    }

    /// @notice Returns if `who` can call `sig`
    /// @param sig Method signature (4Byte)
    /// @param who Address of who should be able to call `sig`
    function canCall(bytes32 sig, address who) public view returns (bool) {
        return (_canCall[sig][who] ||
            _canCall[ANY_SIG][who] ||
            _canCall[sig][ANY_CALLER]);
    }

    /// @notice Sets the root user (granted `ANY_SIG`)
    /// @param root Address of who should be set as root
    function _setRoot(address root) internal {
        _canCall[ANY_SIG][root] = true;
        emit AllowCaller(ANY_SIG, root);
    }
}

////// src/oracle/IOracle.sol
/* pragma solidity ^0.8.0; */

interface IOracle {
    function value() external view returns (int256, bool);

    function update() external;
}

////// src/pausable/Pausable.sol
/* pragma solidity ^0.8.0; */

/// @notice Emitted when paused
error Pausable__whenNotPaused_paused();

/// @notice Emitted when not paused
error Pausable__whenPaused_notPaused();

/* import {Guarded} from "src/guarded/Guarded.sol"; */

contract Pausable is Guarded {
    event Paused(address who);
    event Unpaused(address who);

    bool private _paused;

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        // If the contract is paused, throw an error
        if (_paused) {
            revert Pausable__whenNotPaused_paused();
        }
        _;
    }

    modifier whenPaused() {
        // If the contract is not paused, throw an error
        if (_paused == false) {
            revert Pausable__whenPaused_notPaused();
        }
        _;
    }

    function _pause() internal whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

////// src/aggregator/AggregatorOracle.sol
/* pragma solidity ^0.8.0; */

/* import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol"; */

/* import {Guarded} from "src/guarded/Guarded.sol"; */
/* import {Pausable} from "src/pausable/Pausable.sol"; */

/* import {IOracle} from "src/oracle/IOracle.sol"; */
/* import {IAggregatorOracle} from "src/aggregator/IAggregatorOracle.sol"; */

contract AggregatorOracle is Guarded, Pausable, IAggregatorOracle, IOracle {
    // @notice Emitted when trying to add an oracle that already exists
    error AggregatorOracle__addOracle_oracleAlreadyRegistered(address oracle);

    // @notice Emitted when trying to remove an oracle that does not exist
    error AggregatorOracle__removeOracle_oracleNotRegistered(address oracle);

    // @notice Emitted when trying to remove an oracle makes a valid value impossible
    error AggregatorOracle__removeOracle_minimumRequiredValidValues_higherThan_oracleCount(
        uint256 requiredValidValues,
        uint256 oracleCount
    );

    // @notice Emitted when one does not have the right permissions to manage _oracles
    error AggregatorOracle__notAuthorized();

    // @notice Emitted when trying to set the minimum number of valid values higher than the oracle count
    error AggregatorOracle__setParam_requiredValidValues_higherThan_oracleCount(
        uint256 requiredValidValues,
        uint256 oracleCount
    );

    // @notice Emitted when trying to set a parameter that does not exist
    error AggregatorOracle__setParam_unrecognizedParam(bytes32 param);
    /// ======== Events ======== ///

    event OracleAdded(address oracleAddress);
    event OracleRemoved(address oracleAddress);
    event OracleUpdated(bool success, address oracleAddress);
    event OracleValue(int256 value, bool valid);
    event OracleValueFailed(address oracleAddress);
    event AggregatedValue(int256 value, uint256 validValues);
    event SetParam(bytes32 param, uint256 value);

    /// ======== Storage ======== ///

    // List of registered oracles
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _oracles;

    // Current aggregated value
    int256 private _aggregatedValue;

    // Minimum number of valid values required
    // from oracles to consider an aggregated value valid
    uint256 public requiredValidValues;

    // Number of valid values from oracles
    uint256 private _aggregatedValidValues;

    /// @notice Returns the number of oracles
    function oracleCount()
        public
        view
        override(IAggregatorOracle)
        returns (uint256)
    {
        return _oracles.length();
    }

    /// @notice Returns `true` if the oracle is registered
    function oracleExists(address oracle)
        public
        view
        override(IAggregatorOracle)
        returns (bool)
    {
        return _oracles.contains(oracle);
    }

    /// @notice         Returns the address of an oracle at index
    /// @param index_   The internal index of the oracle
    /// @return         Returns the address pf the oracle
    function oracleAt(uint256 index_)
        external
        view
        override(IAggregatorOracle)
        returns (address)
    {
        return _oracles.at(index_);
    }

    /// @notice Adds an oracle to the list of oracles
    /// @dev Reverts if the oracle is already registered
    function oracleAdd(address oracle)
        public
        override(IAggregatorOracle)
        checkCaller
    {
        bool added = _oracles.add(oracle);
        if (added == false) {
            revert AggregatorOracle__addOracle_oracleAlreadyRegistered(oracle);
        }

        emit OracleAdded(oracle);
    }

    /// @notice Removes an oracle from the list of oracles
    /// @dev Reverts if removing the oracle would break the minimum required valid values
    /// @dev Reverts if removing the oracle is not registered
    function oracleRemove(address oracle)
        public
        override(IAggregatorOracle)
        checkCaller
    {
        uint256 localOracleCount = oracleCount();

        // Make sure the minimum number of required valid values is not higher than the oracle count
        if (requiredValidValues >= localOracleCount) {
            revert AggregatorOracle__removeOracle_minimumRequiredValidValues_higherThan_oracleCount(
                requiredValidValues,
                localOracleCount
            );
        }

        // Try to remove
        bool removed = _oracles.remove(oracle);
        if (removed == false) {
            revert AggregatorOracle__removeOracle_oracleNotRegistered(oracle);
        }

        emit OracleRemoved(oracle);
    }

    /// @notice Update values from oracles and return aggregated value
    function update() public override(IOracle) {
        // Call all oracles to update and get values
        uint256 oracleLength = _oracles.length();
        int256[] memory values = new int256[](oracleLength);

        // Count how many oracles have a valid value
        uint256 validValues = 0;

        // Update each oracle and get its value
        for (uint256 i = 0; i < oracleLength; i++) {
            IOracle oracle = IOracle(_oracles.at(i));

            try oracle.update() {
                emit OracleUpdated(true, address(oracle));
                try oracle.value() returns (
                    int256 returnedValue,
                    bool isValid
                ) {
                    if (isValid) {
                        // Add the value to the list of valid values
                        values[validValues] = returnedValue;

                        // Increase count of valid values
                        validValues++;
                    }
                    emit OracleValue(returnedValue, isValid);
                } catch {
                    emit OracleValueFailed(address(oracle));
                    continue;
                }
            } catch {
                emit OracleUpdated(false, address(oracle));
                continue;
            }
        }

        // Aggregate the returned values
        _aggregatedValue = _aggregateValues(values, validValues);

        // Update the number of valid values
        _aggregatedValidValues = validValues;

        emit AggregatedValue(_aggregatedValue, validValues);
    }

    /// @notice Returns the aggregated value
    /// @dev The value is considered valid if
    ///      - the number of valid values is higher than the minimum required valid values
    ///      - the number of required valid values is > 0
    function value()
        public
        view
        override(IOracle)
        whenNotPaused
        returns (int256, bool)
    {
        bool isValid = _aggregatedValidValues >= requiredValidValues &&
            _aggregatedValidValues > 0;
        return (_aggregatedValue, isValid);
    }

    /// @notice Pause contract
    function pause() public checkCaller {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() public checkCaller {
        _unpause();
    }

    function setParam(bytes32 param, uint256 value)
        public
        override(IAggregatorOracle)
        checkCaller
    {
        if (param == "requiredValidValues") {
            uint256 localOracleCount = oracleCount();
            // Should not be able to set the minimum number of required valid values higher than the oracle count
            if (value > localOracleCount) {
                revert AggregatorOracle__setParam_requiredValidValues_higherThan_oracleCount(
                    value,
                    localOracleCount
                );
            }
            requiredValidValues = value;
        } else revert AggregatorOracle__setParam_unrecognizedParam(param);

        emit SetParam(param, value);
    }

    /// @notice Aggregates the values
    function _aggregateValues(int256[] memory values, uint256 validValues)
        internal
        pure
        returns (int256)
    {
        // Avoid division by zero
        if (validValues == 0) {
            return 0;
        }

        int256 sum;
        for (uint256 i = 0; i < validValues; i++) {
            sum += values[i];
        }

        return sum / int256(validValues);
    }
}

////// src/factory/FactoryAggregatorOracle.sol
/* pragma solidity ^0.8.0; */

/* import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol"; */

interface IFactoryAggregatorOracle {
    function create() external returns (address);
}

contract FactoryAggregatorOracle is IFactoryAggregatorOracle {
    function create()
        public
        override(IFactoryAggregatorOracle)
        returns (address)
    {
        AggregatorOracle aggOracle = new AggregatorOracle();
        aggOracle.allowCaller(aggOracle.ANY_SIG(), msg.sender);
        return address(aggOracle);
    }
}

////// src/oracle/Oracle.sol
/* pragma solidity ^0.8.0; */

/* import {IOracle} from "src/oracle/IOracle.sol"; */

/* import {Pausable} from "src/pausable/Pausable.sol"; */

abstract contract Oracle is Pausable, IOracle {
    /// ======== Events ======== ///

    event ValueInvalid();
    event ValueUpdated(int256 currentValue, int256 nextValue);
    event OracleReset();

    /// ======== Storage ======== ///

    uint256 public immutable timeUpdateWindow;

    uint256 public immutable maxValidTime;

    uint256 public lastTimestamp;

    // alpha determines how much influence
    // the new value has on the computed moving average
    // A commonly used value is 2 / (N + 1)
    int256 public immutable alpha;

    // next EMA value
    int256 public nextValue;

    // current EMA value and its validity
    int256 private _currentValue;
    bool private _validReturnedValue;

    constructor(
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) {
        timeUpdateWindow = timeUpdateWindow_;
        maxValidTime = maxValidTime_;
        alpha = alpha_;
        _validReturnedValue = false;
    }

    /// @notice Get the current value of the oracle
    /// @return the current value of the oracle
    /// @return whether the value is valid
    function value()
        public
        view
        override(IOracle)
        whenNotPaused
        returns (int256, bool)
    {
        // Value is considered valid if the value provider successfully returned a value
        // and it was updated before maxValidTime ago
        bool valid = _validReturnedValue &&
            (block.timestamp < lastTimestamp + maxValidTime);
        return (_currentValue, valid);
    }

    function getValue() external virtual returns (int256);

    function update() public override(IOracle) {
        // Not enough time has passed since the last update
        if (lastTimestamp + timeUpdateWindow > block.timestamp) {
            // Exit early if no update is needed
            return;
        }

        // Oracle update should not fail even if the value provider fails to return a value
        try this.getValue() returns (int256 returnedValue) {
            // Update the value using an exponential moving average
            if (_currentValue == 0) {
                // First update takes the current value
                nextValue = returnedValue;
                _currentValue = nextValue;
            } else {
                // Update the current value with the next value
                _currentValue = nextValue;

                // Update the EMA and store it in the next value
                int256 newValue = returnedValue;
                // EMA = EMA(prev) + alpha * (Value - EMA(prev))
                // Scales down because of fixed number of decimals
                nextValue =
                    _currentValue +
                    (alpha * (newValue - _currentValue)) /
                    10**18;
            }

            // Save when the value was last updated
            lastTimestamp = block.timestamp;
            _validReturnedValue = true;

            emit ValueUpdated(_currentValue, nextValue);
        } catch {
            // When a value provider fails, we update the valid flag which will
            // invalidate the value instantly
            _validReturnedValue = false;
            emit ValueInvalid();
        }
    }

    function pause() public checkCaller {
        _pause();
    }

    function unpause() public checkCaller {
        _unpause();
    }

    function reset() public whenPaused checkCaller {
        _currentValue = 0;
        nextValue = 0;
        lastTimestamp = 0;
        _validReturnedValue = false;

        emit OracleReset();
    }
}

////// src/oracle_implementations/discount_rate/utils/Convert.sol
/* pragma solidity ^0.8.0; */

contract Convert {
    function convert(
        int256 x,
        uint256 currentPrecision,
        uint256 targetPrecision
    ) internal pure returns (int256) {
        if (targetPrecision > currentPrecision)
            return x * int256(10**(targetPrecision - currentPrecision));

        return x / int256(10**(currentPrecision - targetPrecision));
    }

    function uconvert(
        uint256 x,
        uint256 currentPrecision,
        uint256 targetPrecision
    ) internal pure returns (uint256) {
        if (targetPrecision > currentPrecision)
            return x * 10**(targetPrecision - currentPrecision);

        return x / 10**(currentPrecision - targetPrecision);
    }
}

////// src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol
/* pragma solidity ^0.8.0; */

// Chainlink Aggregator v3 interface
// https://github.com/smartcontractkit/chainlink/blob/6fea3ccd275466e082a22be690dbaf1609f19dce/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol
interface IChainlinkAggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
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

////// src/oracle_implementations/spot_price/Chainlink/ChainLinkValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol"; */
/* import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol"; */
/* import {Oracle} from "src/oracle/Oracle.sol"; */

contract ChainLinkValueProvider is Oracle, Convert {
    uint8 public immutable underlierDecimals;
    address public underlierAddress;
    address public chainlinkAggregatorAddress;

    /// @notice                             Constructs the Value provider contracts with the needed Chainlink.
    /// @param timeUpdateWindow_            Minimum time between updates of the value
    /// @param maxValidTime_                Maximum time for which the value is valid
    /// @param alpha_                       Alpha parameter for EMA
    /// @param chainlinkAggregatorAddress_  Address of the deployed chainlink aggregator contract.
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address chainlinkAggregatorAddress_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        chainlinkAggregatorAddress = chainlinkAggregatorAddress_;
        underlierDecimals = IChainlinkAggregatorV3Interface(
            chainlinkAggregatorAddress_
        ).decimals();
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        (, int256 answer, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkAggregatorAddress
        ).latestRoundData();

        return convert(answer, underlierDecimals, 18);
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external view returns (string memory) {
        return
            IChainlinkAggregatorV3Interface(chainlinkAggregatorAddress)
                .description();
    }
}

////// src/factory/FactoryChainlinkValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {ChainLinkValueProvider} from "src/oracle_implementations/spot_price/Chainlink/ChainLinkValueProvider.sol"; */

interface IFactoryChainlinkValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address chainlinkAggregatorAddress_
    ) external returns (address);
}

contract FactoryChainlinkValueProvider is IFactoryChainlinkValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address chainlinkAggregatorAddress_
    ) public override(IFactoryChainlinkValueProvider) returns (address) {
        ChainLinkValueProvider chainlinkValueProvider = new ChainLinkValueProvider(
                timeUpdateWindow_,
                maxValidTime_,
                alpha_,
                chainlinkAggregatorAddress_
            );

        return address(chainlinkValueProvider);
    }
}

////// src/relayer/IRelayer.sol
/* pragma solidity ^0.8.0; */

interface IRelayer {
    function check() external returns (bool);

    function execute() external;

    function executeWithRevert() external;
}

////// src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol
/* pragma solidity ^0.8.0; */
/* import {IRelayer} from "src/relayer/IRelayer.sol"; */

interface ICollybusDiscountRateRelayer is IRelayer {
    function oracleCount() external view returns (uint256);

    function oracleExists(address oracle_) external view returns (bool);

    function oracleAt(uint256 index) external view returns (address);

    function oracleAdd(
        address oracle_,
        uint256 tokenId_,
        uint256 minimumThresholdValue_
    ) external;

    function oracleRemove(address oracle_) external;
}

////// src/relayer/ICollybus.sol
/* pragma solidity ^0.8.0; */

// Lightweight interface for Collybus
// Source: https://github.com/fiatdao/fiat-lux/blob/f49a9457fbcbdac1969c35b4714722f00caa462c/src/interfaces/ICollybus.sol
interface ICollybus {
    function updateDiscountRate(uint256 tokenId, uint256 rate) external;

    function updateSpot(address token, uint256 spot) external;
}

////// src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol
/* pragma solidity ^0.8.0; */

/* import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol"; */
/* import {IRelayer} from "src/relayer/IRelayer.sol"; */
/* import {IOracle} from "src/oracle/IOracle.sol"; */
/* import {ICollybus} from "src/relayer/ICollybus.sol"; */
/* import {ICollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol"; */
/* import {Guarded} from "src/guarded/Guarded.sol"; */

contract CollybusDiscountRateRelayer is Guarded, ICollybusDiscountRateRelayer {
    // @notice Emitted when trying to add an oracle that already exists
    error CollybusDiscountRateRelayer__addOracle_oracleAlreadyRegistered(
        address oracle
    );

    // @notice Emitted when trying to add an oracle for a tokenId that already has a registered oracle.
    error CollybusDiscountRateRelayer__addOracle_tokenIdHasOracleRegistered(
        address oracle,
        uint256 tokenId
    );

    // @notice Emitter when trying to remove an oracle that was not registered.
    error CollybusDiscountRateRelayer__removeOracle_oracleNotRegistered(
        address oracle
    );

    // @notice Emitter when check() returns false
    error CollybusDiscountRateRelayer__executeWithRevert_checkFailed();

    struct OracleData {
        bool exists;
        uint256 tokenId;
        int256 lastUpdateValue;
        uint256 minimumThresholdValue;
    }

    /// ======== Events ======== ///

    event OracleAdded(address oracleAddress);
    event OracleRemoved(address oracleAddress);
    event ShouldUpdate(bool shouldUpdate);
    event UpdateOracle(address oracle, int256 value, bool valid);
    event UpdatedCollybus(uint256 tokenId, uint256 rate);

    /// ======== Storage ======== ///

    address public immutable collybus;

    // Mapping that will hold all the oracle params needed by the contract
    mapping(address => OracleData) private _oraclesData;

    // Mapping used tokenId's
    mapping(uint256 => bool) public _tokenIds;

    // Array used for iterating the oracles.
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _oracleList;

    constructor(address collybusAddress_) {
        collybus = collybusAddress_;
    }

    /// @notice Returns the number of registered oracles.
    /// @return the total number of oracles.
    function oracleCount()
        public
        view
        override(ICollybusDiscountRateRelayer)
        returns (uint256)
    {
        return _oracleList.length();
    }

    /// @notice         Returns the address of an oracle at index
    /// @dev            Reverts if the index is out of bounds
    /// @param index_   The internal index of the oracle
    /// @return         Returns the address pf the oracle
    function oracleAt(uint256 index_)
        external
        view
        override(ICollybusDiscountRateRelayer)
        returns (address)
    {
        return _oracleList.at(index_);
    }

    /// @notice         Checks whether an oracle is registered.
    /// @param oracle_  The address of the oracle.
    /// @return         Returns 'true' if the oracle is registered.
    function oracleExists(address oracle_)
        public
        view
        override(ICollybusDiscountRateRelayer)
        returns (bool)
    {
        return _oraclesData[oracle_].exists;
    }

    /// @notice                         Registers an oracle to a token id and set the minimum threshold delta value
    ///                                 calculate the annual rate.
    /// @param oracle_                  The address of the oracle.
    /// @param tokenId_                 The unique token id for which this oracle will update rate values.
    /// @param minimumThresholdValue_   The minimum value delta threshold needed in order to push values to the Collybus
    /// @dev                            Reverts if the oracle is already registered or if the rate id is taken by another oracle.
    function oracleAdd(
        address oracle_,
        uint256 tokenId_,
        uint256 minimumThresholdValue_
    ) public override(ICollybusDiscountRateRelayer) checkCaller {
        // Make sure the oracle was not added previously
        if (oracleExists(oracle_)) {
            revert CollybusDiscountRateRelayer__addOracle_oracleAlreadyRegistered(
                oracle_
            );
        }

        // Make sure there are no existing oracles registered for this rate Id
        if (_tokenIds[tokenId_]) {
            revert CollybusDiscountRateRelayer__addOracle_tokenIdHasOracleRegistered(
                oracle_,
                tokenId_
            );
        }

        // Add oracle in the oracle address array that is used for iterating.
        _oracleList.add(oracle_);

        // Mark the token Id as used
        _tokenIds[tokenId_] = true;

        // Update the oracle address => data mapping with the oracle parameters.
        _oraclesData[oracle_] = OracleData({
            exists: true,
            lastUpdateValue: 0,
            tokenId: tokenId_,
            minimumThresholdValue: minimumThresholdValue_
        });

        emit OracleAdded(oracle_);
    }

    /// @notice         Unregisters an oracle.
    /// @param oracle_  The address of the oracle.
    /// @dev            Reverts if the oracle is not registered
    function oracleRemove(address oracle_)
        public
        override(ICollybusDiscountRateRelayer)
        checkCaller
    {
        // Make sure the oracle is registered
        if (!oracleExists(oracle_)) {
            revert CollybusDiscountRateRelayer__removeOracle_oracleNotRegistered(
                oracle_
            );
        }

        // Reset the tokenId Mapping
        _tokenIds[_oraclesData[oracle_].tokenId] = false;

        // Remove the oracle from the list
        // This returns true/false depending on if the oracle was removed
        _oracleList.remove(oracle_);

        // Reset struct to default values
        delete _oraclesData[oracle_];

        emit OracleRemoved(oracle_);
    }

    /// @notice Returns the oracle data for a given oracle address
    /// @param oracle_ The address of the oracle
    /// @return Returns the oracle data as `OracleData`
    function oraclesData(address oracle_)
        public
        view
        returns (OracleData memory)
    {
        return _oraclesData[oracle_];
    }

    // function oraclesData()

    /// @notice Iterates and updates each oracle until it finds one that should push data
    ///         in the Collybus, more exactly, the delta change in value is bigger than the minimum
    ///         threshold value set for that oracle.
    /// @dev    Oracles that return invalid values are skipped.
    /// @return Returns 'true' if at least one oracle should update data in the Collybus
    function check() public override(IRelayer) returns (bool) {
        uint256 arrayLength = _oracleList.length();
        for (uint256 i = 0; i < arrayLength; i++) {
            // Cache oracle address
            address localOracle = _oracleList.at(i);

            // Trigger the oracle to update its data
            IOracle(localOracle).update();

            (int256 rate, bool isValid) = IOracle(localOracle).value();

            emit UpdateOracle(localOracle, rate, isValid);
            if (!isValid) continue;

            if (
                absDelta(_oraclesData[localOracle].lastUpdateValue, rate) >=
                _oraclesData[localOracle].minimumThresholdValue
            ) {
                emit ShouldUpdate(true);
                return true;
            }
        }

        emit ShouldUpdate(false);
        return false;
    }

    /// @notice Iterates and updates all the oracles and pushes the updated data to Collybus for the
    ///         oracles that have delta changes in value bigger than the minimum threshold values.
    /// @dev    Oracles that return invalid values are skipped.
    function execute() public override(IRelayer) {
        // Update Collybus all tokenIds with the new discount rate
        uint256 arrayLength = _oracleList.length();
        for (uint256 i = 0; i < arrayLength; i++) {
            // Cache oracle address
            address localOracle = _oracleList.at(i);

            // We always update the oracles before retrieving the rates
            IOracle(localOracle).update();
            (int256 rate, bool isValid) = IOracle(localOracle).value();

            if (!isValid) continue;

            OracleData storage oracleData = _oraclesData[localOracle];

            // If the change in delta rate from the last update is bigger than the threshold value push
            // the rates to Collybus
            if (
                absDelta(oracleData.lastUpdateValue, rate) >=
                oracleData.minimumThresholdValue
            ) {
                oracleData.lastUpdateValue = rate;
                ICollybus(collybus).updateDiscountRate(
                    oracleData.tokenId,
                    uint256(rate)
                );

                emit UpdatedCollybus(oracleData.tokenId, uint256(rate));
            }
        }
    }

    /// @notice The function will call `execute()` if `check()` returns `true`, otherwise it will revert
    /// @dev This method is needed for services that try to updates the oracles on each block and only call the method if it doesn't fail
    function executeWithRevert() public override(IRelayer) {
        if (check()) {
            execute();
        } else {
            revert CollybusDiscountRateRelayer__executeWithRevert_checkFailed();
        }
    }

    /// @notice     Computes the positive delta between two signed int256
    /// @param a    First parameter.
    /// @param b    Second parameter.
    /// @return     Returns the positive delta.
    function absDelta(int256 a, int256 b) internal pure returns (uint256) {
        if (a > b) {
            return uint256(a - b);
        }
        return uint256(b - a);
    }
}

////// src/factory/FactoryCollybusDiscountRateRelayer.sol
/* pragma solidity ^0.8.0; */

/* import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol"; */

interface IFactoryCollybusDiscountRateRelayer {
    function create(address collybus_) external returns (address);
}

contract FactoryCollybusDiscountRateRelayer is
    IFactoryCollybusDiscountRateRelayer
{
    function create(address collybus_)
        public
        override(IFactoryCollybusDiscountRateRelayer)
        returns (address)
    {
        CollybusDiscountRateRelayer discountRateRelayer = new CollybusDiscountRateRelayer(
                collybus_
            );

        discountRateRelayer.allowCaller(
            discountRateRelayer.ANY_SIG(),
            msg.sender
        );

        return address(discountRateRelayer);
    }
}

////// src/relayer/CollybusSpotPrice/ICollybusSpotPriceRelayer.sol
/* pragma solidity ^0.8.0; */
/* import {IRelayer} from "src/relayer/IRelayer.sol"; */

interface ICollybusSpotPriceRelayer is IRelayer {
    function oracleCount() external view returns (uint256);

    function oracleAdd(
        address oracle_,
        address tokenAddress_,
        uint256 minimumThresholdValue_
    ) external;

    function oracleRemove(address oracle_) external;

    function oracleExists(address oracle_) external view returns (bool);

    function oracleAt(uint256 index) external view returns (address);
}

////// src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol
/* pragma solidity ^0.8.0; */

/* import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol"; */
/* import {ICollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/ICollybusSpotPriceRelayer.sol"; */
/* import {IRelayer} from "src/relayer/IRelayer.sol"; */
/* import {IOracle} from "src/oracle/IOracle.sol"; */
/* import {ICollybus} from "src/relayer/ICollybus.sol"; */
/* import {Guarded} from "src/guarded/Guarded.sol"; */

contract CollybusSpotPriceRelayer is Guarded, ICollybusSpotPriceRelayer {
    // @notice Emitted when trying to add an oracle that already exists
    error CollybusSpotPriceRelayer__addOracle_oracleAlreadyRegistered(
        address oracle
    );

    // @notice Emitted when trying to add an oracle for a tokenId that already has a registered oracle
    error CollybusSpotPriceRelayer__addOracle_tokenIdHasOracleRegistered(
        address oracle,
        address tokenAddress
    );

    // @notice Emitter when trying to remove an oracle that was not registered
    error CollybusSpotPriceRelayer__removeOracle_oracleNotRegistered(
        address oracle
    );

    // @notice Emitter when check() returns false
    error CollybusSpotPriceRelayer__executeWithRevert_checkFailed();

    struct OracleData {
        bool exists;
        address tokenAddress;
        int256 lastUpdateValue;
        uint256 minimumThresholdValue;
    }

    /// ======== Events ======== ///

    event OracleAdded(address oracleAddress);
    event OracleRemoved(address oracleAddress);
    event ShouldUpdate(bool shouldUpdate);
    event UpdateOracle(address oracle, int256 value, bool valid);
    event UpdatedCollybus(address tokenAddress, uint256 rate);

    /// ======== Storage ======== ///

    address public immutable collybus;

    // Mapping that will hold all the oracle params needed by the contract
    mapping(address => OracleData) private _oraclesData;

    // Mapping used to track used Rate Ids.
    mapping(address => bool) public tokenIds;

    // Array used for iterating the oracles.
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _oracleList;

    constructor(address collybusAddress_) {
        collybus = collybusAddress_;
    }

    /// @notice Returns the number of registered oracles.
    /// @return the total number of oracles.
    function oracleCount()
        public
        view
        override(ICollybusSpotPriceRelayer)
        returns (uint256)
    {
        return _oracleList.length();
    }

    /// @notice         Returns the address of an oracle at index
    /// @dev            Reverts if the index is out of bounds
    /// @param index_   The internal index of the oracle
    /// @return         Returns the address pf the oracle
    function oracleAt(uint256 index_)
        external
        view
        override(ICollybusSpotPriceRelayer)
        returns (address)
    {
        return _oracleList.at(index_);
    }

    /// @notice         Checks whether an oracle is registered
    /// @param oracle_  The address of the oracle
    /// @return         Returns 'true' if the oracle is registered
    function oracleExists(address oracle_)
        public
        view
        override(ICollybusSpotPriceRelayer)
        returns (bool)
    {
        return _oraclesData[oracle_].exists;
    }

    /// @notice                         Registers an oracle to a token id and set the minimum threshold delta value
    ///                                 calculate the annual rate.
    /// @param oracle_                  The address of the oracle.
    /// @param tokenAddress_            The address of the underlier token.
    /// @param minimumThresholdValue_   The minimum value delta threshold needed in order to push values to the Collybus
    /// @dev                            Reverts if the oracle is already registered or if the rate id is taken by another oracle.
    function oracleAdd(
        address oracle_,
        address tokenAddress_,
        uint256 minimumThresholdValue_
    ) public override(ICollybusSpotPriceRelayer) checkCaller {
        // Make sure the oracle was not added previously
        if (oracleExists(oracle_)) {
            revert CollybusSpotPriceRelayer__addOracle_oracleAlreadyRegistered(
                oracle_
            );
        }

        // Make sure there are no existing oracles registered for this rate Id
        if (tokenIds[tokenAddress_]) {
            revert CollybusSpotPriceRelayer__addOracle_tokenIdHasOracleRegistered(
                oracle_,
                tokenAddress_
            );
        }

        // Add oracle in the oracle address array that is used for iterating.
        _oracleList.add(oracle_);

        // Mark the token address as used
        tokenIds[tokenAddress_] = true;

        // Update the oracle address => data mapping with the oracle parameters.
        _oraclesData[oracle_] = OracleData({
            exists: true,
            lastUpdateValue: 0,
            tokenAddress: tokenAddress_,
            minimumThresholdValue: minimumThresholdValue_
        });

        emit OracleAdded(oracle_);
    }

    /// @notice         Unregisters an oracle.
    /// @param oracle_  The address of the oracle.
    /// @dev            Reverts if the oracle is not registered
    function oracleRemove(address oracle_)
        public
        override(ICollybusSpotPriceRelayer)
        checkCaller
    {
        // Make sure the oracle is registered
        if (!oracleExists(oracle_)) {
            revert CollybusSpotPriceRelayer__removeOracle_oracleNotRegistered(
                oracle_
            );
        }

        // Reset the token address Mapping
        tokenIds[_oraclesData[oracle_].tokenAddress] = false;

        // Remove the oracle from the list
        // This returns true/false depending on if the oracle was removed
        _oracleList.remove(oracle_);

        // Reset struct to default values
        delete _oraclesData[oracle_];

        emit OracleRemoved(oracle_);
    }

    /// @notice Returns the oracle data for a given oracle address
    /// @param oracle_ The address of the oracle
    /// @return Returns the oracle data as `OracleData`
    function oraclesData(address oracle_)
        public
        view
        returns (OracleData memory)
    {
        return _oraclesData[oracle_];
    }

    /// @notice Iterates and updates each oracle until it finds one that should push data
    ///         in the Collybus, more exactly, the delta change in value is greater than the minimum
    ///         threshold value set for that oracle.
    /// @dev    Oracles that return invalid values are skipped.
    /// @return Returns 'true' if at least one oracle should update data in the Collybus
    function check() public override(IRelayer) returns (bool) {
        uint256 arrayLength = _oracleList.length();
        for (uint256 i = 0; i < arrayLength; i++) {
            // Cache oracle address
            address localOracle = _oracleList.at(i);

            // Trigger the oracle to update its data
            IOracle(localOracle).update();

            (int256 rate, bool isValid) = IOracle(localOracle).value();

            emit UpdateOracle(localOracle, rate, isValid);
            if (!isValid) continue;

            if (
                absDelta(_oraclesData[localOracle].lastUpdateValue, rate) >=
                _oraclesData[localOracle].minimumThresholdValue
            ) {
                emit ShouldUpdate(true);
                return true;
            }
        }

        emit ShouldUpdate(false);
        return false;
    }

    /// @notice Iterates and updates all the oracles and pushes the updated data to Collybus for the
    ///         oracles that have delta changes in value greater than the minimum threshold values.
    /// @dev    Oracles that return invalid values are skipped.
    function execute() public override(IRelayer) {
        // Update Collybus all tokenIds with the new discount rate
        uint256 arrayLength = _oracleList.length();
        for (uint256 i = 0; i < arrayLength; i++) {
            // Cache oracle address
            address localOracle = _oracleList.at(i);

            // We always update the oracles before retrieving the rates
            IOracle(localOracle).update();
            (int256 rate, bool isValid) = IOracle(localOracle).value();

            if (!isValid) continue;

            OracleData storage oracleData = _oraclesData[localOracle];

            // If the change in delta rate from the last update is greater or equal than the threshold value
            // push the rates to Collybus
            if (
                absDelta(oracleData.lastUpdateValue, rate) >=
                oracleData.minimumThresholdValue
            ) {
                oracleData.lastUpdateValue = rate;
                ICollybus(collybus).updateSpot(
                    oracleData.tokenAddress,
                    uint256(rate)
                );

                emit UpdatedCollybus(oracleData.tokenAddress, uint256(rate));
            }
        }
    }

    /// @notice The function will call `execute()` if `check()` returns `true`, otherwise it will revert
    /// @dev This method is needed for services that try to updates the oracles on each block and only call the method if it doesn't fail
    function executeWithRevert() public override(IRelayer) {
        if (check()) {
            execute();
        } else {
            revert CollybusSpotPriceRelayer__executeWithRevert_checkFailed();
        }
    }

    /// @notice     Computes the positive delta between two signed int256
    /// @param a    First parameter.
    /// @param b    Second parameter.
    /// @return     Returns the positive delta.
    function absDelta(int256 a, int256 b) internal pure returns (uint256) {
        if (a > b) {
            return uint256(a - b);
        }
        return uint256(b - a);
    }
}

////// src/factory/FactoryCollybusSpotPriceRelayer.sol
/* pragma solidity ^0.8.0; */

/* import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol"; */

interface IFactoryCollybusSpotPriceRelayer {
    function create(address collybus_) external returns (address);
}

contract FactoryCollybusSpotPriceRelayer is IFactoryCollybusSpotPriceRelayer {
    function create(address collybus_)
        public
        override(IFactoryCollybusSpotPriceRelayer)
        returns (address)
    {
        CollybusSpotPriceRelayer spotPriceRelayer = new CollybusSpotPriceRelayer(
                collybus_
            );
        spotPriceRelayer.allowCaller(spotPriceRelayer.ANY_SIG(), msg.sender);
        return address(spotPriceRelayer);
    }
}

////// src/oracle_implementations/discount_rate/ElementFi/IVault.sol
/* pragma solidity ^0.8.0; */

/* import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; */

/**
 * @dev partial external interface for the Vault core contract
 * full source available here:
 *https://github.com/alcuadrado/balancer-core-v2/blob/f153c38c5ee8911680363eaf52aad0d691896a75/contracts/vault/interfaces/IVault.sol
 */
interface IVault {
    /**
     * @dev Returns detailed information for a Pool's registered token.
     *
     * `cash` is the number of tokens the Vault currently holds for the Pool. `managed` is the number of tokens
     * withdrawn and held outside the Vault by the Pool's token Asset Manager. The Pool's total balance for `token`
     * equals the sum of `cash` and `managed`.
     *
     * Internally, `cash` and `managed` are stored using 112 bits. No action can ever cause a Pool's token `cash`,
     * `managed` or `total` balance to be greater than 2^112 - 1.
     *
     * `lastChangeBlock` is the number of the block in which `token`'s total balance was last modified (via either a
     * join, exit, swap, or Asset Manager update). This value is useful to avoid so-called 'sandwich attacks', for
     * example when developing price oracles. A change of zero (e.g. caused by a swap with amount zero) is considered a
     * change for this purpose, and will update `lastChangeBlock`.
     *
     * `assetManager` is the Pool's token Asset Manager.
     */
    function getPoolTokenInfo(bytes32 poolId, IERC20 token)
        external
        view
        returns (
            uint256 cash,
            uint256 managed,
            uint256 lastChangeBlock,
            address assetManager
        );
}

////// src/oracle_implementations/discount_rate/ElementFi/ElementFiValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; */
/* import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; */
/* import {Oracle} from "src/oracle/Oracle.sol"; */
/* import {IVault} from "./IVault.sol"; */
/* import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol"; */

/* import "lib/prb-math/contracts/PRBMathSD59x18.sol"; */

contract ElementFiValueProvider is Oracle, Convert {
    // @notice Emitted when trying to add pull a value for an expired pool
    error ElementFiValueProvider__value_maturityLessThanBlocktime(
        uint256 maturity
    );

    bytes32 public immutable poolId;
    address public immutable balancerVaultAddress;
    address public immutable poolToken;
    uint8 public immutable poolTokenDecimals;
    address public immutable underlier;
    uint8 public immutable underlierDecimals;
    address public immutable ePTokenBond;
    uint8 public immutable ePTokenBondDecimals;
    int256 public immutable timeScale;
    uint256 public immutable maturity;

    /// @notice                      Constructs the Value provider contracts with the needed Element data in order to
    ///                              calculate the annual rate.
    /// @param timeUpdateWindow_     Minimum time between updates of the value
    /// @param maxValidTime_         Maximum time for which the value is valid
    /// @param alpha_                Alpha parameter for EMA
    /// @param poolId_               poolID of the pool
    /// @param balancerVaultAddress_ Address of the balancer vault
    /// @param poolToken_            Address of the pool (LP token) contract
    /// @param underlier_            Address of the underlier IERC20 token
    /// @param ePTokenBond_          Address of the bond IERC20 token
    /// @param timeScale_            Time scale used on this pool (i.e. 1/(timeStretch*secondsPerYear)) in 59x18 fixed point
    /// @param maturity_             The Maturity timestamp
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        bytes32 poolId_,
        address balancerVaultAddress_,
        address poolToken_,
        address underlier_,
        address ePTokenBond_,
        int256 timeScale_,
        uint256 maturity_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        poolId = poolId_;
        balancerVaultAddress = balancerVaultAddress_;
        poolToken = poolToken_;
        poolTokenDecimals = ERC20(poolToken_).decimals();
        underlier = underlier_;
        underlierDecimals = ERC20(underlier_).decimals();
        ePTokenBond = ePTokenBond_;
        ePTokenBondDecimals = ERC20(ePTokenBond_).decimals();
        timeScale = timeScale_;
        maturity = maturity_;
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Returns if called after the maturity date
    /// @return result The result as an signed 59.18-decimal fixed-point number
    function getValue() external view override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturity) {
            revert ElementFiValueProvider__value_maturityLessThanBlocktime(
                maturity
            );
        }

        // The base token reserves from the balancer vault in 18 digits precision
        (uint256 baseReserves, , , ) = IVault(balancerVaultAddress)
            .getPoolTokenInfo(poolId, IERC20(underlier));
        baseReserves = uconvert(baseReserves, underlierDecimals, 18);

        // The epToken balance from the balancer vault in 18 digits precision
        (uint256 ePTokenBalance, , , ) = IVault(balancerVaultAddress)
            .getPoolTokenInfo(poolId, IERC20(ePTokenBond));
        ePTokenBalance = uconvert(ePTokenBalance, ePTokenBondDecimals, 18);

        // The number of LP shares in 18 digits precision
        // These reflect the virtual reserves of the epToken in the AMM
        uint256 totalSupply = IERC20(poolToken).totalSupply();
        totalSupply = uconvert(totalSupply, poolTokenDecimals, 18);

        // The reserves ratio in signed 59.18 format
        int256 reservesRatio59x18 = PRBMathSD59x18.div(
            int256(ePTokenBalance + totalSupply),
            int256(baseReserves)
        );

        // The implied per-second rate in signed 59.18 format
        int256 ratePerSecond59x18 = (PRBMathSD59x18.pow(
            reservesRatio59x18,
            timeScale
        ) - PRBMathSD59x18.SCALE);

        // The result is a 59.18 fixed-point number.
        return ratePerSecond59x18;
    }
}

////// src/factory/FactoryElementFiValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {ElementFiValueProvider} from "src/oracle_implementations/discount_rate/ElementFi/ElementFiValueProvider.sol"; */

interface IFactoryElementFiValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        bytes32 poolId_,
        address balancerVaultAddress_,
        address poolToken_,
        address underlier_,
        address ePTokenBond_,
        int256 timeScale_,
        uint256 maturity_
    ) external returns (address);
}

contract FactoryElementFiValueProvider is IFactoryElementFiValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        bytes32 poolId_,
        address balancerVaultAddress_,
        address poolToken_,
        address underlier_,
        address ePTokenBond_,
        int256 timeScale_,
        uint256 maturity_
    ) external override(IFactoryElementFiValueProvider) returns (address) {
        ElementFiValueProvider elementFiValueProvider = new ElementFiValueProvider(
                timeUpdateWindow_,
                maxValidTime_,
                alpha_,
                poolId_,
                balancerVaultAddress_,
                poolToken_,
                underlier_,
                ePTokenBond_,
                timeScale_,
                maturity_
            );

        return address(elementFiValueProvider);
    }
}

////// src/oracle_implementations/discount_rate/NotionalFinance/INotionalView.sol
/* pragma solidity ^0.8.0; */

/// Imported from:
/// https://github.com/notional-finance/contracts-v2/blob/23a3d5fcdba8a2e2ae6b0730f73eed810484e4cc/contracts/global/Types.sol
/// @dev Holds information about a market, total storage is 42 bytes so this spans
/// two storage words
struct MarketStorage {
    // Total fCash in the market
    uint80 totalfCash;
    // Total asset cash in the market
    uint80 totalAssetCash;
    // Last annualized interest rate the market traded at
    uint32 lastImpliedRate;
    // Last recorded oracle rate for the market
    uint32 oracleRate;
    // Last time a trade was made
    uint32 previousTradeTime;
    // This is stored in slot + 1
    uint80 totalLiquidity;
}

/// Imported from:
/// https://github.com/notional-finance/contracts-v2/blob/23a3d5fcdba8a2e2ae6b0730f73eed810484e4cc/contracts/global/Types.sol
/// @dev Market object as represented in memory
struct MarketParameters {
    bytes32 storageSlot;
    uint256 maturity;
    // Total amount of fCash available for purchase in the market.
    int256 totalfCash;
    // Total amount of cash available for purchase in the market.
    int256 totalAssetCash;
    // Total amount of liquidity tokens (representing a claim on liquidity) in the market.
    int256 totalLiquidity;
    // This is the previous annualized interest rate in RATE_PRECISION that the market traded
    // at. This is used to calculate the rate anchor to smooth interest rates over time.
    // RATE_PRECISION is defined as 1e9 in the constants contract deployed here:
    // https://github.com/notional-finance/contracts-v2/blob/23a3d5fcdba8a2e2ae6b0730f73eed810484e4cc/contracts/global/Constants.sol
    uint256 lastImpliedRate;
    // Time lagged version of lastImpliedRate, used to value fCash assets at market rates while
    // remaining resistent to flash loan attacks.
    uint256 oracleRate;
    // This is the timestamp of the previous trade
    uint256 previousTradeTime;
}

interface INotionalView {
    /// @notice Returns a single market
    function getMarket(
        uint16 currencyId,
        uint256 maturity,
        uint256 settlementDate
    ) external view returns (MarketParameters memory);
}

////// src/oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol"; */
/* import {INotionalView, MarketParameters} from "src/oracle_implementations/discount_rate/NotionalFinance/INotionalView.sol"; */
/* import {Oracle} from "src/oracle/Oracle.sol"; */
/* import "lib/prb-math/contracts/PRBMathSD59x18.sol"; */

contract NotionalFinanceValueProvider is Oracle, Convert {
    // @notice Emitted when trying to add pull a value for an expired pool
    error NotionalFinanceValueProvider__value_maturityLessThanBlocktime(
        uint256 maturity
    );

    // Seconds in a 360 days year as used by Notional in 18 digits precision
    int256 internal constant SECONDS_PER_YEAR = 31104000 * 1e18;

    address public immutable notionalView;
    uint16 public immutable currencyId;
    uint256 public immutable maturityDate;
    uint256 public immutable settlementDate;

    uint256 private immutable oracleRateDecimals;

    /// @notice                         Constructs the Value provider contracts with the needed Notional contract data in order to
    ///                                 calculate the annual rate.
    /// @param timeUpdateWindow_        Minimum time between updates of the value
    /// @param maxValidTime_            Maximum time for which the value is valid
    /// @param alpha_                   Alpha parameter for EMA
    /// @param notionalViewContract_    The address of the deployed notional view contract.
    /// @param currencyId_              Currency ID(eth = 1, dai = 2, usdc = 3, wbtc = 4)
    /// @param oracleRateDecimals_      Precision of the Notional Market rate.
    /// @param maturity_                Maturity date.
    /// @param settlementDate_          Settlement date.
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address notionalViewContract_,
        uint16 currencyId_,
        uint256 oracleRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        oracleRateDecimals = oracleRateDecimals_;
        notionalView = notionalViewContract_;
        currencyId = currencyId_;
        maturityDate = maturity_;
        settlementDate = settlementDate_;
    }

    /// @notice Calculates the annual rate used by the FIAT DAO contracts
    /// the rate is precomputed by the notional contract and scaled to 1e18 precision.
    /// @dev For more details regarding the computed rate in the Notional contracts:
    /// https://github.com/notional-finance/contracts-v2/blob/b8e3792e39486b2719c6153acc270199377cc6b9/contracts/internal/markets/Market.sol#L495
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturityDate) {
            revert NotionalFinanceValueProvider__value_maturityLessThanBlocktime(
                maturityDate
            );
        }

        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        MarketParameters memory marketParams = INotionalView(notionalView)
            .getMarket(currencyId, maturityDate, settlementDate);

        // Convert rate per annum to 18 digits precision.
        uint256 ratePerAnnum = uconvert(
            marketParams.oracleRate,
            oracleRateDecimals,
            18
        );

        // Convert per annum to per second rate
        int256 ratePerSecondD59x18 = PRBMathSD59x18.div(
            int256(ratePerAnnum),
            SECONDS_PER_YEAR
        );

        // Convert continuous compounding to discrete compounding rate
        int256 discreteRateD59x18 = PRBMathSD59x18.exp(ratePerSecondD59x18) -
            PRBMathSD59x18.SCALE;

        // The result is a 59.18 fixed-point number.
        return discreteRateD59x18;
    }
}

////// src/factory/FactoryNotionalFinanceValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {NotionalFinanceValueProvider} from "src/oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol"; */

interface IFactoryNotionalFinanceValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address notionalViewContract_,
        uint16 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) external returns (address);
}

contract FactoryNotionalFinanceValueProvider is
    IFactoryNotionalFinanceValueProvider
{
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address notionalViewContract_,
        uint16 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    )
        external
        override(IFactoryNotionalFinanceValueProvider)
        returns (address)
    {
        NotionalFinanceValueProvider notionalFinanceValueProvider = new NotionalFinanceValueProvider(
                timeUpdateWindow_,
                maxValidTime_,
                alpha_,
                notionalViewContract_,
                currencyId_,
                lastImpliedRateDecimals_,
                maturity_,
                settlementDate_
            );

        return address(notionalFinanceValueProvider);
    }
}

////// src/oracle_implementations/discount_rate/Yield/IYieldPool.sol
/* pragma solidity ^0.8.0; */

/// @notice The Yield pool contract interface
/// Only the useful functionality is defined in the interface.
/// For the full contract interface:
/// https://github.com/yieldprotocol/yieldspace-interfaces/blob/0266fbfd0117ff821cb2f43010a004cc44d1bfc1/IPool.sol
/// deployed contract example : https://etherscan.io/address/0x3771c99c087a81df4633b50d8b149afaa83e3c9e
interface IYieldPool {
    function ts() external view returns (int128);

    function getCache()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );

    function getBaseBalance() external view returns (uint112);

    function getFYTokenBalance() external view returns (uint112);

    // Fixed point factor with 27 decimals (ray)
    function cumulativeBalancesRatio() external view returns (uint256);
}

////// src/oracle_implementations/discount_rate/Yield/YieldValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol"; */

/* import {IYieldPool} from "./IYieldPool.sol"; */
/* import "lib/prb-math/contracts/PRBMathSD59x18.sol"; */
/* import {Oracle} from "src/oracle/Oracle.sol"; */

contract YieldValueProvider is Oracle, Convert {
    // @notice Emitted when trying to add pull a value for an expired pool
    error YieldProtocolValueProvider__getValue_maturityLessThanBlocktime(
        uint256 maturity
    );

    // The cumulative Balance Ratio in 18 digit precision
    uint256 public cumulativeBalanceRatioLast;
    uint32 public blockTimestampLast;

    address public immutable poolAddress;
    uint256 public immutable maturity;
    int256 public immutable timeScale;

    /// @notice                     Constructs the Value provider contracts with the needed Element data in order to
    ///                             calculate the annual rate.
    /// @param timeUpdateWindow_    Minimum time between updates of the value
    /// @param maxValidTime_        Maximum time for which the value is valid
    /// @param alpha_               Alpha parameter for EMA
    /// @param poolAddress_         Address of the pool
    /// @param maturity_            Expiration of the pool
    /// @param timeScale_           Time scale used on this pool (i.e. 1/(timeStretch*secondsPerYear)) in 59x18 fixed point
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        poolAddress = poolAddress_;
        maturity = maturity_;
        timeScale = timeScale_;

        // Load the initial values from the pool
        (, , blockTimestampLast) = IYieldPool(poolAddress_).getCache();
        cumulativeBalanceRatioLast = uconvert(
            IYieldPool(poolAddress_).cumulativeBalancesRatio(),
            27,
            18
        );
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Reverts if the block time exceeds or is equal to pool maturity.
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturity) {
            revert YieldProtocolValueProvider__getValue_maturityLessThanBlocktime(
                maturity
            );
        }

        // Get the current block timestamp for the Cumulative Balance Ratio
        (, , uint32 blockTimestamp) = IYieldPool(poolAddress).getCache();

        // Compute the elapsed time
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        // Get the current cumulative balance ratio and scale it to 18 digit precision
        uint256 cumulativeBalanceRatio = uconvert(
            IYieldPool(poolAddress).cumulativeBalancesRatio(),
            27,
            18
        );

        // Compute the scaled cumulative balance delta
        // Reverting here if timeElapsed is 0 is wanted
        int256 cumulativeScaledBalanceDelta59x18 = PRBMathSD59x18.div(
            int256(cumulativeBalanceRatio - cumulativeBalanceRatioLast),
            PRBMathSD59x18.fromInt(int256(uint256(timeElapsed)))
        );

        // Save the last used values
        blockTimestampLast = blockTimestamp;
        cumulativeBalanceRatioLast = cumulativeBalanceRatio;

        // Compute the per-second rate in signed 59.18 format
        int256 ratePerSecond59x18 = (PRBMathSD59x18.pow(
            cumulativeScaledBalanceDelta59x18,
            timeScale
        ) - PRBMathSD59x18.SCALE);

        // The result is a 59.18 fixed-point number.
        return ratePerSecond59x18;
    }
}

////// src/factory/FactoryYieldValueProvider.sol
/* pragma solidity ^0.8.0; */

/* import {YieldValueProvider} from "src/oracle_implementations/discount_rate/Yield/YieldValueProvider.sol"; */

interface IFactoryYieldValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) external returns (address);
}

contract FactoryYieldValueProvider is IFactoryYieldValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) public override(IFactoryYieldValueProvider) returns (address) {
        YieldValueProvider yieldValueProvider = new YieldValueProvider(
            timeUpdateWindow_,
            maxValidTime_,
            alpha_,
            poolAddress_,
            maturity_,
            timeScale_
        );

        return address(yieldValueProvider);
    }
}

////// src/factory/Factory.sol
/* pragma solidity ^0.8.0; */

/* import {IOracle} from "src/oracle/IOracle.sol"; */
/* import {IAggregatorOracle} from "src/aggregator/IAggregatorOracle.sol"; */

// Contract Deployers
/* import {IFactoryElementFiValueProvider} from "src/factory/FactoryElementFiValueProvider.sol"; */
/* import {IFactoryNotionalFinanceValueProvider} from "src/factory/FactoryNotionalFinanceValueProvider.sol"; */
/* import {IFactoryYieldValueProvider} from "src/factory/FactoryYieldValueProvider.sol"; */
/* import {IFactoryChainlinkValueProvider} from "src/factory/FactoryChainlinkValueProvider.sol"; */
/* import {IFactoryAggregatorOracle} from "src/factory/FactoryAggregatorOracle.sol"; */
/* import {IFactoryCollybusSpotPriceRelayer} from "src/factory/FactoryCollybusSpotPriceRelayer.sol"; */
/* import {IFactoryCollybusDiscountRateRelayer} from "src/factory/FactoryCollybusDiscountRateRelayer.sol"; */

// Relayers
/* import {ICollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol"; */
/* import {ICollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/ICollybusSpotPriceRelayer.sol"; */

/* import {Guarded} from "src/guarded/Guarded.sol"; */

/// @notice Data structure that wraps data needed to deploy an Element Value Provider contract
struct ElementVPData {
    bytes32 poolId;
    address balancerVault;
    address poolToken;
    address underlier;
    address ePTokenBond;
    int256 timeScale;
    uint256 maturity;
}

/// @notice Data structure that wraps data needed to deploy an Notional Value Provider contract
struct NotionalVPData {
    address notionalViewAddress;
    uint16 currencyId;
    uint256 lastImpliedRateDecimals;
    uint256 maturityDate;
    uint256 settlementDate;
}

/// @notice Data structure that wraps data needed to deploy a Chainlink spot price value provider
struct ChainlinkVPData {
    address chainlinkAggregatorAddress;
}

/// @notice Data structure that wraps data needed to deploy a Yield value provider
struct YieldVPData {
    address poolAddress;
    uint256 maturity;
    int256 timeScale;
}

/// @notice Data structure that wraps needed data to deploy an Oracle contract
/// @dev The value provider data field is a abi.encoded struct based on the given providerType
/// @dev The Factory will revert if the providerType is not found
struct OracleData {
    bytes valueProviderData;
    uint8 valueProviderType;
    uint256 timeWindow;
    uint256 maxValidTime;
    int256 alpha;
}

/// @notice Data structure that wraps needed data to deploy an Oracle Aggregator contract
/// @dev The oracleData array field contains abi.encoded OracleData structures
/// @dev Factory will revert if the requiredValidValues is bigger than the oracleData item count
struct DiscountRateAggregatorData {
    uint256 tokenId;
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumThresholdValue;
}

/// @notice Data structure that wraps needed data to deploy an Oracle Aggregator contract
/// @dev The oracleData field contains a abi.encoded OracleData structure
///      We only have one oracle per aggregator as we trust chainlink as the single source or truth
/// @dev Factory will revert if the requiredValidValues is bigger than the oracleData item count
struct SpotPriceAggregatorData {
    address tokenAddress;
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumThresholdValue;
}

/// @notice Data structure that wraps needed data to deploy a full Relayer architecture
/// @dev The aggregatorData field contains abi.encoded DiscountRateAggregatorData or SpotPriceAggregatorData structures
/// @dev Factory will revert if the aggregators do not contain unique tokenId's
struct RelayerDeployData {
    bytes[] aggregatorData;
}

contract Factory is Guarded {
    event RelayerDeployed(address relayerAddress, uint256 relayerType);
    event AggregatorDeployed(address aggregatorAddress, uint256 relayerType);
    event OracleDeployed(address oracleAddress);

    // @notice Emitted when the collybus address is address(0)
    error Factory__deployCollybusDiscountRateRelayer_invalidCollybusAddress();

    // @notice Emitted when the collybus address is address(0)
    error Factory__deployCollybusSpotPriceRelayer_invalidCollybusAddress();

    // @notice Emitted if no value provider is found for given providerType
    error Factory__deployOracle_invalidValueProviderType(uint8);

    // Supported value provider oracle types
    enum ValueProviderType {
        Element,
        Notional,
        Yield,
        Chainlink,
        COUNT
    }

    enum RelayerType {
        DiscountRate,
        SpotPrice
    }

    address public immutable elementFiValueProviderFactory;
    address public immutable notionalValueProviderFactory;
    address public immutable yieldValueProviderFactory;
    address public immutable chainlinkValueProviderFactory;
    address public immutable aggregatorOracleFactory;
    address public immutable collybusDiscountRateRelayerFactory;
    address public immutable collybusSpotPriceRelayerFactory;

    constructor(
        address elementFiValueProviderFactory_,
        address notionalValueProviderFactory_,
        address yieldValueProviderFactory_,
        address chainlinkValueProviderFactory_,
        address aggregatorOracleFactory_,
        address collybusDiscountRateRelayerFactory_,
        address collybusSpotPriceRelayerFactory_
    ) {
        elementFiValueProviderFactory = elementFiValueProviderFactory_;
        notionalValueProviderFactory = notionalValueProviderFactory_;
        yieldValueProviderFactory = yieldValueProviderFactory_;
        chainlinkValueProviderFactory = chainlinkValueProviderFactory_;
        aggregatorOracleFactory = aggregatorOracleFactory_;
        collybusDiscountRateRelayerFactory = collybusDiscountRateRelayerFactory_;
        collybusSpotPriceRelayerFactory = collybusSpotPriceRelayerFactory_;
    }

    /// @notice Deploys an Element Fi Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add GitHub URL contract
    /// @return Returns the address of the new value provider
    function deployElementFiValueProvider(
        // Oracle params
        OracleData memory oracleParams_
    ) public checkCaller returns (address) {
        ElementVPData memory elementParams = abi.decode(
            oracleParams_.valueProviderData,
            (ElementVPData)
        );

        address elementFiValueProviderAddress = IFactoryElementFiValueProvider(
            elementFiValueProviderFactory
        ).create(
                oracleParams_.timeWindow,
                oracleParams_.maxValidTime,
                oracleParams_.alpha,
                elementParams.poolId,
                elementParams.balancerVault,
                elementParams.poolToken,
                elementParams.underlier,
                elementParams.ePTokenBond,
                elementParams.timeScale,
                elementParams.maturity
            );

        return elementFiValueProviderAddress;
    }

    /// @notice Deploys a Notional Finance Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add GitHub URL contract
    /// @return Returns the address of the new value provider
    function deployNotionalFinanceValueProvider(
        // Oracle params
        OracleData memory oracleParams_
    ) public checkCaller returns (address) {
        NotionalVPData memory notionalParams = abi.decode(
            oracleParams_.valueProviderData,
            (NotionalVPData)
        );

        address notionalFinanceValueProviderAddress = IFactoryNotionalFinanceValueProvider(
                notionalValueProviderFactory
            ).create(
                    oracleParams_.timeWindow,
                    oracleParams_.maxValidTime,
                    oracleParams_.alpha,
                    notionalParams.notionalViewAddress,
                    notionalParams.currencyId,
                    notionalParams.lastImpliedRateDecimals,
                    notionalParams.maturityDate,
                    notionalParams.settlementDate
                );

        return notionalFinanceValueProviderAddress;
    }

    /// @notice Deploys an Yield Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add the master github path to contract
    /// @return Returns the address of the new value provider
    function deployYieldValueProvider(
        // Oracle params
        OracleData memory oracleParams
    ) public checkCaller returns (address) {
        YieldVPData memory yieldParams = abi.decode(
            oracleParams.valueProviderData,
            (YieldVPData)
        );

        address yieldValueProviderAddress = IFactoryYieldValueProvider(
            yieldValueProviderFactory
        ).create(
                oracleParams.timeWindow,
                oracleParams.maxValidTime,
                oracleParams.alpha,
                yieldParams.poolAddress,
                yieldParams.maturity,
                yieldParams.timeScale
            );

        return yieldValueProviderAddress;
    }

    /// @notice Deploys an Chainlink Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add the master github path to contract
    /// @return Returns the address of the new value provider
    function deployChainlinkValueProvider(
        // Oracle params
        OracleData memory oracleParams_
    ) public checkCaller returns (address) {
        ChainlinkVPData memory chainlinkParams = abi.decode(
            oracleParams_.valueProviderData,
            (ChainlinkVPData)
        );

        address chainlinkValueProviderAddress = IFactoryChainlinkValueProvider(
            chainlinkValueProviderFactory
        ).create(
                oracleParams_.timeWindow,
                oracleParams_.maxValidTime,
                oracleParams_.alpha,
                chainlinkParams.chainlinkAggregatorAddress
            );

        return chainlinkValueProviderAddress;
    }

    /// @notice Deploys a new Oracle and adds it to an Aggregator
    /// @param oracleDataEncoded_ ABI encoded Oracle data structure
    /// @param aggregatorAddress_ The aggregator address that will contain the created Oracle
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Oracle
    function deployAggregatorOracle(
        bytes memory oracleDataEncoded_,
        address aggregatorAddress_
    ) public checkCaller returns (address) {
        // Decode oracle data
        OracleData memory oracleData = abi.decode(
            oracleDataEncoded_,
            (OracleData)
        );

        address oracleAddress;

        // Create the value provider based on valueProviderType
        // Revert if no match match is found
        if (oracleData.valueProviderType == uint8(ValueProviderType.Element)) {
            // Create the value provider
            oracleAddress = deployElementFiValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint8(ValueProviderType.Notional)
        ) {
            // Create the value provider
            oracleAddress = deployNotionalFinanceValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint8(ValueProviderType.Chainlink)
        ) {
            // Create the value provider
            oracleAddress = deployChainlinkValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint8(ValueProviderType.Yield)
        ) {
            // Create the value provider
            oracleAddress = deployYieldValueProvider(oracleData);
        } else {
            // Revert if the value provider type is not supported
            revert Factory__deployOracle_invalidValueProviderType(
                oracleData.valueProviderType
            );
        }

        // Add the oracle to the Aggregator Oracle
        IAggregatorOracle(aggregatorAddress_).oracleAdd(oracleAddress);
        emit OracleDeployed(oracleAddress);

        return oracleAddress;
    }

    /// @notice Deploys a new Aggregator and adds it to a Relayer
    /// @param aggregatorDataEncoded_ ABI encoded Aggregator data structure
    /// @param discountRateRelayerAddress_ The address of the discount rate relayer where we will add the aggregator
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Aggregator
    function deployDiscountRateAggregator(
        bytes memory aggregatorDataEncoded_,
        address discountRateRelayerAddress_
    ) public checkCaller returns (address) {
        // Create aggregator contract
        address aggregatorOracleAddress = IFactoryAggregatorOracle(
            aggregatorOracleFactory
        ).create();

        // Decode aggregator structure
        DiscountRateAggregatorData memory aggData = abi.decode(
            aggregatorDataEncoded_,
            (DiscountRateAggregatorData)
        );

        // Iterate and deploy each oracle
        uint256 oracleCount = aggData.oracleData.length;
        for (
            uint256 oracleIndex = 0;
            oracleIndex < oracleCount;
            oracleIndex++
        ) {
            // TODO: We can use the oracles returned address to emit events
            // Each oracle is also added to the aggregator
            deployAggregatorOracle(
                aggData.oracleData[oracleIndex],
                aggregatorOracleAddress
            );
        }

        // Set the minimum required valid values for the aggregator
        // Reverts if the requiredValidValues is greater than the oracleCount
        IAggregatorOracle(aggregatorOracleAddress).setParam(
            "requiredValidValues",
            aggData.requiredValidValues
        );

        // Add the aggregator to the relayer
        // Reverts if the tokenId is not unique
        // Reverts if the Aggregator is already used
        ICollybusDiscountRateRelayer(discountRateRelayerAddress_).oracleAdd(
            aggregatorOracleAddress,
            aggData.tokenId,
            aggData.minimumThresholdValue
        );

        emit AggregatorDeployed(
            aggregatorOracleAddress,
            uint256(RelayerType.DiscountRate)
        );
        return aggregatorOracleAddress;
    }

    /// @notice Deploys a new Aggregator and adds it to a Relayer
    /// @param aggregatorDataEncoded_ ABI encoded Oracle data structure
    /// @param spotPriceRelayerAddress_ The address of the spot price relayer where we will add the aggregator
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Aggregator
    function deploySpotPriceAggregator(
        bytes memory aggregatorDataEncoded_,
        address spotPriceRelayerAddress_
    ) public checkCaller returns (address) {
        // Create aggregator contract
        address aggregatorOracleAddress = IFactoryAggregatorOracle(
            aggregatorOracleFactory
        ).create();

        // Decode aggregator structure
        SpotPriceAggregatorData memory aggData = abi.decode(
            aggregatorDataEncoded_,
            (SpotPriceAggregatorData)
        );

        // Iterate and deploy each oracle
        uint256 oracleCount = aggData.oracleData.length;
        for (
            uint256 oracleIndex = 0;
            oracleIndex < oracleCount;
            oracleIndex++
        ) {
            // TODO: We can use the oracles returned address to emit events
            // Each oracle is also added to the aggregator
            deployAggregatorOracle(
                aggData.oracleData[oracleIndex],
                aggregatorOracleAddress
            );
        }

        // Set the minimum required valid values for the aggregator
        // Reverts if the requiredValidValues is greater than the oracleCount
        IAggregatorOracle(aggregatorOracleAddress).setParam(
            "requiredValidValues",
            aggData.requiredValidValues
        );

        // Add the aggregator to the relayer
        // Reverts if the tokenAddress is not unique
        // Revert if the Aggregator is already used
        ICollybusSpotPriceRelayer(spotPriceRelayerAddress_).oracleAdd(
            aggregatorOracleAddress,
            aggData.tokenAddress,
            aggData.minimumThresholdValue
        );

        emit AggregatorDeployed(
            aggregatorOracleAddress,
            uint256(RelayerType.SpotPrice)
        );
        return aggregatorOracleAddress;
    }

    /// @notice Deploys a new Discount Rate Relayer
    /// @param collybus_ Address of Collybus
    /// @dev Reverts if Collybus is not set
    /// @return Returns the address of the Relayer
    function deployCollybusDiscountRateRelayer(address collybus_)
        public
        checkCaller
        returns (address)
    {
        // Collybus address is needed in order to deploy the Discount Rate Relayer
        if (collybus_ == address(0)) {
            revert Factory__deployCollybusDiscountRateRelayer_invalidCollybusAddress();
        }

        address discountRateRelayerAddress = IFactoryCollybusDiscountRateRelayer(
                collybusDiscountRateRelayerFactory
            ).create(collybus_);

        emit RelayerDeployed(
            discountRateRelayerAddress,
            uint256(RelayerType.DiscountRate)
        );
        return discountRateRelayerAddress;
    }

    /// @notice Deploys a new Spot Price Relayer
    /// @param collybus_ Address of Collybus
    /// @dev Reverts if Collybus is not set
    /// @return Returns the address of the Relayer
    function deployCollybusSpotPriceRelayer(address collybus_)
        public
        checkCaller
        returns (address)
    {
        // The Collybus address is needed in order to deploy the Spot Price Rate Relayer
        if (collybus_ == address(0)) {
            revert Factory__deployCollybusSpotPriceRelayer_invalidCollybusAddress();
        }

        address spotPriceRelayerAddress = IFactoryCollybusSpotPriceRelayer(
            collybusSpotPriceRelayerFactory
        ).create(collybus_);

        emit RelayerDeployed(
            spotPriceRelayerAddress,
            uint256(RelayerType.SpotPrice)
        );
        return spotPriceRelayerAddress;
    }

    /// @notice Deploys a full Discount Rate Relayer architecture, can contain Aggregator Oracles and Oracles
    /// @param discountRateRelayerDataEncoded_ ABI encoded RelayerDeployData struct
    /// @param collybus_ Collybus address
    /// @dev Reverts on dependencies checks and conditions
    /// @return Returns the Discount Rate Relayer
    function deployDiscountRateArchitecture(
        bytes memory discountRateRelayerDataEncoded_,
        address collybus_
    ) public checkCaller returns (address) {
        RelayerDeployData memory discountRateRelayerData = abi.decode(
            discountRateRelayerDataEncoded_,
            (RelayerDeployData)
        );
        // Create the relayer and cache the address
        address discountRateRelayerAddress = deployCollybusDiscountRateRelayer(
            collybus_
        );

        // Iterate and deploy each aggregator
        uint256 aggCount = discountRateRelayerData.aggregatorData.length;
        for (uint256 aggIndex = 0; aggIndex < aggCount; aggIndex++) {
            deployDiscountRateAggregator(
                discountRateRelayerData.aggregatorData[aggIndex],
                discountRateRelayerAddress
            );
        }

        return discountRateRelayerAddress;
    }

    /// @notice Deploys a full Spot Price Relayer architecture, can contain Aggregator Oracles and Oracles
    /// @param spotPriceRelayerDataEncoded_ ABI encoded RelayerDeployData struct
    /// @param collybusAddress_ Collybus address
    /// @dev Reverts on dependency checks and conditions
    /// @return Returns the Spot Price Relayer
    function deploySpotPriceArchitecture(
        bytes memory spotPriceRelayerDataEncoded_,
        address collybusAddress_
    ) public checkCaller returns (address) {
        RelayerDeployData memory spotPriceRelayerData = abi.decode(
            spotPriceRelayerDataEncoded_,
            (RelayerDeployData)
        );

        // Create the relayer and cache the address
        address spotPriceRelayerAddress = deployCollybusSpotPriceRelayer(
            collybusAddress_
        );

        // Iterate and deploy each aggregator
        uint256 aggCount = spotPriceRelayerData.aggregatorData.length;
        for (uint256 aggIndex = 0; aggIndex < aggCount; aggIndex++) {
            deploySpotPriceAggregator(
                spotPriceRelayerData.aggregatorData[aggIndex],
                spotPriceRelayerAddress
            );
        }

        return spotPriceRelayerAddress;
    }

    /// @notice Sets permission on the destination contract
    /// @param where_ What contract to set permission on. This contract needs to implement `Guarded.allowCaller(sig, who)`
    /// @param sig_ Method signature [4byte]
    /// @param who_ Address of who should be able to call `sig_`
    /// @dev Reverts if the current contract can't call `.allowCaller`
    function setPermission(
        address where_,
        bytes32 sig_,
        address who_
    ) public checkCaller {
        Guarded(where_).allowCaller(sig_, who_);
    }

    /// @notice Removes permission on the destination contract
    /// @param where_ What contract to remove permission from. This contract needs to implement `Guarded.blockCaller(sig, who)`
    /// @param sig_ Method signature [4byte]
    /// @param who_ Address of who should not be able to call `sig_`
    /// @dev Reverts if the current contract can't call `.blockCaller`
    function removePermission(
        address where_,
        bytes32 sig_,
        address who_
    ) public checkCaller {
        Guarded(where_).blockCaller(sig_, who_);
    }
}

////// src/deploy/SpotPriceDeploy.sol
/* pragma solidity ^0.8.0; */

/* import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; */
/* import {IVault} from "src/oracle_implementations/discount_rate/ElementFi/IVault.sol"; */
/* import {RelayerDeployData, SpotPriceAggregatorData, OracleData, ChainlinkVPData, Factory} from "src/factory/Factory.sol"; */

/* import "lib/prb-math/contracts/PRBMathSD59x18.sol"; */

contract SpotPriceDeploy {
    function createDeployData(address chainlinkDataFeedAddress_)
        external
        view
        returns (bytes memory)
    {
        ChainlinkVPData memory chainlinkValueProvider = ChainlinkVPData({
            chainlinkAggregatorAddress: chainlinkDataFeedAddress_
        });

        OracleData memory chainlinkOracleData = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 60,
            maxValidTime: 600,
            alpha: 10**18,
            valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
        });

        SpotPriceAggregatorData
            memory chainlinkAggregator = SpotPriceAggregatorData({
                tokenAddress: address(
                    0x78dEca24CBa286C0f8d56370f5406B48cFCE2f86
                ),
                oracleData: new bytes[](1),
                requiredValidValues: 1,
                minimumThresholdValue: 0
            });

        chainlinkAggregator.oracleData[0] = abi.encode(chainlinkOracleData);

        RelayerDeployData memory deployData;
        deployData.aggregatorData = new bytes[](1);
        deployData.aggregatorData[0] = abi.encode(chainlinkAggregator);

        return abi.encode(deployData);
    }
}