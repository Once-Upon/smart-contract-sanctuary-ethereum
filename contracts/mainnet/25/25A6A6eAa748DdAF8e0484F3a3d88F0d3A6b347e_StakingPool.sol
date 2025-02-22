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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

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
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
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

pragma solidity =0.8.17;

interface IAffiliateProgram {
    function hasAffiliate(address _addr) external view returns (bool result);

    function countReferrals(address _addr) external view returns (uint256 amount);

    function getAffiliate(address _addr) external view returns (address account);

    function getReferrals(address _addr) external view returns (address[] memory results);
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFungibleToken is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenStorage {
    function charge(uint256 _amount) external;

    function charge(address _to, uint256 _amount) external;

    function allowance(address _spender) external view returns (uint256 balance);

    function getBalance() external view returns (uint256 balance);

    function token() external view returns (IERC20);
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IFungibleToken.sol";
import "./interfaces/IAffiliateProgram.sol";
import "./interfaces/ITokenStorage.sol";

// @title StakingPool - staking contract simplified MasterChef.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once XXX is sufficiently
// distributed and the community can show to govern itself.
//
// Please disable mining in two steps first remove MINTER_ROLE rights, then through
// some time set multiplier value 0.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract StakingPool is Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IFungibleToken;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lockedTo; // Amount locked to.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 stakingToken; // Address of LP token contract.
        uint256 lastRewardBlock; // Last block number that XXXes distribution occurs.
        uint256 accTokensPerShare; // Accumulated XXXes per share, times 1e12. See below.
        uint256 totalDeposited; // Total deposited tokens amount.
    }
    // Initialization storage.
    bool internal _initialized;
    // The XXX TOKEN!
    IFungibleToken public rewardToken;
    // Reward token storage.
    address public mintFromWallet;
    // XXX tokens created per block.
    uint256 public tokensPerBlock;
    // Bonus muliplier for early rewardToken makers.
    uint256 public rewardMultiplier;
    // The block number when XXX mining starts.
    uint256 public startBlock;
    // Deposit locked for that time.
    uint256 public lockPeriod;
    //
    uint256 public timeLockEnabled;
    // Affiliate percent, added to referral reward.
    uint256 public affiliatePercent;
    // Affiliate program.
    address public affiliateProgram;
    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event MintError(string);
    event MintToAffiliateError(string);
    event TokenPerBlockSet(uint256 amount);
    event RewardMultiplierSet(uint256 multiplier);
    event LockPeriodSet(uint256 secs);
    event AffiliateReward(address affiliate, uint256 reward);
    event AffiliatePercentSet(uint256 value);
    event AffiliateProgramSet(address addr);
    event MintWalletSet(address addr);

    function initialize(
        IFungibleToken _depositToken,
        IFungibleToken _rewardToken,
        address _mintFromWallet,
        address _admin,
        uint256 _tokensPerBlock,
        uint256 _startBlock
    ) public {
        require(!_initialized, "Initialized");
        require(
            address(_depositToken) != address(0) && address(_depositToken) == address(_rewardToken),
            "Staking: constructor deposit token"
        );

        _initialized = true;
        _transferOwnership(_admin);

        rewardToken = _rewardToken;
        tokensPerBlock = _tokensPerBlock;
        startBlock = _startBlock;

        if (_mintFromWallet != address(0)) {
            require(_rewardToken == ITokenStorage(_mintFromWallet).token(), "Reward token");
            mintFromWallet = _mintFromWallet;
        }

        rewardMultiplier = 1;

        // staking pool
        poolInfo = PoolInfo({
            stakingToken: _depositToken,
            lastRewardBlock: startBlock,
            accTokensPerShare: 0,
            totalDeposited: 0
        });
    }

    /**
     * @dev Set tokens per block. Zero set disable mining.
     */
    function setTokensPerBlock(uint256 _amount) external onlyOwner {
        updatePool();
        tokensPerBlock = _amount;
        emit TokenPerBlockSet(_amount);
    }

    /**
     * @dev Set reward multiplier. Zero set disable mining.
     */
    function setRewardMultiplier(uint256 _multiplier) external onlyOwner {
        updatePool();
        rewardMultiplier = _multiplier;
        emit RewardMultiplierSet(_multiplier);
    }

    /**
     * @dev Set lock period.
     */
    function setLockPeriod(uint256 _seconds) external onlyOwner {
        lockPeriod = _seconds;
        emit LockPeriodSet(_seconds);
    }

    /**
     * @dev Set affiliate percent period.
     */
    function setAffiliatePercent(uint256 _percent) external onlyOwner {
        affiliatePercent = _percent;
        emit AffiliatePercentSet(_percent);
    }

    /**
     * @dev Set lock period.
     */
    function setAffiliateProgram(address _addr) external onlyOwner {
        affiliateProgram = _addr;
        emit AffiliateProgramSet(_addr);
    }

    /**
     * @dev Set mint wallet. address(0) - disable feature
     */
    function setMintWallet(address _addr) external onlyOwner {
        if (_addr != address(0)) {
            require(rewardToken == ITokenStorage(_addr).token(), "Reward token");
            mintFromWallet = _addr;
        }
        emit MintWalletSet(_addr);
    }

    /**
     * @dev Deposit token.
     *      Send `_amount` as 0 for claim effect.
     */
    function deposit(uint256 _amount) external {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        if (user.lockedTo != 0 && user.lockedTo > block.timestamp) {
            require(_amount != 0, "Cannot claim during lock period");
        }
        updatePool();
        if (user.amount > 0 && user.lockedTo < block.timestamp) {
            uint256 pending = ((user.amount * pool.accTokensPerShare) / 1e12) - user.rewardDebt;
            if (pending > 0) {
                _safeTransfer(msg.sender, pending);
                _mintAffiliateReward(msg.sender, pending);
            }
        }
        if (_amount != 0) {
            pool.stakingToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount + _amount;
            user.lockedTo = block.timestamp + lockPeriod;
            pool.totalDeposited += _amount;
        }
        user.rewardDebt = (user.amount * pool.accTokensPerShare) / 1e12;
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @dev Withdraw tokens with reward.
     */
    function withdraw(uint256 _amount) external {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Withdraw insufficient balance");
        require(user.lockedTo < block.timestamp, "Cannot withdraw during lock period");
        updatePool();
        uint256 pending = ((user.amount * pool.accTokensPerShare) / 1e12) - user.rewardDebt;
        if (pending > 0) {
            _safeTransfer(msg.sender, pending);
            _mintAffiliateReward(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.totalDeposited -= _amount;
            pool.stakingToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = (user.amount * pool.accTokensPerShare) / 1e12;
        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @dev Withdraw without caring about rewards. EMERGENCY ONLY. ONLY OWNER.
     */
    function emergencyWithdraw(address _account) external onlyOwner {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_account];
        pool.totalDeposited -= user.amount;
        pool.stakingToken.safeTransfer(_account, user.amount);
        emit EmergencyWithdraw(_account, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        user.lockedTo = 0;
    }

    /**
     * @dev View function to see pending XXXes on frontend.
     */
    function pendingReward(address _user) external view returns (uint256 reward) {
        PoolInfo memory pool = poolInfo;
        UserInfo memory user = userInfo[_user];
        uint256 accTokensPerShare = pool.accTokensPerShare;
        uint256 lpSupply = pool.totalDeposited;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier * tokensPerBlock;
            accTokensPerShare = accTokensPerShare + ((tokenReward * 1e12) / lpSupply);
        }
        reward = (user.amount * accTokensPerShare) / 1e12 - user.rewardDebt;
    }

    /**
     * @dev View function to see available XXXes on frontend.
     */
    function availableReward(address _user) external view returns (uint256 reward) {
        PoolInfo memory pool = poolInfo;
        UserInfo memory user = userInfo[_user];
        uint256 accTokensPerShare = pool.accTokensPerShare;
        uint256 lpSupply = pool.totalDeposited;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier * tokensPerBlock;
            accTokensPerShare = accTokensPerShare + ((tokenReward * 1e12) / lpSupply);
        }
        if (user.lockedTo < block.timestamp) {
            reward = (user.amount * accTokensPerShare) / 1e12 - user.rewardDebt;
        }
    }

    /**
     * @dev Update reward variables of the given pool to be up-to-date.
     */
    function updatePool() public {
        PoolInfo storage pool = poolInfo;
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.totalDeposited;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier * tokensPerBlock;
        if (tokenReward == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        if (mintFromWallet != address(0)) {
            try ITokenStorage(mintFromWallet).charge(address(this), tokenReward) {
                //
            } catch Error(string memory reason) {
                emit MintError(reason);
            }
        } else {
            try rewardToken.mint(address(this), tokenReward) {
                //
            } catch Error(string memory reason) {
                emit MintError(reason);
            }
        }

        pool.accTokensPerShare = pool.accTokensPerShare + ((tokenReward * 1e12) / lpSupply);
        pool.lastRewardBlock = block.number;
    }

    /**
     * @dev Return reward multiplier over the given _from to _to block.
     */
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256 multiplier) {
        multiplier = (_to - _from) * rewardMultiplier;
    }

    function _mintAffiliateReward(address _user, uint256 _pendingReward) internal {
        if (affiliateProgram == address(0)) {
            return;
        }
        address affiliate = IAffiliateProgram(affiliateProgram).getAffiliate(_user);
        if (affiliate != address(0)) {
            _pendingReward = (_pendingReward * affiliatePercent) / 100;
            if (mintFromWallet != address(0)) {
                try ITokenStorage(mintFromWallet).charge(affiliate, _pendingReward) {
                    //
                } catch Error(string memory reason) {
                    emit MintToAffiliateError(reason);
                }
            } else {
                try rewardToken.mint(affiliate, _pendingReward) {
                    //
                } catch Error(string memory reason) {
                    emit MintToAffiliateError(reason);
                }
            }
        }
    }

    /**
     * @dev Safe rewardToken transfer function, just in case
     * if rounding error causes pool to not have enough XXXes.
     */
    function _safeTransfer(address _to, uint256 _amount) internal {
        uint256 xxxBalance = rewardToken.balanceOf(address(this)) - poolInfo.totalDeposited;
        if (_amount > xxxBalance) {
            rewardToken.safeTransfer(_to, xxxBalance);
        } else {
            rewardToken.safeTransfer(_to, _amount);
        }
    }
}