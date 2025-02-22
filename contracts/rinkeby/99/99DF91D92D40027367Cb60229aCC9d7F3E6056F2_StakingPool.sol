/**
 *Submitted for verification at Etherscan.io on 2022-05-25
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;



// Part: CheckContract

contract CheckContract {
    /**
     * Check that the account is an already deployed non-destroyed contract.
     */
    function checkContract(address _account) internal view {
        require(_account != address(0), "Account cannot be zero address");

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(_account) }
        require(size > 0, "Account code size cannot be zero");
    }
}

// Part: IERC20

/**
 * Based on the OpenZeppelin IER20 interface:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol
 *
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
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

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

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    
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

// Part: IERC2612

/**
 * @dev Interface of the ERC2612 standard as defined in the EIP.
 *
 * Adds the {permit} method, which can be used to change one's
 * {IERC20-allowance} without having to send a transaction, by signing a
 * message. This allows users to spend tokens without having to hold Ether.
 *
 * See https://eips.ethereum.org/EIPS/eip-2612.
 * 
 * Code adapted from https://github.com/OpenZeppelin/openzeppelin-contracts/pull/2237/
 */
interface IERC2612 {
    /**
     * @dev Sets `amount` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
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
    function permit(address owner, address spender, uint256 amount, 
                    uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    
    /**
     * @dev Returns the current ERC2612 nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases `owner`'s nonce by one. This
     * prevents a signature from being used multiple times.
     *
     * `owner` can limit the time a Permit is valid for by setting `deadline` to 
     * a value in the near future. The deadline argument can be set to uint(-1) to 
     * create Permits that effectively never expire.
     */
    function nonces(address owner) external view returns (uint256);
    
    function version() external view returns (string memory);
    function permitTypeHash() external view returns (bytes32);
    function domainSeparator() external view returns (bytes32);
}

// Part: IStakingInterface

interface IStakingInterface  {
    // --- Events ---

    event UsdcTokenAddressChanged(address _usdcTokenAddress);
    event StakingPoolAddressChanged(address _stakingPoolAddress);


    // --- Functions ---

    function getTotalUSDC() external view returns (uint);

    function USDCWitdrawFromStakingPool(uint _amount) external;

    function USDCProvidedToStakingPool(uint _amount) external;

}

// Part: IStakingPool

interface IStakingPool {
    // Events

    event ExternalStakerChanged(address _address);
    event taygenNFTAddressChanged(address _taygenNFTAddress);
    event StakingPoolUSDCBalanceUpdated(uint _newBalance);
    event tUSDCTokenAddressChanged(address _tusdcTokenAddress);
    event USDCTokenAddressChanged(address _usdcTokenAddress);
    event WithdrawalPoolAddressChanged(address _withdrawalPoolAddress);
    event StakingInterfaceAddressChanged(address _stakingInterfaceAddress);

    // Functions

    function provideToStakingPool(uint _amount) external;

    function requestWithdrawFromStakingPool(uint _amount) external;

    function getUSDCDeposits() external returns (uint);

    function converttUSDCToUSDC(uint _amount) external view returns (uint);

    function convertUSDCTotUSDC(uint _amount) external view returns (uint);

    function getNFTVariables(uint _id) external view returns (uint, uint, uint, uint, uint);

    function getWithdrawAmount() external view returns (uint);

    function resetWithdrawAmount(uint _amount) external;

}

// Part: IWithdrawalPool

interface IWithdrawalPool {
    // Events

    event USDCTokenAddressChanged(address _usdcTokenAddress);
    event StakingPoolAddressChanged(address _stakingPoolAddress);
    event TaygenNFTAddressChanged(address _taygenNFTAddress);
    event TreasuryAddressChanged(address _treasuryAddress);
    event StakingInterfaceAddressChanged(address _stakingInterfaceAddress);

    // Functions

    function withdrawUSDC(uint _id) external;

}

// Part: OpenZeppelin/[email protected]/IERC165Upgradeable

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

// Part: OpenZeppelin/[email protected]/Context

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

// Part: IUSDCToken

interface IUSDCToken is IERC20, IERC2612 { 
    
    // --- Events ---

    event StakingPoolAddressChanged(address _newStakingPoolAddress);

    event USDCTokenBalanceUpdated(address _user, uint _amount);

    // --- Functions ---

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function sendToPool(address _sender,  address poolAddress, uint256 _amount) external;

    function returnFromPool(address poolAddress, address user, uint256 _amount ) external;
}

// Part: ItUSDCToken

interface ItUSDCToken is IERC20, IERC2612 { 
    
    // --- Events ---
    
    event borrowerOpsAddressChanged(address _borrowerOpsAddress);
    event stakingPoolAddressChanged(address _stakingPoolAddress);

    // --- Functions ---

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function sendToPool(address _sender,  address poolAddress, uint256 _amount) external;

    function returnFromPool(address poolAddress, address user, uint256 _amount ) external;
}

// Part: OpenZeppelin/[email protected]/IERC721Upgradeable

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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

// Part: OpenZeppelin/[email protected]/Ownable

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

// Part: ITaygenNFT

interface ITaygenNFT is IERC721Upgradeable {
    // --- Events ---



    // --- Functions ---

   function mint(address _to) external returns (uint256);

    function burn(uint256 _tokenId) external;

    function isApprovedOrOwner(address _spender, uint256 _tokenId)
        external
        view
        returns (bool);

    function setStakingPoolAddress(address _stakingPoolAddress) external;

}

// File: StakingPool.sol

contract StakingPool is IStakingPool, Ownable, CheckContract{

    uint internal constant DECIMAL_PRECISION = 1e6;
    uint public withdrawAmount;
    uint public feePercentage = 5e3;

    uint public LOCKED_WITHDRAWAL_PERIOD = 86400;

    address externalStakingAddress;
    address treasury;

    IUSDCToken public usdc_token;
    ItUSDCToken public tUSDCToken;
    IStakingInterface public stackingInterface;
    ITaygenNFT public taygenNFT;
    IWithdrawalPool public withdrawalPool;

    struct RequestWithdraw {
        uint USDCAmount;
        uint tUSDCAmount;
        uint conversionRate;
        uint USDCFee;
        uint withdrawlTime;
    }

    mapping(uint => RequestWithdraw) public withdrawRequest;

    function setAddresses(
        address _usdcTokenAddress,
        address _tUSDCTokenAddress,
        address _taygenNFTAddress,
        address _treasuryAddress,
        address _withdrawalPoolAddress,
        address _stakingInterfaceAddress
    ) 
    external 
    onlyOwner
    {
        usdc_token = IUSDCToken(_usdcTokenAddress);
        tUSDCToken = ItUSDCToken(_tUSDCTokenAddress);
        taygenNFT  = ITaygenNFT(_taygenNFTAddress);
        treasury = _treasuryAddress;
        withdrawalPool = IWithdrawalPool(_withdrawalPoolAddress);
        stackingInterface = IStakingInterface(_stakingInterfaceAddress);

        checkContract(_usdcTokenAddress);
        checkContract(_tUSDCTokenAddress);
        checkContract(_taygenNFTAddress);
        checkContract(_withdrawalPoolAddress);
        checkContract(_stakingInterfaceAddress);

        emit USDCTokenAddressChanged(_usdcTokenAddress);
        emit tUSDCTokenAddressChanged(_tUSDCTokenAddress);
        emit taygenNFTAddressChanged(_taygenNFTAddress);
        emit WithdrawalPoolAddressChanged(_withdrawalPoolAddress);
        emit StakingInterfaceAddressChanged(_stakingInterfaceAddress);
    }

    // --- Getters for public variables. ---
    function getUSDCDeposits() external override view returns (uint) {
        return stackingInterface.getTotalUSDC();
    }

    function getMaxWithdrawalAmount(address _user) external view returns (uint) {
        return (tUSDCToken.balanceOf(_user) * getConversionRate()) / DECIMAL_PRECISION;
    } 

    function getNFTVariables (uint _id) external view override returns (uint, uint, uint, uint, uint) {
        RequestWithdraw memory nftVariable = withdrawRequest[_id];
        return (nftVariable.USDCAmount, nftVariable.tUSDCAmount, nftVariable.conversionRate, nftVariable.USDCFee, nftVariable.withdrawlTime);
    }

    function getWithdrawAmount() external view override returns (uint) {
        return withdrawAmount;
    }

    // --- External USDC staking address ---
    function setExternalStaker(address _address) external onlyOwner {
        stackingInterface = IStakingInterface(_address);
        externalStakingAddress = _address;

        checkContract(_address);

        emit ExternalStakerChanged(_address);
    }

    function setWithdrawalFeePercentage(uint _fee) external onlyOwner {
        require(_fee <= 1e6, "StakingPool: Fee percentage value out of bounds");
        feePercentage = _fee;
    }

    function resetWithdrawAmount(uint _amount) external override {
        _requireCallerIsStakingInterface();
        withdrawAmount -= _amount;
    }

    function withdrawUSDCFromStakingPool(uint _id) external {
        withdrawalPool.withdrawUSDC(_id);
        taygenNFT.burn(_id);
    }

    // StakingPool interaction functions

    function requestWithdrawFromStakingPool(uint _amount) external override {
        uint tUSDCBalance = tUSDCToken.balanceOf(msg.sender);
        uint tUSDCAmount = convertUSDCTotUSDC(_amount);
        require(tUSDCBalance >= tUSDCAmount, "StakingPool: Insufficient tUSDC balance in user wallet");
        uint conversionRate = getConversionRate();

        //mint Taygen NFT

        withdrawAmount += _amount;

        uint tokenIndex = taygenNFT.mint(msg.sender);
        uint USDCFee = (_amount * feePercentage) / DECIMAL_PRECISION;

        stackingInterface.USDCWitdrawFromStakingPool(_amount);

        withdrawRequest[tokenIndex] = RequestWithdraw(
            _amount,
            tUSDCAmount,
            conversionRate,
            USDCFee,
            block.timestamp + LOCKED_WITHDRAWAL_PERIOD
        );

        // tUSDC token burn
        tUSDCToken.burn(msg.sender, tUSDCAmount);

    }

    function provideToStakingPool(uint256 _amount) external override {
        require(usdc_token.balanceOf(msg.sender) >= _amount, "StakingPool: Insufficient USDC balance in user wallet");

        // Transfer of tUSDC to depositor
        uint tUSDCAmount = convertUSDCTotUSDC(_amount);
        tUSDCToken.mint(msg.sender, tUSDCAmount);

        //Stable coin transfer from lender to SP
        bool sentToStakingInterface = _sendUSDCtoStakingPool(msg.sender, externalStakingAddress, _amount);
        require(sentToStakingInterface, "StakingPool: Transfer to StakingInterface failed");
        stackingInterface.USDCProvidedToStakingPool(_amount);
    }
    
    // Transfer the USDC tokens from the user to the Staking Pool's address, and update its recorded USDC
    function _sendUSDCtoStakingPool(address _sender, address _address, uint _amount) internal returns (bool) {
        usdc_token.transferFrom(_sender, _address, _amount);
        return true;
    }

     // Send USDC to user and decrease USDC in Pool
    function _sendUSDCToDepositor(address _depositor, uint USDCWithdrawal) internal {
        if (USDCWithdrawal == 0) {return;}
        bool success = usdc_token.transfer(_depositor, USDCWithdrawal);
        require(success, "Staking pool: USDC transfer failed from StakingPool");
    }

    // USDC - tUSDC conversion functions
    function converttUSDCToUSDC(uint _amount) public view override returns (uint) {
        uint CR = getConversionRate();

        uint USDCAmount = (_amount * CR) / DECIMAL_PRECISION;
        return USDCAmount;
    }

    function convertUSDCTotUSDC(uint _amount) public view override returns (uint) {
        uint CR = getConversionRate();

        uint tUSDCAmount = (_amount * DECIMAL_PRECISION) / CR;
        return tUSDCAmount;
    }

    function getConversionRate() public view returns (uint) {
        uint totalUSDC = stackingInterface.getTotalUSDC();
        uint totaltUSDC = tUSDCToken.totalSupply();

        uint CR = totalUSDC == 0 || totaltUSDC == 0 ? DECIMAL_PRECISION : (totalUSDC * DECIMAL_PRECISION) / totaltUSDC;
        return CR;  
    }

    function modifyLockedWithdrawlPeriod(uint _time) external onlyOwner returns (uint) {
        LOCKED_WITHDRAWAL_PERIOD = _time;
        return LOCKED_WITHDRAWAL_PERIOD;
    }
    

    function _requireCallerIsStakingInterface() internal {
        require(msg.sender == address(stackingInterface), "StakingPool: Caller is not withdrawal pool");
    }
}