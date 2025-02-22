/**
 *Submitted for verification at Etherscan.io on 2022-08-04
*/

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

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

    constructor () internal {
        _status = _NOT_ENTERED;
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
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: contracts/Helpers/GlideErrors.sol


// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.6.12;

// solhint-disable
library GlideErrors {
    // Liquid Staking
    uint256 internal constant UPDATE_EPOCH_NOT_ENOUGH_ELA = 101;
    uint256 internal constant RECEIVE_PAYLOAD_ADDRESS_ZERO = 102;
    uint256 internal constant REQUEST_WITHDRAW_NOT_ENOUGH_AMOUNT = 103;
    uint256 internal constant WITHDRAW_NOT_ENOUGH_AMOUNT = 104;
    uint256 internal constant WITHDRAW_TRANSFER_NOT_SUCCESS = 105;
    uint256 internal constant SET_STELA_TRANSFER_OWNER = 106;
    uint256 internal constant TRANSFER_STELA_OWNERSHIP = 107;
    uint256 internal constant EXCHANGE_RATE_MUST_BE_GREATER_OR_EQUAL_PREVIOUS =
        108;
    uint256 internal constant ELASTOS_MAINNET_ADDRESS_LENGTH = 109;
    uint256 internal constant EXCHANGE_RATE_UPPER_LIMIT = 110;
    uint256 internal constant STATUS_CANNOT_BE_ONHOLD = 111;
    uint256 internal constant STATUS_MUST_BE_ONHOLD = 112;

    // Liquid Staking Instant Swap
    uint256 internal constant FEE_RATE_IS_NOT_IN_RANGE = 201;
    uint256 internal constant NOT_ENOUGH_STELA_IN_CONTRACT = 202;
    uint256 internal constant NOT_ENOUGH_ELA_IN_CONTRACT = 203;
    uint256 internal constant SWAP_TRANSFER_NOT_SUCCEESS = 204;
    uint256 internal constant NO_ENOUGH_WITHDRAW_ELA_IN_CONTRACT = 205;

    /**
     * @dev Reverts if `condition` is false, with a revert reason containing `errorCode`. Only codes up to 999 are
     * supported.
     */
    function _require(bool condition, uint256 errorCode) internal pure {
        if (!condition) _revert(errorCode);
    }

    /**
     * @dev Reverts with a revert reason containing `errorCode`. Only codes up to 999 are supported.
     */
    function _revert(uint256 errorCode) internal pure {
        // We're going to dynamically create a revert string based on the error code, with the following format:
        // 'GLIDE#{errorCode}'
        // where the code is left-padded with zeroes to three digits (so they range from 000 to 999).
        //
        // We don't have revert strings embedded in the contract to save bytecode size: it takes much less space to store a
        // number (8 to 16 bits) than the individual string characters.
        //
        // The dynamic string creation algorithm that follows could be implemented in Solidity, but assembly allows for a
        // much denser implementation, again saving bytecode size. Given this function unconditionally reverts, this is a
        // safe place to rely on it without worrying about how its usage might affect e.g. memory contents.
        assembly {
            // First, we need to compute the ASCII representation of the error code. We assume that it is in the 0-999
            // range, so we only need to convert three digits. To convert the digits to ASCII, we add 0x30, the value for
            // the '0' character.

            let units := add(mod(errorCode, 10), 0x30)

            errorCode := div(errorCode, 10)
            let tenths := add(mod(errorCode, 10), 0x30)

            errorCode := div(errorCode, 10)
            let hundreds := add(mod(errorCode, 10), 0x30)

            // With the individual characters, we can now construct the full string. The "GLIDE#" part is a known constant
            // (0x474c49444523): we simply shift this by 24 (to provide space for the 3 bytes of the error code), and add the
            // characters to it, each shifted by a multiple of 8.
            // The revert reason is then shifted left by 200 bits (256 minus the length of the string, 7 characters * 8 bits
            // per character = 56) to locate it in the most significant part of the 256 slot (the beginning of a byte
            // array).

            let revertReason := shl(
                184,
                add(
                    0x474c49444523000000,
                    add(add(units, shl(8, tenths)), shl(16, hundreds))
                )
            )

            // We can now encode the reason in memory, which can be safely overwritten as we're about to revert. The encoded
            // message will have the following layout:
            // [ revert reason identifier ] [ string location offset ] [ string length ] [ string contents ]

            // The Solidity revert reason identifier is 0x08c739a0, the function selector of the Error(string) function. We
            // also write zeroes to the next 28 bytes of memory, but those are about to be overwritten.
            mstore(
                0x0,
                0x08c379a000000000000000000000000000000000000000000000000000000000
            )
            // Next is the offset to the location of the string, which will be placed immediately after (20 bytes away).
            mstore(
                0x04,
                0x0000000000000000000000000000000000000000000000000000000000000020
            )
            // The string length is fixed: 7 characters.
            mstore(0x24, 9)
            // Finally, the string itself is stored.
            mstore(0x44, revertReason)

            // Even if the string is only 7 bytes long, we need to return a full 32 byte slot containing it. The length of
            // the encoded message is therefore 4 + 32 + 32 + 32 = 100.
            revert(0, 100)
        }
    }
}

// File: @openzeppelin/contracts/math/SafeMath.sol



pragma solidity >=0.6.0 <0.8.0;

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
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol



pragma solidity >=0.6.0 <0.8.0;

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

// File: @openzeppelin/contracts/utils/Context.sol



pragma solidity >=0.6.0 <0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol



pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol



pragma solidity >=0.6.0 <0.8.0;




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
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
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
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
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

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// File: contracts/LiquidStaking/stELAToken.sol


pragma solidity ^0.6.12;



// solhint-disable-next-line contract-name-camelcase
contract stELAToken is ERC20("Staked ELA", "stELA"), Ownable {
    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (LiquidStaking).
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Creates `_amount` token from `_from`. Must only be called by the owner (LiquidStaking).
    function burn(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }
}

// File: contracts/LiquidStaking/interfaces/ICrossChainPayload.sol


pragma solidity ^0.6.12;

interface ICrossChainPayload {
    function receivePayload(
        string memory _addr,
        uint256 _amount,
        uint256 _fee
    ) external payable;
}

// File: contracts/LiquidStaking/interfaces/ILiquidStaking.sol


pragma solidity ^0.6.12;


interface ILiquidStaking {
    struct WithrawRequest {
        uint256 elaAmount;
        uint256 epoch;
    }

    struct WithdrawReady {
        uint256 elaAmount;
        uint256 elaOnHoldAmount;
    }

    event Deposit(
        address indexed user,
        uint256 elaAmountDeposited,
        uint256 stELAAmountReceived
    );

    event WithdrawRequest(
        address indexed user,
        uint256 amount,
        uint256 elaAmount
    );

    event Withdraw(address indexed user, uint256 elaReceived);

    event Fund(address indexed user, uint256 elaAmount);

    event Epoch(uint256 indexed epoch, uint256 exchangeRate);

    event ReceivePayloadAddressChange(string indexed newAddress);

    event ReceivePayloadFeeChange(uint256 newFee);

    event EnableWithdraw(uint256 elaAmountForWithdraw);

    event StELATransferOwner(address indexed newAddress);

    event StELAOwner(address indexed newAddress);

    /// @dev Set mainchain address for crosschain transfer where ELA will be deposit
    /// @param _receivePayloadAddress Mainchain address
    function setReceivePayloadAddress(string calldata _receivePayloadAddress)
        external
        payable;

    /// @dev Set fee that will be paid for crosschain transfer when user deposit ELA
    /// @param _receivePayloadFee Fee amount
    function setReceivePayloadFee(uint256 _receivePayloadFee) external payable;

    /// @dev First step for update epoch (before amount send to contract)
    /// @param _exchangeRate Exchange rate
    function updateEpoch(uint256 _exchangeRate) external;

    /// @dev Second step for update epoch (after balance for withdrawal received)
    function enableWithdraw() external;

    /// @dev How much amount needed before beginEpoch (complete update epoch)
    /// @return uint256 Amount that is needed to be provided before enableWithdraw
    function getUpdateEpochAmount() external view returns (uint256);

    /// @dev Deposit ELA amount and get stELA token
    function deposit() external payable;

    /// @dev Request withdraw stELA amount and get ELA
    /// @param _amount stELA amount that user requested to withdraw
    function requestWithdraw(uint256 _amount) external;

    /// @dev Withdraw stELA amount and get ELA coin
    /// @param _amount stELA amount that the user wants to withdraw
    function withdraw(uint256 _amount) external;

    /// @dev Transfer owner will be set to a TimeLock contract
    /// @param _stELATransferOwner address that controls ownership of the stELA token
    function setstELATransferOwner(address _stELATransferOwner) external;

    /// @dev Allow for the migration of the stELA token contract if upgrades are made to the LiquidStaking functions
    /// @param _newOwner target address for transferring ownership of the stELA token
    function transferstELAOwnership(address _newOwner) external;

    /// @dev Convert stELA to ELA based on current exchange rate
    /// @param _stELAAmount amount of stELA token to be withdrawn
    function getELAAmountForWithdraw(uint256 _stELAAmount)
        external
        view
        returns (uint256);
}

// File: contracts/LiquidStaking/LiquidStaking.sol


pragma solidity ^0.6.12;








contract LiquidStaking is ILiquidStaking, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 private constant _EXCHANGE_RATE_DIVIDER = 10000;
    uint256 private constant _EXCHANGE_RATE_UPPER_LIMIT = 100;

    stELAToken public immutable stELA;
    ICrossChainPayload public immutable crossChainPayload;

    mapping(address => WithrawRequest) public withdrawRequests;
    mapping(address => WithdrawReady) public withdrawReady;

    address public stELATransferOwner;

    string public receivePayloadAddress;
    uint256 public receivePayloadFee;

    bool public onHold;
    uint256 public exchangeRate;
    uint256 public currentEpoch;
    uint256 public totalELAWithdrawRequested;
    uint256 public currentEpochRequestTotal;
    uint256 public prevEpochRequestTotal;
    uint256 public totalELA;

    constructor(
        stELAToken _stELA,
        ICrossChainPayload _crossChainPayload,
        string memory _receivePayloadAddress,
        uint256 _receivePayloadFee
    ) public {
        stELA = _stELA;
        crossChainPayload = _crossChainPayload;
        receivePayloadAddress = _receivePayloadAddress;
        receivePayloadFee = _receivePayloadFee;
        exchangeRate = _EXCHANGE_RATE_DIVIDER;
        currentEpoch = 1;
        stELATransferOwner = msg.sender;
    }

    receive() external payable onlyOwner {
        totalELA = totalELA.add(msg.value);
        prevEpochRequestTotal = totalELA;

        emit Fund(msg.sender, msg.value);
    }

    function setReceivePayloadAddress(string calldata _receivePayloadAddress)
        external
        payable
        override
        onlyOwner
    {
        GlideErrors._require(
            bytes(_receivePayloadAddress).length == 34,
            GlideErrors.ELASTOS_MAINNET_ADDRESS_LENGTH
        );

        receivePayloadAddress = _receivePayloadAddress;

        emit ReceivePayloadAddressChange(_receivePayloadAddress);
    }

    function setReceivePayloadFee(uint256 _receivePayloadFee)
        external
        payable
        override
        onlyOwner
    {
        receivePayloadFee = _receivePayloadFee;

        emit ReceivePayloadFeeChange(receivePayloadFee);
    }

    function updateEpoch(uint256 _exchangeRate) external override onlyOwner {
        GlideErrors._require(
            _exchangeRate >= exchangeRate,
            GlideErrors.EXCHANGE_RATE_MUST_BE_GREATER_OR_EQUAL_PREVIOUS
        );

        GlideErrors._require(
            _exchangeRate <= exchangeRate.add(_EXCHANGE_RATE_UPPER_LIMIT),
            GlideErrors.EXCHANGE_RATE_UPPER_LIMIT
        );

        GlideErrors._require(!onHold, GlideErrors.STATUS_CANNOT_BE_ONHOLD);

        totalELAWithdrawRequested = totalELAWithdrawRequested.add(
            currentEpochRequestTotal
        );
        currentEpochRequestTotal = 0;
        currentEpoch = currentEpoch.add(1);
        exchangeRate = _exchangeRate;
        onHold = true;

        emit Epoch(currentEpoch, _exchangeRate);
    }

    function enableWithdraw() external override onlyOwner {
        GlideErrors._require(onHold, GlideErrors.STATUS_MUST_BE_ONHOLD);

        GlideErrors._require(
            prevEpochRequestTotal >= totalELAWithdrawRequested,
            GlideErrors.UPDATE_EPOCH_NOT_ENOUGH_ELA
        );
        prevEpochRequestTotal = 0;
        onHold = false;

        emit EnableWithdraw(totalELAWithdrawRequested);
    }

    function getUpdateEpochAmount() external view override returns (uint256) {
        if (totalELAWithdrawRequested > prevEpochRequestTotal) {
            return totalELAWithdrawRequested.sub(prevEpochRequestTotal);
        }
        return 0;
    }

    function deposit() external payable override nonReentrant {
        GlideErrors._require(
            bytes(receivePayloadAddress).length != 0,
            GlideErrors.RECEIVE_PAYLOAD_ADDRESS_ZERO
        );

        uint256 receivePayloadAmount = msg.value.sub(receivePayloadFee);
        uint256 amountOut = (receivePayloadAmount.mul(_EXCHANGE_RATE_DIVIDER))
            .div(exchangeRate);
        stELA.mint(msg.sender, amountOut);

        crossChainPayload.receivePayload{value: msg.value}(
            receivePayloadAddress,
            msg.value,
            receivePayloadFee
        );

        emit Deposit(msg.sender, msg.value, amountOut);
    }

    function requestWithdraw(uint256 _stELAAmount) external override nonReentrant {
        GlideErrors._require(
            _stELAAmount <= stELA.balanceOf(msg.sender),
            GlideErrors.REQUEST_WITHDRAW_NOT_ENOUGH_AMOUNT
        );

        _withdrawRequestToReadyTransfer();

        uint256 elaAmount = getELAAmountForWithdraw(_stELAAmount);

        withdrawRequests[msg.sender].elaAmount = withdrawRequests[msg.sender]
            .elaAmount
            .add(elaAmount);
        withdrawRequests[msg.sender].epoch = currentEpoch;

        currentEpochRequestTotal = currentEpochRequestTotal.add(elaAmount);

        stELA.burn(msg.sender, _stELAAmount);

        emit WithdrawRequest(msg.sender, _stELAAmount, elaAmount);
    }

    function withdraw(uint256 _elaAmount) external override nonReentrant {
        _withdrawRequestToReadyTransfer();

        if (!onHold) {
            if (withdrawReady[msg.sender].elaOnHoldAmount > 0) {
                withdrawReady[msg.sender].elaAmount = withdrawReady[msg.sender]
                    .elaAmount
                    .add(withdrawReady[msg.sender].elaOnHoldAmount);
                withdrawReady[msg.sender].elaOnHoldAmount = 0;
            }
        }

        GlideErrors._require(
            _elaAmount <= withdrawReady[msg.sender].elaAmount,
            GlideErrors.WITHDRAW_NOT_ENOUGH_AMOUNT
        );
        withdrawReady[msg.sender].elaAmount = withdrawReady[msg.sender]
            .elaAmount
            .sub(_elaAmount);

        totalELAWithdrawRequested = totalELAWithdrawRequested.sub(_elaAmount);
        totalELA = totalELA.sub(_elaAmount);

        // solhint-disable-next-line avoid-low-level-calls
        (bool successTransfer, ) = payable(msg.sender).call{value: _elaAmount}(
            ""
        );
        GlideErrors._require(
            successTransfer,
            GlideErrors.WITHDRAW_TRANSFER_NOT_SUCCESS
        );

        emit Withdraw(msg.sender, _elaAmount);
    }

    function setstELATransferOwner(address _stELATransferOwner)
        external
        override
    {
        GlideErrors._require(
            msg.sender == stELATransferOwner,
            GlideErrors.SET_STELA_TRANSFER_OWNER
        );
        stELATransferOwner = _stELATransferOwner;

        emit StELATransferOwner(_stELATransferOwner);
    }

    function transferstELAOwnership(address _newOwner) external override {
        GlideErrors._require(
            msg.sender == stELATransferOwner,
            GlideErrors.TRANSFER_STELA_OWNERSHIP
        );
        stELA.transferOwnership(_newOwner);

        emit StELAOwner(_newOwner);
    }

    function getELAAmountForWithdraw(uint256 _stELAAmount)
        public
        view
        override
        returns (uint256)
    {
        return _stELAAmount.mul(exchangeRate).div(_EXCHANGE_RATE_DIVIDER);
    }

    /// @dev Check if user has existing withdrawal request and add to ready status if funds are available
    function _withdrawRequestToReadyTransfer() internal {
        if (
            withdrawRequests[msg.sender].elaAmount > 0 &&
            withdrawRequests[msg.sender].epoch < currentEpoch
        ) {
            if (
                onHold &&
                currentEpoch.sub(withdrawRequests[msg.sender].epoch) == 1
            ) {
                withdrawReady[msg.sender].elaOnHoldAmount = withdrawReady[
                    msg.sender
                ].elaOnHoldAmount.add(withdrawRequests[msg.sender].elaAmount);
            } else {
                withdrawReady[msg.sender].elaAmount = withdrawReady[msg.sender]
                    .elaAmount
                    .add(withdrawRequests[msg.sender].elaAmount)
                    .add(withdrawReady[msg.sender].elaOnHoldAmount);
                withdrawReady[msg.sender].elaOnHoldAmount = 0;
            }
            withdrawRequests[msg.sender].elaAmount = 0;
        }
    }
}