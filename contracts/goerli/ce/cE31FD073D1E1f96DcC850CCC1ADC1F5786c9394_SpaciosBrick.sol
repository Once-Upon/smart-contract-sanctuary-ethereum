/**
 *Submitted for verification at Etherscan.io on 2023-03-07
*/

// SPDX-License-Identifier: MIT
 // OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)
 
 
 pragma solidity ^0.8.0;
 //import "./Context.sol";
 //import "./Ownable.sol";
 //import "./Address.sol";
 //import "./SafeMath.sol";
 //import "./IERC20.sol";
 //import "./IUniswapV2Factory.sol";
 //import "./IERC20Metadata.sol";
 
 interface IERC20 {
 
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
         return _functionCallWithValue(target, data, 0, errorMessage);
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
         return _functionCallWithValue(target, data, value, errorMessage);
     }
 
     function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
         require(isContract(target), "Address: call to non-contract");
 
         // solhint-disable-next-line avoid-low-level-calls
         (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
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
 
 abstract contract Context {
     function _msgSender() internal view virtual returns (address) {
         return msg.sender;
     }
 
     function _msgData() internal view virtual returns (bytes calldata) {
         return msg.data;
     }
 }
 
 contract Ownable is Context {
     address private _owner;
     address private _previousOwner;
     uint256 private _lockTime;
 
     event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
 
     /**
      * @dev Initializes the contract setting the deployer as the initial owner.
      */
     function initial() public{
         address msgSender = _msgSender();
         _owner = msg.sender;
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
         require(_owner == _msgSender(), "OOOOOOOOwnable: caller is not the owner");
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
 
     function geUnlockTime() public view returns (uint256) {
         return _lockTime;
     }
 /**
  * 
  * Remove lock and unlock functions after auditor recommendations.
     //Locks the contract for owner for the amount of time provided
     function lock(uint256 time) public virtual onlyOwner {
         _previousOwner = _owner;
         _owner = address(0);
         _lockTime = now + time;
         emit OwnershipTransferred(_owner, address(0));
     }
     
     //Unlocks the contract for owner when _lockTime is exceeds
     function unlock() public virtual {
         require(_previousOwner == msg.sender, "You don't have permission to unlock");
         require(now < _lockTime , "Contract is locked until 7 days");
         emit OwnershipTransferred(_owner, _previousOwner);
         _owner = _previousOwner;
     } 
     */
 }
 
 /**
  * @dev Implementation of the {IERC20} interface.
  *
  */
 contract SpaciosBrick is Context, IERC20, IERC20Metadata {
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
       constructor(string memory name_, string memory symbol_, uint256 totalSupply_) {
         _name = name_;
         _symbol = symbol_;
         _totalSupply= totalSupply_*10**18;
         _balances[_msgSender()]= _totalSupply;
         emit Transfer(address(0), _msgSender(), _totalSupply);
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