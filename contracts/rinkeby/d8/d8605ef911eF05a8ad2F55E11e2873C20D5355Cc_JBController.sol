// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
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

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

import "prb-math/contracts/PRBMath.sol";

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@paulrberg/contracts/math/PRBMath.sol';
import './abstract/JBOperatable.sol';
import './interfaces/IJBProjects.sol';
import './interfaces/IJBPaymentTerminal.sol';
import './interfaces/IJBOperatorStore.sol';
import './interfaces/IJBFundingCycleDataSource.sol';
import './interfaces/IJBPrices.sol';
import './interfaces/IJBController.sol';
import './interfaces/IJBController.sol';
import './libraries/JBConstants.sol';
import './libraries/JBOperations.sol';
import './libraries/JBSplitsGroups.sol';
import './libraries/JBFundingCycleMetadataResolver.sol';

//*********************************************************************//
// --------------------------- custom errors ------------------------- //
//*********************************************************************//
error INVALID_DISTRIBUTION_LIMIT();
error INVALID_DISTRIBUTION_LIMIT_CURRENCY();
error INVALID_OVERFLOW_ALLOWANCE();
error INVALID_OVERFLOW_ALLOWANCE_CURRENCY();
error BURN_PAUSED_AND_SENDER_NOT_VALID_TERMINAL_DELEGATE();
error NOT_CURRENT_CONTROLLER();
error CANT_MIGRATE_TO_CURRENT_CONTROLLER();
error CHANGE_TOKEN_NOT_ALLOWED();
error FUNDING_CYCLE_ALREADY_LAUNCHED();
error INVALID_BALLOT_REDEMPTION_RATE();
error INVALID_RESERVED_RATE();
error INVALID_REDEMPTION_RATE();
error MIGRATION_NOT_ALLOWED();
error MINT_PAUSED_AND_NOT_TERMINAL_DELEGATE();
error NO_BURNABLE_TOKENS();
error ZERO_TOKENS_TO_MINT();

/**
  @notice
  Stitches together funding cycles and community tokens, making sure all activity is accounted for and correct.

  @dev
  Adheres to:
  IJBController - general interface for the generic controller methods in this contract that interacts with funding cycles and tokens according to the protocol's rules.

  @dev
  Inherits from:
  JBOperatable - several functions in this contract can only be accessed by a project owner, or an address that has been preconfifigured to be an operator of the project.
  ReentrencyGuard - several function in this contract shouldn't be accessible recursively.
*/
contract JBController is IJBController, JBOperatable {
  // A library that parses the packed funding cycle metadata into a more friendly format.
  using JBFundingCycleMetadataResolver for JBFundingCycle;

  //*********************************************************************//
  // --------------------- private stored properties ------------------- //
  //*********************************************************************//

  /**
    @notice
    The difference between the processed token tracker of a project and the project's token's total supply is the amount of tokens that still need to have reserves minted against them.

    _projectId The ID of the project to get the tracker of.
  */
  mapping(uint256 => int256) private _processedTokenTrackerOf;

  /**
    @notice
    Data regarding the distribution limit of a project during a configuration.

    @dev
    bits 0-247: The amount of token that a project can distribute per funding cycle.

    @dev
    bits 248-255: The currency of amount that a project can distribute.

    _projectId The ID of the project to get the packed distribution limit data of.
    _configuration The configuration during which the packed distribution limit data applies.
    _terminal The terminal from which distributions are being limited.
  */
  mapping(uint256 => mapping(uint256 => mapping(IJBPaymentTerminal => uint256)))
    private _packedDistributionLimitDataOf;

  /**
    @notice
    Data regarding the overflow allowance of a project during a configuration.

    @dev
    bits 0-247: The amount of overflow that a project is allowed to tap into on-demand throughout the configuration.

    @dev
    bits 248-255: The currency of the amount of overflow that a project is allowed to tap.

    _projectId The ID of the project to get the packed overflow allowance data of.
    _configuration The configuration during which the packed overflow allowance data applies.
    _terminal The terminal managing the overflow.
  */
  mapping(uint256 => mapping(uint256 => mapping(IJBPaymentTerminal => uint256)))
    private _packedOverflowAllowanceDataOf;

  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /**
    @notice
    The Projects contract which mints ERC-721's that represent project ownership.
  */
  IJBProjects public immutable override projects;

  /**
    @notice
    The contract storing all funding cycle configurations.
  */
  IJBFundingCycleStore public immutable override fundingCycleStore;

  /**
    @notice
    The contract that manages token minting and burning.
  */
  IJBTokenStore public immutable override tokenStore;

  /**
    @notice
    The contract that stores splits for each project.
  */
  IJBSplitsStore public immutable override splitsStore;

  /**
    @notice
    The directory of terminals and controllers for projects.
  */
  IJBDirectory public immutable override directory;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /**
    @notice
    The amount of token that a project can distribute per funding cycle, and the currency it's in terms of.

    @dev
    The number of decimals in the returned fixed point amount is the same as that of the specified terminal. 

    @param _projectId The ID of the project to get the distribution limit of.
    @param _configuration The configuration during which the distribution limit applies.
    @param _terminal The terminal from which distributions are being limited.

    @return The distribution limit, as a fixed point number with the same number of decimals as the provided terminal.
    @return The currency of the distribution limit.
  */
  function distributionLimitOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal
  ) external view override returns (uint256, uint256) {
    // Get a reference to the packed data.
    uint256 _data = _packedDistributionLimitDataOf[_projectId][_configuration][_terminal];

    // The limit is in bits 0-247. The currency is in bits 248-255.
    return (uint256(uint248(_data)), _data >> 248);
  }

  /**
    @notice
    The amount of overflow that a project is allowed to tap into on-demand throughout a configuration, and the currency it's in terms of.

    @dev
    The number of decimals in the returned fixed point amount is the same as that of the specified terminal. 

    @param _projectId The ID of the project to get the overflow allowance of.
    @param _configuration The configuration of the during which the allowance applies.
    @param _terminal The terminal managing the overflow.

    @return The overflow allowance, as a fixed point number with the same number of decimals as the provided terminal.
    @return The currency of the overflow allowance.
  */
  function overflowAllowanceOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal
  ) external view override returns (uint256, uint256) {
    // Get a reference to the packed data.
    uint256 _data = _packedOverflowAllowanceDataOf[_projectId][_configuration][_terminal];

    // The allowance is in bits 0-247. The currency is in bits 248-255.
    return (uint256(uint248(_data)), _data >> 248);
  }

  /**
    @notice
    Gets the amount of reserved tokens that a project has available to distribute.

    @param _projectId The ID of the project to get a reserved token balance of.
    @param _reservedRate The reserved rate to use when making the calculation.

    @return The current amount of reserved tokens.
  */
  function reservedTokenBalanceOf(uint256 _projectId, uint256 _reservedRate)
    external
    view
    override
    returns (uint256)
  {
    return
      _reservedTokenAmountFrom(
        _processedTokenTrackerOf[_projectId],
        _reservedRate,
        tokenStore.totalSupplyOf(_projectId)
      );
  }

  /**
    @notice
    Gets the current total amount of outstanding tokens for a project, given a reserved rate.

    @param _projectId The ID of the project to get total outstanding tokens of.
    @param _reservedRate The reserved rate to use when making the calculation.

    @return The current total amount of outstanding tokens for the project.
  */
  function totalOutstandingTokensOf(uint256 _projectId, uint256 _reservedRate)
    external
    view
    override
    returns (uint256)
  {
    // Get the total number of tokens in circulation.
    uint256 _totalSupply = tokenStore.totalSupplyOf(_projectId);

    // Get the number of reserved tokens the project has.
    uint256 _reservedTokenAmount = _reservedTokenAmountFrom(
      _processedTokenTrackerOf[_projectId],
      _reservedRate,
      _totalSupply
    );

    // Add the reserved tokens to the total supply.
    return _totalSupply + _reservedTokenAmount;
  }

  //*********************************************************************//
  // ---------------------------- constructor -------------------------- //
  //*********************************************************************//

  /**
    @param _operatorStore A contract storing operator assignments.
    @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
    @param _directory A contract storing directories of terminals and controllers for each project.
    @param _fundingCycleStore A contract storing all funding cycle configurations.
    @param _tokenStore A contract that manages token minting and burning.
    @param _splitsStore A contract that stores splits for each project.
  */
  constructor(
    IJBOperatorStore _operatorStore,
    IJBProjects _projects,
    IJBDirectory _directory,
    IJBFundingCycleStore _fundingCycleStore,
    IJBTokenStore _tokenStore,
    IJBSplitsStore _splitsStore
  ) JBOperatable(_operatorStore) {
    projects = _projects;
    directory = _directory;
    fundingCycleStore = _fundingCycleStore;
    tokenStore = _tokenStore;
    splitsStore = _splitsStore;
  }

  //*********************************************************************//
  // --------------------- external transactions ----------------------- //
  //*********************************************************************//

  /**
    @notice
    Creates a project. This will mint an ERC-721 into the specified owner's account, configure a first funding cycle, and set up any splits.

    @dev
    Each operation within this transaction can be done in sequence separately.

    @dev
    Anyone can deploy a project on an owner's behalf.

    @param _owner The address to set as the owner of the project. The project ERC-721 will be owned by this address.
    @param _projectMetadata Metadata to associate with the project within a particular domain. This can be updated any time by the owner of the project.
    @param _data Data that defines the project's first funding cycle. These properties will remain fixed for the duration of the funding cycle.
    @param _metadata Metadata specifying the controller specific params that a funding cycle can have. These properties will remain fixed for the duration of the funding cycle.
    @param _mustStartAtOrAfter The time before which the configured funding cycle cannot start.
    @param _groupedSplits An array of splits to set for any number of groups. 
    @param _fundAccessConstraints An array containing amounts that a project can use from its treasury for each payment terminal. Amounts are fixed point numbers using the same number of decimals as the accompanying terminal.
    @param _terminals Payment terminals to add for the project.
    @param _memo A memo to pass along to the emitted event.

    @return projectId The ID of the project.
  */
  function launchProjectFor(
    address _owner,
    JBProjectMetadata calldata _projectMetadata,
    JBFundingCycleData calldata _data,
    JBFundingCycleMetadata calldata _metadata,
    uint256 _mustStartAtOrAfter,
    JBGroupedSplits[] calldata _groupedSplits,
    JBFundAccessConstraints[] calldata _fundAccessConstraints,
    IJBPaymentTerminal[] memory _terminals,
    string memory _memo
  ) external override returns (uint256 projectId) {
    // Mint the project into the wallet of the message sender.
    projectId = projects.createFor(_owner, _projectMetadata);

    // Set this contract as the project's controller in the directory.
    directory.setControllerOf(projectId, this);

    // Configure the first funding cycle.
    uint256 _configuration = _configure(
      projectId,
      _data,
      _metadata,
      _mustStartAtOrAfter,
      _groupedSplits,
      _fundAccessConstraints
    );

    // Add the provided terminals to the list of terminals.
    if (_terminals.length > 0) directory.setTerminalsOf(projectId, _terminals);

    emit LaunchProject(_configuration, projectId, _memo, msg.sender);
  }

  /**
    @notice
    Creates a funding cycle for an already existing project ERC-721.

    @dev
    Each operation within this transaction can be done in sequence separately.

    @dev
    Only a project owner or operator can launch its funding cycles.

    @param _projectId The ID of the project to launch funding cycles for.
    @param _data Data that defines the project's first funding cycle. These properties will remain fixed for the duration of the funding cycle.
    @param _metadata Metadata specifying the controller specific params that a funding cycle can have. These properties will remain fixed for the duration of the funding cycle.
    @param _mustStartAtOrAfter The time before which the configured funding cycle cannot start.
    @param _groupedSplits An array of splits to set for any number of groups. 
    @param _fundAccessConstraints An array containing amounts that a project can use from its treasury for each payment terminal. Amounts are fixed point numbers using the same number of decimals as the accompanying terminal.
    @param _terminals Payment terminals to add for the project.
    @param _memo A memo to pass along to the emitted event.

    @return configuration The configuration of the funding cycle that was successfully created.
  */
  function launchFundingCyclesFor(
    uint256 _projectId,
    JBFundingCycleData calldata _data,
    JBFundingCycleMetadata calldata _metadata,
    uint256 _mustStartAtOrAfter,
    JBGroupedSplits[] calldata _groupedSplits,
    JBFundAccessConstraints[] memory _fundAccessConstraints,
    IJBPaymentTerminal[] memory _terminals,
    string memory _memo
  )
    external
    override
    requirePermission(projects.ownerOf(_projectId), _projectId, JBOperations.RECONFIGURE)
    returns (uint256 configuration)
  {
    // If there is a previous configuration, reconfigureFundingCyclesOf should be called instead
    if (fundingCycleStore.latestConfigurationOf(_projectId) > 0)
      revert FUNDING_CYCLE_ALREADY_LAUNCHED();

    // Set this contract as the project's controller in the directory.
    directory.setControllerOf(_projectId, this);

    // Configure the first funding cycle.
    configuration = _configure(
      _projectId,
      _data,
      _metadata,
      _mustStartAtOrAfter,
      _groupedSplits,
      _fundAccessConstraints
    );

    // Add the provided terminals to the list of terminals.
    if (_terminals.length > 0) directory.setTerminalsOf(_projectId, _terminals);

    emit LaunchFundingCycles(configuration, _projectId, _memo, msg.sender);
  }

  /**
    @notice
    Proposes a configuration of a subsequent funding cycle that will take effect once the current one expires if it is approved by the current funding cycle's ballot.

    @dev
    Only a project's owner or a designated operator can configure its funding cycles.

    @param _projectId The ID of the project whose funding cycles are being reconfigured.
    @param _data Data that defines the funding cycle. These properties will remain fixed for the duration of the funding cycle.
    @param _metadata Metadata specifying the controller specific params that a funding cycle can have. These properties will remain fixed for the duration of the funding cycle.
    @param _mustStartAtOrAfter The time before which the configured funding cycle cannot start.
    @param _groupedSplits An array of splits to set for any number of groups. 
    @param _fundAccessConstraints An array containing amounts that a project can use from its treasury for each payment terminal. Amounts are fixed point numbers using the same number of decimals as the accompanying terminal.
    @param _memo A memo to pass along to the emitted event.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
  function reconfigureFundingCyclesOf(
    uint256 _projectId,
    JBFundingCycleData calldata _data,
    JBFundingCycleMetadata calldata _metadata,
    uint256 _mustStartAtOrAfter,
    JBGroupedSplits[] calldata _groupedSplits,
    JBFundAccessConstraints[] calldata _fundAccessConstraints,
    string calldata _memo
  )
    external
    override
    requirePermission(projects.ownerOf(_projectId), _projectId, JBOperations.RECONFIGURE)
    returns (uint256 configuration)
  {
    // Configure the next funding cycle.
    configuration = _configure(
      _projectId,
      _data,
      _metadata,
      _mustStartAtOrAfter,
      _groupedSplits,
      _fundAccessConstraints
    );

    emit ReconfigureFundingCycles(configuration, _projectId, _memo, msg.sender);
  }

  /**
    @notice
    Issues an owner's ERC20 JBTokens that'll be used when claiming tokens.

    @dev
    Deploys a project's ERC20 JBToken contract.

    @dev
    Only a project's owner or operator can issue its token.

    @param _projectId The ID of the project being issued tokens.
    @param _name The ERC20's name.
    @param _symbol The ERC20's symbol.
  */
  function issueTokenFor(
    uint256 _projectId,
    string calldata _name,
    string calldata _symbol
  )
    external
    override
    requirePermission(projects.ownerOf(_projectId), _projectId, JBOperations.ISSUE)
    returns (IJBToken token)
  {
    // Issue the token in the store.
    return tokenStore.issueFor(_projectId, _name, _symbol);
  }

  /**
    @notice
    Swap the current project's token that is minted and burned for another, and transfer ownership of the current token to another address if needed.

    @dev
    Only a project's owner or operator can change its token.

    @param _projectId The ID of the project to which the changed token belongs.
    @param _token The new token.
    @param _newOwner An address to transfer the current token's ownership to. This is optional, but it cannot be done later.
  */
  function changeTokenOf(
    uint256 _projectId,
    IJBToken _token,
    address _newOwner
  )
    external
    override
    requirePermission(projects.ownerOf(_projectId), _projectId, JBOperations.CHANGE_TOKEN)
  {
    // Get a reference to the project's current funding cycle.
    JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(_projectId);

    // The current funding cycle must not be paused.
    if (!_fundingCycle.changeTokenAllowed()) revert CHANGE_TOKEN_NOT_ALLOWED();

    // Change the token in the store.
    tokenStore.changeFor(_projectId, _token, _newOwner);
  }

  /**
    @notice
    Mint new token supply into an account, and optionally reserve a supply to be distributed according to the project's current funding cycle configuration.

    @dev
    Only a project's owner, a designated operator, or one of its terminals can mint its tokens.

    @param _projectId The ID of the project to which the tokens being minted belong.
    @param _tokenCount The amount of tokens to mint in total, counting however many should be reserved.
    @param _beneficiary The account that the tokens are being minted for.
    @param _memo A memo to pass along to the emitted event.
    @param _preferClaimedTokens A flag indicating whether a project's attached token contract should be minted if they have been issued.
    @param _useReservedRate Whether to use the current funding cycle's reserved rate in the mint calculation.

    @return beneficiaryTokenCount The amount of tokens minted for the beneficiary.
  */
  function mintTokensOf(
    uint256 _projectId,
    uint256 _tokenCount,
    address _beneficiary,
    string calldata _memo,
    bool _preferClaimedTokens,
    bool _useReservedRate
  )
    external
    override
    requirePermissionAllowingOverride(
      projects.ownerOf(_projectId),
      _projectId,
      JBOperations.MINT,
      directory.isTerminalOf(_projectId, IJBPaymentTerminal(msg.sender))
    )
    returns (uint256 beneficiaryTokenCount)
  {
    // There should be tokens to mint.
    if (_tokenCount == 0) revert ZERO_TOKENS_TO_MINT();

    // Define variables that will be needed outside scoped section below.
    // Keep a reference to the reserved rate to use
    uint256 _reservedRate;

    // Scoped section prevents stack too deep. `_fundingCycle` only used within scope.
    {
      // Get a reference to the project's current funding cycle.
      JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(_projectId);

      // If the message sender is not a terminal, the current funding cycle must not be paused.
      if (
        _fundingCycle.mintPaused() &&
        !directory.isTerminalOf(_projectId, IJBPaymentTerminal(msg.sender))
      ) revert MINT_PAUSED_AND_NOT_TERMINAL_DELEGATE();

      // Determine the reserved rate to use.
      _reservedRate = _useReservedRate ? _fundingCycle.reservedRate() : 0;
    }

    if (_reservedRate == JBConstants.MAX_RESERVED_RATE)
      // Subtract the total weighted amount from the tracker so the full reserved token amount can be printed later.
      _processedTokenTrackerOf[_projectId] =
        _processedTokenTrackerOf[_projectId] -
        int256(_tokenCount);
    else {
      // The unreserved token count that will be minted for the beneficiary.
      beneficiaryTokenCount = PRBMath.mulDiv(
        _tokenCount,
        JBConstants.MAX_RESERVED_RATE - _reservedRate,
        JBConstants.MAX_RESERVED_RATE
      );

      if (_reservedRate == 0)
        // If there's no reserved rate, increment the tracker with the newly minted tokens.
        _processedTokenTrackerOf[_projectId] =
          _processedTokenTrackerOf[_projectId] +
          int256(beneficiaryTokenCount);

      // Mint the tokens.
      tokenStore.mintFor(_beneficiary, _projectId, beneficiaryTokenCount, _preferClaimedTokens);
    }

    emit MintTokens(
      _beneficiary,
      _projectId,
      _tokenCount,
      beneficiaryTokenCount,
      _memo,
      _reservedRate,
      msg.sender
    );
  }

  /**
    @notice
    Burns a token holder's supply.

    @dev
    Only a token's holder, a designated operator, or a project's terminal can burn it.

    @param _holder The account that is having its tokens burned.
    @param _projectId The ID of the project to which the tokens being burned belong.
    @param _tokenCount The number of tokens to burn.
    @param _memo A memo to pass along to the emitted event.
    @param _preferClaimedTokens A flag indicating whether a project's attached token contract should be burned first if they have been issued.
  */
  function burnTokensOf(
    address _holder,
    uint256 _projectId,
    uint256 _tokenCount,
    string calldata _memo,
    bool _preferClaimedTokens
  )
    external
    override
    requirePermissionAllowingOverride(
      _holder,
      _projectId,
      JBOperations.BURN,
      directory.isTerminalOf(_projectId, IJBPaymentTerminal(msg.sender))
    )
  {
    // There should be tokens to burn
    if (_tokenCount == 0) revert NO_BURNABLE_TOKENS();

    // Get a reference to the project's current funding cycle.
    JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(_projectId);

    // If the message sender is not a terminal, the current funding cycle must not be paused.
    if (
      _fundingCycle.burnPaused() &&
      !directory.isTerminalOf(_projectId, IJBPaymentTerminal(msg.sender))
    ) revert BURN_PAUSED_AND_SENDER_NOT_VALID_TERMINAL_DELEGATE();

    // Update the token tracker so that reserved tokens will still be correctly mintable.
    _processedTokenTrackerOf[_projectId] =
      _processedTokenTrackerOf[_projectId] -
      int256(_tokenCount);

    // Burn the tokens.
    tokenStore.burnFrom(_holder, _projectId, _tokenCount, _preferClaimedTokens);

    emit BurnTokens(_holder, _projectId, _tokenCount, _memo, msg.sender);
  }

  /**
    @notice
    Distributes all outstanding reserved tokens for a project.

    @param _projectId The ID of the project to which the reserved tokens belong.
    @param _memo A memo to pass along to the emitted event.

    @return The amount of minted reserved tokens.
  */
  function distributeReservedTokensOf(uint256 _projectId, string calldata _memo)
    external
    override
    returns (uint256)
  {
    return _distributeReservedTokensOf(_projectId, _memo);
  }

  /**
    @notice
    Allows other controllers to signal to this one that a migration is expected for the specified project.

    @dev
    This controller should not yet be the project's controller.

    @param _projectId The ID of the project that will be migrated to this controller.
    @param _from The controller being migrated from.
  */
  function prepForMigrationOf(uint256 _projectId, IJBController _from) external override {
    // This controller must not be the project's current controller.
    if (directory.controllerOf(_projectId) == this) revert CANT_MIGRATE_TO_CURRENT_CONTROLLER();

    // Set the tracker as the total supply.
    _processedTokenTrackerOf[_projectId] = int256(tokenStore.totalSupplyOf(_projectId));

    emit PrepMigration(_projectId, _from, msg.sender);
  }

  /**
    @notice
    Allows a project to migrate from this controller to another.

    @dev
    Only a project's owner or a designated operator can migrate it.

    @param _projectId The ID of the project that will be migrated from this controller.
    @param _to The controller to which the project is migrating.
  */
  function migrate(uint256 _projectId, IJBController _to)
    external
    override
    requirePermission(projects.ownerOf(_projectId), _projectId, JBOperations.MIGRATE_CONTROLLER)
  {
    // This controller must be the project's current controller.
    if (directory.controllerOf(_projectId) != this) revert NOT_CURRENT_CONTROLLER();

    // Get a reference to the project's current funding cycle.
    JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(_projectId);

    // Migration must be allowed.
    if (!_fundingCycle.controllerMigrationAllowed()) revert MIGRATION_NOT_ALLOWED();

    // All reserved tokens must be minted before migrating.
    if (uint256(_processedTokenTrackerOf[_projectId]) != tokenStore.totalSupplyOf(_projectId))
      _distributeReservedTokensOf(_projectId, '');

    // Make sure the new controller is prepped for the migration.
    _to.prepForMigrationOf(_projectId, this);

    // Set the new controller.
    directory.setControllerOf(_projectId, _to);

    emit Migrate(_projectId, _to, msg.sender);
  }

  //*********************************************************************//
  // --------------------- private helper functions -------------------- //
  //*********************************************************************//

  /**
    @notice
    Distributes all outstanding reserved tokens for a project.

    @param _projectId The ID of the project to which the reserved tokens belong.
    @param _memo A memo to pass along to the emitted event.

    @return tokenCount The amount of minted reserved tokens.
  */
  function _distributeReservedTokensOf(uint256 _projectId, string memory _memo)
    private
    returns (uint256 tokenCount)
  {
    // Get the current funding cycle to read the reserved rate from.
    JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(_projectId);

    // Get a reference to new total supply of tokens before minting reserved tokens.
    uint256 _totalTokens = tokenStore.totalSupplyOf(_projectId);

    // Get a reference to the number of tokens that need to be minted.
    tokenCount = _reservedTokenAmountFrom(
      _processedTokenTrackerOf[_projectId],
      _fundingCycle.reservedRate(),
      _totalTokens
    );

    // Set the tracker to be the new total supply.
    _processedTokenTrackerOf[_projectId] = int256(_totalTokens + tokenCount);

    // Get a reference to the project owner.
    address _owner = projects.ownerOf(_projectId);

    // Distribute tokens to splits and get a reference to the leftover amount to mint after all splits have gotten their share.
    uint256 _leftoverTokenCount = tokenCount == 0
      ? 0
      : _distributeToReservedTokenSplitsOf(_projectId, _fundingCycle, tokenCount);

    // Mint any leftover tokens to the project owner.
    if (_leftoverTokenCount > 0) tokenStore.mintFor(_owner, _projectId, _leftoverTokenCount, false);

    emit DistributeReservedTokens(
      _fundingCycle.configuration,
      _fundingCycle.number,
      _projectId,
      _owner,
      tokenCount,
      _leftoverTokenCount,
      _memo,
      msg.sender
    );
  }

  /**
    @notice
    Distribute tokens to the splits according to the specified funding cycle configuration.

    @param _projectId The ID of the project for which reserved token splits are being distributed.
    @param _fundingCycle The funding cycle to base the token distribution on.
    @param _amount The total amount of tokens to mint.

    @return leftoverAmount If the splits percents dont add up to 100%, the leftover amount is returned.
  */
  function _distributeToReservedTokenSplitsOf(
    uint256 _projectId,
    JBFundingCycle memory _fundingCycle,
    uint256 _amount
  ) private returns (uint256 leftoverAmount) {
    // Set the leftover amount to the initial amount.
    leftoverAmount = _amount;

    // Get a reference to the project's reserved token splits.
    JBSplit[] memory _splits = splitsStore.splitsOf(
      _projectId,
      _fundingCycle.configuration,
      JBSplitsGroups.RESERVED_TOKENS
    );

    //Transfer between all splits.
    for (uint256 _i = 0; _i < _splits.length; _i++) {
      // Get a reference to the split being iterated on.
      JBSplit memory _split = _splits[_i];

      // The amount to send towards the split.
      uint256 _tokenCount = PRBMath.mulDiv(
        _amount,
        _split.percent,
        JBConstants.SPLITS_TOTAL_PERCENT
      );

      // Mints tokens for the split if needed.
      if (_tokenCount > 0) {
        tokenStore.mintFor(
          // If an allocator is set in the splits, set it as the beneficiary.
          // Otherwise if a projectId is set in the split, set the project's owner as the beneficiary.
          // If the split has a beneficiary send to the split's beneficiary. Otherwise send to the msg.sender.
          _split.allocator != IJBSplitAllocator(address(0))
            ? address(_split.allocator)
            : _split.projectId != 0
            ? projects.ownerOf(_split.projectId)
            : _split.beneficiary != address(0)
            ? _split.beneficiary
            : msg.sender,
          _projectId,
          _tokenCount,
          _split.preferClaimed
        );

        // If there's an allocator set, trigger its `allocate` function.
        if (_split.allocator != IJBSplitAllocator(address(0)))
          _split.allocator.allocate(
            JBSplitAllocationData(
              _tokenCount,
              18,
              _projectId,
              JBSplitsGroups.RESERVED_TOKENS,
              _split
            )
          );

        // Subtract from the amount to be sent to the beneficiary.
        leftoverAmount = leftoverAmount - _tokenCount;
      }

      emit DistributeToReservedTokenSplit(
        _fundingCycle.configuration,
        _fundingCycle.number,
        _projectId,
        _split,
        _tokenCount,
        msg.sender
      );
    }
  }

  /**
    @notice
    Configures a funding cycle and stores information pertinent to the configuration.

    @param _projectId The ID of the project whose funding cycles are being reconfigured.
    @param _data Data that defines the funding cycle. These properties will remain fixed for the duration of the funding cycle.
    @param _metadata Metadata specifying the controller specific params that a funding cycle can have. These properties will remain fixed for the duration of the funding cycle.
    @param _mustStartAtOrAfter The time before which the configured funding cycle cannot start.
    @param _groupedSplits An array of splits to set for any number of groups. 
    @param _fundAccessConstraints An array containing amounts that a project can use from its treasury for each payment terminal. Amounts are fixed point numbers using the same number of decimals as the accompanying terminal.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
  function _configure(
    uint256 _projectId,
    JBFundingCycleData calldata _data,
    JBFundingCycleMetadata calldata _metadata,
    uint256 _mustStartAtOrAfter,
    JBGroupedSplits[] memory _groupedSplits,
    JBFundAccessConstraints[] memory _fundAccessConstraints
  ) private returns (uint256) {
    // Make sure the provided reserved rate is valid.
    if (_metadata.reservedRate > JBConstants.MAX_RESERVED_RATE) revert INVALID_RESERVED_RATE();

    // Make sure the provided redemption rate is valid.
    if (_metadata.redemptionRate > JBConstants.MAX_REDEMPTION_RATE)
      revert INVALID_REDEMPTION_RATE();

    // Make sure the provided ballot redemption rate is valid.
    if (_metadata.ballotRedemptionRate > JBConstants.MAX_REDEMPTION_RATE)
      revert INVALID_BALLOT_REDEMPTION_RATE();

    // Configure the funding cycle's properties.
    JBFundingCycle memory _fundingCycle = fundingCycleStore.configureFor(
      _projectId,
      _data,
      JBFundingCycleMetadataResolver.packFundingCycleMetadata(_metadata),
      _mustStartAtOrAfter
    );

    for (uint256 _i; _i < _groupedSplits.length; _i++)
      // Set splits for the current group being iterated on if there are any.
      if (_groupedSplits[_i].splits.length > 0)
        splitsStore.set(
          _projectId,
          _fundingCycle.configuration,
          _groupedSplits[_i].group,
          _groupedSplits[_i].splits
        );

    // Set distribution limits if there are any.
    for (uint256 _i; _i < _fundAccessConstraints.length; _i++) {
      JBFundAccessConstraints memory _constraints = _fundAccessConstraints[_i];

      // If distribution limit value is larger than 248 bits, revert.
      if (_constraints.distributionLimit > type(uint248).max) revert INVALID_DISTRIBUTION_LIMIT();

      // If distribution limit currency value is larger than 8 bits, revert.
      if (_constraints.distributionLimitCurrency > type(uint8).max)
        revert INVALID_DISTRIBUTION_LIMIT_CURRENCY();

      // If overflow allowance value is larger than 248 bits, revert.
      if (_constraints.overflowAllowance > type(uint248).max) revert INVALID_OVERFLOW_ALLOWANCE();

      // If overflow allowance currency value is larger than 8 bits, revert.
      if (_constraints.overflowAllowanceCurrency > type(uint8).max)
        revert INVALID_OVERFLOW_ALLOWANCE_CURRENCY();

      // Set the distribution limit if there is one.
      if (_constraints.distributionLimit > 0)
        _packedDistributionLimitDataOf[_projectId][_fundingCycle.configuration][
          _constraints.terminal
        ] = _constraints.distributionLimit | (_constraints.distributionLimitCurrency << 248);

      // Set the overflow allowance if there is one.
      if (_constraints.overflowAllowance > 0)
        _packedOverflowAllowanceDataOf[_projectId][_fundingCycle.configuration][
          _constraints.terminal
        ] = _constraints.overflowAllowance | (_constraints.overflowAllowanceCurrency << 248);

      emit SetFundAccessConstraints(
        _fundingCycle.configuration,
        _fundingCycle.number,
        _projectId,
        _constraints,
        msg.sender
      );
    }

    return _fundingCycle.configuration;
  }

  /**
    @notice
    Gets the amount of reserved tokens currently tracked for a project given a reserved rate.

    @param _processedTokenTracker The tracker to make the calculation with.
    @param _reservedRate The reserved rate to use to make the calculation.
    @param _totalEligibleTokens The total amount to make the calculation with.

    @return amount reserved token amount.
  */
  function _reservedTokenAmountFrom(
    int256 _processedTokenTracker,
    uint256 _reservedRate,
    uint256 _totalEligibleTokens
  ) private pure returns (uint256) {
    // Get a reference to the amount of tokens that are unprocessed.
    uint256 _unprocessedTokenBalanceOf = _processedTokenTracker >= 0
      ? _totalEligibleTokens - uint256(_processedTokenTracker)
      : _totalEligibleTokens + uint256(-_processedTokenTracker);

    // If there are no unprocessed tokens, return.
    if (_unprocessedTokenBalanceOf == 0) return 0;

    // If all tokens are reserved, return the full unprocessed amount.
    if (_reservedRate == JBConstants.MAX_RESERVED_RATE) return _unprocessedTokenBalanceOf;

    return
      PRBMath.mulDiv(
        _unprocessedTokenBalanceOf,
        JBConstants.MAX_RESERVED_RATE,
        JBConstants.MAX_RESERVED_RATE - _reservedRate
      ) - _unprocessedTokenBalanceOf;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBOperatable.sol';

// --------------------------- custom errors -------------------------- //
//*********************************************************************//
error UNAUTHORIZED();

/** 
  @notice
  Modifiers to allow access to functions based on the message sender's operator status.
*/
abstract contract JBOperatable is IJBOperatable {
  modifier requirePermission(
    address _account,
    uint256 _domain,
    uint256 _permissionIndex
  ) {
    if (
      msg.sender != _account &&
      !operatorStore.hasPermission(msg.sender, _account, _domain, _permissionIndex) &&
      !operatorStore.hasPermission(msg.sender, _account, 0, _permissionIndex)
    ) revert UNAUTHORIZED();

    _;
  }

  modifier requirePermissionAllowingOverride(
    address _account,
    uint256 _domain,
    uint256 _permissionIndex,
    bool _override
  ) {
    if (
      !_override &&
      msg.sender != _account &&
      !operatorStore.hasPermission(msg.sender, _account, _domain, _permissionIndex) &&
      !operatorStore.hasPermission(msg.sender, _account, 0, _permissionIndex)
    ) revert UNAUTHORIZED();

    _;
  }

  /** 
    @notice 
    A contract storing operator assignments.
  */
  IJBOperatorStore public immutable override operatorStore;

  /** 
    @param _operatorStore A contract storing operator assignments.
  */
  constructor(IJBOperatorStore _operatorStore) {
    operatorStore = _operatorStore;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

enum JBBallotState {
  Approved,
  Active,
  Failed
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../structs/JBFundingCycleData.sol';
import './../structs/JBFundingCycleMetadata.sol';
import './../structs/JBProjectMetadata.sol';
import './../structs/JBGroupedSplits.sol';
import './../structs/JBFundAccessConstraints.sol';
import './IJBDirectory.sol';
import './IJBToken.sol';
import './IJBPaymentTerminal.sol';
import './IJBFundingCycleStore.sol';
import './IJBTokenStore.sol';
import './IJBSplitsStore.sol';

interface IJBController {
  event LaunchProject(uint256 configuration, uint256 projectId, string memo, address caller);

  event LaunchFundingCycles(uint256 configuration, uint256 projectId, string memo, address caller);

  event ReconfigureFundingCycles(
    uint256 configuration,
    uint256 projectId,
    string memo,
    address caller
  );

  event SetFundAccessConstraints(
    uint256 indexed fundingCycleConfiguration,
    uint256 indexed fundingCycleNumber,
    uint256 indexed projectId,
    JBFundAccessConstraints constraints,
    address caller
  );

  event DistributeReservedTokens(
    uint256 indexed fundingCycleConfiguration,
    uint256 indexed fundingCycleNumber,
    uint256 indexed projectId,
    address beneficiary,
    uint256 tokenCount,
    uint256 beneficiaryTokenCount,
    string memo,
    address caller
  );

  event DistributeToReservedTokenSplit(
    uint256 indexed fundingCycleConfiguration,
    uint256 indexed fundingCycleNumber,
    uint256 indexed projectId,
    JBSplit split,
    uint256 tokenCount,
    address caller
  );

  event MintTokens(
    address indexed beneficiary,
    uint256 indexed projectId,
    uint256 tokenCount,
    uint256 beneficiaryTokenCount,
    string memo,
    uint256 reservedRate,
    address caller
  );

  event BurnTokens(
    address indexed holder,
    uint256 indexed projectId,
    uint256 tokenCount,
    string memo,
    address caller
  );

  event Migrate(uint256 indexed projectId, IJBController to, address caller);

  event PrepMigration(uint256 indexed projectId, IJBController from, address caller);

  function projects() external view returns (IJBProjects);

  function fundingCycleStore() external view returns (IJBFundingCycleStore);

  function tokenStore() external view returns (IJBTokenStore);

  function splitsStore() external view returns (IJBSplitsStore);

  function directory() external view returns (IJBDirectory);

  function reservedTokenBalanceOf(uint256 _projectId, uint256 _reservedRate)
    external
    view
    returns (uint256);

  function distributionLimitOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal
  ) external view returns (uint256 distributionLimit, uint256 distributionLimitCurrency);

  function overflowAllowanceOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal
  ) external view returns (uint256 overflowAllowance, uint256 overflowAllowanceCurrency);

  function totalOutstandingTokensOf(uint256 _projectId, uint256 _reservedRate)
    external
    view
    returns (uint256);

  function launchProjectFor(
    address _owner,
    JBProjectMetadata calldata _projectMetadata,
    JBFundingCycleData calldata _data,
    JBFundingCycleMetadata calldata _metadata,
    uint256 _mustStartAtOrAfter,
    JBGroupedSplits[] memory _groupedSplits,
    JBFundAccessConstraints[] memory _fundAccessConstraints,
    IJBPaymentTerminal[] memory _terminals,
    string calldata _memo
  ) external returns (uint256 projectId);

  function launchFundingCyclesFor(
    uint256 _projectId,
    JBFundingCycleData calldata _data,
    JBFundingCycleMetadata calldata _metadata,
    uint256 _mustStartAtOrAfter,
    JBGroupedSplits[] memory _groupedSplits,
    JBFundAccessConstraints[] memory _fundAccessConstraints,
    IJBPaymentTerminal[] memory _terminals,
    string calldata _memo
  ) external returns (uint256 configuration);

  function reconfigureFundingCyclesOf(
    uint256 _projectId,
    JBFundingCycleData calldata _data,
    JBFundingCycleMetadata calldata _metadata,
    uint256 _mustStartAtOrAfter,
    JBGroupedSplits[] memory _groupedSplits,
    JBFundAccessConstraints[] memory _fundAccessConstraints,
    string calldata _memo
  ) external returns (uint256);

  function issueTokenFor(
    uint256 _projectId,
    string calldata _name,
    string calldata _symbol
  ) external returns (IJBToken token);

  function changeTokenOf(
    uint256 _projectId,
    IJBToken _token,
    address _newOwner
  ) external;

  function mintTokensOf(
    uint256 _projectId,
    uint256 _tokenCount,
    address _beneficiary,
    string calldata _memo,
    bool _preferClaimedTokens,
    bool _useReservedRate
  ) external returns (uint256 beneficiaryTokenCount);

  function burnTokensOf(
    address _holder,
    uint256 _projectId,
    uint256 _tokenCount,
    string calldata _memo,
    bool _preferClaimedTokens
  ) external;

  function distributeReservedTokensOf(uint256 _projectId, string memory _memo)
    external
    returns (uint256);

  function prepForMigrationOf(uint256 _projectId, IJBController _from) external;

  function migrate(uint256 _projectId, IJBController _to) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBPaymentTerminal.sol';
import './IJBProjects.sol';
import './IJBFundingCycleStore.sol';
import './IJBController.sol';

interface IJBDirectory {
  event SetController(uint256 indexed projectId, IJBController indexed controller, address caller);

  event AddTerminal(uint256 indexed projectId, IJBPaymentTerminal indexed terminal, address caller);

  event SetTerminals(uint256 indexed projectId, IJBPaymentTerminal[] terminals, address caller);

  event SetPrimaryTerminal(
    uint256 indexed projectId,
    address indexed token,
    IJBPaymentTerminal indexed terminal,
    address caller
  );

  event SetIsAllowedToSetFirstController(address indexed addr, bool indexed flag, address caller);

  function projects() external view returns (IJBProjects);

  function fundingCycleStore() external view returns (IJBFundingCycleStore);

  function controllerOf(uint256 _projectId) external view returns (IJBController);

  function isAllowedToSetFirstController(address _address) external view returns (bool);

  function terminalsOf(uint256 _projectId) external view returns (IJBPaymentTerminal[] memory);

  function isTerminalOf(uint256 _projectId, IJBPaymentTerminal _terminal)
    external
    view
    returns (bool);

  function primaryTerminalOf(uint256 _projectId, address _token)
    external
    view
    returns (IJBPaymentTerminal);

  function setControllerOf(uint256 _projectId, IJBController _controller) external;

  function setTerminalsOf(uint256 _projectId, IJBPaymentTerminal[] calldata _terminals) external;

  function setPrimaryTerminalOf(uint256 _projectId, IJBPaymentTerminal _terminal) external;

  function setIsAllowedToSetFirstController(address _address, bool _flag) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../enums/JBBallotState.sol';

interface IJBFundingCycleBallot {
  function duration() external view returns (uint256);

  function stateOf(uint256 _projectId, uint256 _configuration)
    external
    view
    returns (JBBallotState);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBFundingCycleStore.sol';

import './IJBPayDelegate.sol';
import './IJBRedemptionDelegate.sol';

import './../structs/JBPayParamsData.sol';
import './../structs/JBRedeemParamsData.sol';

interface IJBFundingCycleDataSource {
  function payParams(JBPayParamsData calldata _data)
    external
    view
    returns (
      uint256 weight,
      string memory memo,
      IJBPayDelegate delegate
    );

  function redeemParams(JBRedeemParamsData calldata _data)
    external
    view
    returns (
      uint256 reclaimAmount,
      string memory memo,
      IJBRedemptionDelegate delegate
    );
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBFundingCycleBallot.sol';
import './../structs/JBFundingCycle.sol';
import './../structs/JBFundingCycleData.sol';

interface IJBFundingCycleStore {
  event Configure(
    uint256 indexed configuration,
    uint256 indexed projectId,
    JBFundingCycleData data,
    uint256 metadata,
    uint256 mustStartAtOrAfter,
    address caller
  );

  event Init(uint256 indexed configuration, uint256 indexed projectId, uint256 indexed basedOn);

  function latestConfigurationOf(uint256 _projectId) external view returns (uint256);

  function get(uint256 _projectId, uint256 _configuration)
    external
    view
    returns (JBFundingCycle memory);

  function queuedOf(uint256 _projectId) external view returns (JBFundingCycle memory);

  function currentOf(uint256 _projectId) external view returns (JBFundingCycle memory);

  function currentBallotStateOf(uint256 _projectId) external view returns (JBBallotState);

  function configureFor(
    uint256 _projectId,
    JBFundingCycleData calldata _data,
    uint256 _metadata,
    uint256 _mustStartAtOrAfter
  ) external returns (JBFundingCycle memory fundingCycle);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBOperatorStore.sol';

interface IJBOperatable {
  function operatorStore() external view returns (IJBOperatorStore);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../structs/JBOperatorData.sol';

interface IJBOperatorStore {
  event SetOperator(
    address indexed operator,
    address indexed account,
    uint256 indexed domain,
    uint256[] permissionIndexes,
    uint256 packed
  );

  function permissionsOf(
    address _operator,
    address _account,
    uint256 _domain
  ) external view returns (uint256);

  function hasPermission(
    address _operator,
    address _account,
    uint256 _domain,
    uint256 _permissionIndex
  ) external view returns (bool);

  function hasPermissions(
    address _operator,
    address _account,
    uint256 _domain,
    uint256[] calldata _permissionIndexes
  ) external view returns (bool);

  function setOperator(JBOperatorData calldata _operatorData) external;

  function setOperators(JBOperatorData[] calldata _operatorData) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../structs/JBDidPayData.sol';

interface IJBPayDelegate {
  function didPay(JBDidPayData calldata _data) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBDirectory.sol';

interface IJBPaymentTerminal {
  function token() external view returns (address);

  function currency() external view returns (uint256);

  function decimals() external view returns (uint256);

  // Return value must be a fixed point number with 18 decimals.
  function currentEthOverflowOf(uint256 _projectId) external view returns (uint256);

  function pay(
    uint256 _amount,
    uint256 _projectId,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string calldata _memo,
    bytes calldata _metadata
  ) external payable;

  function addToBalanceOf(
    uint256 _projectId,
    uint256 _amount,
    string calldata _memo
  ) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IJBPriceFeed {
  function currentPrice(uint256 _targetDecimals) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBPriceFeed.sol';

interface IJBPrices {
  event AddFeed(uint256 indexed currency, uint256 indexed base, IJBPriceFeed feed);

  function feedFor(uint256 _currency, uint256 _base) external view returns (IJBPriceFeed);

  function priceFor(
    uint256 _currency,
    uint256 _base,
    uint256 _decimals
  ) external view returns (uint256);

  function addFeedFor(
    uint256 _currency,
    uint256 _base,
    IJBPriceFeed _priceFeed
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import './IJBPaymentTerminal.sol';
import './IJBTokenUriResolver.sol';

import './../structs/JBProjectMetadata.sol';
import './IJBTokenUriResolver.sol';

interface IJBProjects is IERC721 {
  event Create(
    uint256 indexed projectId,
    address indexed owner,
    JBProjectMetadata metadata,
    address caller
  );

  event SetMetadata(uint256 indexed projectId, JBProjectMetadata metadata, address caller);

  event SetTokenUriResolver(IJBTokenUriResolver resolver, address caller);

  function count() external view returns (uint256);

  function metadataContentOf(uint256 _projectId, uint256 _domain)
    external
    view
    returns (string memory);

  function tokenUriResolver() external view returns (IJBTokenUriResolver);

  function createFor(address _owner, JBProjectMetadata calldata _metadata)
    external
    returns (uint256 projectId);

  function setMetadataOf(uint256 _projectId, JBProjectMetadata calldata _metadata) external;

  function setTokenUriResolver(IJBTokenUriResolver _newResolver) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBFundingCycleStore.sol';

import './../structs/JBDidRedeemData.sol';

interface IJBRedemptionDelegate {
  function didRedeem(JBDidRedeemData calldata _data) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '../structs/JBSplitAllocationData.sol';

interface IJBSplitAllocator {
  function allocate(JBSplitAllocationData calldata _data) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBOperatorStore.sol';
import './IJBProjects.sol';
import './IJBDirectory.sol';
import './IJBSplitAllocator.sol';

import './../structs/JBSplit.sol';

interface IJBSplitsStore {
  event SetSplit(
    uint256 indexed projectId,
    uint256 indexed domain,
    uint256 indexed group,
    JBSplit split,
    address caller
  );

  function projects() external view returns (IJBProjects);

  function directory() external view returns (IJBDirectory);

  function splitsOf(
    uint256 _projectId,
    uint256 _domain,
    uint256 _group
  ) external view returns (JBSplit[] memory);

  function set(
    uint256 _projectId,
    uint256 _domain,
    uint256 _group,
    JBSplit[] memory _splits
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IJBToken {
  function decimals() external view returns (uint8);

  function totalSupply(uint256 _projectId) external view returns (uint256);

  function balanceOf(address _account, uint256 _projectId) external view returns (uint256);

  function mint(
    uint256 _projectId,
    address _account,
    uint256 _amount
  ) external;

  function burn(
    uint256 _projectId,
    address _account,
    uint256 _amount
  ) external;

  function approve(
    uint256,
    address _spender,
    uint256 _amount
  ) external;

  function transfer(
    uint256 _projectId,
    address _to,
    uint256 _amount
  ) external;

  function transferFrom(
    uint256 _projectId,
    address _from,
    address _to,
    uint256 _amount
  ) external;

  function transferOwnership(address _newOwner) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IJBProjects.sol';
import './IJBToken.sol';

interface IJBTokenStore {
  event Issue(
    uint256 indexed projectId,
    IJBToken indexed token,
    string name,
    string symbol,
    address caller
  );

  event Mint(
    address indexed holder,
    uint256 indexed projectId,
    uint256 amount,
    bool tokensWereClaimed,
    bool preferClaimedTokens,
    address caller
  );

  event Burn(
    address indexed holder,
    uint256 indexed projectId,
    uint256 amount,
    uint256 initialUnclaimedBalance,
    uint256 initialClaimedBalance,
    bool preferClaimedTokens,
    address caller
  );

  event Claim(
    address indexed holder,
    uint256 indexed projectId,
    uint256 initialUnclaimedBalance,
    uint256 amount,
    address caller
  );

  event ShouldRequireClaim(uint256 indexed projectId, bool indexed flag, address caller);

  event Change(
    uint256 indexed projectId,
    IJBToken indexed newToken,
    IJBToken indexed oldToken,
    address owner,
    address caller
  );

  event Transfer(
    address indexed holder,
    uint256 indexed projectId,
    address indexed recipient,
    uint256 amount,
    address caller
  );

  function tokenOf(uint256 _projectId) external view returns (IJBToken);

  function projects() external view returns (IJBProjects);

  function unclaimedBalanceOf(address _holder, uint256 _projectId) external view returns (uint256);

  function unclaimedTotalSupplyOf(uint256 _projectId) external view returns (uint256);

  function totalSupplyOf(uint256 _projectId) external view returns (uint256);

  function balanceOf(address _holder, uint256 _projectId) external view returns (uint256 _result);

  function requireClaimFor(uint256 _projectId) external view returns (bool);

  function issueFor(
    uint256 _projectId,
    string calldata _name,
    string calldata _symbol
  ) external returns (IJBToken token);

  function changeFor(
    uint256 _projectId,
    IJBToken _token,
    address _newOwner
  ) external returns (IJBToken oldToken);

  function burnFrom(
    address _holder,
    uint256 _projectId,
    uint256 _amount,
    bool _preferClaimedTokens
  ) external;

  function mintFor(
    address _holder,
    uint256 _projectId,
    uint256 _amount,
    bool _preferClaimedTokens
  ) external;

  function shouldRequireClaimingFor(uint256 _projectId, bool _flag) external;

  function claimFor(
    address _holder,
    uint256 _projectId,
    uint256 _amount
  ) external;

  function transferFrom(
    address _holder,
    uint256 _projectId,
    address _recipient,
    uint256 _amount
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IJBTokenUriResolver {
  function getUri(uint256 _projectId) external view returns (string memory tokenUri);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/**
  @notice
  Global constants used across multiple Juicebox contracts.
*/
library JBConstants {
  /** 
    @notice
    Maximum value for reserved, redemption, and ballot redemption rates. Does not include discount rate.
  */
  uint256 public constant MAX_RESERVED_RATE = 10000;

  /**
    @notice
    Maximum token redemption rate.  
    */
  uint256 public constant MAX_REDEMPTION_RATE = 10000;

  /** 
    @notice
    A funding cycle's discount rate is expressed as a percentage out of 1000000000.
  */
  uint256 public constant MAX_DISCOUNT_RATE = 1000000000;

  /** 
    @notice
    Maximum splits percentage.
  */
  uint256 public constant SPLITS_TOTAL_PERCENT = 1000000000;

  /** 
    @notice
    Maximum fee rate as a percentage out of 1000000000
  */
  uint256 public constant MAX_FEE = 1000000000;

  /** 
    @notice
    Maximum discount on fee granted by a gauge.
  */
  uint256 public constant MAX_FEE_DISCOUNT = 1000000000;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './JBConstants.sol';
import './../interfaces/IJBFundingCycleStore.sol';
import './../interfaces/IJBFundingCycleDataSource.sol';
import './../structs/JBFundingCycleMetadata.sol';

library JBFundingCycleMetadataResolver {
  function reservedRate(JBFundingCycle memory _fundingCycle) internal pure returns (uint256) {
    return uint256(uint16(_fundingCycle.metadata >> 8));
  }

  function redemptionRate(JBFundingCycle memory _fundingCycle) internal pure returns (uint256) {
    // Redemption rate is a number 0-10000. It's inverse was stored so the most common case of 100% results in no storage needs.
    return JBConstants.MAX_REDEMPTION_RATE - uint256(uint16(_fundingCycle.metadata >> 24));
  }

  function ballotRedemptionRate(JBFundingCycle memory _fundingCycle)
    internal
    pure
    returns (uint256)
  {
    // Redemption rate is a number 0-10000. It's inverse was stored so the most common case of 100% results in no storage needs.
    return JBConstants.MAX_REDEMPTION_RATE - uint256(uint16(_fundingCycle.metadata >> 40));
  }

  function payPaused(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 56) & 1) == 1;
  }

  function distributionsPaused(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 57) & 1) == 1;
  }

  function redeemPaused(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 58) & 1) == 1;
  }

  function mintPaused(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 59) & 1) == 1;
  }

  function burnPaused(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 60) & 1) == 1;
  }

  function changeTokenAllowed(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 61) & 1) == 1;
  }

  function terminalMigrationAllowed(JBFundingCycle memory _fundingCycle)
    internal
    pure
    returns (bool)
  {
    return ((_fundingCycle.metadata >> 62) & 1) == 1;
  }

  function controllerMigrationAllowed(JBFundingCycle memory _fundingCycle)
    internal
    pure
    returns (bool)
  {
    return ((_fundingCycle.metadata >> 63) & 1) == 1;
  }

  function setTerminalsAllowed(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 64) & 1) == 1;
  }

  function setControllerAllowed(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 65) & 1) == 1;
  }

  function shouldHoldFees(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return ((_fundingCycle.metadata >> 66) & 1) == 1;
  }

  function useTotalOverflowForRedemptions(JBFundingCycle memory _fundingCycle)
    internal
    pure
    returns (bool)
  {
    return ((_fundingCycle.metadata >> 67) & 1) == 1;
  }

  function useDataSourceForPay(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
    return (_fundingCycle.metadata >> 68) & 1 == 1;
  }

  function useDataSourceForRedeem(JBFundingCycle memory _fundingCycle)
    internal
    pure
    returns (bool)
  {
    return (_fundingCycle.metadata >> 69) & 1 == 1;
  }

  function dataSource(JBFundingCycle memory _fundingCycle)
    internal
    pure
    returns (IJBFundingCycleDataSource)
  {
    return IJBFundingCycleDataSource(address(uint160(_fundingCycle.metadata >> 70)));
  }

  /**
    @notice
    Pack the funding cycle metadata.

    @param _metadata The metadata to validate and pack.

    @return packed The packed uint256 of all metadata params. The first 8 bits specify the version.
  */
  function packFundingCycleMetadata(JBFundingCycleMetadata memory _metadata)
    internal
    pure
    returns (uint256 packed)
  {
    // version 1 in the bits 0-7 (8 bits).
    packed = 1;
    // reserved rate in bits 8-23 (16 bits).
    packed |= _metadata.reservedRate << 8;
    // redemption rate in bits 24-39 (16 bits).
    // redemption rate is a number 0-10000. Store the reverse so the most common case of 100% results in no storage needs.
    packed |= (JBConstants.MAX_REDEMPTION_RATE - _metadata.redemptionRate) << 24;
    // ballot redemption rate rate in bits 40-55 (16 bits).
    // ballot redemption rate is a number 0-10000. Store the reverse so the most common case of 100% results in no storage needs.
    packed |= (JBConstants.MAX_REDEMPTION_RATE - _metadata.ballotRedemptionRate) << 40;
    // pause pay in bit 56.
    if (_metadata.pausePay) packed |= 1 << 56;
    // pause tap in bit 57.
    if (_metadata.pauseDistributions) packed |= 1 << 57;
    // pause redeem in bit 58.
    if (_metadata.pauseRedeem) packed |= 1 << 58;
    // pause mint in bit 59.
    if (_metadata.pauseMint) packed |= 1 << 59;
    // pause mint in bit 60.
    if (_metadata.pauseBurn) packed |= 1 << 60;
    // pause change token in bit 61.
    if (_metadata.allowChangeToken) packed |= 1 << 61;
    // allow terminal migration in bit 62.
    if (_metadata.allowTerminalMigration) packed |= 1 << 62;
    // allow controller migration in bit 63.
    if (_metadata.allowControllerMigration) packed |= 1 << 63;
    // allow set terminals in bit 64.
    if (_metadata.allowSetTerminals) packed |= 1 << 64;
    // allow set controller in bit 65.
    if (_metadata.allowSetController) packed |= 1 << 65;
    // hold fees in bit 66.
    if (_metadata.holdFees) packed |= 1 << 66;
    // useTotalOverflowForRedemptions in bit 67.
    if (_metadata.useTotalOverflowForRedemptions) packed |= 1 << 67;
    // use pay data source in bit 68.
    if (_metadata.useDataSourceForPay) packed |= 1 << 68;
    // use redeem data source in bit 69.
    if (_metadata.useDataSourceForRedeem) packed |= 1 << 69;
    // data source address in bits 70-229.
    packed |= uint256(uint160(address(_metadata.dataSource))) << 70;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

library JBOperations {
  uint256 public constant RECONFIGURE = 1;
  uint256 public constant REDEEM = 2;
  uint256 public constant MIGRATE_CONTROLLER = 3;
  uint256 public constant MIGRATE_TERMINAL = 4;
  uint256 public constant PROCESS_FEES = 5;
  uint256 public constant SET_METADATA = 6;
  uint256 public constant ISSUE = 7;
  uint256 public constant CHANGE_TOKEN = 8;
  uint256 public constant MINT = 9;
  uint256 public constant BURN = 10;
  uint256 public constant CLAIM = 11;
  uint256 public constant TRANSFER = 12;
  uint256 public constant REQUIRE_CLAIM = 13;
  uint256 public constant SET_CONTROLLER = 14;
  uint256 public constant SET_TERMINALS = 15;
  uint256 public constant SET_PRIMARY_TERMINAL = 16;
  uint256 public constant USE_ALLOWANCE = 17;
  uint256 public constant SET_SPLITS = 18;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

library JBSplitsGroups {
  uint256 public constant ETH_PAYOUT = 1;
  uint256 public constant RESERVED_TOKENS = 2;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './JBTokenAmount.sol';

struct JBDidPayData {
  // The address from which the payment originated.
  address payer;
  // The ID of the project for which the payment was made.
  uint256 projectId;
  // The amount of the payment. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
  JBTokenAmount amount;
  // The number of project tokens minted for the beneficiary.
  uint256 projectTokenCount;
  // The address to which the tokens were minted.
  address beneficiary;
  // The memo that is being emitted alongside the payment.
  string memo;
  // Metadata to send to the delegate.
  bytes metadata;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './JBTokenAmount.sol';

struct JBDidRedeemData {
  // The holder of the tokens being redeemed.
  address holder;
  // The project to which the redeemed tokens are associated.
  uint256 projectId;
  // The number of project tokens being redeemed.
  uint256 projectTokenCount;
  // The reclaimed amount. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
  JBTokenAmount reclaimedAmount;
  // The address to which the reclaimed amount will be sent.
  address payable beneficiary;
  // The memo that is being emitted alongside the redemption.
  string memo;
  // Metadata to send to the delegate.
  bytes metadata;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBPaymentTerminal.sol';

struct JBFundAccessConstraints {
  // The terminal within which the distribution limit and the overflow allowance applies.
  IJBPaymentTerminal terminal;
  // The amount of the distribution limit, as a fixed point number with the same number of decimals as the terminal within which the limit applies.
  uint256 distributionLimit;
  // The currency of the distribution limit.
  uint256 distributionLimitCurrency;
  // The amount of the allowance, as a fixed point number with the same number of decimals as the terminal within which the allowance applies.
  uint256 overflowAllowance;
  // The currency of the overflow allowance.
  uint256 overflowAllowanceCurrency;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBFundingCycleBallot.sol';

struct JBFundingCycle {
  // The funding cycle number for each project.
  // Each funding cycle has a number that is an increment of the cycle that directly preceded it.
  // Each project's first funding cycle has a number of 1.
  uint256 number;
  // The timestamp when the parameters for this funding cycle were configured.
  // This value will stay the same for subsequent funding cycles that roll over from an originally configured cycle.
  uint256 configuration;
  // The `configuration` of the funding cycle that was active when this cycle was created.
  uint256 basedOn;
  // The timestamp marking the moment from which the funding cycle is considered active.
  // It is a unix timestamp measured in seconds.
  uint256 start;
  // The number of seconds the funding cycle lasts for, after which a new funding cycle will start.
  // A duration of 0 means that the funding cycle will stay active until the project owner explicitly issues a reconfiguration, at which point a new funding cycle will immediately start with the updated properties.
  // If the duration is greater than 0, a project owner cannot make changes to a funding cycle's parameters while it is active – any proposed changes will apply to the subsequent cycle.
  // If no changes are proposed, a funding cycle rolls over to another one with the same properties but new `start` timestamp and a discounted `weight`.
  uint256 duration;
  // A fixed point number with 18 decimals that contracts can use to base arbitrary calculations on.
  // For example, payment terminals can use this to determine how many tokens should be minted when a payment is received.
  uint256 weight;
  // A percent by how much the `weight` of the subsequent funding cycle should be reduced, if the project owner hasn't configured the subsequent funding cycle with an explicit `weight`.
  // If it's 0, each funding cycle will have equal weight.
  // If the number is 90%, the next funding cycle will have a 10% smaller weight.
  // This weight is out of `JBConstants.MAX_DISCOUNT_RATE`.
  uint256 discountRate;
  // An address of a contract that says whether a proposed reconfiguration should be accepted or rejected.
  // It can be used to create rules around how a project owner can change funding cycle parameters over time.
  IJBFundingCycleBallot ballot;
  // Extra data that can be associated with a funding cycle.
  uint256 metadata;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBFundingCycleBallot.sol';

struct JBFundingCycleData {
  // The number of seconds the funding cycle lasts for, after which a new funding cycle will start.
  // A duration of 0 means that the funding cycle will stay active until the project owner explicitly issues a reconfiguration, at which point a new funding cycle will immediately start with the updated properties.
  // If the duration is greater than 0, a project owner cannot make changes to a funding cycle's parameters while it is active – any proposed changes will apply to the subsequent cycle.
  // If no changes are proposed, a funding cycle rolls over to another one with the same properties but new `start` timestamp and a discounted `weight`.
  uint256 duration;
  // A fixed point number with 18 decimals that contracts can use to base arbitrary calculations on.
  // For example, payment terminals can use this to determine how many tokens should be minted when a payment is received.
  uint256 weight;
  // A percent by how much the `weight` of the subsequent funding cycle should be reduced, if the project owner hasn't configured the subsequent funding cycle with an explicit `weight`.
  // If it's 0, each funding cycle will have equal weight.
  // If the number is 90%, the next funding cycle will have a 10% smaller weight.
  // This weight is out of `JBConstants.MAX_DISCOUNT_RATE`.
  uint256 discountRate;
  // An address of a contract that says whether a proposed reconfiguration should be accepted or rejected.
  // It can be used to create rules around how a project owner can change funding cycle parameters over time.
  IJBFundingCycleBallot ballot;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBFundingCycleDataSource.sol';

struct JBFundingCycleMetadata {
  // The reserved rate of the funding cycle. This number is a percentage calculated out of `JBConstants.MAX_RESERVED_RATE`.
  uint256 reservedRate;
  // The redemption rate of the funding cycle. This number is a percentage calculated out of `JBConstants.MAX_REDEMPTION_RATE`.
  uint256 redemptionRate;
  // The redemption rate to use during an active ballot of the funding cycle. This number is a percentage calculated out of `JBConstants.MAX_REDEMPTION_RATE`.
  uint256 ballotRedemptionRate;
  // If the pay functionality should be paused during the funding cycle.
  bool pausePay;
  // If the distribute functionality should be paused during the funding cycle.
  bool pauseDistributions;
  // If the redeem functionality should be paused during the funding cycle.
  bool pauseRedeem;
  // If the mint functionality should be paused during the funding cycle.
  bool pauseMint;
  // If the burn functionality should be paused during the funding cycle.
  bool pauseBurn;
  // If changing tokens should be allowed during this funding cycle.
  bool allowChangeToken;
  // If migrating terminals should be allowed during this funding cycle.
  bool allowTerminalMigration;
  // If migrating controllers should be allowed during this funding cycle.
  bool allowControllerMigration;
  // If setting terminals should be allowed during this funding cycle.
  bool allowSetTerminals;
  // If setting a new controller should be allowed during this funding cycle.
  bool allowSetController;
  // If fees should be held during this funding cycle.
  bool holdFees;
  // If redemptions should use the project's balance held in all terminals instead of the project's local terminal balance from which the redemption is being fulfilled.
  bool useTotalOverflowForRedemptions;
  // If the data source should be used for pay transactions during this funding cycle.
  bool useDataSourceForPay;
  // If the data source should be used for redeem transactions during this funding cycle.
  bool useDataSourceForRedeem;
  // The data source to use during this funding cycle.
  IJBFundingCycleDataSource dataSource;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './JBSplit.sol';
import '../libraries/JBSplitsGroups.sol';

struct JBGroupedSplits {
  // The group indentifier.
  uint256 group;
  // The splits to associate with the group.
  JBSplit[] splits;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

struct JBOperatorData {
  // The address of the operator.
  address operator;
  // The domain within which the operator is being given permissions.
  // A domain of 0 is a wildcard domain, which gives an operator access to all domains.
  uint256 domain;
  // The indexes of the permissions the operator is being given.
  uint256[] permissionIndexes;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBPaymentTerminal.sol';

import './JBTokenAmount.sol';

struct JBPayParamsData {
  // The terminal that is facilitating the payment.
  IJBPaymentTerminal terminal;
  // The address from which the payment originated.
  address payer;
  // The amount of the payment. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
  JBTokenAmount amount;
  // The ID of the project being paid.
  uint256 projectId;
  // The weight of the funding cycle during which the payment is being made.
  uint256 weight;
  // The reserved rate of the funding cycle during which the payment is being made.
  uint256 reservedRate;
  // The memo that was sent alongside the payment.
  string memo;
  // Arbitrary metadata provided by the payer.
  bytes metadata;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

struct JBProjectMetadata {
  // Metadata content.
  string content;
  // The domain within which the metadata applies.
  uint256 domain;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBPaymentTerminal.sol';

struct JBRedeemParamsData {
  // The terminal that is facilitating the redemption.
  IJBPaymentTerminal terminal;
  // The holder of the tokens being redeemed.
  address holder;
  // The ID of the project whos tokens are being redeemed.
  uint256 projectId;
  // The proposed number of tokens being redeemed, as a fixed point number with 18 decimals.
  uint256 tokenCount;
  // The total supply of tokens used in the calculation, as a fixed point number with 18 decimals.
  uint256 totalSupply;
  // The amount of overflow used in the reclaim amount calculation.
  uint256 overflow;
  // The number of decimals included in the reclaim amount fixed point number.
  uint256 decimals;
  // The currency that the reclaim amount is expected to be in terms of.
  uint256 currency;
  // The amount that should be reclaimed by the redeemer using the protocol's standard bonding curve redemption formula.
  uint256 reclaimAmount;
  // If overflow across all of a project's terminals is being used when making redemptions.
  bool useTotalOverflow;
  // The redemption rate of the funding cycle during which the redemption is being made.
  uint256 redemptionRate;
  // The ballot redemption rate of the funding cycle during which the redemption is being made.
  uint256 ballotRedemptionRate;
  // The proposed memo that is being emitted alongside the redemption.
  string memo;
  // Arbitrary metadata provided by the redeemer.
  bytes metadata;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../interfaces/IJBSplitAllocator.sol';

struct JBSplit {
  // A flag that only has effect if a projectId is also specified, and the project has a token contract attached.
  // If so, this flag indicates if the tokens that result from making a payment to the project should be delivered claimed into the beneficiary's wallet, or unclaimed to save gas.
  bool preferClaimed;
  // The percent of the whole group that this split occupies. This number is out of `JBConstants.SPLITS_TOTAL_PERCENT`.
  uint256 percent;
  // If an allocator is not set but a projectId is set, funds will be sent to the protocol treasury belonging to the project who's ID is specified.
  // Resulting tokens will be routed to the beneficiary with the claimed token preference respected.
  uint256 projectId;
  // The role the of the beneficary depends on whether or not projectId is specified, and whether or not an allocator is specified.
  // If allocator is set, the beneficiary will be forwarded to the allocator for it to use.
  // If allocator is not set but projectId is set, the beneficiary is the address to which the project's tokens will be sent that result from a payment to it.
  // If neither allocator or projectId are set, the beneficiary is where the funds from the split will be sent.
  address payable beneficiary;
  // Specifies if the split should be unchangeable until the specified time, with the exception of extending the locked period.
  uint256 lockedUntil;
  // If an allocator is specified, funds will be sent to the allocator contract along with all properties of this split.
  IJBSplitAllocator allocator;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './JBSplit.sol';
import './JBTokenAmount.sol';

struct JBSplitAllocationData {
  // The amount being sent to the split allocator, as a fixed point number.
  uint256 amount;
  // The number of decimals in the amount.
  uint256 decimals;
  // The project to which the split belongs.
  uint256 projectId;
  // The group to which the split belongs.
  uint256 group;
  // The split that caused the allocation.
  JBSplit split;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

struct JBTokenAmount {
  // The token the payment was made in.
  address token;
  // The amount of tokens that was paid, as a fixed point number.
  uint256 value;
  // The number of decimals included in the value fixed point number.
  uint256 decimals;
  // The expected currency of the value.
  uint256 currency;
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivFixedPointOverflow(uint256 prod1);

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivOverflow(uint256 prod1, uint256 denominator);

/// @notice Emitted when one of the inputs is type(int256).min.
error PRBMath__MulDivSignedInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows int256.
error PRBMath__MulDivSignedOverflow(uint256 rAbs);

/// @notice Emitted when the input is MIN_SD59x18.
error PRBMathSD59x18__AbsInputTooSmall();

/// @notice Emitted when ceiling a number overflows SD59x18.
error PRBMathSD59x18__CeilOverflow(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__DivInputTooSmall();

/// @notice Emitted when one of the intermediary unsigned results overflows SD59x18.
error PRBMathSD59x18__DivOverflow(uint256 rAbs);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathSD59x18__ExpInputTooBig(int256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathSD59x18__Exp2InputTooBig(int256 x);

/// @notice Emitted when flooring a number underflows SD59x18.
error PRBMathSD59x18__FloorUnderflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMathSD59x18__FromIntOverflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMathSD59x18__FromIntUnderflow(int256 x);

/// @notice Emitted when the product of the inputs is negative.
error PRBMathSD59x18__GmNegativeProduct(int256 x, int256 y);

/// @notice Emitted when multiplying the inputs overflows SD59x18.
error PRBMathSD59x18__GmOverflow(int256 x, int256 y);

/// @notice Emitted when the input is less than or equal to zero.
error PRBMathSD59x18__LogInputTooSmall(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__MulInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__MulOverflow(uint256 rAbs);

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__PowuOverflow(uint256 rAbs);

/// @notice Emitted when the input is negative.
error PRBMathSD59x18__SqrtNegativeInput(int256 x);

/// @notice Emitted when the calculating the square root overflows SD59x18.
error PRBMathSD59x18__SqrtOverflow(int256 x);

/// @notice Emitted when addition overflows UD60x18.
error PRBMathUD60x18__AddOverflow(uint256 x, uint256 y);

/// @notice Emitted when ceiling a number overflows UD60x18.
error PRBMathUD60x18__CeilOverflow(uint256 x);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathUD60x18__ExpInputTooBig(uint256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathUD60x18__Exp2InputTooBig(uint256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format format overflows UD60x18.
error PRBMathUD60x18__FromUintOverflow(uint256 x);

/// @notice Emitted when multiplying the inputs overflows UD60x18.
error PRBMathUD60x18__GmOverflow(uint256 x, uint256 y);

/// @notice Emitted when the input is less than 1.
error PRBMathUD60x18__LogInputTooSmall(uint256 x);

/// @notice Emitted when the calculating the square root overflows UD60x18.
error PRBMathUD60x18__SqrtOverflow(uint256 x);

/// @notice Emitted when subtraction underflows UD60x18.
error PRBMathUD60x18__SubUnderflow(uint256 x, uint256 y);

/// @dev Common mathematical functions used in both PRBMathSD59x18 and PRBMathUD60x18. Note that this shared library
/// does not always assume the signed 59.18-decimal fixed-point or the unsigned 60.18-decimal fixed-point
/// representation. When it does not, it is explicitly mentioned in the NatSpec documentation.
library PRBMath {
    /// STRUCTS ///

    struct SD59x18 {
        int256 value;
    }

    struct UD60x18 {
        uint256 value;
    }

    /// STORAGE ///

    /// @dev How many trailing decimals can be represented.
    uint256 internal constant SCALE = 1e18;

    /// @dev Largest power of two divisor of SCALE.
    uint256 internal constant SCALE_LPOTD = 262144;

    /// @dev SCALE inverted mod 2^256.
    uint256 internal constant SCALE_INVERSE =
        78156646155174841979727994598816262306175212592076161876661_508869554232690281;

    /// FUNCTIONS ///

    /// @notice Calculates the binary exponent of x using the binary fraction method.
    /// @dev Has to use 192.64-bit fixed-point numbers.
    /// See https://ethereum.stackexchange.com/a/96594/24693.
    /// @param x The exponent as an unsigned 192.64-bit fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function exp2(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            // Start from 0.5 in the 192.64-bit fixed-point format.
            result = 0x800000000000000000000000000000000000000000000000;

            // Multiply the result by root(2, 2^-i) when the bit at position i is 1. None of the intermediary results overflows
            // because the initial result is 2^191 and all magic factors are less than 2^65.
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }

            // We're doing two things at the same time:
            //
            //   1. Multiply the result by 2^n + 1, where "2^n" is the integer part and the one is added to account for
            //      the fact that we initially set the result to 0.5. This is accomplished by subtracting from 191
            //      rather than 192.
            //   2. Convert the result to the unsigned 60.18-decimal fixed-point format.
            //
            // This works because 2^(191-ip) = 2^ip / 2^191, where "ip" is the integer part "2^n".
            result *= SCALE;
            result >>= (191 - (x >> 64));
        }
    }

    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            // No need to shift x any more.
            msb += 1;
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
    ///
    /// Requirements:
    /// - The denominator cannot be zero.
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The multiplicand as an uint256.
    /// @param y The multiplier as an uint256.
    /// @param denominator The divisor as an uint256.
    /// @return result The result as an uint256.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division.
        if (prod1 == 0) {
            unchecked {
                result = prod0 / denominator;
            }
            return result;
        }

        // Make sure the result is less than 2^256. Also prevents denominator == 0.
        if (prod1 >= denominator) {
            revert PRBMath__MulDivOverflow(prod1, denominator);
        }

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0].
        uint256 remainder;
        assembly {
            // Compute remainder using mulmod.
            remainder := mulmod(x, y, denominator)

            // Subtract 256 bit number from 512 bit number.
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
        // See https://cs.stackexchange.com/q/138556/92363.
        unchecked {
            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 lpotdod = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by lpotdod.
                denominator := div(denominator, lpotdod)

                // Divide [prod1 prod0] by lpotdod.
                prod0 := div(prod0, lpotdod)

                // Flip lpotdod such that it is 2^256 / lpotdod. If lpotdod is zero, then it becomes one.
                lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * lpotdod;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /// @notice Calculates floor(x*y÷1e18) with full precision.
    ///
    /// @dev Variant of "mulDiv" with constant folding, i.e. in which the denominator is always 1e18. Before returning the
    /// final result, we add 1 if (x * y) % SCALE >= HALF_SCALE. Without this, 6.6e-19 would be truncated to 0 instead of
    /// being rounded to 1e-18.  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717.
    ///
    /// Requirements:
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - The body is purposely left uncommented; see the NatSpec comments in "PRBMath.mulDiv" to understand how this works.
    /// - It is assumed that the result can never be type(uint256).max when x and y solve the following two equations:
    ///     1. x * y = type(uint256).max * SCALE
    ///     2. (x * y) % SCALE >= SCALE / 2
    ///
    /// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
    /// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function mulDivFixedPoint(uint256 x, uint256 y) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 >= SCALE) {
            revert PRBMath__MulDivFixedPointOverflow(prod1);
        }

        uint256 remainder;
        uint256 roundUpUnit;
        assembly {
            remainder := mulmod(x, y, SCALE)
            roundUpUnit := gt(remainder, 499999999999999999)
        }

        if (prod1 == 0) {
            unchecked {
                result = (prod0 / SCALE) + roundUpUnit;
                return result;
            }
        }

        assembly {
            result := add(
                mul(
                    or(
                        div(sub(prod0, remainder), SCALE_LPOTD),
                        mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, SCALE_LPOTD), SCALE_LPOTD), 1))
                    ),
                    SCALE_INVERSE
                ),
                roundUpUnit
            )
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev An extension of "mulDiv" for signed numbers. Works by computing the signs and the absolute values separately.
    ///
    /// Requirements:
    /// - None of the inputs can be type(int256).min.
    /// - The result must fit within int256.
    ///
    /// @param x The multiplicand as an int256.
    /// @param y The multiplier as an int256.
    /// @param denominator The divisor as an int256.
    /// @return result The result as an int256.
    function mulDivSigned(
        int256 x,
        int256 y,
        int256 denominator
    ) internal pure returns (int256 result) {
        if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
            revert PRBMath__MulDivSignedInputTooSmall();
        }

        // Get hold of the absolute values of x, y and the denominator.
        uint256 ax;
        uint256 ay;
        uint256 ad;
        unchecked {
            ax = x < 0 ? uint256(-x) : uint256(x);
            ay = y < 0 ? uint256(-y) : uint256(y);
            ad = denominator < 0 ? uint256(-denominator) : uint256(denominator);
        }

        // Compute the absolute value of (x*y)÷denominator. The result must fit within int256.
        uint256 rAbs = mulDiv(ax, ay, ad);
        if (rAbs > uint256(type(int256).max)) {
            revert PRBMath__MulDivSignedOverflow(rAbs);
        }

        // Get the signs of x, y and the denominator.
        uint256 sx;
        uint256 sy;
        uint256 sd;
        assembly {
            sx := sgt(x, sub(0, 1))
            sy := sgt(y, sub(0, 1))
            sd := sgt(denominator, sub(0, 1))
        }

        // XOR over sx, sy and sd. This is checking whether there are one or three negative signs in the inputs.
        // If yes, the result should be negative.
        result = sx ^ sy ^ sd == 0 ? -int256(rAbs) : int256(rAbs);
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }

        // Set the initial guess to the closest power of two that is higher than x.
        uint256 xAux = uint256(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }

        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint256 roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }
}