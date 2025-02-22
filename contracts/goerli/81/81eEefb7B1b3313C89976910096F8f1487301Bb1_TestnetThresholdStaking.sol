// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;


import "SimplePREApplication.sol";
import "Ownable.sol";


contract TestnetThresholdStaking is Ownable {

    struct StakingProviderInfo {
        address owner;
        address payable beneficiary;
        address authorizer;
        uint96 tStake;
        uint96 keepInTStake;
        uint96 nuInTStake;
    }

    SimplePREApplication public preApplication;

    mapping (address => StakingProviderInfo) public stakingProviderInfo;

    function setApplication(SimplePREApplication _preApplication) external onlyOwner {
        preApplication = _preApplication;
    }

    function stakedNu(address) external view returns (uint256) {
        return 0;
    }

    function setRoles(
        address _stakingProvider,
        address _owner,
        address payable _beneficiary,
        address _authorizer
    )
        external onlyOwner
    {
        StakingProviderInfo storage info = stakingProviderInfo[_stakingProvider];
        info.owner = _owner;
        info.beneficiary = _beneficiary;
        info.authorizer = _authorizer;
    }

    /**
    * @dev If the function is called with only the _stakingProvider parameter,
    * we presume that the caller wants that address set for the other roles as well.
    */
    function setRoles(address _stakingProvider) external onlyOwner {
        StakingProviderInfo storage info = stakingProviderInfo[_stakingProvider];
        info.owner = _stakingProvider;
        info.beneficiary = payable(_stakingProvider);
        info.authorizer = _stakingProvider;
    }

    function setStakes(
        address _stakingProvider,
        uint96 _tStake,
        uint96 _keepInTStake,
        uint96 _nuInTStake
    )
        external onlyOwner
    {
        StakingProviderInfo storage info = stakingProviderInfo[_stakingProvider];
        info.tStake = _tStake;
        info.keepInTStake = _keepInTStake;
        info.nuInTStake = _nuInTStake;
    }

    function authorizedStake(address _stakingProvider, address _application) external view returns (uint96) {
        return 0;
    }

    function stakes(address _stakingProvider) external view returns (
        uint96 tStake,
        uint96 keepInTStake,
        uint96 nuInTStake
    ) {
        StakingProviderInfo storage info = stakingProviderInfo[_stakingProvider];
        tStake = info.tStake;
        keepInTStake = info.keepInTStake;
        nuInTStake = info.nuInTStake;
    }

    function rolesOf(address _stakingProvider) external view returns (
        address owner,
        address payable beneficiary,
        address authorizer
    ) {
        StakingProviderInfo storage info = stakingProviderInfo[_stakingProvider];
        owner = info.owner;
        beneficiary = info.beneficiary;
        authorizer = info.authorizer;
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;


import "IStaking.sol";


/**
* @title PRE Application
* @notice Contract handles PRE configuration
*/
contract SimplePREApplication {

    /**
    * @notice Signals that an operator was bonded to the staking provider
    * @param stakingProvider Staking provider address
    * @param operator Operator address
    * @param startTimestamp Timestamp bonding occurred
    */
    event OperatorBonded(address indexed stakingProvider, address indexed operator, uint256 startTimestamp);

    /**
    * @notice Signals that an operator address is confirmed
    * @param stakingProvider Staking provider address
    * @param operator Operator address
    */
    event OperatorConfirmed(address indexed stakingProvider, address indexed operator);

    struct StakingProviderInfo {
        address operator;
        bool operatorConfirmed;
        uint256 operatorStartTimestamp;
    }

    uint256 public immutable minAuthorization;
    uint256 public immutable minOperatorSeconds;

    IStaking public immutable tStaking;

    mapping (address => StakingProviderInfo) public stakingProviderInfo;
    address[] public stakingProviders;
    mapping(address => address) internal _stakingProviderFromOperator;


    /**
    * @notice Constructor sets address of token contract and parameters for staking
    * @param _tStaking T token staking contract
    * @param _minAuthorization Amount of minimum allowable authorization
    * @param _minOperatorSeconds Min amount of seconds while an operator can't be changed
    */
    constructor(
        IStaking _tStaking,
        uint256 _minAuthorization,
        uint256 _minOperatorSeconds
    ) {
        require(
            _tStaking.authorizedStake(address(this), address(this)) == 0,
            "Wrong input parameters"
        );
        minAuthorization = _minAuthorization;
        tStaking = _tStaking;
        minOperatorSeconds = _minOperatorSeconds;
    }

    /**
    * @dev Checks caller is a staking provider or stake owner
    */
    modifier onlyOwnerOrStakingProvider(address _stakingProvider)
    {
        require(isAuthorized(_stakingProvider), "Not owner or provider");
        if (_stakingProvider != msg.sender) {
            (address owner,,) = tStaking.rolesOf(_stakingProvider);
            require(owner == msg.sender, "Not owner or provider");
        }
        _;
    }


    //-------------------------Main-------------------------
    /**
    * @notice Returns staking provider for specified operator
    */
    function stakingProviderFromOperator(address _operator) public view returns (address) {
        return _stakingProviderFromOperator[_operator];
    }

    /**
    * @notice Returns operator for specified staking provider
    */
    function getOperatorFromStakingProvider(address _stakingProvider) public view returns (address) {
        return stakingProviderInfo[_stakingProvider].operator;
    }

    /**
    * @notice Get all tokens delegated to the staking provider
    */
    function authorizedStake(address _stakingProvider) public view returns (uint96) {
        (uint96 tStake, uint96 keepInTStake, uint96 nuInTStake) = tStaking.stakes(_stakingProvider);
        return tStake + keepInTStake + nuInTStake;
    }

    /**
    * @notice Get the value of authorized tokens for active providers as well as providers and their authorized tokens
    * @param _startIndex Start index for looking in providers array
    * @param _maxStakingProviders Max providers for looking, if set 0 then all will be used
    * @return allAuthorizedTokens Sum of authorized tokens for active providers
    * @return activeStakingProviders Array of providers and their authorized tokens.
    * Providers addresses stored as uint256
    * @dev Note that activeStakingProviders[0] is an array of uint256, but you want addresses.
    * Careful when used directly!
    */
    function getActiveStakingProviders(uint256 _startIndex, uint256 _maxStakingProviders)
        external view returns (uint256 allAuthorizedTokens, uint256[2][] memory activeStakingProviders)
    {
        uint256 endIndex = stakingProviders.length;
        require(_startIndex < endIndex, "Wrong start index");
        if (_maxStakingProviders != 0 && _startIndex + _maxStakingProviders < endIndex) {
            endIndex = _startIndex + _maxStakingProviders;
        }
        activeStakingProviders = new uint256[2][](endIndex - _startIndex);
        allAuthorizedTokens = 0;

        uint256 resultIndex = 0;
        for (uint256 i = _startIndex; i < endIndex; i++) {
            address stakingProvider = stakingProviders[i];
            StakingProviderInfo storage info = stakingProviderInfo[stakingProvider];
            uint256 eligibleAmount = authorizedStake(stakingProvider);
            if (eligibleAmount < minAuthorization || !info.operatorConfirmed) {
                continue;
            }
            activeStakingProviders[resultIndex][0] = uint256(uint160(stakingProvider));
            activeStakingProviders[resultIndex++][1] = eligibleAmount;
            allAuthorizedTokens += eligibleAmount;
        }
        assembly {
            mstore(activeStakingProviders, resultIndex)
        }
    }

    /**
    * @notice Returns beneficiary related to the staking provider
    */
    function getBeneficiary(address _stakingProvider) public view returns (address payable beneficiary) {
        (, beneficiary,) = tStaking.rolesOf(_stakingProvider);
    }

    /**
    * @notice Returns true if staking provider has authorized stake to this application
    */
    function isAuthorized(address _stakingProvider) public view returns (bool) {
        return authorizedStake(_stakingProvider) >= minAuthorization;
    }

    /**
    * @notice Returns true if operator has confirmed address
    */
    // TODO maybe _stakingProvider instead of _operator as input?
    function isOperatorConfirmed(address _operator) public view returns (bool) {
        address stakingProvider = _stakingProviderFromOperator[_operator];
        StakingProviderInfo storage info = stakingProviderInfo[stakingProvider];
        return info.operatorConfirmed;
    }

    /**
    * @notice Return the length of the array of staking providers
    */
    function getStakingProvidersLength() external view returns (uint256) {
        return stakingProviders.length;
    }

    /**
    * @notice Bond operator
    * @param _stakingProvider Staking provider address
    * @param _operator Operator address. Must be a real address, not a contract
    */
    function bondOperator(address _stakingProvider, address _operator)
        external onlyOwnerOrStakingProvider(_stakingProvider)
    {
        StakingProviderInfo storage info = stakingProviderInfo[_stakingProvider];
        require(_operator != info.operator, "Specified operator is already bonded with this provider");
        // If this staker had an operator ...
        if (info.operator != address(0)) {
            require(
                block.timestamp >= info.operatorStartTimestamp + minOperatorSeconds,
                "Not enough time passed to change operator"
            );
            // Remove the old relation "operator->stakingProvider"
            _stakingProviderFromOperator[info.operator] = address(0);
        }

        if (_operator != address(0)) {
            require(_stakingProviderFromOperator[_operator] == address(0), "Specified operator is already in use");
            require(
                _operator == _stakingProvider || getBeneficiary(_operator) == address(0),
                "Specified operator is a provider"
            );
            // Set new operator->stakingProvider relation
            _stakingProviderFromOperator[_operator] = _stakingProvider;
        }

        if (info.operatorStartTimestamp == 0) {
            stakingProviders.push(_stakingProvider);
        }

        // Bond new operator (or unbond if _operator == address(0))
        info.operator = _operator;
        info.operatorStartTimestamp = block.timestamp;
        info.operatorConfirmed = false;
        emit OperatorBonded(_stakingProvider, _operator, block.timestamp);
    }

    /**
    * @notice Make a confirmation by operator
    */
    function confirmOperatorAddress() external {
        address stakingProvider = _stakingProviderFromOperator[msg.sender];
        require(isAuthorized(stakingProvider), "No stake associated with the operator");
        StakingProviderInfo storage info = stakingProviderInfo[stakingProvider];
        require(!info.operatorConfirmed, "Operator address is already confirmed");
        require(msg.sender == tx.origin, "Only operator with real address can make a confirmation");
        info.operatorConfirmed = true;
        emit OperatorConfirmed(stakingProvider, msg.sender);
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later

// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌

pragma solidity ^0.8.0;

/// @title Interface of Threshold Network staking contract
/// @notice The staking contract enables T owners to have their wallets offline
///         and their stake managed by providers on their behalf. All off-chain
///         client software should be able to run without exposing provider’s
///         private key and should not require any owner’s keys at all.
///         The stake delegation optimizes the network throughput without
///         compromising the security of the owners’ stake.
interface IStaking {
    enum StakeType {
        NU,
        KEEP,
        T
    }

    //
    //
    // Delegating a stake
    //
    //

    /// @notice Creates a delegation with `msg.sender` owner with the given
    ///         provider, beneficiary, and authorizer. Transfers the given
    ///         amount of T to the staking contract.
    /// @dev The owner of the delegation needs to have the amount approved to
    ///      transfer to the staking contract.
    function stake(
        address stakingProvider,
        address payable beneficiary,
        address authorizer,
        uint96 amount
    ) external;

    /// @notice Copies delegation from the legacy KEEP staking contract to T
    ///         staking contract. No tokens are transferred. Caches the active
    ///         stake amount from KEEP staking contract. Can be called by
    ///         anyone.
    function stakeKeep(address stakingProvider) external;

    /// @notice Copies delegation from the legacy NU staking contract to T
    ///         staking contract, additionally appointing beneficiary and
    ///         authorizer roles. Caches the amount staked in NU staking
    ///         contract. Can be called only by the original delegation owner.
    function stakeNu(
        address stakingProvider,
        address payable beneficiary,
        address authorizer
    ) external;

    /// @notice Refresh Keep stake owner. Can be called only by the old owner.
    function refreshKeepStakeOwner(address stakingProvider) external;

    /// @notice Allows the Governance to set the minimum required stake amount.
    ///         This amount is required to protect against griefing the staking
    ///         contract and individual applications are allowed to require
    ///         higher minimum stakes if necessary.
    function setMinimumStakeAmount(uint96 amount) external;

    //
    //
    // Authorizing an application
    //
    //

    /// @notice Allows the Governance to approve the particular application
    ///         before individual stake authorizers are able to authorize it.
    function approveApplication(address application) external;

    /// @notice Increases the authorization of the given provider for the given
    ///         application by the given amount. Can only be called by the given
    ///         provider’s authorizer.
    /// @dev Calls `authorizationIncreased(address stakingProvider, uint256 amount)`
    ///      on the given application to notify the application about
    ///      authorization change. See `IApplication`.
    function increaseAuthorization(
        address stakingProvider,
        address application,
        uint96 amount
    ) external;

    /// @notice Requests decrease of the authorization for the given provider on
    ///         the given application by the provided amount.
    ///         It may not change the authorized amount immediatelly. When
    ///         it happens depends on the application. Can only be called by the
    ///         given provider’s authorizer. Overwrites pending authorization
    ///         decrease for the given provider and application.
    /// @dev Calls `authorizationDecreaseRequested(address stakingProvider, uint256 amount)`
    ///      on the given application. See `IApplication`.
    function requestAuthorizationDecrease(
        address stakingProvider,
        address application,
        uint96 amount
    ) external;

    /// @notice Requests decrease of all authorizations for the given provider on
    ///         the applications by all authorized amount.
    ///         It may not change the authorized amount immediatelly. When
    ///         it happens depends on the application. Can only be called by the
    ///         given provider’s authorizer. Overwrites pending authorization
    ///         decrease for the given provider and application.
    /// @dev Calls `authorizationDecreaseRequested(address stakingProvider, uint256 amount)`
    ///      for each authorized application. See `IApplication`.
    function requestAuthorizationDecrease(address stakingProvider) external;

    /// @notice Called by the application at its discretion to approve the
    ///         previously requested authorization decrease request. Can only be
    ///         called by the application that was previously requested to
    ///         decrease the authorization for that provider.
    ///         Returns resulting authorized amount for the application.
    function approveAuthorizationDecrease(address stakingProvider)
        external
        returns (uint96);

    /// @notice Decreases the authorization for the given `stakingProvider` on
    ///         the given disabled `application`, for all authorized amount.
    ///         Can be called by anyone.
    function forceDecreaseAuthorization(
        address stakingProvider,
        address application
    ) external;

    /// @notice Pauses the given application’s eligibility to slash stakes.
    ///         Besides that stakers can't change authorization to the application.
    ///         Can be called only by the Panic Button of the particular
    ///         application. The paused application can not slash stakes until
    ///         it is approved again by the Governance using `approveApplication`
    ///         function. Should be used only in case of an emergency.
    function pauseApplication(address application) external;

    /// @notice Disables the given application. The disabled application can't
    ///         slash stakers. Also stakers can't increase authorization to that
    ///         application but can decrease without waiting by calling
    ///         `requestAuthorizationDecrease` at any moment. Can be called only
    ///         by the governance. The disabled application can't be approved
    ///         again. Should be used only in case of an emergency.
    function disableApplication(address application) external;

    /// @notice Sets the Panic Button role for the given application to the
    ///         provided address. Can only be called by the Governance. If the
    ///         Panic Button for the given application should be disabled, the
    ///         role address should be set to 0x0 address.
    function setPanicButton(address application, address panicButton) external;

    /// @notice Sets the maximum number of applications one provider can
    ///         authorize. Used to protect against DoSing slashing queue.
    ///         Can only be called by the Governance.
    function setAuthorizationCeiling(uint256 ceiling) external;

    //
    //
    // Stake top-up
    //
    //

    /// @notice Increases the amount of the stake for the given provider.
    ///         Can be called only by the owner or provider.
    /// @dev The sender of this transaction needs to have the amount approved to
    ///      transfer to the staking contract.
    function topUp(address stakingProvider, uint96 amount) external;

    /// @notice Propagates information about stake top-up from the legacy KEEP
    ///         staking contract to T staking contract. Can be called only by
    ///         the owner or provider.
    function topUpKeep(address stakingProvider) external;

    /// @notice Propagates information about stake top-up from the legacy NU
    ///         staking contract to T staking contract. Can be called only by
    ///         the owner or provider.
    function topUpNu(address stakingProvider) external;

    //
    //
    // Undelegating a stake (unstaking)
    //
    //

    /// @notice Reduces the liquid T stake amount by the provided amount and
    ///         withdraws T to the owner. Reverts if there is at least one
    ///         authorization higher than the sum of the legacy stake and
    ///         remaining liquid T stake or if the unstake amount is higher than
    ///         the liquid T stake amount. Can be called only by the owner or
    ///         provider.
    function unstakeT(address stakingProvider, uint96 amount) external;

    /// @notice Sets the legacy KEEP staking contract active stake amount cached
    ///         in T staking contract to 0. Reverts if the amount of liquid T
    ///         staked in T staking contract is lower than the highest
    ///         application authorization. This function allows to unstake from
    ///         KEEP staking contract and still being able to operate in T
    ///         network and earning rewards based on the liquid T staked. Can be
    ///         called only by the delegation owner and provider.
    function unstakeKeep(address stakingProvider) external;

    /// @notice Reduces cached legacy NU stake amount by the provided amount.
    ///         Reverts if there is at least one authorization higher than the
    ///         sum of remaining legacy NU stake and liquid T stake for that
    ///         provider or if the untaked amount is higher than the cached
    ///         legacy stake amount. If succeeded, the legacy NU stake can be
    ///         partially or fully undelegated on the legacy staking contract.
    ///         This function allows to unstake from NU staking contract and
    ///         still being able to operate in T network and earning rewards
    ///         based on the liquid T staked. Can be called only by the
    ///         delegation owner and provider.
    function unstakeNu(address stakingProvider, uint96 amount) external;

    /// @notice Sets cached legacy stake amount to 0, sets the liquid T stake
    ///         amount to 0 and withdraws all liquid T from the stake to the
    ///         owner. Reverts if there is at least one non-zero authorization.
    ///         Can be called only by the delegation owner and provider.
    function unstakeAll(address stakingProvider) external;

    //
    //
    // Keeping information in sync
    //
    //

    /// @notice Notifies about the discrepancy between legacy KEEP active stake
    ///         and the amount cached in T staking contract. Slashes the provider
    ///         in case the amount cached is higher than the actual active stake
    ///         amount in KEEP staking contract. Needs to update authorizations
    ///         of all affected applications and execute an involuntary
    ///         allocation decrease on all affected applications. Can be called
    ///         by anyone, notifier receives a reward.
    function notifyKeepStakeDiscrepancy(address stakingProvider) external;

    /// @notice Notifies about the discrepancy between legacy NU active stake
    ///         and the amount cached in T staking contract. Slashes the
    ///         provider in case the amount cached is higher than the actual
    ///         active stake amount in NU staking contract. Needs to update
    ///         authorizations of all affected applications and execute an
    ///         involuntary allocation decrease on all affected applications.
    ///         Can be called by anyone, notifier receives a reward.
    function notifyNuStakeDiscrepancy(address stakingProvider) external;

    /// @notice Sets the penalty amount for stake discrepancy and reward
    ///         multiplier for reporting it. The penalty is seized from the
    ///         provider account, and 5% of the penalty, scaled by the
    ///         multiplier, is given to the notifier. The rest of the tokens are
    ///         burned. Can only be called by the Governance. See `seize` function.
    function setStakeDiscrepancyPenalty(
        uint96 penalty,
        uint256 rewardMultiplier
    ) external;

    /// @notice Sets reward in T tokens for notification of misbehaviour
    ///         of one provider. Can only be called by the governance.
    function setNotificationReward(uint96 reward) external;

    /// @notice Transfer some amount of T tokens as reward for notifications
    ///         of misbehaviour
    function pushNotificationReward(uint96 reward) external;

    /// @notice Withdraw some amount of T tokens from notifiers treasury.
    ///         Can only be called by the governance.
    function withdrawNotificationReward(address recipient, uint96 amount)
        external;

    /// @notice Adds providers to the slashing queue along with the amount that
    ///         should be slashed from each one of them. Can only be called by
    ///         application authorized for all providers in the array.
    function slash(uint96 amount, address[] memory stakingProviders) external;

    /// @notice Adds providers to the slashing queue along with the amount.
    ///         The notifier will receive reward per each provider from
    ///         notifiers treasury. Can only be called by application
    ///         authorized for all providers in the array.
    function seize(
        uint96 amount,
        uint256 rewardMultipier,
        address notifier,
        address[] memory stakingProviders
    ) external;

    /// @notice Takes the given number of queued slashing operations and
    ///         processes them. Receives 5% of the slashed amount.
    ///         Executes `involuntaryAllocationDecrease` function on each
    ///         affected application.
    function processSlashing(uint256 count) external;

    //
    //
    // Auxiliary functions
    //
    //

    /// @notice Returns the authorized stake amount of the provider for the
    ///         application.
    function authorizedStake(address stakingProvider, address application)
        external
        view
        returns (uint96);

    /// @notice Returns staked amount of T, Keep and Nu for the specified
    ///         staking provider.
    /// @dev    All values are in T denomination
    function stakes(address stakingProvider)
        external
        view
        returns (
            uint96 tStake,
            uint96 keepInTStake,
            uint96 nuInTStake
        );

    /// @notice Returns start staking timestamp for T/NU stake.
    /// @dev    This value is set at most once, and only when a stake is created
    ///         with T or NU tokens. If a stake is created from a legacy KEEP
    ///         stake, this value will remain as zero
    function getStartStakingTimestamp(address stakingProvider)
        external
        view
        returns (uint256);

    /// @notice Returns staked amount of NU for the specified provider
    function stakedNu(address stakingProvider) external view returns (uint256);

    /// @notice Gets the stake owner, the beneficiary and the authorizer
    ///         for the specified provider address.
    /// @return owner Stake owner address.
    /// @return beneficiary Beneficiary address.
    /// @return authorizer Authorizer address.
    function rolesOf(address stakingProvider)
        external
        view
        returns (
            address owner,
            address payable beneficiary,
            address authorizer
        );

    /// @notice Returns length of application array
    function getApplicationsLength() external view returns (uint256);

    /// @notice Returns length of slashing queue
    function getSlashingQueueLength() external view returns (uint256);

    /// @notice Returns minimum possible stake for T, KEEP or NU in T denomination
    /// @dev For example, suppose the given provider has 10 T, 20 T worth
    ///      of KEEP, and 30 T worth of NU all staked, and the maximum
    ///      application authorization is 40 T, then `getMinStaked` for
    ///      that provider returns:
    ///          * 0 T if KEEP stake type specified i.e.
    ///            min = 40 T max - (10 T + 30 T worth of NU) = 0 T
    ///          * 10 T if NU stake type specified i.e.
    ///            min = 40 T max - (10 T + 20 T worth of KEEP) = 10 T
    ///          * 0 T if T stake type specified i.e.
    ///            min = 40 T max - (20 T worth of KEEP + 30 T worth of NU) < 0 T
    ///      In other words, the minimum stake amount for the specified
    ///      stake type is the minimum amount of stake of the given type
    ///      needed to satisfy the maximum application authorization given
    ///      the staked amounts of the other stake types for that provider.
    function getMinStaked(address stakingProvider, StakeType stakeTypes)
        external
        view
        returns (uint96);

    /// @notice Returns available amount to authorize for the specified application
    function getAvailableToAuthorize(
        address stakingProvider,
        address application
    ) external view returns (uint96);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "Context.sol";

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