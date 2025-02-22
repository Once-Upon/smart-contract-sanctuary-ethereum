// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../utils/math/SortedList.sol";
import "../utils/math/Percent.sol";
import "../utils/DynamicArray.sol";

import "../SomaGuard/utils/GuardableUpgradeable.sol";
import "../SecurityTokens/ERC20/utils/SafeERC20Balance.sol";
import "../Lockdrop/TokenRecoveryUpgradeable.sol";

import "./SomaStakingLibrary.sol";
import "./ISomaStaking.sol";

contract SomaStaking is ISomaStaking, ReentrancyGuardUpgradeable, TokenRecoveryUpgradeable, GuardableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Balance for IERC20;
    using SafeERC20 for IERC20;
    using SortedList for SortedList.AscendingList;
    using Percent for uint256;
    using SafeCastUpgradeable for uint256;

    bytes32 public constant override GLOBAL_ADMIN_ROLE = keccak256('Staking.GLOBAL_ADMIN_ROLE');
    bytes32 public override LOCAL_ADMIN_ROLE;

    /* Amount of staked tokens globally */
    uint256         private _totalStaked;
    uint256         private _totalPendingUnstake;
    address         private _stakingToken;
    uint256         private _currentRequestId;
    StakingConfig   private _config;

    mapping(address => uint256)         private _tps;
    mapping(address => UserInfo)        private _users;
    mapping(address => uint256)         private _adminClaimable;
    mapping(uint256 => Request)    private _requests;

    SortedList.AscendingList                private _pendingStrategies;
    EnumerableSetUpgradeable.AddressSet     private _rewardTokens;
    Strategy[]                              private _strategies;

    constructor(address somaAddress)
    GuardableUpgradeable(somaAddress) {}

    modifier onlyAdmin() {
        address _sender = _msgSender();
        require(hasRole(GLOBAL_ADMIN_ROLE, _sender) || hasRole(LOCAL_ADMIN_ROLE, _sender), 'Staking: ADMIN_ONLY'); // TODO errors should be Staking or SomaStaking
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(GuardableUpgradeable, TokenRecoveryUpgradeable) returns (bool) {
        return interfaceId == type(ISomaStaking).interfaceId || super.supportsInterface(interfaceId);
    }

    function config() external override view returns (StakingConfig memory) {
        return _config;
    }

    function totalStaked() external override view returns (uint256) {
        return _totalStaked;
    }

    function totalPendingUnstake() external override view returns (uint256) {
        return _totalPendingUnstake;
    }

    function strategy(uint256 id) external override view returns (Strategy memory) {
        return _strategies[id];
    }

    function totalStrategies() external override view returns (uint256) {
        return _strategies.length;
    }

    function stakingToken() external override view returns (address) {
        return _stakingToken;
    }

    function rewardToken(uint256 index) external override view returns (address) {
        return _rewardTokens.at(index);
    }

    function totalRewardTokens() external override view returns (uint256) {
        return _rewardTokens.length();
    }

    function pendingStrategy(uint256 index) external override view returns (Strategy memory) {
        (bytes32 id,) = _pendingStrategies.at(index);
        return _strategies[uint256(id)];
    }

    function totalPendingStrategies() external override view returns (uint256) {
        return _pendingStrategies.length();
    }

    function tps(address _asset) external override view returns (uint256) {
        return _tps[_asset];
    }

    function adminClaimable(address _asset) external override view returns (uint256) {
        require(_rewardTokens.contains(_asset), 'Staking: INVALID_ASSET');
        // add the extra rewards if there are currently no stakers
        return _adminClaimable[_asset] + (_totalStaked == 0 ? _rewardsUnlocked(_asset) : 0);
    }

    function debt(address _account, address _asset) external override view returns (uint256) {
        require(_rewardTokens.contains(_asset), 'Staking: INVALID_ASSET');
        return SomaStakingLibrary.stakeToRewards(_users[_account].stake, currentTPS(_asset));
    }

    function claimable(address _account, address _asset) external override view returns (uint256) {
        UserInfo storage _user = _users[_account];
        require(_rewardTokens.contains(_asset), 'Staking: INVALID_ASSET');
        return _user.claimable[_asset] +
            SomaStakingLibrary.stakeToRewards(_user.stake, currentTPS(_asset)) -
            _user.debt[_asset];
    }

    function claimRequest(address _account, address _asset, uint256 _id) external override view returns (Request memory) {
        require(_rewardTokens.contains(_asset), 'Staking: INVALID_ASSET');
        return _getRequest(_id, _asset, _account);
    }

    function stakeOf(address _account) external override view returns (uint256) {
        return _users[_account].stake;
    }

    function unstakeRequest(address _account, uint256 _id) external override view returns (Request memory) {
        return _getRequest(_id, _stakingToken, _account);
    }

    function initialize(address stakingToken_, address[] memory rewardTokens_) external override initializer {
        LOCAL_ADMIN_ROLE = keccak256(abi.encodePacked(address(this), GLOBAL_ADMIN_ROLE));

        _stakingToken = stakingToken_;
        for (uint256 i = 0; i < rewardTokens_.length; ++i) {
            address _token = rewardTokens_[i];
            require(_token != address(0), 'Staking: INVALID_ASSET');
            _rewardTokens.add(_token);
            _disableTokenRecovery(_token);
        }

        __Guardable__init();
    }

    function currentTPS(address token) public override view returns (uint256 tps_) {
        uint256 totalStaked_ = _totalStaked;
        uint256 extraTPS = (totalStaked_ > 0) ? SomaStakingLibrary.rewardsToTPS(_totalStaked, _rewardsUnlocked(token)) : 0;
        return _tps[token] + extraTPS;
    }

    function createUnstakeRequest(uint256 _amount) external override nonReentrant returns (uint256 _id){
        address _sender = _msgSender();
        UserInfo storage _user = _users[_sender];
        uint256 _userStake = _user.stake;
        uint256 totalStake_ = _totalStaked;

        require(_userStake >= _amount, "Staking: INSUFFICIENT_STAKE");
        require(_amount > 0, "Staking: INVALID_AMOUNT");

        _update(totalStake_);
        // remove this amount from the users stake amount, so that they no longer earn rewards on
        _syncUser(_user, _userStake, _userStake - _amount);

        // adjust the total stake balances
        unchecked {
            _totalStaked = totalStake_ - _amount;
            _totalPendingUnstake += _amount;
        }

        return _createRequest(_sender, _stakingToken, _amount);
    }

    function cancelUnstakeRequests(uint256[] calldata _ids) external override nonReentrant {
        address _sender = _msgSender();
        UserInfo storage _user = _users[_sender];
        uint256 _userStake = _user.stake;
        uint256 totalStake_ = _totalStaked;

        require(_ids.length > 0, 'Staking: INVALID_IDS_LENGTH');
        address stakingToken_ = _stakingToken;
        uint256 _totalAmount = _userStake;
        for (uint i = 0; i < _ids.length; ++i) {
            unchecked {
                _totalAmount += _cancelRequest(_ids[i], stakingToken_, _sender);
            }
        }

        _update(totalStake_);
        _syncUser(_user, _userStake, _userStake + _totalAmount);

        unchecked {
            _totalStaked = totalStake_ + _totalAmount;
            _totalPendingUnstake -= _totalAmount;
        }
    }

    function createClaimRequests(address[] calldata _assets) external override nonReentrant returns (uint256[] memory _ids) {
        address _sender = _msgSender();
        UserInfo storage _user = _users[_sender];
        uint256 _userStake = _user.stake;

        _ids = new uint256[](_assets.length);

        _update(_totalStaked);
        _syncUser(_user, _userStake, _userStake);

        for (uint i = 0; i < _assets.length; ++i) {
            address _asset = _assets[i];
            uint256 _rewards = _user.claimable[_asset];

            require(_rewardTokens.contains(_asset), 'Staking: INVALID_ASSET');
            require(_rewards > 0, 'Staking: NO_REWARDS');

            delete _user.claimable[_asset];

            _ids[i] = _createRequest(_sender, _asset, _rewards);
        }
    }

    function cancelClaimRequests(address[] calldata _assets, uint256[][] calldata _ids) external override nonReentrant {
        address _sender = _msgSender();
        UserInfo storage _user = _users[_sender];

        require(_assets.length > 0, 'Staking: INVALID_ASSETS_LENGTH');
        require(_ids.length == _assets.length, 'Staking: INVALID_INPUT_LENGTHS');

        for (uint i = 0; i < _assets.length; ++i) {
            uint256 _idsLength = _ids[i].length;
            address _asset = _assets[i];
            uint256 _totalAmount;

            require(_idsLength > 0, 'Staking: INVALID_IDS_LENGTH');
            for (uint j = 0; j < _idsLength; ++j) {
                unchecked {
                    _totalAmount += _cancelRequest(_ids[i][j], _asset, _sender);
                }
            }

            unchecked {
                _user.claimable[_asset] += _totalAmount;
            }
        }
    }

    function claim(address[] calldata _assets, uint256[][] calldata _ids) external override nonReentrant {
        address _sender = _msgSender();
        uint256 _claimDuration = _config.claimDuration;

        require(_assets.length == _ids.length, 'Staking: INVALID_INPUT_LENGTHS');

        for (uint i = 0; i < _assets.length; ++i) {
            uint256 _idsLength = _ids[i].length;
            address _asset = _assets[i];
            uint256 _totalAmount;

            require(_idsLength > 0, 'Staking: INVALID_IDS_LENGTH');
            for (uint j = 0; j < _idsLength; ++j) {
                unchecked {
                    _totalAmount += _useRequest(_ids[i][j], _asset, _sender, _claimDuration);
                }
            }

            IERC20(_asset).safeTransfer(_sender, _totalAmount);

            emit Claimed(_asset, _totalAmount, _sender);
        }
    }

    function claimImmediate(address[] calldata _assets, uint256[] calldata _amounts) external override nonReentrant {
        require(_assets.length == _amounts.length, 'Staking: INCONSISTENT_LENGTHS');

        address _sender = _msgSender();
        UserInfo storage _user = _users[_sender];
        StakingConfig memory config_ = _config;

        uint256 _userStake = _user.stake;
        _update(_totalStaked);
        _syncUser(_user, _userStake, _userStake);

        for (uint i = 0; i < _assets.length; ++i) {
            _claimImmediate(
                _user,
                config_.earlyClaimFee,
                _sender,
                _assets[i],
                _amounts[i]
            );
        }
    }

    function stake(uint256 _amount) external override nonReentrant {
        address _sender = _msgSender();
        UserInfo storage _user = _users[_sender];
        uint256 _userStake = _user.stake;
        uint256 totalStake_ = _totalStaked;

        // slither-disable-next-line reentrancy-no-eth
        _amount = SafeERC20Balance.safeTransferFrom(
            IERC20(_stakingToken),
            _sender,
            address(this),
            _amount
        );

        require(_amount > 0, "SomaStaking: INVALID_AMOUNT");

        _update(totalStake_);
        _syncUser(_user, _userStake, _userStake + _amount);
        _totalStaked = totalStake_ + _amount;

        emit Staked(_amount, _sender);
    }

    // TODO should this have an input amount?
    function adminClaim(address _asset, address _to) external override onlyAdmin nonReentrant {
        _update(_totalStaked);
        uint256 _claimable = _adminClaimable[_asset];
        require(_claimable > 0, "Staking: INSUFFICIENT_CLAIMABLE");
        delete _adminClaimable[_asset];
        IERC20(_asset).safeTransfer(_to, _claimable);
        emit AdminClaimed(_asset, _claimable, _to, _msgSender());
    }

    function unstake(uint256[] calldata _ids) external override nonReentrant {
        address _sender = _msgSender();
        address stakingToken_ = _stakingToken;
        uint256 _unstakeDuration = _config.unstakeDuration;

        uint256 _totalAmount;
        for (uint i = 0; i < _ids.length; ++i) {
            unchecked {
                _totalAmount += _useRequest(_ids[i], stakingToken_, _sender, _unstakeDuration);
            }
        }

        unchecked {
            _totalPendingUnstake -= _totalAmount;
        }

        IERC20(_stakingToken).safeTransfer(_sender, _totalAmount);

        emit Unstaked(_totalAmount, _sender);
    }

    function unstakeImmediate(uint256 _amount) external override nonReentrant {
        address _sender = _msgSender();
        UserInfo storage _user = _users[_sender];
        uint256 _userStake = _user.stake;
        uint256 totalStake_ = _totalStaked;

        StakingConfig memory config_ = _config;

        require(_userStake >= _amount, "Staking: INSUFFICIENT_STAKE");
        require(_amount > 0, "Staking: INVALID_AMOUNT");

        _update(totalStake_);
        _syncUser(_user, _userStake, _userStake - _amount);

        unchecked {
            _totalStaked = totalStake_ - _amount;
        }
        uint256 _adminFee = _amount.applyPercent(config_.earlyUnstakeFee);

        address _asset = _stakingToken;
        _adminClaimable[_asset] += _adminFee;
        IERC20(_asset).safeTransfer(_sender, _amount - _adminFee);

        emit UnstakedImmediate(_amount, _adminFee, _msgSender());
    }

    function addRewardToken(address _asset) external override onlyAdmin nonReentrant {
        _rewardTokens.add(_asset);
        emit RewardTokenAdded(_asset, _msgSender());
    }

    function createStrategy(
        uint256 _startDate,
        uint256 _endDate,
        address _rewardToken,
        uint256 _rewardAmount
    ) external override onlyAdmin nonReentrant {
        require(_startDate > block.timestamp, 'SomaStaking: INVALID_START_DATE');
        require(_startDate < _endDate, 'SomaStaking: INVALID_DATE_ORDER');
        require(_rewardTokens.contains(_rewardToken), 'SomaStaking: INVALID_TOKEN');
        require(_endDate <= type(uint48).max, 'SomaStaking: INVALID_END_DATE');

        // slither-disable-next-line reentrancy-no-eth
        _rewardAmount = SafeERC20Balance.safeTransferFrom(
            IERC20(_rewardToken),
            _msgSender(),
            address(this),
            _rewardAmount
        );

        require(_rewardAmount > 0, 'SomaStaking: INVALID_AMOUNT');

        uint256 strategyId = _strategies.length;
        Strategy memory _strategy = Strategy({
            startDate: uint48(_startDate),
            endDate: uint48(_endDate),
            rewardsLocked: _rewardAmount.toUint128(),
            rewardToken: _rewardToken,
            rewardsUnlocked: 0
        });

        _strategies.push(_strategy);

        _pendingStrategies.add(bytes32(strategyId), _startDate);

        emit StrategyCreated(_rewardToken, _strategy.rewardsLocked, _startDate, _endDate, _msgSender());
    }

    function updateConfig(
        uint64 _unstakeDuration,
        uint64 _claimDuration,
        uint16 _earlyUnstakeFee,
        uint16 _earlyClaimFee
    ) external override onlyAdmin {
        StakingConfig memory config_ = StakingConfig({
            unstakeDuration: _unstakeDuration,
            claimDuration: _claimDuration,
            earlyUnstakeFee: _earlyUnstakeFee,
            earlyClaimFee: _earlyClaimFee
        });
        emit StakingConfigUpdated(_config, config_, _msgSender());
        _config = config_;
    }

    function _update(uint256 totalStake_) private {
        uint256 curId = _pendingStrategies.head();
        uint256 nextId;
        bytes32 key;

        // slither-disable-next-line weak-prng
        uint48 curTimestamp = uint48(block.timestamp % type(uint48).max);

        while (curId != 0) {
            (key, nextId) = _pendingStrategies.get(curId);
            Strategy memory _strategy = _strategies[uint256(key)];
            if (curTimestamp < _strategy.startDate) {
                break;
            }

            uint256 rewardsUnlocked = SomaStakingLibrary.rewardsUnlocked(_strategy, block.timestamp);

            // increment how many rewards have been released
            _strategies[uint256(key)].rewardsUnlocked = rewardsUnlocked.toUint128() + _strategy.rewardsUnlocked;
            // if there is nobody staking, lets go ahead and return the rewards earned to the admin
            if (totalStake_ > 0) {
                _tps[_strategy.rewardToken] += SomaStakingLibrary.rewardsToTPS(totalStake_, rewardsUnlocked);
            } else {
                _adminClaimable[_strategy.rewardToken] += rewardsUnlocked;
            }

            // if this strategy has been completed then let us remove it from the pending list
            if (curTimestamp >= _strategy.endDate) {
                _pendingStrategies.remove(curId);
            }

            // progress to the next item in the list
            curId = nextId;
        }
    }

    function _syncUser(UserInfo storage _user, uint256 _userStake, uint256 _newUserStake) private {
        if (_newUserStake != _userStake) _user.stake = _newUserStake;
        if (_userStake == 0) return;

        // sync the claimable and debt values
        uint256 _totalTokens = _rewardTokens.length();
        for (uint i = 0; i < _totalTokens; ++i) {
            address _rewardToken = _rewardTokens.at(i);
            uint256 tps_ = _tps[_rewardToken];
            _user.claimable[_rewardToken] += SomaStakingLibrary.stakeToRewards(_userStake, tps_) - _user.debt[_rewardToken];
            _user.debt[_rewardToken] = SomaStakingLibrary.stakeToRewards(_newUserStake, tps_);
        }
    }

    function _claimImmediate(
        UserInfo storage _user,
        uint256 _earlyClaimFee,
        address _sender,
        address _asset,
        uint256 _amount
    ) private {
        require(_rewardTokens.contains(_asset), "Staking: INVALID_ASSET");

        uint256 _claimable = _user.claimable[_asset];

        require(_amount > 0, 'Staking: INVALID_AMOUNT');
        require(_claimable > 0, "Staking: NO_REWARDS");
        require(_amount <= _claimable, 'Staking: INSUFFICIENT_CLAIMABLE');

        uint256 _adminFee = _amount.applyPercent(_earlyClaimFee);

        _adminClaimable[_asset] += _adminFee;
        IERC20(_asset).safeTransfer(_sender, _amount - _adminFee);

        unchecked {
            _user.claimable[_asset] = _claimable - _amount;
        }

        emit ClaimedImmediate(_asset, _amount, _adminFee, _sender);
    }

    function _rewardsUnlocked(address token) private view returns (uint256 _totalUnlocked) {
        bytes32 key;
        uint256 curId = _pendingStrategies.head();

        while (curId != 0) {
            (key, curId) = _pendingStrategies.get(curId);
            Strategy memory _strategy = _strategies[uint256(key)];
            if (block.timestamp < _strategy.startDate) break;
            if (_strategy.rewardToken == token) _totalUnlocked += SomaStakingLibrary.rewardsUnlocked(_strategy, block.timestamp);
        }
    }

    function _createRequest(address _sender, address _asset, uint256 _amount) private returns (uint256 _id) {
        require(_amount > 0, 'Staking: INVALID_AMOUNT');

        _id = ++_currentRequestId;
        _requests[_id] = Request({
            hash: bytes8(keccak256(abi.encodePacked(_id, _sender, _asset))),
            timestamp: block.timestamp.toUint64(),
            amount: _amount.toUint128()
        });

        emit RequestCreated(_id, _asset, _amount, _sender);
    }

    function _getRequest(uint256 _id, address _asset, address _sender) private view returns (Request memory _request) {
        bytes8 _hash = bytes8(keccak256(abi.encodePacked(_id, _sender, _asset)));
        _request = _requests[_id];
        require(_request.hash == _hash, 'Staking: INVALID_REQUEST');
    }

    function _useRequest(uint256 _id, address _asset, address _sender, uint256 _requiredDuration) private returns (uint256 _amount) {
        Request memory _request = _getRequest(_id, _asset, _sender);

        require(block.timestamp - _request.timestamp >= _requiredDuration, "Staking: INSUFFICIENT_TIME");

        delete _requests[_id];
        emit RequestFulfilled(_id);

        return _request.amount;
    }

    function _cancelRequest(uint256 _id, address _asset, address _sender) private returns (uint256 _amount) {
        _amount = _getRequest(_id, _asset, _sender).amount;
        delete _requests[_id];
        emit RequestCancelled(_id);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeCast.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCastUpgradeable {
    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

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
library EnumerableSetUpgradeable {
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
        mapping(bytes32 => uint256) _indexes;
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

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

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
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

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

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library SortedList {

    struct ListItemDetails {
        bool exists;
        uint64 id;
        uint64 nextId;
        uint64 prevId;
    }

    struct ListItem {
        ListItemDetails details;
        uint256 value;
    }

    struct ListDetails {
        uint64 head;
        uint64 tail;
        uint64 current;
        uint64 length;
    }

    struct AscendingList {
        ListDetails __details;
        mapping(uint256 => ListItem) __items;
        mapping(uint256 => bytes32) __keys;
    }

    function head(AscendingList storage list) internal view returns (uint256 id) {
        return list.__details.head;
    }

    function tail(AscendingList storage list) internal view returns (uint256 id) {
        return list.__details.tail;
    }

    function get(AscendingList storage list, uint256 id) internal view returns (bytes32 key, uint256 nextId) {
        require(list.__items[id].details.exists, 'SortedList: INVALID_ID');
        key = list.__keys[id];
        nextId = list.__items[id].details.nextId;
    }

    function exists(AscendingList storage list, uint256 id) internal view returns (bool) {
        return list.__items[id].details.exists;
    }

    function length(AscendingList storage list) internal view returns (uint256) {
        return list.__details.length;
    }

    function at(AscendingList storage list, uint256 index) internal view returns (bytes32 key, uint256 curId) {
        ListDetails memory details = list.__details;
        require(index < details.length, 'SortedList: OUT_OF_BOUNDS');

        curId = details.head;
        for (uint i = 0; i < index; ++i) {
            curId = list.__items[curId].details.nextId;
        }
        key = list.__keys[curId];
    }

    function add(AscendingList storage list, bytes32 key, uint256 value) internal {
        ListDetails memory details = list.__details;

        // when it hits the end loop back around to the beginning
        uint64 id;
        unchecked {
            id = details.current + 1;
        }

        ListItemDetails memory itemDetails = list.__items[id].details;

        // we want to override the previous values if they exist
        if (itemDetails.exists) _remove(list, id);

        ListItem memory nextItem;
        ListItem memory prevItem;
        uint64 curId = details.head;
        while (curId != 0) {
            ListItem memory curListItem = list.__items[curId];
            // sort until we find first value that is larger.
            // then this item should go on the right. so it is ascending
            if (curListItem.value > value) {
                nextItem = curListItem;
                break;
            }

            prevItem = curListItem;
            curId = curListItem.details.nextId;
        }

        list.__details = ListDetails({
            length: details.length + 1,
            head: nextItem.details.id == details.head ? id : details.head,
            tail: prevItem.details.id == details.tail ? id : details.tail,
            current: id
        });
        list.__keys[id] = key;
        list.__items[id] = ListItem({
            value: value,
            details: ListItemDetails({
                exists: true,
                id: id,
                prevId: prevItem.details.id,
                nextId: nextItem.details.id
            })
        });

        if (prevItem.details.exists) {
            prevItem.details.nextId = id;
            list.__items[prevItem.details.id].details = prevItem.details;
        }
        if (nextItem.details.exists) {
            nextItem.details.prevId = id;
            list.__items[nextItem.details.id].details = nextItem.details;
        }
    }

    function remove(AscendingList storage list, uint256 id) internal returns (bytes32 key) {
        return _remove(list, id);
    }

    function _remove(AscendingList storage list, uint256 id) private returns (bytes32 key) {
        ListDetails memory listDetails = list.__details;
        ListItemDetails memory itemDetails = list.__items[id].details;

        require(listDetails.length > 0, 'SortedList: LIST_EMPTY');
        require(itemDetails.exists, 'SortedList: INVALID_ID');

        key = list.__keys[id];

        if (listDetails.length == 1) {
            delete list.__details;
        } else {

            if (uint64(id) == listDetails.head)
                listDetails.head = itemDetails.nextId;
            if (uint64(id) == listDetails.tail)
                listDetails.tail = itemDetails.prevId;
            if (itemDetails.prevId != 0)
                list.__items[itemDetails.prevId].details.nextId = itemDetails.nextId;
            if (itemDetails.nextId != 0)
                list.__items[itemDetails.nextId].details.prevId = itemDetails.prevId;

            --listDetails.length;
            list.__details = listDetails;
        }

        // TODO confirm the gas of this -- does this clear all the structs?
        delete list.__items[id];
        delete list.__keys[id];
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library Percent {

    uint256 internal constant BASE_PERCENT = type(uint16).max;

    function isValidPercent(uint256 nb) internal pure returns (bool) {
        return nb <= BASE_PERCENT;
    }

    function validatePercent(uint256 nb) internal pure {
        require(isValidPercent(nb), 'Percent: INVALID_NUMBER');
    }

    function applyPercent(uint256 nb, uint256 _percent) internal pure returns (uint256) {
        return (nb * _percent) / BASE_PERCENT;
    }

    function inverseApplyPercent(uint256 nb, uint256 _percent) internal pure returns (uint256) {
        return asPercent(nb) / (_percent);
    }

    function percentValueOf(uint256 value, uint256 total) internal pure returns (uint256) {
        return asPercent(value) / total;
    }

    function asPercent(uint256 value) internal pure returns (uint256) {
        return value * BASE_PERCENT;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library DynamicArray {

    struct Bytes32Array {
        uint256 length;
        bytes __data;
    }

    function push(Bytes32Array memory array, bytes32 item) internal pure {
        ++array.length;
        array.__data = abi.encodePacked(array.__data, item);
    }

    function toArray(Bytes32Array memory array) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encodePacked(array.length, array.__data), (bytes32[]));
    }

    function includes(Bytes32Array memory array, bytes32 item) internal pure returns (bool) {
        return indexOf(array, item) != type(uint256).max;
    }

    function indexOf(Bytes32Array memory array, bytes32 item) internal pure returns (uint256) {
        return _indexOf(array, item);
    }

    // ----------------------------------------------------------------------------------------------

    struct Uint256Array {
        uint256 length;
        bytes __data;
    }

    function push(Uint256Array memory array, uint256 item) internal pure {
        ++array.length;
        array.__data = abi.encodePacked(array.__data, item);
    }

    function toArray(Uint256Array memory array) internal pure returns (uint256[] memory) {
        return abi.decode(abi.encodePacked(array.length, array.__data), (uint256[]));
    }

    function includes(Uint256Array memory array, uint256 item) internal pure returns (bool) {
        return indexOf(array, item) != type(uint256).max;
    }

    function indexOf(Uint256Array memory array, uint256 item) internal pure returns (uint256) {
        return _indexOf(Bytes32Array(array.length, array.__data), bytes32(item));
    }

    // ----------------------------------------------------------------------------------------------

    struct AddressArray {
        uint256 length;
        bytes __data;
    }

    function push(AddressArray memory array, address item) internal pure {
        ++array.length;
        array.__data = abi.encodePacked(array.__data, abi.encode(item));
    }

    function toArray(AddressArray memory array) internal pure returns (address[] memory) {
        return abi.decode(abi.encodePacked(array.length, array.__data), (address[]));
    }

    function includes(AddressArray memory array, address item) internal pure returns (bool) {
        return indexOf(array, item) != type(uint256).max;
    }

    function indexOf(AddressArray memory array, address item) internal pure returns (uint256) {
        return _indexOf(Bytes32Array(array.length, array.__data), bytes32(uint256(uint160(item)) << 96));
    }

    // ----------------------------------------------------------------------------------------------

    function _indexOf(Bytes32Array memory array, bytes32 item) private pure returns (uint256) {
        bytes memory data = array.__data;
        for (uint i = 0; i < array.length; i++) {
            bytes32 piece;
            uint pos;

            unchecked {
                pos = i * 32;
            }
            assembly {
                piece := mload(add(data, pos))
            }

            if (piece == item) {
                return i;
            }
        }
        return type(uint256).max;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../SomaAccessControl/utils/AccessibleUpgradeable.sol";

import "./GuardHelper.sol";
import "./IGuardable.sol";

abstract contract GuardableUpgradeable is IGuardable, AccessibleUpgradeable {

    function __Guardable__init() internal {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __Guardable__init_unchained();
        __SomaContract_init_unchained();
        __Accessible_init_unchained();
    }

    function __Guardable__init_unchained() internal onlyInitializing {
        LOCAL_UPDATE_PRIVILEGES_ROLE = keccak256(abi.encodePacked(address(this), GLOBAL_UPDATE_PRIVILEGES_ROLE));
        _updateRequiredPrivileges(bytes32(type(uint256).max));
    }

    bytes32 public immutable DEFAULT_PRIVILEGES = GuardHelper.DEFAULT_PRIVILEGES;
    bytes32 public constant GLOBAL_UPDATE_PRIVILEGES_ROLE = keccak256('Guardable.GLOBAL_UPDATE_PRIVILEGES_ROLE');

    bytes32 public LOCAL_UPDATE_PRIVILEGES_ROLE;
    bytes32 private _requiredPrivileges;

    constructor(address somaAddress)
    SomaContractUpgradeable(somaAddress) {}

    modifier onlyApprovedPrivileges(address sender) {
        require(hasPrivileges(sender), 'required privileges not met');
        _;
    }

    function hasPrivileges(address account) public view virtual override returns (bool) {
        return SOMA.guard().check(account, requiredPrivileges());
    }

    function requiredPrivileges() public view virtual override returns (bytes32) {
        return _requiredPrivileges;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IGuardable).interfaceId || super.supportsInterface(interfaceId);
    }

    function updateRequiredPrivileges(bytes32 newRequiredPrivileges) external virtual override returns (bool) {
        require(
            hasRole(LOCAL_UPDATE_PRIVILEGES_ROLE, _msgSender()) || hasRole(GLOBAL_UPDATE_PRIVILEGES_ROLE, _msgSender()),
            'Guardable: you do not have the required roles to do this'
        );
        _updateRequiredPrivileges(newRequiredPrivileges);
        return true;
    }

    function _updateRequiredPrivileges(bytes32 newRequiredPrivileges) internal {
        emit RequiredPrivilegesUpdated(_requiredPrivileges, newRequiredPrivileges, _msgSender());
        _requiredPrivileges = newRequiredPrivileges;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library SafeERC20Balance {
    using SafeERC20 for IERC20;

    function safeTransferFrom(
        IERC20 token,
        address sender,
        address receiver,
        uint256 amount
    ) internal returns (uint256) {
        uint256 prevBalance = token.balanceOf(receiver);
        token.safeTransferFrom(sender, receiver, amount);
        return token.balanceOf(receiver) - prevBalance;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../SomaAccessControl/utils/AccessibleUpgradeable.sol";

import "./ITokenRecoveryUpgradeable.sol";

abstract contract TokenRecoveryUpgradeable is ITokenRecoveryUpgradeable, AccessibleUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    function __TokenRecovery__init() internal onlyInitializing {
        __TokenRecovery__init(new address[](0));
    }

    function __TokenRecovery__init(address[] memory disabledTokens) internal onlyInitializing {
        __ERC165_init_unchained();
        __Context_init_unchained();
        __SomaContract_init_unchained();
        __Accessible_init_unchained();
        __TokenRecovery__init_unchained(disabledTokens);
    }

    function __TokenRecovery__init_unchained(address[] memory disabledTokens) internal onlyInitializing {
        for (uint i; i < disabledTokens.length; ++i) {
            _disabledTokens.add(disabledTokens[i]);
        }
    }

    bytes32 public constant override TOKEN_RECOVERY_ROLE = keccak256('TokenRecovery.TOKEN_RECOVERY_ROLE');

    EnumerableSet.AddressSet private _disabledTokens;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ITokenRecoveryUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function recoverTokens(address token, address to, uint256 amount) external override onlyRole(TOKEN_RECOVERY_ROLE) {
        require(!_disabledTokens.contains(token), 'TokenRecovery: INVALID_TOKEN');
        IERC20(token).safeTransfer(to, amount);
        emit TokensRecovered(token, to, amount, _msgSender());
    }

    function _disableTokenRecovery(address token) internal {
        _disabledTokens.add(token);
    }

    function _enableTokenRecovery(address token) internal {
        _disabledTokens.remove(token);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ISomaStaking.sol";

library SomaStakingLibrary {

    uint256 internal constant PRECISION_FACTOR = 10**12;

    function rewardsUnlocked(ISomaStaking.Strategy memory _strategy, uint256 timestamp) internal pure returns (uint256) {
        uint256 locked = (timestamp >= _strategy.endDate)
            ? _strategy.rewardsLocked
            : ((timestamp - _strategy.startDate) * _strategy.rewardsLocked) / (_strategy.endDate - _strategy.startDate);
        return locked - _strategy.rewardsUnlocked;
    }

    function rewardsToTPS(uint256 totalStake, uint256 _rewardsUnlocked) internal pure returns (uint256 tps) {
        return (_rewardsUnlocked * PRECISION_FACTOR) / totalStake;
    }

    function stakeToRewards(uint256 stake, uint256 tps) internal pure returns (uint256) {
        return (stake * tps) / PRECISION_FACTOR;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISomaStaking {

    /************************************ Events ************************************/
    event Staked(uint256 amount, address indexed sender);
    event Unstaked(uint256 amount, address indexed sender);
    event UnstakedImmediate(uint256 amount, uint256 fee, address indexed sender);
    event Claimed(address indexed asset, uint256 amount, address indexed sender);
    // TODO asset or token?
    event ClaimedImmediate(address indexed asset, uint256 amount, uint256 fee, address indexed sender);
    event StrategyCreated(address indexed rewardToken,  uint256 amount, uint256 startDate, uint256 endDate, address indexed sender);
    event AdminClaimed(address indexed asset, uint256 amount, address indexed to, address indexed sender);
    event StakingConfigUpdated(StakingConfig prevConfig, StakingConfig newConfig, address indexed sender);
    event RequestCreated(uint256 indexed id, address indexed asset, uint256 amount, address indexed sender);
    event RequestCancelled(uint256 indexed id);
    event RequestFulfilled(uint256 indexed id);
    event RewardTokenAdded(address indexed token, address indexed sender);

    /************************************ Structs ************************************/
    struct StakingConfig {
        uint64 unstakeDuration;
        uint64 claimDuration;

        uint16 earlyUnstakeFee;
        uint16 earlyClaimFee;
    }

    struct Request {
        bytes8 hash;
        uint64 timestamp;
        uint128 amount;
    }

    /* UserInfo type structure */
    struct UserInfo {
        uint256 stake; // How many tokens the user has staked
        mapping(address => uint256) claimable;
        mapping(address => uint256) debt;
    }

    /* Strategy type structure */
    struct Strategy {
        uint48 startDate;
        uint48 endDate;
        address rewardToken;
        uint128 rewardsLocked;
        uint128 rewardsUnlocked;
    }

    function GLOBAL_ADMIN_ROLE() external pure returns (bytes32);
    function LOCAL_ADMIN_ROLE() external view returns (bytes32);

    function config() external view returns (StakingConfig memory);
    function strategy(uint256 id) external view returns (Strategy memory);
    function pendingStrategy(uint256 id) external view returns (Strategy memory);
    function totalStrategies() external view returns (uint256);
    function totalPendingStrategies() external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function totalPendingUnstake() external view returns (uint256);
    function tps(address token) external view returns (uint256 tps_);
    function currentTPS(address token) external view returns (uint256 tps_);
    function totalRewardTokens() external view returns (uint256);
    function rewardToken(uint256 index) external view returns (address);
    function stakingToken() external view returns (address);

    function stakeOf(address account) external view returns (uint256);
    function unstakeRequest(address account, uint256 id) external view returns (Request memory);

    function debt(address account, address asset) external view returns (uint256);
    function claimable(address account, address asset) external view returns (uint256);
    function claimRequest(address account, address asset, uint256 id) external view returns (Request memory);

    function initialize(address stakingToken, address[] memory rewardTokens) external;

    function stake(uint256 amount) external;

    function createUnstakeRequest(uint256 amount) external returns (uint256 id);
    function cancelUnstakeRequests(uint256[] calldata ids) external;
    function unstake(uint256[] calldata ids) external;
    function unstakeImmediate(uint256 amount) external;

    function createClaimRequests(address[] calldata assets) external returns (uint256[] memory ids);
    function cancelClaimRequests(address[] calldata asset, uint256[][] calldata ids) external;
    function claim(address[] calldata assets, uint256[][] calldata ids) external;
    function claimImmediate(address[] calldata assets, uint256[] calldata amounts) external;

    // ********************************** ADMIN **********************************

    function adminClaimable(address asset) external view returns (uint256);

    function addRewardToken(address asset) external;
    function adminClaim(address asset, address to) external;
    function createStrategy(
        uint256 startDate,
        uint256 endDate,
        address rewardToken,
        uint256 rewardAmount
    ) external;
    function updateConfig(
        uint64 unstakeDuration,
        uint64 claimDuration,
        uint16 earlyUnstakeFee,
        uint16 earlyClaimFee
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0-rc.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
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
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

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

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0-rc.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts (last updated v4.5.0-rc.0) (utils/Address.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

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
        mapping(bytes32 => uint256) _indexes;
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

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

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
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "../../utils/security/IPausable.sol";
import "../../utils/SomaContractUpgradeable.sol";

import "../ISomaAccessControl.sol";
import "./IAccessible.sol";

abstract contract AccessibleUpgradeable is IAccessible, SomaContractUpgradeable {

    function __Accessible_init() internal onlyInitializing {
        __SomaContract_init_unchained();
    }

    function __Accessible_init_unchained() internal onlyInitializing {
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, _msgSender()), "SomaAccessControl: caller does not have the appropriate authority");
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessible).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // slither-disable-next-line external-function
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return IAccessControlUpgradeable(address(SOMA.access())).getRoleAdmin(role);
    }

    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return IAccessControlUpgradeable(address(SOMA.access())).hasRole(role, account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IGuardable.sol";

library GuardHelper {

    // 00000000(192 0's repeated)111(64times)
    // (64 default on, 192 default off)
    bytes32 internal constant DEFAULT_PRIVILEGES = bytes32(uint256(2 ** 64 - 1));

    function requiredPrivileges(address account) internal view returns (bytes32 privileges) {
        try IGuardable(account).requiredPrivileges() returns (bytes32 requiredPrivileges_) {
            privileges = requiredPrivileges_;
        } catch(bytes memory) {
            privileges = DEFAULT_PRIVILEGES;
        }
    }

    function check(bytes32 privileges, bytes32 query) internal pure returns (bool) {
        return privileges & query == query;
    }

    function mergePrivileges(bytes32 privileges1, bytes32 privileges2) internal pure returns (bytes32) {
        return privileges1 | privileges2;
    }

    function mergePrivileges(bytes32 privileges1, bytes32 privileges2, bytes32 privileges3) internal pure returns (bytes32) {
        return privileges1 | privileges2 | privileges3;
    }

    function switchOn(uint256[] memory ids, bytes32 base) internal pure returns (bytes32 result) {
        result = base;
        for (uint i; i < ids.length; ++i) {
            result = result | bytes32(2**ids[i]);
        }
    }

    function switchOff(uint256[] memory ids, bytes32 base) internal pure returns (bytes32 result) {
        result = base;
        for (uint i; i < ids.length; ++i) {
            result = result & bytes32(type(uint256).max - 2**ids[i]);
        }
        result = result | DEFAULT_PRIVILEGES;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IGuardable {
    event RequiredPrivilegesUpdated(bytes32 prevPrivileges, bytes32 newPrivileges, address indexed sender);

    // Privileges Control
    function hasPrivileges(address account) external view returns (bool);
    function requiredPrivileges() external view returns (bytes32);
    function updateRequiredPrivileges(bytes32) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
    function __Context_init() internal onlyInitializing {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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

pragma solidity ^0.8.9;

interface IPausable {

    function paused() external view returns (bool);

    function pause() external;

    function unpause() external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../ISOMA.sol";

import "./ISomaContract.sol";

contract SomaContractUpgradeable is ISomaContract, PausableUpgradeable, ERC165Upgradeable {
    function __SomaContract_init() internal onlyInitializing {
        __ERC165_init_unchained();
        __Context_init_unchained();
        __SomaContract_init_unchained();
    }

    function __SomaContract_init_unchained() internal onlyInitializing {
        emit Initialized();
    }

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ISOMA public immutable override SOMA;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address somaAddress) {
        SOMA = ISOMA(somaAddress);
    }

    modifier onlyMasterOrSubMaster {
        address sender = _msgSender();
        require(SOMA.master() == sender || SOMA.subMaster() == sender, 'SOMA: MASTER or SUB MASTER only');
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ISomaContract).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function paused() public view virtual override returns (bool) {
        return PausableUpgradeable(address(SOMA)).paused() || super.paused();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISomaAccessControl {

    function rolesOf(address account) external view returns (bytes32[] memory);

    function accountsOf(bytes32 role) external view returns (address[] memory);

    function revokeRoles(bytes32[] memory roles, address target) external;

    function grantRoles(bytes32[] memory roles, address target) external;

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IAccessible {

    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

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
    function __ERC165_init() internal onlyInitializing {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal onlyInitializing {
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
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./SomaAccessControl/ISomaAccessControl.sol";
import "./SomaSwap/periphery/ISomaSwapRouter.sol";
import "./SomaSwap/core/interfaces/ISomaSwapFactory.sol";
import "./SomaGuard/ISomaGuard.sol";
import "./TemplateFactory/ITemplateFactory.sol";
import "./Lockdrop/ILockdropFactory.sol";

interface ISOMA {

    event SOMAUpgraded(bytes32 hash, bytes shapshot);

    event SeizeToUpdated(
        address indexed prevSeizeTo,
        address indexed newSeizeTo,
        address indexed sender
    );

    event MintToUpdated(
        address indexed prevMintTo,
        address indexed newMintTo,
        address indexed sender
    );

    struct Snapshot {
        address master;
        address subMaster;
        ISomaAccessControl access;
        ISomaGuard guard;
        ISomaSwapFactory swapFactory;
        ITemplateFactory templateFactory;
        ILockdropFactory lockdropFactory;
        IERC20 token;
    }

    function master() external view returns (address);
    function subMaster() external view returns (address);

    function access() external view returns (ISomaAccessControl);
    function guard() external view returns (ISomaGuard);
    function swapFactory() external view returns (ISomaSwapFactory);
    function templateFactory() external view returns (ITemplateFactory);
    function lockdropFactory() external view returns (ILockdropFactory);
    function token() external view returns (IERC20);

    function snapshotHash() external view returns (bytes32);
    function snapshots(bytes32 hash) external view returns (bytes memory);

    function mintTo() external view returns (address);
    function seizeTo() external view returns (address);

    function __upgrade() external;

    function pause() external;
    function unpause() external;

    function setMintTo(address _mintTo) external;
    function setSeizeTo(address _seizeTo) external;

    function snapshot() external view returns (Snapshot memory _cache);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../ISOMA.sol";

interface ISomaContract {

    event Initialized();

    function SOMA() external view returns (ISOMA);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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

pragma solidity >=0.6.2;

interface ISomaSwapRouter {
    function factory() external view returns (address);
    function WETH() external view returns (address);

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISomaSwapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event FeeToUpdated(address indexed prevFeeTo, address indexed newFeeTo, address indexed sender);
    event RouterAdded(address indexed router, address indexed sender);
    event RouterRemoved(address indexed router, address indexed sender);

    function TEMPLATE() external view returns (bytes32);
    function TEMPLATE_VERSION() external view returns (uint256);

    function CREATE_PAIR_ROLE() external pure returns (bytes32);
    function FEE_SETTER_ROLE() external pure returns (bytes32);
    function MANAGE_ROUTER_ROLE() external pure returns (bytes32);

    function DEPLOYER() external view returns (address);
    function INIT_CODE_HASH() external view returns (bytes32);

    function feeTo() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function isRouter(address target) external view returns (bool);
    function addRouter(address target) external;
    function removeRouter(address target) external;

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface ISomaGuard {

    event PrivilegesUpdated(address indexed operator, bytes32 prevPrivileges, bytes32 newPrivileges, address indexed account);
    event ContractApproved(address indexed operator, address account);
    event ContractUnapproved(address indexed operator, address account);

    event BatchUpdate(
        address[][] accounts,
        bytes32[] privileges,
        address indexed sender
    );

    event BatchUpdateSingle(
        address[] accounts,
        bytes32[] access,
        address indexed sender
    );

    function DEFAULT_PRIVILEGES() external view returns (bytes32);
    function OPERATOR_ROLE() external view returns (bytes32);

    function privileges(address account) external view returns (bytes32);
    function check(address account, bytes32 query) external view returns (bool);

    function batchFetch(address[] calldata accounts) external view returns (bytes32[] memory access_);
    function batchUpdate(address[] calldata accounts_, bytes32[] calldata access_) external returns (bool);
    function batchUpdate(address[][] calldata accounts_, bytes32[] calldata access_) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ITemplateFactory {

    event TemplateVersionCreated(bytes32 indexed templateId, uint256 indexed version, address implementation, address indexed sender);
    event DeployRoleUpdated(bytes32 indexed templateId, bytes32 prevRole, bytes32 newRole, address indexed sender);
    event TemplateEnabled(bytes32 indexed templateId, address indexed sender);
    event TemplateDisabled(bytes32 indexed templateId, address indexed sender);
    event TemplateVersionDeprecated(bytes32 indexed templateId, uint256 indexed version, address indexed sender);
    event TemplateVersionUndeprecated(bytes32 indexed templateId, uint256 indexed version, address indexed sender);
    event TemplateDeployed(address indexed instance, bytes32 indexed templateId, uint256 version, bytes args, bytes[] functionCalls, address indexed sender);
    event TemplateCloned(address indexed instance, bytes32 indexed templateId, uint256 version, bytes[] functionCalls, address indexed sender);
    event FunctionCalled(address indexed target, bytes data, bytes result, address indexed sender);

    struct Version {
        bool deprecated;
        address implementation;
        bytes creationCode;
        uint256 totalParts;
        uint256 partsUploaded;
        address[] instances;
    }

    struct Template {
        bool disabled;
        bytes32 deployRole;
        Version[] versions;
        address[] instances;
    }

    struct DeploymentInfo {
        bool exists;
        bytes32 templateId;
        uint256 version;
        bytes args;
        bytes[] functionCalls;
        bool cloned;
    }

    function initialize() external;

    function version(bytes32 templateId, uint256 version) external view returns (Version memory);

    function latestVersion(bytes32 templateId) external view returns (uint256);

    function templateInstances(bytes32 templateId) external view returns (address[] memory);

    function deploymentInfo(address instance) external view returns (DeploymentInfo memory);

    function deployRole(bytes32 templateId) external view returns (bytes32);

    function deployedByFactory(address instance) external view returns (bool);

    function uploadTemplate(bytes32 templateId, bytes memory creationCode, address implementation) external returns (bool);
    function uploadTemplate(bytes32 templateId, bytes memory initialPart, uint256 totalParts, address implementation) external returns (bool);
    function uploadTemplatePart(bytes32 templateId, uint256 version, bytes memory part) external returns (bool);

    function updateDeployRole(bytes32 templateId, bytes32 deployRole) external returns (bool);

    function disableTemplate(bytes32 templateId) external returns (bool);

    function enableTemplate(bytes32 templateId) external returns (bool);

    function deprecateVersion(bytes32 templateId, uint256 version) external returns (bool);

    function undeprecateVersion(bytes32 templateId, uint256 version) external returns (bool);

    function initCodeHash(bytes32 templateId, uint256 version, bytes memory args) external view returns (bytes32);

    function predictDeployAddress(bytes32 templateId, uint256 version, bytes memory args) external view returns (address);

    function predictDeployAddress(bytes32 templateId, uint256 version, bytes memory args, bytes32 salt) external view returns (address);

    function predictCloneAddress(bytes32 templateId, uint256 version) external view returns (address);

    function predictCloneAddress(bytes32 templateId, uint256 version, bytes32 salt) external view returns (address);

    function deployTemplateLATEST(bytes32 templateId, bytes memory args) external returns (address instance);

    function deployTemplateLATEST(bytes32 templateId, bytes memory args, bytes32 salt) external returns (address instance);

    function deployTemplateLATEST(bytes32 templateId, bytes memory args, bytes[] memory functionCalls) external returns (address instance);

    function deployTemplateLATEST(bytes32 templateId, bytes memory args, bytes[] memory functionCalls, bytes32 salt) external returns (address instance);

    function deployTemplate(bytes32 templateId, uint256 version, bytes memory args) external returns (address instance);

    function deployTemplate(bytes32 templateId, uint256 version, bytes memory args, bytes32 salt) external returns (address instance);

    function deployTemplate(bytes32 templateId, uint256 version, bytes memory args, bytes[] memory functionCalls) external returns (address instance);

    function deployTemplate(bytes32 templateId, uint256 version, bytes memory args, bytes[] memory functionCalls, bytes32 salt) external returns (address instance);

    function cloneTemplateLATEST(bytes32 templateId) external returns (address instance);

    function cloneTemplateLATEST(bytes32 templateId, bytes32 salt) external returns (address instance);

    function cloneTemplateLATEST(bytes32 templateId, bytes[] memory functionCalls) external returns (address instance);

    function cloneTemplateLATEST(bytes32 templateId, bytes[] memory functionCalls, bytes32 salt) external returns (address instance);

    function cloneTemplate(bytes32 templateId, uint256 _version) external returns (address instance);

    function cloneTemplate(bytes32 templateId, uint256 _version, bytes32 salt) external returns (address instance);

    function cloneTemplate(bytes32 templateId, uint256 _version, bytes[] memory functionCalls) external returns (address instance);

    function cloneTemplate(bytes32 templateId, uint256 version, bytes[] memory functionCalls, bytes32 salt) external returns (address instance);

    function functionCall(address target, bytes memory data) external returns (bytes memory result);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ILockdrop.sol";

interface ILockdropFactory {

    event LockdropCreated(uint256 id, address asset, address instance);

    function CREATE_ROLE() external pure returns (bytes32);
    function TEMPLATE() external pure returns (bytes32);
    function TEMPLATE_VERSION() external pure returns (uint256);

    function lockdrop(uint256 id) external view returns (address);
    function totalLockdrops() external view returns (uint256);

    function create(
        address asset,
        address withdrawTo,
        ILockdrop.DateConfig calldata dateConfig
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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
interface IERC165 {
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

pragma solidity ^0.8.9;

interface ILockdrop {

    event DelegationConfigUpdated(DelegationConfig prevConfig, DelegationConfig newConfig, address indexed sender);
    event WithdrawToUpdated(address prevTo, address newTo, address indexed sender);
    event DelegationAdded(bytes32 indexed poolId, uint256 amount, address indexed sender);
    event DelegationMoved(bytes32 indexed fromPoolId, bytes32 indexed toPoolId, uint256 amount, address indexed sender);
    event DatesUpdated(DateConfig prevDateConfig, DateConfig newDateConfig, address indexed sender);
    event PoolUpdated(bytes32 indexed poolId, bytes32 requiredPrivileges, bool enabled, address indexed sender);

    struct DateConfig {
        uint48 phase1;
        uint48 phase2;
        uint48 phase3;
    }

    struct Pool {
        bool enabled;
        bytes32 requiredPrivileges;
        mapping(address => uint256) balances;
    }

    struct DelegationConfig {
        uint8 percentLocked;
        uint8 lockDuration;
    }

    function GLOBAL_ADMIN_ROLE() external pure returns (bytes32);
    function LOCAL_ADMIN_ROLE() external view returns (bytes32);

    function id() external view returns (uint256);
    function asset() external view returns (address);
    function dateConfig() external view returns (DateConfig memory);
    function withdrawTo() external view returns (address);

    function initialize(
        uint256 _id,
        address _asset,
        address _withdrawTo,
        DateConfig calldata _dateConfig
    ) external;

    function updateDateConfig(DateConfig calldata newConfig) external;
    function setWithdrawTo(address account) external;
    function balanceOf(bytes32 poolId, address account) external view returns (uint256);
    function delegationConfig(address account) external view returns (DelegationConfig memory);
    function enabled(bytes32 poolId) external view returns (bool);
    function requiredPrivileges(bytes32 poolId) external view returns (bytes32);
    function updatePool(bytes32 poolId, bytes32 requiredPrivileges, bool enabled) external;
    function withdraw(uint256 amount) external;
    function moveDelegation(bytes32 fromPoolId, bytes32 toPoolId, uint256 amount) external;
    function delegate(bytes32 poolId, uint256 amount) external;
    function updateDelegationConfig(DelegationConfig calldata newConfig) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITokenRecoveryUpgradeable {

    event TokensRecovered(address indexed token, address indexed to, uint256 amount, address indexed sender);

    function TOKEN_RECOVERY_ROLE() external pure returns (bytes32);

    function recoverTokens(address asset, address to, uint256 amount) external;
}