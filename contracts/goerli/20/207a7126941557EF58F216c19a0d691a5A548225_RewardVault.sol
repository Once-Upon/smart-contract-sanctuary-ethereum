/**
 *Submitted for verification at Etherscan.io on 2023-02-01
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


// File contracts/Vault.sol



pragma solidity 0.8.4;
/// @title  RewardVault
/// @notice This contract is deployed by the Reaward Factory contract for each client.
contract RewardVault is IRewardVault, OwnableUpgradeable {
    using UniversalERC20 for IERC20Upgradeable;

    /// @notice Minimum invest amount at once
    uint256 private _minInvestAmt;
    /// @notice Maximum invest amount at once
    uint256 private _maxInvestAmt;

    /// @notice Reward locked flag
    bool private _locked;

    /// @notice Project token which investors to buy
    address private _projectToken;
    /// @notice Reward token to give to the referrers
    address private _rewardToken;
    /// @notice Store factory address to get common configurations
    address private _factory;

    /// @notice We have blacklist of the investors
    mapping(address => bool) private _investorBlacklist;
    /// @notice We have blacklist of the referrers
    mapping(address => bool) private _referrerBlacklist;
    /// @notice We store used signatures, so it can not be used several times for the spam purpose
    mapping(bytes32 => bool) private _usedSignatures;

    event InvestLimitUpdated(uint256 minInvestAmt, uint256 maxInvestAmt);
    event InvestorBlackfied(address investor, bool blackfied);
    event Locked(bool locked);
    event ReferrerBlackfied(address referrer, bool blackfied);
    event ReferrerRewarded(address referrer, uint256 amount);

    error DisabledWhenLocked();
    error DuplicatedRequest();
    error ExpiredRequest(uint256 expireTime, uint256 reqTime);
    error InvalidInvestAmtLimits();
    error InvalidSignature();
    error UnpermittedRequest();

    modifier whenNotLocked() {
        if (_locked) revert DisabledWhenLocked();
        _;
    }

    function initialize(
        uint256 minInvestAmt_,
        uint256 maxInvestAmt_,
        address admin_,
        address projectToken_,
        address rewardToken_
    ) public override initializer {
        __Ownable_init();

        if (maxInvestAmt_ > 0 && minInvestAmt_ > maxInvestAmt_)
            revert InvalidInvestAmtLimits();
        _minInvestAmt = minInvestAmt_;
        _maxInvestAmt = maxInvestAmt_;

        _projectToken = projectToken_;
        _rewardToken = rewardToken_;

        _factory = _msgSender();
        transferOwnership(admin_);
    }

    /// @notice Referrer claim rewards
    /// @param sig_ - It should get signature from the BE for the verification
    function claimReward(
        uint256 expireTime_,
        uint256 amount_,
        bytes calldata sig_
    ) external whenNotLocked {
        if (expireTime_ < block.timestamp)
            revert ExpiredRequest(expireTime_, block.timestamp);
        if (_referrerBlacklist[_msgSender()]) revert UnpermittedRequest();

        // This recreates the message that was signed on the backend.
        bytes32 message = prefixed(
            keccak256(
                abi.encodePacked(
                    _msgSender(),
                    _rewardToken,
                    amount_,
                    expireTime_,
                    this
                )
            )
        );
        if (_usedSignatures[message]) revert DuplicatedRequest();
        _usedSignatures[message] = true;

        address signer = IRewardVaultFactory(_factory).signer();
        if (recoverSigner(message, sig_) != signer) revert InvalidSignature();

        IERC20Upgradeable(_rewardToken).universalTransfer(
            _msgSender(),
            amount_
        );

        emit ReferrerRewarded(_msgSender(), amount_);
    }

    function recoverSigner(bytes32 message_, bytes memory sig_)
        internal
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig_);

        return ecrecover(message_, v, r, s);
    }

    /// @dev Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash_) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash_)
            );
    }

    function splitSignature(bytes memory sig_)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig_.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig_, 32))
            // second 32 bytes
            s := mload(add(sig_, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig_, 96)))
        }

        return (v, r, s);
    }

    /// @notice Recover tokens from the contract
    /// @dev This function is only callable by admin.
    /// @param token_: the address of the token to withdraw
    /// @param amount_: the number of tokens to withdraw
    function recoverTokens(address token_, uint256 amount_) external onlyOwner {
        IERC20Upgradeable(token_).universalTransfer(_msgSender(), amount_);
    }

    /// @notice Lock rewards distribution in the vault
    function lock(bool flag_) external onlyOwner {
        _locked = flag_;
        emit Locked(flag_);
    }

    function locked() external view returns (bool) {
        return _locked;
    }

    /// @notice Update invest min / max limitation
    function updateInvestLimits(uint256 minInvestAmt_, uint256 maxInvestAmt_)
        external
        onlyOwner
    {
        if (maxInvestAmt_ > 0 && minInvestAmt_ > maxInvestAmt_)
            revert InvalidInvestAmtLimits();
        _minInvestAmt = minInvestAmt_;
        _maxInvestAmt = maxInvestAmt_;

        emit InvestLimitUpdated(minInvestAmt_, maxInvestAmt_);
    }

    /// @notice View min / max invest limitation
    function investLimits() external view override returns (uint256, uint256) {
        return (_minInvestAmt, _maxInvestAmt);
    }

    /// @notice Disable investor address. This account can not invest in the project if disabled
    function disableInvestor(address investor_, bool flag_) external onlyOwner {
        _investorBlacklist[investor_] = flag_;
        emit InvestorBlackfied(investor_, flag_);
    }

    /// @notice Check if the investor is allowed to invest in the project
    function investorEnabled(address investor_)
        external
        view
        override
        returns (bool)
    {
        return !_investorBlacklist[investor_];
    }

    /// @notice Disable referrer address. This account can not get rewards from his referred accounts.
    function disableReferrer(address referrer_, bool flag_) external onlyOwner {
        _referrerBlacklist[referrer_] = flag_;
        emit ReferrerBlackfied(referrer_, flag_);
    }

    /// @notice Check if the referrer is allowed to get rewards from this project
    function referrerEnabled(address referrer_)
        external
        view
        override
        returns (bool)
    {
        return !_referrerBlacklist[referrer_];
    }

    /// @notice View project token
    function projectToken() external view override returns (address) {
        return _projectToken;
    }

    /// @notice View reward token
    function rewardToken() external view override returns (address) {
        return _rewardToken;
    }

    /// @notice View factory address
    function factory() external view returns (address) {
        return _factory;
    }
}