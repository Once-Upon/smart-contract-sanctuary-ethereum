/**
 *Submitted for verification at Etherscan.io on 2022-08-09
*/

// SPDX-License-Identifier: GPL-3.0-only
// File: @openzeppelin/contracts/introspection/IERC165.sol


pragma solidity >=0.6.0 <0.8.0;

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

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


pragma solidity >=0.6.2 <0.8.0;

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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol


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

// File: contracts/v1.5/AuctionFractions.sol

pragma solidity ^0.6.0;

contract AuctionFractions
{
	fallback () external payable
	{
		assembly {
			calldatacopy(0, 0, calldatasize())
			let result := delegatecall(gas(), 0x8fCD445E86ecF0C79355C5dF257A4E5A32C73AfE, 0, calldatasize(), 0, 0) // replace 2nd parameter by AuctionFractionsImpl address on deploy
			returndatacopy(0, 0, returndatasize())
			switch result
			case 0 { revert(0, returndatasize()) }
			default { return(0, returndatasize()) }
		}
	}
}

// File: @openzeppelin/contracts/GSN/Context.sol


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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
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
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
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
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
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
    function _setupDecimals(uint8 decimals_) internal {
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

// File: @openzeppelin/contracts/utils/Address.sol


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

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol


pragma solidity >=0.6.0 <0.8.0;



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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


pragma solidity >=0.6.0 <0.8.0;

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
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// File: @openzeppelin/contracts/token/ERC721/ERC721Holder.sol


pragma solidity >=0.6.0 <0.8.0;

  /**
   * @dev Implementation of the {IERC721Receiver} interface.
   *
   * Accepts all token transfers. 
   * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
   */
contract ERC721Holder is IERC721Receiver {

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// File: @openzeppelin/contracts/token/ERC721/IERC721Metadata.sol


pragma solidity >=0.6.2 <0.8.0;

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

// File: @openzeppelin/contracts/utils/Strings.sol


pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    /**
     * @dev Converts a `uint256` to its ASCII `string` representation.
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
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = byte(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }
}

// File: contracts/v1.5/SafeERC721.sol

pragma solidity ^0.6.0;


library SafeERC721
{
	function safeName(IERC721Metadata _metadata) internal view returns (string memory _name)
	{
		try _metadata.name() returns (string memory _n) { return _n; } catch {}
	}

	function safeSymbol(IERC721Metadata _metadata) internal view returns (string memory _symbol)
	{
		try _metadata.symbol() returns (string memory _s) { return _s; } catch {}
	}

	function safeTokenURI(IERC721Metadata _metadata, uint256 _tokenId) internal view returns (string memory _tokenURI)
	{
		try _metadata.tokenURI(_tokenId) returns (string memory _t) { return _t; } catch {}
	}

	function safeTransfer(IERC721 _token, address _to, uint256 _tokenId) internal
	{
		address _from = address(this);
		try _token.transferFrom(_from, _to, _tokenId) { return; } catch {}
		// attempts to handle non-conforming ERC721 contracts
		_token.approve(_from, _tokenId);
		_token.transferFrom(_from, _to, _tokenId);
	}
}

// File: contracts/v1.5/AuctionFractionsImpl.sol

pragma solidity ^0.6.0;








contract AuctionFractionsImpl is ERC721Holder, ERC20, ReentrancyGuard
{
	using SafeERC20 for IERC20;
	using SafeERC721 for IERC721;
	using SafeERC721 for IERC721Metadata;
	using Strings for uint256;

	address public target;
	uint256 public tokenId;
	uint256 public fractionsCount;
	uint256 public fractionPrice;
	address public paymentToken;
	uint256 public kickoff;
	uint256 public duration;
	uint256 public fee;
	address public vault;

	bool public released;
	uint256 public cutoff;
	address payable public bidder;

	uint256 private lockedFractions_;
	uint256 private lockedAmount_;

	string private name_;
	string private symbol_;

	constructor () ERC20("Fractions", "FRAC") public
	{
		target = address(-1); // prevents proxy code from misuse
	}

	function __name() public view /*override*/ returns (string memory _name) // rename to name() and change name() on ERC20 to virtual to be able to override on deploy
	{
		if (bytes(name_).length != 0) return name_;
		return string(abi.encodePacked(IERC721Metadata(target).safeName(), " #", tokenId.toString(), " Fractions"));
	}

	function __symbol() public view /*override*/ returns (string memory _symbol) // rename to name() and change name() on ERC20 to virtual to be able to override on deploy
	{
		if (bytes(symbol_).length != 0) return symbol_;
		return string(abi.encodePacked(IERC721Metadata(target).safeSymbol(), tokenId.toString()));
	}

	modifier onlyOwner()
	{
		require(isOwner(msg.sender), "access denied");
		_;
	}

	modifier onlyHolder()
	{
		require(balanceOf(msg.sender) > 0, "access denied");
		_;
	}

	modifier onlyBidder()
	{
		require(msg.sender == bidder, "access denied");
		_;
	}

	modifier inAuction()
	{
		require(kickoff <= now && now <= cutoff, "not available");
		_;
	}

	modifier afterAuction()
	{
		require(now > cutoff, "not available");
		_;
	}

	function initialize(address _from, address _target, uint256 _tokenId, string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken, uint256 _kickoff, uint256 _duration, uint256 _fee, address _vault) external
	{
		require(target == address(0), "already initialized");
		require(IERC721(_target).ownerOf(_tokenId) == address(this), "missing token");
		require(_fractionsCount > 0, "invalid count");
		require(_fractionsCount * _fractionPrice / _fractionsCount == _fractionPrice, "price overflow");
		require(_paymentToken != address(this), "invalid token");
		require(_kickoff <= now + 731 days, "invalid kickoff");
		require(30 minutes <= _duration && _duration <= 731 days, "invalid duration");
		require(_fee <= 1e18, "invalid fee");
		require(_vault != address(0), "invalid address");
		target = _target;
		tokenId = _tokenId;
		fractionsCount = _fractionsCount;
		fractionPrice = _fractionPrice;
		paymentToken = _paymentToken;
		kickoff = _kickoff;
		duration = _duration;
		fee = _fee;
		vault = _vault;
		released = false;
		cutoff = uint256(-1);
		bidder = address(0);
		name_ = _name;
		symbol_ = _symbol;
		_setupDecimals(_decimals);
		uint256 _feeFractionsCount = _fractionsCount.mul(_fee) / 1e18;
		uint256 _netFractionsCount = _fractionsCount - _feeFractionsCount;
		_mint(_from, _netFractionsCount);
		_mint(address(this), _feeFractionsCount);
		lockedFractions_ = _feeFractionsCount;
		lockedAmount_ = 0;
	}

	function status() external view returns (string memory _status)
	{
		return bidder == address(0) ? now < kickoff ? "PAUSE" : "OFFER" : now > cutoff ? "SOLD" : "AUCTION";
	}

	function isOwner(address _from) public view returns (bool _soleOwner)
	{
		return bidder == address(0) && balanceOf(_from) + lockedFractions_ == fractionsCount;
	}

	function reservePrice() external view returns (uint256 _reservePrice)
	{
		return fractionsCount * fractionPrice;
	}

	function bidRangeOf(address _from) external view inAuction returns (uint256 _minFractionPrice, uint256 _maxFractionPrice)
	{
		if (bidder == address(0)) {
			_minFractionPrice = fractionPrice;
		} else {
			_minFractionPrice = (fractionPrice * 11 + 9) / 10; // 10% increase, rounded up
		}
		uint256 _fractionsCount = balanceOf(_from);
		if (bidder == _from) _fractionsCount += lockedFractions_;
		if (_fractionsCount == 0) {
			_maxFractionPrice = uint256(-1);
		} else {
			_maxFractionPrice = _minFractionPrice + (fractionsCount * fractionsCount * fractionPrice) / (_fractionsCount * _fractionsCount * 100); // 1% / (ownership ^ 2)
		}
		return (_minFractionPrice, _maxFractionPrice);
	}

	function bidAmountOf(address _from, uint256 _newFractionPrice) external view inAuction returns (uint256 _bidAmount)
	{
		uint256 _fractionsCount = balanceOf(_from);
		if (bidder == _from) _fractionsCount += lockedFractions_;
		return (fractionsCount - _fractionsCount) * _newFractionPrice;
	}

	function vaultBalance() external view returns (uint256 _vaultBalance)
	{
		if (now <= cutoff) return 0;
		uint256 _fractionsCount = totalSupply();
		return _fractionsCount * fractionPrice;
	}

	function vaultBalanceOf(address _from) external view returns (uint256 _vaultBalanceOf)
	{
		if (now <= cutoff) return 0;
		uint256 _fractionsCount = balanceOf(_from);
		return _fractionsCount * fractionPrice;
	}

	function updatePrice(uint256 _newFractionPrice) external onlyOwner
	{
		address _from = msg.sender;
		require(fractionsCount * _newFractionPrice / fractionsCount == _newFractionPrice, "price overflow");
		uint256 _oldFractionPrice = fractionPrice;
		fractionPrice = _newFractionPrice;
		emit UpdatePrice(_from, _oldFractionPrice, _newFractionPrice);
	}

	function cancel() external nonReentrant onlyOwner
	{
		address _from = msg.sender;
		released = true;
		_burn(_from, balanceOf(_from));
		_burn(address(this), lockedFractions_);
		IERC721(target).safeTransfer(_from, tokenId);
		emit Cancel(_from);
		_cleanup();
	}

	function bid(uint256 _newFractionPrice) external payable nonReentrant inAuction
	{
		address payable _from = msg.sender;
		uint256 _value = msg.value;
		require(fractionsCount * _newFractionPrice / fractionsCount == _newFractionPrice, "price overflow");
		uint256 _oldFractionPrice = fractionPrice;
		uint256 _fractionsCount;
		if (bidder == address(0)) {
			_transfer(address(this), vault, lockedFractions_);
			_fractionsCount = balanceOf(_from);
			uint256 _fractionsCount2 = _fractionsCount * _fractionsCount;
			require(_newFractionPrice >= _oldFractionPrice, "below minimum");
			require(_newFractionPrice * _fractionsCount2 * 100 <= _oldFractionPrice * (_fractionsCount2 * 100 + fractionsCount * fractionsCount), "above maximum"); // <= 1% / (ownership ^ 2)
			cutoff = now + duration;
		} else {
			if (lockedFractions_ > 0) _transfer(address(this), bidder, lockedFractions_);
			_safeTransfer(paymentToken, bidder, lockedAmount_);
			_fractionsCount = balanceOf(_from);
			uint256 _fractionsCount2 = _fractionsCount * _fractionsCount;
			require(_newFractionPrice * 10 >= _oldFractionPrice * 11, "below minimum"); // >= 10%
			require(_newFractionPrice * _fractionsCount2 * 100 <= _oldFractionPrice * (_fractionsCount2 * 110 + fractionsCount * fractionsCount), "above maximum"); // <= 10% + 1% / (ownership ^ 2)
			if (cutoff < now + 15 minutes) cutoff = now + 15 minutes;
		}
		bidder = _from;
		fractionPrice = _newFractionPrice;
		uint256 _bidAmount = (fractionsCount - _fractionsCount) * _newFractionPrice;
		if (_fractionsCount > 0) _transfer(_from, address(this), _fractionsCount);
		_safeTransferFrom(paymentToken, _from, _value, payable(address(this)), _bidAmount);
		lockedFractions_ = _fractionsCount;
		lockedAmount_ = _bidAmount;
		emit Bid(_from, _oldFractionPrice, _newFractionPrice, _fractionsCount, _bidAmount);
	}

	function redeem() external nonReentrant onlyBidder afterAuction
	{
		address _from = msg.sender;
		require(!released, "missing token");
		released = true;
		_burn(address(this), lockedFractions_);
		IERC721(target).safeTransfer(_from, tokenId);
		emit Redeem(_from);
		_cleanup();
	}

	function claim() external nonReentrant onlyHolder afterAuction
	{
		address payable _from = msg.sender;
		uint256 _fractionsCount = balanceOf(_from);
		uint256 _claimAmount = _fractionsCount * fractionPrice;
		_burn(_from, _fractionsCount);
		_safeTransfer(paymentToken, _from, _claimAmount);
		emit Claim(_from, _fractionsCount, _claimAmount);
		_cleanup();
	}

	function _cleanup() internal
	{
		uint256 _fractionsCount = totalSupply();
		if (released && _fractionsCount == 0) {
			selfdestruct(address(0));
		}
	}

	function _safeTransfer(address _token, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			_to.transfer(_amount);
		} else {
			IERC20(_token).safeTransfer(_to, _amount);
		}
	}

	function _safeTransferFrom(address _token, address payable _from, uint256 _value, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			require(_value == _amount, "invalid value");
			if (_to != address(this)) _to.transfer(_amount);
		} else {
			require(_value == 0, "invalid value");
			IERC20(_token).safeTransferFrom(_from, _to, _amount);
		}
	}

	event UpdatePrice(address indexed _from, uint256 _oldFractionPrice, uint256 _newFractionPrice);
	event Cancel(address indexed _from);
	event Bid(address indexed _from, uint256 _oldFractionPrice, uint256 _newFractionPrice, uint256 _fractionsCount, uint256 _bidAmount);
	event Redeem(address indexed _from);
	event Claim(address indexed _from, uint256 _fractionsCount, uint256 _claimAmount);
}

// File: contracts/v1.5/IAuctionFractionalizer.sol

pragma solidity ^0.6.0;

interface IAuctionFractionalizer
{
	function fractionalize(address _target, uint256 _tokenId, string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken, uint256 _kickoff, uint256 _duration, uint256 _fee) external returns (address _fractions);
}

// File: contracts/v1.5/AuctionFractionalizer.sol

pragma solidity ^0.6.0;




contract AuctionFractionalizer is IAuctionFractionalizer, ReentrancyGuard
{
	address public immutable vault;

	constructor (address _vault) public
	{
		vault = _vault;
	}

	function fractionalize(address _target, uint256 _tokenId, string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken, uint256 _kickoff, uint256 _duration, uint256 _fee) external override nonReentrant returns (address _fractions)
	{
		address _from = msg.sender;
		_fractions = address(new AuctionFractions());
		IERC721(_target).transferFrom(_from, _fractions, _tokenId);
		AuctionFractionsImpl(_fractions).initialize(_from, _target, _tokenId, _name, _symbol, _decimals, _fractionsCount, _fractionPrice, _paymentToken, _kickoff, _duration, _fee, vault);
		emit Fractionalize(_from, _target, _tokenId, _fractions);
		return _fractions;
	}

	event Fractionalize(address indexed _from, address indexed _target, uint256 indexed _tokenId, address _fractions);
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
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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

// File: contracts/v1.5/CollectivePurchase.sol

pragma solidity ^0.6.0;








contract CollectivePurchase is ERC721Holder, Ownable, ReentrancyGuard
{
	using SafeERC20 for IERC20;
	using SafeERC721 for IERC721;
	using SafeMath for uint256;

	enum State { Created, Funded, Started, Ended }

	struct BuyerInfo {
		uint256 amount;
	}

	struct ListingInfo {
		State state;
		address payable seller;
		address collection;
		uint256 tokenId;
		address paymentToken;
		uint256 reservePrice;
		uint256 limitPrice;
		uint256 extension;
		uint256 priceMultiplier;
		bytes extra;
		uint256 amount;
		uint256 cutoff;
		uint256 fractionsCount;
		address fractions;
		mapping (address => BuyerInfo) buyers;
	}

	uint8 constant public FRACTIONS_DECIMALS = 6;
	uint256 constant public FRACTIONS_COUNT = 100000e6;

	uint256 public immutable fee;
	address payable public immutable vault;
	mapping (bytes32 => address) public fractionalizers;

	mapping (address => uint256) private balances;
	mapping (address => mapping (uint256 => bool)) private items;

	ListingInfo[] public listings;

	modifier onlySeller(uint256 _listingId)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(msg.sender == _listing.seller, "access denied");
		_;
	}

	modifier inState(uint256 _listingId, State _state)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(_state == _listing.state, "not available");
		_;
	}

	modifier notInState(uint256 _listingId, State _state)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(_state != _listing.state, "not available");
		_;
	}

	constructor (uint256 _fee, address payable _vault) public
	{
		require(_fee <= 1e18, "invalid fee");
		require(_vault != address(0), "invalid address");
		fee = _fee;
		vault = _vault;
	}

	function listingCount() external view returns (uint256 _count)
	{
		return listings.length;
	}

	function buyers(uint256 _listingId, address _buyer) external view returns (uint256 _amount)
	{
		ListingInfo storage _listing = listings[_listingId];
		BuyerInfo storage _info = _listing.buyers[_buyer];
		return _info.amount;
	}

	function status(uint256 _listingId) external view returns (string memory _status)
	{
		ListingInfo storage _listing = listings[_listingId];
		if (_listing.state == State.Created) return "CREATED";
		if (_listing.state == State.Funded) return "FUNDED";
		if (_listing.state == State.Started) return now <= _listing.cutoff ? "STARTED" : "ENDING";
		return "ENDED";
	}

	function maxJoinAmount(uint256 _listingId) external view returns (uint256 _amount)
	{
		ListingInfo storage _listing = listings[_listingId];
		return _listing.limitPrice - _listing.amount;
	}

	function buyerFractionsCount(uint256 _listingId, address _buyer) external view inState(_listingId, State.Ended) returns (uint256 _fractionsCount)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		_fractionsCount = (_amount * _listing.fractionsCount) / _listing.reservePrice;
		return _fractionsCount;
	}

	function sellerPayout(uint256 _listingId) external view returns (uint256 _netAmount, uint256 _feeAmount, uint256 _netFractionsCount, uint256 _feeFractionsCount)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _reservePrice = _listing.reservePrice;
		uint256 _amount = _listing.amount;
		_feeAmount = (_amount * fee) / 1e18;
		_netAmount = _amount - _feeAmount;
		_feeFractionsCount = 0;
		_netFractionsCount = 0;
		if (_reservePrice > _amount) {
			uint256 _missingAmount = _reservePrice - _amount;
			uint256 _missingFeeAmount = (_missingAmount * fee) / 1e18;
			uint256 _missingNetAmount = _missingAmount - _missingFeeAmount;
			uint256 _fractionsCount = _issuing(_listing.extra);
			_feeFractionsCount = _fractionsCount * _missingFeeAmount / _reservePrice;
			_netFractionsCount = _fractionsCount * _missingNetAmount / _reservePrice;
		}
	}

	function addFractionalizer(bytes32 _type, address _fractionalizer) external onlyOwner
	{
		require(fractionalizers[_type] == address(0), "already defined");
		fractionalizers[_type] = _fractionalizer;
		emit AddFractionalizer(_type, _fractionalizer);
	}

	function list(address _collection, uint256 _tokenId, address _paymentToken, uint256 _reservePrice, uint256 _limitPrice, uint256 _extension, uint256 _priceMultiplier, bytes calldata _extra) external nonReentrant returns (uint256 _listingId)
	{
		address payable _seller = msg.sender;
		require(_limitPrice * 1e18 / _limitPrice == 1e18, "price overflow");
		require(0 < _reservePrice && _reservePrice <= _limitPrice, "invalid price");
		require(30 minutes <= _extension && _extension <= 731 days, "invalid duration");
		require(0 < _priceMultiplier && _priceMultiplier <= 10000, "invalid multiplier"); // from 1% up to 100x
		_validate(_extra);
		IERC721(_collection).transferFrom(_seller, address(this), _tokenId);
		items[_collection][_tokenId] = true;
		_listingId = listings.length;
		listings.push(ListingInfo({
			state: State.Created,
			seller: _seller,
			collection: _collection,
			tokenId: _tokenId,
			paymentToken: _paymentToken,
			reservePrice: _reservePrice,
			limitPrice: _limitPrice,
			extension: _extension,
			priceMultiplier: _priceMultiplier,
			extra: _extra,
			amount: 0,
			cutoff: uint256(-1),
			fractionsCount: 0,
			fractions: address(0)
		}));
		emit Listed(_listingId);
		return _listingId;
	}

	function cancel(uint256 _listingId) external nonReentrant onlySeller(_listingId) inState(_listingId, State.Created)
	{
		ListingInfo storage _listing = listings[_listingId];
		_listing.state = State.Ended;
		items[_listing.collection][_listing.tokenId] = false;
		IERC721(_listing.collection).safeTransfer(_listing.seller, _listing.tokenId);
		emit Canceled(_listingId);
	}

	function updatePrice(uint256 _listingId, uint256 _newReservePrice, uint256 _newLimitPrice) external onlySeller(_listingId) inState(_listingId, State.Created)
	{
		require(_newLimitPrice * 1e18 / _newLimitPrice == 1e18, "price overflow");
		require(0 < _newReservePrice && _newReservePrice <= _newLimitPrice, "invalid price");
		ListingInfo storage _listing = listings[_listingId];
		uint256 _oldReservePrice = _listing.reservePrice;
		uint256 _oldLimitPrice = _listing.limitPrice;
		_listing.reservePrice = _newReservePrice;
		_listing.limitPrice = _newLimitPrice;
		emit UpdatePrice(_listingId, _oldReservePrice, _oldLimitPrice, _newReservePrice, _newLimitPrice);
	}

	function accept(uint256 _listingId) external onlySeller(_listingId) inState(_listingId, State.Funded)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.reservePrice - _listing.amount;
		uint256 _feeAmount = (_amount * fee) / 1e18;
		uint256 _netAmount = _amount - _feeAmount;
		_listing.state = State.Started;
		_listing.cutoff = now - 1;
		_listing.buyers[vault].amount += _feeAmount;
		_listing.buyers[_listing.seller].amount += _netAmount;
		emit Sold(_listingId);
	}

	function join(uint256 _listingId, uint256 _amount) external payable nonReentrant notInState(_listingId, State.Ended)
	{
		address payable _buyer = msg.sender;
		uint256 _value = msg.value;
		ListingInfo storage _listing = listings[_listingId];
		require(now <= _listing.cutoff, "not available");
		uint256 _leftAmount = _listing.limitPrice - _listing.amount;
		require(_amount <= _leftAmount, "limit exceeded");
		_safeTransferFrom(_listing.paymentToken, _buyer, _value, payable(address(this)), _amount);
		balances[_listing.paymentToken] += _amount;
		_listing.amount += _amount;
		_listing.buyers[_buyer].amount += _amount;
		if (_listing.state == State.Created) _listing.state = State.Funded;
		if (_listing.state == State.Funded) {
			if (_listing.amount >= _listing.reservePrice) {
				_listing.state = State.Started;
				_listing.cutoff = now + _listing.extension;
				emit Sold(_listingId);
			}
		}
		if (_listing.state == State.Started) _listing.reservePrice = _listing.amount;
		emit Join(_listingId, _buyer, _amount);
	}

	function leave(uint256 _listingId) external nonReentrant inState(_listingId, State.Funded)
	{
		address payable _buyer = msg.sender;
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		require(_amount > 0, "insufficient balance");
		_listing.buyers[_buyer].amount = 0;
		_listing.amount -= _amount;
		balances[_listing.paymentToken] -= _amount;
		if (_listing.amount == 0) _listing.state = State.Created;
		_safeTransfer(_listing.paymentToken, _buyer, _amount);
		emit Leave(_listingId, _buyer, _amount);
	}

	function relist(uint256 _listingId) public nonReentrant inState(_listingId, State.Started)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(now > _listing.cutoff, "not available");
		uint256 _fractionPrice = (_listing.reservePrice + (FRACTIONS_COUNT - 1)) / FRACTIONS_COUNT;
		uint256 _relistFractionPrice = (_listing.priceMultiplier * _fractionPrice + 99) / 100;
		_listing.state = State.Ended;
		_listing.fractions = _fractionalize(_listingId, _relistFractionPrice);
		_listing.fractionsCount = _balanceOf(_listing.fractions);
		items[_listing.collection][_listing.tokenId] = false;
		balances[_listing.fractions] = _listing.fractionsCount;
		emit Relisted(_listingId);
	}

	function payout(uint256 _listingId) public nonReentrant inState(_listingId, State.Ended)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.amount;
		require(_amount > 0, "insufficient balance");
		uint256 _feeAmount = (_amount * fee) / 1e18;
		uint256 _netAmount = _amount - _feeAmount;
		_listing.amount = 0;
		balances[_listing.paymentToken] -= _amount;
		_safeTransfer(_listing.paymentToken, vault, _feeAmount);
		_safeTransfer(_listing.paymentToken, _listing.seller, _netAmount);
		emit Payout(_listingId, _listing.seller, _netAmount, _feeAmount);
	}

	function claim(uint256 _listingId, address payable _buyer) public nonReentrant inState(_listingId, State.Ended)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		require(_amount > 0, "insufficient balance");
		uint256 _fractionsCount = (_amount * _listing.fractionsCount) / _listing.reservePrice;
		_listing.buyers[_buyer].amount = 0;
		balances[_listing.fractions] -= _fractionsCount;
		_safeTransfer(_listing.fractions, _buyer, _fractionsCount);
		emit Claim(_listingId, _buyer, _amount, _fractionsCount);
	}

	function relistPayoutAndClaim(uint256 _listingId, address payable[] calldata _buyers) external
	{
		ListingInfo storage _listing = listings[_listingId];
		if (_listing.state != State.Ended) {
			relist(_listingId);
		}
		if (_listing.amount > 0) {
			payout(_listingId);
		}
		if (_listing.buyers[vault].amount > 0) {
			claim(_listingId, vault);
		}
		if (_listing.buyers[_listing.seller].amount > 0) {
			claim(_listingId, _listing.seller);
		}
		for (uint256 _i = 0; _i < _buyers.length; _i++) {
			address payable _buyer = _buyers[_i];
			if (_listing.buyers[_buyer].amount > 0) {
				claim(_listingId, _buyer);
			}
		}
	}

	function recoverLostFunds(address _token, address payable _to) external onlyOwner nonReentrant
	{
		uint256 _balance = balances[_token];
		uint256 _current = _balanceOf(_token);
		if (_current > _balance) {
			uint256 _excess = _current - _balance;
			_safeTransfer(_token, _to, _excess);
		}
	}

	function recoverLostItem(address _collection, uint256 _tokenId, address _to) external onlyOwner nonReentrant
	{
		if (items[_collection][_tokenId]) return;
		IERC721(_collection).safeTransfer(_to, _tokenId);
	}

	function _validate(bytes calldata _extra) internal view
	{
		(bytes32 _type,,, uint256 _duration, uint256 _fee) = abi.decode(_extra, (bytes32, string, string, uint256, uint256));
		require(fractionalizers[_type] != address(0), "unsupported type");
		require(30 minutes <= _duration && _duration <= 731 days, "invalid duration");
		require(_fee <= 1e18, "invalid fee");
	}

	function _issuing(bytes storage _extra) internal pure returns (uint256 _fractionsCount)
	{
		(,,,, uint256 _fee) = abi.decode(_extra, (bytes32, string, string, uint256, uint256));
		return FRACTIONS_COUNT - (FRACTIONS_COUNT * _fee / 1e18);
	}

	function _fractionalize(uint256 _listingId, uint256 _fractionPrice) internal returns (address _fractions)
	{
		ListingInfo storage _listing = listings[_listingId];
		(bytes32 _type, string memory _name, string memory _symbol, uint256 _duration, uint256 _fee) = abi.decode(_listing.extra, (bytes32, string, string, uint256, uint256));
		IERC721(_listing.collection).approve(fractionalizers[_type], _listing.tokenId);
		return IAuctionFractionalizer(fractionalizers[_type]).fractionalize(_listing.collection, _listing.tokenId, _name, _symbol, FRACTIONS_DECIMALS, FRACTIONS_COUNT, _fractionPrice, _listing.paymentToken, 0, _duration, _fee);
	}

	function _balanceOf(address _token) internal view returns (uint256 _balance)
	{
		if (_token == address(0)) {
			return address(this).balance;
		} else {
			return IERC20(_token).balanceOf(address(this));
		}
	}

	function _safeTransfer(address _token, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			_to.transfer(_amount);
		} else {
			IERC20(_token).safeTransfer(_to, _amount);
		}
	}

	function _safeTransferFrom(address _token, address payable _from, uint256 _value, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			require(_value == _amount, "invalid value");
			if (_to != address(this)) _to.transfer(_amount);
		} else {
			require(_value == 0, "invalid value");
			IERC20(_token).safeTransferFrom(_from, _to, _amount);
		}
	}

	event AddFractionalizer(bytes32 indexed _type, address indexed _fractionalizer);
	event Listed(uint256 indexed _listingId);
	event Sold(uint256 indexed _listingId);
	event Relisted(uint256 indexed _listingId);
	event Canceled(uint256 indexed _listingId);
	event UpdatePrice(uint256 indexed _listingId, uint256 _oldReservePrice, uint256 _oldLimitPrice, uint256 _newReservePrice, uint256 _newLimitPrice);
	event Join(uint256 indexed _listingId, address indexed _buyer, uint256 _amount);
	event Leave(uint256 indexed _listingId, address indexed _buyer, uint256 _amount);
	event Payout(uint256 indexed _listingId, address indexed _seller, uint256 _netAmount, uint256 _feeAmount);
	event Claim(uint256 indexed _listingId, address indexed _buyer, uint256 _amount, uint256 _fractionsCount);
}

// File: contracts/v1.5/LibCreate.sol

pragma solidity ^0.6.0;

library LibCreate
{
	function computeAddress(address _account, uint256 _nonce) internal pure returns (address _address)
	{
		bytes memory _data;
		if (_nonce == 0x00) {
			_data = abi.encodePacked(byte(0xd6), byte(0x94), _account, byte(0x80));
		}
		else
		if (_nonce <= 0x7f) {
			_data = abi.encodePacked(byte(0xd6), byte(0x94), _account, uint8(_nonce));
		}
		else
		if (_nonce <= 0xff) {
			_data = abi.encodePacked(byte(0xd7), byte(0x94), _account, byte(0x81), uint8(_nonce));
		}
		else
		if (_nonce <= 0xffff) {
			_data = abi.encodePacked(byte(0xd8), byte(0x94), _account, byte(0x82), uint16(_nonce));
		}
		else
		if (_nonce <= 0xffffff) {
			_data = abi.encodePacked(byte(0xd9), byte(0x94), _account, byte(0x83), uint24(_nonce));
		}
		else {
			_data = abi.encodePacked(byte(0xda), byte(0x94), _account, byte(0x84), uint32(_nonce));
		}
		return address(uint256(keccak256(_data)));
	}
}

// File: contracts/v1.5/CompatibilityFractionalizer.sol

pragma solidity ^0.6.0;








interface LegacyFractionalizer
{
	function fractionalize(address _target, uint256 _tokenId, string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken) external;
}

contract CompatibilityFractionalizer is IAuctionFractionalizer, ERC721Holder, Ownable, ReentrancyGuard
{
	using Address for address;
	using SafeERC20 for IERC20;
	using LibCreate for address;

	address public immutable fractionalizer;
	uint256 public nonce = 1;

	constructor (address _fractionalizer) public
	{
		fractionalizer = _fractionalizer;
	}

	function updateNonce(uint256 _nonce) external onlyOwner
	{
		nonce = _nonce;
	}

	function fractionalize(address _target, uint256 _tokenId, string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken, uint256 /*_kickoff*/, uint256 /*_duration*/, uint256 /*_fee*/) external override nonReentrant returns (address _fractions)
	{
		address _from = msg.sender;
		IERC721(_target).transferFrom(_from, address(this), _tokenId);
		IERC721(_target).approve(fractionalizer, _tokenId);
		while (true) {
			_fractions = fractionalizer.computeAddress(nonce);
			if (!_fractions.isContract()) break;
			nonce++;
		}
		LegacyFractionalizer(fractionalizer).fractionalize(_target, _tokenId, _name, _symbol, _decimals, _fractionsCount, _fractionPrice, _paymentToken);
		require(_fractions.isContract(), "invalid nonce");
		IERC20(_fractions).safeTransfer(_from, _fractionsCount);
		return _fractions;
	}
}

// File: contracts/v1.5/FlashAcquireCallee.sol

pragma solidity ^0.6.0;

interface FlashAcquireCallee
{
	function flashAcquireCall(address _sender, uint256 _listingId, bytes calldata _data) external;
}

// File: contracts/v1.5/OpenCollectivePurchase.sol

pragma solidity ^0.6.0;








contract OpenCollectivePurchase is ERC721Holder, Ownable, ReentrancyGuard
{
	using SafeERC20 for IERC20;
	using SafeERC721 for IERC721;

	enum State { Created, Acquired, Ended }

	struct BuyerInfo {
		uint256 amount;
	}

	struct ListingInfo {
		State state;
		address payable seller;
		address collection;
		uint256 tokenId;
		bool listed;
		address paymentToken;
		uint256 reservePrice;
		uint256 priceMultiplier;
		bytes extra;
		uint256 amount;
		uint256 fractionsCount;
		address fractions;
		uint256 fee;
		mapping (address => BuyerInfo) buyers;
	}

	struct CreatorInfo {
		address payable creator;
		uint256 fee;
	}

	uint8 constant public FRACTIONS_DECIMALS = 6;
	uint256 constant public FRACTIONS_COUNT = 100000e6;

	uint256 public fee;
	address payable public immutable vault;
	mapping (bytes32 => address) public fractionalizers;

	mapping (address => uint256) private balances;
	mapping (address => mapping (uint256 => bool)) private items;
	ListingInfo[] public listings;
	CreatorInfo[] public creators;

	modifier inState(uint256 _listingId, State _state)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(_state == _listing.state, "not available");
		_;
	}

	modifier onlyCreator(uint256 _listingId)
	{
		CreatorInfo storage _creator = creators[_listingId];
		require(msg.sender == _creator.creator, "not available");
		_;
	}

	constructor (uint256 _fee, address payable _vault) public
	{
		require(_fee <= 100e16, "invalid fee");
		require(_vault != address(0), "invalid address");
		fee = _fee;
		vault = _vault;
	}

	function listingCount() external view returns (uint256 _count)
	{
		return listings.length;
	}

	function buyers(uint256 _listingId, address _buyer) external view returns (uint256 _amount)
	{
		ListingInfo storage _listing = listings[_listingId];
		BuyerInfo storage _info = _listing.buyers[_buyer];
		return _info.amount;
	}

	function status(uint256 _listingId) external view returns (string memory _status)
	{
		ListingInfo storage _listing = listings[_listingId];
		if (_listing.state == State.Created) return "CREATED";
		if (_listing.state == State.Acquired) return "ACQUIRED";
		return "ENDED";
	}

	function buyerFractionsCount(uint256 _listingId, address _buyer) external view inState(_listingId, State.Ended) returns (uint256 _fractionsCount)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		_fractionsCount = (_amount * _listing.fractionsCount) / _listing.reservePrice;
		return _fractionsCount;
	}

	function sellerPayout(uint256 _listingId) external view returns (uint256 _netAmount, uint256 _feeAmount, uint256 _creatorFeeAmount)
	{
		ListingInfo storage _listing = listings[_listingId];
		CreatorInfo storage _creator = creators[_listingId];
		uint256 _amount = _listing.amount;
		_feeAmount = (_amount * _listing.fee) / 1e18;
		_creatorFeeAmount = (_amount * _creator.fee) / 1e18;
		_netAmount = _amount - (_feeAmount + _creatorFeeAmount);
	}

	function setFee(uint256 _fee) external onlyOwner
	{
		require(_fee <= 100e16, "invalid fee");
		fee = _fee;
		emit UpdateFee(_fee);
	}

	function setCreatorFee(uint256 _listingId, uint256 _fee) external onlyCreator(_listingId) inState(_listingId, State.Created)
	{
		ListingInfo storage _listing = listings[_listingId];
		CreatorInfo storage _creator = creators[_listingId];
		require(_listing.fee + _fee <= 100e16, "invalid fee");
		_creator.fee = _fee;
		emit UpdateCreatorFee(_listingId, _fee);
	}

	function addFractionalizer(bytes32 _type, address _fractionalizer) external onlyOwner
	{
		require(fractionalizers[_type] == address(0), "already defined");
		fractionalizers[_type] = _fractionalizer;
		emit AddFractionalizer(_type, _fractionalizer);
	}

	function list(address _collection, uint256 _tokenId, bool _listed, uint256 _fee, address _paymentToken, uint256 _priceMultiplier, bytes calldata _extra) external nonReentrant returns (uint256 _listingId)
	{
		address payable _creator = msg.sender;
		require(fee + _fee <= 100e16, "invalid fee");
		require(0 < _priceMultiplier && _priceMultiplier <= 10000, "invalid multiplier"); // from 1% up to 100x
		_validate(_extra);
		_listingId = listings.length;
		listings.push(ListingInfo({
			state: State.Created,
			seller: address(0),
			collection: _collection,
			tokenId: _tokenId,
			listed: _listed,
			paymentToken: _paymentToken,
			reservePrice: 0,
			priceMultiplier: _priceMultiplier,
			extra: _extra,
			amount: 0,
			fractionsCount: 0,
			fractions: address(0),
			fee: fee
		}));
		creators.push(CreatorInfo({
			creator: _creator,
			fee: _fee
		}));
		emit Listed(_listingId, _creator);
		return _listingId;
	}

	function join(uint256 _listingId, uint256 _amount, uint256 _maxReservePrice) external payable nonReentrant inState(_listingId, State.Created)
	{
		address payable _buyer = msg.sender;
		uint256 _value = msg.value;
		ListingInfo storage _listing = listings[_listingId];
		require(_listing.reservePrice <= _maxReservePrice, "price slippage");
		_safeTransferFrom(_listing.paymentToken, _buyer, _value, payable(address(this)), _amount);
		balances[_listing.paymentToken] += _amount;
		_listing.amount += _amount;
		_listing.buyers[_buyer].amount += _amount;
		_listing.reservePrice = _listing.amount;
		emit Join(_listingId, _buyer, _amount);
	}

	function leave(uint256 _listingId) external nonReentrant inState(_listingId, State.Created)
	{
		address payable _buyer = msg.sender;
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		require(_amount > 0, "insufficient balance");
		_listing.buyers[_buyer].amount = 0;
		_listing.amount -= _amount;
		_listing.reservePrice = _listing.amount;
		balances[_listing.paymentToken] -= _amount;
		_safeTransfer(_listing.paymentToken, _buyer, _amount);
		emit Leave(_listingId, _buyer, _amount);
	}

	function acquire(uint256 _listingId, uint256 _minReservePrice) public nonReentrant inState(_listingId, State.Created)
	{
		address payable _seller = msg.sender;
		ListingInfo storage _listing = listings[_listingId];
		require(_listing.reservePrice >= _minReservePrice, "price slippage");
		IERC721(_listing.collection).transferFrom(_seller, address(this), _listing.tokenId);
		items[_listing.collection][_listing.tokenId] = true;
		_listing.state = State.Acquired;
		_listing.seller = _seller;
		emit Acquired(_listingId);
	}

	function flashAcquire(uint256 _listingId, uint256 _minReservePrice, address payable _to, bytes calldata _data) external inState(_listingId, State.Created)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(_listing.reservePrice >= _minReservePrice, "price slippage");
		_listing.state = State.Ended;
		_listing.seller = _to;
		payout(_listingId);
		_listing.state = State.Created;
		_listing.seller = address(0);
		FlashAcquireCallee(_to).flashAcquireCall(msg.sender, _listingId, _data);
		require(_listing.state == State.Acquired, "not acquired");
		require(_listing.seller == _to, "unexpected seller");
	}

	function relist(uint256 _listingId) public nonReentrant inState(_listingId, State.Acquired)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _fractionPrice = (_listing.reservePrice + (FRACTIONS_COUNT - 1)) / FRACTIONS_COUNT;
		uint256 _relistFractionPrice = (_listing.priceMultiplier * _fractionPrice + 99) / 100;
		_listing.state = State.Ended;
		_listing.fractions = _fractionalize(_listingId, _relistFractionPrice);
		_listing.fractionsCount = _balanceOf(_listing.fractions);
		items[_listing.collection][_listing.tokenId] = false;
		balances[_listing.fractions] = _listing.fractionsCount;
		emit Relisted(_listingId);
	}

	function payout(uint256 _listingId) public nonReentrant inState(_listingId, State.Ended)
	{
		ListingInfo storage _listing = listings[_listingId];
		CreatorInfo storage _creator = creators[_listingId];
		uint256 _amount = _listing.amount;
		require(_amount > 0, "insufficient balance");
		uint256 _feeAmount = (_amount * _listing.fee) / 1e18;
		uint256 _creatorFeeAmount = (_amount * _creator.fee) / 1e18;
		uint256 _netAmount = _amount - (_feeAmount + _creatorFeeAmount);
		_listing.amount = 0;
		balances[_listing.paymentToken] -= _amount;
		_safeTransfer(_listing.paymentToken, _creator.creator, _creatorFeeAmount);
		_safeTransfer(_listing.paymentToken, vault, _feeAmount);
		_safeTransfer(_listing.paymentToken, _listing.seller, _netAmount);
		emit Payout(_listingId, _listing.seller, _netAmount, _feeAmount, _creatorFeeAmount);
	}

	function claim(uint256 _listingId, address payable _buyer) public nonReentrant inState(_listingId, State.Ended)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		require(_amount > 0, "insufficient balance");
		uint256 _fractionsCount = (_amount * _listing.fractionsCount) / _listing.reservePrice;
		_listing.buyers[_buyer].amount = 0;
		balances[_listing.fractions] -= _fractionsCount;
		_safeTransfer(_listing.fractions, _buyer, _fractionsCount);
		emit Claim(_listingId, _buyer, _amount, _fractionsCount);
	}

	function relistPayoutAndClaim(uint256 _listingId, address payable[] calldata _buyers) external
	{
		ListingInfo storage _listing = listings[_listingId];
		if (_listing.state != State.Ended) {
			relist(_listingId);
		}
		if (_listing.amount > 0) {
			payout(_listingId);
		}
		for (uint256 _i = 0; _i < _buyers.length; _i++) {
			address payable _buyer = _buyers[_i];
			if (_listing.buyers[_buyer].amount > 0) {
				claim(_listingId, _buyer);
			}
		}
	}

	function recoverLostFunds(address _token, address payable _to) external onlyOwner nonReentrant
	{
		uint256 _balance = balances[_token];
		uint256 _current = _balanceOf(_token);
		if (_current > _balance) {
			uint256 _excess = _current - _balance;
			_safeTransfer(_token, _to, _excess);
		}
	}

	function recoverLostItem(address _collection, uint256 _tokenId, address _to) external onlyOwner nonReentrant
	{
		if (items[_collection][_tokenId]) return;
		IERC721(_collection).safeTransfer(_to, _tokenId);
	}

	function _validate(bytes calldata _extra) internal view
	{
		(bytes32 _type,,, uint256 _duration, uint256 _fee) = abi.decode(_extra, (bytes32, string, string, uint256, uint256));
		require(fractionalizers[_type] != address(0), "unsupported type");
		require(30 minutes <= _duration && _duration <= 731 days, "invalid duration");
		require(_fee <= 100e16, "invalid fee");
	}

	function _issuing(bytes storage _extra) internal pure returns (uint256 _fractionsCount)
	{
		(,,,, uint256 _fee) = abi.decode(_extra, (bytes32, string, string, uint256, uint256));
		return FRACTIONS_COUNT - (FRACTIONS_COUNT * _fee / 1e18);
	}

	function _fractionalize(uint256 _listingId, uint256 _fractionPrice) internal returns (address _fractions)
	{
		ListingInfo storage _listing = listings[_listingId];
		(bytes32 _type, string memory _name, string memory _symbol, uint256 _duration, uint256 _fee) = abi.decode(_listing.extra, (bytes32, string, string, uint256, uint256));
		IERC721(_listing.collection).approve(fractionalizers[_type], _listing.tokenId);
		return IAuctionFractionalizer(fractionalizers[_type]).fractionalize(_listing.collection, _listing.tokenId, _name, _symbol, FRACTIONS_DECIMALS, FRACTIONS_COUNT, _fractionPrice, _listing.paymentToken, 0, _duration, _fee);
	}

	function _balanceOf(address _token) internal view returns (uint256 _balance)
	{
		if (_token == address(0)) {
			return address(this).balance;
		} else {
			return IERC20(_token).balanceOf(address(this));
		}
	}

	function _safeTransfer(address _token, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			_to.transfer(_amount);
		} else {
			IERC20(_token).safeTransfer(_to, _amount);
		}
	}

	function _safeTransferFrom(address _token, address payable _from, uint256 _value, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			require(_value == _amount, "invalid value");
			if (_to != address(this)) _to.transfer(_amount);
		} else {
			require(_value == 0, "invalid value");
			IERC20(_token).safeTransferFrom(_from, _to, _amount);
		}
	}

	event UpdateFee(uint256 _fee);
	event UpdateCreatorFee(uint256 indexed _listingId, uint256 _fee);
	event AddFractionalizer(bytes32 indexed _type, address indexed _fractionalizer);
	event Listed(uint256 indexed _listingId, address indexed _creator);
	event Acquired(uint256 indexed _listingId);
	event Relisted(uint256 indexed _listingId);
	event Join(uint256 indexed _listingId, address indexed _buyer, uint256 _amount);
	event Leave(uint256 indexed _listingId, address indexed _buyer, uint256 _amount);
	event Payout(uint256 indexed _listingId, address indexed _seller, uint256 _netAmount, uint256 _feeAmount, uint256 _creatorFeeAmount);
	event Claim(uint256 indexed _listingId, address indexed _buyer, uint256 _amount, uint256 _fractionsCount);
}

// File: contracts/v1.5/ExternalAcquirer.sol

pragma solidity 0.6.12;





contract ExternalAcquirer is FlashAcquireCallee
{
	using SafeERC20 for IERC20;
	using Address for address payable;

	address immutable public collective;
	address payable immutable public vault;

	constructor (address _collective) public
	{
		collective = _collective;
		vault = OpenCollectivePurchase(_collective).vault();
	}

	function acquire(uint256 _listingId, bool _relist, bytes calldata _data) external
	{
		OpenCollectivePurchase(collective).flashAcquire(_listingId, 0, address(this), _data);
		if (_relist) {
			OpenCollectivePurchase(collective).relist(_listingId);
		}
	}

	function flashAcquireCall(address _source, uint256 _listingId, bytes calldata _data) external override
	{
		require(msg.sender == collective, "invalid sender");
		require(_source == address(this), "invalid source");
		(address _spender, address _target, bytes memory _calldata) = abi.decode(_data, (address, address, bytes));
		(,,address _collection, uint256 _tokenId,, address _paymentToken,,,,,,,) = OpenCollectivePurchase(collective).listings(_listingId);
		if (_paymentToken == address(0)) {
			uint256 _balance = address(this).balance;
			(bool _success, bytes memory _returndata) = _target.call{value: _balance}(_calldata);
			require(_success, string(_returndata));
			_balance = address(this).balance;
			if (_balance > 0) {
				vault.sendValue(_balance);
			}
		} else {
			uint256 _balance = IERC20(_paymentToken).balanceOf(address(this));
			IERC20(_paymentToken).safeApprove(_spender, _balance);
			(bool _success, bytes memory _returndata) = _target.call(_calldata);
			require(_success, string(_returndata));
			IERC20(_paymentToken).safeApprove(_spender, 0);
			_balance = IERC20(_paymentToken).balanceOf(address(this));
			if (_balance > 0) {
				IERC20(_paymentToken).safeTransfer(vault, _balance);
			}
		}
		IERC721(_collection).approve(collective, _tokenId);
		OpenCollectivePurchase(collective).acquire(_listingId, 0);
	}

	receive() external payable
	{
	}
}

// File: contracts/v1.5/OpenCollectivePurchaseV2.sol

pragma solidity ^0.6.0;








contract OpenCollectivePurchaseV2 is ERC721Holder, Ownable, ReentrancyGuard
{
	using SafeERC20 for IERC20;
	using SafeERC721 for IERC721;

	enum State { Created, Acquired, Ended }

	struct BuyerInfo {
		uint256 amount;
	}

	struct ListingInfo {
		State state;
		address payable seller;
		address collection;
		uint256 tokenId;
		bool listed;
		address paymentToken;
		uint256 reservePrice;
		uint256 priceMultiplier;
		bytes extra;
		uint256 amount;
		uint256 fractionsCount;
		address fractions;
		uint256 fee;
		bool any;
		mapping (address => BuyerInfo) buyers;
	}

	struct CreatorInfo {
		address payable creator;
		uint256 fee;
	}

	uint8 constant public FRACTIONS_DECIMALS = 6;
	uint256 constant public FRACTIONS_COUNT = 100000e6;

	uint256 public fee;
	address payable public immutable vault;
	mapping (bytes32 => address) public fractionalizers;

	mapping (address => uint256) private balances;
	mapping (address => mapping (uint256 => bool)) private items;
	ListingInfo[] public listings;
	CreatorInfo[] public creators;

	modifier inState(uint256 _listingId, State _state)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(_state == _listing.state, "not available");
		_;
	}

	modifier onlyCreator(uint256 _listingId)
	{
		CreatorInfo storage _creator = creators[_listingId];
		require(msg.sender == _creator.creator, "not available");
		_;
	}

	constructor (uint256 _fee, address payable _vault) public
	{
		require(_fee <= 100e16, "invalid fee");
		require(_vault != address(0), "invalid address");
		fee = _fee;
		vault = _vault;
	}

	function listingCount() external view returns (uint256 _count)
	{
		return listings.length;
	}

	function buyers(uint256 _listingId, address _buyer) external view returns (uint256 _amount)
	{
		ListingInfo storage _listing = listings[_listingId];
		BuyerInfo storage _info = _listing.buyers[_buyer];
		return _info.amount;
	}

	function status(uint256 _listingId) external view returns (string memory _status)
	{
		ListingInfo storage _listing = listings[_listingId];
		if (_listing.state == State.Created) return "CREATED";
		if (_listing.state == State.Acquired) return "ACQUIRED";
		return "ENDED";
	}

	function buyerFractionsCount(uint256 _listingId, address _buyer) external view inState(_listingId, State.Ended) returns (uint256 _fractionsCount)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		_fractionsCount = (_amount * _listing.fractionsCount) / _listing.reservePrice;
		return _fractionsCount;
	}

	function sellerPayout(uint256 _listingId) external view returns (uint256 _netAmount, uint256 _feeAmount, uint256 _creatorFeeAmount)
	{
		ListingInfo storage _listing = listings[_listingId];
		CreatorInfo storage _creator = creators[_listingId];
		uint256 _amount = _listing.amount;
		_feeAmount = (_amount * _listing.fee) / 1e18;
		_creatorFeeAmount = (_amount * _creator.fee) / 1e18;
		_netAmount = _amount - (_feeAmount + _creatorFeeAmount);
	}

	function setFee(uint256 _fee) external onlyOwner
	{
		require(_fee <= 100e16, "invalid fee");
		fee = _fee;
		emit UpdateFee(_fee);
	}

	function setCreatorFee(uint256 _listingId, uint256 _fee) external onlyCreator(_listingId) inState(_listingId, State.Created)
	{
		ListingInfo storage _listing = listings[_listingId];
		CreatorInfo storage _creator = creators[_listingId];
		require(_listing.fee + _fee <= 100e16, "invalid fee");
		_creator.fee = _fee;
		emit UpdateCreatorFee(_listingId, _fee);
	}

	function addFractionalizer(bytes32 _type, address _fractionalizer) external onlyOwner
	{
		require(fractionalizers[_type] == address(0), "already defined");
		fractionalizers[_type] = _fractionalizer;
		emit AddFractionalizer(_type, _fractionalizer);
	}

	function _defaultCreator() internal view virtual returns (address payable _creator)
	{
		return msg.sender;
	}

	function list(address _collection, bool any, uint256 _tokenId, bool _listed, uint256 _fee, address _paymentToken, uint256 _priceMultiplier, bytes memory _extra) public nonReentrant returns (uint256 _listingId)
	{
		address payable _creator = _defaultCreator();
		if (any) {
			require(_tokenId == 0, "invalid tokenId");
		}
		require(fee + _fee <= 100e16, "invalid fee");
		require(0 < _priceMultiplier && _priceMultiplier <= 10000, "invalid multiplier"); // from 1% up to 100x
		_validate(_extra);
		_listingId = listings.length;
		listings.push(ListingInfo({
			state: State.Created,
			seller: address(0),
			collection: _collection,
			tokenId: _tokenId,
			listed: _listed,
			paymentToken: _paymentToken,
			reservePrice: 0,
			priceMultiplier: _priceMultiplier,
			extra: _extra,
			amount: 0,
			fractionsCount: 0,
			fractions: address(0),
			fee: fee,
			any: any
		}));
		creators.push(CreatorInfo({
			creator: _creator,
			fee: _fee
		}));
		emit Listed(_listingId, _creator);
		return _listingId;
	}

	function join(uint256 _listingId, uint256 _amount, uint256 _maxReservePrice) public payable nonReentrant inState(_listingId, State.Created)
	{
		address payable _buyer = msg.sender;
		uint256 _value = msg.value;
		ListingInfo storage _listing = listings[_listingId];
		require(_listing.reservePrice <= _maxReservePrice, "price slippage");
		_safeTransferFrom(_listing.paymentToken, _buyer, _value, payable(address(this)), _amount);
		balances[_listing.paymentToken] += _amount;
		_listing.amount += _amount;
		_listing.buyers[_buyer].amount += _amount;
		_listing.reservePrice = _listing.amount;
		emit Join(_listingId, _buyer, _amount);
	}

	function leave(uint256 _listingId) public nonReentrant inState(_listingId, State.Created)
	{
		address payable _buyer = msg.sender;
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		require(_amount > 0, "insufficient balance");
		_listing.buyers[_buyer].amount = 0;
		_listing.amount -= _amount;
		_listing.reservePrice = _listing.amount;
		balances[_listing.paymentToken] -= _amount;
		_safeTransfer(_listing.paymentToken, _buyer, _amount);
		emit Leave(_listingId, _buyer, _amount);
	}

	function acquire(uint256 _listingId, uint256 _tokenId, uint256 _minReservePrice) public nonReentrant inState(_listingId, State.Created)
	{
		address payable _seller = msg.sender;
		ListingInfo storage _listing = listings[_listingId];
		require(_tokenId == _listing.tokenId || _listing.any, "invalid tokenId");
		require(_listing.reservePrice >= _minReservePrice, "price slippage");
		IERC721(_listing.collection).transferFrom(_seller, address(this), _tokenId);
		items[_listing.collection][_listing.tokenId] = true;
		_listing.state = State.Acquired;
		_listing.tokenId = _tokenId;
		_listing.seller = _seller;
		emit Acquired(_listingId);
	}

	function flashAcquire(uint256 _listingId, uint256 _minReservePrice, address payable _to, bytes calldata _data) external inState(_listingId, State.Created)
	{
		ListingInfo storage _listing = listings[_listingId];
		require(_listing.reservePrice >= _minReservePrice, "price slippage");
		_listing.state = State.Ended;
		_listing.seller = _to;
		payout(_listingId);
		_listing.state = State.Created;
		_listing.seller = address(0);
		FlashAcquireCallee(_to).flashAcquireCall(msg.sender, _listingId, _data);
		require(_listing.state == State.Acquired, "not acquired");
		require(_listing.seller == _to, "unexpected seller");
	}

	function relist(uint256 _listingId) public nonReentrant inState(_listingId, State.Acquired)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _fractionPrice = (_listing.reservePrice + (FRACTIONS_COUNT - 1)) / FRACTIONS_COUNT;
		uint256 _relistFractionPrice = (_listing.priceMultiplier * _fractionPrice + 99) / 100;
		_listing.state = State.Ended;
		_listing.fractions = _fractionalize(_listingId, _relistFractionPrice);
		_listing.fractionsCount = _balanceOf(_listing.fractions);
		items[_listing.collection][_listing.tokenId] = false;
		balances[_listing.fractions] = _listing.fractionsCount;
		emit Relisted(_listingId);
	}

	function payout(uint256 _listingId) public nonReentrant inState(_listingId, State.Ended)
	{
		ListingInfo storage _listing = listings[_listingId];
		CreatorInfo storage _creator = creators[_listingId];
		uint256 _amount = _listing.amount;
		require(_amount > 0, "insufficient balance");
		uint256 _feeAmount = (_amount * _listing.fee) / 1e18;
		uint256 _creatorFeeAmount = (_amount * _creator.fee) / 1e18;
		uint256 _netAmount = _amount - (_feeAmount + _creatorFeeAmount);
		_listing.amount = 0;
		balances[_listing.paymentToken] -= _amount;
		_safeTransfer(_listing.paymentToken, _creator.creator, _creatorFeeAmount);
		_safeTransfer(_listing.paymentToken, vault, _feeAmount);
		_safeTransfer(_listing.paymentToken, _listing.seller, _netAmount);
		emit Payout(_listingId, _listing.seller, _netAmount, _feeAmount, _creatorFeeAmount);
	}

	function claim(uint256 _listingId, address payable _buyer) public nonReentrant inState(_listingId, State.Ended)
	{
		ListingInfo storage _listing = listings[_listingId];
		uint256 _amount = _listing.buyers[_buyer].amount;
		require(_amount > 0, "insufficient balance");
		uint256 _fractionsCount = (_amount * _listing.fractionsCount) / _listing.reservePrice;
		_listing.buyers[_buyer].amount = 0;
		balances[_listing.fractions] -= _fractionsCount;
		_safeTransfer(_listing.fractions, _buyer, _fractionsCount);
		emit Claim(_listingId, _buyer, _amount, _fractionsCount);
	}

	function relistPayoutAndClaim(uint256 _listingId, address payable[] calldata _buyers) external
	{
		ListingInfo storage _listing = listings[_listingId];
		if (_listing.state != State.Ended) {
			relist(_listingId);
		}
		if (_listing.amount > 0) {
			payout(_listingId);
		}
		for (uint256 _i = 0; _i < _buyers.length; _i++) {
			address payable _buyer = _buyers[_i];
			if (_listing.buyers[_buyer].amount > 0) {
				claim(_listingId, _buyer);
			}
		}
	}
/*
	function recoverLostFunds(address _token, address payable _to) external onlyOwner nonReentrant
	{
		uint256 _balance = balances[_token];
		uint256 _current = _balanceOf(_token);
		if (_current > _balance) {
			uint256 _excess = _current - _balance;
			_safeTransfer(_token, _to, _excess);
		}
	}

	function recoverLostItem(address _collection, uint256 _tokenId, address _to) external onlyOwner nonReentrant
	{
		if (items[_collection][_tokenId]) return;
		IERC721(_collection).safeTransfer(_to, _tokenId);
	}
*/
	function _validate(bytes memory _extra) internal view
	{
		(bytes32 _type,,, uint256 _duration, uint256 _fee) = abi.decode(_extra, (bytes32, string, string, uint256, uint256));
		require(fractionalizers[_type] != address(0), "unsupported type");
		require(30 minutes <= _duration && _duration <= 731 days, "invalid duration");
		require(_fee <= 100e16, "invalid fee");
	}

	function _issuing(bytes storage _extra) internal pure returns (uint256 _fractionsCount)
	{
		(,,,, uint256 _fee) = abi.decode(_extra, (bytes32, string, string, uint256, uint256));
		return FRACTIONS_COUNT - (FRACTIONS_COUNT * _fee / 1e18);
	}

	function _fractionalize(uint256 _listingId, uint256 _fractionPrice) internal returns (address _fractions)
	{
		ListingInfo storage _listing = listings[_listingId];
		(bytes32 _type, string memory _name, string memory _symbol, uint256 _duration, uint256 _fee) = abi.decode(_listing.extra, (bytes32, string, string, uint256, uint256));
		IERC721(_listing.collection).approve(fractionalizers[_type], _listing.tokenId);
		return IAuctionFractionalizer(fractionalizers[_type]).fractionalize(_listing.collection, _listing.tokenId, _name, _symbol, FRACTIONS_DECIMALS, FRACTIONS_COUNT, _fractionPrice, _listing.paymentToken, 0, _duration, _fee);
	}

	function _balanceOf(address _token) internal view returns (uint256 _balance)
	{
		if (_token == address(0)) {
			return address(this).balance;
		} else {
			return IERC20(_token).balanceOf(address(this));
		}
	}

	function _safeTransfer(address _token, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			_to.transfer(_amount);
		} else {
			IERC20(_token).safeTransfer(_to, _amount);
		}
	}

	function _safeTransferFrom(address _token, address payable _from, uint256 _value, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			require(_value == _amount, "invalid value");
			if (_to != address(this)) _to.transfer(_amount);
		} else {
			require(_value == 0, "invalid value");
			IERC20(_token).safeTransferFrom(_from, _to, _amount);
		}
	}

	event UpdateFee(uint256 _fee);
	event UpdateCreatorFee(uint256 indexed _listingId, uint256 _fee);
	event AddFractionalizer(bytes32 indexed _type, address indexed _fractionalizer);
	event Listed(uint256 indexed _listingId, address indexed _creator);
	event Acquired(uint256 indexed _listingId);
	event Relisted(uint256 indexed _listingId);
	event Join(uint256 indexed _listingId, address indexed _buyer, uint256 _amount);
	event Leave(uint256 indexed _listingId, address indexed _buyer, uint256 _amount);
	event Payout(uint256 indexed _listingId, address indexed _seller, uint256 _netAmount, uint256 _feeAmount, uint256 _creatorFeeAmount);
	event Claim(uint256 indexed _listingId, address indexed _buyer, uint256 _amount, uint256 _fractionsCount);
}

// File: contracts/v1.5/ExternalAcquirerV2.sol

pragma solidity 0.6.12;





contract ExternalAcquirerV2 is FlashAcquireCallee
{
	using SafeERC20 for IERC20;
	using Address for address payable;

	address immutable public collective;
	address payable immutable public vault;

	constructor (address _collective) public
	{
		collective = _collective;
		vault = OpenCollectivePurchaseV2(_collective).vault();
	}

	function acquire(uint256 _listingId, bool _relist, bytes calldata _data) external
	{
		OpenCollectivePurchaseV2(collective).flashAcquire(_listingId, 0, address(this), _data);
		if (_relist) {
			OpenCollectivePurchaseV2(collective).relist(_listingId);
		}
	}

	function flashAcquireCall(address _source, uint256 _listingId, bytes calldata _data) external override
	{
		require(msg.sender == collective, "invalid sender");
		require(_source == address(this), "invalid source");
		(address _spender, address _target, uint256 _tokenId, bytes memory _calldata) = abi.decode(_data, (address, address, uint256, bytes));
		(,,address _collection,,, address _paymentToken,,,,,,,,) = OpenCollectivePurchaseV2(collective).listings(_listingId);
		if (_paymentToken == address(0)) {
			uint256 _balance = address(this).balance;
			(bool _success, bytes memory _returndata) = _target.call{value: _balance}(_calldata);
			require(_success, string(_returndata));
			_balance = address(this).balance;
			if (_balance > 0) {
				vault.sendValue(_balance);
			}
		} else {
			uint256 _balance = IERC20(_paymentToken).balanceOf(address(this));
			IERC20(_paymentToken).safeApprove(_spender, _balance);
			(bool _success, bytes memory _returndata) = _target.call(_calldata);
			require(_success, string(_returndata));
			IERC20(_paymentToken).safeApprove(_spender, 0);
			_balance = IERC20(_paymentToken).balanceOf(address(this));
			if (_balance > 0) {
				IERC20(_paymentToken).safeTransfer(vault, _balance);
			}
		}
		IERC721(_collection).approve(collective, _tokenId);
		OpenCollectivePurchaseV2(collective).acquire(_listingId, _tokenId, 0);
	}

	receive() external payable
	{
	}
}

// File: contracts/v1.5/Fractions.sol

pragma solidity ^0.6.0;

contract Fractions
{
	fallback () external payable
	{
		assembly {
			calldatacopy(0, 0, calldatasize())
			let result := delegatecall(gas(), 0x04859E76a961E8B2530afc4829605013bEBD01A4, 0, calldatasize(), 0, 0) // replace 2nd parameter by FractionsImpl address on deploy
			returndatacopy(0, 0, returndatasize())
			switch result
			case 0 { revert(0, returndatasize()) }
			default { return(0, returndatasize()) }
		}
	}
}

// File: contracts/v1.5/FractionsImpl.sol

pragma solidity ^0.6.0;








contract FractionsImpl is ERC721Holder, ERC20, ReentrancyGuard
{
	using SafeERC20 for IERC20;
	using SafeERC721 for IERC721;
	using SafeERC721 for IERC721Metadata;
	using Strings for uint256;

	address public target;
	uint256 public tokenId;
	uint256 public fractionsCount;
	uint256 public fractionPrice;
	address public paymentToken;

	bool public released;

	string private name_;
	string private symbol_;

	constructor () ERC20("Fractions", "FRAC") public
	{
		target = address(-1); // prevents proxy code from misuse
	}

	function __name() public view /*override*/ returns (string memory _name) // rename to name() and change name() on ERC20 to virtual to be able to override on deploy
	{
		if (bytes(name_).length != 0) return name_;
		return string(abi.encodePacked(IERC721Metadata(target).safeName(), " #", tokenId.toString(), " Fractions"));
	}

	function __symbol() public view /*override*/ returns (string memory _symbol) // rename to name() and change name() on ERC20 to virtual to be able to override on deploy
	{
		if (bytes(symbol_).length != 0) return symbol_;
		return string(abi.encodePacked(IERC721Metadata(target).safeSymbol(), tokenId.toString()));
	}

	function initialize(address _from, address _target, uint256 _tokenId, string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken) external
	{
		require(target == address(0), "already initialized");
		require(IERC721(_target).ownerOf(_tokenId) == address(this), "token not staked");
		require(_fractionsCount > 0, "invalid fraction count");
		require(_fractionsCount * _fractionPrice / _fractionsCount == _fractionPrice, "invalid fraction price");
		require(_paymentToken != address(this), "invalid token");
		target = _target;
		tokenId = _tokenId;
		fractionsCount = _fractionsCount;
		fractionPrice = _fractionPrice;
		paymentToken = _paymentToken;
		released = false;
		name_ = _name;
		symbol_ = _symbol;
		_setupDecimals(_decimals);
		_mint(_from, _fractionsCount);
	}

	function status() external view returns (string memory _status)
	{
		return released ? "SOLD" : "OFFER";
	}

	function reservePrice() public view returns (uint256 _reservePrice)
	{
		return fractionsCount * fractionPrice;
	}

	function redeemAmountOf(address _from) public view returns (uint256 _redeemAmount)
	{
		require(!released, "token already redeemed");
		uint256 _fractionsCount = balanceOf(_from);
		uint256 _reservePrice = reservePrice();
		return _reservePrice - _fractionsCount * fractionPrice;
	}

	function vaultBalance() external view returns (uint256 _vaultBalance)
	{
		if (!released) return 0;
		uint256 _fractionsCount = totalSupply();
		return _fractionsCount * fractionPrice;
	}

	function vaultBalanceOf(address _from) public view returns (uint256 _vaultBalanceOf)
	{
		if (!released) return 0;
		uint256 _fractionsCount = balanceOf(_from);
		return _fractionsCount * fractionPrice;
	}

	function redeem() external payable nonReentrant
	{
		address payable _from = msg.sender;
		uint256 _value = msg.value;
		require(!released, "token already redeemed");
		uint256 _fractionsCount = balanceOf(_from);
		uint256 _redeemAmount = redeemAmountOf(_from);
		released = true;
		if (_fractionsCount > 0) _burn(_from, _fractionsCount);
		_safeTransferFrom(paymentToken, _from, _value, payable(address(this)), _redeemAmount);
		IERC721(target).safeTransfer(_from, tokenId);
		emit Redeem(_from, _fractionsCount, _redeemAmount);
		_cleanup();
	}

	function claim() external nonReentrant
	{
		address payable _from = msg.sender;
		require(released, "token not redeemed");
		uint256 _fractionsCount = balanceOf(_from);
		require(_fractionsCount > 0, "nothing to claim");
		uint256 _claimAmount = vaultBalanceOf(_from);
		_burn(_from, _fractionsCount);
		_safeTransfer(paymentToken, _from, _claimAmount);
		emit Claim(_from, _fractionsCount, _claimAmount);
		_cleanup();
	}

	function _cleanup() internal
	{
		uint256 _fractionsCount = totalSupply();
		if (_fractionsCount == 0) {
			selfdestruct(address(0));
		}
	}

	function _safeTransfer(address _token, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			_to.transfer(_amount);
		} else {
			IERC20(_token).safeTransfer(_to, _amount);
		}
	}

	function _safeTransferFrom(address _token, address payable _from, uint256 _value, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			require(_value == _amount, "invalid value");
			if (_to != address(this)) _to.transfer(_amount);
		} else {
			require(_value == 0, "invalid value");
			IERC20(_token).safeTransferFrom(_from, _to, _amount);
		}
	}

	event Redeem(address indexed _from, uint256 _fractionsCount, uint256 _redeemAmount);
	event Claim(address indexed _from, uint256 _fractionsCount, uint256 _claimAmount);
}

// File: contracts/v1.5/Fractionalizer.sol

pragma solidity ^0.6.0;



contract Fractionalizer is ReentrancyGuard
{
	function fractionalize(address _target, uint256 _tokenId, string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken) external nonReentrant returns (address _fractions)
	{
		address _from = msg.sender;
		_fractions = address(new Fractions());
		IERC721(_target).transferFrom(_from, _fractions, _tokenId);
		FractionsImpl(_fractions).initialize(_from, _target, _tokenId, _name, _symbol, _decimals, _fractionsCount, _fractionPrice, _paymentToken);
		emit Fractionalize(_from, _target, _tokenId, _fractions);
		return _fractions;
	}

	event Fractionalize(address indexed _from, address indexed _target, uint256 indexed _tokenId, address _fractions);
}

// File: contracts/v1.5/PerpetualOpenCollectivePurchaseV2.sol

pragma solidity ^0.6.0;

contract PerpetualOpenCollectivePurchaseV2 is OpenCollectivePurchaseV2
{
	struct PerpetualInfo {
		uint256 listingId;
		uint256 priceMultiplier;
	}

	uint256 constant DEFAULT_PRICE_MULTIPLIER = 140; // 140%

	uint256 public priceMultiplier = DEFAULT_PRICE_MULTIPLIER;

	mapping (address => mapping (address => PerpetualInfo)) public perpetuals;

	constructor (uint256 _fee, address payable _vault) public
		OpenCollectivePurchaseV2(_fee, _vault)
	{
		// list(address(0), false, 0, false, fee, address(0), 100, abi.encode(bytes32(""), string(""), string(""), uint256(0), uint256(0)));
	}

	function _defaultCreator() internal view override returns (address payable _creator)
	{
		return payable(0);
	}

	function setDefaultPriceMultiplier(uint256 _priceMultiplier) external onlyOwner
	{
		require(0 < _priceMultiplier && _priceMultiplier <= 10000, "invalid multiplier"); // from 1% up to 100x
		priceMultiplier = _priceMultiplier;
		emit UpdateDefaultPriceMultiplier(_priceMultiplier);
	}

	function setPriceMultiplier(address _collection, address _paymentToken, uint256 _priceMultiplier) external onlyOwner
	{
		require(0 < _priceMultiplier && _priceMultiplier <= 10000, "invalid multiplier"); // from 1% up to 100x
		PerpetualInfo storage _perpetual = perpetuals[_collection][_paymentToken];
		_perpetual.priceMultiplier = _priceMultiplier;
		ListingInfo storage _listing = listings[_perpetual.listingId];
		if (_perpetual.listingId != 0 && _listing.state == State.Created) {
			_listing.priceMultiplier = _priceMultiplier;
		}
		emit UpdatePriceMultiplier(_collection, _paymentToken, _priceMultiplier);
	}

	function perpetualJoin(address _collection, address _paymentToken, uint256 _amount, uint256 _maxReservePrice, bytes32 _referralId) external payable
	{
		PerpetualInfo storage _perpetual = perpetuals[_collection][_paymentToken];
		ListingInfo storage _listing = listings[_perpetual.listingId];
		if (_perpetual.listingId == 0 || _listing.state != State.Created) {
			uint256 _priceMultiplier = _perpetual.priceMultiplier;
			if (_priceMultiplier == 0) _priceMultiplier = priceMultiplier;
			_perpetual.listingId = list(_collection, true, 0, true, fee, _paymentToken, _priceMultiplier, abi.encode(bytes32("SET_PRICE"), string("Perpetual Fractions"), string("PFRAC"), uint256(0), uint256(0)));
		}
		join(_perpetual.listingId, _amount, _maxReservePrice);
		emit Referral(msg.sender, _paymentToken, _amount, _referralId);
	}

	function perpetualLeave(address _collection, address _paymentToken) external
	{
		PerpetualInfo storage _perpetual = perpetuals[_collection][_paymentToken];
		require(_perpetual.listingId != 0, "invalid listing");
		leave(_perpetual.listingId);
	}

	event UpdateDefaultPriceMultiplier(uint256 _priceMultiplier);
	event UpdatePriceMultiplier(address indexed _collection, address indexed _paymentToken, uint256 _priceMultiplier);
	event Referral(address indexed _account, address indexed _paymentToken, uint256 _amount, bytes32 indexed _referralId);
}