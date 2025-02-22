//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/Math.sol';
import './interfaces/IFarmingRewards.sol';
import './interfaces/IWhiteSwapV2Factory.sol';
import './interfaces/ITreasure.sol';
import './FarmingRewards.sol';
import './Treasure.sol';

contract FarmingRewardsFactory is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint8 private constant MAX_COMMISSION = 50;
    uint8 public wsUnlockCommissionPercent;

    address public immutable wsd;
    address public immutable whiteswapV2Factory;
    address public immutable treasure;
    address public timeLock;

    uint256 public lockAmount;
    uint256 public iteratorIdFarmingPools;
    uint256 public constant MIN_STAKING_EXIT_TIME = 1 minutes;
    uint256 public constant MAX_STAKING_EXIT_TIME = 30 days;
    uint256 public constant MIN_EPOCH_DURATION = 1 minutes;

    mapping(uint => FarmingPoolsInfo) public farmingInfo;

    struct FarmingPoolsInfo {
        uint256 id;
        address stakingToken;
        address rewardToken;
        uint256 startDate;
        uint256 endDate;
        uint256 totalReward;
        uint256 epochDuration;
        address farmingPool;
    }

    event FarmingPoolCreated(
        address farmingRewards,
        address rewardToken,
        address stakingToken,
        uint256 rewardAmount,
        uint256 startDate,
        uint256 endDate,
        uint256 epochDuration,
        uint256 minimumStakingExitTime
    );
    //events
    event LockAmountChanged(uint256 amount);
    event WSUnlockCommission(uint8 amount);

    constructor(
        uint8 _wsUnlockCommissionPercent,
        uint256 _lockAmount,
        address _wsd,
        address _timeLock,
        address _whiteswapV2Factory
    ) public {
        require(_lockAmount != 0, 'Lock can not be zero');
        require(_wsd != address(0), 'Wsd can not be zero');
        require(_timeLock != address(0), 'TimeLock can not be zero');
        require(_whiteswapV2Factory != address(0), 'WhiteswapV2Factory can not be zero');
        require(_wsUnlockCommissionPercent <= MAX_COMMISSION, 'Too high percent');

        wsd = _wsd;

        lockAmount = _lockAmount;
        wsUnlockCommissionPercent = _wsUnlockCommissionPercent;

        treasure = address(new Treasure(_wsd, msg.sender, address(this)));
        timeLock = _timeLock;
        transferOwnership(timeLock);
        whiteswapV2Factory = _whiteswapV2Factory;
    }

    function changeLockAmount(uint256 _lockAmount) external onlyOwner returns(bool) {
        require(_lockAmount != 0, 'Can not be zero');
        lockAmount = _lockAmount;

        emit LockAmountChanged(lockAmount);

        return true;
    }

    function changeWsUnlockCommissionPercent(uint8 _wsUnlockCommissionPercent) external onlyOwner returns(bool) {
        require(_wsUnlockCommissionPercent <= MAX_COMMISSION, 'Too high percent');
        wsUnlockCommissionPercent = _wsUnlockCommissionPercent;
        emit WSUnlockCommission(wsUnlockCommissionPercent);

        return true;
    }

    function deploy(
        address stakingToken,
        address rewardToken,
        uint256 startDate,
        uint256 epochDuration,
        uint256 totalReward,
        uint256 minimumStakingExitTime
    ) external {
        require(stakingToken != address(0), 'Staking token can not be zero');
        require(rewardToken != address(0), 'Reward token can not be zero');
        require(totalReward > 0, 'TotalReward can not be zero');
        require(epochDuration >= MIN_EPOCH_DURATION, 'Epoch duration less than min epoch duration');
        require(minimumStakingExitTime >= MIN_STAKING_EXIT_TIME, 'Can not be min staking time less than 14 days');
        require(minimumStakingExitTime <= MAX_STAKING_EXIT_TIME, 'Can not be max staking time greater than 30 days');
        require(totalReward >= epochDuration, 'Total reward must be greater than epoch duration');

        validateLPToken(stakingToken);

        uint256 endDate = startDate.add(epochDuration);

        address farmingReward = address(new FarmingRewards());
        ITreasure(treasure).lock(
            lockAmount,
            startDate,
            epochDuration,
            wsUnlockCommissionPercent,
            farmingReward,
            msg.sender
        );

        FarmingPoolsInfo memory newRewardsInfo;
        iteratorIdFarmingPools++;

        newRewardsInfo.id = iteratorIdFarmingPools;
        newRewardsInfo.stakingToken = stakingToken;
        newRewardsInfo.rewardToken = rewardToken;
        newRewardsInfo.startDate = startDate;
        newRewardsInfo.endDate = endDate;
        newRewardsInfo.totalReward = totalReward;
        newRewardsInfo.epochDuration = epochDuration;
        newRewardsInfo.farmingPool = farmingReward;

        farmingInfo[iteratorIdFarmingPools] = newRewardsInfo;

        IERC20(rewardToken).transferFrom(msg.sender, address(farmingReward), totalReward);

        IFarmingRewards(farmingReward).initialize(
            msg.sender,
            rewardToken,
            stakingToken,
            totalReward,
            startDate,
            endDate,
            epochDuration,
            minimumStakingExitTime
        );

        emit FarmingPoolCreated(
            address(farmingReward),
            rewardToken,
            stakingToken,
            totalReward,
            startDate,
            endDate,
            epochDuration,
            minimumStakingExitTime
        );
    }

    function validateLPToken(address lpToken) internal view {
        uint256 pairLength = IWhiteSwapV2Factory(whiteswapV2Factory).allPairsLength();
        bool isWSLPToken = false;

        for(uint256 i = 0; i < pairLength; i++) {
            address pair = IWhiteSwapV2Factory(whiteswapV2Factory).allPairs(i);

            if (pair == lpToken) {
                isWSLPToken = true;
                break;
            }
        }

        require(isWSLPToken, 'Not valid LP token');
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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

// SPDX-License-Identifier: MIT

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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
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

// SPDX-License-Identifier: MIT

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

//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

import './interfaces/IFarmingRewards.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract FarmingRewards is ReentrancyGuard, IFarmingRewards, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool private initialized;
    uint256 private lastUpdateTime;
    uint256 private rewardPerTokenStored;
    IERC20 public rewardToken;
    IERC20 public stakingToken;
    uint256 public rewardAmount;
    uint256 private _totalSupply;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public epochDuration;
    uint256 public minimumStakingExitTime;
    uint256 public rewardRate;
    uint256 public currentCountAccounts;
    uint256 public distributedTokens;

    //account start farm => amount
    mapping(address => uint) public accountStartFarm;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;
    mapping(address => uint) public _balances;
    // in case when account withdraw his staking token

    //address => id
    mapping(address => uint) public accountIdByAddress;
    //id => address
    mapping(uint256 => address) public accountAddressById;

    event FarmingPoolInfo(
        address indexed farmingPool,
        address stakingToken,
        address rewardToken,
        uint256 startDate,
        uint256 endDate,
        uint256 baseReward,
        uint256 epochDuration,
        uint256 minimumStakingExitTime
    );

    event Stake(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Reward(address indexed user, uint256 reward);
    event OwnerWithdrawFunds(address indexed owner, uint256 reward);
    event UpdatedRewardForEpoch(address indexed owner, uint256 reward);

    modifier updateReward(address account) {
        require(account != address(0), 'Can not be zero address');

        _updateRewardForEpoch(account);
        _;
    }

    modifier earlyStakingExit(address account) {
        uint256 unstakeAvailableDate = accountStartFarm[account].add(minimumStakingExitTime);
        require(
            block.timestamp > unstakeAvailableDate ||
            unstakeAvailableDate > endDate ||
            block.timestamp < startDate,
            'Fail unstake earlier then it available'
        );
        _;
    }

    function initialize (
        address owner,
        address _rewardToken,
        address _stakingToken,
        uint256 _rewardAmount,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _epochDuration,
        uint256 _minimumStakingExitTime
    ) external override returns (bool) {
        require(!initialized, 'Contract already initialized.');
        require(_rewardToken != _stakingToken, 'Staking and reward tokens can not be the same.');
        rewardToken = IERC20(_rewardToken);
        stakingToken = IERC20(_stakingToken);

        createEpoch(_startDate, _endDate, _rewardAmount, _epochDuration, _minimumStakingExitTime);

        initialized = true;
        transferOwnership(owner);

        uint256 balanceOf = IERC20(rewardToken).balanceOf(address(this));
        require(balanceOf == rewardAmount, 'Invalid amount');

        return true;
    }

    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }

    function balanceOfStakingToken(address account) external override view returns (uint) {
        return _balances[account];
    }

    function getActiveAccountCount() external view returns (uint) {
        uint256 count;

        for(uint256 i = 1; i <= currentCountAccounts; i++) {
            if (accountAddressById[i] != address(0)) {
                count = count + 1;
            }
        }

        return count;
    }

    function earned(address account) external override view returns (uint256) {
        return _earned(account);
    }

    function getRewardForDuration() external override view returns (uint256) {
        return rewardRate.mul(endDate.sub(startDate));
    }

    function farm(uint256 amount) nonReentrant updateReward(msg.sender) external override {
        require(amount > 0, 'Cannot farm 0');
        require(block.timestamp < endDate, 'Farming pool already finished');

        if (accountIdByAddress[msg.sender] == 0) {
            currentCountAccounts = currentCountAccounts + 1;
            accountIdByAddress[msg.sender] = currentCountAccounts;
            accountAddressById[currentCountAccounts] = msg.sender;
        }

        if (block.timestamp >= startDate) {
            accountStartFarm[msg.sender] = block.timestamp;
        } else {
            accountStartFarm[msg.sender] = startDate;
        }

        accountStartFarm[msg.sender] = block.timestamp;
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Stake(msg.sender, amount);
    }

    function exit() override external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function withdrawFunds(uint256 startId, uint256 endId) external onlyOwner {
        require(block.timestamp > endDate, 'Not available while farming pool is active');

        uint256 remainingBalanceOnContract = rewardToken.balanceOf(address(this));
        require(remainingBalanceOnContract > 0, 'Not available to withdraw zero');

        uint256 balanceToWithdraw = getRemainingRewardsForOwner(startId, endId);

        rewardToken.safeTransfer(owner(), balanceToWithdraw);

        emit OwnerWithdrawFunds(
            msg.sender,
            balanceToWithdraw
        );
    }

    function lastTimeRewardApplicable() external override view returns (uint) {
        return _lastTimeRewardApplicable();
    }

    function rewardPerToken() external override view returns (uint) {
        return _rewardPerToken();
    }

    function getRemainingRewardsForOwner(uint256 startId, uint256 endId) public view returns(uint256) {
        uint256 remainingBalanceOnContract = rewardToken.balanceOf(address(this));

        if (block.timestamp < endDate) {
            return 0;
        }

        uint256 totalEarned;
        address accountAddress;

        for (uint256 i = startId; i <= endId; i ++) {
            accountAddress = accountAddressById[i];

            if (accountAddress != address(0)) {
                totalEarned = totalEarned.add(_earned(accountAddressById[i]));
            }
        }

        return remainingBalanceOnContract.sub(totalEarned);
    }

    function withdraw(uint256 amount) override public earlyStakingExit(msg.sender) nonReentrant updateReward(msg.sender) {
        if (_balances[msg.sender] > 0) {
            _totalSupply = _totalSupply.sub(amount);
            _balances[msg.sender] = _balances[msg.sender].sub(amount);

            if (_balances[msg.sender] == 0) {
                accountStartFarm[msg.sender] = 0;
                accountAddressById[accountIdByAddress[msg.sender]] = address(0);
                accountIdByAddress[msg.sender] = 0;
            }

            stakingToken.safeTransfer(msg.sender, amount);

            emit Withdrawn(msg.sender, amount);
        }
    }

    function getReward() override public nonReentrant updateReward(msg.sender) {
        if (rewards[msg.sender] > 0) {
            uint256 reward = rewards[msg.sender];
            rewards[msg.sender] = 0;
            uint256 totalRewardDistributed;
            rewardAmount = rewardAmount.sub(reward);
            rewardToken.safeTransfer(msg.sender, reward);
            totalRewardDistributed = totalRewardDistributed.add(reward);

            distributedTokens = distributedTokens.add(totalRewardDistributed);
            emit Reward(msg.sender, reward);
        }
    }

    function _updateRewardForEpoch(address account) internal {
        rewardPerTokenStored = _rewardPerToken();
        lastUpdateTime = _lastTimeRewardApplicable();

        rewards[account] = _earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;

        emit UpdatedRewardForEpoch(account, rewards[account]);
    }

    function _lastTimeRewardApplicable() internal view returns (uint) {
        if (block.timestamp < startDate) {
            return 0;
        }
        return Math.min(block.timestamp, endDate);
    }

    function _rewardPerToken() internal view returns (uint) {
        if (block.timestamp < startDate) {
            return 0;
        }
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(
            _lastTimeRewardApplicable()
            .sub(lastUpdateTime)
            .mul(rewardRate)
            .mul(1e18)
            .div(_totalSupply)
        );
    }

    function _earned(address account) internal view returns (uint256) {
        return _balances[account]
        .mul(_rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
    }

    function createEpoch(
        uint256 _startDate,
        uint256 _endDate,
        uint256 _rewardAmount,
        uint256 _epochDuration,
        uint256 _minimumStakingExitTime
    ) internal {
        require(_startDate >= block.timestamp, 'Provided start date too early');
        require(_endDate > _startDate, 'Wrong end date epoch');
        require(_rewardAmount > 0, 'Wrong reward amount');
        require(_minimumStakingExitTime < _endDate.sub(_startDate), 'Wrong stake time');

        startDate = _startDate;
        endDate = _endDate;
        rewardAmount = _rewardAmount;
        epochDuration = _epochDuration;
        minimumStakingExitTime = _minimumStakingExitTime;
        rewardRate = rewardAmount.div(epochDuration);

        emit FarmingPoolInfo(
            address(this),
            address(stakingToken),
            address(rewardToken),
            startDate,
            endDate,
            rewardAmount,
            epochDuration,
            minimumStakingExitTime
        );
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

interface IFarmingRewards {

    function initialize(
        address owner,
        address rewardsToken,
        address stakingToken,
        uint256 rewardAmount,
        uint256 startDate,
        uint256 finishDate,
        uint256 epochDuration,
        uint256 _minimumStakingExitTime
    ) external returns (bool);
    // Views
    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOfStakingToken(address account) external view returns (uint);

    function farm(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function exit() external;
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

interface ITreasure {
    function lock(
        uint256 lockAmount,
        uint256 farmingStart,
        uint256 duration,
        uint8 fee,
        address farmingPool,
        address account
    ) external;

    function unlock(address farmingPool) external;

    function getStartFarmingPoolDate(address account, address farmingPool) external view returns(uint256);

    function getUnlockDate(address account, address farmingPool) external view returns(uint256);

    function getLockDuration(address account, address farmingPool) external view returns(uint256);

    function getLockFee(address account, address farmingPool) external view returns(uint256);

    function getContribution(address account, address farmingPool) external view returns(uint256);

    function getIsDistributedLockedFunds(address account, address farmingPool) external view returns(bool);

    function changeFeeRecipient(address _feeRecipient) external;
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

interface IWhiteSwapV2Factory {
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

import './interfaces/ITreasure.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

contract Treasure is ITreasure, Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint32 private constant ONE_YEAR = 360;
    uint8 private constant MAX_COMMISSION = 50;
    uint256 public totalLocked;
    address public immutable wsd;
    address public immutable farmingRewardFactory;
    address public feeRecipient;
    //account address => contract address => locked amount
    mapping(address => mapping(address => uint256)) private contributions;
    //account address => contract address => fee percent amount
    mapping(address => mapping(address => uint8)) private lockFee;
    //account address => contract address => timestamp lock duration
    mapping(address => mapping(address => uint256)) private lockDuration;
    //account address => contract address => timestamp startFarmingPool
    mapping(address => mapping(address => uint256)) private startFarmingPool;
    //account address => contract address => timestamp finish
    mapping(address => mapping(address => uint256)) private finishFarmingPool;
    mapping(address => mapping(address => bool)) private isDistributedLockedFunds;
    mapping(address => bool) public isAlreadyLockedContract;

    event FundsLocked(address indexed account, uint256 value);
    event FundsUnlocked(address indexed account, uint256 value);
    event FeeRecipientChanged(address indexed feeRecipient);

    constructor(address _wsd, address _feeRecipient, address _farmingRewardFactory) public {
        require(_wsd != address(0), 'Token can not be zero address');
        require(_farmingRewardFactory != address(0), 'Factory can not be zero address');
        require(_feeRecipient != address(0), 'FeeRecipient Can not be zero address');

        wsd = _wsd;
        farmingRewardFactory = _farmingRewardFactory;
        transferOwnership(_feeRecipient);

        feeRecipient = _feeRecipient;
        emit FeeRecipientChanged(feeRecipient);
    }

    function changeFeeRecipient(address _feeRecipient) public onlyOwner override {
        require(_feeRecipient != address(0), 'Fee recipient can not be zero address');

        feeRecipient = _feeRecipient;

        emit FeeRecipientChanged(feeRecipient);
    }

    function getUnlockDate(address account, address farmingPool) external view override returns(uint) {
        return finishFarmingPool[account][farmingPool];
    }

    function getStartFarmingPoolDate(address account, address farmingPool) external view override returns(uint) {
        return startFarmingPool[account][farmingPool];
    }

    function getLockDuration(address account, address farmingPool) external view override returns(uint) {
        return lockDuration[account][farmingPool];
    }

    function getLockFee(address account, address farmingPool) external view override returns(uint) {
        return lockFee[account][farmingPool];
    }

    function getContribution(address account, address farmingPool) external view override returns(uint) {
        return contributions[account][farmingPool];
    }

    function getIsDistributedLockedFunds(address account, address farmingPool) external view override returns(bool) {
        return isDistributedLockedFunds[account][farmingPool];
    }

    function lock(
        uint256 lockAmount,
        uint256 farmingStart,
        uint256 duration,
        uint8 fee,
        address farmingPool,
        address account
    ) external override {
        require(msg.sender == farmingRewardFactory, 'Allowed only for factory');
        require(duration > 0, 'Can not be zero duration');
        require(fee <= MAX_COMMISSION, 'Too high fee');
        require(!isAlreadyLockedContract[farmingPool], 'Already locked');
        require(farmingStart >= block.timestamp, 'Can not be in past');
        uint256 endDate;
        uint256 lockDurationModifier;

        contributions[account][farmingPool] = lockAmount;
        lockFee[account][farmingPool] = fee;

        startFarmingPool[account][farmingPool] = farmingStart;
        totalLocked = totalLocked.add(lockAmount);

        if (duration >= ONE_YEAR) {
            endDate = farmingStart.add(duration);
            lockDurationModifier = duration;
        } else {
            endDate = farmingStart.add(ONE_YEAR);
            lockDurationModifier = ONE_YEAR;
        }

        lockDuration[account][farmingPool] = lockDurationModifier;
        isDistributedLockedFunds[account][farmingPool] = false;
        isAlreadyLockedContract[farmingPool] = true;
        finishFarmingPool[account][farmingPool] = endDate;

        IERC20(wsd).safeTransferFrom(account, address(this), lockAmount);

        emit FundsLocked(account, lockAmount);
    }

    function unlock(address farmingPool) external override {
        require(!isDistributedLockedFunds[msg.sender][farmingPool], 'Already distributed');
        require(contributions[msg.sender][farmingPool] > 0, 'Not contributed');
        uint256 lockAmount = contributions[msg.sender][farmingPool];
        uint256 fee = lockFee[msg.sender][farmingPool];
        uint256 farmingPoolDuration = finishFarmingPool[msg.sender][farmingPool];

        require(farmingPoolDuration <= block.timestamp, 'Finish date is not reached');

        totalLocked = totalLocked.sub(lockAmount);
        contributions[msg.sender][farmingPool] = 0;
        lockDuration[msg.sender][farmingPool] = 0;
        lockFee[msg.sender][farmingPool] = 0;
        startFarmingPool[msg.sender][farmingPool] = 0;
        isDistributedLockedFunds[msg.sender][farmingPool] = true;
        uint256 unlockAmount;

        if (fee > 0) {
            uint256 wsFeeAmount = lockAmount.mul(fee).div(100);
            unlockAmount = lockAmount.sub(wsFeeAmount);
            IERC20(wsd).safeTransfer(feeRecipient, wsFeeAmount);
        } else {
            unlockAmount = lockAmount;
        }

        IERC20(wsd).safeTransfer(msg.sender, unlockAmount);

        emit FundsUnlocked(msg.sender, lockAmount);
    }
}