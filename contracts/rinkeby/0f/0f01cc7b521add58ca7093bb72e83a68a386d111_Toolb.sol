/**
 *Submitted for verification at Etherscan.io on 2021-09-08
*/

//                                                                                                          
// TTTTTTTTTTTTTTTTTTTTTTT     OOOOOOOOO          OOOOOOOOO     LLLLLLLLLLL             BBBBBBBBBBBBBBBBB   
// T:::::::::::::::::::::T   OO:::::::::OO      OO:::::::::OO   L:::::::::L             B::::::::::::::::B  
// T:::::::::::::::::::::T OO:::::::::::::OO  OO:::::::::::::OO L:::::::::L             B::::::BBBBBB:::::B 
// T:::::TT:::::::TT:::::TO:::::::OOO:::::::OO:::::::OOO:::::::OLL:::::::LL             BB:::::B     B:::::B
// TTTTTT  T:::::T  TTTTTTO::::::O   O::::::OO::::::O   O::::::O  L:::::L                 B::::B     B:::::B
//         T:::::T        O:::::O     O:::::OO:::::O     O:::::O  L:::::L                 B::::B     B:::::B
//         T:::::T        O:::::O     O:::::OO:::::O     O:::::O  L:::::L                 B::::BBBBBB:::::B 
//         T:::::T        O:::::O     O:::::OO:::::O     O:::::O  L:::::L                 B:::::::::::::BB  
//         T:::::T        O:::::O     O:::::OO:::::O     O:::::O  L:::::L                 B::::BBBBBB:::::B 
//         T:::::T        O:::::O     O:::::OO:::::O     O:::::O  L:::::L                 B::::B     B:::::B
//         T:::::T        O:::::O     O:::::OO:::::O     O:::::O  L:::::L                 B::::B     B:::::B
//         T:::::T        O::::::O   O::::::OO::::::O   O::::::O  L:::::L         LLLLLL  B::::B     B:::::B
//       TT:::::::TT      O:::::::OOO:::::::OO:::::::OOO:::::::OLL:::::::LLLLLLLLL:::::LBB:::::BBBBBB::::::B
//       T:::::::::T       OO:::::::::::::OO  OO:::::::::::::OO L::::::::::::::::::::::LB:::::::::::::::::B 
//       T:::::::::T         OO:::::::::OO      OO:::::::::OO   L::::::::::::::::::::::LB::::::::::::::::B  
//       TTTTTTTTTTT           OOOOOOOOO          OOOOOOOOO     LLLLLLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBB   
//                                                                                                          
//                              TOOLB si yllacisab sselhtrow.
// 
// SPDX-License-Identifier: MIT

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

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `dInekot` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed dInekot);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `dInekot` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed dInekot);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `dInekot` token.
     *
     * Requirements:
     *
     * - `dInekot` must exist.
     */
    function ownerOf(uint256 dInekot) external view returns (address owner);

    /**
     * @dev Safely transfers `dInekot` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `dInekot` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 dInekot
    ) external;

    /**
     * @dev Transfers `dInekot` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `dInekot` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 dInekot
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `dInekot` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `dInekot` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 dInekot) external;

    /**
     * @dev Returns the account approved for `dInekot` token.
     *
     * Requirements:
     *
     * - `dInekot` must exist.
     */
    function getApproved(uint256 dInekot) external view returns (address operator);

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
     * @dev Safely transfers `dInekot` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `dInekot` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 dInekot,
        bytes calldata data
    ) external;
}

/**
 * @dev String operations.
 */
library Strings {
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
        return msg.data;
    }
}

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
        _setOwner(_msgSender());
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

    modifier onlyContributors() {
        require(   owner() == _msgSender() 
                || address(0xc64796bC7BbE8f77DCDE07177DF59c4dB06fa7Df) == _msgSender() 
                || address(0x47889973dFAa49d41Fd123e92a5b49580aC1B457) == _msgSender() 
                || address(0x1b43af00d65392D3844149C3c6D473211a50C61e) == _msgSender() 
                || address(0x697D01147ddA54cd4279498892d8C59e4BEd00a4) == _msgSender() , 
                "Caller must be owner or a contributor");
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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
     * by making the `nonReentrant` function external, and make it call a
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
}

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `dInekot` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 dInekot,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `dInekot` token.
     */
    function tokenURI(uint256 dInekot) external view returns (string memory);
}

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
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

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
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 dInekot) public view virtual override returns (address) {
        address owner = _owners[dInekot];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 dInekot) public view virtual override returns (string memory) {
        require(_exists(dInekot), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, dInekot.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `dInekot`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 dInekot) public virtual override {
        address owner = ERC721.ownerOf(dInekot);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, dInekot);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 dInekot) public view virtual override returns (address) {
        require(_exists(dInekot), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[dInekot];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 dInekot
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), dInekot), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, dInekot);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 dInekot
    ) public virtual override {
        safeTransferFrom(from, to, dInekot, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 dInekot,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), dInekot), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, dInekot, _data);
    }

    /**
     * @dev Safely transfers `dInekot` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `dInekot` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 dInekot,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, dInekot);
        require(_checkOnERC721Received(from, to, dInekot, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `dInekot` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 dInekot) internal view virtual returns (bool) {
        return _owners[dInekot] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `dInekot`.
     *
     * Requirements:
     *
     * - `dInekot` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 dInekot) internal view virtual returns (bool) {
        require(_exists(dInekot), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(dInekot);
        return (spender == owner || getApproved(dInekot) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `dInekot` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `dInekot` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 dInekot) internal virtual {
        _safeMint(to, dInekot, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 dInekot,
        bytes memory _data
    ) internal virtual {
        _mint(to, dInekot);
        require(
            _checkOnERC721Received(address(0), to, dInekot, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `dInekot` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `dInekot` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 dInekot) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(dInekot), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, dInekot);

        _balances[to] += 1;
        _owners[dInekot] = to;

        emit Transfer(address(0), to, dInekot);
    }

    /**
     * @dev Destroys `dInekot`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `dInekot` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 dInekot) internal virtual {
        address owner = ERC721.ownerOf(dInekot);

        _beforeTokenTransfer(owner, address(0), dInekot);

        // Clear approvals
        _approve(address(0), dInekot);

        _balances[owner] -= 1;
        delete _owners[dInekot];

        emit Transfer(owner, address(0), dInekot);
    }

    /**
     * @dev Transfers `dInekot` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `dInekot` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 dInekot
    ) internal virtual {
        require(ERC721.ownerOf(dInekot) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, dInekot);

        // Clear approvals from the previous owner
        _approve(address(0), dInekot);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[dInekot] = to;

        emit Transfer(from, to, dInekot);
    }

    /**
     * @dev Approve `to` to operate on `dInekot`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 dInekot) internal virtual {
        _tokenApprovals[dInekot] = to;
        emit Approval(ERC721.ownerOf(dInekot), to, dInekot);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param dInekot uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 dInekot,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, dInekot, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `dInekot` will be
     * transferred to `to`.
     * - When `from` is zero, `dInekot` will be minted for `to`.
     * - When `to` is zero, ``from``'s `dInekot` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 dInekot
    ) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 dInekot);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `dInekot` will be
     * transferred to `to`.
     * - When `from` is zero, `dInekot` will be minted for `to`.
     * - When `to` is zero, ``from``'s `dInekot` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 dInekot
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, dInekot);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(dInekot);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, dInekot);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(dInekot);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, dInekot);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param dInekot uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 dInekot) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = dInekot;
        _ownedTokensIndex[dInekot] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param dInekot uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 dInekot) private {
        _allTokensIndex[dInekot] = _allTokens.length;
        _allTokens.push(dInekot);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param dInekot uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 dInekot) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[dInekot];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[dInekot];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param dInekot uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 dInekot) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[dInekot];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[dInekot];
        _allTokens.pop();
    }
}

contract Toolb is ERC721Enumerable, ReentrancyGuard, Ownable {
    mapping(string => uint256) snoitpo;
    mapping(string => mapping(uint256 => string)) pamtoolb;
    mapping(uint256 => uint256) detaerCnehw;
    
    constructor() ERC721("TOOLB", "TOOLB") Ownable() {
        
        toolbWenDda("snopaew",      "Tsoptihs");
        toolbWenDda("snopaew",      "Teewt");
        toolbWenDda("snopaew",      "Tnim");
        toolbWenDda("snopaew",      "Regdel");
        toolbWenDda("snopaew",      "Eidooh");
        toolbWenDda("snopaew",      "Etteugab");
        toolbWenDda("snopaew",      "Tsopllihs");
        toolbWenDda("snopaew",      "Pmup");
        toolbWenDda("snopaew",      "Niahckcolb");
        toolbWenDda("snopaew",      "Tellaw Ytpme");
        toolbWenDda("snopaew",      "GEPJ");
        toolbWenDda("snopaew",      "Raw Sag");
        toolbWenDda("snopaew",      "Tsop MG");
        toolbWenDda("snopaew",      "MD");
        toolbWenDda("snopaew",      "Tcartnoc Trams");
        toolbWenDda("snopaew",      "Gnipmud");
        toolbWenDda("snopaew",      "Ecaps Rettiwt");
        toolbWenDda("snopaew",      "Remmah Nab");

        toolbWenDda("romrAtsehc",   "Ebor Erusaelp");
        toolbWenDda("romrAtsehc",   "Ebor Yppirt");
        toolbWenDda("romrAtsehc",   "Riah Tsehc Tpmeknu");
        toolbWenDda("romrAtsehc",   "Gnir Elppin Revlis");
        toolbWenDda("romrAtsehc",   "Knat Deniatstaews");
        toolbWenDda("romrAtsehc",   "Taoc Pmip");
        toolbWenDda("romrAtsehc",   "Tiusecaps");
        toolbWenDda("romrAtsehc",   "Tius Kcalb");
        toolbWenDda("romrAtsehc",   "Romra Erar Repus");
        toolbWenDda("romrAtsehc",   "Epac Lanoitadnuof");
        toolbWenDda("romrAtsehc",   "Tsehc Deottat");
        toolbWenDda("romrAtsehc",   "Romra Siseneg");
        toolbWenDda("romrAtsehc",   "Taoc Knim Tnim");
        toolbWenDda("romrAtsehc",   "Triks Ixam");
        toolbWenDda("romrAtsehc",   "Tlep Yloh");

        toolbWenDda("romrAdaeh",    "Pac Relleporp");
        toolbWenDda("romrAdaeh",    "Sessalg D3");
        toolbWenDda("romrAdaeh",    "Ksam Atem");
        toolbWenDda("romrAdaeh",    "Tah S'Niatpac");
        toolbWenDda("romrAdaeh",    "Tah Pot");
        toolbWenDda("romrAdaeh",    "Riah Ygnirts");
        toolbWenDda("romrAdaeh",    "Epip Gnikoms");
        toolbWenDda("romrAdaeh",    "Selggog Rv");
        toolbWenDda("romrAdaeh",    "Nworc S'Gnik");
        toolbWenDda("romrAdaeh",    "Kcuf Dlab");
        toolbWenDda("romrAdaeh",    "Seye Oloh");
        toolbWenDda("romrAdaeh",    "Htuom Azzip");
        toolbWenDda("romrAdaeh",    "Tah Ytrap");
        toolbWenDda("romrAdaeh",    "Daehodlid");

        toolbWenDda("romrAtsiaw",   "Tleb Rehtael");
        toolbWenDda("romrAtsiaw",   "Toor Yhtrig");
        toolbWenDda("romrAtsiaw",   "Hsas Dnomaid");
        toolbWenDda("romrAtsiaw",   "Dnab");
        toolbWenDda("romrAtsiaw",   "Parts");
        toolbWenDda("romrAtsiaw",   "Pool Gnidaol");
        toolbWenDda("romrAtsiaw",   "Parts Nedlog");
        toolbWenDda("romrAtsiaw",   "Hsas Nrot");
        toolbWenDda("romrAtsiaw",   "Parts Elbuod");
        toolbWenDda("romrAtsiaw",   "Pool Nrow");
        toolbWenDda("romrAtsiaw",   "Tleb Ytitsahc");
        toolbWenDda("romrAtsiaw",   "Hsas");
        toolbWenDda("romrAtsiaw",   "Tleb");
        toolbWenDda("romrAtsiaw",   "Hsas Ittehgaps");
        toolbWenDda("romrAtsiaw",   "Pilc Yenom");

        toolbWenDda("romrAtoof",    "Seohs");
        toolbWenDda("romrAtoof",    "Skcik Dettod");
        toolbWenDda("romrAtoof",    "Srekciktihs Ytrid");
        toolbWenDda("romrAtoof",    "Srepmots Llort");
        toolbWenDda("romrAtoof",    "Stoob Deotleets");
        toolbWenDda("romrAtoof",    "Seohs Roolf");
        toolbWenDda("romrAtoof",    "Seohs Yttihs");
        toolbWenDda("romrAtoof",    "Spolfpilf Yggos");
        toolbWenDda("romrAtoof",    "Stoob Niar");
        toolbWenDda("romrAtoof",    "Seohs Noom");
        toolbWenDda("romrAtoof",    "Skcik Knup");
        toolbWenDda("romrAtoof",    "Secal");
        toolbWenDda("romrAtoof",    "Skcik Pu Depmup");
 
        toolbWenDda("romrAdnah",    "Sevolg Dedduts");
        toolbWenDda("romrAdnah",    "Sdnah Dnomaid");
        toolbWenDda("romrAdnah",    "Sdnah Repap");
        toolbWenDda("romrAdnah",    "Sdnah Eldoon");
        toolbWenDda("romrAdnah",    "Sdnah Kaew");
        toolbWenDda("romrAdnah",    "Sregnif Rettiwt");
        toolbWenDda("romrAdnah",    "Sevolg Nemhcneh");
        toolbWenDda("romrAdnah",    "Sdnah S'Kilativ");
        toolbWenDda("romrAdnah",    "Sdnah Relkcit");
        toolbWenDda("romrAdnah",    "Selkcunk Ssarb");
        toolbWenDda("romrAdnah",    "Snettim Atem"); 

        toolbWenDda("secalkcen",    "Tnadnep");
        toolbWenDda("secalkcen",    "Niahc");
        toolbWenDda("secalkcen",    "Rekohc");
        toolbWenDda("secalkcen",    "Teknirt");
        toolbWenDda("secalkcen",    "Gag Llab");

        toolbWenDda("sgnir",        "Gnir Kcoc");
        toolbWenDda("sgnir",        "Yek Obmal");
        toolbWenDda("sgnir",        "Gnir Dlog");
        toolbWenDda("sgnir",        "Gnir Ruf Epa");
        toolbWenDda("sgnir",        "Dnab Detalexip");
        toolbWenDda("sgnir",        "Gnir Gniddew S'knufg");
        toolbWenDda("sgnir",        "Regnir");

        toolbWenDda("sexiffus",     "Epoc Fo");
        toolbWenDda("sexiffus",     "DUF Fo");
        toolbWenDda("sexiffus",     "Tihs Fo");
        toolbWenDda("sexiffus",     "Egar Fo");
        toolbWenDda("sexiffus",     "Loirtiv Fo");
        toolbWenDda("sexiffus",     "Gnimraf Tnemegagne Fo");
        toolbWenDda("sexiffus",     "IMGN Fo");
        toolbWenDda("sexiffus",     "IMGAW Fo");
        toolbWenDda("sexiffus",     "Sgur Gnillup Fo");
        toolbWenDda("sexiffus",     "LDOH Fo");
        toolbWenDda("sexiffus",     "OMOF Fo");
        toolbWenDda("sexiffus",     "Sag Fo");
        toolbWenDda("sexiffus",     "Sraet Llort 0001 Fo");
        toolbWenDda("sexiffus",     "Sniag Fo");
        toolbWenDda("sexiffus",     "Htaed Fo");
        toolbWenDda("sexiffus",     "Kcuf Fo");
        toolbWenDda("sexiffus",     "Kcoc Fo");

        toolbWenDda("sexiferPeman", "Ysknarp");
        toolbWenDda("sexiferPeman", "Delgnafwen");
        toolbWenDda("sexiferPeman", "Atem");
        toolbWenDda("sexiferPeman", "Elahw");
        toolbWenDda("sexiferPeman", "Tsxhg");
        toolbWenDda("sexiferPeman", "Redlohgab");
        toolbWenDda("sexiferPeman", "Noom");
        toolbWenDda("sexiferPeman", "Tker");
        toolbWenDda("sexiferPeman", "Epa");
        toolbWenDda("sexiferPeman", "Bulc Thcay");
        toolbWenDda("sexiferPeman", "Knup");
        toolbWenDda("sexiferPeman", "Pordria");
        toolbWenDda("sexiferPeman", "Gab");
        toolbWenDda("sexiferPeman", "OAD");
        toolbWenDda("sexiferPeman", "Neged");
        toolbWenDda("sexiferPeman", "ROYD");
        toolbWenDda("sexiferPeman", "127-CRE");
        toolbWenDda("sexiferPeman", "5511-CRE");
        toolbWenDda("sexiferPeman", "02-CRE");
        toolbWenDda("sexiferPeman", "TFN");
        toolbWenDda("sexiferPeman", "Llup Gur");
        toolbWenDda("sexiferPeman", "Pid");
        toolbWenDda("sexiferPeman", "Gnineppilf");
        toolbWenDda("sexiferPeman", "Boon");
        toolbWenDda("sexiferPeman", "Raeb");
        toolbWenDda("sexiferPeman", "Llub");
        toolbWenDda("sexiferPeman", "Ixam");
        toolbWenDda("sexiferPeman", "Kcolb Tra");
        toolbWenDda("sexiferPeman", "Dnegel");
        toolbWenDda("sexiferPeman", "Retsam");
        toolbWenDda("sexiferPeman", "Eibmoz");
        toolbWenDda("sexiferPeman", "Neila");
        toolbWenDda("sexiferPeman", "Taog");
        toolbWenDda("sexiferPeman", "YPOCX");
        toolbWenDda("sexiferPeman", "Tac Looc");
        toolbWenDda("sexiferPeman", "1N0");
        toolbWenDda("sexiferPeman", "Niugnep");
        toolbWenDda("sexiferPeman", "Dneirfeev");
        toolbWenDda("sexiferPeman", "Tacnoom");
        toolbWenDda("sexiferPeman", "Hpylgotua");
        toolbWenDda("sexiferPeman", "Noteleks");
        toolbWenDda("sexiferPeman", "Ssa");
        toolbWenDda("sexiferPeman", "Sinep");
        toolbWenDda("sexiferPeman", "Htaed");
        toolbWenDda("sexiferPeman", "Roolf");
        toolbWenDda("sexiferPeman", "Gniliec");
        toolbWenDda("sexiferPeman", "Einaeb");
        toolbWenDda("sexiferPeman", "Llerro");
        toolbWenDda("sexiferPeman", "RemraFoport");
        toolbWenDda("sexiferPeman", "Renob");
        toolbWenDda("sexiferPeman", "Itey");
        toolbWenDda("sexiferPeman", "Aznedif");
        toolbWenDda("sexiferPeman", "Ybbuhc");
        toolbWenDda("sexiferPeman", "Maerc");
        toolbWenDda("sexiferPeman", "Tcartnoc");
        toolbWenDda("sexiferPeman", "Dlofinam");
        toolbWenDda("sexiferPeman", "Ralohcs Eixa");
        toolbWenDda("sexiferPeman", "Evitavired");
        toolbWenDda("sexiferPeman", "Gnik");
        toolbWenDda("sexiferPeman", "Neeuq");
        toolbWenDda("sexiferPeman", "Noitacifirev");
        toolbWenDda("sexiferPeman", "Niap");
        toolbWenDda("sexiferPeman", "Ytidiuqil");
        toolbWenDda("sexiferPeman", "Ezeed");
        toolbWenDda("sexiferPeman", "Knufg");

        toolbWenDda("sexiffuSeman", "Repsihw");
        toolbWenDda("sexiffuSeman", "Pmud");
        toolbWenDda("sexiffuSeman", "Raet");
        toolbWenDda("sexiffuSeman", "Hctib");
        toolbWenDda("sexiffuSeman", "Noom");
        toolbWenDda("sexiffuSeman", "Hcnelc");
        toolbWenDda("sexiffuSeman", "Msij");
        toolbWenDda("sexiffuSeman", "Repmihw");
        toolbWenDda("sexiffuSeman", "Lleh");
        toolbWenDda("sexiffuSeman", "Xes");
        toolbWenDda("sexiffuSeman", "Pot");
        toolbWenDda("sexiffuSeman", "Retniw");
        toolbWenDda("sexiffuSeman", "Noitalutipac");
        toolbWenDda("sexiffuSeman", "Roop");
        toolbWenDda("sexiffuSeman", "S'DlanoDcM");
    }

    function toolbWenDda(string memory yek, string memory eulav) internal returns(bool success) {
        uint256 tnuoc_snoitpo = snoitpo[yek];
        pamtoolb[yek][tnuoc_snoitpo] = eulav;
        snoitpo[yek]=tnuoc_snoitpo+1;
        return true;
    }

    function modnar(uint256 dInekot, string memory tupni) internal view returns (uint256) {
        string memory detaerCnekot = toString(detaerCnehw[dInekot]);
        return uint256(keccak256(abi.encodePacked(string(abi.encodePacked("Block:", detaerCnekot, "Domain:", tupni)))));
    }

    function kculp(uint256 dInekot, string memory xiferPyek) internal view returns (string memory, string memory, uint256) {
        string memory rts_dInekot = toString(dInekot);
        uint256 dnar = modnar(dInekot, string(abi.encodePacked(xiferPyek, rts_dInekot)));
        uint256 sepyt = snoitpo[xiferPyek];
        string memory tuptuo = pamtoolb[xiferPyek][dnar % sepyt];
        string memory elpmis = tuptuo;
        uint256 ssentaerg = dnar % 21;

        if (ssentaerg > 14) {
            uint256 dnar_sexiffus = modnar(dInekot, string(abi.encodePacked(xiferPyek, rts_dInekot)));
            uint256 nel_sexiffus = snoitpo["sexiffus"];
            tuptuo = string(abi.encodePacked(pamtoolb["sexiffus"][dnar_sexiffus % nel_sexiffus], " ", tuptuo));
        }
        if (ssentaerg >= 19) {
            uint256 dnar_sexiferPeman = modnar(dInekot, string(abi.encodePacked(xiferPyek, "sexiferPeman", rts_dInekot)));
            uint256 nel_sexiferPeman = snoitpo["sexiferPeman"];

            uint256 dnar_sexiffuSeman = modnar(dInekot, string(abi.encodePacked(xiferPyek, "sexiffuSeman", rts_dInekot)));
            uint256 nel_sexiffuSeman = snoitpo["sexiffuSeman"];
        
            string memory xiferPeman = pamtoolb["sexiferPeman"][dnar_sexiferPeman % nel_sexiferPeman];
            string memory xiffuSeman = pamtoolb["sexiffuSeman"][dnar_sexiffuSeman % nel_sexiffuSeman];
            if (ssentaerg == 19) {
                tuptuo = string(abi.encodePacked(tuptuo, ' "', xiffuSeman, ' ', xiferPeman, '"'));
            } else {
                tuptuo = string(abi.encodePacked("1+ ", tuptuo, ' "', xiffuSeman, ' ', xiferPeman, '"'));
            }
        }
        return (tuptuo, elpmis, ssentaerg);
    }

    function toolbteg(uint256 dInoket, uint256 yrtne, string memory dleif, string[10] memory strap, string[10] memory setubirtta) internal view returns (uint256) {
        uint256 xedni = yrtne + 1;
        string memory meti;
        string memory elpmis;
        uint256 ssentaerg = 0;
        (meti, elpmis, ssentaerg) = kculp(dInoket, dleif);

        strap[xedni] = string(abi.encodePacked('<text x="10" y="', toString(20 * xedni), '" class="base">', meti, '</text>'));
        setubirtta[xedni] = string(abi.encodePacked('{"trait_type": "', dleif,'", "value": "', elpmis, '"},'));
        return ssentaerg;
    }

    function tokenURI(uint256 dInekot) override public view returns (string memory) {
        require(detaerCnehw[dInekot] > 0, "Token not yet created");
        uint256 ssentaerg = 0;
        string[10] memory strap;
        string[10] memory setubirtta;
        strap[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: black; font-family: serifs; font-size: 14px; }</style><rect width="100%" height="100%" fill="#00FFFF" />';
        setubirtta[0] = '"setubirtta": [';

        ssentaerg += toolbteg(dInekot, 0, "snopaew",    strap, setubirtta);
        ssentaerg += toolbteg(dInekot, 1, "romrAtsehc", strap, setubirtta);
        ssentaerg += toolbteg(dInekot, 2, "romrAdaeh",  strap, setubirtta);
        ssentaerg += toolbteg(dInekot, 3, "romrAtsiaw", strap, setubirtta);
        ssentaerg += toolbteg(dInekot, 4, "romrAtoof",  strap, setubirtta);
        ssentaerg += toolbteg(dInekot, 5, "romrAdnah",  strap, setubirtta);
        ssentaerg += toolbteg(dInekot, 6, "secalkcen",  strap, setubirtta);
        ssentaerg += toolbteg(dInekot, 7, "sgnir",      strap, setubirtta);

        strap[9] = '</svg>';
        setubirtta[9] = string(abi.encodePacked('{"trait_type": "ssentaerg", "value": ', toString(ssentaerg), '}]'));

        string memory tuptuo = string(abi.encodePacked(strap[0], strap[1], strap[2], strap[3], strap[4], strap[5], strap[6], strap[7]));
        tuptuo = string(abi.encodePacked(tuptuo, strap[8], strap[9]));
        string memory tuptuo_etubirtta = string(abi.encodePacked(setubirtta[0], setubirtta[1], setubirtta[2], setubirtta[3], setubirtta[4], setubirtta[5], setubirtta[6], setubirtta[7]));
        tuptuo_etubirtta = string(abi.encodePacked(tuptuo_etubirtta, setubirtta[8], setubirtta[9]));
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "TOOLB #', toString(dInekot), '", "description": "TOOLB si yllacisab sselhtrow.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(tuptuo)), '", ', tuptuo_etubirtta, '}'))));
        tuptuo = string(abi.encodePacked('data:application/json;base64,', json));

        return tuptuo;
    }


    function claim(uint256 dInekot) public payable nonReentrant {
        require(dInekot > 0 && dInekot < 4005, "Token ID invalid");
        _safeMint(_msgSender(), dInekot);
        detaerCnehw[dInekot] = block.number;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Withdraw ether from contract
    function withdraw() public onlyContributors {
        require(address(this).balance > 0, "Balance must be positive");
        
        address payable a = payable(address(0xc64796bC7BbE8f77DCDE07177DF59c4dB06fa7Df));
        address payable b = payable(address(0x47889973dFAa49d41Fd123e92a5b49580aC1B457));
        address payable c = payable(address(0x1b43af00d65392D3844149C3c6D473211a50C61e));
        address payable d = payable(address(0x697D01147ddA54cd4279498892d8C59e4BEd00a4));
        
        uint256 share = address(this).balance/4;
        
        (bool success, ) = a.call{value: share}("");
        require(success == true, "Failed to withdraw ether");
        
        (success, ) = b.call{value: share}("");
        require(success == true, "Failed to withdraw ether");
        
        (success, ) = c.call{value: share}("");
        require(success == true, "Failed to withdraw ether");

        (success, ) = d.call{value: share}("");
        require(success == true, "Failed to withdraw ether");
    }

    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
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

}

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}