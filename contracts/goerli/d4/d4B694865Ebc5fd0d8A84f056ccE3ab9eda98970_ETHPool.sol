// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./token/PoolToken.sol";
import "./token/IPoolToken.sol";
import "./oracle/PriceOracle.sol";
import "./oracle/IPriceOracle.sol";

/// @notice Thrown when owner is not allowed to access certain function
error ETHPool__OwnerNotAllowed();
/// @notice Thrown when caller requests more tokens to be withdrawn than balance
error ETHPool__NotEnoughTokens();
/// @notice Thrown when transfer of eth fails
error ETHPool__EthTransferFailed();

/**
 * @title ETHPool
 * @author Philipp Keinberger
 * @notice This contract is an ethereum pool allowing users to deposit eth and earn rewards
 * on their deposits. Rewards are manually transferred into the pool by `teamAddress`. The amount
 * of rewards eligible dependends on the individual stake of users inside the pool.
 * @dev This contract implements the IPoolToken and IPriceOracle interfaces for its pool token
 * and corresponding token price oracle.
 *
 * This contracts inherits from Openzeppelins Ownable contract to allow for the controlled
 * deposit of rewards by `teamAddress`.
 */
contract ETHPool is Ownable {
    IPoolToken private immutable i_token;
    IPriceOracle private immutable i_priceOracle;

    /// @notice Checks if caller is not the owner of contract
    modifier notOwner() {
        if (msg.sender == owner()) revert ETHPool__OwnerNotAllowed();
        _;
    }

    /// @notice sets the team address and deploys the pool token and its corresponding price oracle
    constructor(address teamAddress) {
        i_token = new PoolToken();
        i_priceOracle = new PriceOracle(address(this), address(i_token));

        _transferOwnership(teamAddress);
    }

    /// @dev if caller is the owner, the pool will not mint new tokens
    receive() external payable {
        if (msg.sender != owner()) deposit();
    }

    /**
     * @notice Function for depositing funds into the pool
     * @dev This function can not be called by the owner (team)
     * This function will mint new pool tokens to the sender, depending on the current price.
     * This token balance is a representation for the callers stake in the pool. The tokens
     * can then be used for withdrawal.
     */
    function deposit() public payable notOwner {
        uint256 amountToMint = i_priceOracle.getTokenAmountFromEthAmountAtDeposit(msg.value);
        i_token.mint(msg.sender, amountToMint);
    }

    /**
     * @notice Function for withdrawing funds from the pool
     * @param tokenAmount is the amount of tokens the caller exchanges for ETH
     * @dev This function burns `tokenAmount` and sends the corresponding amount
     * of ETH (determined by the price) to the user.
     *
     * This functions reverts if `tokenAmount` exceeds the callers balance.
     * This function reverts if the transfer of ETH to the caller fails.
     */
    function withdraw(uint256 tokenAmount) external payable {
        uint256 ethAmount = i_priceOracle.getEthAmountFromTokenAmount(tokenAmount);

        uint256 balance = i_token.balanceOf(msg.sender);
        if (tokenAmount > balance) revert ETHPool__NotEnoughTokens();

        i_token.burn(msg.sender, tokenAmount);

        (bool success, ) = msg.sender.call{value: ethAmount}("");
        if (!success) revert ETHPool__EthTransferFailed();
    }

    /**
     * @notice Function for getting the ERC20 token address of the pool
     * @return address of the token
     */
    function getTokenAddress() public view returns (address) {
        return (address(i_token));
    }

    /**
     * @notice Function for getting the price oracle address of the pool
     * @return address of the price oracle
     */
    function getPriceOracleAddress() public view returns (address) {
        return (address(i_priceOracle));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev This interface adds additional mint and burn functionality to standard ERC20 tokens
 * defined by the IERC20 interface of Openzeppelin.
 */
interface IPoolToken is IERC20 {
    /**
     * @notice Function for minting new tokens
     * @param to is the address the new tokens be minted to
     * @param amount is the amount of new tokens to be minted
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Function for burning tokens
     * @param from is the address tokens will be burnt from
     * @param amount is the amount of tokens to be burnt
     */
    function burn(address from, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPoolToken.sol";

/**
 * @title PoolToken
 * @author Philipp Keinberger
 * @notice This contract is an ERC20 with additional minting and burning functionality restricted
 * to the owner.
 * @dev This contract inherits from Openzeppelins ERC20 contract to implement ERC20 functionality.
 * This contracts inherits from Openzeppelins Ownable contract to allow for controlled
 * minting and burning of tokens by the owner.
 *
 * PoolToken implements the IPoolToken interface to extend its ERC20 functionality to
 * allow for minting and burning of tokens
 */
contract PoolToken is ERC20, Ownable, IPoolToken {
    constructor() ERC20("PoolToken", "PT") {}

    /**
     * @inheritdoc IPoolToken
     * @dev This function reverts if caller is not the owner
     */
    function mint(address to, uint256 amount) public override onlyOwner {
        _mint(to, amount);
    }

    /**
     * @inheritdoc IPoolToken
     * @dev This function reverts if caller is not the owner
     */
    function burn(address from, uint256 amount) public override onlyOwner {
        _burn(from, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPriceOracle.sol";

/**
 * @title PriceOracle
 * @author Philipp Keinberger
 * @notice This contract provides a price oracle for a given ERC-20 token and ETH pool contract.
 * The price is determined by the amount of tokens in circulation and the total value of ETH
 * inside of the pool.
 * The price formula is: (amount of ETH inside the pool) / (total Supply of tokens)
 * @dev This contract implements the IPriceOracle interface.
 */
contract PriceOracle is IPriceOracle {
    /**
     * @dev DIVISION_GUARD is a constant that is required for safe divisions.
     * It ensures that the divisor is never greater than the numerator, which would
     * lead to the divsion result being 0.
     */
    uint256 private constant DIVISION_GUARD = 1e18;
    address private immutable i_poolAddress;
    IERC20 private immutable i_token;

    /// @notice sets the ETH pool and ERC-20 token addresses
    constructor(address poolAddress, address tokenAddress) {
        i_poolAddress = poolAddress;
        i_token = IERC20(tokenAddress);
    }

    /**
     * @notice Internal function for calculating the price.
     * The function will return the price determined by the price formula.
     * If the amount of ETH inside the pool or the amount of tokens in circulation is zero, the
     * function will return a price of 1 (starting price 1token = 1eth).
     * @param poolValue is the ETH value of the pool
     * @dev This function gets called by getPrice and getTokenAmountFromEthAmountAtDeposit.
     */
    function _getPrice(uint256 poolValue) internal view returns (uint256) {
        uint256 totalSupply = i_token.totalSupply();
        if (poolValue == 0 || totalSupply == 0) return 1e18;
        return ((poolValue * DIVISION_GUARD) / totalSupply);
    }

    /**
     * @notice Function for retrieving the current price
     * @return price of 1 token in ETH (wei)
     */
    function getPrice() public view override returns (uint256) {
        uint256 poolValue = i_poolAddress.balance;
        return _getPrice(poolValue);
    }

    /**
     * @inheritdoc IPriceOracle
     * @dev This function returns the amount of tokens equivalent to `ethAmount`, while
     * taking into account that `ethAmount` has already been deposited into the pool.
     */
    function getTokenAmountFromEthAmountAtDeposit(uint256 ethAmount)
        external
        view
        override
        returns (uint256)
    {
        uint256 poolValueMinMsgValue = i_poolAddress.balance - ethAmount;

        return
            (ethAmount * ((1e18 * DIVISION_GUARD) / _getPrice(poolValueMinMsgValue))) /
            DIVISION_GUARD;
    }

    /**
     * @inheritdoc IPriceOracle
     * @dev This function returns the amount of tokens equivalent to `ethAmount`.
     */
    function getTokenAmountFromEthAmount(uint256 ethAmount)
        external
        view
        override
        returns (uint256)
    {
        uint256 poolValue = i_poolAddress.balance;

        return (ethAmount * ((1e18 * DIVISION_GUARD) / _getPrice(poolValue))) / DIVISION_GUARD;
    }

    /**
     * @inheritdoc IPriceOracle
     * @dev This function returns the amount of ETH equivalent to `tokenAmount`.
     */
    function getEthAmountFromTokenAmount(uint256 tokenAmount)
        external
        view
        override
        returns (uint256)
    {
        return (getPrice() * tokenAmount) / DIVISION_GUARD;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @dev This is an interface defining standard functions of the price oracle
 * for the PoolToken.
 */
interface IPriceOracle {
    /**
     * @notice Function for retrieving the price of the token
     * @return price of token in wei
     */
    function getPrice() external view returns (uint256);

    /**
     * @notice Function for getting the amount of tokens for a given amount of ETH `ethAmount`
     * at deposit
     * @param ethAmount is the amount of ETH in wei
     * @return tokenAmount amount of tokens in wei
     */
    function getTokenAmountFromEthAmountAtDeposit(uint256 ethAmount)
        external
        view
        returns (uint256);

    /**
     * @notice Function for getting the amount of tokens for a given amount of ETH `ethAmount`
     * @param ethAmount is the amount of ETH in wei
     * @return amount of tokens in wei
     */
    function getTokenAmountFromEthAmount(uint256 ethAmount) external view returns (uint256);

    /**
     * @notice Function for retrieving the eth amount for given amount of tokens
     * @param tokenAmount is the amount of tokens
     * @return amount of ETH in wei
     */
    function getEthAmountFromTokenAmount(uint256 tokenAmount) external view returns (uint256);
}

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