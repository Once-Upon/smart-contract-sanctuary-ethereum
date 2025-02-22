/*
                                                                                                                                                                                                                                                           
    ,---,.                        ,---,                                                         ,---,                    ___     
  ,'  .' |                      ,--.' |                                                        '  .' \                 ,--.'|_   
,---.'   |                      |  |  :                      ,---,                            /  ;    '.      __  ,-.  |  | :,'  
|   |   .' ,--,  ,--,           :  :  :                  ,-+-. /  |  ,----._,.               :  :       \   ,' ,'/ /|  :  : ' :  
:   :  |-, |'. \/ .`|    ,---.  :  |  |,--.  ,--.--.    ,--.'|'   | /   /  ' /   ,---.       :  |   /\   \  '  | |' |.;__,'  /   
:   |  ;/| '  \/  / ;   /     \ |  :  '   | /       \  |   |  ,"' ||   :     |  /     \      |  :  ' ;.   : |  |   ,'|  |   |    
|   :   .'  \  \.' /   /    / ' |  |   /' :.--.  .-. | |   | /  | ||   | .\  . /    /  |     |  |  ;/  \   \'  :  /  :__,'| :    
|   |  |-,   \  ;  ;  .    ' /  '  :  | | | \__\/: . . |   | |  | |.   ; ';  |.    ' / |     '  :  | \  \ ,'|  | '     '  : |__  
'   :  ;/|  / \  \  \ '   ; :__ |  |  ' | : ," .--.; | |   | |  |/ '   .   . |'   ;   /|     |  |  '  '--'  ;  : |     |  | '.'| 
|   |    \./__;   ;  \'   | '.'||  :  :_:,'/  /  ,.  | |   | |--'   `---`-'| |'   |  / |___  |  :  :        |  , ;     ;  :    ; 
|   :   .'|   :/\  \ ;|   :    :|  | ,'   ;  :   .'   \|   |/       .'__/\_: ||   :    /  .\ |  | ,'         ---'      |  ,   /  
|   | ,'  `---'  `--`  \   \  / `--''     |  ,     .-./'---'        |   :    : \   \  /\  ; |`--''                      ---`-'   
`----'                  `----'             `--`---'                  \   \  /   `----'  `--"                                     
                                                                      `--`-'                                                     

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./mixins/shared/Constants.sol";
import "./mixins/shared/ExchangeArtTreasuryNode.sol";
import "./mixins/shared/NFTMarketFees.sol";
import "./mixins/shared/NFTMarketSharedCore.sol";
import "./mixins/shared/SendValueWithFallbackWithdraw.sol";

import "./mixins/NFTMarketBuyNow.sol";
import "./mixins/NFTMarketAuction.sol";
import "./mixins/NFTMarketAuctionIdentification.sol";
import "./mixins/NFTMarketCore.sol";

/**
 * @title A marketplace for NFTs on Exchange.Art.
 * @notice The Exchange Art marketplace is a contract which allows traders to buy and sell NFTs.
 * It supports buying and selling via buy now. Auctions and offers coming soon
 * @dev All sales in the Foundation market will pay the creator 10% royalties on secondary sales. This is not specific
 * to NFTs minted on Foundation, it should work for any NFT. If royalty information was not defined when the NFT was
 * originally deployed, it may be added using the [Royalty Registry](https://royaltyregistry.xyz/) which will be
 * respected by our market contract.
 * @author robeMalu
 */
contract ExchangeArtNFTMarket is
  ExchangeArtTreasuryNode,
  NFTMarketSharedCore,
  NFTMarketCore,
  ReentrancyGuard,
  SendValueWithFallbackWithdraw,
  NFTMarketFees,
  NFTMarketAuctionIdentification,
  NFTMarketAuction,
  NFTMarketBuyNow
{
  /**
   * @notice Set immutable variables for the implementation contract.
   * @dev Using immutable instead of constants allows us to use different values on testnet.
   * @param treasury The Foundation Treasury contract address.
   */
  constructor(
    address payable treasury
  )
    //todo change this
    ExchangeArtTreasuryNode(treasury)
    NFTMarketFees()
    NFTMarketAuction(700)
  {}

  /**
   * @notice Called once to configure the contract after the initial proxy deployment.
   * @dev This farms the initialize call out to inherited contracts as needed to initialize mutable variables.
   */
  function initialize() external initializer {
    NFTMarketAuctionIdentification._initializeNFTMarketAuction();
  }

  /**
   * @inheritdoc NFTMarketCore
   */
  function _transferFromEscrow(
    address nftContract,
    uint256 tokenId,
    address recipient,
    address authorizeSeller
  ) internal override(NFTMarketCore, NFTMarketAuction, NFTMarketBuyNow) {
    // This is a no-op function required to avoid compile errors.
    super._transferFromEscrow(nftContract, tokenId, recipient, authorizeSeller);
  }

  /**
   * @inheritdoc NFTMarketCore
   */
  function _transferFromEscrowIfAvailable(
    address nftContract,
    uint256 tokenId,
    address recipient
  ) internal override(NFTMarketCore, NFTMarketAuction, NFTMarketBuyNow) {
    // This is a no-op function required to avoid compile errors.
    super._transferFromEscrowIfAvailable(nftContract, tokenId, recipient);
  }

  /**
   * @inheritdoc NFTMarketCore
   */
  function _transferToEscrow(
    address nftContract,
    uint256 tokenId
  ) internal override(NFTMarketCore, NFTMarketAuction, NFTMarketBuyNow) {
    // This is a no-op function required to avoid compile errors.
    super._transferToEscrow(nftContract, tokenId);
  }

  /**
   * @inheritdoc NFTMarketSharedCore
   */
  function _getSellerOf(
    address nftContract,
    uint256 tokenId
  )
    internal
    view
    override(
      NFTMarketSharedCore,
      NFTMarketCore,
      NFTMarketAuction,
      NFTMarketBuyNow
    )
    returns (address payable seller)
  {
    // This is a no-op function required to avoid compile errors.
    seller = super._getSellerOf(nftContract, tokenId);
  }

  /**
   * @inheritdoc NFTMarketCore
   */
  function _notifyAuctionStarted(
    address nftContract,
    uint256 tokenId
  ) internal override(NFTMarketCore, NFTMarketBuyNow) {
    // This is a no-op function required to avoid compile errors.
    super._notifyAuctionStarted(nftContract, tokenId);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

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
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
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
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
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
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
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
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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

    constructor() {
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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
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

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

interface IGetRoyalties {
  /**
   * @notice Get the creator royalties to be sent.
   * @dev The data is the same as when calling `getFeeRecipients` and `getFeeBps` separately.
   * @param tokenId The ID of the NFT to get royalties for.
   * @return recipients An array of addresses to which royalties should be sent.
   * @return royaltiesInBasisPoints The array of fees to be sent to each recipient, in basis points.
   */
  function getRoyalties(uint256 tokenId)
    external
    view
    returns (address payable[] memory recipients, uint256[] memory royaltiesInBasisPoints);
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

/**
 * @notice Interface for EIP-2981: NFT Royalty Standard.
 * For more see: https://eips.ethereum.org/EIPS/eip-2981.
 */
interface IRoyaltyInfo {
  /**
   * @notice Get the creator royalties to be sent.
   * @param tokenId The ID of the NFT to get royalties for.
   * @param salePrice The total price of the sale.
   * @return receiver The address to which royalties should be sent.
   * @return royaltyAmount The total amount that should be sent to the `receiver`.
   */
  function royaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    view
    returns (address receiver, uint256 royaltyAmount);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * From https://github.com/OpenZeppelin/openzeppelin-contracts
 * Copying the method below which is currently unreleased.
 */

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title Library to query ERC165 support.
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library OZERC165Checker {
    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function supportsERC165InterfaceUnchecked(
        address account,
        bytes4 interfaceId
    ) internal view returns (bool) {
        bytes memory encodedParams = abi.encodeWithSelector(
            IERC165.supportsInterface.selector,
            interfaceId
        );
        (bool success, bytes memory result) = account.staticcall{gas: 30_000}(
            encodedParams
        );
        if (result.length < 32) return false;
        return success && abi.decode(result, (uint256)) > 0;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./shared/NFTMarketSharedCore.sol";
import "./shared/ExchangeArtTreasuryNode.sol";
import "./shared/NFTMarketFees.sol";
import "./shared/SendValueWithFallbackWithdraw.sol";
import "./NFTMarketCore.sol";
import "./NFTMarketAuctionIdentification.sol";

/// @param auctionId The already listed auctionId for this NFT.
error NFTMarketReserveAuction_Already_Listed(uint256 auctionId);
/// @param minAmount The minimum amount that must be bid in order for it to be accepted.
error NFTMarketReserveAuction_Bid_Must_Be_At_Least_Min_Amount(
  uint256 minAmount
);
/// @param reservePrice The current reserve price.
error NFTMarketReserveAuction_Cannot_Bid_Lower_Than_Reserve_Price(
  uint256 reservePrice
);
/// @param endTime The timestamp at which the auction had ended.
error NFTMarketReserveAuction_Cannot_Bid_On_Ended_Auction(uint256 endTime);
error NFTMarketReserveAuction_Cannot_Bid_On_Nonexistent_Auction();
error NFTMarketReserveAuction_Cannot_Finalize_Already_Settled_Auction();
/// @param endTime The timestamp at which the auction will end.
error NFTMarketReserveAuction_Cannot_Finalize_Auction_In_Progress(
  uint256 endTime
);
error NFTMarketReserveAuction_Cannot_Rebid_Over_Outstanding_Bid();
error NFTMarketReserveAuction_Cannot_Update_Auction_In_Progress();
/// @param maxDuration The maximum configuration for a duration of the auction, in seconds.
error NFTMarketReserveAuction_Exceeds_Max_Duration(uint256 maxDuration);
/// @param extensionDuration The extension duration, in seconds.
error NFTMarketReserveAuction_Less_Than_Extension_Duration(
  uint256 extensionDuration
);
error NFTMarketReserveAuction_Must_Set_Non_Zero_Reserve_Price();
/// @param seller The current owner of the NFT.
error NFTMarketReserveAuction_Not_Matching_Seller(address seller);
/// @param owner The current owner of the NFT.
error NFTMarketReserveAuction_Only_Owner_Can_Update_Auction(address owner);
error NFTMarketReserveAuction_Price_Already_Set();
error NFTMarketReserveAuction_Too_Much_Value_Provided();
/// @param percentageFlip The current owner of the NFT.
error NFTMarketReserveAuction_Percentage_Flip_Grater_Than_100(
  uint256 percentageFlip
);
error NFTMarketReserveAuction_Ending_Phase_Provided_With_No_percentage_Flip();
error NFTMarketReserveAuction_Must_Set_Non_Zero_Minimum_Increment(
  uint256 minimumIncrement
);
error NFTMarketReserveAuction_Start_grater_Than_End();
error NFTMarketReserveAuction_Ending_Phase_Grater_Than_Duration(
  uint256 endingPhase
);
error NFTMarketReserveAuction_Exrtension_Window_Grater_Than_Ending_Phase(
  uint256 extensionWindow
);

/**
 * @title Allows the owner of an NFT to list it in auction.
 * @notice NFTs in auction are escrowed in the market contract.
 */
abstract contract NFTMarketAuction is
  ExchangeArtTreasuryNode,
  NFTMarketSharedCore,
  NFTMarketCore,
  ReentrancyGuard,
  SendValueWithFallbackWithdraw,
  NFTMarketFees,
  NFTMarketAuctionIdentification
{
  using Address for address payable;

  /// @notice The auction configuration for a specific NFT.
  struct AuctionState {
    /// @notice The address of the NFT contract.
    address nftContract;
    /// @notice The id of the NFT.
    uint256 tokenId;
    /// @notice The owner of the NFT which listed it in auction.
    address payable seller;
    /// @notice The difference between two subsequent bids, if no ending phase mechanics are applied.
    uint256 minimumIncrement;
    /// @notice The extension window for this auction.
    uint256 endingPhase;
    /// @notice During the ending phase, add a minimum percentage increase each bid must meet.
    uint256 endingPhasePercentageFlip;
    /// @notice Extension window is how much time after the previous bid where the auction ends.
    /// This will be enforced by extending the auction, if required.
    /// Can be greater than 0 only if ending phase is greater than 0.
    uint256 extensionWindow;
    /// @notice The time at which this auction has kicked off
    /// @dev IMPORTANT - In order to save gas and not define another variable, when the auction is reserved price triggered
    /// we pass here the duration
    uint256 start;
    /// @notice The time at which this auction will not accept any new bids.
    /// @dev This is `0` until the first bid is placed.
    uint256 end;
    /// @notice The current highest bidder in this auction.
    /// @dev This is `address(0)` until the first bid is placed.
    address payable highestBidder;
    /// @notice The latest price of the NFT in this auction.
    /// @dev This is set to the reserve price, and then to the highest bid once the auction has started.
    uint256 reservePriceOrHighestBid;
    /// @notice The price at which anyoane can aquire this NFT while the auction is ongoing.
    /// @dev This works only if the value is grater than the highest bid
    uint256 buyOutPrice;
    /// @notice Specifies if this is a primary sale or a secondary one.
    bool isPrimarySale;
  }

  // todo this is a duplicate of auctionState almost, need to get confirmation for auction configuration and update properly
  struct InitAuctionArguments {
    /// @notice The address of the NFT contract.
    address nftContract;
    /// @notice The id of the NFT.
    uint256 tokenId;
    /// @notice The owner of the NFT which listed it in auction.
    address payable seller;
    /// @notice The difference between two subsequent bids, if no ending phase mechanics are applied.
    uint256 minimumIncrement;
    /// @notice The extension window for this auction.
    uint256 endingPhase;
    /// @notice During the ending phase, add a minimum percentage increase each bid must meet.
    uint256 endingPhasePercentageFlip;
    /// @notice Extension window is how much time after the previous bid where the auction ends.
    /// This will be enforced by extending the auction, if required.
    /// Can be greater than 0 only if ending phase is greater than 0.
    uint256 extensionWindow;
    /// @notice The time at which this auction has kicked off
    /// @dev IMPORTANT - In order to save gas and not define another variable, when the auction is reserved price triggered
    /// we pass here the duration
    uint256 start;
    /// @notice The time at which this auction will not accept any new bids.
    /// @dev This is `0` until the first bid is placed.
    uint256 end;
    /// @notice The current highest bidder in this auction.
    /// @dev This is `address(0)` until the first bid is placed.
    address payable highestBidder;
    /// @notice The latest price of the NFT in this auction.
    /// @dev This is set to the reserve price, and then to the highest bid once the auction has started.
    uint256 reservePriceOrHighestBid;
    /// @notice The price at which anyoane can aquire this NFT while the auction is ongoing.
    /// @dev This works only if the value is grater than the highest bid
    uint256 buyOutPrice;
    /// @notice Specifies if this is a primary sale or a secondary one.
    bool isReservePriceTriggered;
    /// @notice Specifies if this is a primary sale or a secondary one.
    bool isPrimarySale;
  }

  /// @notice The auction configuration for a specific auction id.
  mapping(address => mapping(uint256 => uint256))
    private nftContractToTokenIdToAuctionId;
  /// @notice The auction id for a specific NFT.
  /// @dev This is deleted when an auction is finalized or canceled.
  mapping(uint256 => AuctionState) private auctionIdToAuction;

  /// @notice How long an auction lasts for once the first bid has been received.
  uint256 private immutable DURATION;

  /// @notice The window for auction extensions, any bid placed in the final 15 minutes
  /// of an auction will reset the time remaining to 15 minutes.
  uint256 private constant EXTENSION_DURATION = 10 minutes;

  /// @notice Caps the max duration that may be configured so that overflows will not occur.
  uint256 private constant MAX_MAX_DURATION = 1_000 days;

  /**
   * @notice Emitted when a bid is placed.
   * @param auctionId The id of the auction this bid was for.
   * @param bidder The address of the bidder.
   * @param amount The amount of the bid.
   * @param endTime The new end time of the auction (which may have been set or extended by this bid).
   */
  event AuctionBidPlaced(
    uint256 indexed auctionId,
    address indexed bidder,
    uint256 amount,
    uint256 endTime
  );
  /**
   * @notice Emitted when an auction is canceled.
   * @dev This is only possible if the auction has not received any bids.
   * @param auctionId The id of the auction that was canceled.
   */
  event AuctionCanceled(uint256 indexed auctionId);
  /**
   * @notice Emitted when an NFT is listed for auction.
   * @param seller The address of the seller.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @param duration The duration of the auction (always 24-hours).
   * @param extensionDuration The duration of the auction extension window (always 15-minutes).
   * @param reservePrice The reserve price to kick off the auction.
   * @param auctionId The id of the auction that was created.
   */
  event AuctionCreated(
    address indexed seller,
    address indexed nftContract,
    uint256 indexed tokenId,
    uint256 duration,
    uint256 extensionDuration,
    uint256 reservePrice,
    uint256 auctionId
  );
  /**
   * @notice Emitted when an auction that has already ended is finalized,
   * indicating that the NFT has been transferred and revenue from the sale distributed.
   * @param auctionId The id of the auction that was finalized.
   * @param seller The address of the seller.
   * @param bidder The address of the highest bidder that won the NFT.
   * @param totalFees The amount of ETH that was sent to Exchange Art for holding this auction.
   * @param creatorRev The amount of ETH that was sent to the creator for this sale.
   * @param sellerRev The amount of ETH that was sent to the owner for this sale.
   */
  event AuctionFinalized(
    uint256 indexed auctionId,
    address indexed seller,
    address indexed bidder,
    uint256 totalFees,
    uint256 creatorRev,
    uint256 sellerRev
  );

  /**
   * @notice Emitted when an auction is invalidated due to other market activity.
   * @dev This occurs when the NFT is sold another way, such as with `buy` or when auction terminates with no bids placed.
   * @param auctionId The id of the auction that was invalidated.
   */
  event AuctionInvalidated(uint256 indexed auctionId);

  // todo this is not used atm, needs to be deleted
  /**
   * @notice Configures the duration for auctions.
   * @param duration The duration for auctions, in seconds.
   */
  constructor(uint256 duration) {
    if (duration > MAX_MAX_DURATION) {
      // This ensures that math in this file will not overflow due to a huge duration.
      revert NFTMarketReserveAuction_Exceeds_Max_Duration(MAX_MAX_DURATION);
    }
    if (duration < EXTENSION_DURATION) {
      // The auction duration configuration must be greater than the extension window of 15 minutes
      revert NFTMarketReserveAuction_Less_Than_Extension_Duration(
        EXTENSION_DURATION
      );
    }
    DURATION = duration;
  }

  /// @notice Confirms that the reserve price is not zero.
  modifier onlyValidAuctionConfig(
    uint256 reservePrice,
    uint256 endingPhase,
    uint256 percetageFlip,
    uint256 minimumIncrement,
    uint256 extensionWindow,
    uint256 start,
    uint256 end
  ) {
    if (reservePrice == 0) {
      revert NFTMarketReserveAuction_Must_Set_Non_Zero_Reserve_Price();
    }
    if (percetageFlip == 0 && endingPhase != 0) {
      revert NFTMarketReserveAuction_Ending_Phase_Provided_With_No_percentage_Flip();
    }
    if (percetageFlip == 100) {
      revert NFTMarketReserveAuction_Percentage_Flip_Grater_Than_100(
        percetageFlip
      );
    }
    if (minimumIncrement == 0) {
      revert NFTMarketReserveAuction_Must_Set_Non_Zero_Minimum_Increment(
        minimumIncrement
      );
    }
    if (start > end) {
      revert NFTMarketReserveAuction_Start_grater_Than_End();
    }
    if (endingPhase > end - start) {
      revert NFTMarketReserveAuction_Ending_Phase_Grater_Than_Duration(
        endingPhase
      );
    }
    if (extensionWindow > endingPhase) {
      revert NFTMarketReserveAuction_Exrtension_Window_Grater_Than_Ending_Phase(
        extensionWindow
      );
    }
    _;
  }

  /**
   * @notice Creates an auction for the given NFT.
   * The NFT is held in escrow until the auction is finalized or canceled.
   * @param auctionConfig The auction configuration
   */
  function createAuction(
    InitAuctionArguments calldata auctionConfig
  )
    external
    nonReentrant
    onlyValidAuctionConfig(
      auctionConfig.reservePriceOrHighestBid,
      auctionConfig.endingPhase,
      auctionConfig.endingPhasePercentageFlip,
      auctionConfig.minimumIncrement,
      auctionConfig.extensionWindow,
      auctionConfig.start,
      auctionConfig.end
    )
  {
    uint256 auctionId = _getNextAndIncrementAuctionId();

    // If the `msg.sender` is not the owner of the NFT, transferring into escrow should fail.
    _transferToEscrow(auctionConfig.nftContract, auctionConfig.tokenId);

    // This check must be after _transferToEscrow in case auto-settle was required
    if (
      nftContractToTokenIdToAuctionId[auctionConfig.nftContract][
        auctionConfig.tokenId
      ] != 0
    ) {
      revert NFTMarketReserveAuction_Already_Listed(
        nftContractToTokenIdToAuctionId[auctionConfig.nftContract][
          auctionConfig.tokenId
        ]
      );
    }

    // Store the auction details
    nftContractToTokenIdToAuctionId[auctionConfig.nftContract][
      auctionConfig.tokenId
    ] = auctionId;
    AuctionState storage auction = auctionIdToAuction[auctionId];
    auction.nftContract = auctionConfig.nftContract;
    auction.tokenId = auctionConfig.tokenId;
    auction.seller = payable(msg.sender);
    auction.reservePriceOrHighestBid = auctionConfig.reservePriceOrHighestBid;
    auction.isPrimarySale = auctionConfig.isPrimarySale;
    auction.buyOutPrice = auctionConfig.buyOutPrice;
    auction.endingPhase = auctionConfig.endingPhase;
    auction.endingPhasePercentageFlip = auctionConfig.endingPhasePercentageFlip;
    auction.extensionWindow = auctionConfig.extensionWindow;
    auction.minimumIncrement = auctionConfig.minimumIncrement;
    auction.start = auctionConfig.start;
    //auction.end = 0;

    // If is not a reserve price triggered auction start immediately
    if (!auctionConfig.isReservePriceTriggered) {
      auction.end = auctionConfig.end;
    }

    emit AuctionCreated(
      msg.sender,
      auctionConfig.nftContract,
      auctionConfig.tokenId,
      auctionConfig.end - auctionConfig.start,
      auctionConfig.extensionWindow,
      auctionConfig.reservePriceOrHighestBid,
      auctionId
    );
  }

  /**
   * @notice Place a bid in an auction.
   * A bidder may place a bid which is at least the amount defined by `getMinBidAmount`.
   * If this is the first bid on the auction, the countdown will begin.
   * If there is already an outstanding bid, the previous bidder will be refunded at this time
   * and if the bid is placed in the final moments of the auction, the countdown may be extended.
   * @dev `amount` - `msg.value` is withdrawn from the bidder's FETH balance.
   * @param auctionId The id of the auction to bid on.
   * @param amount The amount to bid.
   */
  /* solhint-disable-next-line code-complexity */
  function placeBid(
    uint256 auctionId,
    uint256 amount
  ) public payable nonReentrant {
    AuctionState storage auctionDetails = auctionIdToAuction[auctionId];

    if (auctionDetails.reservePriceOrHighestBid == 0) {
      // No auction found
      revert NFTMarketReserveAuction_Cannot_Bid_On_Nonexistent_Auction();
    } else if (amount < msg.value) {
      // The amount is specified by the bidder, so if too much ETH is sent then something went wrong.
      revert NFTMarketReserveAuction_Too_Much_Value_Provided();
    }

    uint256 endTime = auctionDetails.end;

    // If this wasn't a reserve price triggered auction the enTime Would have been !=0
    if (endTime == 0) {
      // This is the first bid, kicking off the auction.
      if (amount < auctionDetails.reservePriceOrHighestBid) {
        // The bid must be >= the reserve price.
        revert NFTMarketReserveAuction_Cannot_Bid_Lower_Than_Reserve_Price(
          auctionDetails.reservePriceOrHighestBid
        );
      }

      // Notify other market tools that an auction for this NFT has started, so that we can cancel any ongoing buy nows or offers
      _notifyAuctionStarted(auctionDetails.nftContract, auctionDetails.tokenId);

      // Store the bid details.
      auctionDetails.reservePriceOrHighestBid = amount;
      auctionDetails.highestBidder = payable(msg.sender);

      // On the first bid, set start and end
      unchecked {
        endTime = auctionDetails.start;
      }
      auctionDetails.end = endTime;
      auctionDetails.start = block.timestamp;
    } else {
      if (endTime < block.timestamp) {
        // The auction has already ended.
        revert NFTMarketReserveAuction_Cannot_Bid_On_Ended_Auction(endTime);
      } else if (auctionDetails.highestBidder == msg.sender) {
        // We currently do not allow a bidder to increase their bid unless another user has outbid them first.
        revert NFTMarketReserveAuction_Cannot_Rebid_Over_Outstanding_Bid();
      } else {
        uint256 minIncrement = getMinBidAmount(
          auctionDetails.reservePriceOrHighestBid
        );
        if (amount < minIncrement) {
          // If this bid outbids another, it must be at least 'minimumIncrement' greater than the last bid.
          revert NFTMarketReserveAuction_Bid_Must_Be_At_Least_Min_Amount(
            minIncrement
          );
        }
      }

      // Update bidder state
      uint256 originalAmount = auctionDetails.reservePriceOrHighestBid;
      address payable originalBidder = auctionDetails.highestBidder;
      auctionDetails.reservePriceOrHighestBid = amount;
      auctionDetails.highestBidder = payable(msg.sender);

      // When a bid outbids another, check to see if a time extension should apply.
      // We confirmed that the auction has not ended, so endTime is always >= the current timestamp.
      // Current time plus extension duration (always 15 mins) cannot overflow
      uint256 endTimeWithExtension = block.timestamp +
        auctionDetails.extensionWindow;
      if (endTime < endTimeWithExtension) {
        endTime = endTimeWithExtension;
        auctionDetails.end = endTime;
      }

      // Refund the previous bidder
      _sendValueWithFallbackWithdraw(
        originalBidder,
        originalAmount,
        SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT
      );
    }

    emit AuctionBidPlaced(auctionId, msg.sender, amount, endTime);
  }

  /**
   * @notice Settle an auction that has already ended.
   * This will send the NFT to the highest bidder and distribute revenue for this sale.
   */
  function _settleAuction(uint256 auctionId) private {
    AuctionState memory auction = auctionIdToAuction[auctionId];

    if (auction.end >= block.timestamp) {
      revert NFTMarketReserveAuction_Cannot_Finalize_Auction_In_Progress(
        auction.end
      );
    }

    // Remove the auction.
    delete nftContractToTokenIdToAuctionId[auction.nftContract][
      auction.tokenId
    ];
    delete auctionIdToAuction[auctionId];

    // The seller was authorized when the auction was originally created
    super._transferFromEscrow(
      auction.nftContract,
      auction.tokenId,
      auction.highestBidder,
      address(0)
    );

    // Distribute revenue for this sale.
    (
      uint256 totalFees,
      uint256 creatorRev,
      uint256 sellerRev
    ) = _distributeFunds(
        auction.nftContract,
        auction.tokenId,
        auction.seller,
        auction.reservePriceOrHighestBid,
        auction.isPrimarySale
      );

    emit AuctionFinalized(
      auctionId,
      auction.seller,
      auction.highestBidder,
      totalFees,
      creatorRev,
      sellerRev
    );
  }

  /**
   * @inheritdoc NFTMarketSharedCore
   * @dev Returns the seller that has the given NFT in escrow for an auction,
   * or bubbles the call up for other considerations.
   */
  function _getSellerOf(
    address nftContract,
    uint256 tokenId
  )
    internal
    view
    virtual
    override(NFTMarketSharedCore, NFTMarketCore)
    returns (address payable seller)
  {
    seller = auctionIdToAuction[
      nftContractToTokenIdToAuctionId[nftContract][tokenId]
    ].seller;
    if (seller == address(0)) {
      seller = super._getSellerOf(nftContract, tokenId);
    }
  }

  // todo we can save gas here by changing public into external and defining another function inside marketCore
  /**
   * @notice Returns the minimum amount a bidder must spend to participate in an auction at this particular moment in time.
   * Bids must be greater than or equal to this value or they will revert.
   * @param auctionId The id of the auction to check.
   * @return minimum The minimum amount for a bid to be accepted.
   */
  function getMinBidAmount(
    uint256 auctionId
  ) public view returns (uint256 minimum) {
    AuctionState storage auctionDetails = auctionIdToAuction[auctionId];
    if (auctionDetails.end == 0) {
      return auctionDetails.reservePriceOrHighestBid;
    }
    if (block.timestamp >= auctionDetails.end - auctionDetails.endingPhase) {
      // In the ending phase
      uint256 percentageBasedBid = auctionDetails.reservePriceOrHighestBid +
        (auctionDetails.endingPhasePercentageFlip *
          auctionDetails.reservePriceOrHighestBid) /
        100;
      uint256 minIncrementBasedBid = auctionDetails.reservePriceOrHighestBid +
        auctionDetails.minimumIncrement;
      if (percentageBasedBid > minIncrementBasedBid) {
        minimum = percentageBasedBid;
      } else {
        minimum = minIncrementBasedBid;
      }
    }
    minimum =
      auctionDetails.reservePriceOrHighestBid +
      auctionDetails.minimumIncrement;
  }

  /**
   * @inheritdoc NFTMarketCore
   * @dev If an auction is found:
   *  - If the auction is over, it will settle the auction and confirm the new seller won the auction.
   *  - If the auction has not received a bid, it will invalidate the auction.
   *  - If the auction is in progress, this will revert.
   */
  function _transferFromEscrow(
    address nftContract,
    uint256 tokenId,
    address recipient,
    address authorizeSeller
  ) internal virtual override {
    uint256 auctionId = nftContractToTokenIdToAuctionId[nftContract][tokenId];
    if (auctionId != 0) {
      AuctionState storage auction = auctionIdToAuction[auctionId];
      if (auction.end == 0) {
        // The auction has not received any bids yet so it may be invalided.

        if (
          authorizeSeller != address(0) && auction.seller != authorizeSeller
        ) {
          // The account trying to transfer the NFT is not the current owner.
          revert NFTMarketReserveAuction_Not_Matching_Seller(auction.seller);
        }

        // Remove the auction.
        delete nftContractToTokenIdToAuctionId[nftContract][tokenId];
        delete auctionIdToAuction[auctionId];

        emit AuctionInvalidated(auctionId);
      } else {
        // If the auction has ended, the highest bidder will be the new owner
        // and if the auction is in progress, this will revert.

        // `authorizeSeller != address(0)` does not apply here since an unsettled auction must go
        // through this path to know who the authorized seller should be.
        if (auction.highestBidder != authorizeSeller) {
          revert NFTMarketReserveAuction_Not_Matching_Seller(
            auction.highestBidder
          );
        }

        // Finalization will revert if the auction has not yet ended.
        _settleAuction(auctionId);
      }
      // The seller authorization has been confirmed.
      authorizeSeller = address(0);
    }

    super._transferFromEscrow(nftContract, tokenId, recipient, authorizeSeller);
  }

  /**
   * @inheritdoc NFTMarketCore
   * @dev Checks if there is an auction for this NFT before allowing the transfer to continue.
   */
  function _transferFromEscrowIfAvailable(
    address nftContract,
    uint256 tokenId,
    address recipient
  ) internal virtual override {
    if (nftContractToTokenIdToAuctionId[nftContract][tokenId] == 0) {
      // No auction was found

      super._transferFromEscrowIfAvailable(nftContract, tokenId, recipient);
    }
  }

  /**
   * @inheritdoc NFTMarketCore
   */
  function _transferToEscrow(
    address nftContract,
    uint256 tokenId
  ) internal virtual override {
    uint256 auctionId = nftContractToTokenIdToAuctionId[nftContract][tokenId];
    if (auctionId == 0) {
      // NFT is not in auction
      super._transferToEscrow(nftContract, tokenId);
      return;
    }
    // Using storage saves gas since most of the data is not needed
    AuctionState storage auction = auctionIdToAuction[auctionId];
    if (auction.end == 0) {
      // Reserve price set, confirm the seller is a match
      if (auction.seller != msg.sender) {
        revert NFTMarketReserveAuction_Not_Matching_Seller(auction.seller);
      }
    } else {
      // Auction in progress, confirm the highest bidder is a match
      if (auction.highestBidder != msg.sender) {
        revert NFTMarketReserveAuction_Not_Matching_Seller(
          auction.highestBidder
        );
      }

      // Finalize auction but leave NFT in escrow, reverts if the auction has not ended
      _settleAuction(auctionId);
    }
  }

  /**
   * @notice Returns auction details for a given auctionId.
   * @param auctionId The id of the auction to lookup.
   */
  function getAuctionDetails(
    uint256 auctionId
  ) external view returns (AuctionState memory auction) {
    AuctionState storage auctionDetails = auctionIdToAuction[auctionId];
    auction = auctionDetails;
  }

  /**
   * @notice Returns the auctionId for a given NFT, or 0 if no auction is found.
   * @dev If an auction is canceled, it will not be returned. However the auction may be over and pending finalization.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @return auctionId The id of the auction, or 0 if no auction is found.
   */
  function getReserveAuctionIdFor(
    address nftContract,
    uint256 tokenId
  ) external view returns (uint256 auctionId) {
    auctionId = nftContractToTokenIdToAuctionId[nftContract][tokenId];
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[1_000] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title An abstraction layer for auctions.
 * @dev This contract can be expanded with reusable calls and data as more auction types are added.
 * @author batu-inal & HardlyDifficult
 */
abstract contract NFTMarketAuctionIdentification is Initializable {
  /**
   * @notice A global id for auctions of any type.
   */
  uint256 private nextAuctionId;

  /**
   * @notice Called once to configure the contract after the initial proxy deployment.
   * @dev This sets the initial auction id to 1, making the first auction cheaper
   * and id 0 represents no auction found.
   */
  function _initializeNFTMarketAuction() internal onlyInitializing {
    nextAuctionId = 1;
  }

  /**
   * @notice Returns id to assign to the next auction.
   */
  function _getNextAndIncrementAuctionId() internal returns (uint256) {
    // AuctionId cannot overflow 256 bits.
    unchecked {
      return nextAuctionId++;
    }
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[1_000] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./shared/NFTMarketSharedCore.sol";
import "./shared/ExchangeArtTreasuryNode.sol";
import "./shared/NFTMarketFees.sol";
import "./shared/SendValueWithFallbackWithdraw.sol";
import "./NFTMarketCore.sol";

/// @param buyPrice The current buy price set for this NFT.
error NFTMarketBuyPrice_Cannot_Buy_At_Lower_Price(uint256 buyPrice);
error NFTMarketBuyPrice_Cannot_Buy_Unset_Price();
error NFTMarketBuyPrice_Cannot_Cancel_Unset_Price();
/// @param owner The current owner of this NFT.
error NFTMarketBuyPrice_Only_Owner_Can_Set_Price(address owner);
error NFTMarketBuyPrice_Only_Owner_Can_Cancel_Price(address owner);
error NFTMarketBuyPrice_Price_Already_Set();
error NFTMarketBuyPrice_Price_Too_High();
/// @param seller The current owner of this NFT.
error NFTMarketBuyPrice_Seller_Mismatch(address seller);
error NFTMarketBuyPrice_Caller_is_Not_Seller();
/// @param startTime The start time of this sale.
error NFTMarketBuyPrice_Sale_Not_Started(uint256 startTime);

/**
 * @title Allows sellers to set a buy price of their NFTs that may be accepted and instantly transferred to the buyer.
 * @notice NFTs with a buy price set are escrowed in the market contract.
 * @author batu-inal & HardlyDifficult
 */
abstract contract NFTMarketBuyNow is
  ExchangeArtTreasuryNode,
  NFTMarketSharedCore,
  NFTMarketCore,
  ReentrancyGuard,
  SendValueWithFallbackWithdraw,
  NFTMarketFees
{
  using Address for address payable;

  /// @notice Stores the buy price details for a specific NFT.
  /// @dev The struct is packed into a single slot to optimize gas.
  struct BuyNow {
    /// @notice The current owner of this NFT which set a buy price.
    /// @dev A zero price is acceptable so a non-zero address determines whether a price has been set.
    address payable seller;
    /// @notice The current buy price set for this NFT.
    uint96 price;
    /// @notice The timestamp at which this sale should start, or 0 if it should start immediatly.
    uint256 startTime;
    /// @notice If this is a primary or secondary sale
    bool isPrimarySale;
  }

  /// @notice Stores the current buy price for each NFT.
  mapping(address => mapping(uint256 => BuyNow))
    private nftContractToTokenIdToBuyPrice;

  /**
   * @notice Emitted when an NFT is bought by accepting the buy price,
   * indicating that the NFT has been transferred and revenue from the sale distributed.
   * @dev The total buy price that was accepted is `totalFees` + `creatorRev` + `sellerRev`.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @param buyer The address of the collector that purchased the NFT using `buy`.
   * @param seller The address of the seller which originally set the buy price.
   * @param totalFees The amount of ETH that was sent to Exchange Art.
   * @param creatorRev The amount of ETH that was sent to the creator for this sale.
   * @param sellerRev The amount of ETH that was sent to the owner for this sale.
   */
  event BuyPriceAccepted(
    address indexed nftContract,
    uint256 indexed tokenId,
    address indexed seller,
    address buyer,
    uint256 totalFees,
    uint256 creatorRev,
    uint256 sellerRev
  );

  /**
   * @notice Emitted when the buy price is removed by the owner of an NFT.
   * @dev The NFT is transferred back to the owner unless it's still escrowed for another market tool,
   * e.g. listed for sale in an auction.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   */
  event BuyPriceCanceled(address indexed nftContract, uint256 indexed tokenId);

  /**
   * @notice Emitted when a buy price is invalidated due to other market activity.
   * @dev This occurs when the buy price is no longer eligible to be accepted,
   * e.g. when a bid is placed in an auction for this NFT.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   */

  event BuyPriceInvalidated(
    address indexed nftContract,
    uint256 indexed tokenId
  );
  /**
   * @notice Emitted when a buy price is set by the owner of an NFT.
   * @dev The NFT is transferred into the market contract for escrow unless it was already escrowed,
   * e.g. for auction listing.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @param seller The address of the NFT owner which set the buy price.
   * @param price The price of the NFT.
   */
  event BuyPriceSet(
    address indexed nftContract,
    uint256 indexed tokenId,
    address indexed seller,
    uint256 price
  );

  /**
   * @notice Buy the NFT at the set buy price.
   * `msg.value` must be <= `maxPrice` and any delta will be taken from the account's available FETH balance.
   * @dev `maxPrice` protects the buyer in case a the price is increased but allows the transaction to continue
   * when the price is reduced (and any surplus funds provided are refunded).
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @param maxPrice The maximum price to pay for the NFT.
   */
  function buy(
    address nftContract,
    uint256 tokenId,
    uint256 maxPrice
  ) external payable {
    BuyNow storage buyNowSale = nftContractToTokenIdToBuyPrice[nftContract][
      tokenId
    ];
    if (buyNowSale.price > maxPrice) {
      revert NFTMarketBuyPrice_Cannot_Buy_At_Lower_Price(buyNowSale.price);
    } else if (buyNowSale.seller == address(0)) {
      revert NFTMarketBuyPrice_Cannot_Buy_Unset_Price();
    }
    if (block.timestamp < buyNowSale.startTime) {
      revert NFTMarketBuyPrice_Sale_Not_Started(buyNowSale.startTime);
    }
    _process_buy_now(nftContract, tokenId);
  }

  /**
   * @notice Removes the buy price set for an NFT.
   * @dev The NFT is transferred back to the owner unless it's still escrowed for another market tool,
   * e.g. listed for sale in an auction.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   */
  function cancelBuyNow(
    address nftContract,
    uint256 tokenId
  ) external nonReentrant {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId]
      .seller;
    if (seller == address(0)) {
      // This check is redundant with the next one, but done in order to provide a more clear error message.
      revert NFTMarketBuyPrice_Cannot_Cancel_Unset_Price();
    } else if (seller != msg.sender) {
      revert NFTMarketBuyPrice_Only_Owner_Can_Cancel_Price(seller);
    }

    // Remove the buy price
    delete nftContractToTokenIdToBuyPrice[nftContract][tokenId];

    // Transfer the NFT back to the owner if it is not listed in auction.
    _transferFromEscrowIfAvailable(nftContract, tokenId, msg.sender);

    emit BuyPriceCanceled(nftContract, tokenId);
  }

  /**
   * @notice Allows a user to create a buy now sale for an NFT, if the NFT is already in escrow, the details can be edited.
   * @dev If the NFT is already in escrow we ensure that only the owner of the NFT can call this function again.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @param price The price at which someone could buy this NFT.
   * @param startTime The timestamp indicating when this NFT can be sold, if set to 0, sale starts immediatley
   * @param isPrimarySale Flag indicating if this is a primary sale. roayalty distribution is affected depending on this
   */
  function createOrEditBuyNowSale(
    address nftContract,
    uint256 tokenId,
    uint256 price,
    uint256 startTime,
    bool isPrimarySale
  ) external nonReentrant {
    if (price > type(uint96).max) {
      // This ensures that no data is lost when storing the price as `uint96`.
      revert NFTMarketBuyPrice_Price_Too_High();
    }

    BuyNow storage buyNowSale = nftContractToTokenIdToBuyPrice[nftContract][
      tokenId
    ];
    address seller = buyNowSale.seller;

    if (
      buyNowSale.price == price &&
      seller != address(0) &&
      buyNowSale.startTime == startTime &&
      buyNowSale.isPrimarySale == isPrimarySale
    ) {
      revert NFTMarketBuyPrice_Price_Already_Set();
    }

    // there is no active by now sale for this NFT
    if (seller == address(0)) {
      // Transfer the NFT into escrow, if it's already in escrow confirm the `msg.sender` is the owner.
      _transferToEscrow(nftContract, tokenId);

      // The price was not previously set for this NFT, store the seller.
      buyNowSale.seller = payable(msg.sender);
    } else if (seller != msg.sender) {
      // Buy price was previously set by a different user
      revert NFTMarketBuyPrice_Only_Owner_Can_Set_Price(seller);
    }

    // Store the details of this buy now sale.
    buyNowSale.price = uint96(price); // todo: why is this uint96?
    buyNowSale.startTime = startTime;
    buyNowSale.isPrimarySale = isPrimarySale;

    emit BuyPriceSet(nftContract, tokenId, msg.sender, price);
  }

  /**
   * @notice Process the purchase of an NFT at the current buy price.
   * @dev The caller must confirm that the seller != address(0) before calling this function.
   */
  function _process_buy_now(
    address nftContract,
    uint256 tokenId
  ) private nonReentrant {
    BuyNow memory buyPrice = nftContractToTokenIdToBuyPrice[nftContract][
      tokenId
    ];

    // Remove the buy now price
    delete nftContractToTokenIdToBuyPrice[nftContract][tokenId];

    // Cancel the buyer's offer if there is one in order to free up their FETH balance
    // even if they don't need the FETH for this specific purchase.
    // _cancelSendersOffer(nftContract, tokenId);

    // Transfer the NFT to the buyer.
    // The seller was already authorized when the buyPrice was set originally set.
    _transferFromEscrow(nftContract, tokenId, msg.sender, address(0));

    // Distribute revenue for this sale.
    (
      uint256 totalFees,
      uint256 creatorRev,
      uint256 sellerRev
    ) = _distributeFunds(
        nftContract,
        tokenId,
        buyPrice.seller,
        buyPrice.price,
        buyPrice.isPrimarySale
      );

    emit BuyPriceAccepted(
      nftContract,
      tokenId,
      buyPrice.seller,
      msg.sender,
      totalFees,
      creatorRev,
      sellerRev
    );
  }

  /**
   * @notice Returns the buy now sale details for an NFT if one is available.
   * @dev If no price is found, seller will be address(0) and price will be max uint256.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @return seller The address of the owner that listed a buy price for this NFT.
   * Returns `address(0)` if there is no buy price set for this NFT.
   * @return price The price of the NFT.
   * Returns max uint256 if there is no buy price set for this NFT (since a price of 0 is supported).
   */
  function getBuyNowSaleDetails(
    address nftContract,
    uint256 tokenId
  )
    external
    view
    returns (
      address seller,
      uint256 price,
      uint256 startTime,
      bool isPrimarySale
    )
  {
    seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller == address(0)) {
      return (seller, type(uint256).max, 0, false);
    }
    price = nftContractToTokenIdToBuyPrice[nftContract][tokenId].price;
    startTime = nftContractToTokenIdToBuyPrice[nftContract][tokenId].startTime;
    isPrimarySale = nftContractToTokenIdToBuyPrice[nftContract][tokenId]
      .isPrimarySale;
  }

  /**
   * @inheritdoc NFTMarketSharedCore
   * @dev Returns the seller if there is a buy price set for this NFT, otherwise
   * bubbles the call up for other considerations.
   */
  function _getSellerOf(
    address nftContract,
    uint256 tokenId
  )
    internal
    view
    virtual
    override(NFTMarketSharedCore, NFTMarketCore)
    returns (address payable seller)
  {
    seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller == address(0)) {
      seller = super._getSellerOf(nftContract, tokenId);
    }
  }

  /**
   * @inheritdoc NFTMarketCore
   * @dev Invalidates the buy price if one is found before transferring the NFT.
   * This will revert if there is a buy price set but the `authorizeSeller` is not the owner.
   */
  function _transferFromEscrow(
    address nftContract,
    uint256 tokenId,
    address recipient,
    address authorizeSeller
  ) internal virtual override {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId]
      .seller;
    if (seller != address(0)) {
      // A buy price was set for this NFT.
      // `authorizeSeller != address(0) &&` could be added when other mixins use this flow.
      // ATM that additional check would never return false.
      if (seller != authorizeSeller) {
        // When there is a buy price set, the `buyPrice.seller` is the owner of the NFT.
        revert NFTMarketBuyPrice_Seller_Mismatch(seller);
      }
      // The seller authorization has been confirmed.
      authorizeSeller = address(0);
    }

    super._transferFromEscrow(nftContract, tokenId, recipient, authorizeSeller);
  }

  /**
   * @inheritdoc NFTMarketCore
   * @dev Checks if there is a buy price set, if not then allow the transfer to proceed.
   */
  function _transferFromEscrowIfAvailable(
    address nftContract,
    uint256 tokenId,
    address recipient
  ) internal virtual override {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId]
      .seller;
    if (seller == address(0)) {
      // A buy price has been set for this NFT so it should remain in escrow.
      super._transferFromEscrowIfAvailable(nftContract, tokenId, recipient);
    }
  }

  /**
   * @inheritdoc NFTMarketCore
   * @dev Checks if the NFT is already in escrow for buy now.
   */
  function _transferToEscrow(
    address nftContract,
    uint256 tokenId
  ) internal virtual override {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId]
      .seller;
    if (seller == address(0)) {
      // The NFT is not in escrow for buy now.
      super._transferToEscrow(nftContract, tokenId);
    } else if (seller != msg.sender) {
      // When there is a buy price set, the `seller` is the owner of the NFT.
      revert NFTMarketBuyPrice_Seller_Mismatch(seller);
    }
  }

  /**
   * @notice Clear a buy price and emit BuyPriceInvalidated.
   * @dev The caller must confirm the buy price is set before calling this function.
   */
  function _invalidateBuyPrice(address nftContract, uint256 tokenId) private {
    delete nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    emit BuyPriceInvalidated(nftContract, tokenId);
  }

  /**
   * @inheritdoc NFTMarketCore
   * @dev Invalidates the buy price on a auction start, if one is found.
   */
  function _notifyAuctionStarted(
    address nftContract,
    uint256 tokenId
  ) internal virtual override {
    BuyNow storage buyPrice = nftContractToTokenIdToBuyPrice[nftContract][
      tokenId
    ];
    if (buyPrice.seller != address(0)) {
      // A buy price was set for this NFT, invalidate it.
      _invalidateBuyPrice(nftContract, tokenId);
    }
    super._notifyAuctionStarted(nftContract, tokenId);
  }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./shared/NFTMarketSharedCore.sol";

error NFTMarketCore_Seller_Not_Found();

/**
 * @title A place for common modifiers and functions used by various NFTMarket mixins, if any.
 * @dev This also leaves a gap which can be used to add a new mixin to the top of the inheritance tree.
 * @author batu-inal & HardlyDifficult
 */
abstract contract NFTMarketCore is NFTMarketSharedCore {
  using Address for address;
  using Address for address payable;

  /**
   * @notice Transfers the NFT from escrow and clears any state tracking this escrowed NFT.
   * @param authorizeSeller The address of the seller pending authorization.
   * Once it's been authorized by one of the escrow managers, it should be set to address(0)
   * indicated that it's no longer pending authorization.
   */
  function _transferFromEscrow(
    address nftContract,
    uint256 tokenId,
    address recipient,
    address authorizeSeller
  ) internal virtual {
    if (authorizeSeller != address(0)) {
      revert NFTMarketCore_Seller_Not_Found();
    }
    IERC721(nftContract).transferFrom(address(this), recipient, tokenId);
  }

  /**
   * @notice Transfers the NFT from escrow unless there is another reason for it to remain in escrow.
   */
  function _transferFromEscrowIfAvailable(address nftContract, uint256 tokenId, address recipient) internal virtual {
    _transferFromEscrow(nftContract, tokenId, recipient, address(0));
  }

  /**
   * @notice Transfers an NFT into escrow,
   * if already there this requires the msg.sender is authorized to manage the sale of this NFT.
   */
  function _transferToEscrow(address nftContract, uint256 tokenId) internal virtual {
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
  }

  /**
   * @inheritdoc NFTMarketSharedCore
   */
  function _getSellerOf(
    address nftContract,
    uint256 tokenId
  )
    internal
    view
    virtual
    override
    returns (
      address payable seller // solhint-disable-next-line no-empty-blocks
    )
  {
    // No-op by default
  }

  /**
   * @inheritdoc NFTMarketSharedCore
   */
  function _getSellerOrOwnerOf(
    address nftContract,
    uint256 tokenId
  ) internal view override returns (address payable sellerOrOwner) {
    sellerOrOwner = _getSellerOf(nftContract, tokenId);
    if (sellerOrOwner == address(0)) {
      sellerOrOwner = payable(IERC721(nftContract).ownerOf(tokenId));
    }
  }

  /**
   * @notice Notify implementors when an auction has received its first bid.
   * Once a bid is received the sale is guaranteed to the auction winner
   * and other sale mechanisms become unavailable.
   * @dev Implementors of this interface should update internal state to reflect an auction has been kicked off.
   */
  function _notifyAuctionStarted(
    address /*nftContract*/,
    uint256 /*tokenId*/ // solhint-disable-next-line no-empty-blocks
  ) internal virtual {
    // No-op
  }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

/**
 * @dev 100% in basis points.
 */
uint256 constant BASIS_POINTS = 10_000;


// todo: Why do we need this? - investigate if correct
/**
 * @dev The gas limit to send ETH to a single recipient, enough for a contract with a simple receiver.
 */
uint256 constant SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT = 20_000;

/**
 * @dev The gas limit to send ETH to multiple recipients, enough for a 5-way split.
 */
uint256 constant SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS = 210_000;

/**
 * @dev The gas limit used when making external read-only calls.
 * This helps to ensure that external calls does not prevent the market from executing.
 */
uint256 constant READ_ONLY_GAS_LIMIT = 40_000;

/**
 * @dev The gas limit used when making external read-only calls.
 * This helps to ensure that external calls does not prevent the market from executing.
 */
uint256 constant EXCHANGE_ART_PRIMARY_FEE = 500;

/**
 * @dev The gas limit used when making external read-only calls.
 * This helps to ensure that external calls does not prevent the market from executing.
 */
uint256 constant EXCHANGE_ART_SECONDARY_FEE = 300;

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";


error ExchangeArtTreasuryNode_Address_Is_Not_A_Contract();
// error FoundationTreasuryNode_Caller_Not_Admin();
// error FoundationTreasuryNode_Caller_Not_Operator();

/**
 * @title A mixin that stores a reference to the Exchange Art treasury contract.
 * @notice The treasury collects fees and defines admin/operator roles.
 * @author batu-inal & HardlyDifficult
 */
abstract contract ExchangeArtTreasuryNode {
  using AddressUpgradeable for address payable;

  /// @notice The address of the treasury contract.
  address payable private immutable treasury;

  // /// @notice Requires the caller is a ExchangeArt admin.
  // modifier onlyFoundationAdmin() {
  //   if (!IAdminRole(treasury).isAdmin(msg.sender)) {
  //     revert FoundationTreasuryNode_Caller_Not_Admin();
  //   }
  //   _;
  // }

  // /// @notice Requires the caller is a ExchangeArt operator.
  // modifier onlyFoundationOperator() {
  //   if (!IOperatorRole(treasury).isOperator(msg.sender)) {
  //     revert FoundationTreasuryNode_Caller_Not_Operator();
  //   }
  //   _;
  // }

  /**
   * @notice Set immutable variables for the implementation contract.
   * @dev Assigns the treasury contract address.
   */
  constructor(address payable _treasury) {
    // todo: uncomment this when deploying to mainnet
    // if (!_treasury.isContract()) {
    //   revert ExchangeArtTreasuryNode_Address_Is_Not_A_Contract();
    // }
    treasury = _treasury;
  }

  /**
   * @notice Gets the Foundation treasury contract.
   * @dev This call is used in the royalty registry contract.
   * @return treasuryAddress The address of the ExchangeArt treasury contract.
   */
  function getExchangeArtTreasury() public view returns (address payable treasuryAddress) {
    treasuryAddress = treasury;
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[2_000] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
//import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "./NFTMarketSharedCore.sol";
import "./SendValueWithFallbackWithdraw.sol";
import "./Constants.sol";
import "./ExchangeArtTreasuryNode.sol";

import "../../libraries/OZERC165Checker.sol";

import "../../interfaces/royalties/IRoyaltyInfo.sol";
import "../../interfaces/royalties/IGetRoyalties.sol";

/**
 * @title A mixin to distribute funds when an NFT is sold.
 * @author exhgArt
 */
abstract contract NFTMarketFees is
  ExchangeArtTreasuryNode,
  NFTMarketSharedCore,
  SendValueWithFallbackWithdraw
{
  using Address for address;
  //using ERC165Checker for address;
  using OZERC165Checker for address;

  /// @notice The address of this contract's implementation.
  /// @dev This is used when making stateless external calls to this contract,
  /// saving gas over hopping through the proxy which is only necessary when accessing state.
  NFTMarketFees private immutable implementationAddress;

  constructor() {
    // We don't use this anywehere yet
    // In the constructor, `this` refers to the implementation address. Everywhere else it'll be the proxy.
    implementationAddress = this;
  }

  /**
   * @notice Distributes funds to Exchange Art, creator recipients, and NFT owner after a sale.
   */
  function _distributeFunds(
    address nftContract,
    uint256 tokenId,
    address payable seller,
    uint256 price,
    bool isPrimarySale
  )
    internal
    returns (uint256 exchangeArtFees, uint256 creatorRev, uint256 sellerRev)
  {
    if (price == 0) {
      // When the sale price is 0, there are no revenue to distribute.
      return (0, 0, 0);
    }
    address payable[] memory creatorRecipients;
    uint256[] memory creatorShares;

    (exchangeArtFees, creatorRecipients, creatorShares, sellerRev) = _getFees(
      nftContract,
      tokenId,
      price,
      isPrimarySale
    );

    // Pay the creator(s)
    if (creatorRecipients.length > 0) {
      // If just a single recipient was defined, use a larger gas limit in order to support in-contract split logic.
      uint256 creatorGasLimit = creatorRecipients.length == 1
        ? SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS
        : SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT;
      unchecked {
        for (uint256 i = 0; i < creatorRecipients.length; ++i) {
          _sendValueWithFallbackWithdraw(
            creatorRecipients[i],
            creatorShares[i],
            creatorGasLimit
          );
          // Sum the total creator rev from shares
          // creatorShares is in ETH so creatorRev will not overflow here.
          creatorRev += creatorShares[i];
        }
      }
    }

    // Pay the seller
    if (sellerRev > 0) {
      // Unlikely scenario in which someone does a primary sale but is not in the creators array
      _sendValueWithFallbackWithdraw(
        seller,
        sellerRev,
        SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT
      );
    }

    // Pay the protocol fee
    _sendValueWithFallbackWithdraw(
      getExchangeArtTreasury(),
      exchangeArtFees,
      SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT
    );
  }

  /**
   * @notice **For internal use only.**
   * @dev This function is external to allow using try/catch but is not intended for external use.
   * If ERC2981 royalties (or getRoyalties) are defined by the NFT contract, allow this standard to define immutable
   * royalties that cannot be later changed via the royalty registry.
   */
  function internalGetImmutableRoyalties(
    address nftContract,
    uint256 tokenId
  )
    external
    view
    returns (
      address payable[] memory recipients,
      uint256[] memory splitPerRecipientInBasisPoints
    )
  {
    // 1st priority: ERC-2981
    if (
      nftContract.supportsERC165InterfaceUnchecked(
        type(IRoyaltyInfo).interfaceId
      )
    ) {
      try
        IRoyaltyInfo(nftContract).royaltyInfo{gas: READ_ONLY_GAS_LIMIT}(
          tokenId,
          BASIS_POINTS
        )
      returns (address receiver, uint256 royaltyAmount) {
        // Manifold contracts return (address(this), 0) when royalties are not defined
        // - so ignore results when the amount is 0
        if (royaltyAmount > 0) {
          recipients = new address payable[](1);
          recipients[0] = payable(receiver);
          splitPerRecipientInBasisPoints = new uint256[](1);
          // The split amount is assumed to be 100% when only 1 recipient is returned
          return (recipients, splitPerRecipientInBasisPoints);
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }

    // 2nd priority: getRoyalties
    if (
      nftContract.supportsERC165InterfaceUnchecked(
        type(IGetRoyalties).interfaceId
      )
    ) {
      try
        IGetRoyalties(nftContract).getRoyalties{gas: READ_ONLY_GAS_LIMIT}(
          tokenId
        )
      returns (
        address payable[] memory _recipients,
        uint256[] memory recipientBasisPoints
      ) {
        if (
          _recipients.length != 0 &&
          _recipients.length == recipientBasisPoints.length
        ) {
          return (_recipients, recipientBasisPoints);
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }
  }

  /**
   * @notice Calculates how funds should be distributed for the given sale details.
   * @dev When the NFT is being sold by the `tokenCreator`, all the seller revenue will
   * be split with the royalty recipients defined for that NFT.
   */
  // solhint-disable-next-line code-complexity
  function _getFees(
    address nftContract,
    uint256 tokenId,
    uint256 price,
    bool isPrimarySale
  )
    private
    view
    returns (
      uint256 exchangeArtFees,
      address payable[] memory creatorRecipients,
      uint256[] memory creatorShares,
      uint256 sellerRev
    )
  {
    // Calculate the protocol fee

    try
      implementationAddress.internalGetImmutableRoyalties(nftContract, tokenId)
    returns (
      address payable[] memory _recipients,
      uint256[] memory _splitPerRecipientInBasisPoints
    ) {
      (creatorRecipients, creatorShares) = (
        _recipients,
        _splitPerRecipientInBasisPoints
      );
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }

    uint256 totalShares = 0;
    uint256 creatorsPayout = 0;
    sellerRev = 0;

    // Calculate total shares of creators
    for (uint256 i = 0; i < creatorRecipients.length; ++i) {
      totalShares += creatorShares[i];
    }

    if (isPrimarySale) {
      unchecked {
        exchangeArtFees = (price * EXCHANGE_ART_PRIMARY_FEE) / BASIS_POINTS;
        creatorsPayout = price - exchangeArtFees;
      }
      // If there are no creators defined, all revenue goes to seller;
      if (
        creatorRecipients.length == 0 ||
        totalShares > BASIS_POINTS - EXCHANGE_ART_PRIMARY_FEE
      ) {
        sellerRev = creatorsPayout;
        creatorsPayout = 0;
      } else {
        sellerRev = 0;
      }
    } else {
      unchecked {
        exchangeArtFees = (price * EXCHANGE_ART_SECONDARY_FEE) / BASIS_POINTS;
      }
      if (totalShares > BASIS_POINTS - EXCHANGE_ART_SECONDARY_FEE) {
        // todo what do we want to do here?
        creatorsPayout = 0;
      } else {
        creatorsPayout =
          ((price - exchangeArtFees) * totalShares) /
          BASIS_POINTS;
      }
      sellerRev = price - exchangeArtFees - creatorsPayout;
    }

    // Send payouts to each additional recipient if more than 1 was defined
    uint256 totalRoyaltiesDistributed;
    for (uint256 i = 0; i < creatorRecipients.length; ) {
      uint256 royalty = (creatorsPayout * creatorShares[i]) / totalShares;
      totalRoyaltiesDistributed += royalty;
      creatorShares[i] = royalty;
      unchecked {
        ++i;
      }
    }

    if (creatorsPayout - totalRoyaltiesDistributed != 0) {
      if (isPrimarySale && creatorShares.length > 0) {
        // Send the remainder to the 1st creator, rounding in their favor
        creatorShares[0] += creatorsPayout - totalRoyaltiesDistributed;
      } else {
        sellerRev += creatorsPayout - totalRoyaltiesDistributed;
      }
    }
  }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;


/**
 * @title A place for common modifiers and functions used by various market mixins, if any.
 * @dev This also leaves a gap which can be used to add a new mixin to the top of the inheritance tree.
 * @author exchArt
 */
abstract contract NFTMarketSharedCore  {
  /**
   * @notice Checks who the seller for an NFT is if listed in this market.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @return seller The seller which listed this NFT for sale, or address(0) if not listed.
   */
  function getSellerOf(address nftContract, uint256 tokenId) external view returns (address payable seller) {
    seller = _getSellerOf(nftContract, tokenId);
  }

  /**
   * @notice Checks who the seller for an NFT is if listed in this market.
   */
  function _getSellerOf(address nftContract, uint256 tokenId) internal view virtual returns (address payable seller);

  /**
   * @notice Checks who the seller for an NFT is if listed in this market or returns the current owner.
   */
  function _getSellerOrOwnerOf(address nftContract, uint256 tokenId)
    internal
    view
    virtual
    returns (address payable sellerOrOwner);

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[500] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title A mixin for sending ETH with a fallback withdraw mechanism.
 * @notice Attempt to send ETH and if the transfer fails or runs out of gas, store the balance
 * in the FETH token contract for future withdrawal instead.
 * @dev This mixin was recently switched to escrow funds in FETH.
 * Once we have confirmed all pending balances have been withdrawn, we can remove the escrow tracking here.
 * @author batu-inal & HardlyDifficult
 */
abstract contract SendValueWithFallbackWithdraw  {
  using Address for address payable;


  /**
   * @notice Attempt to send a user or contract ETH.
   * If it fails store the amount owned for later withdrawal in FETH.
   * @dev This may fail when sending ETH to a contract that is non-receivable or exceeds the gas limit specified.
   */
  function _sendValueWithFallbackWithdraw(
    address payable user,
    uint256 amount,
    uint256 gasLimit
  ) internal {
    if (amount == 0) {
      return;
    }
    // Cap the gas to prevent consuming all available gas to block a tx from completing successfully
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = user.call{ value: amount, gas: gasLimit }("");
    // if (!success) {
    //   // Store the funds that failed to send for the user in the FETH token
    //   feth.depositFor{ value: amount }(user);
    //   emit WithdrawalToFETH(user, amount);
    // }
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[999] private __gap;
}