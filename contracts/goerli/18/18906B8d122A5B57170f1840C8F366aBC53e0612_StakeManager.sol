pragma solidity 0.7.6;
// SPDX-License-Identifier: GPL-3.0-only

import {SafeERC20, IERC20, SafeMath} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../balancer-metastable-rate-providers/interfaces/IRateProvider.sol";
import "./Types.sol";
import "./IStakePool.sol";
import "./IERC20MintBurn.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract StakeManager is IRateProvider {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant UNBOND_TIMES_LIMIT = 100;

    address public admin;
    address public delegationBalancer;
    address public rTokenAddress;
    address public erc20TokenAddress;
    uint256 public minStakeAmount;
    uint256 public unstakeFeeCommission; // decimals 18
    uint256 public protocolFeeCommission; // decimals 18
    uint256 public rateChangeLimit; // decimals 18
    uint256 public eraSeconds;
    uint256 public eraOffset;
    uint256 public unbondingDuration;

    uint256 public latestEra;
    uint256 private rate; // decimals 18
    uint256 public totalRTokenSupply;
    uint256 public totalProtocolFee;

    EnumerableSet.AddressSet bondedPools;
    mapping(address => PoolInfo) public poolInfoOf;
    mapping(address => EnumerableSet.UintSet) validatorIdsOf;
    mapping(address => mapping(uint256 => uint256)) public maxClaimedNonceOf; // pool => validator Id => max claimed nonce
    mapping(uint256 => uint256) public eraRate;

    // unstake info
    uint256 public nextUnstakeIndex;
    mapping(uint256 => UnstakeInfo) public unstakeAtIndex;
    mapping(address => EnumerableSet.UintSet) unstakesOfUser;

    // events
    event Stake(address staker, address poolAddress, uint256 tokenAmount, uint256 rTokenAmount);
    event Unstake(
        address staker,
        address poolAddress,
        uint256 tokenAmount,
        uint256 rTokenAmount,
        uint256 burnAmount,
        uint256 unstakeIndex
    );
    event Withdraw(address staker, address poolAddress, uint256 tokenAmount, int256[] unstakeIndexList);
    event ExecuteNewEra(uint256 indexed era, uint256 rate);
    event SetUnbondingDuration(uint256 unbondingDuration);
    event Delegate(address pool, uint256 validator, uint256 amount);
    event Undelegate(address pool, uint256 validator, uint256 amount);
    event NewReward(address pool, uint256 amount);
    event NewClaimedNonce(address pool, uint256 validator, uint256 nonce);

    // init
    function init(address _rTokenAddress, address _erc20TokenAddress, uint256 _unbondingDuration) public {
        require(admin == address(0), "already init");

        admin = msg.sender;
        delegationBalancer = msg.sender;
        rTokenAddress = _rTokenAddress;
        erc20TokenAddress = _erc20TokenAddress;
        unbondingDuration = _unbondingDuration;

        minStakeAmount = 1e12;
        rateChangeLimit = 1e15;
        unstakeFeeCommission = 2e15;
        protocolFeeCommission = 1e17;
        eraSeconds = 86400;
        eraOffset = 16845;
    }

    // modifer
    modifier onlyAdmin() {
        require(admin == msg.sender, "caller is not admin");
        _;
    }

    modifier onlyDelegationBalancer() {
        require(delegationBalancer == msg.sender, "caller is not delegation balancer");
        _;
    }

    // ----- getters

    function getRate() external view override returns (uint256) {
        return rate;
    }

    function getBondedPools() public view returns (address[] memory pools) {
        pools = new address[](bondedPools.length());
        for (uint256 i = 0; i < bondedPools.length(); ++i) {
            pools[i] = bondedPools.at(i);
        }
        return pools;
    }

    function getValidatorIdsOf(address _poolAddress) public view returns (uint256[] memory validatorIds) {
        validatorIds = new uint256[](validatorIdsOf[_poolAddress].length());
        for (uint256 i = 0; i < validatorIdsOf[_poolAddress].length(); ++i) {
            validatorIds[i] = validatorIdsOf[_poolAddress].at(i);
        }
        return validatorIds;
    }

    function getUnstakeIndexListOf(address _staker) external view returns (uint256[] memory unstakeIndexList) {
        unstakeIndexList = new uint256[](unstakesOfUser[_staker].length());
        for (uint256 i = 0; i < unstakesOfUser[_staker].length(); ++i) {
            unstakeIndexList[i] = unstakesOfUser[_staker].at(i);
        }
        return unstakeIndexList;
    }

    function currentEra() public view returns (uint256) {
        return block.timestamp.div(eraSeconds).sub(eraOffset);
    }

    // ------ settings

    function migrate(
        address _poolAddress,
        uint256 _validatorId,
        uint256 _govDelegated,
        uint256 _bond,
        uint256 _unbond,
        uint256 _rate,
        uint256 _totalRTokenSupply,
        uint256 _totalProtocolFee,
        uint256 _era
    ) external onlyAdmin {
        require(rate == 0, "already migrate");
        require(bondedPools.add(_poolAddress), "already exist");

        validatorIdsOf[_poolAddress].add(_validatorId);
        poolInfoOf[_poolAddress] = PoolInfo({bond: _bond, unbond: _unbond, active: _govDelegated});
        rate = _rate;
        totalRTokenSupply = _totalRTokenSupply;
        totalProtocolFee = _totalProtocolFee;
        latestEra = _era;
        eraRate[_era] = _rate;
    }

    function transferAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "zero address");
        admin = _newAdmin;
    }

    function transferDelegationBalancer(address _newDelegationBalancer) public onlyAdmin {
        require(_newDelegationBalancer != address(0), "zero address");
        delegationBalancer = _newDelegationBalancer;
    }

    function setParams(
        uint256 _unstakeFeeCommission,
        uint256 _protocolFeeCommission,
        uint256 _minStakeAmount,
        uint256 _unbondingDuration,
        uint256 _rateChangeLimit,
        uint256 _eraSeconds,
        uint256 _eraOffset
    ) external onlyAdmin {
        unstakeFeeCommission = _unstakeFeeCommission == 1 ? unstakeFeeCommission : _unstakeFeeCommission;
        protocolFeeCommission = _protocolFeeCommission == 1 ? protocolFeeCommission : _protocolFeeCommission;
        minStakeAmount = _minStakeAmount == 0 ? minStakeAmount : _minStakeAmount;
        rateChangeLimit = _rateChangeLimit == 0 ? rateChangeLimit : _rateChangeLimit;
        eraSeconds = _eraSeconds == 0 ? eraSeconds : _eraSeconds;
        eraOffset = _eraOffset == 0 ? eraOffset : _eraOffset;

        if (_unbondingDuration > 0) {
            unbondingDuration = _unbondingDuration;
            emit SetUnbondingDuration(_unbondingDuration);
        }
    }

    function addStakePool(address _poolAddress) external onlyAdmin {
        require(bondedPools.add(_poolAddress), "pool exist");
    }

    function rmStakePool(address _poolAddress) external onlyAdmin {
        PoolInfo memory poolInfo = poolInfoOf[_poolAddress];
        require(poolInfo.active == 0 && poolInfo.bond == 0 && poolInfo.unbond == 0, "pool not empty");

        uint256[] memory validators = getValidatorIdsOf(_poolAddress);
        for (uint256 j = 0; j < validators.length; ++j) {
            require(IStakePool(_poolAddress).getTotalStakeOnValidator(validators[j]) == 0, "delegate not empty");

            validatorIdsOf[_poolAddress].remove(validators[j]);
        }

        require(bondedPools.remove(_poolAddress), "pool not exist");
    }

    function approve(address _poolAddress, uint256 _amount) external onlyAdmin {
        IStakePool(_poolAddress).approveForStakeManager(erc20TokenAddress, _amount);
    }

    function withdrawProtocolFee(address _to) external onlyAdmin {
        IERC20(rTokenAddress).safeTransfer(_to, IERC20(rTokenAddress).balanceOf(address(this)));
    }

    // ------ delegation balancer

    function redelegate(
        address _poolAddress,
        uint256 _srcValidatorId,
        uint256 _dstValidatorId,
        uint256 _amount
    ) external onlyDelegationBalancer {
        require(validatorIdsOf[_poolAddress].contains(_srcValidatorId), "val not exist");
        require(_srcValidatorId != _dstValidatorId, "val duplicate");
        require(_amount > 0, "amount zero");

        if (!validatorIdsOf[_poolAddress].contains(_dstValidatorId)) {
            validatorIdsOf[_poolAddress].add(_dstValidatorId);
        }

        IStakePool(_poolAddress).redelegate(_srcValidatorId, _dstValidatorId, _amount);

        if (IStakePool(_poolAddress).getTotalStakeOnValidator(_srcValidatorId) == 0) {
            validatorIdsOf[_poolAddress].remove(_srcValidatorId);
        }
    }

    // ----- staker operation

    function stake(uint256 _stakeAmount) external {
        stakeWithPool(bondedPools.at(0), _stakeAmount);
    }

    function unstake(uint256 _rTokenAmount) external {
        unstakeWithPool(bondedPools.at(0), _rTokenAmount);
    }

    function withdraw() external {
        withdrawWithPool(bondedPools.at(0));
    }

    function stakeWithPool(address _poolAddress, uint256 _stakeAmount) public {
        require(_stakeAmount >= minStakeAmount, "amount not enough");
        require(bondedPools.contains(_poolAddress), "pool not exist");

        uint256 rTokenAmount = _stakeAmount.mul(1e18).div(rate);

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.bond = poolInfo.bond.add(_stakeAmount);
        poolInfo.active = poolInfo.active.add(_stakeAmount);

        // transfer erc20 token
        IERC20(erc20TokenAddress).safeTransferFrom(msg.sender, _poolAddress, _stakeAmount);

        // mint rtoken
        totalRTokenSupply = totalRTokenSupply.add(rTokenAmount);
        IERC20MintBurn(rTokenAddress).mint(msg.sender, rTokenAmount);

        emit Stake(msg.sender, _poolAddress, _stakeAmount, rTokenAmount);
    }

    function unstakeWithPool(address _poolAddress, uint256 _rTokenAmount) public {
        require(_rTokenAmount > 0, "rtoken amount zero");
        require(bondedPools.contains(_poolAddress), "pool not exist");
        require(unstakesOfUser[msg.sender].length() <= UNBOND_TIMES_LIMIT, "unstake times limit");

        uint256 unstakeFee = _rTokenAmount.mul(unstakeFeeCommission).div(1e18);
        uint256 leftRTokenAmount = _rTokenAmount.sub(unstakeFee);
        uint256 tokenAmount = leftRTokenAmount.mul(rate).div(1e18);

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.unbond = poolInfo.unbond.add(tokenAmount);
        poolInfo.active = poolInfo.active.sub(tokenAmount);

        // burn rtoken
        IERC20MintBurn(rTokenAddress).burnFrom(msg.sender, leftRTokenAmount);
        totalRTokenSupply = totalRTokenSupply.sub(leftRTokenAmount);

        // protocol fee
        totalProtocolFee = totalProtocolFee.add(unstakeFee);
        IERC20(rTokenAddress).safeTransferFrom(msg.sender, address(this), unstakeFee);

        // unstake info
        uint256 willUseUnstakeIndex = nextUnstakeIndex;
        nextUnstakeIndex = willUseUnstakeIndex.add(1);

        unstakeAtIndex[willUseUnstakeIndex] = UnstakeInfo({
            era: currentEra(),
            pool: _poolAddress,
            receiver: msg.sender,
            amount: tokenAmount
        });
        unstakesOfUser[msg.sender].add(willUseUnstakeIndex);

        emit Unstake(msg.sender, _poolAddress, tokenAmount, _rTokenAmount, leftRTokenAmount, willUseUnstakeIndex);
    }

    function withdrawWithPool(address _poolAddress) public {
        uint256 totalWithdrawAmount;
        uint256 length = unstakesOfUser[msg.sender].length();
        uint256[] memory unstakeIndexList = new uint256[](length);
        int256[] memory emitUnstakeIndexList = new int256[](length);

        for (uint256 i = 0; i < length; ++i) {
            unstakeIndexList[i] = unstakesOfUser[msg.sender].at(i);
        }
        uint256 curEra = currentEra();
        for (uint256 i = 0; i < length; ++i) {
            uint256 unstakeIndex = unstakeIndexList[i];
            UnstakeInfo memory unstakeInfo = unstakeAtIndex[unstakeIndex];
            if (unstakeInfo.era.add(unbondingDuration) > curEra || unstakeInfo.pool != _poolAddress) {
                emitUnstakeIndexList[i] = -1;
                continue;
            }

            require(unstakesOfUser[msg.sender].remove(unstakeIndex), "already withdrawed");

            totalWithdrawAmount = totalWithdrawAmount.add(unstakeInfo.amount);
            emitUnstakeIndexList[i] = int256(unstakeIndex);
        }

        if (totalWithdrawAmount > 0) {
            IStakePool(_poolAddress).withdrawForStaker(erc20TokenAddress, msg.sender, totalWithdrawAmount);
        }

        emit Withdraw(msg.sender, _poolAddress, totalWithdrawAmount, emitUnstakeIndexList);
    }

    // ----- permissionless

    function newEra() external {
        uint256 _era = latestEra.add(1);
        require(currentEra() >= _era, "calEra not match");

        // update era
        latestEra = _era;

        uint256 totalNewReward;
        uint256 newTotalActive;
        address[] memory poolList = getBondedPools();
        for (uint256 i = 0; i < poolList.length; ++i) {
            address poolAddress = poolList[i];

            uint256[] memory validators = getValidatorIdsOf(poolAddress);

            // newReward
            uint256 poolNewReward = IStakePool(poolAddress).checkAndWithdrawRewards(validators);
            emit NewReward(poolAddress, poolNewReward);
            totalNewReward = totalNewReward.add(poolNewReward);

            // unstakeClaimTokens
            for (uint256 j = 0; j < validators.length; ++j) {
                uint256 oldClaimedNonce = maxClaimedNonceOf[poolAddress][validators[j]];
                uint256 newClaimedNonce = IStakePool(poolAddress).unstakeClaimTokens(validators[j], oldClaimedNonce);
                if (newClaimedNonce > oldClaimedNonce) {
                    maxClaimedNonceOf[poolAddress][validators[j]] = newClaimedNonce;

                    emit NewClaimedNonce(poolAddress, validators[j], newClaimedNonce);
                }
            }

            // bond or unbond
            PoolInfo memory poolInfo = poolInfoOf[poolAddress];
            uint256 poolBondAndNewReward = poolInfo.bond.add(poolNewReward);
            if (poolBondAndNewReward > poolInfo.unbond) {
                uint256 needDelegate = poolBondAndNewReward.sub(poolInfo.unbond);
                IStakePool(poolAddress).delegate(validators[0], needDelegate);

                emit Delegate(poolAddress, validators[0], needDelegate);
            } else if (poolBondAndNewReward < poolInfo.unbond) {
                uint256 needUndelegate = poolInfo.unbond.sub(poolBondAndNewReward);

                for (uint256 j = 0; j < validators.length; ++j) {
                    if (needUndelegate == 0) {
                        break;
                    }
                    uint256 totalStaked = IStakePool(poolAddress).getTotalStakeOnValidator(validators[j]);

                    uint256 unbondAmount;
                    if (needUndelegate < totalStaked) {
                        unbondAmount = needUndelegate;
                        needUndelegate = 0;
                    } else {
                        unbondAmount = totalStaked;
                        needUndelegate = needUndelegate.sub(totalStaked);
                    }

                    if (unbondAmount > 0) {
                        IStakePool(poolAddress).undelegate(validators[j], unbondAmount);

                        emit Undelegate(poolAddress, validators[j], unbondAmount);
                    }
                }
                require(needUndelegate == 0, "undelegate not enough");
            }

            // cal total active
            uint256 newPoolActive = IStakePool(poolAddress).getTotalStakeOnValidators(validators);
            newTotalActive = newTotalActive.add(newPoolActive);

            // update pool state
            poolInfo.active = newPoolActive;
            poolInfo.bond = 0;
            poolInfo.unbond = 0;

            poolInfoOf[poolAddress] = poolInfo;
        }

        // cal protocol fee
        if (totalNewReward > 0) {
            uint256 rTokenProtocolFee = totalNewReward.mul(protocolFeeCommission).div(rate);
            totalProtocolFee = totalProtocolFee.add(rTokenProtocolFee);

            // mint rtoken
            totalRTokenSupply = totalRTokenSupply.add(rTokenProtocolFee);
            IERC20MintBurn(rTokenAddress).mint(address(this), rTokenProtocolFee);
        }

        // update rate
        uint256 newRate = newTotalActive.mul(1e18).div(totalRTokenSupply);
        uint256 rateChange = newRate > rate ? newRate.sub(rate) : rate.sub(newRate);
        require(rateChange.mul(1e18).div(rate) < rateChangeLimit, "rate change over limit");

        rate = newRate;
        eraRate[_era] = newRate;

        emit ExecuteNewEra(_era, newRate);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

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

pragma solidity ^0.7.0;

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

pragma solidity ^0.7.0;

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

pragma solidity ^0.7.0;

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

pragma solidity ^0.7.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.6;

// TODO: pull this from the monorepo
interface IRateProvider {
    function getRate() external view returns (uint256);
}

pragma solidity 0.7.6;

// SPDX-License-Identifier: GPL-3.0-only

interface IERC20MintBurn {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

pragma solidity 0.7.6;

// SPDX-License-Identifier: GPL-3.0-only

interface IStakePool {
    function checkAndWithdrawRewards(uint256[] calldata validator) external returns (uint256 reward);

    function delegate(uint256 validator, uint256 amount) external returns (uint256 amountToDeposit);

    function undelegate(uint256 validator, uint256 claimAmount) external;

    function redelegate(uint256 fromValidatorId, uint256 toValidatorId, uint256 amount) external;

    function unstakeClaimTokens(uint256 validator, uint256 claimedNonce) external returns (uint256);

    function withdrawForStaker(address erc20TokenAddress, address staker, uint256 amount) external;

    function approveForStakeManager(address erc20TokenAddress, uint256 amount) external;

    function getTotalStakeOnValidator(uint256 validator) external view returns (uint256);

    function getTotalStakeOnValidators(uint256[] calldata validator) external view returns (uint256);
}

pragma solidity 0.7.6;
// SPDX-License-Identifier: GPL-3.0-only

struct PoolInfo {
    uint256 bond;
    uint256 unbond;
    uint256 active;
}

struct UnstakeInfo {
    uint256 era;
    address pool;
    address receiver;
    uint256 amount;
}