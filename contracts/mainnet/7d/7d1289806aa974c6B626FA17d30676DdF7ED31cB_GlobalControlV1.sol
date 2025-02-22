// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

/**
 * Copyright (C) 2022 National Australia Bank Limited
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not,
 * see <https://www.gnu.org/licenses/>.
 */

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interface/IGlobalControlV1.sol";
import "../../stablecoin-core/V1/DenyList/interface/IERC20DeniableUpgradeableV1.sol";
import "../../common/V1/library/LibErrorsV1.sol";
import "../../common/V1/FundsRescue/FundsRescuableUpgradeableV1.sol";

/**
 * @title Global Control (V1)
 * @author National Australia Bank Limited
 * @notice The Global Control contract acts as a centralised point of control for participating
 * contracts (e.g. stablecoins). The Global Control contract is concerned with DenyList management, pause
 * control and maintaining a contract registry.
 *
 * The Global Control contract Role Based Access Control employs following roles:
 *
 * - UPGRADER_ROLE
 * - PAUSER_ROLE
 * - ACCESS_CONTROL_ADMIN_ROLE
 * - PARTICIPANT_ADMIN_ROLE
 * - GLOBAL_PAUSE_ADMIN_ROLE
 * - GLOBAL_DENYLIST_ADMIN_ROLE
 * - GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE
 * - GLOBAL_FUNDS_RESCUE_ROLE
 *
 * The relationship between the Global Control's own pause state and the Global Pause being active is such that
 * when the Global Control contract is paused, Global Pause is automatically activated (but not vice versa).
 * It is valid for the Global Pause to be active and the Global Control contract to not be paused. This is useful
 * in a range of situations, for example, if we wish to add additional addresses to the DenyList.
 *
 * @dev The Global Control contract will not push, write, or update the state in participating smart contracts.
 *
 * Participation state entails the management of participating contract addresses as well as making
 * functions available to participating contracts.
 *
 * DenyList management entails the management of addresses in the DenyList as well as making functions
 * available to participating contracts.
 *
 * Pause control entails both the activation and deactivation of either the Global Pause feature or
 * this contract's pause state control, as well as making functions available to participating contracts.
 *
 * In {GlobalControlV1}, a function caller will be only checked against Global DenyList before the function proceeds
 * and not against any local DenyList.
 */
contract GlobalControlV1 is
    Initializable,
    IGlobalControlV1,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    FundsRescuableUpgradeableV1,
    UUPSUpgradeable
{
    /// Constants

    /**
     * @notice The Access Control identifier for the Upgrader Role.
     *
     * An account with "UPGRADER_ROLE" can upgrade the implementation contract address.
     *
     * @dev This constant holds the hash of the string "UPGRADER_ROLE".
     */
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /**
     * @notice  The Access Control identifier for the Pauser Role.
     *
     * An account with "PAUSER_ROLE" can pause and unpause the Global Control contract. When the
     * Global Control contract has been paused, Global Pause is also activated.
     *
     * @dev This constant holds the hash of the string "PAUSER_ROLE".
     */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @notice The Access Control identifier for the Access Control Admin Role.
     *
     * An account with "ACCESS_CONTROL_ADMIN_ROLE" can assign and revoke all the roles except itself and
     * the "UPGRADER_ROLE".
     *
     * @dev This constant holds the hash of the string "ACCESS_CONTROL_ADMIN_ROLE".
     */
    bytes32 public constant ACCESS_CONTROL_ADMIN_ROLE = keccak256("ACCESS_CONTROL_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Participant Admin Role.
     *
     * An account with "PARTICIPANT_ADMIN_ROLE" can add and remove addresses from the Participant List.
     *
     * @dev This constant holds the hash of the string "PARTICIPANT_ADMIN_ROLE".
     */
    bytes32 public constant PARTICIPANT_ADMIN_ROLE = keccak256("PARTICIPANT_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Global Pause Admin Role.
     *
     * An account with "GLOBAL_PAUSE_ADMIN_ROLE" can activate and deactivate Global Pause.
     *
     * @dev This constant holds the hash of the string "GLOBAL_PAUSE_ADMIN_ROLE".
     */
    bytes32 public constant GLOBAL_PAUSE_ADMIN_ROLE = keccak256("GLOBAL_PAUSE_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Global DenyList Admin Role.
     *
     * An account with "GLOBAL_DENYLIST_ADMIN_ROLE" can add and remove addresses from the Global DenyList.
     *
     * @dev This constant holds the hash of the string "GLOBAL_DENYLIST_ADMIN_ROLE".
     */
    bytes32 public constant GLOBAL_DENYLIST_ADMIN_ROLE = keccak256("GLOBAL_DENYLIST_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Global DenyList Funds Retire Role.
     *
     * An account with "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" can {burn} part or all funds of an address in the
     * Global DenyList.
     *
     * @dev This constant holds the hash of the string "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE".
     */
    bytes32 public constant GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE = keccak256("GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE");

    /**
     * @notice The Access Control identifier for the Global Funds Rescue Role.
     *
     * An account with "GLOBAL_FUNDS_RESCUE_ROLE" can rescue funds from the participant contracts and the
     * Global Control contract.
     *
     * @dev This constant holds the hash of the string "GLOBAL_FUNDS_RESCUE_ROLE".
     */
    bytes32 public constant GLOBAL_FUNDS_RESCUE_ROLE = keccak256("GLOBAL_FUNDS_RESCUE_ROLE");

    /// State

    /**
     * @notice This is a dictionary that holds all the addresses that are in the Global DenyList.
     *
     * @dev In the mapping addresses that are in the Global DenyList, point to a "True" value.
     *
     * Key: account (address).
     * Value: state (bool).
     *
     */
    mapping(address => bool) private _globalDenyList;

    /**
     * @notice This is a dictionary that holds all the participating contracts in cohort of participating
     * smart contracts.
     *
     * @dev In this mapping, addresses that are in the Global Participant List point to a "True" value.
     *
     * Key: participant contract (address).
     * Value: state (bool).
     *
     */
    mapping(address => bool) private _globalParticipantList;

    /**
     * @notice This is a flag used to keep the status of the Global Pause.
     *
     * @dev If it is "True", Global Pause is active. If it is "False", Global Pause is inactive.
     */
    bool private _globalPauseIsActive;

    /// Events

    /**
     * @notice This is an event that logs the addition of a contract to the Participant List.
     * @param sender The (indexed) address that added the contract.
     * @param smartContract The address that was added to the Participant List.
     */
    event ParticipantAdded(address indexed sender, address smartContract);

    /**
     * @notice This is an event that logs the removal of a contract from the Participant List.
     * @param sender The (indexed) address that removed the contract.
     * @param smartContract The address that was removed from the Participant List.
     */
    event ParticipantRemoved(address indexed sender, address smartContract);

    /**
     * @notice This is an event that logs when Global Pause is activated.
     * @param sender The (indexed) address that activated Global Pause.
     */
    event GlobalPauseIssued(address indexed sender);

    /**
     * @notice This is an event that logs when Global Pause is deactivated.
     * @param sender The (indexed) address that deactivated Global Pause.
     */
    event GlobalPauseCleared(address indexed sender);

    /**
     * @notice This is an event that logs when an address is added to the Global DenyList.
     * @param sender The (indexed) address that added the address to the Global DenyList.
     * @param account The (indexed) address that was added to the Global DenyList.
     */
    event GlobalDenyListAddressAdded(address indexed sender, address indexed account);

    /**
     * @notice This is an event that logs when an address is removed from the Global DenyList.
     * @param sender The (indexed) address that removed the address from the Global DenyList.
     * @param account The (indexed) address that was removed from the Global DenyList.
     */
    event GlobalDenyListAddressRemoved(address indexed sender, address indexed account);

    /**
     * @notice This is an event that logs when funds are removed from a holder in the DenyList.
     * @param sender The (indexed) address of "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" holder which enacted the remove.
     * @param holder The (indexed) address of the asset holder.
     * @param asset The (indexed) asset address that was removed from the holder's balance.
     * @param amount The amount that was removed from the holder's balance.
     */
    event DenyListFundsERC20Retired(
        address indexed sender,
        address indexed holder,
        address indexed asset,
        uint256 amount
    );

    /// Modifiers

    /**
     * @notice Functions defined with this modifier confirm that the account address is not in the Global
     * DenyList before continuing.
     * @dev Reverts when the account is in the Global DenyList.
     * @param account The address of the account to be assessed.
     */
    modifier notInGlobalDenyList(address account) virtual {
        require(!isGlobalDenyListed(account), "Address is in Global DenyList");
        _;
    }

    /// Functions

    /**
     * @notice This function acts as the constructor of the contract.
     * @dev This function disables the initializers.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice This function initializes the Global Control contract by validating that the privileged addresses
     * are non-zero, initialising inherited libraries (for example the Access Control library), configuring role
     * grant privileges, and granting privileged roles.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked once (controlled via the initializer modifier).
     * - Non-zero address `upgraderRoleAddress`.
     * - Non-zero address `pauserRoleAddress`.
     * - Non-zero address `accessControlAdminRoleAddress`.
     * - Non-zero address `participantAdminRoleAddress`.
     * - Non-zero address `globalPauseAdminRoleAddress`.
     * - Non-zero address `globalDenyListAdminRoleAddress`.
     * - Non-zero address `globalDenyListFundsRetireRoleAddress`.
     * - Non-zero address `globalFundsRescueRoleAddress`.
     *
     * The `upgraderRoleAddress` address will also receive the "DEFAULT_ADMIN_ROLE". An account with
     * "DEFAULT_ADMIN_ROLE" can manage all roles, unless {_setRoleAdmin} is used to appoint an alternate
     * admin role.
     *
     * @param upgraderRoleAddress The account to be granted the "UPGRADER_ROLE".
     * @param pauserRoleAddress The account to be granted the "PAUSER_ROLE".
     * @param accessControlAdminRoleAddress The account to be granted the "ACCESS_CONTROL_ADMIN_ROLE".
     * @param participantAdminRoleAddress The account to be granted the "PARTICIPANT_ADMIN_ROLE".
     * @param globalPauseAdminRoleAddress The account to be granted the "GLOBAL_PAUSE_ADMIN_ROLE".
     * @param globalDenyListAdminRoleAddress The account to be granted the "GLOBAL_DENYLIST_ADMIN_ROLE".
     * @param globalDenyListFundsRetireRoleAddress The account to be granted the "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE".
     * @param globalFundsRescueRoleAddress The account to be granted the "GLOBAL_FUNDS_RESCUE_ROLE".
     */
    function initialize(
        address upgraderRoleAddress,
        address pauserRoleAddress,
        address accessControlAdminRoleAddress,
        address participantAdminRoleAddress,
        address globalPauseAdminRoleAddress,
        address globalDenyListAdminRoleAddress,
        address globalDenyListFundsRetireRoleAddress,
        address globalFundsRescueRoleAddress
    ) external initializer {
        if (upgraderRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("upgraderRoleAddress");
        }
        if (pauserRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("pauserRoleAddress");
        }
        if (accessControlAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("accessControlAdminRoleAddress");
        }
        if (participantAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("participantAdminRoleAddress");
        }
        if (globalPauseAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalPauseAdminRoleAddress");
        }
        if (globalDenyListAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalDenyListAdminRoleAddress");
        }
        if (globalDenyListFundsRetireRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalDenyListFundsRetireRoleAddress");
        }
        if (globalFundsRescueRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalFundsRescueRoleAddress");
        }

        // Init inherited dependencies.
        __UUPSUpgradeable_init();
        __Pausable_init();
        __FundsRescuableUpgradeableV1_init();
        __AccessControlEnumerable_init();

        // Grant access control admin role control.
        _setRoleAdmin(ACCESS_CONTROL_ADMIN_ROLE, UPGRADER_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        _setRoleAdmin(PARTICIPANT_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        _setRoleAdmin(GLOBAL_PAUSE_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(GLOBAL_DENYLIST_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(GLOBAL_FUNDS_RESCUE_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        // Grant roles.
        _grantRole(DEFAULT_ADMIN_ROLE, upgraderRoleAddress);
        _grantRole(UPGRADER_ROLE, upgraderRoleAddress);
        _grantRole(PAUSER_ROLE, pauserRoleAddress);
        _grantRole(ACCESS_CONTROL_ADMIN_ROLE, accessControlAdminRoleAddress);

        _grantRole(PARTICIPANT_ADMIN_ROLE, participantAdminRoleAddress);

        _grantRole(GLOBAL_PAUSE_ADMIN_ROLE, globalPauseAdminRoleAddress);
        _grantRole(GLOBAL_DENYLIST_ADMIN_ROLE, globalDenyListAdminRoleAddress);
        _grantRole(GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE, globalDenyListFundsRetireRoleAddress);
        _grantRole(GLOBAL_FUNDS_RESCUE_ROLE, globalFundsRescueRoleAddress);

        // Initialise state.
        _globalPauseIsActive = false;
    }

    /**
     * @notice This function is used to confirm whether an account is present on the Global Control DenyList.
     * @dev This function is a getter for the boolean value in Global Control DenyList for a particular address.
     * @param inspect The account address to be assessed.
     * @return The function returns a value of "True" if an address is present in the Global DenyList.
     */
    function isGlobalDenyListed(address inspect) public view returns (bool) {
        return _globalDenyList[inspect];
    }

    /**
     * @notice A function used to remove funds from a given address.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - `asset` should be a member of the Global Participant List.
     * - Global Pause is inactive.
     * - The sender of this function is not in Global DenyList. Participant smart contract DenyList not checked.
     * - An account must have the "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" to call this function.
     *
     * This function emits a {DenyListFundsERC20Retired} event, signalling that the funds
     * were removed from the specified address.
     *
     * @param participantSmartContract The asset that will be removed from the `account`.
     * @param account The address from which the funds are to be removed.
     * @param amount The amount of the `asset` that was removed from the `account` address.
     */
    function fundsRetireERC20(
        address participantSmartContract,
        address account,
        uint256 amount
    ) external whenNotPaused notInGlobalDenyList(_msgSender()) onlyRole(GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE) {
        require(_globalParticipantList[participantSmartContract], "Asset is not a participant");
        IERC20DeniableUpgradeableV1 participantSmartContractInstance = IERC20DeniableUpgradeableV1(
            participantSmartContract
        );
        emit DenyListFundsERC20Retired(_msgSender(), account, participantSmartContract, amount);
        participantSmartContractInstance.fundsRetire(account, amount);
    }

    /**
     * @notice This function is used to rescue ETH from Global Control contract.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - 'beneficiary' is not listed in the Global DenyList.
     * - `beneficiary` is non-zero address. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueETH})
     * - `amount` is greater than 0. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueETH})
     * - `amount` is less than or equal to the ETH balance of {GlobalControlV1}.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function emits a {FundsRescuedETH} event (as part of {FundsRescuableUpgradeableV1.fundsRescueETH}).
     *
     * This function could potentially call into an external contract. The controls for such interaction are listed
     * in {FundsRescuableUpgradeableV1.fundsRescueETH}.
     *
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function fundsRescueETH(
        address beneficiary,
        uint256 amount
    )
        public
        virtual
        override(FundsRescuableUpgradeableV1, IFundsRescuableUpgradeableV1)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        notInGlobalDenyList(beneficiary)
        onlyRole(GLOBAL_FUNDS_RESCUE_ROLE)
    {
        super.fundsRescueETH(beneficiary, amount); // In {FundsRescuableUpgradeableV1}
    }

    /**
     * @notice This function is used to rescue ERC20 tokens from the Global Control contract.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - 'beneficiary' is not listed in the Global DenyList.
     * - 'asset is not listed in the Global DenyList.
     * - `beneficiary` is non-zero address. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueERC20})
     * - `amount` is greater than 0. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueERC20})
     * - `amount` is less than or equal to the `asset` balance of {GlobalControlV1}.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function emits a {FundsRescuedERC20} event (as part of {FundsRescuableUpgradeableV1.fundsRescueERC20}).
     *
     * This function could potentially call into an external contract. The controls for such interaction are listed
     * in {FundsRescuableUpgradeableV1.fundsRescueERC20}.
     *
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of the foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function fundsRescueERC20(
        address beneficiary,
        address asset,
        uint256 amount
    )
        public
        virtual
        override(FundsRescuableUpgradeableV1, IFundsRescuableUpgradeableV1)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        notInGlobalDenyList(beneficiary)
        notInGlobalDenyList(asset)
        onlyRole(GLOBAL_FUNDS_RESCUE_ROLE)
    {
        super.fundsRescueERC20(beneficiary, asset, amount); // In {FundsRescuableUpgradeableV1}
    }

    /**
     * @notice This function is used to rescue ERC20 tokens from a participant contract.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - `participantSmartContract` should be a member of the Global Participant List.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Limits interactions to only contracts that are in the Participant List.
     *
     * This function will fail if the Global Pause is active. However, the check is not implemented
     * at the Global Control contract level. The participant contract that implements {fundsRescueERC20}
     * should implement the check and revert if the Global Pause is active.
     *
     * @param participantSmartContract The contract address from which the asset is extracted.
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of the foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function participantFundsRescueERC20(
        address participantSmartContract,
        address beneficiary,
        address asset,
        uint256 amount
    ) external virtual whenNotPaused notInGlobalDenyList(_msgSender()) onlyRole(GLOBAL_FUNDS_RESCUE_ROLE) {
        require(_globalParticipantList[participantSmartContract], "Not a participant");
        IFundsRescuableUpgradeableV1 participantSmartContractInstance = IFundsRescuableUpgradeableV1(
            participantSmartContract
        );
        participantSmartContractInstance.fundsRescueERC20(beneficiary, asset, amount);
    }

    /**
     * @notice This function is used to rescue ETH from a participant contract.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - `participantSmartContract` should be a member of the Global Participant List.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Limits interactions to only contracts that are in the Participant List.
     *
     * This function will fail if the Global Pause is active. However, the check is not implemented
     * at the Global Control contract level. The participant contract that implements {fundsRescueETH}
     * should implement the check and revert if the Global Pause is active.
     *
     * @param participantSmartContract The contract address from which the funds are extracted.
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function participantFundsRescueETH(
        address participantSmartContract,
        address beneficiary,
        uint256 amount
    ) external virtual whenNotPaused notInGlobalDenyList(_msgSender()) onlyRole(GLOBAL_FUNDS_RESCUE_ROLE) {
        require(_globalParticipantList[participantSmartContract], "Not a participant");
        IFundsRescuableUpgradeableV1 participantSmartContractInstance = IFundsRescuableUpgradeableV1(
            participantSmartContract
        );
        participantSmartContractInstance.fundsRescueETH(beneficiary, amount);
    }

    /**
     * @notice This is a function used to confirm whether the Global Pause is active.
     * @return The function returns a value of "True" if the Global Pause is active.
     */
    function isGlobalPaused() public view returns (bool) {
        return _globalPauseIsActive;
    }

    /**
     * @notice This is a function used to confirm that the contract is participating in the Stablecoin System,
     * governed by the Global Control contract.
     * @dev This function is a getter for the boolean value in Global Participant List for a particular address.
     * @param smartContract The address of the contract to be assessed.
     * @return This function returns a value of "True" if the `smartContract` address is registered
     * as a participant in the Global Control contract.
     */
    function isGlobalParticipant(address smartContract) external view returns (bool) {
        return _globalParticipantList[smartContract];
    }

    /**
     * @notice This is a function used to add a list of addresses to the Global Participant List.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Can only be invoked by the address that has the role "PARTICIPANT_ADMIN_ROLE".
     * - Each member of the `participants` list should be a contract address.
     * - `participants` must have at least one non-zero address. Zero addresses won't be added to the Participant List.
     * - `participants` is not an empty array.
     * - `participants` list size is less than or equal to 100.
     *
     * This function emits a {ParticipantAdded} event for each address which was successfully added
     * to the Global Participant List.
     *
     * @param participants The list of accounts that will be added to the Global Participant List.
     */
    function globalParticipantListAdd(address[] calldata participants)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(PARTICIPANT_ADMIN_ROLE)
    {
        if (participants.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
        require(participants.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < participants.length; ) {
            if (participants[i] != address(0)) {
                hasNonZeroAddress = true;
                require(AddressUpgradeable.isContract(participants[i]), "Participant is not a contract");
                if (!_globalParticipantList[participants[i]]) {
                    _globalParticipantList[participants[i]] = true;
                    emit ParticipantAdded(_msgSender(), participants[i]);
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
    }

    /**
     * @notice This is a function used to remove a list of addresses from the Global Participant List.
     * @dev Calling Conditions:
     *
     * - The sender is not listed in the Global DenyList.
     * - Can only be invoked by the address that has the role "PARTICIPANT_ADMIN_ROLE".
     * - {GlobalControlV1} is not paused.
     * - `participants` must have atleast one non-zero address.
     * - `participants` is not an empty array.
     * - `participants` list size is less than or equal to 100.
     *
     * This function emits a {ParticipantRemoved} event for each address which was successfully removed
     * from the Global Participant List.
     *
     * @param participants The list of accounts that will be removed from the Global Participant List.
     */
    function globalParticipantListRemove(address[] calldata participants)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(PARTICIPANT_ADMIN_ROLE)
    {
        if (participants.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
        require(participants.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < participants.length; ) {
            if (participants[i] != address(0)) {
                hasNonZeroAddress = true;
                if (_globalParticipantList[participants[i]]) {
                    _globalParticipantList[participants[i]] = false;
                    emit ParticipantRemoved(_msgSender(), participants[i]);
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
    }

    /**
     * @notice This is a function used to add a list of addresses to the Global DenyList.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the DenyList.
     * - Can only be invoked by the address that has the role "GLOBAL_DENYLIST_ADMIN_ROLE".
     * - `accounts` must have at least one non-zero address. Zero addresses won't be added to the DenyList.
     * - `accounts` is not an empty array.
     * - `accounts` list size is less than or equal to 100.
     *
     * This function emits a {GlobalDenyListAddressAdded} event for each account which was successfully added to the
     * Global DenyList.
     *
     * @param accounts The list of accounts that will be added to the Global DenyList.
     */
    function globalDenyListAdd(address[] calldata accounts)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_DENYLIST_ADMIN_ROLE)
    {
        if (accounts.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
        require(accounts.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < accounts.length; ) {
            if (accounts[i] != address(0)) {
                hasNonZeroAddress = true;
                if (!_globalDenyList[accounts[i]]) {
                    _globalDenyList[accounts[i]] = true;
                    emit GlobalDenyListAddressAdded(_msgSender(), accounts[i]);
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
    }

    /**
     * @notice This is a function used to remove a list of addresses from the Global DenyList.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Can only be invoked by the address that has the role "GLOBAL_DENYLIST_ADMIN_ROLE".
     * - `accounts` is a non-zero address.
     * - `accounts` is not an empty array.
     * - `accounts` list size is less than or equal to 100.
     *
     * This function emits a {GlobalDenyListAddressRemoved} event for each account which was successfully removed from
     * the Global DenyList.
     *
     * @param accounts A list of accounts that will be removed from the Global DenyList.
     */
    function globalDenyListRemove(address[] calldata accounts)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_DENYLIST_ADMIN_ROLE)
    {
        if (accounts.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
        require(accounts.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < accounts.length; ) {
            if (accounts[i] != address(0)) {
                hasNonZeroAddress = true;
                if (_globalDenyList[accounts[i]]) {
                    _globalDenyList[accounts[i]] = false;
                    emit GlobalDenyListAddressRemoved(_msgSender(), accounts[i]);
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
    }

    /**
     * @notice This is a function used to pause the Global Control contract.
     * It also activates Global Pause when it is called.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "PAUSER_ROLE".
     * - The sender is not listed in the Global DenyList.
     * - {GlobalControlV1} is not paused.
     *
     * This function might emit a {Paused} event as part of {PausableUpgradeable._pause}.
     * This function emits a {GlobalPauseIssued} event(as part of {_globalPause}) indicating Global Pause is active.
     */
    function pause() external virtual notInGlobalDenyList(_msgSender()) onlyRole(PAUSER_ROLE) {
        _globalPause();
        _pause();
    }

    /**
     * @notice This is a function used to unpause the Global Control contract.
     *
     * Restoring full operation after a {pause} was enacted will, by design,
     * require calling {unpause} followed by {globalUnpause}.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "PAUSER_ROLE".
     * - The sender is not listed in the Global DenyList.
     * - {GlobalControlV1} is paused.
     */
    function unpause() external virtual notInGlobalDenyList(_msgSender()) onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice This is a function used to activate Global Pause.
     * This function does not pause the Global Control contract.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "GLOBAL_PAUSE_ADMIN_ROLE".
     * - {GloablControlV1} must not be paused.
     * - The sender is not listed in the Global DenyList.
     * - Global Pause must not be active.
     *
     * Uses the internal function {_globalPause} to set the `gloablPauseInEffect` boolean.
     *
     * This function emits a {GlobalPauseIssued} event(as part of {_globalPause}) indicating Global Pause is active.
     */
    function activateGlobalPause()
        external
        virtual
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_PAUSE_ADMIN_ROLE)
    {
        require((!isGlobalPaused()), "Global Pause is already active");
        _globalPause();
    }

    /**
     * @notice This is a function used to deactivate Global Pause.
     * This function does not unpause the Global Control contract.
     *
     * @dev RCalling Conditions:
     *
     * - Can only be invoked by the address that has the role "GLOBAL_PAUSE_ADMIN_ROLE".
     * - {GloablControlV1} must not be paused.
     * - The sender is not listed in the Global DenyList.
     * - Global Pause must be active.
     *
     * Uses the internal function {_globalUnpause} to set the `gloablPauseInEffect` boolean.
     *
     * This function emits a {GlobalPauseCleared} event(as part of {_globalUnpause}) indicating Global Pause is inactive.
     */
    function deactivateGlobalPause()
        external
        virtual
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_PAUSE_ADMIN_ROLE)
    {
        require(_globalPauseIsActive, "Global Pause is inactive");
        _globalUnpause();
    }

    /**
     * @notice This function disables the OpenZeppelin inherited {renounceRole} function. Access Control roles
     * are controlled exclusively by "ACCESS_CONTROL_ADMIN_ROLE" and "UPGRADER_ROLE" role.
     */
    function renounceRole(bytes32, address)
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        revert LibErrorsV1.OpenZeppelinFunctionDisabled();
    }

    /**
     * @notice This function allows the sender to grant a role to the `account` address.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Non-zero address `account`.
     *
     * This function might emit an {RoleGranted} event as part of {AccessControlUpgradeable._grantRole}.
     *
     * @param role The role that will be granted.
     * @param account The address that will receive the role.
     */
    function grantRole(bytes32 role, address account)
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
    {
        if (account == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("account");
        }
        super.grantRole(role, account); // In {AccessControlUpgradeable}
    }

    /**
     * @notice This function allows the sender to revoke a role from the `account` address.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Non-zero address `account`.
     *
     * This function might emit an {RoleRevoked} event as part of {AccessControlUpgradeable._revokeRole}.
     *
     * @param role The role that will be revoked.
     * @param account The address that will have its role revoked.
     */
    function revokeRole(bytes32 role, address account)
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
    {
        if (account == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("account");
        }
        super.revokeRole(role, account); // In {AccessControlUpgradeable}
    }

    /**
     * @notice This is a function that sets the Global Pause to active.
     * @dev This function emits a {GlobalPauseIssued} event indicating Global Pause is active.
     */
    function _globalPause() internal virtual {
        _globalPauseIsActive = true;
        emit GlobalPauseIssued(_msgSender());
    }

    /**
     * @notice This is a function that sets the Global Pause to inactive.
     * @dev This function emits a {GlobalPauseCleared} event indicating Global Pause is inactive.
     */
    function _globalUnpause() internal virtual {
        _globalPauseIsActive = false;
        emit GlobalPauseCleared(_msgSender());
    }

    /**
     * @notice This is a function used to update the implementation address.
     * @dev Calling Conditions:
     *
     * - Only the "UPGRADER_ROLE" can execute.
     * - `newImplementation` is a non-zero address.
     *
     * @param newImplementation The address of the new logic contract.
     */
    /* solhint-disable no-empty-blocks */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}
    /* solhint-enable no-empty-blocks */
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import "../../../common/V1/FundsRescue/interface/IFundsRescuableUpgradeableV1.sol";

/**
 * Copyright (C) 2022 National Australia Bank Limited
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not,
 * see <https://www.gnu.org/licenses/>.
 */

/**
 * @title Global Control Interface (V1)
 * @author National Australia Bank Limited
 * @notice The Global Control Interface details the interface surface the Global Control
 * makes available to participating smart contracts (e.g. Stablecoins) for shared control.
 *
 * For example the shared DenyList management and single call {pause} and {unpause}
 * patterns.
 */
interface IGlobalControlV1 is IFundsRescuableUpgradeableV1 {
    /// Functions

    /**
     * @notice This is a function used to activate Global Pause.
     *
     * This function does not pause the Global Control contract.
     */
    function activateGlobalPause() external;

    /**
     * @notice This is a function used to deactivate Global Pause.
     *
     * This function does not unpause the Global Control contract.
     */
    function deactivateGlobalPause() external;

    /**
     * @notice This function is used to remove the funds from a given user.
     * @param participantSmartContract The asset that will be removed from the `account`.
     * @param account The address for which the funds are to be removed.
     * @param amount The amount of the `asset` removed from the `account` address.
     */
    function fundsRetireERC20(
        address participantSmartContract,
        address account,
        uint256 amount
    ) external;

    /**
     * @notice This function is used to rescue ERC20 tokens from a participant contract.
     * @param participantSmartContract The contract address from which the asset is extracted.
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of the foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function participantFundsRescueERC20(
        address participantSmartContract,
        address beneficiary,
        address asset,
        uint256 amount
    ) external;

    /**
     * @notice This function is used to rescue ETH from a participant contract.
     * @param participantSmartContract The contract address from which the funds are extracted.
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function participantFundsRescueETH(
        address participantSmartContract,
        address beneficiary,
        uint256 amount
    ) external;

    /**
     * @notice This is a function used to add a list of addresses to the Global DenyList.
     * @param accounts The list of accounts that will be added to the Global DenyList.
     */
    function globalDenyListAdd(address[] memory accounts) external;

    /**
     * @notice This is a function used to remove a list of addresses from the Global DenyList.
     * @param accounts A list of accounts that will be removed from the Global DenyList.
     */
    function globalDenyListRemove(address[] memory accounts) external;

    /**
     * @notice This function is used to confirm whether an account is present on the Global Control DenyList.
     * @param inspect The account address to be assessed.
     * @return The function returns a value of "True" if an address is present in the Global DenyList.
     */
    function isGlobalDenyListed(address inspect) external view returns (bool);

    /**
     * @notice This is a function used to confirm that the contract is participating in the Stablecoin System,
     * governed by the Global Control contract.
     *
     * @param smartContract The address of the contract to be assessed.
     * @return This function returns a value of "True" if the `smartContract` address is registered
     * in the Global Control contract.
     */
    function isGlobalParticipant(address smartContract) external view returns (bool);

    /**
     * @notice This is a function used to confirm whether the Global Pause is active.
     * @return The function returns a value of "True" if the Global Pause is active.
     */
    function isGlobalPaused() external view returns (bool);

    /**
     * @notice This is a function used to pause the Global Control contract.
     * It also activates Global Pause when it is called.
     */
    function pause() external;

    /**
     * @notice This is a function used to unpause the Global Control contract.
     *
     * Restoring full operation post {pause} will, by design,
     * require calling {unpause} followed by {globalUnpause}.
     */
    function unpause() external;

    /**
     * @notice This is a function used to add a list of addresses to the Global Participant List.
     * @param participants The list of accounts that will be added to the Global Participant List.
     */
    function globalParticipantListAdd(address[] calldata participants) external;

    /**
     * @notice This is a function used to remove a list of addresses from the Global Participant List.
     * @param participants The list of accounts that will be removed from the Global Participant List.
     */
    function globalParticipantListRemove(address[] calldata participants) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

/**
 * Copyright (C) 2022 National Australia Bank Limited
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not,
 * see <https://www.gnu.org/licenses/>.
 */

/**
 * @title Custom Errors Library (V1)
 * @author National Australia Bank Limited
 * @notice This library holds the definition of custom errors as they may appear throughout the system.
 * @dev This library should be imported by consumer contracts which require the use of custom errors.
 */
library LibErrorsV1 {
    /// Errors

    /**
     * @notice Thrown when an inherited OpenZeppelin function has been disabled.
     */
    error OpenZeppelinFunctionDisabled();

    /**
     * @notice Custom error to interpret error conditions where an "empty" parameter is provided.
     * @dev Thrown by functions with a precondition on the parameter to not have a null value (0x0), but
     * a parameter with such value is provided.
     *
     * @param paramName The name of the parameter that cannot have a null value (0x0).
     */
    error ZeroValuedParameter(string paramName);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

/**
 * Copyright (C) 2022 National Australia Bank Limited
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not,
 * see <https://www.gnu.org/licenses/>.
 */
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interface/IFundsRescuableUpgradeableV1.sol";
import "../library/LibErrorsV1.sol";

/**
 * @title Funds Rescuable Abstract (V1)
 * @author National Australia Bank Limited
 * @notice This abstract contract defines funds rescue functionality, both for ETH and ERC20 tokens.
 */
abstract contract FundsRescuableUpgradeableV1 is
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    IFundsRescuableUpgradeableV1
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Events

    /**
     * @notice This is an event that logs whenever ERC20 funds are rescued from a contract.
     * @param sender The (indexed) address that rescued the ERC20 funds.
     * @param beneficiary The (indexed) address that received the rescued ERC20 funds.
     * @param asset The (indexed) address of the rescued asset.
     * @param amount The amount of tokens that were rescued.
     */
    event FundsRescuedERC20(address indexed sender, address indexed beneficiary, address indexed asset, uint256 amount);

    /**
     * @notice This is an event that logs whenever ETH is rescued from a contract.
     * @param sender The (indexed) address that rescued the funds.
     * @param beneficiary The (indexed) address that received the rescued ETH funds.
     * @param amount The amount of ETH that was rescued.
     */
    event FundsRescuedETH(address indexed sender, address indexed beneficiary, uint256 amount);

    /// Functions

    /**
     * @notice A function used to rescue ERC20 tokens sent to a contract.
     * @dev Calling Conditions:
     *
     * - `beneficiary` is non-zero address.
     * - `asset` is a contract.
     * - `amount` is greater than 0.
     * - `amount` is less than or equal to the contract's `asset` balance.
     * 
     * This function emits a {FundsRescuedERC20} event, indicating that funds were rescued.
     * 
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Uses the safeTransfer method from {IERC20Upgradeable}.
     * - Protects against re-entrancy using the {ReentrancyGuardUpgradeable} contract.
     * 
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function fundsRescueERC20(address beneficiary, address asset, uint256 amount) public virtual nonReentrant {
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
        if (beneficiary == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("beneficiary");
        }
        require(AddressUpgradeable.isContract(asset), "Asset to rescue is not a contract");

        IERC20Upgradeable _token = IERC20Upgradeable(asset);
        require(_token.balanceOf(address(this)) >= amount, "Cannot rescue more than available balance");

        emit FundsRescuedERC20(_msgSender(), beneficiary, asset, amount);
        _token.safeTransfer(beneficiary, amount);
    }

    /**
     * @notice A function used to rescue ETH sent to a contract.
     * @dev Calling Conditions:
     *
     * - `beneficiary` is non-zero address.
     * - `amount` is greater than 0.
     * - `amount` is less than or equal to the contract's ETH balance.
     * 
     * This function emits a {FundsRescuedETH} event, indicating that funds were rescued.
     * 
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Uses the sendValue method from {AddressUpgradeable}.
     * - Protects against reentrancy using the {ReentrancyGuardUpgradeable} contract.
     * 
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function fundsRescueETH(address beneficiary, uint256 amount) public virtual nonReentrant {
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
        if (beneficiary == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("beneficiary");
        }
        require(address(this).balance >= amount, "Cannot rescue more than available balance");

        emit FundsRescuedETH(_msgSender(), beneficiary, amount);
        AddressUpgradeable.sendValue(payable(beneficiary), amount);
    }

    /* solhint-disable func-name-mixedcase */
    // @dev Initializer function for FundsRescuableUpgradeable.
    function __FundsRescuableUpgradeableV1_init() internal onlyInitializing {
        __ReentrancyGuard_init();
    }

    /* solhint-enable func-name-mixedcase */

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    //slither-disable-next-line naming-convention
    uint256[50] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

/**
 * Copyright (C) 2022 National Australia Bank Limited
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not,
 * see <https://www.gnu.org/licenses/>.
 */

/**
 * @title ERC20 DenyList Interface (V1)
 * @author National Australia Bank Limited
 * @notice ERC20 DenyList Interface is the backbone for ERC20 DenyList functionality. It outlines the functions that
 * must be implemented by child contracts and establishes how external systems should interact with it. In particular,
 * this interface outlines the common DenyList controls for the NAB cohort of participant smart contracts.
 *
 * @dev Interface for the ERC20 DenyList features.
 *
 * The ERC20 DenyList Interface contract Role Based Access Control employs following roles:
 *
 *  - DENYLIST_ADMIN_ROLE
 *  - DENYLIST_FUNDS_RETIRE_ROLE
 */
interface IERC20DeniableUpgradeableV1 {
    /// Events

    /**
     * @notice This is an event that logs when an address is added to the DenyList.
     * @dev Notifies that the logged address will be denied using functions like {transfer}, {transferFrom} and
     * {approve}.
     *
     * @param sender The (indexed) account which called the {denyListAdd} function to impose the deny restrictions
     * on the address(es).
     * @param account The (indexed) address which was confirmed as present on the DenyList.
     * @param balance The balance of the address at the moment it was added to the DenyList.
     */
    event DenyListAddressAdded(address indexed sender, address indexed account, uint256 balance);

    /**
     * @notice This is an event that logs when an address is removed from the DenyList.
     * @dev Notifies that the logged address can resume using functions like {transfer}, {transferFrom} and {approve}.
     *
     * @param sender The (indexed) account which called the {denyListRemove} function to lift the deny restrictions
     * on the address(es).
     * @param account The (indexed) address which was removed from the DenyList.
     * @param balance The balance of the address after it was removed from the DenyList.
     */
    event DenyListAddressRemoved(address indexed sender, address indexed account, uint256 balance);

    /**
     * @notice This is an event that logs when an account with either "DENYLIST_FUNDS_RETIRE_ROLE"
     * or "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" calls the {denyListFundsRetire} function to remove funds from address'
     * balance.
     *
     * @dev Indicates that the funds were retired and the `amount` was burnt from the `holder`'s balance.
     *
     * @param sender The (indexed) account that effected the removal of the funds from the
     * `holder`'s balance.
     * @param holder The (indexed) address whose funds were removed.
     * @param preBalance The holder's ERC-20 balance before the funds were removed.
     * @param postBalance The holder's ERC-20 balance after the funds were removed.
     * @param amount The amount which was removed from the holder's balance.
     */
    event DenyListFundsRetired(
        address indexed sender,
        address indexed holder,
        uint256 preBalance,
        uint256 postBalance,
        uint256 amount
    );

    /// Functions

    /**
     * @notice This is a function that adds a list of addresses to the DenyList. The function can be
     * called by the address which has the "DENYLIST_ADMIN_ROLE".
     *
     * @param accounts The list of addresses to be added to the DenyList.
     */
    function denyListAdd(address[] calldata accounts) external;

    /**
     * @notice This is a function that removes a list of addresses from the DenyList.
     * The function can be called by the address which has the "DENYLIST_ADMIN_ROLE".
     *
     * @param accounts The list of addresses to be removed from DenyList.
     */
    function denyListRemove(address[] calldata accounts) external;

    /**
     * @notice This is a function used to remove an asset from an address' balance. The function can be called
     * by the address which has the "DENYLIST_FUNDS_RETIRE_ROLE".
     *
     * @param account The address whose assets will be removed.
     * @param amount The amount to be removed.
     */
    function fundsRetire(address account, uint256 amount) external;

    /**
     * @notice This is a function used to check if the account is in DenyList.
     * @param account The account to be checked if it is in DenyList.
     * @return true if the account is in DenyList (false otherwise).
     */
    function isInDenyList(address account) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControlEnumerableUpgradeable.sol";
import "./AccessControlUpgradeable.sol";
import "../utils/structs/EnumerableSetUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerableUpgradeable is Initializable, IAccessControlEnumerableUpgradeable, AccessControlUpgradeable {
    function __AccessControlEnumerable_init() internal onlyInitializing {
    }

    function __AccessControlEnumerable_init_unchained() internal onlyInitializing {
    }
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    mapping(bytes32 => EnumerableSetUpgradeable.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view virtual override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {_grantRole} to track enumerable memberships
     */
    function _grantRole(bytes32 role, address account) internal virtual override {
        super._grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {_revokeRole} to track enumerable memberships
     */
    function _revokeRole(bytes32 role, address account) internal virtual override {
        super._revokeRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate that the this implementation remains valid after an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

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
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

/**
 * Copyright (C) 2022 National Australia Bank Limited
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not,
 * see <https://www.gnu.org/licenses/>.
 */

/**
 * @title Funds Rescuable Interface (V1)
 * @author National Australia Bank Limited
 * @notice This interface describes the set of functions required to rescue foreign funds, both ERC20
 * and ETH, from a contract.
 */
interface IFundsRescuableUpgradeableV1 {
    /// Functions

    /**
     * @notice A function used to rescue ERC20 tokens sent to a contract.
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function fundsRescueERC20(
        address beneficiary,
        address asset,
        uint256 amount
    ) external;

    /**
     * @notice A function used to rescue ETH sent to a contract.
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function fundsRescueETH(address beneficiary, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

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

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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
        IERC20PermitUpgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
interface IERC20PermitUpgradeable {
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerableUpgradeable is IAccessControlUpgradeable {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

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
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
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
        _checkRole(role);
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
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
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
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
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
     *
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleRevoked} event.
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
     *
     * May emit a {RoleRevoked} event.
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
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)

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
 *
 * [WARNING]
 * ====
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
 * ====
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
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
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

        /// @solidity memory-safe-assembly
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

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
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
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
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
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}