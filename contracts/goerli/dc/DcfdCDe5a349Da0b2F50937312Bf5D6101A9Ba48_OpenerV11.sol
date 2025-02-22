// SPDX-License-Identifier: MIT

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
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
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

pragma solidity ^0.8.0;

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

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    constructor () {
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

pragma solidity ^0.8.0;

/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./../../voucher/IVoucher.sol";

interface ITransferFromAndBurnFrom {
    function burnFrom(address account, uint256 amount) external;

    function burn(uint256 amount) external;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;

    function transfer(address recipient, uint256 amount) external;
}

interface ICanMint {
    function mint(address to, uint256 tokenId) external;
}

interface ISoftMinter {
    function registeredHashes(address to, bytes32 openingHash) external returns (bool);

    function alreadyMinted(uint256 nftId) external returns (bool);
}

interface IStakingPool {
    function addRewards(uint256 amount) external;
}

interface IApprovable {
    function approve(address spender, uint256 amount) external;
}

interface IReverseSwap {
    function burnedTokens(uint256 nftId) external view returns (bool);
}

interface ISwapRouter {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

//The OpenerV6 adds support for the collector staking
contract OpenerV11 is Initializable, OwnableUpgradeable {
    ITransferFromAndBurnFrom private _pmonToken;
    ICanMint private _nftContract;
    ISoftMinter private _oldSoftMinter;
    // unused
    address public _stakeAddress;
    address public _feeAddress;
    // unused
    address public _swapBackAddress;

    event Opening(address indexed from, uint256 amount, uint256 openedBoosters);

    uint256 public _burnShare;
    // unused
    uint256 public _stakeShare;
    uint256 public _feeShare;
    // unused
    uint256 public _swapBackShare;

    // unused
    uint256 private _decimalMultiplier;

    bool public _closed;
    uint256 public _openedBoosters;

    mapping(uint256 => address) public registeredIds;
    mapping(address => mapping(bytes32 => bool)) public registeredHashes;

    // unused
    IStakingPool public _stakingPool;
    address public _ownerAddress;

    IStakingPool public _collectorStakingPool;
    uint256 public _collectorStakingShare;

    IReverseSwap public reverseSwap;

    IVoucher public voucher;
    // unused
    bool public onlyUseFullVouchers;

    mapping(uint256 => bool) public alreadyMinted;

    // unused
    uint256 public boosterPriceMultiplier;

    // ---------------------------
    // start native token booster
    // ---------------------------

    uint256 public boosterPriceNative;
    uint256 public voucherLimit;
    uint256 public voucherCounter;
    uint256 public nativeTokenLimit;
    uint256 public nativeTokenCounter;

    ISwapRouter public swapRouter;
    address[] public nativeTokenToPMONPath;

    event TokenRecovered(address indexed token, address indexed to, uint256 amount);
    event NativeTokenRecovered(address indexed to, uint256 amount);

    // ---------------------------
    // start opening via NFB
    // ---------------------------

    enum NfbType {
        STANDARD_NFB
    }

    address public nfbContract;
    uint16 public nfbSeriesId;
    uint8 public nfbEditionId;

    event OpeningViaNfbContract(address indexed from, uint256 amount, uint16 seriesId, uint8 editionId);
    event OpeningViaNFBs(address indexed to, uint256 amount, uint256 openedBoosters, NfbType source);
    
    // nativeTokenPrice: price of the native token in USD with cents (1650.43 = 165043)
    // boosterPrice: price of one pack in USD with cents (10.00 = 1000)
    function setPrice(uint256 nativeTokenPrice, uint256 boosterPrice) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        boosterPriceNative = (1 ether / nativeTokenPrice) * boosterPrice;
    }

    function setVoucherLimit(uint256 limit) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        voucherLimit = limit;
    }

    function setNativeTokenLimit(uint256 limit) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        nativeTokenLimit = limit;
    }

    function setSwapRouter(ISwapRouter router) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        swapRouter = router;
    }

    function setNativeTokenToPMONPath(address[] memory path) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        nativeTokenToPMONPath = path;
    }

    function setNfbContractConfig(address _nfbContract, uint16 seriesId, uint8 editionId) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        nfbContract = _nfbContract;
        nfbSeriesId = seriesId;
        nfbEditionId = editionId;
    }

    function openViaNfb(    
        uint16 seriesId,
        uint8 editionId,
        uint256 amount,
        address to
    ) public {
        require(msg.sender == nfbContract, "Only NFB contract can call this function");
        require(seriesId == nfbSeriesId, "Series ID is not correct");
        require(editionId == nfbEditionId, "Edition ID is not correct");
        
        emit OpeningViaNfbContract(to, amount, seriesId, editionId);
        emit OpeningViaNFBs(to, amount * 1 ether, _openedBoosters, NfbType.STANDARD_NFB);

        _openViaNfb(amount, to);
    }

    function _openViaNfb(uint256 amount, address to) internal {
        require(!_closed, "Opener is locked");
        require(
            nativeTokenCounter + amount <= nativeTokenLimit,
            "Global max opening amount with native token has been exceeded"
        );
        require(amount > 0, "Amount has to be gt 0");

        _addHash(amount, _openedBoosters, msg.sender);
        
        emit Opening(to, amount * 1 ether, _openedBoosters);
        
        _openedBoosters = _openedBoosters + amount;
        nativeTokenCounter += amount;
    }


    function openBooster(uint256 boosterAmountVoucher, uint256 boosterAmountNativeToken) public payable {
        require(!_closed, "Opener is locked");
        require(boosterPriceNative > 0, "The booster price has not been set correctly");

        require(voucherCounter + boosterAmountVoucher <= voucherLimit, "Global max opening amount with vouchers has been exceeded");
        require(
            nativeTokenCounter + boosterAmountNativeToken <= nativeTokenLimit,
            "Global max opening amount with native token has been exceeded"
        );

        voucher.spendVouchers(msg.sender, boosterAmountVoucher * 1 ether);
        uint256 nativeTokenCost = boosterAmountNativeToken * boosterPriceNative;
        require(msg.value == nativeTokenCost, "Native token amount does not cover cost");

        uint256 amount = boosterAmountVoucher + boosterAmountNativeToken;
        require(amount > 0, "Amount has to be gt 0");

        _addHash(amount, _openedBoosters, msg.sender);
        emit Opening(msg.sender, amount * 1 ether, _openedBoosters);

        _openedBoosters = _openedBoosters + amount;
        if (boosterAmountVoucher > 0) voucherCounter += boosterAmountVoucher;
        if (boosterAmountNativeToken > 0) nativeTokenCounter += boosterAmountNativeToken;

        _distributeNativeTokenShares(nativeTokenCost);
    }

    function openBoosterForUser(uint256 boosterAmountNativeToken, address user) public payable {
        require(!_closed, "Opener is locked");
        require(boosterPriceNative > 0, "The booster price has not been set correctly");
        require(user != address(0), "Target address not defined");

        require(
            nativeTokenCounter + boosterAmountNativeToken <= nativeTokenLimit,
            "Global max opening amount with native token has been exceeded"
        );

        uint256 nativeTokenCost = boosterAmountNativeToken * boosterPriceNative;
        require(msg.value == nativeTokenCost, "Native token amount does not cover cost");

        require(boosterAmountNativeToken > 0, "Amount has to be gt 0");

        _addHash(boosterAmountNativeToken, _openedBoosters, user);
        emit Opening(user, boosterAmountNativeToken * 1 ether, _openedBoosters);

        _openedBoosters = _openedBoosters + boosterAmountNativeToken;
        nativeTokenCounter += boosterAmountNativeToken;

        _distributeNativeTokenShares(nativeTokenCost);
    }

    function _distributeNativeTokenShares(uint256 amount) internal {
        // transfer of fee share
        uint256 feeAmount = (amount * _feeShare) / 100;
        if (feeAmount > 0) {
            payable(_feeAddress).send(feeAmount);
        }

        uint256 swapAmount = amount - feeAmount;
        if (
            (_collectorStakingShare > 0 || _burnShare > 0) &&
            (address(swapRouter) != address(0) && nativeTokenToPMONPath.length > 0) &&
            swapAmount > 0
        ) {
            uint256[] memory amounts = swapRouter.swapExactETHForTokens{value: swapAmount}(
                0,
                nativeTokenToPMONPath,
                address(this),
                block.timestamp
            );
            uint256 pmonAmount = amounts[amounts.length - 1];

            uint256 collectorStakingAmount = (pmonAmount * _collectorStakingShare) / (100 - _feeShare);
            uint256 burnAmount = (pmonAmount * _burnShare) / (100 - _feeShare);

            // transfer of collector-staking share
            if (collectorStakingAmount > 0) {
                _collectorStakingPool.addRewards(collectorStakingAmount);
            }
            if (burnAmount > 0) {
                _pmonToken.burn(burnAmount);
            }
        }
    }

    function _addHash(
        uint256 amount,
        uint256 openedBoosters,
        address userAddress
    ) private {
        uint256 firstId = openedBoosters * 3 + 1 + 1000000000;
        uint256 lastId = firstId + amount * 3 - 1;
        registeredHashes[userAddress][keccak256(abi.encode(userAddress, firstId, lastId))] = true;
    }

    function setShares(
        uint256 burnShare,
        uint256 feeShare,
        uint256 collectorStakingShare
    ) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        require(burnShare + feeShare + collectorStakingShare == 100, "Doesn't add up to 100");

        _burnShare = burnShare;
        _feeShare = feeShare;
        _collectorStakingShare = collectorStakingShare;
    }

    function emergencyRecoverToken(address token, uint256 amount) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        ITransferFromAndBurnFrom(token).transfer(msg.sender, amount);
        emit TokenRecovered(token, msg.sender, amount);
    }

    function emergencyRecoverNativeToken(uint256 amount) external {
        require(msg.sender == _ownerAddress, "Sender is not owner");

        payable(msg.sender).send(amount);
        emit NativeTokenRecovered(msg.sender, amount);
    }

    // ---------------------------
    // end native token booster
    // ---------------------------

    // ---------------------------
    // cleaned old stuff
    // ---------------------------

    function initialize(
        ITransferFromAndBurnFrom pmonToken,
        ICanMint nftContract,
        address stakeAddress,
        address feeAddress,
        address swapBackAddress,
        uint256 openedBoosters
    ) public initializer {
        _pmonToken = pmonToken;
        _stakeAddress = stakeAddress;
        _feeAddress = feeAddress;
        _swapBackAddress = swapBackAddress;
        _openedBoosters = openedBoosters;
        _nftContract = nftContract;

        _burnShare = 75;
        _stakeShare = 0;
        _feeShare = 25;
        _swapBackShare = 0;

        _decimalMultiplier = 10**uint256(18);

        _closed = false;
    }

    function mint(
        address to,
        uint256 idToMint,
        uint256 firstId,
        uint256 lastId
    ) public {
        bytes32 dataHash = keccak256(abi.encode(to, firstId, lastId));
        require(registeredHashes[to][dataHash], "Hash not registered");
        require(idToMint >= firstId && idToMint <= lastId, "Not Owner of requested NFT");
        require(!alreadyMinted[idToMint], "Already minted");
        require(!reverseSwap.burnedTokens(idToMint), "Token has been burned in reverse swap");

        alreadyMinted[idToMint] = true;
        _nftContract.mint(to, idToMint);
    }

    function setFeeAddress(address feeAddress) public {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        _feeAddress = feeAddress;
    }

    function lock() public {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        _closed = true;
    }

    function unlock() public {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        _closed = false;
    }

    function setOwner(address ownerAddress) public {
        //if the owneraddress is the null-address, we allow
        if (_ownerAddress == address(0)) {
            _ownerAddress = ownerAddress;
            return;
        } else if (_ownerAddress != msg.sender) {
            //if the owner address is not the null address and the caller is not the owner, we revert
            require(false, "Caller is not the Owner");
        } else if (_ownerAddress == msg.sender) {
            //if the owner address is the caller we allow chainging the owneraddress but not to the null-address
            require(ownerAddress != address(0), "New OwnerAddress cannot be zero-address");
            _ownerAddress = ownerAddress;
        }
    }

    function setCollectorStakingPool(IStakingPool collectorStakingPool) public {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        _setCollectorStakingPool(collectorStakingPool);
    }

    function _setCollectorStakingPool(IStakingPool collectorStakingPool) internal {
        require(address(collectorStakingPool) != address(0), "Address of collectorStakingPool is zero-address");

        _collectorStakingPool = collectorStakingPool;

        IApprovable(address(_pmonToken)).approve(address(collectorStakingPool), 100000000000 * 10**uint256(18));
    }

    function setReverseSwap(IReverseSwap _reverseSwap) public {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        reverseSwap = _reverseSwap;
    }

    function setVoucher(IVoucher _voucher) public {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        voucher = _voucher;
    }

    function setBoosterPriceMultiplier(uint256 _boosterPriceMultiplier) public {
        require(msg.sender == _ownerAddress, "Sender is not owner");
        boosterPriceMultiplier = _boosterPriceMultiplier;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVoucher {
    function vouchers(address owner) external view returns (uint256);
    function creditVouchers(address receiver, uint256 amount) external;
    function spendVouchers(address spender, uint256 amount) external;
    function DECIMALS() external view returns (uint256);
}