// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract StakingPools is AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /**********
     * DATA INTERFACE
     **********/

    // Info of each user.
    struct UserInfo {
        uint256 lastDepositTimestamp;
        uint256 amount; // How many ASSET tokensens the user has provided.
        uint256[] rewardsDebts; // Order like in AssetInfo rewardsTokens
        // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of rewards
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * asset.accumulatedPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws ASSET tokensens to a asset. Here's what happens:
        //   1. The assets `accumulatedPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to the address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each asset.
    struct PoolInfo {
        address assetToken; // Address of LP token contract.
        uint256 lastRewardBlock; // Last block number that Flypes distribution occurs.
        uint256 lastRewardBlockTimestamp; // Last block timestamp that Flypes distribution occurs.        
        uint256[] accumulatedPerShare; // Accumulated token per share, times token decimals. See below.
        address[] rewardsTokens; // Must be constant.
        uint256[] rewardsPerSecond; // Tokens to distribute per second.
        uint256[] rewardsSupply;
        uint256[] accuracy; // Tokens accuracy.
        uint256 poolSupply; // Total amount of deposits by users.
        bool paused;
        uint256 deadline;
        uint256 lockTime;
    }

    /**********
     * STORAGE
     **********/
    
    uint256 public flypeTotalSupply; 
    address public flype;
    /// @notice pid => pool info
    mapping(uint256 => PoolInfo) public poolInfo;
    /// @notice address => pids
    mapping(address => int[]) public deposits;
    /// @notice pid => user address => UserInfo
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @notice user => provided flype
    mapping(address => uint256) public flypePoolInfo;

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount, uint256 amountFlype);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 amountFlype);
    event ClaimRewards(address indexed user, uint256 indexed poolId, address[] tokens, uint256[] amounts);
    event NewPool(uint256 pid, uint256 durationInDays, uint256 lockTime, address assetAddress, address[] rewardsTokens, uint256[] totalRewards, uint[] rewardsPerSecond);

    /**********
     * MODIFIERS
     **********/

    modifier hasPool(uint256 _pid) {
        require(poolExist(_pid), "Flype::staking: pool does not exist");
        _;
    }

    modifier notZeroAddress(address addr){
        require(addr != address(0), "Flype::staking: zero address");
        _;
    }

    modifier poolRunning(uint256 _pid) {
        require(!poolInfo[_pid].paused, "Flype::staking: pool is on pause");
        _;
    }

    /**********
     * ADMIN INTERFACE
     **********/

    function initialize(address _flype) public virtual initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        __ReentrancyGuard_init();
        flype = _flype;
    }

    /// @notice Add staking pool to the chief contract
    /// @param _pid New pool id.
    /// @param _durationInDays Duration of this pool
    /// @param _lockTime Duration between deposit and withdraw
    /// @param _assetAddress Staked token
    /// @param _rewardsTokens Addresses of the reward tokens
    /// @param _totalRewards Amount of rewards distributed to the pool 
    function addPool(
        uint256 _pid,
        uint256 _durationInDays,
        uint256 _lockTime,
        address _assetAddress,
        address[] calldata _rewardsTokens,
        uint256[] calldata _totalRewards
    ) external onlyRole(DEFAULT_ADMIN_ROLE) notZeroAddress(_assetAddress){
        require(!poolExist(_pid), "Flype::staking:addPool: pool exist");
        require(_rewardsTokens.length == _rewardsTokens.length, "Flype::staking:addPool: wrong rewards tokens");
        uint256[] memory _rewardsPerSecond = new uint256[](_rewardsTokens.length);
        for(uint256 i; i < _rewardsTokens.length; i++){
            _rewardsPerSecond[i] = _totalRewards[i] / (1 days * _durationInDays);
            IERC20(_rewardsTokens[i]).safeTransferFrom(_msgSender(), address(this), _totalRewards[i]);
        }
        poolInfo[_pid] = PoolInfo({
            assetToken: _assetAddress,
            lastRewardBlock: block.number,
            lastRewardBlockTimestamp: block.timestamp,
            deadline: block.timestamp + (1 days * _durationInDays),
            accumulatedPerShare: new uint256[](_rewardsTokens.length),
            rewardsTokens: _rewardsTokens,
            accuracy: new uint256[](_rewardsTokens.length),
            rewardsPerSecond: _rewardsPerSecond,
            rewardsSupply: _totalRewards,
            poolSupply: 0,
            lockTime: _lockTime, 
            paused: false
        });
        for (uint256 i = 0; i < _rewardsTokens.length; i++) {
            poolInfo[_pid].accuracy[i] = 10**IERC20Metadata(_rewardsTokens[i]).decimals();
        }
        emit NewPool(_pid, _durationInDays, _lockTime, _assetAddress, _rewardsTokens, _totalRewards, _rewardsPerSecond);
    }

    /// @notice Update rewards distribution speed
    /// @param _pid New pool id.
    /// @param _rewardsPerSecond Amount of rewards distributed to the pool every block
    /// @param _withUpdate Update current rewards before changing the coefficients
    /// @param _deadline New deadline of the pool
    function updatePoolSettings(
        uint256 _pid,
        uint256[] calldata _rewardsPerSecond,
        uint256 _deadline,
        uint256 _locktime,
        bool _withUpdate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) hasPool(_pid) {
        if (_withUpdate) {
            updatePool(_pid);
        }
        require(_deadline > block.timestamp);
        require(poolInfo[_pid].rewardsTokens.length == _rewardsPerSecond.length, "Flype::staking:updatePoolSettings wrong rewards tokens");
        poolInfo[_pid].rewardsPerSecond = _rewardsPerSecond;
        poolInfo[_pid].deadline = _deadline;
        poolInfo[_pid].lockTime = _locktime;
    }

    /// @notice Pauses/unpauses the pool
    /// @param _pid Pool's id
    /// @param _paused True to pause, False to unpause
    function setOnPause(uint256 _pid, bool _paused) external hasPool(_pid) onlyRole(DEFAULT_ADMIN_ROLE) {
        poolInfo[_pid].paused = _paused;
    }

    /// @notice If pool is ended or paused this function transfer rewards to caller
    /// @dev dont use it in pool without updating pools settings
    /// @param _pid Pool's id
    /// @param _amounts Amount of each reward token to transfer 
    function removeRewards(uint256 _pid, uint256[] calldata _amounts) external hasPool(_pid) onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolInfo memory pool = poolInfo[_pid];
        require(pool.paused == true || pool.deadline <= block.timestamp, "Flype::staking:removeRewards: pool is still running");
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            IERC20(pool.rewardsTokens[i]).transfer(_msgSender(), _amounts[i]);
        }
    }

    /**********
     * USER INTERFACE
     **********/

    /// @notice Update reward variables of the given asset to be up-to-date.
    /// @param _pid Pool's id
    function updatePool(uint256 _pid) public hasPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.poolSupply == 0) {
            pool.lastRewardBlock = block.number;
            pool.lastRewardBlockTimestamp = block.timestamp;
            return;
        }
        uint256 time;
        if (block.timestamp <= pool.deadline) time = block.timestamp - pool.lastRewardBlockTimestamp;
        else time = pool.deadline - pool.lastRewardBlockTimestamp;
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            uint256 unaccountedReward = pool.rewardsPerSecond[i] * time;
            pool.accumulatedPerShare[i] += unaccountedReward * pool.accuracy[i] / pool.poolSupply;
        }
        pool.lastRewardBlock = block.number;
       if (block.timestamp <= pool.deadline)  pool.lastRewardBlockTimestamp = block.timestamp;
       else pool.lastRewardBlockTimestamp = pool.deadline;
    }

    /// @notice Deposit (stake) ASSET tokens
    /// @param _pid Pool's id
    /// @param _amount Amount to stake
    /// @param _amountFlype Amount of aditional flype token staked
    function deposit(uint256 _pid, uint256 _amount, uint256 _amountFlype) public virtual nonReentrant hasPool(_pid) poolRunning(_pid) {
        updatePool(_pid);
        require(poolInfo[_pid].deadline >= block.timestamp, "Flype::staking:deposit: staking on this pool is ended");
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        if (user.rewardsDebts.length == 0 && pool.rewardsTokens.length > 0) {
            user.rewardsDebts = new uint256[](pool.rewardsTokens.length);
        }
        if(_amountFlype != 0 && deposits[_msgSender()].length > 0){
            int[] memory _deposits = deposits[_msgSender()];
            for(int i; i <= int(_deposits.length - 1); i++){
                if(_deposits[uint(i)] == int(_pid)) continue;
                _claimRewards(uint(_deposits[uint(i)]), _msgSender());
            }            
        }
        uint256 poolAmountBefore = user.amount;
        uint256 poolAmountFlypeBefore = flypePoolInfo[_msgSender()];
        uint256 flypeTotalSupplyBefore = flypeTotalSupply;
        user.amount += _amount;
        flypePoolInfo[_msgSender()] += _amountFlype;
        flypeTotalSupply += _amountFlype;
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            _updateUserInfo(pool, user, i, poolAmountBefore, poolAmountFlypeBefore, flypeTotalSupplyBefore);
        }
        poolInfo[_pid].poolSupply += _amount;
        user.lastDepositTimestamp = block.timestamp;
        IERC20(pool.assetToken).safeTransferFrom(_msgSender(), address(this), _amount);
        IERC20(flype).safeTransferFrom(_msgSender(), address(this), _amountFlype);
        if(deposits[_msgSender()].length == 0) deposits[_msgSender()].push(int(_pid));
        else{
            for(uint i; i <= deposits[_msgSender()].length - 1; i++){
                if(deposits[_msgSender()][i] == int(_pid)) break;
                else if (i == deposits[_msgSender()].length - 1){
                    deposits[_msgSender()].push(int(_pid));
                }
            }
        }
        emit Deposit(_msgSender(), _pid, _amount, _amountFlype);
    }

    /// @notice Withdraw (unstake) ASSET tokens
    /// @param _pid Pool's id
    /// @param _amount Amount to stake
    /// @param _amountFlype Amount of aditional flype token staked
    function withdraw(uint256 _pid, uint256 _amount, uint256 _amountFlype) public virtual nonReentrant poolRunning(_pid) hasPool(_pid) {
        updatePool(_pid);
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.lastDepositTimestamp + pool.lockTime <= block.timestamp, "Flype::staking:withdraw: wait locktime to withdraw");
        require((user.amount > 0 && user.amount >= _amount) || (flypePoolInfo[_msgSender()] > 0 && flypePoolInfo[_msgSender()] >= _amountFlype), "Flype::staking:withdraw: wrong amount");
        if(_amountFlype != 0 && deposits[_msgSender()].length > 0){
            for(int i; i <= int(deposits[_msgSender()].length - 1); i++){
                if(deposits[_msgSender()][uint(i)] == int(_pid) || deposits[_msgSender()][uint(i)] == -1) continue;
                _claimRewards(uint(deposits[_msgSender()][uint(i)]), _msgSender());
            }
        }
        uint256 poolAmountBefore = user.amount;
        uint256 poolAmountFlypeBefore = flypePoolInfo[_msgSender()];
        uint256 flypeTotalSupplyBefore = flypeTotalSupply;
        user.amount -= _amount;   
        if(_amount == 0){ 
            _claimRewards(_pid, _msgSender());
            flypePoolInfo[_msgSender()] -= _amountFlype;     
            flypeTotalSupply -= _amountFlype;
            IERC20(flype).safeTransfer(_msgSender(), _amountFlype);
        }
        else
        {
            flypePoolInfo[_msgSender()] -= _amountFlype;     
            flypeTotalSupply -= _amountFlype;
            for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
                _updateUserInfo(pool, user, i, poolAmountBefore, poolAmountFlypeBefore, flypeTotalSupplyBefore);
            }
            
            poolInfo[_pid].poolSupply -= _amount;
            IERC20(pool.assetToken).safeTransfer(_msgSender(), _amount);
            if(_amountFlype > 0) IERC20(flype).safeTransfer(_msgSender(), _amountFlype);
        }
        if(user.amount == 0) {
            int[] memory _deposits =  deposits[_msgSender()];
            for(uint i; i <= _deposits.length - 1; i++){
                if(_deposits[i] != int(_pid)) continue;
                deposits[_msgSender()][i] = _deposits[_deposits.length - 1];
                deposits[_msgSender()].pop();
            }
        }
        emit Withdraw(_msgSender(), _pid, _amount, _amountFlype);
    }

    /// @notice Update pool and claim pending rewards for the user
    /// @param _pid Pool's id
    function claimRewards(uint256 _pid) external nonReentrant poolRunning(_pid) {
        require(userInfo[_pid][_msgSender()].amount > 0, "Flype::staking:claimRewards: stake before claiming rewards");
        updatePool(_pid);
        _claimRewards(_pid, _msgSender());
    }

    function _updateUserInfo(
        PoolInfo memory pool,
        UserInfo storage user,
        uint256 _tokenNum,
        uint256 _amount,
        uint256 _amountBonus,
        uint256 _bonusTotalSupply
    ) internal returns (uint256 pending) {
        uint256 accumulatedPerShare = pool.accumulatedPerShare[_tokenNum];
        if (_amount > 0) {
            uint256 reward = ((_amount * accumulatedPerShare) / pool.accuracy[_tokenNum]) - user.rewardsDebts[_tokenNum];
            uint256 baseReward = reward * 75 / 100;
            uint256 holdersReward = 0;
            if (_bonusTotalSupply > 0) holdersReward = (reward - baseReward) * _amountBonus / _bonusTotalSupply ;
            pending = baseReward + holdersReward;
            if (pending > 0) {
                IERC20(pool.rewardsTokens[_tokenNum]).safeTransfer(_msgSender(), pending);
                pool.rewardsSupply[_tokenNum] -= pending;
            }
        }
        user.rewardsDebts[_tokenNum] = (user.amount * accumulatedPerShare) / pool.accuracy[_tokenNum];
    }

    /**********
     * VIEW INTERFACE
     **********/

    /// @notice View function to see pending Flypes on frontend.
    /// @param _pid Pool's id
    /// @param _user Address to check
    /// @return amounts Amounts of reward tokens available to claim
    function pendingRewards(uint256 _pid, address _user) public view hasPool(_pid) notZeroAddress(_user) returns (uint256[] memory amounts) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        amounts = new uint256[](pool.rewardsTokens.length);
        if(user.rewardsDebts.length == 0) return amounts;
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            uint256 accumulatedPerShare = pool.accumulatedPerShare[i];
            if (block.number > pool.lastRewardBlock && pool.poolSupply != 0) {
                uint256 time;
                if (block.timestamp <= pool.deadline) time = block.timestamp - pool.lastRewardBlockTimestamp;
                else time = pool.deadline - pool.lastRewardBlockTimestamp;
                uint256 unaccountedReward = pool.rewardsPerSecond[i] * time;
                accumulatedPerShare = accumulatedPerShare + (unaccountedReward * pool.accuracy[i]) / pool.poolSupply;
            }        
            uint256 reward = user.amount * accumulatedPerShare / pool.accuracy[i] - user.rewardsDebts[i];
            uint256 baseReward = reward * 75 / 100;
            uint256 holdersReward = 0;
            if (flypeTotalSupply > 0) holdersReward = (reward - baseReward) * flypePoolInfo[_user] / flypeTotalSupply;
            amounts[i] = baseReward + holdersReward;
        }
    }

    /// @notice Check if pool exists
    /// @param _pid Pool's id
    /// @return true if pool exists
    function poolExist(uint256 _pid) public view returns (bool) {
        return poolInfo[_pid].assetToken != address(0);
    }

    /// @notice Check the user's staked amount in the pool
    /// @param _pid Pool's id
    /// @param _user Address to check
    /// @return Staked amount
    function userPoolAmount(uint256 _pid, address _user) external notZeroAddress(_user) hasPool(_pid) view returns (uint256) {
        return userInfo[_pid][_user].amount;
    }

    function userRewardsDebts(uint256 _pid, address _user) external notZeroAddress(_user) hasPool(_pid) view returns (uint256[] memory) {
        return userInfo[_pid][_user].rewardsDebts;
    }

    function getAccumulatedPerShare(uint256 _pid) external view  hasPool(_pid) returns(uint256[] memory){
        return poolInfo[_pid].accumulatedPerShare;
    }

    function getRewardsTokens(uint256 _pid) external view  hasPool(_pid) returns(address[] memory){
        return poolInfo[_pid].rewardsTokens;
    }

    function getRewardsPerSecond(uint256 _pid) external view  hasPool(_pid) returns(uint256[] memory){
        return poolInfo[_pid].rewardsPerSecond;
    }

    function getRewardsSupply(uint256 _pid) external view  hasPool(_pid) returns(uint256[] memory){
        return poolInfo[_pid].rewardsSupply;
    }

    function getAccuracy(uint256 _pid) external view  hasPool(_pid) returns(uint256[] memory){
        return poolInfo[_pid].accuracy;
    }

    /**********
     * INTERNAL HELPERS
     **********/

    function _claimRewards(uint256 _pid, address _user) internal {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256[] memory amounts = new uint256[](pool.rewardsTokens.length);
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            amounts[i] = _updateUserInfo(pool, user, i, user.amount, flypePoolInfo[_user], flypeTotalSupply);
        }
        emit ClaimRewards(_user, _pid, pool.rewardsTokens, amounts);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

pragma solidity ^0.8.0;

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
        assembly {
            size := extcodesize(account)
        }
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
// OpenZeppelin Contracts v4.4.0 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/extensions/IERC20Metadata.sol)

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
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (proxy/utils/Initializable.sol)

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
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}