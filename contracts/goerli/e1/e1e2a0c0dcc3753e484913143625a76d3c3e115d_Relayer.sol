/**
 *Submitted for verification at Etherscan.io on 2023-01-26
*/

// Sources flattened with hardhat v2.3.3 https://hardhat.org

// File @openzeppelin/contracts-upgradeable/proxy/utils/[email protected]

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
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


// File @openzeppelin/contracts-upgradeable/utils/[email protected]



pragma solidity ^0.8.0;

/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}


// File @openzeppelin/contracts-upgradeable/access/[email protected]



pragma solidity ^0.8.0;


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
    uint256[49] private __gap;
}


// File @uniswap/v2-periphery/contracts/interfaces/[email protected]

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


// File @uniswap/v2-periphery/contracts/interfaces/[email protected]

pragma solidity >=0.6.2;

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


// File @uniswap/v2-periphery/contracts/interfaces/[email protected]

pragma solidity >=0.5.0;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}


// File contracts/IETHPlugin.sol



pragma solidity ^0.8.4;

interface IETHPlugin {
    function unwrap(address, uint256) external;
}


// File contracts/IVaultFactory.sol


pragma solidity 0.8.4;

/// @title  RewardVaultFactory Interface
/// @notice Interface with exposed methods that can be used by outside contracts.
interface IRewardVaultFactory {
    function signer() external view returns (address);
}

/// @title  RewardVault Interface
/// @notice Interface with exposed methods that can be used by outside contracts.
interface IRewardVault {
    function initialize(
        uint256 minInvestAmt_,
        uint256 maxInvestAmt_,
        address admin_,
        address projectToken_,
        address rewardToken_
    ) external;

    function investLimits() external view returns (uint256, uint256);

    function investorEnabled(address investor_) external view returns (bool);

    function referrerEnabled(address referrer_) external view returns (bool);

    function projectToken() external view returns (address);

    function rewardToken() external view returns (address);
}


// File @openzeppelin/contracts-upgradeable/token/ERC20/[email protected]



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


// File @openzeppelin/contracts-upgradeable/utils/[email protected]



pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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


// File @openzeppelin/contracts-upgradeable/token/ERC20/utils/[email protected]



pragma solidity ^0.8.0;


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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


// File contracts/UniversalERC20.sol


pragma solidity ^0.8.4;

// File: contracts/UniversalERC20Upgradeable.sol
library UniversalERC20 {
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable internal constant ZERO_ADDRESS =
        IERC20Upgradeable(0x0000000000000000000000000000000000000000);
    IERC20Upgradeable internal constant ETH_ADDRESS =
        IERC20Upgradeable(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    error FuncWrongUsage();

    function universalTransfer(
        IERC20Upgradeable token_,
        address to_,
        uint256 amount_
    ) internal returns (uint256) {
        if (amount_ == 0) {
            return 0;
        }

        if (isETH(token_)) {
            payable(address(uint160(to_))).sendValue(amount_);
            return amount_;
        } else {
            uint256 balanceBefore = token_.balanceOf(to_);
            token_.safeTransfer(to_, amount_);
            return token_.balanceOf(to_) - balanceBefore;
        }
    }

    function universalTransferFrom(
        IERC20Upgradeable token_,
        address from_,
        address to_,
        uint256 amount_
    ) internal returns (uint256) {
        if (amount_ == 0) {
            return 0;
        }

        if (isETH(token_)) {
            if (from_ != msg.sender || msg.value < amount_)
                revert FuncWrongUsage();
            if (to_ != address(this))
                payable(address(uint160(to_))).sendValue(amount_);
            // refund redundant amount
            if (msg.value > amount_)
                payable(msg.sender).sendValue(msg.value - amount_);

            return amount_;
        } else {
            uint256 balanceBefore = token_.balanceOf(to_);
            token_.safeTransferFrom(from_, to_, amount_);
            return token_.balanceOf(to_) - balanceBefore;
        }
    }

    function universalTransferFromSenderToThis(
        IERC20Upgradeable token_,
        uint256 amount_
    ) internal returns (uint256) {
        if (amount_ == 0) {
            return 0;
        }

        if (isETH(token_)) {
            if (msg.value < amount_) revert FuncWrongUsage();
            // Refund redundant amount
            if (msg.value > amount_)
                payable(msg.sender).sendValue(msg.value - amount_);

            return amount_;
        } else {
            uint256 balanceBefore = token_.balanceOf(address(this));
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            return token_.balanceOf(address(this)) - balanceBefore;
        }
    }

    function universalApprove(
        IERC20Upgradeable token_,
        address to_,
        uint256 amount_
    ) internal {
        if (!isETH(token_)) {
            if (amount_ > 0 && token_.allowance(address(this), to_) > 0)
                token_.safeApprove(to_, 0);

            token_.safeApprove(to_, amount_);
        }
    }

    function universalBalanceOf(IERC20Upgradeable token_, address who_)
        internal
        view
        returns (uint256)
    {
        if (isETH(token_)) return who_.balance;
        else return token_.balanceOf(who_);
    }

    function universalDecimals(IERC20Upgradeable token_)
        internal
        view
        returns (uint256)
    {
        if (isETH(token_)) return 18;

        (bool success, bytes memory data) = address(token_).staticcall{
            gas: 10000
        }(abi.encodeWithSignature("decimals()"));
        if (!success || data.length == 0) {
            (success, data) = address(token_).staticcall{gas: 10000}(
                abi.encodeWithSignature("DECIMALS()")
            );
        }

        return (success && data.length > 0) ? abi.decode(data, (uint256)) : 18;
    }

    function isETH(IERC20Upgradeable token_) internal pure returns (bool) {
        return (address(token_) == address(ZERO_ADDRESS) ||
            address(token_) == address(ETH_ADDRESS));
    }

    function eq(IERC20Upgradeable a, IERC20Upgradeable b)
        internal
        pure
        returns (bool)
    {
        return a == b || (isETH(a) && isETH(b));
    }
}


// File contracts/Relayer.sol



pragma solidity 0.8.4;
/// @title  Asset Relayer
/// @notice This contract is to be used as a transaction relayer.
/// @notice Valid txns will be assessed a fee and relayed to account/smart contracts for processing.
/// @dev Roles based for admin methods; public contract interactions for txns relays.
contract Relayer is OwnableUpgradeable {
    using UniversalERC20 for IERC20Upgradeable;

    struct PurchaseArgs {
        address dex; // The address of the DEX where token is being traded
        address vault; // The escrow vault address which manages the project
        address referrer; // The address of the referrer. Needed to produce event for successful invest
        address tokenIn; // The address of the token that the user is investing with
        address[] path; // The swap path array, it can be multi-hop for better investment
        uint256 amountIn; // The amount (pre fees) the user is intending to purchase with
        uint256 amountOutMin; // The minimum amount of tokens that the user wants to receive from this investment
    }

    uint32 public constant FEE_DENOMINATOR = 10000;
    uint32 public constant MAX_FEE = 3000;

    /// @notice Relay fee will be assessed for every valid txn.
    uint32 private _relayFee;

    /// @notice Wallet where fees will be collected.
    address private _treasury;

    IETHPlugin private _ethPlugin;

    /// @notice Save referrer address for each user & vault (vault => user => referrer)
    mapping(address => mapping(address => address)) private _referrers;

    /// @notice Event to be captured, including relayed transaction and referrer to be credited.
    event AssetRelayed(
        address investor,
        address referrer,
        address vault,
        address tokenIn,
        uint256 feeAmount,
        uint256 amountOut
    );

    error InvalidZeroAddress();
    error InvestDisabled();
    error TooMuchFee(uint32 value, uint32 limit);
    error TooMuchInvest(uint256 amount, uint256 maxAmount);
    error TooSmallAmountOut(uint256 amountOut, uint256 amountOutMin);
    error TooSmallInvest(uint256 amount, uint256 minAmount);

    function initialize(address treasury_, address ethPlugin_)
        public
        initializer
    {
        __Ownable_init();

        if (treasury_ == address(0) || ethPlugin_ == address(0))
            revert InvalidZeroAddress();
        _treasury = treasury_;
        _ethPlugin = IETHPlugin(ethPlugin_);

        _relayFee = 25; // Default value, 25 basis points (0.25%)
    }

    /// @notice Used to invest token in post-deployed, approved assets/projects
    /// @notice Txn will be relayed to DEX for swapping the token for the approved asset
    /// @param args_ - A struct of args
    function purchaseFromDex(PurchaseArgs calldata args_) external payable {
        (uint256 minInvestAmt, uint256 maxInvestAmt) = IRewardVault(args_.vault)
            .investLimits();
        bool investorEnabled = IRewardVault(args_.vault).investorEnabled(
            _msgSender()
        );
        bool referrerEnabled = IRewardVault(args_.vault).referrerEnabled(
            args_.referrer
        );

        if (!investorEnabled) revert InvestDisabled();

        uint256 amountIn = IERC20Upgradeable(args_.tokenIn)
            .universalTransferFromSenderToThis(args_.amountIn);

        // Relay fee is deducted from the input amount
        // We are going to collect fee later to save gas costs
        uint256 feeAmount = (amountIn * _relayFee) / FEE_DENOMINATOR;
        amountIn -= feeAmount;

        // Swap token to the project token
        uint256 amountOut = swapOnDex(args_, amountIn);

        // Validate amountOut
        if (amountOut < args_.amountOutMin)
            revert TooSmallAmountOut(amountOut, args_.amountOutMin);
        if (amountOut < minInvestAmt)
            revert TooSmallInvest(amountOut, minInvestAmt);
        if (maxInvestAmt > 0 && amountOut > maxInvestAmt)
            revert TooMuchInvest(amountOut, maxInvestAmt);

        address currentReferrer;
        if (referrerEnabled) {
            currentReferrer = _referrers[args_.vault][_msgSender()];

            // If this investor does not have his referrer yet and the referrer address passed in the arg is valid,
            // we update the referrer address of this investor.
            if (
                currentReferrer == address(0) &&
                args_.referrer != address(0) &&
                args_.referrer != _msgSender()
            ) {
                currentReferrer = args_.referrer;
                _referrers[args_.vault][_msgSender()] = currentReferrer;
            }
        }

        emit AssetRelayed(
            _msgSender(),
            currentReferrer,
            args_.vault,
            args_.tokenIn,
            feeAmount,
            amountOut
        );
    }

    /// @notice Swap action is described in this function
    /// @return amountOut - Swapped amount out
    function swapOnDex(PurchaseArgs memory args_, uint256 amountIn_)
        internal
        returns (uint256 amountOut)
    {
        IERC20Upgradeable tokenIn = IERC20Upgradeable(args_.tokenIn);
        IERC20Upgradeable tokenOut = IERC20Upgradeable(
            IRewardVault(args_.vault).projectToken()
        );
        IUniswapV2Router02 dex = IUniswapV2Router02(args_.dex);
        address weth = dex.WETH();
        uint256 balanceBefore = tokenOut.universalBalanceOf(_msgSender());

        // tokenIn = tokenOut
        if (tokenIn.eq(tokenOut)) {
            tokenIn.universalTransfer(_msgSender(), amountIn_);
        }
        // tokenIn = eth && tokenout = weth
        else if (tokenIn.isETH() && address(tokenOut) == weth) {
            IWETH(weth).deposit{value: amountIn_}();
            IERC20Upgradeable(weth).universalTransfer(_msgSender(), amountIn_);
        }
        // tokenIn = eth
        else if (tokenIn.isETH()) {
            dex.swapExactETHForTokensSupportingFeeOnTransferTokens{
                value: amountIn_
            }(
                args_.amountOutMin,
                args_.path,
                _msgSender(),
                block.timestamp + 300
            );
        }
        // tokenIn = weth && tokenOut = eth
        else if (args_.tokenIn == weth && tokenOut.isETH()) {
            IETHPlugin plugin = _ethPlugin;
            tokenIn.universalApprove(address(plugin), amountIn_);
            plugin.unwrap(weth, amountIn_);
            UniversalERC20.ETH_ADDRESS.universalTransfer(
                _msgSender(),
                amountIn_
            );
        }
        // tokenOut = eth
        else if (tokenOut.isETH()) {
            tokenIn.universalApprove(args_.dex, amountIn_);
            dex.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountIn_,
                args_.amountOutMin,
                args_.path,
                _msgSender(),
                block.timestamp + 300
            );
        }
        // normal swap case
        else {
            tokenIn.universalApprove(args_.dex, amountIn_);
            dex.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn_,
                args_.amountOutMin,
                args_.path,
                _msgSender(),
                block.timestamp + 300
            );
        }

        amountOut = tokenOut.universalBalanceOf(_msgSender()) - balanceBefore;
    }

    /// @notice View referrer of the vault and account
    function viewReferrer(address vault_, address account_)
        external
        view
        returns (address)
    {
        return _referrers[vault_][account_];
    }

    /// @notice Update relay fee
    function updateRelayFee(uint32 fee_) external onlyOwner {
        if (fee_ > MAX_FEE) revert TooMuchFee(fee_, MAX_FEE);
        _relayFee = fee_;
    }

    function relayFee() external view returns (uint32) {
        return _relayFee;
    }

    /// @notice Update ETH plugin contract address
    function updateETHPlugin(address ethPlugin_) external onlyOwner {
        if (ethPlugin_ == address(0)) revert InvalidZeroAddress();
        _ethPlugin = IETHPlugin(ethPlugin_);
    }

    function ethPlugin() external view returns (address) {
        return address(_ethPlugin);
    }

    /// @notice Update treasury address to receive fee
    function updateTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert InvalidZeroAddress();
        _treasury = treasury_;
    }

    function treasury() external view returns (address) {
        return _treasury;
    }

    /// @notice Recover tokens from the contract
    /// @dev This function is only callable by admin.
    /// @param token_: the address of the token to withdraw
    /// @param amount_: the number of tokens to withdraw
    function recoverTokens(address token_, uint256 amount_) external {
        IERC20Upgradeable(token_).universalTransfer(_treasury, amount_);
    }

    fallback() external payable {}

    receive() external payable {}
}