// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IEigenPodManager.sol";
import "../interfaces/IDelayedWithdrawalRouter.sol";
import "../permissions/Pausable.sol";

contract DelayedWithdrawalRouter is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, Pausable, IDelayedWithdrawalRouter{
    /// @notice Emitted when the `withdrawalDelayBlocks` variable is modified from `previousValue` to `newValue`.
    event WithdrawalDelayBlocksSet(uint256 previousValue, uint256 newValue);

    // index for flag that pauses withdrawals (i.e. 'delayedWithdrawal claims') when set
    uint8 internal constant PAUSED_DELAYED_WITHDRAWAL_CLAIMS = 0;

    /**
     * @notice Delay enforced by this contract for completing any delayedWithdrawal. Measured in blocks, and adjustable by this contract's owner,
     * up to a maximum of `MAX_WITHDRAWAL_DELAY_BLOCKS`. Minimum value is 0 (i.e. no delay enforced).
     */
    uint256 public withdrawalDelayBlocks;
    // the number of 12-second blocks in one week (60 * 60 * 24 * 7 / 12 = 50,400)
    uint256 public constant MAX_WITHDRAWAL_DELAY_BLOCKS = 50400;

    /// @notice The EigenPodManager contract of EigenLayer.
    IEigenPodManager public immutable eigenPodManager;

    /// @notice Mapping: user => struct storing all delayedWithdrawal info. Marked as internal with an external getter function named `userWithdrawals`
    mapping(address => UserDelayedWithdrawals) internal _userWithdrawals;

    /// @notice event for delayedWithdrawal creation
    event DelayedWithdrawalCreated(address podOwner, address recipient, uint256 amount, uint256 index);

    /// @notice event for the claiming of delayedWithdrawals
    event DelayedWithdrawalsClaimed(address recipient, uint256 amountClaimed, uint256 delayedWithdrawalsCompleted);

    /// @notice Modifier used to permission a function to only be called by the EigenPod of the specified `podOwner`
    modifier onlyEigenPod(address podOwner) {
        require(address(eigenPodManager.getPod(podOwner)) == msg.sender, "DelayedWithdrawalRouter.onlyEigenPod: not podOwner's EigenPod");
        _;
    }

    constructor(IEigenPodManager _eigenPodManager) {
        require(address(_eigenPodManager) != address(0), "DelayedWithdrawalRouter.constructor: _eigenPodManager cannot be zero address");
        eigenPodManager = _eigenPodManager;
    }

    function initialize(address initOwner, IPauserRegistry _pauserRegistry, uint256 initPausedStatus, uint256 _withdrawalDelayBlocks) external initializer {
        _transferOwnership(initOwner);
        _initializePauser(_pauserRegistry, initPausedStatus);
        _setWithdrawalDelayBlocks(_withdrawalDelayBlocks);
    }

    /** 
     * @notice Creates a delayed withdrawal for `msg.value` to the `recipient`.
     * @dev Only callable by the `podOwner`'s EigenPod contract.
     */
    function createDelayedWithdrawal(address podOwner, address recipient) external payable onlyEigenPod(podOwner) onlyWhenNotPaused(PAUSED_DELAYED_WITHDRAWAL_CLAIMS) {
        require(recipient != address(0), "DelayedWithdrawalRouter.createDelayedWithdrawal: recipient cannot be zero address");
        uint224 withdrawalAmount = uint224(msg.value);
        if (withdrawalAmount != 0) {
            DelayedWithdrawal memory delayedWithdrawal = DelayedWithdrawal({
                amount: withdrawalAmount,
                blockCreated: uint32(block.number)
            });
            _userWithdrawals[recipient].delayedWithdrawals.push(delayedWithdrawal);
            emit DelayedWithdrawalCreated(podOwner, recipient, withdrawalAmount, _userWithdrawals[recipient].delayedWithdrawals.length - 1);
        }
    }

    /**
     * @notice Called in order to withdraw delayed withdrawals made to the `recipient` that have passed the `withdrawalDelayBlocks` period.
     * @param recipient The address to claim delayedWithdrawals for.
     * @param maxNumberOfDelayedWithdrawalsToClaim Used to limit the maximum number of delayedWithdrawals to loop through claiming.
     * @dev 
     *      WARNING: Note that the caller of this function cannot control where the funds are sent, but they can control when the 
     *              funds are sent once the withdrawal becomes claimable.
     */
    function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfDelayedWithdrawalsToClaim)
        external
        nonReentrant
        onlyWhenNotPaused(PAUSED_DELAYED_WITHDRAWAL_CLAIMS)
    {
        _claimDelayedWithdrawals(recipient, maxNumberOfDelayedWithdrawalsToClaim);
    }

    /**
     * @notice Called in order to withdraw delayed withdrawals made to the caller that have passed the `withdrawalDelayBlocks` period.
     * @param maxNumberOfDelayedWithdrawalsToClaim Used to limit the maximum number of delayedWithdrawals to loop through claiming.
     */
    function claimDelayedWithdrawals(uint256 maxNumberOfDelayedWithdrawalsToClaim)
        external
        nonReentrant
        onlyWhenNotPaused(PAUSED_DELAYED_WITHDRAWAL_CLAIMS)
    {
        _claimDelayedWithdrawals(msg.sender, maxNumberOfDelayedWithdrawalsToClaim);
    }

    /// @notice Owner-only function for modifying the value of the `withdrawalDelayBlocks` variable.
    function setWithdrawalDelayBlocks(uint256 newValue) external onlyOwner {
        _setWithdrawalDelayBlocks(newValue);
    }

    /// @notice Getter function for the mapping `_userWithdrawals`
    function userWithdrawals(address user) external view returns (UserDelayedWithdrawals memory) {
        return _userWithdrawals[user];
    }

    /// @notice Getter function to get all delayedWithdrawals of the `user`
    function getUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory) {
        uint256 delayedWithdrawalsCompleted = _userWithdrawals[user].delayedWithdrawalsCompleted;
        uint256 totalDelayedWithdrawals = _userWithdrawals[user].delayedWithdrawals.length;
        uint256 userDelayedWithdrawalsLength = totalDelayedWithdrawals - delayedWithdrawalsCompleted;
        DelayedWithdrawal[] memory userDelayedWithdrawals = new DelayedWithdrawal[](userDelayedWithdrawalsLength);
        for (uint256 i = 0; i < userDelayedWithdrawalsLength; i++) {
            userDelayedWithdrawals[i] = _userWithdrawals[user].delayedWithdrawals[delayedWithdrawalsCompleted + i];
        }
        return userDelayedWithdrawals;
    }

    /// @notice Getter function to get all delayedWithdrawals that are currently claimable by the `user`
    function getClaimableUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory) {
        uint256 delayedWithdrawalsCompleted = _userWithdrawals[user].delayedWithdrawalsCompleted;
        uint256 totalDelayedWithdrawals = _userWithdrawals[user].delayedWithdrawals.length;
        uint256 userDelayedWithdrawalsLength = totalDelayedWithdrawals - delayedWithdrawalsCompleted;

        uint256 firstNonClaimableWithdrawalIndex = userDelayedWithdrawalsLength;

        for (uint256 i = 0; i < userDelayedWithdrawalsLength; i++) {
            DelayedWithdrawal memory delayedWithdrawal = _userWithdrawals[user].delayedWithdrawals[delayedWithdrawalsCompleted + i];
            // check if delayedWithdrawal can be claimed. break the loop as soon as a delayedWithdrawal cannot be claimed
            if (block.number < delayedWithdrawal.blockCreated + withdrawalDelayBlocks) {
                firstNonClaimableWithdrawalIndex = i;
                break;
            }
        }
        uint256 numberOfClaimableWithdrawals = firstNonClaimableWithdrawalIndex;
        DelayedWithdrawal[] memory claimableDelayedWithdrawals = new DelayedWithdrawal[](numberOfClaimableWithdrawals);
        
        if(numberOfClaimableWithdrawals != 0) {
            for (uint256 i = 0; i < numberOfClaimableWithdrawals; i++) {
                claimableDelayedWithdrawals[i] = _userWithdrawals[user].delayedWithdrawals[delayedWithdrawalsCompleted + i];
            }
        }
        return claimableDelayedWithdrawals;
    }

    /// @notice Getter function for fetching the delayedWithdrawal at the `index`th entry from the `_userWithdrawals[user].delayedWithdrawals` array
    function userDelayedWithdrawalByIndex(address user, uint256 index) external view returns (DelayedWithdrawal memory) {
        return _userWithdrawals[user].delayedWithdrawals[index];
    }

    /// @notice Getter function for fetching the length of the delayedWithdrawals array of a specific user
    function userWithdrawalsLength(address user) external view returns (uint256) {
        return _userWithdrawals[user].delayedWithdrawals.length;
    }

    /// @notice Convenience function for checking whether or not the delayedWithdrawal at the `index`th entry from the `_userWithdrawals[user].delayedWithdrawals` array is currently claimable
    function canClaimDelayedWithdrawal(address user, uint256 index) external view returns (bool) {
        return ((index >= _userWithdrawals[user].delayedWithdrawalsCompleted) && (block.number >= _userWithdrawals[user].delayedWithdrawals[index].blockCreated + withdrawalDelayBlocks));
    }

    /// @notice internal function used in both of the overloaded `claimDelayedWithdrawals` functions
    function _claimDelayedWithdrawals(address recipient, uint256 maxNumberOfDelayedWithdrawalsToClaim) internal {
        uint256 amountToSend = 0;
        uint256 delayedWithdrawalsCompletedBefore = _userWithdrawals[recipient].delayedWithdrawalsCompleted;
        uint256 _userWithdrawalsLength = _userWithdrawals[recipient].delayedWithdrawals.length;
        uint256 i = 0;
        while (i < maxNumberOfDelayedWithdrawalsToClaim && (delayedWithdrawalsCompletedBefore + i) < _userWithdrawalsLength) {
            // copy delayedWithdrawal from storage to memory
            DelayedWithdrawal memory delayedWithdrawal = _userWithdrawals[recipient].delayedWithdrawals[delayedWithdrawalsCompletedBefore + i];
            // check if delayedWithdrawal can be claimed. break the loop as soon as a delayedWithdrawal cannot be claimed
            if (block.number < delayedWithdrawal.blockCreated + withdrawalDelayBlocks) {
                break;
            }
            // otherwise, the delayedWithdrawal can be claimed, in which case we increase the amountToSend and increment i
            amountToSend += delayedWithdrawal.amount;
            // increment i to account for the delayedWithdrawal being claimed
            unchecked {
                ++i;
            }
        }
        // mark the i delayedWithdrawals as claimed
        _userWithdrawals[recipient].delayedWithdrawalsCompleted = delayedWithdrawalsCompletedBefore + i;
        // actually send the ETH
        if (amountToSend != 0) {
            AddressUpgradeable.sendValue(payable(recipient), amountToSend);
        }
        emit DelayedWithdrawalsClaimed(recipient, amountToSend, delayedWithdrawalsCompletedBefore + i);
    }

    /// @notice internal function for changing the value of `withdrawalDelayBlocks`. Also performs sanity check and emits an event.
    function _setWithdrawalDelayBlocks(uint256 newValue) internal {
        require(newValue <= MAX_WITHDRAWAL_DELAY_BLOCKS, "DelayedWithdrawalRouter._setWithdrawalDelayBlocks: newValue too large");
        emit WithdrawalDelayBlocksSet(withdrawalDelayBlocks, newValue);
        withdrawalDelayBlocks = newValue;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
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
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "./IStrategyManager.sol";
import "./IEigenPod.sol";
import "./IBeaconChainOracle.sol";
import "./IPausable.sol";

/**
 * @title Interface for factory that creates and manages solo staking pods that have their withdrawal credentials pointed to EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */

interface IEigenPodManager is IPausable {
    /**
     * @notice Creates an EigenPod for the sender.
     * @dev Function will revert if the `msg.sender` already has an EigenPod.
     */
    function createPod() external;

    /**
     * @notice Stakes for a new beacon chain validator on the sender's EigenPod. 
     * Also creates an EigenPod for the sender if they don't have one already.
     * @param pubkey The 48 bytes public key of the beacon chain validator.
     * @param signature The validator's signature of the deposit data.
     * @param depositDataRoot The root/hash of the deposit data for the validator's deposit.
     */
    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;

    /**
     * @notice Deposits/Restakes beacon chain ETH in EigenLayer on behalf of the owner of an EigenPod.
     * @param podOwner The owner of the pod whose balance must be deposited.
     * @param amount The amount of ETH to 'deposit' (i.e. be credited to the podOwner).
     * @dev Callable only by the podOwner's EigenPod contract.
     */
    function restakeBeaconChainETH(address podOwner, uint256 amount) external;

    /**
     * @notice Removes beacon chain ETH from EigenLayer on behalf of the owner of an EigenPod, when the
     *         balance of a validator is lower than how much stake they have committed to EigenLayer
     * @param podOwner The owner of the pod whose balance must be removed.
     * @param beaconChainETHStrategyIndex is the index of the beaconChainETHStrategy for the pod owner for the callback to 
     *                                    the StrategyManager in case it must be removed from the list of the podOwner's strategies
     * @param amount The amount of ETH to remove.
     * @dev Callable only by the podOwner's EigenPod contract.
     */
    function recordOvercommittedBeaconChainETH(address podOwner, uint256 beaconChainETHStrategyIndex, uint256 amount) external;
    
    /**
     * @notice Withdraws ETH from an EigenPod. The ETH must have first been withdrawn from the beacon chain.
     * @param podOwner The owner of the pod whose balance must be withdrawn.
     * @param recipient The recipient of the withdrawn ETH.
     * @param amount The amount of ETH to withdraw.
     * @dev Callable only by the StrategyManager contract.
     */
    function withdrawRestakedBeaconChainETH(address podOwner, address recipient, uint256 amount) external;

    /**
     * @notice Updates the oracle contract that provides the beacon chain state root
     * @param newBeaconChainOracle is the new oracle contract being pointed to
     * @dev Callable only by the owner of this contract (i.e. governance)
     */
    function updateBeaconChainOracle(IBeaconChainOracle newBeaconChainOracle) external;

    /// @notice Returns the address of the `podOwner`'s EigenPod if it has been deployed.
    function ownerToPod(address podOwner) external view returns(IEigenPod);

    /// @notice Returns the address of the `podOwner`'s EigenPod (whether it is deployed yet or not).
    function getPod(address podOwner) external view returns(IEigenPod);

    /// @notice Oracle contract that provides updates to the beacon chain's state
    function beaconChainOracle() external view returns(IBeaconChainOracle);    

    /// @notice Returns the Beacon Chain state root at `blockNumber`. Reverts if the Beacon Chain state root at `blockNumber` has not yet been finalized.
    function getBeaconChainStateRoot(uint64 blockNumber) external view returns(bytes32);

    /// @notice EigenLayer's StrategyManager contract
    function strategyManager() external view returns(IStrategyManager);

    /// @notice EigenLayer's Slasher contract
    function slasher() external view returns(ISlasher);

    function hasPod(address podOwner) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

interface IDelayedWithdrawalRouter {
    // struct used to pack data into a single storage slot
    struct DelayedWithdrawal {
        uint224 amount;
        uint32 blockCreated;
    }

    // struct used to store a single users delayedWithdrawal data
    struct UserDelayedWithdrawals {
        uint256 delayedWithdrawalsCompleted;
        DelayedWithdrawal[] delayedWithdrawals;
    }

    /** 
     * @notice Creates an delayed withdrawal for `msg.value` to the `recipient`.
     * @dev Only callable by the `podOwner`'s EigenPod contract.
     */
    function createDelayedWithdrawal(address podOwner, address recipient) external payable;

    /**
     * @notice Called in order to withdraw delayed withdrawals made to the `recipient` that have passed the `withdrawalDelayBlocks` period.
     * @param recipient The address to claim delayedWithdrawals for.
     * @param maxNumberOfWithdrawalsToClaim Used to limit the maximum number of withdrawals to loop through claiming.
     */
    function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfWithdrawalsToClaim) external;

    /**
     * @notice Called in order to withdraw delayed withdrawals made to the caller that have passed the `withdrawalDelayBlocks` period.
     * @param maxNumberOfWithdrawalsToClaim Used to limit the maximum number of withdrawals to loop through claiming.
     */
    function claimDelayedWithdrawals(uint256 maxNumberOfWithdrawalsToClaim) external;

    /// @notice Owner-only function for modifying the value of the `withdrawalDelayBlocks` variable.
    function setWithdrawalDelayBlocks(uint256 newValue) external;

    /// @notice Getter function for the mapping `_userWithdrawals`
    function userWithdrawals(address user) external view returns (UserDelayedWithdrawals memory);

    /// @notice Getter function to get all delayedWithdrawals of the `user`
    function getUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory);

    /// @notice Getter function to get all delayedWithdrawals that are currently claimable by the `user`
    function getClaimableUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory);
    
    /// @notice Getter function for fetching the delayedWithdrawal at the `index`th entry from the `_userWithdrawals[user].delayedWithdrawals` array
    function userDelayedWithdrawalByIndex(address user, uint256 index) external view returns (DelayedWithdrawal memory);

    /// @notice Getter function for fetching the length of the delayedWithdrawals array of a specific user
    function userWithdrawalsLength(address user) external view returns (uint256);

    /// @notice Convenience function for checking whether or not the delayedWithdrawal at the `index`th entry from the `_userWithdrawals[user].delayedWithdrawals` array is currently claimable
    function canClaimDelayedWithdrawal(address user, uint256 index) external view returns (bool);

    /**
     * @notice Delay enforced by this contract for completing any delayedWithdrawal. Measured in blocks, and adjustable by this contract's owner,
     * up to a maximum of `MAX_WITHDRAWAL_DELAY_BLOCKS`. Minimum value is 0 (i.e. no delay enforced).
     */
    function withdrawalDelayBlocks() external view returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity =0.8.12;

import "../interfaces/IPausable.sol";

/**
 * @title Adds pausability to a contract, with pausing & unpausing controlled by the `pauser` and `unpauser` of a PauserRegistry contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice Contracts that inherit from this contract may define their own `pause` and `unpause` (and/or related) functions.
 * These functions should be permissioned as "onlyPauser" which defers to a `PauserRegistry` for determining access control.
 * @dev Pausability is implemented using a uint256, which allows up to 256 different single bit-flags; each bit can potentially pause different functionality.
 * Inspiration for this was taken from the NearBridge design here https://etherscan.io/address/0x3FEFc5A4B1c02f21cBc8D3613643ba0635b9a873#code.
 * For the `pause` and `unpause` functions we've implemented, if you pause, you can only flip (any number of) switches to on/1 (aka "paused"), and if you unpause,
 * you can only flip (any number of) switches to off/0 (aka "paused").
 * If you want a pauseXYZ function that just flips a single bit / "pausing flag", it will:
 * 1) 'bit-wise and' (aka `&`) a flag with the current paused state (as a uint256)
 * 2) update the paused state to this new value
 * @dev We note as well that we have chosen to identify flags by their *bit index* as opposed to their numerical value, so, e.g. defining `DEPOSITS_PAUSED = 3`
 * indicates specifically that if the *third bit* of `_paused` is flipped -- i.e. it is a '1' -- then deposits should be paused
 */
contract Pausable is IPausable {
    /// @notice Address of the `PauserRegistry` contract that this contract defers to for determining access control (for pausing).
    IPauserRegistry public pauserRegistry;

    /// @dev whether or not the contract is currently paused
    uint256 private _paused;

    uint256 constant internal UNPAUSE_ALL = 0;
    uint256 constant internal PAUSE_ALL = type(uint256).max;

    /// @notice Emitted when the `pauserRegistry` is set to `newPauserRegistry`.
    event PauserRegistrySet(IPauserRegistry pauserRegistry, IPauserRegistry newPauserRegistry);

    /// @notice Emitted when the pause is triggered by `account`, and changed to `newPausedStatus`.
    event Paused(address indexed account, uint256 newPausedStatus);

    /// @notice Emitted when the pause is lifted by `account`, and changed to `newPausedStatus`.
    event Unpaused(address indexed account, uint256 newPausedStatus);

    /// @notice
    modifier onlyPauser() {
        require(pauserRegistry.isPauser(msg.sender), "msg.sender is not permissioned as pauser");
        _;
    }

    modifier onlyUnpauser() {
        require(msg.sender == pauserRegistry.unpauser(), "msg.sender is not permissioned as unpauser");
        _;
    }

    /// @notice Throws if the contract is paused, i.e. if any of the bits in `_paused` is flipped to 1.
    modifier whenNotPaused() {
        require(_paused == 0, "Pausable: contract is paused");
        _;
    }

    /// @notice Throws if the `indexed`th bit of `_paused` is 1, i.e. if the `index`th pause switch is flipped.
    modifier onlyWhenNotPaused(uint8 index) {
        require(!paused(index), "Pausable: index is paused");
        _;
    }

    /// @notice One-time function for setting the `pauserRegistry` and initializing the value of `_paused`.
    function _initializePauser(IPauserRegistry _pauserRegistry, uint256 initPausedStatus) internal {
        require(
            address(pauserRegistry) == address(0) && address(_pauserRegistry) != address(0),
            "Pausable._initializePauser: _initializePauser() can only be called once"
        );
        _paused = initPausedStatus;
        emit Paused(msg.sender, initPausedStatus);
        _setPauserRegistry(_pauserRegistry);
    }

    /**
     * @notice This function is used to pause an EigenLayer contract's functionality.
     * It is permissioned to the `pauser` address, which is expected to be a low threshold multisig.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only pause functionality, and thus cannot 'unflip' any bit in `_paused` from 1 to 0.
     */
    function pause(uint256 newPausedStatus) external onlyPauser {
        // verify that the `newPausedStatus` does not *unflip* any bits (i.e. doesn't unpause anything, all 1 bits remain)
        require((_paused & newPausedStatus) == _paused, "Pausable.pause: invalid attempt to unpause functionality");
        _paused = newPausedStatus;
        emit Paused(msg.sender, newPausedStatus);
    }

    /**
     * @notice Alias for `pause(type(uint256).max)`.
     */
    function pauseAll() external onlyPauser {
        _paused = type(uint256).max;
        emit Paused(msg.sender, type(uint256).max);
    }

    /**
     * @notice This function is used to unpause an EigenLayer contract's functionality.
     * It is permissioned to the `unpauser` address, which is expected to be a high threshold multisig or governance contract.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only unpause functionality, and thus cannot 'flip' any bit in `_paused` from 0 to 1.
     */
    function unpause(uint256 newPausedStatus) external onlyUnpauser {
        // verify that the `newPausedStatus` does not *flip* any bits (i.e. doesn't pause anything, all 0 bits remain)
        require(((~_paused) & (~newPausedStatus)) == (~_paused), "Pausable.unpause: invalid attempt to pause functionality");
        _paused = newPausedStatus;
        emit Unpaused(msg.sender, newPausedStatus);
    }

    /// @notice Returns the current paused status as a uint256.
    function paused() public view virtual returns (uint256) {
        return _paused;
    }

    /// @notice Returns 'true' if the `indexed`th bit of `_paused` is 1, and 'false' otherwise
    function paused(uint8 index) public view virtual returns (bool) {
        uint256 mask = 1 << index;
        return ((_paused & mask) == mask);
    }

    /// @notice Allows the unpauser to set a new pauser registry
    function setPauserRegistry(IPauserRegistry newPauserRegistry) external onlyUnpauser {
        _setPauserRegistry(newPauserRegistry);
    }

    /// internal function for setting pauser registry
    function _setPauserRegistry(IPauserRegistry newPauserRegistry) internal {
        require(address(newPauserRegistry) != address(0), "Pausable._setPauserRegistry: newPauserRegistry cannot be the zero address");
        emit PauserRegistrySet(pauserRegistry, newPauserRegistry);
        pauserRegistry = newPauserRegistry;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "./IStrategy.sol";
import "./ISlasher.sol";
import "./IDelegationManager.sol";

/**
 * @title Interface for the primary entrypoint for funds into EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice See the `StrategyManager` contract itself for implementation details.
 */
interface IStrategyManager {
    // packed struct for queued withdrawals; helps deal with stack-too-deep errors
    struct WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    /**
     * Struct type used to specify an existing queued withdrawal. Rather than storing the entire struct, only a hash is stored.
     * In functions that operate on existing queued withdrawals -- e.g. `startQueuedWithdrawalWaitingPeriod` or `completeQueuedWithdrawal`,
     * the data is resubmitted and the hash of the submitted data is computed by `calculateWithdrawalRoot` and checked against the
     * stored hash in order to confirm the integrity of the submitted data.
     */
    struct QueuedWithdrawal {
        IStrategy[] strategies;
        uint256[] shares;
        address depositor;
        WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    /**
     * @notice Deposits `amount` of `token` into the specified `strategy`, with the resultant shares credited to `msg.sender`
     * @param strategy is the specified strategy where deposit is to be made,
     * @param token is the denomination in which the deposit is to be made,
     * @param amount is the amount of token to be deposited in the strategy by the depositor
     * @return shares The amount of new shares in the `strategy` created as part of the action.
     * @dev The `msg.sender` must have previously approved this contract to transfer at least `amount` of `token` on their behalf.
     * @dev Cannot be called by an address that is 'frozen' (this function will revert if the `msg.sender` is frozen).
     * 
     * WARNING: Depositing tokens that allow reentrancy (eg. ERC-777) into a strategy is not recommended.  This can lead to attack vectors
     *          where the token balance and corresponding strategy shares are not in sync upon reentrancy.
     */
    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount)
        external
        returns (uint256 shares);


    /**
     * @notice Deposits `amount` of beaconchain ETH into this contract on behalf of `staker`
     * @param staker is the entity that is restaking in eigenlayer,
     * @param amount is the amount of beaconchain ETH being restaked,
     * @dev Only callable by EigenPodManager.
     */
    function depositBeaconChainETH(address staker, uint256 amount) external;

    /**
     * @notice Records an overcommitment event on behalf of a staker. The staker's beaconChainETH shares are decremented by `amount`.
     * @param overcommittedPodOwner is the pod owner to be slashed
     * @param beaconChainETHStrategyIndex is the index of the beaconChainETHStrategy in case it must be removed,
     * @param amount is the amount to decrement the slashedAddress's beaconChainETHStrategy shares
     * @dev Only callable by EigenPodManager.
     */
    function recordOvercommittedBeaconChainETH(address overcommittedPodOwner, uint256 beaconChainETHStrategyIndex, uint256 amount)
        external;

    /**
     * @notice Used for depositing an asset into the specified strategy with the resultant shares credited to `staker`,
     * who must sign off on the action.
     * Note that the assets are transferred out/from the `msg.sender`, not from the `staker`; this function is explicitly designed 
     * purely to help one address deposit 'for' another.
     * @param strategy is the specified strategy where deposit is to be made,
     * @param token is the denomination in which the deposit is to be made,
     * @param amount is the amount of token to be deposited in the strategy by the depositor
     * @param staker the staker that the deposited assets will be credited to
     * @param expiry the timestamp at which the signature expires
     * @param signature is a valid signature from the `staker`. either an ECDSA signature if the `staker` is an EOA, or data to forward
     * following EIP-1271 if the `staker` is a contract
     * @return shares The amount of new shares in the `strategy` created as part of the action.
     * @dev The `msg.sender` must have previously approved this contract to transfer at least `amount` of `token` on their behalf.
     * @dev A signature is required for this function to eliminate the possibility of griefing attacks, specifically those
     * targeting stakers who may be attempting to undelegate.
     * @dev Cannot be called on behalf of a staker that is 'frozen' (this function will revert if the `staker` is frozen).
     * 
     *  WARNING: Depositing tokens that allow reentrancy (eg. ERC-777) into a strategy is not recommended.  This can lead to attack vectors
     *          where the token balance and corresponding strategy shares are not in sync upon reentrancy
     */
    function depositIntoStrategyWithSignature(
        IStrategy strategy,
        IERC20 token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    )
        external
        returns (uint256 shares);

    /// @notice Returns the current shares of `user` in `strategy`
    function stakerStrategyShares(address user, IStrategy strategy) external view returns (uint256 shares);

    /**
     * @notice Get all details on the depositor's deposits and corresponding shares
     * @return (depositor's strategies, shares in these strategies)
     */
    function getDeposits(address depositor) external view returns (IStrategy[] memory, uint256[] memory);

    /// @notice Simple getter function that returns `stakerStrategyList[staker].length`.
    function stakerStrategyListLength(address staker) external view returns (uint256);

    /**
     * @notice Called by a staker to queue a withdrawal of the given amount of `shares` from each of the respective given `strategies`.
     * @dev Stakers will complete their withdrawal by calling the 'completeQueuedWithdrawal' function.
     * User shares are decreased in this function, but the total number of shares in each strategy remains the same.
     * The total number of shares is decremented in the 'completeQueuedWithdrawal' function instead, which is where
     * the funds are actually sent to the user through use of the strategies' 'withdrawal' function. This ensures
     * that the value per share reported by each strategy will remain consistent, and that the shares will continue
     * to accrue gains during the enforced withdrawal waiting period.
     * @param strategyIndexes is a list of the indices in `stakerStrategyList[msg.sender]` that correspond to the strategies
     * for which `msg.sender` is withdrawing 100% of their shares
     * @param strategies The Strategies to withdraw from
     * @param shares The amount of shares to withdraw from each of the respective Strategies in the `strategies` array
     * @param withdrawer The address that can complete the withdrawal and will receive any withdrawn funds or shares upon completing the withdrawal
     * @param undelegateIfPossible If this param is marked as 'true' *and the withdrawal will result in `msg.sender` having no shares in any Strategy,*
     * then this function will also make an internal call to `undelegate(msg.sender)` to undelegate the `msg.sender`.
     * @return The 'withdrawalRoot' of the newly created Queued Withdrawal
     * @dev Strategies are removed from `stakerStrategyList` by swapping the last entry with the entry to be removed, then
     * popping off the last entry in `stakerStrategyList`. The simplest way to calculate the correct `strategyIndexes` to input
     * is to order the strategies *for which `msg.sender` is withdrawing 100% of their shares* from highest index in
     * `stakerStrategyList` to lowest index
     * @dev Note that if the withdrawal includes shares in the enshrined 'beaconChainETH' strategy, then it must *only* include shares in this strategy, and
     * `withdrawer` must match the caller's address. The first condition is because slashing of queued withdrawals cannot be guaranteed 
     * for Beacon Chain ETH (since we cannot trigger a withdrawal from the beacon chain through a smart contract) and the second condition is because shares in
     * the enshrined 'beaconChainETH' strategy technically represent non-fungible positions (deposits to the Beacon Chain, each pointed at a specific EigenPod).
     */
    function queueWithdrawal(
        uint256[] calldata strategyIndexes,
        IStrategy[] calldata strategies,
        uint256[] calldata shares,
        address withdrawer,
        bool undelegateIfPossible
    )
        external returns(bytes32);
        
    /**
     * @notice Used to complete the specified `queuedWithdrawal`. The function caller must match `queuedWithdrawal.withdrawer`
     * @param queuedWithdrawal The QueuedWithdrawal to complete.
     * @param tokens Array in which the i-th entry specifies the `token` input to the 'withdraw' function of the i-th Strategy in the `strategies` array
     * of the `queuedWithdrawal`. This input can be provided with zero length if `receiveAsTokens` is set to 'false' (since in that case, this input will be unused)
     * @param middlewareTimesIndex is the index in the operator that the staker who triggered the withdrawal was delegated to's middleware times array
     * @param receiveAsTokens If true, the shares specified in the queued withdrawal will be withdrawn from the specified strategies themselves
     * and sent to the caller, through calls to `queuedWithdrawal.strategies[i].withdraw`. If false, then the shares in the specified strategies
     * will simply be transferred to the caller directly.
     * @dev middlewareTimesIndex should be calculated off chain before calling this function by finding the first index that satisfies `slasher.canWithdraw`
     */
    function completeQueuedWithdrawal(
        QueuedWithdrawal calldata queuedWithdrawal,
        IERC20[] calldata tokens,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    )
        external;
    
    /**
     * @notice Used to complete the specified `queuedWithdrawals`. The function caller must match `queuedWithdrawals[...].withdrawer`
     * @param queuedWithdrawals The QueuedWithdrawals to complete.
     * @param tokens Array of tokens for each QueuedWithdrawal. See `completeQueuedWithdrawal` for the usage of a single array.
     * @param middlewareTimesIndexes One index to reference per QueuedWithdrawal. See `completeQueuedWithdrawal` for the usage of a single index.
     * @param receiveAsTokens If true, the shares specified in the queued withdrawal will be withdrawn from the specified strategies themselves
     * and sent to the caller, through calls to `queuedWithdrawal.strategies[i].withdraw`. If false, then the shares in the specified strategies
     * will simply be transferred to the caller directly.
     * @dev Array-ified version of `completeQueuedWithdrawal`
     * @dev middlewareTimesIndex should be calculated off chain before calling this function by finding the first index that satisfies `slasher.canWithdraw`
     */
    function completeQueuedWithdrawals(
        QueuedWithdrawal[] calldata queuedWithdrawals,
        IERC20[][] calldata tokens,
        uint256[] calldata middlewareTimesIndexes,
        bool[] calldata receiveAsTokens
    )
        external;

    /**
     * @notice Slashes the shares of a 'frozen' operator (or a staker delegated to one)
     * @param slashedAddress is the frozen address that is having its shares slashed
     * @param recipient is the address that will receive the slashed funds, which could e.g. be a harmed party themself,
     * or a MerkleDistributor-type contract that further sub-divides the slashed funds.
     * @param strategies Strategies to slash
     * @param shareAmounts The amount of shares to slash in each of the provided `strategies`
     * @param tokens The tokens to use as input to the `withdraw` function of each of the provided `strategies`
     * @param strategyIndexes is a list of the indices in `stakerStrategyList[msg.sender]` that correspond to the strategies
     * for which `msg.sender` is withdrawing 100% of their shares
     * @param recipient The slashed funds are withdrawn as tokens to this address.
     * @dev strategies are removed from `stakerStrategyList` by swapping the last entry with the entry to be removed, then
     * popping off the last entry in `stakerStrategyList`. The simplest way to calculate the correct `strategyIndexes` to input
     * is to order the strategies *for which `msg.sender` is withdrawing 100% of their shares* from highest index in
     * `stakerStrategyList` to lowest index
     */
    function slashShares(
        address slashedAddress,
        address recipient,
        IStrategy[] calldata strategies,
        IERC20[] calldata tokens,
        uint256[] calldata strategyIndexes,
        uint256[] calldata shareAmounts
    )
        external;

    /**
     * @notice Slashes an existing queued withdrawal that was created by a 'frozen' operator (or a staker delegated to one)
     * @param recipient The funds in the slashed withdrawal are withdrawn as tokens to this address.
     * @param queuedWithdrawal The previously queued withdrawal to be slashed
     * @param tokens Array in which the i-th entry specifies the `token` input to the 'withdraw' function of the i-th Strategy in the `strategies`
     * array of the `queuedWithdrawal`.
     * @param indicesToSkip Optional input parameter -- indices in the `strategies` array to skip (i.e. not call the 'withdraw' function on). This input exists
     * so that, e.g., if the slashed QueuedWithdrawal contains a malicious strategy in the `strategies` array which always reverts on calls to its 'withdraw' function,
     * then the malicious strategy can be skipped (with the shares in effect "burned"), while the non-malicious strategies are still called as normal.
     */
    function slashQueuedWithdrawal(address recipient, QueuedWithdrawal calldata queuedWithdrawal, IERC20[] calldata tokens, uint256[] calldata indicesToSkip)
        external;

    /// @notice Returns the keccak256 hash of `queuedWithdrawal`.
    function calculateWithdrawalRoot(
        QueuedWithdrawal memory queuedWithdrawal
    )
        external
        pure
        returns (bytes32);

    /**
     * @notice Owner-only function that adds the provided Strategies to the 'whitelist' of strategies that stakers can deposit into
     * @param strategiesToWhitelist Strategies that will be added to the `strategyIsWhitelistedForDeposit` mapping (if they aren't in it already)
    */
    function addStrategiesToDepositWhitelist(IStrategy[] calldata strategiesToWhitelist) external;

    /**
     * @notice Owner-only function that removes the provided Strategies from the 'whitelist' of strategies that stakers can deposit into
     * @param strategiesToRemoveFromWhitelist Strategies that will be removed to the `strategyIsWhitelistedForDeposit` mapping (if they are in it)
    */
    function removeStrategiesFromDepositWhitelist(IStrategy[] calldata strategiesToRemoveFromWhitelist) external;

    /// @notice Returns the single, central Delegation contract of EigenLayer
    function delegation() external view returns (IDelegationManager);

    /// @notice Returns the single, central Slasher contract of EigenLayer
    function slasher() external view returns (ISlasher);

    /// @notice returns the enshrined, virtual 'beaconChainETH' Strategy
    function beaconChainETHStrategy() external view returns (IStrategy);

    /// @notice Returns the number of blocks that must pass between the time a withdrawal is queued and the time it can be completed
    function withdrawalDelayBlocks() external view returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../libraries/BeaconChainProofs.sol";
import "./IEigenPodManager.sol";
import "./IBeaconChainOracle.sol";

/**
 * @title The implementation contract used for restaking beacon chain ETH on EigenLayer 
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice The main functionalities are:
 * - creating new ETH validators with their withdrawal credentials pointed to this contract
 * - proving from beacon chain state roots that withdrawal credentials are pointed to this contract
 * - proving from beacon chain state roots the balances of ETH validators with their withdrawal credentials
 *   pointed to this contract
 * - updating aggregate balances in the EigenPodManager
 * - withdrawing eth when withdrawals are initiated
 * @dev Note that all beacon chain balances are stored as gwei within the beacon chain datastructures. We choose
 *   to account balances in terms of gwei in the EigenPod contract and convert to wei when making calls to other contracts
 */
interface IEigenPod {
    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        OVERCOMMITTED, // proven to be overcommitted to EigenLayer
        WITHDRAWN // withdrawn from the Beacon Chain
    }

    // this struct keeps track of PartialWithdrawalClaims
    struct PartialWithdrawalClaim {
        PARTIAL_WITHDRAWAL_CLAIM_STATUS status;
        // block at which the PartialWithdrawalClaim was created
        uint32 creationBlockNumber;
        // last block (inclusive) in which the PartialWithdrawalClaim can be fraudproofed
        uint32 fraudproofPeriodEndBlockNumber;
        // amount of ETH -- in Gwei -- to be withdrawn until completion of this claim
        uint64 partialWithdrawalAmountGwei;
    }

    enum PARTIAL_WITHDRAWAL_CLAIM_STATUS {
        REDEEMED,
        PENDING,
        FAILED
    }

    /// @notice The amount of eth, in gwei, that is restaked per validator
    function REQUIRED_BALANCE_GWEI() external view returns(uint64);

    /// @notice The amount of eth, in wei, that is restaked per validator
    function REQUIRED_BALANCE_WEI() external view returns(uint256);

    /// @notice this is a mapping of validator indices to a Validator struct containing pertinent info about the validator
    function validatorStatus(uint40 validatorIndex) external view returns(VALIDATOR_STATUS);

    /// @notice the amount of execution layer ETH in this contract that is staked in EigenLayer (i.e. withdrawn from beaconchain but not EigenLayer), 
    function restakedExecutionLayerGwei() external view returns(uint64);

    /// @notice Used to initialize the pointers to contracts crucial to the pod's functionality, in beacon proxy construction from EigenPodManager
    function initialize(address owner) external;

    /// @notice Called by EigenPodManager when the owner wants to create another ETH validator.
    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;

    /**
     * @notice Transfers `amountWei` in ether from this contract to the specified `recipient` address
     * @notice Called by EigenPodManager to withdrawBeaconChainETH that has been added to the EigenPod's balance due to a withdrawal from the beacon chain.
     * @dev Called during withdrawal or slashing.
     * @dev Note that this function is marked as non-reentrant to prevent the recipient calling back into it
     */
    function withdrawRestakedBeaconChainETH(address recipient, uint256 amount) external;

    /// @notice The single EigenPodManager for EigenLayer
    function eigenPodManager() external view returns (IEigenPodManager);

    /// @notice The owner of this EigenPod
    function podOwner() external view returns (address);

    /// @notice an indicator of whether or not the podOwner has ever "fully restaked" by successfully calling `verifyCorrectWithdrawalCredentials`.
    function hasRestaked() external view returns (bool);

    /// @notice block number of the most recent withdrawal
    function mostRecentWithdrawalBlockNumber() external view returns (uint64);


    ///@notice mapping that tracks proven partial withdrawals
    function provenPartialWithdrawal(uint40 validatorIndex, uint64 slot) external view returns (bool);

    /**
     * @notice This function verifies that the withdrawal credentials of the podOwner are pointed to
     * this contract. It also verifies the current (not effective) balance  of the validator.  It verifies the provided proof of the ETH validator against the beacon chain state
     * root, marks the validator as 'active' in EigenLayer, and credits the restaked ETH in Eigenlayer.
     * @param oracleBlockNumber is the Beacon Chain blockNumber whose state root the `proof` will be proven against.
     * @param validatorIndex is the index of the validator being proven, refer to consensus specs 
     * @param proofs is the bytes that prove the ETH validator's balance and withdrawal credentials against a beacon chain state root
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs 
     * for details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentialsAndBalance(
        uint64 oracleBlockNumber,
        uint40 validatorIndex,
        BeaconChainProofs.ValidatorFieldsAndBalanceProofs memory proofs,
        bytes32[] calldata validatorFields
    ) external;
    
    /**
     * @notice This function records an overcommitment of stake to EigenLayer on behalf of a certain ETH validator.
     *         If successful, the overcommitted balance is penalized (available for withdrawal whenever the pod's balance allows).
     *         The ETH validator's shares in the enshrined beaconChainETH strategy are also removed from the StrategyManager and undelegated.
     * @param oracleBlockNumber The oracleBlockNumber whose state root the `proof` will be proven against.
     *        Must be within `VERIFY_OVERCOMMITTED_WINDOW_BLOCKS` of the current block.
     * @param validatorIndex is the index of the validator being proven, refer to consensus specs 
     * @param proofs is the proof of the validator's balance and validatorFields in the balance tree and the balanceRoot to prove for
     * @param beaconChainETHStrategyIndex is the index of the beaconChainETHStrategy for the pod owner for the callback to 
     *                                    the StrategyManager in case it must be removed from the list of the podOwners strategies
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * @dev For more details on the Beacon Chain spec, see: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyOvercommittedStake(
        uint40 validatorIndex,
        BeaconChainProofs.ValidatorFieldsAndBalanceProofs calldata proofs,
        bytes32[] calldata validatorFields,
        uint256 beaconChainETHStrategyIndex,
        uint64 oracleBlockNumber
    ) external;

    /**
     * @notice This function records a full withdrawal on behalf of one of the Ethereum validators for this EigenPod
     * @param withdrawalProofs is the information needed to check the veracity of the block number and withdrawal being proven
     * @param validatorFieldsProof is the proof of the validator's fields in the validator tree
     * @param withdrawalFields are the fields of the withdrawal being proven
     * @param validatorFields are the fields of the validator being proven
     * @param beaconChainETHStrategyIndex is the index of the beaconChainETHStrategy for the pod owner for the callback to 
     *        the EigenPodManager to the StrategyManager in case it must be removed from the podOwner's list of strategies
     */
    function verifyAndProcessWithdrawal(
        BeaconChainProofs.WithdrawalProofs calldata withdrawalProofs, 
        bytes calldata validatorFieldsProof,
        bytes32[] calldata validatorFields,
        bytes32[] calldata withdrawalFields,
        uint256 beaconChainETHStrategyIndex,
        uint64 oracleBlockNumber
    ) external;

    /// @notice Called by the pod owner to withdraw the balance of the pod when `hasRestaked` is set to false
    function withdrawBeforeRestaking() external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

/**
 * @title Interface for the BeaconStateOracle contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface IBeaconChainOracle {
    /// @notice Largest blockNumber that has been confirmed by the oracle.
    function latestConfirmedOracleBlockNumber() external view returns(uint64);
    /// @notice Mapping: Beacon Chain blockNumber => the Beacon Chain state root at the specified blockNumber.
    /// @dev This will return `bytes32(0)` if the state root at the specified blockNumber is not yet confirmed.
    function beaconStateRootAtBlockNumber(uint64 blockNumber) external view returns(bytes32);

    /// @notice Mapping: address => whether or not the address is in the set of oracle signers.
    function isOracleSigner(address _oracleSigner) external view returns(bool);

    /// @notice Mapping: Beacon Chain blockNumber => oracle signer address => whether or not the oracle signer has voted on the state root at the blockNumber.
    function hasVoted(uint64 blockNumber, address oracleSigner) external view returns(bool);

    /// @notice Mapping: Beacon Chain blockNumber => state root => total number of oracle signer votes for the state root at the blockNumber. 
    function stateRootVotes(uint64 blockNumber, bytes32 stateRoot) external view returns(uint256);

    /// @notice Total number of members of the set of oracle signers.
    function totalOracleSigners() external view returns(uint256);

    /**
     * @notice Number of oracle signers that must vote for a state root in order for the state root to be confirmed.
     * Adjustable by this contract's owner through use of the `setThreshold` function.
     * @dev We note that there is an edge case -- when the threshold is adjusted downward, if a state root already has enough votes to meet the *new* threshold,
     * the state root must still receive one additional vote from an oracle signer to be confirmed. This behavior is intended, to minimize unexpected root confirmations.
     */
    function threshold() external view returns(uint256);

    /**
     * @notice Owner-only function used to modify the value of the `threshold` variable.
     * @param _threshold Desired new value for the `threshold` variable. Function will revert if this is set to zero.
     */
    function setThreshold(uint256 _threshold) external;

    /**
     * @notice Owner-only function used to add a signer to the set of oracle signers.
     * @param _oracleSigners Array of address to be added to the set.
     * @dev Function will have no effect on the i-th input address if `_oracleSigners[i]`is already in the set of oracle signers.
     */
    function addOracleSigners(address[] memory _oracleSigners) external;

    /**
     * @notice Owner-only function used to remove a signer from the set of oracle signers.
     * @param _oracleSigners Array of address to be removed from the set.
     * @dev Function will have no effect on the i-th input address if `_oracleSigners[i]`is already not in the set of oracle signers.
     */
    function removeOracleSigners(address[] memory _oracleSigners) external;

    /**
     * @notice Called by a member of the set of oracle signers to assert that the Beacon Chain state root is `stateRoot` at `blockNumber`.
     * @dev The state root will be finalized once the total number of votes *for this exact state root at this exact blockNumber* meets the `threshold` value.
     * @param blockNumber The Beacon Chain blockNumber of interest.
     * @param stateRoot The Beacon Chain state root that the caller asserts was the correct root, at the specified `blockNumber`.
     */
    function voteForBeaconChainStateRoot(uint64 blockNumber, bytes32 stateRoot) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../interfaces/IPauserRegistry.sol";

/**
 * @title Adds pausability to a contract, with pausing & unpausing controlled by the `pauser` and `unpauser` of a PauserRegistry contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice Contracts that inherit from this contract may define their own `pause` and `unpause` (and/or related) functions.
 * These functions should be permissioned as "onlyPauser" which defers to a `PauserRegistry` for determining access control.
 * @dev Pausability is implemented using a uint256, which allows up to 256 different single bit-flags; each bit can potentially pause different functionality.
 * Inspiration for this was taken from the NearBridge design here https://etherscan.io/address/0x3FEFc5A4B1c02f21cBc8D3613643ba0635b9a873#code.
 * For the `pause` and `unpause` functions we've implemented, if you pause, you can only flip (any number of) switches to on/1 (aka "paused"), and if you unpause,
 * you can only flip (any number of) switches to off/0 (aka "paused").
 * If you want a pauseXYZ function that just flips a single bit / "pausing flag", it will:
 * 1) 'bit-wise and' (aka `&`) a flag with the current paused state (as a uint256)
 * 2) update the paused state to this new value
 * @dev We note as well that we have chosen to identify flags by their *bit index* as opposed to their numerical value, so, e.g. defining `DEPOSITS_PAUSED = 3`
 * indicates specifically that if the *third bit* of `_paused` is flipped -- i.e. it is a '1' -- then deposits should be paused
 */

interface IPausable {
    /// @notice Address of the `PauserRegistry` contract that this contract defers to for determining access control (for pausing).
    function pauserRegistry() external view returns (IPauserRegistry); 

    /**
     * @notice This function is used to pause an EigenLayer contract's functionality.
     * It is permissioned to the `pauser` address, which is expected to be a low threshold multisig.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only pause functionality, and thus cannot 'unflip' any bit in `_paused` from 1 to 0.
     */
    function pause(uint256 newPausedStatus) external;

    /**
     * @notice Alias for `pause(type(uint256).max)`.
     */
    function pauseAll() external;

    /**
     * @notice This function is used to unpause an EigenLayer contract's functionality.
     * It is permissioned to the `unpauser` address, which is expected to be a high threshold multisig or governance contract.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only unpause functionality, and thus cannot 'flip' any bit in `_paused` from 0 to 1.
     */
    function unpause(uint256 newPausedStatus) external;

    /// @notice Returns the current paused status as a uint256.
    function paused() external view returns (uint256);

    /// @notice Returns 'true' if the `indexed`th bit of `_paused` is 1, and 'false' otherwise
    function paused(uint8 index) external view returns (bool);

    /// @notice Allows the unpauser to set a new pauser registry
    function setPauserRegistry(IPauserRegistry newPauserRegistry) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Minimal interface for an `Strategy` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice Custom `Strategy` implementations may expand extensively on this interface.
 */
interface IStrategy {
    /**
     * @notice Used to deposit tokens into this Strategy
     * @param token is the ERC20 token being deposited
     * @param amount is the amount of token being deposited
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * `depositIntoStrategy` function, and individual share balances are recorded in the strategyManager as well.
     * @return newShares is the number of new shares issued at the current exchange ratio.
     */
    function deposit(IERC20 token, uint256 amount) external returns (uint256);

    /**
     * @notice Used to withdraw tokens from this Strategy, to the `depositor`'s address
     * @param depositor is the address to receive the withdrawn funds
     * @param token is the ERC20 token being transferred out
     * @param amountShares is the amount of shares being withdrawn
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * other functions, and individual share balances are recorded in the strategyManager as well.
     */
    function withdraw(address depositor, IERC20 token, uint256 amountShares) external;

    /**
     * @notice Used to convert a number of shares to the equivalent amount of underlying tokens for this strategy.
     * @notice In contrast to `sharesToUnderlyingView`, this function **may** make state modifications
     * @param amountShares is the amount of shares to calculate its conversion into the underlying token
     * @return The amount of underlying tokens corresponding to the input `amountShares`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function sharesToUnderlying(uint256 amountShares) external returns (uint256);

    /**
     * @notice Used to convert an amount of underlying tokens to the equivalent amount of shares in this strategy.
     * @notice In contrast to `underlyingToSharesView`, this function **may** make state modifications
     * @param amountUnderlying is the amount of `underlyingToken` to calculate its conversion into strategy shares
     * @return The amount of underlying tokens corresponding to the input `amountShares`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function underlyingToShares(uint256 amountUnderlying) external returns (uint256);

    /**
     * @notice convenience function for fetching the current underlying value of all of the `user`'s shares in
     * this strategy. In contrast to `userUnderlyingView`, this function **may** make state modifications
     */
    function userUnderlying(address user) external returns (uint256);

     /**
     * @notice Used to convert a number of shares to the equivalent amount of underlying tokens for this strategy.
     * @notice In contrast to `sharesToUnderlying`, this function guarantees no state modifications
     * @param amountShares is the amount of shares to calculate its conversion into the underlying token
     * @return The amount of shares corresponding to the input `amountUnderlying`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function sharesToUnderlyingView(uint256 amountShares) external view returns (uint256);

    /**
     * @notice Used to convert an amount of underlying tokens to the equivalent amount of shares in this strategy.
     * @notice In contrast to `underlyingToShares`, this function guarantees no state modifications
     * @param amountUnderlying is the amount of `underlyingToken` to calculate its conversion into strategy shares
     * @return The amount of shares corresponding to the input `amountUnderlying`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function underlyingToSharesView(uint256 amountUnderlying) external view returns (uint256);

    /**
     * @notice convenience function for fetching the current underlying value of all of the `user`'s shares in
     * this strategy. In contrast to `userUnderlying`, this function guarantees no state modifications
     */
    function userUnderlyingView(address user) external view returns (uint256);

    /// @notice The underlying token for shares in this Strategy
    function underlyingToken() external view returns (IERC20);

    /// @notice The total number of extant shares in this Strategy
    function totalShares() external view returns (uint256);

    /// @notice Returns either a brief string explaining the strategy's goal & purpose, or a link to metadata that explains in more detail.
    function explanation() external view returns (string memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

/**
 * @title Interface for the primary 'slashing' contract for EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice See the `Slasher` contract itself for implementation details.
 */
interface ISlasher {
    // struct used to store information about the current state of an operator's obligations to middlewares they are serving
    struct MiddlewareTimes {
        // The update block for the middleware whose most recent update was earliest, i.e. the 'stalest' update out of all middlewares the operator is serving
        uint32 stalestUpdateBlock;
        // The latest 'serveUntilBlock' from all of the middleware that the operator is serving
        uint32 latestServeUntilBlock;
    }

    // struct used to store details relevant to a single middleware that an operator has opted-in to serving
    struct MiddlewareDetails {
        // the block before which the contract is allowed to slash the user
        uint32 contractCanSlashOperatorUntilBlock;
        // the block at which the middleware's view of the operator's stake was most recently updated
        uint32 latestUpdateBlock;
    }

    /**
     * @notice Gives the `contractAddress` permission to slash the funds of the caller.
     * @dev Typically, this function must be called prior to registering for a middleware.
     */
    function optIntoSlashing(address contractAddress) external;

    /**
     * @notice Used for 'slashing' a certain operator.
     * @param toBeFrozen The operator to be frozen.
     * @dev Technically the operator is 'frozen' (hence the name of this function), and then subject to slashing pending a decision by a human-in-the-loop.
     * @dev The operator must have previously given the caller (which should be a contract) the ability to slash them, through a call to `optIntoSlashing`.
     */
    function freezeOperator(address toBeFrozen) external;
    
    /**
     * @notice Removes the 'frozen' status from each of the `frozenAddresses`
     * @dev Callable only by the contract owner (i.e. governance).
     */
    function resetFrozenStatus(address[] calldata frozenAddresses) external;

    /**
     * @notice this function is a called by middlewares during an operator's registration to make sure the operator's stake at registration 
     *         is slashable until serveUntil
     * @param operator the operator whose stake update is being recorded
     * @param serveUntilBlock the block until which the operator's stake at the current block is slashable
     * @dev adds the middleware's slashing contract to the operator's linked list
     */
    function recordFirstStakeUpdate(address operator, uint32 serveUntilBlock) external;

    /**
     * @notice this function is a called by middlewares during a stake update for an operator (perhaps to free pending withdrawals)
     *         to make sure the operator's stake at updateBlock is slashable until serveUntil
     * @param operator the operator whose stake update is being recorded
     * @param updateBlock the block for which the stake update is being recorded
     * @param serveUntilBlock the block until which the operator's stake at updateBlock is slashable
     * @param insertAfter the element of the operators linked list that the currently updating middleware should be inserted after
     * @dev insertAfter should be calculated offchain before making the transaction that calls this. this is subject to race conditions, 
     *      but it is anticipated to be rare and not detrimental.
     */
    function recordStakeUpdate(address operator, uint32 updateBlock, uint32 serveUntilBlock, uint256 insertAfter) external;

    /**
     * @notice this function is a called by middlewares during an operator's deregistration to make sure the operator's stake at deregistration 
     *         is slashable until serveUntil
     * @param operator the operator whose stake update is being recorded
     * @param serveUntilBlock the block until which the operator's stake at the current block is slashable
     * @dev removes the middleware's slashing contract to the operator's linked list and revokes the middleware's (i.e. caller's) ability to
     * slash `operator` once `serveUntil` is reached
     */
    function recordLastStakeUpdateAndRevokeSlashingAbility(address operator, uint32 serveUntilBlock) external;

    /**
     * @notice Used to determine whether `staker` is actively 'frozen'. If a staker is frozen, then they are potentially subject to
     * slashing of their funds, and cannot cannot deposit or withdraw from the strategyManager until the slashing process is completed
     * and the staker's status is reset (to 'unfrozen').
     * @param staker The staker of interest.
     * @return Returns 'true' if `staker` themselves has their status set to frozen, OR if the staker is delegated
     * to an operator who has their status set to frozen. Otherwise returns 'false'.
     */
    function isFrozen(address staker) external view returns (bool);

    /// @notice Returns true if `slashingContract` is currently allowed to slash `toBeSlashed`.
    function canSlash(address toBeSlashed, address slashingContract) external view returns (bool);

    /// @notice Returns the block until which `serviceContract` is allowed to slash the `operator`.
    function contractCanSlashOperatorUntilBlock(address operator, address serviceContract) external view returns (uint32);

    /// @notice Returns the block at which the `serviceContract` last updated its view of the `operator`'s stake
    function latestUpdateBlock(address operator, address serviceContract) external view returns (uint32);

    /// @notice A search routine for finding the correct input value of `insertAfter` to `recordStakeUpdate` / `_updateMiddlewareList`.
    function getCorrectValueForInsertAfter(address operator, uint32 updateBlock) external view returns (uint256);

    /**
     * @notice Returns 'true' if `operator` can currently complete a withdrawal started at the `withdrawalStartBlock`, with `middlewareTimesIndex` used
     * to specify the index of a `MiddlewareTimes` struct in the operator's list (i.e. an index in `operatorToMiddlewareTimes[operator]`). The specified
     * struct is consulted as proof of the `operator`'s ability (or lack thereof) to complete the withdrawal.
     * This function will return 'false' if the operator cannot currently complete a withdrawal started at the `withdrawalStartBlock`, *or* in the event
     * that an incorrect `middlewareTimesIndex` is supplied, even if one or more correct inputs exist.
     * @param operator Either the operator who queued the withdrawal themselves, or if the withdrawing party is a staker who delegated to an operator,
     * this address is the operator *who the staker was delegated to* at the time of the `withdrawalStartBlock`.
     * @param withdrawalStartBlock The block number at which the withdrawal was initiated.
     * @param middlewareTimesIndex Indicates an index in `operatorToMiddlewareTimes[operator]` to consult as proof of the `operator`'s ability to withdraw
     * @dev The correct `middlewareTimesIndex` input should be computable off-chain.
     */
    function canWithdraw(address operator, uint32 withdrawalStartBlock, uint256 middlewareTimesIndex) external returns(bool);

    /**
     * operator => 
     *  [
     *      (
     *          the least recent update block of all of the middlewares it's serving/served, 
     *          latest time that the stake bonded at that update needed to serve until
     *      )
     *  ]
     */
    function operatorToMiddlewareTimes(address operator, uint256 arrayIndex) external view returns (MiddlewareTimes memory);

    /// @notice Getter function for fetching `operatorToMiddlewareTimes[operator].length`
    function middlewareTimesLength(address operator) external view returns (uint256);

    /// @notice Getter function for fetching `operatorToMiddlewareTimes[operator][index].stalestUpdateBlock`.
    function getMiddlewareTimesIndexBlock(address operator, uint32 index) external view returns(uint32);

    /// @notice Getter function for fetching `operatorToMiddlewareTimes[operator][index].latestServeUntil`.
    function getMiddlewareTimesIndexServeUntilBlock(address operator, uint32 index) external view returns(uint32);

    /// @notice Getter function for fetching `_operatorToWhitelistedContractsByUpdate[operator].size`.
    function operatorWhitelistedContractsLinkedListSize(address operator) external view returns (uint256);

    /// @notice Getter function for fetching a single node in the operator's linked list (`_operatorToWhitelistedContractsByUpdate[operator]`).
    function operatorWhitelistedContractsLinkedListEntry(address operator, address node) external view returns (bool, uint256, uint256);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "./IDelegationTerms.sol";

/**
 * @title The interface for the primary delegation contract for EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice  This is the contract for delegation in EigenLayer. The main functionalities of this contract are
 * - enabling anyone to register as an operator in EigenLayer
 * - allowing new operators to provide a DelegationTerms-type contract, which may mediate their interactions with stakers who delegate to them
 * - enabling any staker to delegate its stake to the operator of its choice
 * - enabling a staker to undelegate its assets from an operator (performed as part of the withdrawal process, initiated through the StrategyManager)
 */
interface IDelegationManager {

    /**
     * @notice This will be called by an operator to register itself as an operator that stakers can choose to delegate to.
     * @param dt is the `DelegationTerms` contract that the operator has for those who delegate to them.
     * @dev An operator can set `dt` equal to their own address (or another EOA address), in the event that they want to split payments
     * in a more 'trustful' manner.
     * @dev In the present design, once set, there is no way for an operator to ever modify the address of their DelegationTerms contract.
     */
    function registerAsOperator(IDelegationTerms dt) external;

    /**
     *  @notice This will be called by a staker to delegate its assets to some operator.
     *  @param operator is the operator to whom staker (msg.sender) is delegating its assets
     */
    function delegateTo(address operator) external;

    /**
     * @notice Delegates from `staker` to `operator`.
     * @dev requires that:
     * 1) if `staker` is an EOA, then `signature` is valid ECDSA signature from `staker`, indicating their intention for this action
     * 2) if `staker` is a contract, then `signature` must will be checked according to EIP-1271
     */
    function delegateToBySignature(address staker, address operator, uint256 expiry, bytes memory signature) external;

    /**
     * @notice Undelegates `staker` from the operator who they are delegated to.
     * @notice Callable only by the StrategyManager
     * @dev Should only ever be called in the event that the `staker` has no active deposits in EigenLayer.
     */
    function undelegate(address staker) external;

    /// @notice returns the address of the operator that `staker` is delegated to.
    function delegatedTo(address staker) external view returns (address);

    /// @notice returns the DelegationTerms of the `operator`, which may mediate their interactions with stakers who delegate to them.
    function delegationTerms(address operator) external view returns (IDelegationTerms);

    /// @notice returns the total number of shares in `strategy` that are delegated to `operator`.
    function operatorShares(address operator, IStrategy strategy) external view returns (uint256);

    /**
     * @notice Increases the `staker`'s delegated shares in `strategy` by `shares, typically called when the staker has further deposits into EigenLayer
     * @dev Callable only by the StrategyManager
     */
    function increaseDelegatedShares(address staker, IStrategy strategy, uint256 shares) external;

    /**
     * @notice Decreases the `staker`'s delegated shares in each entry of `strategies` by its respective `shares[i]`, typically called when the staker withdraws from EigenLayer
     * @dev Callable only by the StrategyManager
     */
    function decreaseDelegatedShares(
        address staker,
        IStrategy[] calldata strategies,
        uint256[] calldata shares
    ) external;

    /// @notice Returns 'true' if `staker` *is* actively delegated, and 'false' otherwise.
    function isDelegated(address staker) external view returns (bool);

    /// @notice Returns 'true' if `staker` is *not* actively delegated, and 'false' otherwise.
    function isNotDelegated(address staker) external view returns (bool);

    /// @notice Returns if an operator can be delegated to, i.e. it has called `registerAsOperator`.
    function isOperator(address operator) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity =0.8.12;

import "./Merkle.sol";
import "../libraries/Endian.sol";

//Utility library for parsing and PHASE0 beacon chain block headers
//SSZ Spec: https://github.com/ethereum/consensus-specs/blob/dev/ssz/simple-serialize.md#merkleization
//BeaconBlockHeader Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader
//BeaconState Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconstate
library BeaconChainProofs {
    // constants are the number of fields and the heights of the different merkle trees used in merkleizing beacon chain containers
    uint256 internal constant NUM_BEACON_BLOCK_HEADER_FIELDS = 5;
    uint256 internal constant BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT = 3;

    uint256 internal constant NUM_BEACON_BLOCK_BODY_FIELDS = 11;
    uint256 internal constant BEACON_BLOCK_BODY_FIELD_TREE_HEIGHT = 4;

    uint256 internal constant NUM_BEACON_STATE_FIELDS = 21;
    uint256 internal constant BEACON_STATE_FIELD_TREE_HEIGHT = 5;

    uint256 internal constant NUM_ETH1_DATA_FIELDS = 3;
    uint256 internal constant ETH1_DATA_FIELD_TREE_HEIGHT = 2;

    uint256 internal constant NUM_VALIDATOR_FIELDS = 8;
    uint256 internal constant VALIDATOR_FIELD_TREE_HEIGHT = 3;

    uint256 internal constant NUM_EXECUTION_PAYLOAD_HEADER_FIELDS = 15;
    uint256 internal constant EXECUTION_PAYLOAD_HEADER_FIELD_TREE_HEIGHT = 4;


    uint256 internal constant NUM_EXECUTION_PAYLOAD_FIELDS = 15;
    uint256 internal constant EXECUTION_PAYLOAD_FIELD_TREE_HEIGHT = 4;


    // HISTORICAL_ROOTS_LIMIT	 = 2**24, so tree height is 24
    uint256 internal constant HISTORICAL_ROOTS_TREE_HEIGHT = 24;

    // HISTORICAL_BATCH is root of state_roots and block_root, so number of leaves =  2^1
    uint256 internal constant HISTORICAL_BATCH_TREE_HEIGHT = 1;

    // SLOTS_PER_HISTORICAL_ROOT = 2**13, so tree height is 13
    uint256 internal constant STATE_ROOTS_TREE_HEIGHT = 13;
    uint256 internal constant BLOCK_ROOTS_TREE_HEIGHT = 13;


    uint256 internal constant NUM_WITHDRAWAL_FIELDS = 4;
    // tree height for hash tree of an individual withdrawal container
    uint256 internal constant WITHDRAWAL_FIELD_TREE_HEIGHT = 2;

    uint256 internal constant VALIDATOR_TREE_HEIGHT = 40;
    //refer to the eigenlayer-cli proof library.  Despite being the same dimensions as the validator tree, the balance tree is merkleized differently
    uint256 internal constant BALANCE_TREE_HEIGHT = 38;

    // MAX_WITHDRAWALS_PER_PAYLOAD = 2**4, making tree height = 4
    uint256 internal constant WITHDRAWALS_TREE_HEIGHT = 4;

    //in beacon block body
    uint256 internal constant EXECUTION_PAYLOAD_INDEX = 9;

    // in beacon block header
    uint256 internal constant STATE_ROOT_INDEX = 3;
    uint256 internal constant PROPOSER_INDEX_INDEX = 1;
    uint256 internal constant SLOT_INDEX = 0;
    uint256 internal constant BODY_ROOT_INDEX = 4;
    // in beacon state
    uint256 internal constant STATE_ROOTS_INDEX = 6;
    uint256 internal constant BLOCK_ROOTS_INDEX = 5;
    uint256 internal constant HISTORICAL_ROOTS_INDEX = 7;
    uint256 internal constant ETH_1_ROOT_INDEX = 8;
    uint256 internal constant VALIDATOR_TREE_ROOT_INDEX = 11;
    uint256 internal constant BALANCE_INDEX = 12;
    uint256 internal constant EXECUTION_PAYLOAD_HEADER_INDEX = 24;
    uint256 internal constant HISTORICAL_BATCH_STATE_ROOT_INDEX = 1;

    // in validator
    uint256 internal constant VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX = 1;
    uint256 internal constant VALIDATOR_BALANCE_INDEX = 2;
    uint256 internal constant VALIDATOR_SLASHED_INDEX = 3;
    uint256 internal constant VALIDATOR_WITHDRAWABLE_EPOCH_INDEX = 7;
    
    // in execution payload header
    uint256 internal constant BLOCK_NUMBER_INDEX = 6;
    uint256 internal constant WITHDRAWALS_ROOT_INDEX = 14;

    //in execution payload
    uint256 internal constant WITHDRAWALS_INDEX = 14;

    // in withdrawal
    uint256 internal constant WITHDRAWAL_VALIDATOR_INDEX_INDEX = 1;
    uint256 internal constant WITHDRAWAL_VALIDATOR_AMOUNT_INDEX = 3;

    //In historicalBatch
    uint256 internal constant HISTORICALBATCH_STATEROOTS_INDEX = 1;

    //Misc Constants
    uint256 internal constant SLOTS_PER_EPOCH = 32;

    bytes8 internal constant UINT64_MASK = 0xffffffffffffffff;



    struct WithdrawalProofs {
        bytes blockHeaderProof;
        bytes withdrawalProof;
        bytes slotProof;
        bytes executionPayloadProof;
        bytes blockNumberProof;
        uint64 blockHeaderRootIndex;
        uint64 withdrawalIndex;
        bytes32 blockHeaderRoot;
        bytes32 blockBodyRoot;
        bytes32 slotRoot;
        bytes32 blockNumberRoot;
        bytes32 executionPayloadRoot;
    }

    struct ValidatorFieldsAndBalanceProofs {
        bytes validatorFieldsProof;
        bytes validatorBalanceProof;
        bytes32 balanceRoot;
    }

    struct ValidatorFieldsProof {
        bytes validatorProof;
        uint40 validatorIndex;
    }

    /**
     * 
     * @notice This function is parses the balanceRoot to get the uint64 balance of a validator.  During merkleization of the
     * beacon state balance tree, four uint64 values (making 32 bytes) are grouped together and treated as a single leaf in the merkle tree. Thus the
     * validatorIndex mod 4 is used to determine which of the four uint64 values to extract from the balanceRoot.
     * @param validatorIndex is the index of the validator being proven for.
     * @param balanceRoot is the combination of 4 validator balances being proven for.
     * @return The validator's balance, in Gwei
     */
   function getBalanceFromBalanceRoot(uint40 validatorIndex, bytes32 balanceRoot) internal pure returns (uint64) {
        uint256 bitShiftAmount = (validatorIndex % 4) * 64;
        bytes32 validatorBalanceLittleEndian = bytes32((uint256(balanceRoot) << bitShiftAmount));
        uint64 validatorBalance = Endian.fromLittleEndianUint64(validatorBalanceLittleEndian);
        return validatorBalance;
    }

    /**
     * @notice This function verifies merkle proofs of the fields of a certain validator against a beacon chain state root
     * @param validatorIndex the index of the proven validator
     * @param beaconStateRoot is the beacon chain state root to be proven against.
     * @param proof is the data used in proving the validator's fields
     * @param validatorFields the claimed fields of the validator
     */
    function verifyValidatorFields(
        uint40 validatorIndex,
        bytes32 beaconStateRoot,
        bytes calldata proof, 
        bytes32[] calldata validatorFields
    ) internal view {
        
        require(validatorFields.length == 2**VALIDATOR_FIELD_TREE_HEIGHT, "BeaconChainProofs.verifyValidatorFields: Validator fields has incorrect length");

        /**
         * Note: the length of the validator merkle proof is BeaconChainProofs.VALIDATOR_TREE_HEIGHT + 1.
         * There is an additional layer added by hashing the root with the length of the validator list
         */
        require(proof.length == 32 * ((VALIDATOR_TREE_HEIGHT + 1) + BEACON_STATE_FIELD_TREE_HEIGHT), "BeaconChainProofs.verifyValidatorFields: Proof has incorrect length");
        uint256 index = (VALIDATOR_TREE_ROOT_INDEX << (VALIDATOR_TREE_HEIGHT + 1)) | uint256(validatorIndex);
        // merkleize the validatorFields to get the leaf to prove
        bytes32 validatorRoot = Merkle.merkleizeSha256(validatorFields);

        // verify the proof of the validatorRoot against the beaconStateRoot
        require(Merkle.verifyInclusionSha256(proof, beaconStateRoot, validatorRoot, index), "BeaconChainProofs.verifyValidatorFields: Invalid merkle proof");
    }

    /**
     * @notice This function verifies merkle proofs of the balance of a certain validator against a beacon chain state root
     * @param validatorIndex the index of the proven validator
     * @param beaconStateRoot is the beacon chain state root to be proven against.
     * @param proof is the proof of the balance against the beacon chain state root
     * @param balanceRoot is the serialized balance used to prove the balance of the validator (refer to `getBalanceFromBalanceRoot` above for detailed explanation)
     */
    function verifyValidatorBalance(
        uint40 validatorIndex,
        bytes32 beaconStateRoot,
        bytes calldata proof,
        bytes32 balanceRoot
    ) internal view {
        require(proof.length == 32 * ((BALANCE_TREE_HEIGHT + 1) + BEACON_STATE_FIELD_TREE_HEIGHT), "BeaconChainProofs.verifyValidatorBalance: Proof has incorrect length");

        /**
        * the beacon state's balance list is a list of uint64 values, and these are grouped together in 4s when merkleized.  
        * Therefore, the index of the balance of a validator is validatorIndex/4
        */
        uint256 balanceIndex = uint256(validatorIndex/4);
        balanceIndex = (BALANCE_INDEX << (BALANCE_TREE_HEIGHT + 1)) | balanceIndex;

        require(Merkle.verifyInclusionSha256(proof, beaconStateRoot, balanceRoot, balanceIndex), "BeaconChainProofs.verifyValidatorBalance: Invalid merkle proof");
    }

    /**
     * @notice This function verifies the slot and the withdrawal fields for a given withdrawal
     * @param beaconStateRoot is the beacon chain state root to be proven against.
     * @param proofs is the provided set of merkle proofs
     * @param withdrawalFields is the serialized withdrawal container to be proven
     */
    function verifyWithdrawalProofs(
        bytes32 beaconStateRoot,
        WithdrawalProofs calldata proofs,
        bytes32[] calldata withdrawalFields
    ) internal view {
        require(withdrawalFields.length == 2**WITHDRAWAL_FIELD_TREE_HEIGHT, "BeaconChainProofs.verifyWithdrawalProofs: withdrawalFields has incorrect length");

        require(proofs.blockHeaderRootIndex < 2**BLOCK_ROOTS_TREE_HEIGHT, "BeaconChainProofs.verifyWithdrawalProofs: blockRootIndex is too large");
        require(proofs.withdrawalIndex < 2**WITHDRAWALS_TREE_HEIGHT, "BeaconChainProofs.verifyWithdrawalProofs: withdrawalIndex is too large");
       
        // verify the block header proof length
        require(proofs.blockHeaderProof.length == 32 * (BEACON_STATE_FIELD_TREE_HEIGHT + BLOCK_ROOTS_TREE_HEIGHT),
            "BeaconChainProofs.verifyWithdrawalProofs: blockHeaderProof has incorrect length");
        require(proofs.withdrawalProof.length == 32 * (EXECUTION_PAYLOAD_HEADER_FIELD_TREE_HEIGHT + WITHDRAWALS_TREE_HEIGHT + 1),
            "BeaconChainProofs.verifyWithdrawalProofs: withdrawalProof has incorrect length");
        require(proofs.executionPayloadProof.length == 32 * (BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT + BEACON_BLOCK_BODY_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyWithdrawalProofs: executionPayloadProof has incorrect length");
        require(proofs.slotProof.length == 32 * (BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyWithdrawalProofs: slotProof has incorrect length");
        require(proofs.blockNumberProof.length == 32 * (EXECUTION_PAYLOAD_HEADER_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyWithdrawalProofs: blockNumberProof has incorrect length");


        /**
         * Computes the block_header_index relative to the beaconStateRoot.  It concatenates the indexes of all the
         * intermediate root indexes from the bottom of the sub trees (the block header container) to the top of the tree
         */
        uint256 blockHeaderIndex = BLOCK_ROOTS_INDEX << (BLOCK_ROOTS_TREE_HEIGHT)  | uint256(proofs.blockHeaderRootIndex);
        // Verify the blockHeaderRoot against the beaconStateRoot
        require(Merkle.verifyInclusionSha256(proofs.blockHeaderProof, beaconStateRoot, proofs.blockHeaderRoot, blockHeaderIndex),
            "BeaconChainProofs.verifyWithdrawalProofs: Invalid block header merkle proof");

        //Next we verify the slot against the blockHeaderRoot
        require(Merkle.verifyInclusionSha256(proofs.slotProof, proofs.blockHeaderRoot, proofs.slotRoot, SLOT_INDEX), "BeaconChainProofs.verifyWithdrawalProofs: Invalid slot merkle proof");

        // Next we verify the executionPayloadRoot against the blockHeaderRoot
        uint256 executionPayloadIndex = BODY_ROOT_INDEX << (BEACON_BLOCK_BODY_FIELD_TREE_HEIGHT)| EXECUTION_PAYLOAD_INDEX ;
        require(Merkle.verifyInclusionSha256(proofs.executionPayloadProof, proofs.blockHeaderRoot, proofs.executionPayloadRoot, executionPayloadIndex),
            "BeaconChainProofs.verifyWithdrawalProofs: Invalid executionPayload merkle proof");

        // Next we verify the blockNumberRoot against the executionPayload root
        require(Merkle.verifyInclusionSha256(proofs.blockNumberProof, proofs.executionPayloadRoot, proofs.blockNumberRoot, BLOCK_NUMBER_INDEX),
            "BeaconChainProofs.verifyWithdrawalProofs: Invalid blockNumber merkle proof");

        /**
         * Next we verify the withdrawal fields against the blockHeaderRoot:
         * First we compute the withdrawal_index relative to the blockHeaderRoot by concatenating the indexes of all the 
         * intermediate root indexes from the bottom of the sub trees (the withdrawal container) to the top, the blockHeaderRoot.
         * Then we calculate merkleize the withdrawalFields container to calculate the the withdrawalRoot.
         * Finally we verify the withdrawalRoot against the executionPayloadRoot.
         */
        uint256 withdrawalIndex = WITHDRAWALS_INDEX << (WITHDRAWALS_TREE_HEIGHT + 1) | uint256(proofs.withdrawalIndex);
        bytes32 withdrawalRoot = Merkle.merkleizeSha256(withdrawalFields);
        require(Merkle.verifyInclusionSha256(proofs.withdrawalProof, proofs.executionPayloadRoot, withdrawalRoot, withdrawalIndex),
            "BeaconChainProofs.verifyWithdrawalProofs: Invalid withdrawal merkle proof");
    }

}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

/**
 * @title Interface for the `PauserRegistry` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface IPauserRegistry {
    /// @notice Mapping of addresses to whether they hold the pauser role.
    function isPauser(address pauser) external view returns (bool);

    /// @notice Unique address that holds the unpauser role. Capable of changing *both* the pauser and unpauser addresses.
    function unpauser() external view returns (address);
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "./IStrategy.sol";

/**
 * @title Abstract interface for a contract that helps structure the delegation relationship.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice The gas budget provided to this contract in calls from EigenLayer contracts is limited.
 */
interface IDelegationTerms {
    function payForService(IERC20 token, uint256 amount) external payable;

    function onDelegationWithdrawn(
        address delegator,
        IStrategy[] memory stakerStrategyList,
        uint256[] memory stakerShares
    ) external returns(bytes memory);

    function onDelegationReceived(
        address delegator,
        IStrategy[] memory stakerStrategyList,
        uint256[] memory stakerShares
    ) external returns(bytes memory);
}

// SPDX-License-Identifier: BUSL-1.1
// Adapted from OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/MerkleProof.sol)

pragma solidity =0.8.12;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library Merkle {
    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is 
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     * 
     * Note this is for a Merkle tree using the keccak/sha3 hash function
     */
    function verifyInclusionKeccak(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal pure returns (bool) {
        return processInclusionProofKeccak(proof, leaf, index) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is 
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     * 
     * _Available since v4.4._
     * 
     * Note this is for a Merkle tree using the keccak/sha3 hash function
     */
    function processInclusionProofKeccak(bytes memory proof, bytes32 leaf, uint256 index) internal pure returns (bytes32) {
        require(proof.length != 0 && proof.length % 32 == 0, "Merkle.processInclusionProofKeccak: proof length should be a non-zero multiple of 32");
        bytes32 computedHash = leaf;
        for (uint256 i = 32; i <= proof.length; i+=32) {
            if(index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, computedHash)
                    mstore(0x20, mload(add(proof, i)))
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, computedHash)
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }            
            }
        }
        return computedHash;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is 
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     * 
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function verifyInclusionSha256(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bool) {
        return processInclusionProofSha256(proof, leaf, index) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is 
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * _Available since v4.4._
     * 
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function processInclusionProofSha256(bytes memory proof, bytes32 leaf, uint256 index) internal view returns (bytes32) {
        require(proof.length != 0 && proof.length % 32 == 0, "Merkle.processInclusionProofSha256: proof length should be a non-zero multiple of 32");
        bytes32[1] memory computedHash = [leaf];
        for (uint256 i = 32; i <= proof.length; i+=32) {
            if(index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, mload(computedHash))
                    mstore(0x20, mload(add(proof, i)))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) {revert(0, 0)}
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, mload(computedHash))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) {revert(0, 0)}
                    index := div(index, 2)
                }            
            }
        }
        return computedHash[0];
    }

    /**
     @notice this function returns the merkle root of a tree created from a set of leaves using sha256 as its hash function
     @param leaves the leaves of the merkle tree
     @return The computed Merkle root of the tree.
     @dev A pre-condition to this function is that leaves.length is a power of two.  If not, the function will merkleize the inputs incorrectly.
     */ 
    function merkleizeSha256(
        bytes32[] memory leaves
    ) internal pure returns (bytes32) {
        //there are half as many nodes in the layer above the leaves
        uint256 numNodesInLayer = leaves.length / 2;
        //create a layer to store the internal nodes
        bytes32[] memory layer = new bytes32[](numNodesInLayer);
        //fill the layer with the pairwise hashes of the leaves
        for (uint i = 0; i < numNodesInLayer; i++) {
            layer[i] = sha256(abi.encodePacked(leaves[2*i], leaves[2*i+1]));
        }
        //the next layer above has half as many nodes
        numNodesInLayer /= 2;
        //while we haven't computed the root
        while (numNodesInLayer != 0) {
            //overwrite the first numNodesInLayer nodes in layer with the pairwise hashes of their children
            for (uint i = 0; i < numNodesInLayer; i++) {
                layer[i] = sha256(abi.encodePacked(layer[2*i], layer[2*i+1]));
            }
            //the next layer above has half as many nodes
            numNodesInLayer /= 2;
        }
        //the first node in the layer is the root
        return layer[0];
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

library Endian {
    /**
     * @notice Converts a little endian-formatted uint64 to a big endian-formatted uint64
     * @param lenum little endian-formatted uint64 input, provided as 'bytes32' type
     * @return n The big endian-formatted uint64
     * @dev Note that the input is formatted as a 'bytes32' type (i.e. 256 bits), but it is immediately truncated to a uint64 (i.e. 64 bits)
     * through a right-shift/shr operation.
     */
    function fromLittleEndianUint64(
        bytes32 lenum
    ) internal pure returns (uint64 n) {
        // the number needs to be stored in little-endian encoding (ie in bytes 0-8)
        n = uint64(uint256(lenum >> 192));
        return
            (n >> 56) |
            ((0x00FF000000000000 & n) >> 40) |
            ((0x0000FF0000000000 & n) >> 24) |
            ((0x000000FF00000000 & n) >> 8) |
            ((0x00000000FF000000 & n) << 8) |
            ((0x0000000000FF0000 & n) << 24) |
            ((0x000000000000FF00 & n) << 40) |
            ((0x00000000000000FF & n) << 56);
    }
}