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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract AIInu is ERC20, Ownable {
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000e18;

    address public treasuryWallet;
    address public devWallet;
    address public marketingWallet;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool public tradingActive;

    // SWAPS
    bool private _swapping;
    uint256 public maxPercentToSwap; // 5
    uint256 public swapTokensThreshold; // 0.2% of totalsupply

    // FEES
    uint256 public buyTaxTreasury;
    uint256 public sellTaxTreasury;
    uint256 public buyTaxLiquidity;
    uint256 public sellTaxLiquidity;
    mapping(address => bool) private _isExcludedFromFees;

    // LIMITS
    bool public limitsInEffect = true;
    uint256 public maxTxAmount;
    uint256 public maxWalletAmount;
    mapping(address => bool) public isExempt;

    // EVENTS
    event ExcludeFromFees(address indexed account, bool status);
    event ExemptUpdated(address indexed account, bool status);
    event FeesUpdated(
        uint256 buyTreasuryFee,
        uint256 sellTreasuryFee,
        uint256 buyLiquidityFee,
        uint256 sellLiquidityFee
    );
    event TreasuryWalletUpdated(address indexed newWallet);
    event DevWalletUpdated(address indexed newWallet);
    event MarketingWalletUpdated(address indexed newWallet);
    event SwapTokensThresholdUpdated(uint256 newThreshold);
    event MaxPercentToSwapUpdated(uint256 newPercent);
    event MaxTxAmountUpdated(uint256 newAmount);
    event MaxWalletAmountUpdated(uint256 newAmount);
    event SwapAndSendTreasury(uint256 tokensSwapped, uint256 ethSend);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    // TODO: REMOVE FOR DEPLOYMENT
    // top of transfer
    event TestTransferStart(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    // top of check
    event TestTransferCheckStart(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    // right before require(tradingActive) line (inside if loop)
    event TestTransferTradingActive(bool isTradingActive);
    // right before if (canSwap && !_swapping) line
    event TestTransferCheckSwap(bool canSwap, bool isSwapping);
    // right before swapBack call
    event TestTransferBeforeSwapback(uint256 pairBalance, bool isSwapping);
    // top of swapBack
    event TestTransferTopSwapback(uint256 liqAmount, uint256 tAmount);
    // After router.swapexacttokens call
    event TestTransferAfterUniswapSwapCall(uint256 tokenAmount);
    // Before uniswap.addLiquidity call
    event TestTransferBeforeUniswapLiqCall(
        uint256 tokenAmount,
        uint256 ethAmount
    );
    // Before takeFee if statements
    event TestTransferBeforeTakeFeeChecks(bool takeFee);
    // After take fees (before final transfer call)
    event TestTransferBeforeFinalTransfer(
        address from,
        address to,
        uint256 amount
    );

    // Constructor

    constructor(
        address _treasuryWallet,
        address _devWallet,
        address _marketingWallet
    ) ERC20("AI Inu", "AI INU") {
        _mint(msg.sender, TOTAL_SUPPLY);

        // set limits/thresholds/etc.
        maxPercentToSwap = 5;
        swapTokensThreshold = (TOTAL_SUPPLY * 2) / 1000; // 0.2%
        maxTxAmount = (TOTAL_SUPPLY * 2) / 100; // 2%
        maxWalletAmount = (TOTAL_SUPPLY * 2) / 100; // 2%

        // set wallets
        treasuryWallet = _treasuryWallet;
        devWallet = _devWallet;
        marketingWallet = _marketingWallet;

        // taxes
        buyTaxTreasury = 2;
        sellTaxTreasury = 2;
        buyTaxLiquidity = 1;
        sellTaxLiquidity = 1;

        // uniswap
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;

        // mappings
        _isExcludedFromFees[msg.sender] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[address(uniswapV2Router)] = true;
        // BAG doesn't have anything else except DEAD (ex. marketing wallet not in excludeFee)
        // EvolveAI has marketing,dev,treasury wallets
        _isExcludedFromFees[_treasuryWallet] = true;
        _isExcludedFromFees[_devWallet] = true;
        _isExcludedFromFees[_marketingWallet] = true;

        isExempt[address(uniswapV2Router)] = true;
        isExempt[msg.sender] = true;

        isExempt[address(this)] = true;
        isExempt[_treasuryWallet] = true;
        isExempt[_devWallet] = true;
        isExempt[_marketingWallet] = true;
    }

    // Receiver

    receive() external payable {}

    // External (with view funcs last)

    // Permanently activate trading (cannot disable later)
    function openTrading() external onlyOwner {
        require(!tradingActive, "Trading already opened.");
        tradingActive = true;
    }

    // Permanently disable limits (max/tx checks) (cannot enable later)
    function disableLimits() external onlyOwner {
        require(limitsInEffect, "Limits already disabled.");
        limitsInEffect = false;
    }

    function updateTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), "Address cannot be 0 address");
        require(_treasuryWallet != treasuryWallet, "Wallet same address");

        treasuryWallet = _treasuryWallet;
        emit TreasuryWalletUpdated(_treasuryWallet);
    }

    function updateDevWallet(address _devWallet) external onlyOwner {
        require(_devWallet != address(0), "Address cannot be 0 address");
        require(_devWallet != devWallet, "Wallet same address");

        devWallet = _devWallet;
        emit DevWalletUpdated(_devWallet);
    }

    function updateMarketingWallet(
        address _marketingWallet
    ) external onlyOwner {
        require(_marketingWallet != address(0), "Address cannot be 0 address");
        require(_marketingWallet != marketingWallet, "Wallet same address");

        marketingWallet = _marketingWallet;
        emit MarketingWalletUpdated(_marketingWallet);
    }

    function setExcludeFromFees(
        address account,
        bool status
    ) external onlyOwner {
        require(
            _isExcludedFromFees[account] != status,
            "Account already in status"
        );

        _isExcludedFromFees[account] = status;
        emit ExcludeFromFees(account, status);
    }

    function setExempt(address account, bool status) external onlyOwner {
        require(isExempt[account] != status, "Account already in status");
        isExempt[account] = status;
        emit ExemptUpdated(account, status);
    }

    function updateFees(
        uint256 _buyTaxTreasury,
        uint256 _sellTaxTreasury,
        uint256 _buyTaxLiquidity,
        uint256 _sellTaxLiquidity
    ) external onlyOwner {
        require(
            (_buyTaxTreasury + _buyTaxLiquidity) <= 10,
            "Total buy tax <= 10%"
        );
        require(
            (_sellTaxTreasury + _sellTaxLiquidity) <= 10,
            "Total sell tax <= 10%"
        );

        buyTaxTreasury = _buyTaxTreasury;
        sellTaxTreasury = _sellTaxTreasury;
        buyTaxLiquidity = _buyTaxLiquidity;
        sellTaxLiquidity = _sellTaxLiquidity;

        emit FeesUpdated(
            _buyTaxTreasury,
            _sellTaxTreasury,
            _buyTaxLiquidity,
            _sellTaxLiquidity
        );
    }

    function setSwapTokensThreshold(uint256 newAmount) external onlyOwner {
        require(
            newAmount >= TOTAL_SUPPLY / 10000, // 0.01%
            "swapTokensThreshold too low"
        );
        require(
            newAmount <= TOTAL_SUPPLY / 100, // 1%
            "swapTokensThreshold too high"
        );

        swapTokensThreshold = newAmount;
        emit SwapTokensThresholdUpdated(newAmount);
    }

    function setMaxPercentToSwap(uint256 newAmount) external onlyOwner {
        require(newAmount > 1, "too low");
        require(newAmount <= 10, "too high");

        maxPercentToSwap = newAmount;
        emit MaxPercentToSwapUpdated(newAmount);
    }

    function setMaxTxAmount(uint256 _maxTxAmount) external onlyOwner {
        require(
            _maxTxAmount >= (TOTAL_SUPPLY / 100),
            "MaxTxAmount >= 1% of totalsupply"
        );
        maxTxAmount = _maxTxAmount;
        emit MaxTxAmountUpdated(_maxTxAmount);
    }

    function setMaxWalletAmount(uint256 _maxWalletAmount) external onlyOwner {
        require(
            _maxWalletAmount >= (TOTAL_SUPPLY / 100),
            "MxWalletAmt >= 1% totalSupply"
        );
        maxWalletAmount = _maxWalletAmount;
        emit MaxWalletAmountUpdated(_maxWalletAmount);
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _isExcludedFromFees[account];
    }

    // Public (with view funcs last)

    // Internal (with view funcs last)

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // TEMP
        emit TestTransferStart(from, to, amount);

        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");

        if (amount == 0) {
            return;
        }

        if (!_swapping) {
            _check(from, to, amount);
        }

        uint256 _buyTaxTreasury = buyTaxTreasury;
        uint256 _sellTaxTreasury = sellTaxTreasury;
        uint256 _buyTaxLiquidity = buyTaxLiquidity;
        uint256 _sellTaxLiquidity = sellTaxLiquidity;

        address _uniswapV2Pair = address(uniswapV2Pair);

        if (!isExempt[from] && !isExempt[to]) {
            // TEMP
            emit TestTransferTradingActive(tradingActive);

            // Only relevant during launch (when tradingActive = False)
            // 1) List on uniswap
            // 2) initial allocation

            // mint (this -> owner)
            // initial allocation (owner -> treasury, dev, marketing) [treasury,dev,marketing will exceed limit]
            // adding liquidity (owner -> router -> pair) [pair will exceed limit]

            // set limit off
            // renounced owner (limit disabled) (_isExempt[to] will pass in _check above since owner address is still in mapping)

            // _transfer without owner or router
            require(tradingActive, "Trade is not open");
        }

        bool takeFee = !_swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 toSwap = balanceOf(address(this));

        bool canSwap = toSwap >= swapTokensThreshold &&
            toSwap > 0 &&
            from != _uniswapV2Pair &&
            takeFee;

        // TEMP
        emit TestTransferCheckSwap(canSwap, _swapping);

        if (canSwap && !_swapping) {
            _swapping = true;

            uint256 pairBalance = balanceOf(_uniswapV2Pair);
            if (toSwap > (pairBalance * maxPercentToSwap) / 100) {
                toSwap = (pairBalance * maxPercentToSwap) / 100;
            }

            uint256 liquidityTokenCut = (toSwap *
                (_buyTaxLiquidity + _sellTaxLiquidity)) /
                (_buyTaxTreasury +
                    _sellTaxTreasury +
                    _buyTaxLiquidity +
                    _sellTaxLiquidity); // toSwap * liqTax / totalTax
            uint256 treasuryTokenCut = toSwap - liquidityTokenCut;

            // // add tokens to lp
            // _swapAndLiquify(liquidityTokenCut);
            // // swap and send token to treasury
            // _swapAndSendTreasury(treasuryTokenCut);

            // TEMP
            emit TestTransferBeforeSwapback(pairBalance, _swapping);

            // handle swap, liquify, send
            swapBack(liquidityTokenCut, treasuryTokenCut);

            _swapping = false;
        }

        // TEMP
        emit TestTransferBeforeTakeFeeChecks(takeFee);

        if (
            takeFee &&
            to == _uniswapV2Pair &&
            (_sellTaxTreasury + _sellTaxLiquidity) > 0
        ) {
            uint256 fees = (amount * (_sellTaxTreasury + _sellTaxLiquidity)) /
                100;
            amount = amount - fees;

            super._transfer(from, address(this), fees);
        } else if (
            takeFee &&
            from == _uniswapV2Pair &&
            (_buyTaxTreasury + _buyTaxLiquidity) > 0
        ) {
            uint256 fees = (amount * (_buyTaxTreasury + _buyTaxLiquidity)) /
                100;
            amount = amount - fees;

            super._transfer(from, address(this), fees);
        }

        // TEMP
        emit TestTransferBeforeFinalTransfer(from, to, amount);

        super._transfer(from, to, amount);
    }

    // function _check(address from, address to, uint256 amount) internal view {
    function _check(address from, address to, uint256 amount) internal {
        // TEMP
        emit TestTransferCheckStart(from, to, amount);

        if (limitsInEffect) {
            // TODO: fix this error below
            // While limits in effect
            //      User buys -> adds Liquidity multiple times (2% each time for 3 times)
            //      User ends up owning 5% of total supply worth of tokens in LP
            //      User decides to remove liquidity (all 5%)
            //      Fail max tx check + max wallet check
            //          SHOULD THIS BE THE EXPECTED BEHAVIOR?

            // Dev Wallet
            //  Add liquidity with all initial allocation + eth
            //  Would Skip check below b/c isExempt[router] = true <-- CHECK THIS 1
            //  Would fail removing liquidity (over maxTx amount) <-- CHECK THIS 2

            // IS THIS DONE TO DISCOURAGE REMOVING LP UNTIL LIMITS DISABLED?

            // bool _isSpecialAddrresses = (from == owner() ||
            //     to == owner() ||
            //     from == address(this) ||
            //     to == address(this) ||
            //     from == treasuryWallet ||
            //     to == treasuryWallet ||
            //     from == devWallet ||
            //     to == devWallet ||
            //     from == marketingWallet ||
            //     to == marketingWallet);

            // TODO: include address(0xdead) to list above once burning is implemented
            // TODO: check case when from: Router and to: random address

            if (
                !(from != address(uniswapV2Router) && isExempt[from]) &&
                !isExempt[to]
            ) {
                // if (!_isSpecialAddrresses && !isExempt[to]) {
                // Check max Tx
                require(amount <= maxTxAmount, "Amount exceeds max");

                // Check max Wallet
                if (to == uniswapV2Pair) {
                    return;
                }
                require(
                    balanceOf(to) + amount <= maxWalletAmount,
                    "Max wallet exceeded max"
                );
            }
        }
    }

    // Private (with view funcs last)

    function swapBack(uint256 liquidityAmount, uint256 treasuryAmount) private {
        // TEMP
        emit TestTransferTopSwapback(liquidityAmount, treasuryAmount);

        uint256 liqEthHalf = liquidityAmount / 2;
        uint256 liqTokenHalf = liquidityAmount - liqEthHalf;

        uint256 swapTokenAmount = liqEthHalf + treasuryAmount;

        // swap token
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapTokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

        // TEMP
        emit TestTransferAfterUniswapSwapCall(swapTokenAmount);

        // add liquidity
        uint256 liqNewEthBalance = (address(this).balance * liqEthHalf) /
            swapTokenAmount;
        if (liqTokenHalf > 0 && liqNewEthBalance > 0) {
            _approve(address(this), address(uniswapV2Router), liqTokenHalf);

            // TEMP
            emit TestTransferBeforeUniswapLiqCall(
                liqTokenHalf,
                liqNewEthBalance
            );

            uniswapV2Router.addLiquidityETH{value: liqNewEthBalance}(
                address(this),
                liqTokenHalf,
                0,
                0,
                owner(),
                block.timestamp
            );
            emit SwapAndLiquify(liqEthHalf, liqNewEthBalance, liqTokenHalf);
        }

        // send treasury
        uint256 treasuryEthBalance = address(this).balance;
        (bool sent, ) = payable(treasuryWallet).call{value: treasuryEthBalance}(
            ""
        );
        require(sent, "Failed to send Ether");

        emit SwapAndSendTreasury(treasuryAmount, treasuryEthBalance);
    }
}