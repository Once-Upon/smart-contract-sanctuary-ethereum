/**
 *Submitted for verification at Etherscan.io on 2022-09-15
*/

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
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

// File: @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
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
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

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
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: contracts/AasnMasterChef.sol



pragma solidity ^0.8.0;




interface IRewarder {
    function onReward(
        uint256 pid,
        address user,
        address recipient,
        uint256 rewardAmount,
        uint256 newLpAmount
    ) external;

    function pendingTokens(
        uint256 pid,
        address user,
        uint256 rewardAmount
    ) external view returns (IERC20[] memory, uint256[] memory);
}

/// @notice MasterChef contract for Assassin Protocol
contract AssnMasterChef is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Info of each user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of reward token entitled to the user.
    /// `rewardAccum` The amount of harvestable reward token
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 rewardAccum;
    }

    /// @notice Info of each pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of reward token to distribute per block.
    struct PoolInfo {
        uint256 lpSupply;
        uint256 accRewardPerShare;
        uint256 lastRewardBlock;
        uint256 allocPoint;
    }

    uint256 private constant ACC_REWARD_PRECISION = 1e12;

    /// @notice Address of reward token contract.
    IERC20 public immutable _rewardToken;

    /// @notice Info of each pool.
    PoolInfo[] public _pools;
    /// @notice Address of the LP token for each pool.
    IERC20[] public _lpTokens;
    /// @notice Address of each `IRewarder` contract.
    IRewarder[] public _rewarders;
    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public _users;

    /// @notice Reward tokens allocated per block.
    uint256 public _rewardPerBlock;
    /// @notice The block number when reward starts.
    uint256 public _startBlock;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public _totalAllocPoint;
    /// @notice When some pools have reward token staking, then we need to consider it separately
    uint256 public _totalRewardStaked;

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event Withdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event Harvest(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event LogPoolAddition(
        uint256 indexed pid,
        uint256 allocPoint,
        IERC20 indexed lpToken,
        IRewarder indexed rewarder
    );
    event LogSetPool(
        uint256 indexed pid,
        uint256 allocPoint,
        IRewarder indexed rewarder,
        bool overwrite
    );
    event LogUpdatePool(
        uint256 indexed pid,
        uint256 lastRewardBlock,
        uint256 lpSupply,
        uint256 accRewardPerShare
    );
    event LogUpdateRewardPerBlock(uint256 rewardPerBlock);

    /// @param rewardToken_ The reward token contract address.
    /// @param rewardPerBlock_ Reward token amount per block
    constructor(
        IERC20 rewardToken_,
        uint256 rewardPerBlock_,
        uint256 startBlock_
    ) {
        _rewardToken = rewardToken_;
        _rewardPerBlock = rewardPerBlock_;
        _startBlock = startBlock_ < block.number
            ? block.number + 100
            : startBlock_;
    }

    /// @notice Returns the number of pools.
    function poolLength() public view returns (uint256) {
        return _pools.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// @param allocPoint_ AP of the new pool.
    /// @param lpToken_ Address of the LP ERC-20 token.
    /// @param rewarder_ Address of the rewarder delegate.
    function add(
        uint256 allocPoint_,
        IERC20 lpToken_,
        IRewarder rewarder_
    ) external onlyOwner {
        uint256 lastRewardBlock = block.number > _startBlock
            ? block.number
            : _startBlock;
        _totalAllocPoint += allocPoint_;
        _lpTokens.push(lpToken_);
        _rewarders.push(rewarder_);

        _pools.push(
            PoolInfo({
                lpSupply: 0,
                allocPoint: allocPoint_,
                lastRewardBlock: lastRewardBlock,
                accRewardPerShare: 0
            })
        );
        emit LogPoolAddition(
            _lpTokens.length - 1,
            allocPoint_,
            lpToken_,
            rewarder_
        );
    }

    /// @notice Update the given pool's reward token allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @param allocPoint_ New AP of the pool.
    /// @param rewarder_ Address of the rewarder delegate.
    /// @param overwrite_ True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
    function set(
        uint256 pid_,
        uint256 allocPoint_,
        IRewarder rewarder_,
        bool overwrite_
    ) external onlyOwner {
        _totalAllocPoint =
            (_totalAllocPoint + allocPoint_) -
            _pools[pid_].allocPoint;
        _pools[pid_].allocPoint = allocPoint_;
        if (overwrite_) {
            _rewarders[pid_] = rewarder_;
        }
        emit LogSetPool(pid_, allocPoint_, _rewarders[pid_], overwrite_);
    }

    /// @notice View function to see pending reward token on frontend.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @param user_ Address of user.
    /// @return pending reward for a given user.
    function pendingReward(uint256 pid_, address user_)
        external
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = _pools[pid_];
        UserInfo storage user = _users[pid_][user_];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpSupply;
        uint256 blockNumber = block.number;
        if (blockNumber > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocks = blockNumber - pool.lastRewardBlock;
            uint256 poolReward = (blocks * _rewardPerBlock * pool.allocPoint) /
                _totalAllocPoint;
            accRewardPerShare += (poolReward * ACC_REWARD_PRECISION) / lpSupply;
        }
        pending =
            (user.amount * accRewardPerShare) /
            ACC_REWARD_PRECISION -
            user.rewardDebt;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids_ Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids_) public {
        uint256 len = pids_.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids_[i]);
        }
    }

    /// @notice Update reward allocation amount per block
    /// @param rewardPerBlock_ new reward allocation amount
    /// @param pids_ Pool IDs of all to be updated
    function updateRewardPerBlock(
        uint256 rewardPerBlock_,
        uint256[] calldata pids_
    ) external onlyOwner {
        massUpdatePools(pids_);
        _rewardPerBlock = rewardPerBlock_;
        emit LogUpdateRewardPerBlock(rewardPerBlock_);
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid_) public returns (PoolInfo memory pool) {
        pool = _pools[pid_];
        uint256 blockNumber = block.number;
        if (blockNumber > pool.lastRewardBlock) {
            uint256 lpSupply = pool.lpSupply;
            if (lpSupply > 0) {
                uint256 blocks = blockNumber - pool.lastRewardBlock;
                uint256 poolReward = (blocks *
                    _rewardPerBlock *
                    pool.allocPoint) / _totalAllocPoint;
                pool.accRewardPerShare +=
                    (poolReward * ACC_REWARD_PRECISION) /
                    lpSupply;
            }
            pool.lastRewardBlock = blockNumber;
            _pools[pid_] = pool;
            emit LogUpdatePool(
                pid_,
                blockNumber,
                lpSupply,
                pool.accRewardPerShare
            );
        }
    }

    /// @notice Deposit LP tokens for reward allocation.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @param amount_ LP token amount to deposit.
    /// @param to_ The receiver of `amount` deposit benefit.
    function deposit(
        uint256 pid_,
        uint256 amount_,
        address to_
    ) public {
        PoolInfo memory pool = updatePool(pid_);
        UserInfo storage user = _users[pid_][to_];

        uint256 balanceBefore = _lpTokens[pid_].balanceOf(address(this));
        _lpTokens[pid_].safeTransferFrom(msg.sender, address(this), amount_);
        amount_ = _lpTokens[pid_].balanceOf(address(this)) - balanceBefore;

        // Effects
        user.rewardAccum += ((user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION -
            user.rewardDebt);
        _pools[pid_].lpSupply += amount_;
        user.amount += amount_;
        user.rewardDebt =
            (user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        // Interactions
        IRewarder rewarder = _rewarders[pid_];
        if (address(rewarder) != address(0)) {
            rewarder.onReward(pid_, to_, to_, 0, user.amount);
        }

        if (address(_lpTokens[pid_]) == address(_rewardToken)) {
            _totalRewardStaked += amount_;
        }
        emit Deposit(msg.sender, pid_, amount_, to_);
    }

    /// @notice Withdraw LP tokens.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @param amount_ LP token amount to withdraw.
    /// @param to_ Receiver of the LP tokens.
    function withdraw(
        uint256 pid_,
        uint256 amount_,
        address to_
    ) public {
        PoolInfo memory pool = updatePool(pid_);
        UserInfo storage user = _users[pid_][msg.sender];

        // Effects
        user.rewardAccum += ((user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION -
            user.rewardDebt);
        _pools[pid_].lpSupply -= amount_;
        user.amount -= amount_;
        user.rewardDebt =
            (user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        // Interactions
        IRewarder rewarder = _rewarders[pid_];
        if (address(rewarder) != address(0)) {
            rewarder.onReward(pid_, msg.sender, to_, 0, user.amount);
        }

        _lpTokens[pid_].safeTransfer(to_, amount_);

        if (address(_lpTokens[pid_]) == address(_rewardToken)) {
            _totalRewardStaked -= amount_;
        }

        emit Withdraw(msg.sender, pid_, amount_, to_);
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @param to_ Receiver of rewards.
    function harvest(uint256 pid_, address to_) public {
        PoolInfo memory pool = updatePool(pid_);
        UserInfo storage user = _users[pid_][msg.sender];
        uint256 _pendingReward = user.rewardAccum +
            (user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION -
            user.rewardDebt;

        // Effects
        user.rewardDebt =
            (user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        // Interactions
        safeRewardTransfer(to_, _pendingReward);
        user.rewardAccum = 0;

        IRewarder rewarder = _rewarders[pid_];
        if (address(rewarder) != address(0)) {
            rewarder.onReward(
                pid_,
                msg.sender,
                to_,
                _pendingReward,
                user.amount
            );
        }

        emit Harvest(msg.sender, pid_, _pendingReward, to_);
    }

    /// @notice Withdraw LP tokens and harvest proceeds for transaction sender to `to_`.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @param amount_ LP token amount to withdraw.
    /// @param to_ Receiver of the LP tokens and rewards.
    function withdrawAndHarvest(
        uint256 pid_,
        uint256 amount_,
        address to_
    ) public {
        PoolInfo memory pool = updatePool(pid_);
        UserInfo storage user = _users[pid_][msg.sender];

        uint256 _pendingReward = user.rewardAccum +
            (user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION -
            user.rewardDebt;

        // Effects
        _pools[pid_].lpSupply -= amount_;
        user.amount -= amount_;
        user.rewardDebt =
            (user.amount * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        // Interactions
        safeRewardTransfer(to_, _pendingReward);
        user.rewardAccum = 0;

        IRewarder rewarder = _rewarders[pid_];
        if (address(rewarder) != address(0)) {
            rewarder.onReward(
                pid_,
                msg.sender,
                to_,
                _pendingReward,
                user.amount
            );
        }

        _lpTokens[pid_].safeTransfer(to_, amount_);

        if (address(_lpTokens[pid_]) == address(_rewardToken)) {
            _totalRewardStaked -= amount_;
        }

        emit Withdraw(msg.sender, pid_, amount_, to_);
        emit Harvest(msg.sender, pid_, _pendingReward, to_);
    }

    /// @notice Transfer rewards to the receiver
    /// Consider reward token balance in the contract so that it does not overwhelm staked tokens
    function safeRewardTransfer(address to_, uint256 amount_) private {
        if (amount_ > 0) {
            uint256 rewardTokenBalance = _rewardToken.balanceOf(address(this));
            // Note: reward token balance in the contract >= total reward token staked + amount to transfer
            require(
                rewardTokenBalance - _totalRewardStaked >= amount_,
                "Insufficient rewards"
            );
            _rewardToken.safeTransfer(to_, amount_);
        }
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid_ The index of the pool. See `poolInfo`.
    /// @param to_ Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid_, address to_) external {
        UserInfo storage user = _users[pid_][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        _pools[pid_].lpSupply -= amount;

        IRewarder rewarder = _rewarders[pid_];
        if (address(rewarder) != address(0)) {
            rewarder.onReward(pid_, msg.sender, to_, 0, 0);
        }

        // Note: transfer can fail or succeed if `amount` is zero.
        _lpTokens[pid_].safeTransfer(to_, amount);

        if (address(_lpTokens[pid_]) == address(_rewardToken)) {
            _totalRewardStaked -= amount;
        }

        emit EmergencyWithdraw(msg.sender, pid_, amount, to_);
    }
}