/**
 *Submitted for verification at Etherscan.io on 2022-11-29
*/

// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol

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

// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol

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

// File: contracts/stakingAbbas.sol

// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@****@*%@@@****@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@***********,,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@*@%*****,,,,,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@,,,,,,,,,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@,,,,,,,%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@,,,,,,,.(@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@,,,[email protected]@@@@@@@@@///(@@@@@@@@@@@@@@@@@@%/////@@@@@@@@@@/#@@@@@@@@@
// @@@@@@@@@......,,,,,,,@@@@@@@@@/@@//@@/@/@@@///@*/(/@@/@@@@@//(/@@*/@//@@@@@@@@@
// @@@@@@@@@@.,,,,,,,,,,@@@@@@@@@@/@*/@@&/#&/@@/@@&/(((@@/@@@@@/@@/#@/@@**@@@@@@@@@
// @@@@@@@@@,,,,,,,,,,,,,@@@@@@@@/,@@@(,@**@,@,,@@@@**@@,,@@@@**@@,,@@**@,@@@@@@@@@
// @@@@@@@@@,,,,,,,,,,,,**@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@,,,,,,,******@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@%***********@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@*******#******@@@@@//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

/**
This is RareFnd's official staking contract to be used for all its campaigns.

Website: https://rarefnd.com/
Telegram: https://t.me/RareFnd
*/

pragma solidity 0.8.17;





contract RareStakes is Ownable {
    uint256 private constant YEAR_SECONDS = 365 days;

    IERC20 public mainToken;
    IUniswapV2Router02 public swapRouter;
    // address private constant PCS = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    // address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address private constant PCS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant USDT = 0x4c7fe49745Fc7B60bEA9425c131b33d9dD64822b;

    // Staking record
    struct Record {
        // Date of initial staking
        uint256 origin;
        // Date of last restake
        uint256 from;
        // Amount of RareFnd tokens staked
        uint256 staked;
        // Same, but no rewards to be given out on this amount
        uint256 stakedNoRewards;
        // Total staked in USD
        uint256 stakedUsd;
        // Pending tokens to be claimed
        uint256 pending;
        // Total claimed till now
        uint256 claimed;
        // Timestamp when last claimed
        uint256 lastClaimed;
    }

    uint16 public interestRate;
    uint256 public maturity;
    bool public claimEnabled;
    bool public stakingPostTarget;
    bool public postTargetRewards;
    bool public ended;

    uint256 public totalStaked;

    mapping(address => Record) public ledger;
    address[] public users;

    event StakeStart(address indexed user, uint256 value, uint256 timestamp);
    event Claim(address indexed user, uint256 value, uint256 timestamp);
    event InterestRateChanged(uint256 interestRate);
    event StakingPostTargetChanged(bool status);
    event PostTargetRewardsChanged(bool status);
    event CampaignFailed();

    constructor(
        IERC20 _token,
        uint16 _rate,
        bool _stakingPostTarget,
        bool _postTargetRewards
    ) {
        mainToken = _token;
        interestRate = _rate;
        stakingPostTarget = _stakingPostTarget;
        postTargetRewards = _postTargetRewards;
        swapRouter = IUniswapV2Router02(PCS);
    }

    function stake(uint256 stakeAmount) public {
        require(canStake(), "Staking is currently disabled");
        address staker = msg.sender;
        if (ledger[staker].staked == 0) {
            users.push(staker);
        }
        Record memory existingRecord = ledger[staker];
        bool noRewards = !postTargetRewards && claimEnabled;
        // uint256 usdVal = fndToUsd(stakeAmount);
        uint256 usdVal = stakeAmount;
        if (existingRecord.from > 0) {
            // User has staked before
            ledger[staker] = Record(
                existingRecord.origin,
                block.timestamp,
                existingRecord.staked + (noRewards ? 0 : stakeAmount),
                existingRecord.stakedNoRewards + (noRewards ? stakeAmount : 0),
                existingRecord.stakedUsd + usdVal,
                getUnclaimedGains(staker),
                existingRecord.claimed,
                existingRecord.lastClaimed
            );
        } else {
            ledger[staker] = Record(
                block.timestamp,
                block.timestamp,
                (noRewards ? 0 : stakeAmount),
                (noRewards ? stakeAmount : 0),
                usdVal,
                0,
                0,
                0
            );
        }
        totalStaked += stakeAmount;
        mainToken.transferFrom(staker, address(this), stakeAmount);
        emit StakeStart(staker, stakeAmount, block.timestamp);
    }

    function stakeUsd(uint256 usdAmount) external {
        uint256 stakeAmount = usdToFnd(usdAmount);
        stake(stakeAmount);
    }

    function claim() external {
        address staker = msg.sender;
        require(ledger[staker].from > 0, "No staking record exists");
        require(claimEnabled, "Claiming rewards is not yet enabled");
        uint256 unclaimed = getUnclaimedGains(staker);
        require(unclaimed > 0, "You have no unclaimed gains");

        ledger[staker].claimed += unclaimed;
        ledger[staker].pending = 0;
        ledger[staker].lastClaimed = block.timestamp;

        mainToken.transfer(staker, unclaimed);
        emit Claim(staker, unclaimed, block.timestamp);
    }

    function enableRewards() external onlyOwner {
        require(!claimEnabled, "Rewards are already enabled!");
        claimEnabled = true;
    }

    function disableRewards() external onlyOwner {
        maturity = block.timestamp;
        ended = true;
    }

    function setRate(uint16 _interestRate) public onlyOwner {
        interestRate = _interestRate;
        emit InterestRateChanged(interestRate);
    }

    function setStakingPostTarget(bool _stakingPostTarget) public onlyOwner {
        stakingPostTarget = _stakingPostTarget;
        emit StakingPostTargetChanged(stakingPostTarget);
    }

    function setPostTargetRewards(bool _postTargetRewards) public onlyOwner {
        postTargetRewards = _postTargetRewards;
        emit PostTargetRewardsChanged(postTargetRewards);
    }

    function getUnclaimedGains(address staker) public view returns (uint256) {
        Record memory record = ledger[staker];
        if (record.from == 0) {
            return 0;
        }
        uint256 since;
        if (record.from > record.lastClaimed) {
            since = record.from;
        } else {
            since = record.lastClaimed;
        }

        uint256 baseTime = maturity == 0
            ? block.timestamp
            : (block.timestamp > maturity ? maturity : block.timestamp);
        uint256 timeSinceClaim = 0;
        if (baseTime > since) {
            // In case where the user has claimed after maturity, we need to set this to zero
            // No extra rewards are given out after maturity
            timeSinceClaim = baseTime - since;
        }
        // We do this just in case post-target-hit-rewards were enabled AFTER
        // target was met (and it was initially disabled)
        uint256 stakeAmount = postTargetRewards
            ? (record.staked + record.stakedNoRewards)
            : record.staked;
        return
            (timeSinceClaim * stakeAmount * interestRate) /
            (100 * YEAR_SECONDS) +
            record.pending;
    }

    function getAllGains(address staker) public view returns (uint256) {
        Record memory record = ledger[staker];
        if (record.from == 0) {
            return 0;
        }

        return getUnclaimedGains(staker) + record.claimed;
    }

    function getPendingGains() public view returns (uint256) {
        return getUnclaimedGains(msg.sender);
    }

    function getTotalStaked(address staker) public view returns (uint256) {
        return ledger[staker].staked + ledger[staker].stakedNoRewards;
    }

    function getTotalStakedUsd(address staker) public view returns (uint256) {
        return ledger[staker].stakedUsd;
    }

    function canStake() public view returns (bool) {
        if (stakingPostTarget) {
            return !ended && (maturity == 0 || block.timestamp < maturity);
        }
        return !ended && !claimEnabled;
    }

    function hasExpired() public view returns (bool) {
        return maturity != 0 && block.timestamp >= maturity;
    }

    function getOptions()
        public
        view
        returns (
            uint16,
            uint256,
            uint256,
            uint256,
            bool,
            bool,
            bool,
            bool,
            bool
        )
    {
        return (
            interestRate,
            maturity,
            totalStaked,
            users.length,
            stakingPostTarget,
            postTargetRewards,
            claimEnabled,
            canStake(),
            hasExpired()
        );
    }

    function getUserData()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            getPendingGains(),
            getAllGains(msg.sender),
            getTotalStaked(msg.sender),
            getTotalStakedUsd(msg.sender)
        );
    }

    function myBalance() external view returns (uint256) {
        return mainToken.balanceOf(address(this));
    }

    function withdrawBnb() external onlyOwner {
        uint256 excess = address(this).balance;
        require(excess > 0, "No BNBs to withdraw");
        Address.sendValue(payable(_msgSender()), excess);
    }

    function withdrawNativeTokens(uint256 amount) external onlyOwner {
        if (amount == 0) {
            amount = mainToken.balanceOf(address(this));
        }
        require(amount > 0, "No tokens to withdraw");
        mainToken.transfer(_msgSender(), amount);
    }

    function withdrawOtherTokens(address token, uint256 amount)
        external
        onlyOwner
    {
        require(
            token != address(this),
            "Use the appropriate native token withdraw method"
        );
        if (amount == 0) {
            amount = IERC20(token).balanceOf(address(this));
        }
        require(amount > 0, "No tokens to withdraw");
        IERC20(token).transfer(_msgSender(), amount);
    }

    function campaignFailed() external onlyOwner {
        require(!ended, "This campaign has already ended");
        ended = true;
        for (uint256 i = 0; i < users.length; i++) {
            address staker = users[i];
            Record storage user = ledger[staker];
            uint256 reward = getUnclaimedGains(staker);
            mainToken.transfer(staker, user.staked + reward);
        }
        emit CampaignFailed();
    }

    function setEnded(bool _ended) external onlyOwner {
        // Ideally, should never be called
        // This is more of a debug method
        ended = _ended;
    }

    function setMaturity(uint256 _maturity) external onlyOwner {
        // Ideally, should never be called
        // This is more of a debug method
        maturity = _maturity;
    }

    function fndToUsd(uint256 fndAmount) public view returns (uint256) {
        if (fndAmount == 0) {
            return 0;
        }
        address[] memory path = new address[](3);
        path[0] = address(mainToken);
        path[1] = swapRouter.WETH();
        path[2] = USDT;

        return swapRouter.getAmountsOut(fndAmount, path)[2];
    }

    function usdToFnd(uint256 usdAmount) public view returns (uint256) {
        if (usdAmount == 0) {
            return 0;
        }
        address[] memory path = new address[](3);
        path[0] = USDT;
        path[1] = swapRouter.WETH();
        path[2] = address(mainToken);

        return swapRouter.getAmountsOut(usdAmount, path)[2];
    }
}