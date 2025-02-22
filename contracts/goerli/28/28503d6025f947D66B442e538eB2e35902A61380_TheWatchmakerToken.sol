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
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

pragma solidity >=0.6.2;

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

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

///////////////////////////////////////////////////////////////
// KYL // THE WATCHMAKER // ERC721 NFT COLLECTION //  2022  //
/////////////////////////////////////////////////////////////
// producer: KYL WATCHES LTD // Instagram: @kylwatchesltd //
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//    ___  _______  __  _______   _______  ___  __   __  _______          ///
//   |   ||       ||  ||       | |       ||   ||  |_|  ||       |        ///
//   |   ||_     _||__||  _____| |_     _||   ||       ||    ___|       ///
//   |   |  |   |      | |_____    |   |  |   ||       ||   |___       ///
//   |   |  |   |      |_____  |   |   |  |   ||       ||    ___|     ///
//   |   |  |   |       _____| |   |   |  |   || ||_|| ||   |___     ///
//   |___|  |___|      |_______|   |___|  |___||_|   |_||_______|   ///
//                                                                 ///
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                  ///
//                                                                                 ./%@@@@@@@#,                    ///
//                                           .*(%&@@@@&&%%%##%%%&&@@@@%#*.    ,#@@&#/*,,.....,#@&,                ///
//                                     *%&@@&(*,.......................,*#@@@@#*******,%@@@@@@@@@@(              ///
//                                ,&@@&*.................................... (@@#,******,,,*/#@@@#              ///
//                            ,%@@#,............................................%@%*****/(//*,,..&&.           ///
//                         ,&@%*.,,,.............................................,%@#****//((#&@@@%.          ///
//                       (@&*,,,,,,,,..............................................,@&******,.../@&.         ///
//                     /@@,,,,,,,,,,,,...............................................%@(,/%#/,,..,%@,       ///
//      .*%@@@@&&&&%%%@@/,,,,,,,,,,,,,,,..............................................#@#,**#@@/,.*@@.     ///
//    (@@(,.........,&@*.,,,,,,,,,,,,,,,,............................(@(.............. (@(,**,&@,.,%@*    ///
//  .&@/..,/%&(.....#@/.,,,,,,,,,,,,,,,,,,.....................,(%@&/,..................#@(,**(@&.,%@*   ///
//  #@#&@@@@%,......&&,,,,,,,,,,,,,,,,,,,,,,.......... .*#@@@&(. ...............  .......&@/**(@@&*&@.  ///
// .#&(#@&,.../&#*,*@#.,,,,,,,,,,,,,,,,,,,,,,,*/#&@@&%(*..................,/%@@@@@(*.....,@&*,#@*/@&,  ///
//    %@*.,(@@#*,,.*@#.,,,,,,,,,.%&&&@@@&%%#/*,,......................*&@&#*...,@&#@&,..../@#*@%      ///
//    (@&@@%*******/@#.,,,,,,,,,,,,,,,,,,,,,,,,,....................#@&*.#@@@&/..,&@*......%@@&.      ///
//       @&****,(@@*&&.,,,,,,,,,,,,,,,,,,,,,,,,,,..................%@*.,&@@@@@@@@@@@@%* ...(@/        ///
//      [email protected]&****@@/,.#@*.,,,,,,,,,,,,,,,,,,,,,,,,,,..............*@@%*(@@@@@@@@&&&&&@@@@@@&*,&@,       ///
//       %@/**/@@*,./@%.,,,,/%&@@@@&%%%&&@@&/,,.,,..............&&(@@@@@%@@####%##(((((%@@@@@@%.      ///
//        &@**,#@#,.,%@*.,,*%@@%************#@@@@#,............,&@@@@#(#&@@@&%###%@@@@#(((&@@@@(      ///
//        .%@#,/@@%,*(@%,,,%@@/,**,,/%@@@@@@@@@&#&@#.......... #@@@#(%@@%*/%@@@@@@&(/#@@%((#@@@@.     ///
//          ,@&/@&&@#*%@(,,,./@&&@@@@@@@&&@&&&@@@@@@@(......../@@@((&@&/%@@@@@@@*     *%@&(((@@@&     ///
//            .((. .%@&@@*,,,#@@@@#/%*,,,*@(.,,,#/*%@@@&,.....%@@%(%@@/&@@@@@@@@(.  ,%&/&@%((&@@@*    ///
//                    .(@@*/@@@&,,,,,&#.,,(*..*@/.,,,*@@@#....(@@&(%@&/@@@@@@@@@@@@@@@@/&@#((@@@@%    ///
//                      *@@@@@#%@%,.,,,,,,,,,,,,.. /@@/@@@%%@@@@@@%(&@%%@@@@@@@@@@@@@@/&@&((&@@@@&    ///
//                       #@@@(.,,.,,,,.,,,*(%&%/, .    ,@@@&#/,.#@@&(&@@#&@@@@@@@@@@#%@@#((@@@&/@&    ///
//                       %@@&.***,*##(*.&@@@@&,    ,,,,,@@@,.....*@@@&(#@@@&&&%%&&@@@&((#@@@@/.(@(    ///
//                       &@@@.          #@/*. ..       *@@&........,%@@@&#(((####(((#&@@@@&*..,&@.    ///
//                       (@@@*    (,   @%         #,   %@@(............%@@@@@@@@@@@@@@@#......(@/     ///
//                        #@@@((#,    (,            (&@@@#,...........*#&@%,,*//**[email protected]%      ///
//                         *@@@@(   ,&*  .&*   %(  .#@@@&%*...............#@/./#&@@@&&@@@&%/,%@*      ///
//                           .&@@@@&%,   [email protected]/   .#@@@@@#@@,,,.............,%@@%/,...%@%/...,*(%@@@&#*  ///
//                             /@@@@@@@@@@@@@@@@@@&*.,#@*.,,............(@%.,,&@/...../&@@@(.,#@@@(   ///
//                               /@&*..,*****,..,*(#%&&@@@&(*.........(@@*.....*&@#...,#@@(&@%,       ///
//                                 /@@/.,,,,*%@@%(/,...,,.,*#&@@@@@@@&(,.........*&@&&&/../@(         ///
//                                   ,&@%,(@@(,#@#,*,&@/*,**,................,(&@@(......,@&.         ///
//                                      %@@*,(@&/**,#@#*****,..,,,.*,.....#@@&* .........&@*         ////
//                                   .%@%**/@@%//**#@@%(*********//((#&@@%*..*,.........#@(         /////
//                                [email protected]@@@@@@@&%@@#(#(,.,/%%%%###((/**,.....,(@%,....... (@/          //////
//                                             *@@(,,,,,,,,,,,,,(@&&&&@@@#/...........%@/         ///////
//                                                %@@,.,,,,,,,,,,,,,,,,,........... /@@.         ////////
//                                                  *&@%,,,,,,,,,,,,,,.........,/&@@#.          /////////
//                                                     ,%@&(,........,,*/#%@@@%(,              //////////
//                                                         *%@@@@@@@&%(*,.                    ///////////
//                                                                                           ////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                       ////////
//  ████████╗██╗  ██╗███████╗    ██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗███╗   ███╗ █████╗ ██╗  ██╗███████╗██████╗       ///
//  ╚══██╔══╝██║  ██║██╔════╝    ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║████╗ ████║██╔══██╗██║ ██╔╝██╔════╝██╔══██╗     ///
//     ██║   ███████║█████╗      ██║ █╗ ██║███████║   ██║   ██║     ███████║██╔████╔██║███████║█████╔╝ █████╗  ██████╔╝    ///
//     ██║   ██╔══██║██╔══╝      ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║██║╚██╔╝██║██╔══██║██╔═██╗ ██╔══╝  ██╔══██╗   ///
//     ██║   ██║  ██║███████╗    ╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║██║ ╚═╝ ██║██║  ██║██║  ██╗███████╗██║  ██║  ///
//     ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ///
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @dev Interface for checking active staked balance of a user.
 */
interface IBankSource {
    function getAccumulatedAmount(
        address staker
    ) external view returns (uint256);
}

/**
 * @dev Implementation of the {IERC20} interface.
 */
contract TheWatchmakerToken is ERC20, Ownable, ReentrancyGuard {
IBankSource public BankSource;

    uint256 public MAX_SUPPLY;
    uint256 public constant MAX_TAX_VALUE = 100;

    uint256 public spendTaxAmount;
    uint256 public withdrawTaxAmount;

    uint256 public bribesDistributed;
    uint256 public activeTaxCollectedAmount;

    bool public tokenCapSet;

    bool public withdrawTaxCollectionStopped;
    bool public spendTaxCollectionStopped;

    bool public isPaused;
    bool public isDepositPaused;
    bool public isWithdrawPaused;
    bool public isTransferPaused;

    mapping(address => bool) private _isAuthorised;
    address[] public authorisedLog;

    mapping(address => uint256) public depositedAmount;
    mapping(address => uint256) public spentAmount;

    modifier onlyAuthorised() {
        require(_isAuthorised[_msgSender()], "Not Authorised");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Transfers paused!");
        _;
    }

    event Withdraw(address indexed userAddress, uint256 amount, uint256 tax);
    event Deposit(address indexed userAddress, uint256 amount);
    event DepositFor(
        address indexed caller,
        address indexed userAddress,
        uint256 amount
    );
    event Spend(
        address indexed caller,
        address indexed userAddress,
        uint256 amount,
        uint256 tax
    );
    event ClaimTax(
        address indexed caller,
        address indexed userAddress,
        uint256 amount
    );
    event InternalTransfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    using SafeMath for uint256;
    IUniswapV2Router02 private _uniswapV2Router;
    address private _uniswapV2Pair;
    address public _usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public _router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public _uniswapV3Router =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address public _feeWallet;

    uint256 public _supportLevel;
    uint256 public _floorSellFee;
    uint256 public _marketingFee;
    uint256 public _liquidityFee;
    uint256 public _tokensForLiquidity;
    uint256 public _supportPercentBelowATH;
    uint256 public _addLiquidityAtAmount;
    uint256 public _maxWallet;

    bool public _tradingActive;
    bool public _limitsInEffect;
    bool private _isSwappingBack;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromMaxWallet;
    mapping(address => bool) private _isNonUniswapExchange;
    mapping(address => bool) private _isBlackListedSender;
    mapping(address => bool) private _isBlackListed;

    event IsBuy(
        address indexed msgSender,
        address from,
        address to,
        uint256 tokensAmount,
        uint256 newUsdcBalance
    );
    event IsSell(
        address indexed msgSender,
        address from,
        address to,
        uint256 tokensAmount,
        uint256 newUsdcBalance
    );
    event IsLiquidityOperation(
        address indexed msgSender,
        address from,
        address to,
        uint256 tokensAmount,
        uint256 newUsdcBalance
    );
    event LiquidityAdded(uint256 usdcAmount, uint256 tokenAmount);
    event ExcludeFromFees(address indexed account, bool isExcluded);

    constructor(address _source) ERC20("LOOMI", "LOOMI") {
        _isAuthorised[_msgSender()] = true;
        isPaused = true;
        isTransferPaused = true;

        withdrawTaxAmount = 25;
        spendTaxAmount = 25;

        BankSource = IBankSource(_source);

        _uniswapV2Router = IUniswapV2Router02(_router);
        _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _usdc);
        _supportLevel = 0;
        _supportPercentBelowATH = 5;
        _floorSellFee = 30;
        _marketingFee = 2;
        _liquidityFee = 1;
        _addLiquidityAtAmount = 1000e18;
    }

    /**
     * @dev Returnes current spendable balance of a specific user. This balance can be spent by user for other collections without
     *      withdrawal to ERC-20 LOOMI OR can be withdrawn to ERC-20 LOOMI.
     */
    function getUserBalance(address user) public view returns (uint256) {
        return (BankSource.getAccumulatedAmount(user) +
            depositedAmount[user] -
            spentAmount[user]);
    }

    /**
     * @dev Function to deposit ERC-20 LOOMI to the game balance.
     */
    function depositLoomi(uint256 amount) public nonReentrant whenNotPaused {
        require(!isDepositPaused, "Deposit Paused");
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance");

        _burn(_msgSender(), amount);
        depositedAmount[_msgSender()] += amount;

        emit Deposit(_msgSender(), amount);
    }

    /**
     * @dev Function to withdraw game LOOMI to ERC-20 LOOMI.
     */
    function withdrawLoomi(uint256 amount) public nonReentrant whenNotPaused {
        require(!isWithdrawPaused, "Withdraw Paused");
        require(getUserBalance(_msgSender()) >= amount, "Insufficient balance");
        uint256 tax = withdrawTaxCollectionStopped
            ? 0
            : (amount * withdrawTaxAmount) / 100;

        spentAmount[_msgSender()] += amount;
        activeTaxCollectedAmount += tax;
        _mint(_msgSender(), (amount - tax));

        emit Withdraw(_msgSender(), amount, tax);
    }

    /**
     * @dev Function to transfer game LOOMI from one account to another.
     */
    function transferLoomi(
        address to,
        uint256 amount
    ) public nonReentrant whenNotPaused {
        require(!isTransferPaused, "Transfer Paused");
        require(getUserBalance(_msgSender()) >= amount, "Insufficient balance");

        spentAmount[_msgSender()] += amount;
        depositedAmount[to] += amount;

        emit InternalTransfer(_msgSender(), to, amount);
    }

    /**
     * @dev Function to spend user balance. Can be called by other authorised contracts. To be used for internal purchases of other NFTs, etc.
     */
    function spendLoomi(
        address user,
        uint256 amount
    ) external onlyAuthorised nonReentrant {
        require(getUserBalance(user) >= amount, "Insufficient balance");
        uint256 tax = spendTaxCollectionStopped
            ? 0
            : (amount * spendTaxAmount) / 100;

        spentAmount[user] += amount;
        activeTaxCollectedAmount += tax;

        emit Spend(_msgSender(), user, amount, tax);
    }

    /**
     * @dev Function to deposit tokens to a user balance. Can be only called by an authorised contracts.
     */
    function depositLoomiFor(
        address user,
        uint256 amount
    ) public onlyAuthorised nonReentrant {
        _depositLoomiFor(user, amount);
    }

    /**
     * @dev Function to tokens to the user balances. Can be only called by an authorised users.
     */
    function distributeLoomi(
        address[] memory user,
        uint256[] memory amount
    ) public onlyAuthorised nonReentrant {
        require(user.length == amount.length, "Wrong arrays passed");

        for (uint256 i; i < user.length; i++) {
            _depositLoomiFor(user[i], amount[i]);
        }
    }

    function _depositLoomiFor(address user, uint256 amount) internal {
        require(user != address(0), "Deposit to 0 address");
        depositedAmount[user] += amount;

        emit DepositFor(_msgSender(), user, amount);
    }

    /**
     * @dev Function to mint tokens to a user balance. Can be only called by an authorised contracts.
     */
    function mintFor(
        address user,
        uint256 amount
    ) external onlyAuthorised nonReentrant {
        if (tokenCapSet)
            require(
                totalSupply() + amount <= MAX_SUPPLY,
                "You try to mint more than max supply"
            );
        _mint(user, amount);
    }

    /**
     * @dev Function to claim tokens from the tax accumulated pot. Can be only called by an authorised contracts.
     */
    function claimLoomiTax(
        address user,
        uint256 amount
    ) public onlyAuthorised nonReentrant {
        require(activeTaxCollectedAmount >= amount, "Insufficiend tax balance");

        activeTaxCollectedAmount -= amount;
        depositedAmount[user] += amount;
        bribesDistributed += amount;

        emit ClaimTax(_msgSender(), user, amount);
    }

    /**
     * @dev Function returns maxSupply set by admin. By default returns error (Max supply is not set).
     */
    function getMaxSupply() public view returns (uint256) {
        require(tokenCapSet, "Max supply is not set");
        return MAX_SUPPLY;
    }

    /*
      ADMIN FUNCTIONS
    */

    /**
     * @dev Function allows admin to set total supply of LOOMI token.
     */
    function setTokenCap(uint256 tokenCup) public onlyOwner {
        require(
            totalSupply() < tokenCup,
            "Value is smaller than the number of existing tokens"
        );
        require(!tokenCapSet, "Token cap has been already set");

        MAX_SUPPLY = tokenCup;
    }

    /**
     * @dev Function allows admin add authorised address. The function also logs what addresses were authorised for transparancy.
     */
    function authorise(address addressToAuth) public onlyOwner {
        _isAuthorised[addressToAuth] = true;
        authorisedLog.push(addressToAuth);
    }

    /**
     * @dev Function allows admin add unauthorised address.
     */
    function unauthorise(address addressToUnAuth) public onlyOwner {
        _isAuthorised[addressToUnAuth] = false;
    }

    /**
     * @dev Function allows admin update the address of staking address.
     */
    function changeBankSourceContract(address _source) public onlyOwner {
        BankSource = IBankSource(_source);
        authorise(_source);
    }

    /**
     * @dev Function allows admin to update limmit of tax on withdraw.
     */
    function updateWithdrawTaxAmount(uint256 _taxAmount) public onlyOwner {
        require(_taxAmount < MAX_TAX_VALUE, "Wrong value passed");
        withdrawTaxAmount = _taxAmount;
    }

    /**
     * @dev Function allows admin to update tax amount on spend.
     */
    function updateSpendTaxAmount(uint256 _taxAmount) public onlyOwner {
        require(_taxAmount < MAX_TAX_VALUE, "Wrong value passed");
        spendTaxAmount = _taxAmount;
    }

    /**
     * @dev Function allows admin to stop tax collection on withdraw.
     */
    function stopTaxCollectionOnWithdraw(bool _stop) public onlyOwner {
        withdrawTaxCollectionStopped = _stop;
    }

    /**
     * @dev Function allows admin to stop tax collection on spend.
     */
    function stopTaxCollectionOnSpend(bool _stop) public onlyOwner {
        spendTaxCollectionStopped = _stop;
    }

    /**
     * @dev Function allows admin to pause all in game loomi transfactions.
     */
    function pauseGameLoomi(bool _pause) public onlyOwner {
        isPaused = _pause;
    }

    /**
     * @dev Function allows admin to pause in game loomi transfers.
     */
    function pauseTransfers(bool _pause) public onlyOwner {
        isTransferPaused = _pause;
    }

    /**
     * @dev Function allows admin to pause in game loomi withdraw.
     */
    function pauseWithdraw(bool _pause) public onlyOwner {
        isWithdrawPaused = _pause;
    }

    /**
     * @dev Function allows admin to pause in game loomi deposit.
     */
    function pauseDeposits(bool _pause) public onlyOwner {
        isDepositPaused = _pause;
    }

    /**
     * @dev Function allows admin to withdraw ETH accidentally dropped to the contract.
     */
    function rescue() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function init(address owner) public onlyOwner {
        require(owner != address(0), "Address doesn't exist");

        _feeWallet = address(owner);
        excludeFromFees(address(owner), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        uint256 totalSupply = 21e6 * 1e18;
        _maxWallet = (totalSupply * 3) / 100;

        _mint(owner, totalSupply);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(
            !_isBlackListed[to] || !_isBlackListed[from],
            "Address is blacklisted"
        );
        require(!_isBlackListedSender[msg.sender], "msg.sender is blacklisted");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        (
            bool isSell,
            bool isBuy,
            bool isLiquidityOperation
        ) = getTransactionType(from, to, amount);

        if (isLiquidityOperation || _isSwappingBack) {
            super._transfer(from, to, amount);
            return;
        }

        bool isSwap = isBuy || isSell;
        bool isExcludedFromFee = _isExcludedFromFees[from] ||
            _isExcludedFromFees[to];

        if (!_tradingActive && !isExcludedFromFee && isSwap)
            require(false, "Trading is not yet active");

        bool shouldTakeFee = _tradingActive && isSwap;
        if (isExcludedFromFee) shouldTakeFee = false;

        (
            uint buyerRewardInUSDC,
            uint sellFeeInUSDC,
            uint tokensForLiquidity,
            uint tokensForMarketing
        ) = calculateNewLevel(amount, isBuy);

        uint transferableAmount = amount;
        uint tokensToSellForRewards = 0;
        if (shouldTakeFee) {
            if (tokensForMarketing > 0 || tokensForLiquidity > 0) {
                super._transfer(from, _feeWallet, tokensForMarketing);
                super._transfer(from, address(this), tokensForLiquidity);
                _tokensForLiquidity += tokensForLiquidity;
                transferableAmount -= tokensForMarketing.add(
                    tokensForLiquidity
                );
            }
            if (sellFeeInUSDC > 0) {
                tokensToSellForRewards = getAmountOutForUsdcSell(sellFeeInUSDC);
                super._transfer(from, address(this), tokensToSellForRewards);
                transferableAmount -= tokensToSellForRewards;
            }
        }

        if (
            _limitsInEffect &&
            (!isExcludedFromFee || !_isExcludedFromMaxWallet[to])
        ) {
            if (isBuy || !isSwap)
                require(
                    transferableAmount + balanceOf(to) <= _maxWallet,
                    "Max wallet exceeded"
                );
        }

        if (isSell && !_isSwappingBack) {
            _isSwappingBack = true;
            swapBack(tokensToSellForRewards);
            _isSwappingBack = false;
        }

        if (
            !isSwap &&
            !isLiquidityOperation &&
            !isExcludedFromFee &&
            _tokensForLiquidity >= _addLiquidityAtAmount
        ) {
            bool added = addLiquidity(_tokensForLiquidity);
            if (added) _tokensForLiquidity = 0;
        }

        if (buyerRewardInUSDC > 0) {
            sendReward(to, buyerRewardInUSDC);
        }

        super._transfer(from, to, transferableAmount);
    }

    function getTransactionType(
        address from,
        address to,
        uint256 amount
    ) private returns (bool, bool, bool) {
        (uint reserve0, , ) = IUniswapV2Pair(_uniswapV2Pair)
            .getReserves();
        uint newUsdcBalance = ERC20(_usdc).balanceOf(_uniswapV2Pair);

        bool isBuy = from == _uniswapV2Pair && to != address(_uniswapV2Router);
        bool isSell = false;
        bool isLiquidityOperation = false;

        if (_isNonUniswapExchange[msg.sender]) {
            isBuy = from == _uniswapV2Pair;
            isSell = to == _uniswapV2Pair;
        } else {
            if (
                (msg.sender == address(_uniswapV2Router) ||
                    msg.sender == address(_uniswapV3Router)) &&
                to == _uniswapV2Pair
            ) {
                if (newUsdcBalance > reserve0) isLiquidityOperation = true;
                else isSell = true;
            }

            if (newUsdcBalance < reserve0 && to != _uniswapV2Pair) {
                if (isBuy) {
                    isLiquidityOperation = true;
                    isBuy = false;
                }
            }
        }

        if (isBuy) emit IsBuy(msg.sender, from, to, amount, newUsdcBalance);
        if (isSell) emit IsSell(msg.sender, from, to, amount, newUsdcBalance);
        if (isLiquidityOperation)
            emit IsLiquidityOperation(
                msg.sender,
                from,
                to,
                amount,
                newUsdcBalance
            );

        return (isSell, isBuy, isLiquidityOperation);
    }

    function getAmountOutForUsdcSell(
        uint usdcIn
    ) internal view returns (uint tokensReceived) {
        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(_uniswapV2Pair)
            .getReserves();
        tokensReceived = getAmountIn(usdcIn, reserve1, reserve0);
    }

    function getNewPrice(
        bool isBuy,
        uint amount
    ) internal view returns (uint, uint) {
        uint newPrice = 0;
        uint usdcSpent = 0;
        uint usdcReceived = 0;
        uint usdcFee = 0;
        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(_uniswapV2Pair)
            .getReserves();
        if (isBuy) {
            usdcSpent = getAmountIn(amount, reserve0, reserve1);
            newPrice = getAmountOut(
                1e18,
                reserve1.sub(amount),
                reserve0.add(usdcSpent)
            );
        } else {
            usdcReceived = getAmountOut(amount, reserve1, reserve0);
            newPrice = getAmountOut(
                1e18,
                reserve1.add(amount),
                reserve0.sub(usdcReceived)
            );
            usdcFee = usdcReceived.mul(_floorSellFee).div(100);
        }
        return (newPrice, usdcFee);
    }

    function calculateNewLevel(
        uint amount,
        bool isBuy
    ) internal returns (uint, uint, uint, uint) {
        (uint newPrice, uint usdcFee) = getNewPrice(isBuy, amount);
        uint currentPrice = getCurrentPrice();

        uint buyerRewardInUSDC = 0;
        uint sellFeeInUSDC = 0;
        uint tokensForLiquidity = 0;
        uint tokensForMarketing = 0;

        if (newPrice < _supportLevel) {
            if (isBuy) {
                uint priceMovePercentage = newPrice
                    .sub(currentPrice)
                    .mul(100000000)
                    .div(_supportLevel.sub(currentPrice));
                uint usdcRewardsBank = getBalance();
                if (usdcRewardsBank > 0) {
                    buyerRewardInUSDC = priceMovePercentage
                        .mul(usdcRewardsBank)
                        .div(100000000);
                }
            } else {
                sellFeeInUSDC = usdcFee;
            }
        } else if (newPrice >= _supportLevel && currentPrice < _supportLevel) {
            buyerRewardInUSDC = getBalance();
        } else {
            uint256 numerator = amount.div(100);
            tokensForLiquidity = numerator.mul(_liquidityFee);
            tokensForMarketing = numerator.mul(_marketingFee);
        }

        if (newPrice > _supportLevel) {
            uint tempSupport = newPrice.sub(
                newPrice.div(100).mul(_supportPercentBelowATH)
            );
            if (tempSupport > _supportLevel) _supportLevel = tempSupport;
        }

        return (
            buyerRewardInUSDC,
            sellFeeInUSDC,
            tokensForLiquidity,
            tokensForMarketing
        );
    }

    function swapBack(uint tokenAmount) private {
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance == 0 || tokenAmount == 0) return;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _usdc;

        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        _uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function getCurrentPrice() public view returns (uint price) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(_uniswapV2Pair)
            .getReserves();
        price = getAmountOut(1e18, reserve1, reserve0);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountIn) {
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    function getBalance() public view returns (uint256) {
        return ERC20(_usdc).balanceOf(address(this));
    }

    function sendReward(address to, uint256 amount) private {
        uint256 balance = getBalance();
        require(balance > 0 && balance >= amount, "Funds not enough!");
        ERC20(_usdc).transfer(to, amount);
    }

    function addLiquidity(uint256 tokenAmount) private returns (bool) {
        if (tokenAmount > balanceOf(address(this))) return false;

        uint256 tokensToBeAdded = tokenAmount.div(2);

        uint256 myUSDCBefore = ERC20(_usdc).balanceOf(address(this));
        _isSwappingBack = true;
        swapBack(tokensToBeAdded);
        _isSwappingBack = false;
        uint256 myUSDCAfter = ERC20(_usdc).balanceOf(address(this));
        uint256 usdcToAdd = myUSDCAfter.sub(myUSDCBefore);

        _approve(address(this), address(_uniswapV2Router), tokensToBeAdded);
        ERC20(_usdc).approve(address(_uniswapV2Router), usdcToAdd);

        _uniswapV2Router.addLiquidity(
            address(_usdc),
            address(this),
            usdcToAdd,
            tokensToBeAdded,
            0,
            0,
            _feeWallet,
            block.timestamp
        );

        emit LiquidityAdded(usdcToAdd, tokensToBeAdded);
        return true;
    }

    function enableTrading() public onlyOwner {
        _tradingActive = true;
        _limitsInEffect = true;
        _supportLevel = getCurrentPrice();
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function excludeFromMaxWallet(
        address account,
        bool excluded
    ) public onlyOwner {
        _isExcludedFromMaxWallet[account] = excluded;
    }

    function setLimitsInEffect(bool limitsInEffect) public onlyOwner {
        _limitsInEffect = limitsInEffect;
    }

    function setFeeWallet(address feeWallet) public onlyOwner {
        _feeWallet = feeWallet;
    }

    function setSupportLevel(uint256 supportLevel) public onlyOwner {
        _supportLevel = supportLevel;
    }

    function setNonUniswapExchange(
        address account,
        bool exists
    ) public onlyOwner {
        _isNonUniswapExchange[account] = exists;
    }

    function setFloorSellFee(uint256 floorSellFee) public onlyOwner {
        _floorSellFee = floorSellFee;
    }

    function setSupportPercentBelowATH(
        uint256 supportPercentBelowATH
    ) public onlyOwner {
        _supportPercentBelowATH = supportPercentBelowATH;
    }

    function setAddLiquidityAtAmount(
        uint256 addLiquidityAtAmount
    ) public onlyOwner {
        _addLiquidityAtAmount = addLiquidityAtAmount;
    }

    function SetUniswapV3Router(address uniswapV3Router) public onlyOwner {
        _uniswapV3Router = uniswapV3Router;
    }

    function setTokensForLiquidity(
        uint256 tokensForLiquidity
    ) public onlyOwner {
        _tokensForLiquidity = tokensForLiquidity;
    }

    function setBlackListed(address sender, bool exists) public onlyOwner {
        _isBlackListed[sender] = exists;
    }

    function setBlackListedSender(
        address sender,
        bool exists
    ) public onlyOwner {
        _isBlackListedSender[sender] = exists;
    }

    function rescue(address token) public onlyOwner {
        ERC20 Token = ERC20(token);
        uint256 balance = Token.balanceOf(address(this));
        if (balance > 0) Token.transfer(_msgSender(), balance);
    }

    function setFees(
        uint256 marketingFee,
        uint256 liquidityFee
    ) public onlyOwner {
        require(
            marketingFee.add(liquidityFee) <= 10,
            "Fees can't be greater than 10%"
        );
        _marketingFee = marketingFee;
        _liquidityFee = liquidityFee;
    }

    function setMaxWalletAmount(uint256 maxWallet) external onlyOwner {
        require(
            maxWallet >= ((totalSupply() * 5) / 1000) / 1e18,
            "Cannot set maxWallet lower than 0.5%"
        );
        _maxWallet = maxWallet * 1e18;
    }
}