pragma solidity 0.8.9;



// Part: Address

// Part: Address

// Part: Address

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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
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

// Part: Base64

// Part: Base64

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

// Part: Context

// Part: Context

// Part: Context

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

// Part: IERC165

// Part: IERC165

// Part: IERC165

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

// Part: IERC721Receiver

// Part: IERC721Receiver

// Part: IERC721Receiver

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// Part: Strings

// Part: Strings

// Part: Strings

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant alphabet = "0123456789abcdef";

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
            buffer[i] = alphabet[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

}

// Part: ERC165

// Part: ERC165

// Part: ERC165

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

// Part: IERC721

// Part: IERC721

// Part: IERC721

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

// Part: Ownable

// Part: Ownable

// Part: Ownable

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

// Part: IERC721Enumerable

// Part: IERC721Enumerable

// Part: IERC721Enumerable

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
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// Part: IERC721Metadata

// Part: IERC721Metadata

// Part: IERC721Metadata

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
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// Part: ERC721

// Part: ERC721

// Part: ERC721

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
    mapping (uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping (address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC721Metadata).interfaceId
            || super.supportsInterface(interfaceId);
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
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        string memory json = ".json";
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, tokenId.toString(), json))
            : '';
    }

    /**
     * @dev Base URI for computing {tokenURI}. Empty by default, can be overriden
     * in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
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
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
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
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private returns (bool)
    {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    // solhint-disable-next-line no-inline-assembly
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
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }
}

// Part: ERC721Enumerable

// Part: ERC721Enumerable

// Part: ERC721Enumerable

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
        return interfaceId == type(IERC721Enumerable).interfaceId
            || super.supportsInterface(interfaceId);
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
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// File: dna.sol

// File: dna.sol

contract DNAContract is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string _tokenURI = "http://pandaparadise.info/GIF/Cloning.gif";
    uint256 constant private LINE_LENGTH = 88;   // what is LINE_LENGTH??

    uint256 constant private DNA_LENGTH = 8;
    uint256 constant private eyeTypeNum = 6;
    uint256 constant private mouthTypeNum = 7;
    uint256 constant private eyebrowTypeNum = 4;
    uint256 constant private noseTypeNum = 4;
    uint256 constant private ladderNum = 3;
    
    /*
    //currently not randomizing the cornea and pupil color
    string[] private CorneaColor = [
        "000000", // black
        "C70039", //red
        "FFC300", //yellow
        "FFFFFF", // white
        "DAF7A6" //green
    ];

    string[] private PupilColor = [
        "000000", // black
        "C70039", //red
        "FFC300", //yellow
        "FFFFFF", // white
        "DAF7A6" //green
    ];
    */

    string [] private neucleotide = [
        "A",
        "T",
        "C",
        "G"
    ];

    string [] private neucleotideComb = [
        "ATCG",
        "ATGC", 
        "ACTG",
        "ACGT",
        "AGTC",
        "AGCT",

        "TACG",
        "TAGC",
        "TCAG",
        "TCGA",
        "TGAC",
        "TGCA",
        
        "CATG",
        "CAGT",
        "CTAG",
        "CTGA",
        "CGTA",
        "CGAT",

        "GATC",
        "GACT",
        "GTAC",
        "GTCA",
        "GCAT",
        "GCTA"
    ];
    
    uint[][] private neucleotideCombIndexed = [
        [0,1,2,3],
        [0,1,3,2],
        [0,2,1,3],
        [0,2,3,1],
        [0,3,1,2],
        [0,3,2,1],

        [1,0,2,3],
        [1,0,3,2],
        [1,2,0,3],
        [1,2,3,0],
        [1,3,0,2],
        [1,3,2,0],

        [2,0,1,3],
        [2,0,3,1],
        [2,1,0,3],
        [2,1,3,0],
        [2,3,0,1],
        [2,3,1,0],
        
        [3,0,1,2],
        [3,0,2,1],
        [3,1,0,2],
        [3,1,2,0],
        [3,2,0,1],
        [3,2,1,0]
    ];
    
    /*
    string[] private LadderColor = [
        "79FF00", //green for A
        "FF0000", //red for T
        "005BFF", //blue for C
        "FFFB00"  //yellow for G
    ];
    */

    string[] private DNAColors = [
        "949398",
        "FC766A",
        "5F4B8B",
        "42EADD",
        "000000",
        "00A4CC",

        "00203F",
        "606060",
        "ED2B33",
        "2C5F2D",
        "00539C",
        "0063B2",
        
        "D198C5",
        "101820",
        "CBCE91",
        "B1624E",
        "89ABE3",
        "E3CD81",
        
        "101820",
        "A07855",
        "195190",
        "603F83",
        "2BAE66",
        "FAD0C9"
    ];

    string[] private DNAColors_ATCG = [
        "809398", "948098",
        "FC906F", "FC908E",
        "5F6B8B", "5F6bcd",
        "80DAAD", "AFDAAD",
        "300000", "303435",
        "60A4CC", "60A48E",

        "33203F", "334B61",
        "806060", "806080",
        "9F2B33", "B64B54",
        "4B972D", "4B976D",
        "50539C", "505361",
        "4763B2", "47637F",
        
        "A298C5", "A298A8",
        "301920", "301850",
        "ADCE91", "ADCE71",
        "81624E", "816269",
        "B7ABE3", "B7ABB8",
        "B3CD81", "B3CD7A",
        
        "631920", "636BCA",
        "7A7855", "787878",
        "3C5190", "3C5167",
        "473F83", "473F52",
        "62AE66", "62AEB4", 
        "BCD0C9", "BCD0C9"
    ];

    //Parametrized function for ladder creation:
    function GenerateLadder(uint256 tokenId) public view returns (string memory) {
        string memory ladderString = '';
        uint8[2] memory color_index = [0, 0];
        uint256[] memory neucleotideIdxArray = generateDNAarray(tokenId);
        uint256 ladderNumTemp = 3*((neucleotideIdxArray[7]%ladderNum) + 1);
        string[3*ladderNum] memory ladder_pos_y = ["150", "400", "650", "90", "330", "590", "210", "470", "710"];
        string[4] memory LadderColor = [
            DNAColors_ATCG[2*neucleotideIdxArray[0]], 
            DNAColors_ATCG[2*neucleotideIdxArray[0]+1],
            DNAColors_ATCG[2*neucleotideIdxArray[1]],
            DNAColors_ATCG[2*neucleotideIdxArray[1]+1]
        ];

        uint i_temp = 0;
        if (ladderNumTemp == 6){
            i_temp = 3;
        }

        for (uint i = 0; i<ladderNumTemp; i++){
            ladderString = string(abi.encodePacked(
                ladderString,
                '<g>',
                    '<path d="M400,',
                    ladder_pos_y[i + i_temp],
                    'l-120,0" style="fill:none;stroke-width:20;stroke:#',
                    LadderColor[neucleotideCombIndexed[neucleotideIdxArray[color_index[0]]][color_index[1]]],
                    '"/>',
                    '<path d="M400,',
                    ladder_pos_y[i + i_temp],
                    'l120,0" style="fill:none;stroke-width:20;stroke:#',
                    LadderColor[neucleotideCombIndexed[neucleotideIdxArray[color_index[0]]][color_index[1] + 1]],
                    '"/>',
                '</g>'
            ));            
            if (color_index[1]==2){
                color_index[0] = color_index[0] + 1;
                color_index[1] = 0;
            }
            else {
                color_index[1] = color_index[1] + 2;
            }
        }
        return ladderString;
    }

    function EyeType(uint256 Idx) public view returns (string memory) {
        string memory eyeString = '';
        
        if (Idx == 0) {
            eyeString = string(abi.encodePacked(
                eyeString, 
                '<g id="Left_eye">',
                    '<ellipse cx="325" cy="400" rx="35" ry="50" style="fill:white;stroke:black;stroke-width:2" />',
                    '<circle cx="325" cy="425" r="25"  style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="320" cy="430" r="8" style="fill:white;stroke:black;stroke-width:1" />',
                    '<circle cx="328" cy="438" r="4" style="fill:white;stroke:black;stroke-width:1" />',
                '</g>',
                '<g id="Right_eye">',   
                    '<ellipse cx="475" cy="400" rx="35" ry="50" style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="475" cy="425" r="25" style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="470" cy="430" r="8" style="fill:white;stroke:black;stroke-width:1" />',
                    '<circle cx="478" cy="438" r="4" style="fill:white;stroke:black;stroke-width:1" />',
                '</g>'
            )); 
        }
        else if (Idx == 1) { 
            eyeString = string(abi.encodePacked(        
                eyeString, 
                '<g id="Left_eye">',
                    '<circle cx="325" cy="400" r="45" style="fill:rgb(40,40,40);stroke:rgb(40,40,40);stroke-width:1" />',
                    '<ellipse cx="325" cy="420" rx="40" ry="27"  style="fill:rgb(120,120,120);stroke:rgb(40,40,40);stroke-width:1" />',
                    '<circle cx="325" cy="400" r="48" style="fill:none;stroke:rgb(230,230,255);stroke-width:6" />',       
                    '<circle cx="328" cy="398" r="35" style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="345" cy="415" r="18" style="fill:white;stroke:white;stroke-width:1" />',
                    '<circle cx="295" cy="375" r="5" style="fill:white;stroke:white;stroke-width:1" />',
                '</g>'
            ));
            eyeString = string(abi.encodePacked(
                eyeString,
                '<g id="Right_eye">',
                    '<circle cx="475" cy="400" r="45" style="fill:rgb(40,40,40);stroke:rgb(40,40,40);stroke-width:1" />',
                    '<ellipse cx="475" cy="420" rx="40" ry="27"  style="fill:rgb(120,120,120);stroke:rgb(40,40,40);stroke-width:1" />',
                    '<circle cx="475" cy="400" r="48" style="fill:none;stroke:rgb(230,230,255);stroke-width:6" />',       
                    '<circle cx="478" cy="398" r="35" style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="495" cy="415" r="18" style="fill:white;stroke:white;stroke-width:1" />',
                    '<circle cx="445" cy="375" r="5" style="fill:white;stroke:white;stroke-width:1" />',
                '</g>'
            ));
        }        
        else if (Idx == 2) { 
            eyeString = string(abi.encodePacked(        
                eyeString, 
                '<g id="Left_eye">',
                    '<path d="M278,420 l0,-20 a1,1 0 0,1 94,0 l0,20 a10,1 0 0,1 -94,0" style="fill:rgb(40,40,40);stroke:rgb(40,40,40);stroke-width:1" />',
                    '<ellipse cx="335" cy="400" rx="40" ry="25"  style="fill:rgb(120,120,120);stroke:rgb(120,120,120);stroke-width:1" />',
                    '<path d="M275,420 l0,-20 a1,1 0 0,1 100,0 l0,20 a10,1 0 0,1 -100,0" style="fill:none;stroke:rgb(230,230,255);stroke-width:6" />',      
                    '<circle cx="325" cy="385" r="30" style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="350" cy="385" r="15" style="fill:white;stroke:white;stroke-width:1" />',
                    '<circle cx="295" cy="375" r="5" style="fill:white;stroke:white;stroke-width:1" />',
                '</g>'
            ));
            eyeString = string(abi.encodePacked(
                eyeString,
                '<g id="Right_eye">',
                    '<path d="M428,420 l0,-20 a1,1 0 0,1 94,0 l0,20 a10,1 0 0,1 -94,0" style="fill:rgb(40,40,40);stroke:rgb(40,40,40);stroke-width:1" />',
                    '<ellipse cx="485" cy="400" rx="40" ry="25"  style="fill:rgb(120,120,120);stroke:rgb(120,120,120);stroke-width:1" />',
                    '<path d="M425,420 l0,-20 a1,1 0 0,1 100,0 l0,20 a10,1 0 0,1 -100,0" style="fill:none;stroke:rgb(230,230,255);stroke-width:6" />',
                    '<circle cx="475" cy="385" r="30" style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="500" cy="385" r="15" style="fill:white;stroke:white;stroke-width:1" />',
                    '<circle cx="445" cy="375" r="5" style="fill:white;stroke:white;stroke-width:1" />',
                '</g>'
            ));
        }        
        else if (Idx == 3) { 
            eyeString = string(abi.encodePacked(        
                eyeString,
                '<g id="Left_eye">',        
                    '<path d="M290,375 q35,-40 70,0" style="fill:none;stroke-width:18;stroke:black" />',
                '</g>',
                '<g id="Right_eye">',
                    '<path d="M440,375 q35,-40 70,0" style="fill:none;stroke-width:18;stroke:black" />',
                '</g>'
            ));
        }          
        else if (Idx == 4) { 
            eyeString = string(abi.encodePacked(        
                eyeString,
                '<g id="Left_eye">',       
                    '<path d="M290,375 q35,40 70,0" style="fill:none;stroke-width:18;stroke:black" />',
                '</g>',
                '<g id="Right_eye">',
                    '<path d="M440,375 q35,40 70,0" style="fill:none;stroke-width:18;stroke:black" />',
                '</g>'
            ));
        }   
        else if (Idx == 5) { 
            eyeString = string(abi.encodePacked(        
                eyeString,
                '<g id="Left_eye">',
                    '<path d="M300,365 l50,25" style="fill:none;stroke:black;stroke-width:15" />',
                    '<path d="M300,415 l50,-25" style="fill:none;stroke:black;stroke-width:15" />',
                    '<circle cx="348" cy="390" r="8" style="fill:black;stroke:black;stroke-width:1" />',
                '</g>',
                '<g id="Right_eye">',
                    '<path d="M428,420 l0,-20 a1,1 0 0,1 94,0 l0,20 a10,1 0 0,1 -94,0" style="fill:rgb(40,40,40);stroke:rgb(40,40,40);stroke-width:1" />',
                    '<ellipse cx="485" cy="400" rx="40" ry="25"  style="fill:rgb(120,120,120);stroke:rgb(120,120,120);stroke-width:1" />',
                    '<path d="M425,420 l0,-20 a1,1 0 0,1 100,0 l0,20 a10,1 0 0,1 -100,0" style="fill:none;stroke:rgb(230,230,255);stroke-width:6" />',      
                    '<circle cx="475" cy="385" r="30" style="fill:black;stroke:black;stroke-width:1" />',
                    '<circle cx="500" cy="385" r="15" style="fill:white;stroke:white;stroke-width:1" />',
                    '<circle cx="445" cy="375" r="5" style="fill:white;stroke:white;stroke-width:1" />',
                '</g>'
            ));
        }
        return eyeString;
    }

    function MouthType(uint256 Idx) public view returns (string memory) {
        string memory mouthString = '';
        
        if (Idx == 0) {
            mouthString = string(abi.encodePacked(
                mouthString,
                '<g id="Mouth">',
                    '<ellipse cx="400" cy="505" rx="35" ry="40" style="fill:black;stroke:black;stroke-width:2" />',
                '</g>'
            ));
        }
        else if (Idx == 1) {
            mouthString = string(abi.encodePacked(
                mouthString,
                '<g id="Mouth">',
                    '<path d="M375,490 a1,1 0 0,1 50,0 l0,15 a1,1 0 0,1 -50,0 l0,-15" style="fill:black;stroke:black;stroke-width:2" />',
                '</g>'
            ));
        }
        else if (Idx == 2) {
            mouthString = string(abi.encodePacked(
                mouthString,
                '<g id="Mouth">',
                    '<path d="M370,490 l0,10 a1,1 0 1,0 60,0 l0,-10 a4,1 0 1,0 -60,0" style="fill:black;stroke:black;stroke-width:1" />',
                    '<ellipse cx="400" cy="515" rx="22" ry="12" style="fill:rgb(250, 150, 170); stroke:rgb(250, 150, 170); stroke-width:1" />',
                '</g>'
            ));
        }
        else if (Idx == 3) {
            mouthString = string(abi.encodePacked(
                mouthString,
                '<g id="Mouth">',
                    '<path d="M360,490 q40,40 80,0" style="fill:none;stroke-width:18;stroke:black" />',
                '</g>'
            ));
        }
        else if (Idx == 4) {
            mouthString = string(abi.encodePacked(
                mouthString,
                '<g id="Mouth">',
                    '<path d="M380,500 a2,3 0 1,0 40,0" style="fill:rgb(250, 150, 170); stroke:rgb(250, 150, 170); stroke-width:1" />',
                    '<path d="M350,490 q25,25 50,0 q25,25 50,0" style="fill:none;stroke-width:15;stroke:black" />',
                '</g>'
            ));
        }
        else if (Idx == 5) {
            mouthString = string(abi.encodePacked(
                mouthString,
                '<g id="Mouth">',
                    '<ellipse cx="400" cy="500" rx="50" ry="35" style="fill:black;stroke:black;stroke-width:2" />',
                '</g>'
            ));
        }
        else if (Idx == 6) {
            mouthString = string(abi.encodePacked(
                mouthString,
                '<g id="Mouth">',
                    '<ellipse cx="400" cy="500" rx="50" ry="35" style="fill:black;stroke:black;stroke-width:2" />',
                    '<ellipse cx="400" cy="515" rx="40" ry="18" style="fill:rgb(250, 150, 170); stroke:rgb(250, 150, 170); stroke-width:1" />',
                '</g>'
            ));
        }
        return mouthString;
    }
    
    function EyebrowType(uint256 Idx) public view returns (string memory) {
        string memory eyebrowString = '';
        
        if (Idx == 0) {
            eyebrowString = string(abi.encodePacked(
                eyebrowString,
                '<g id="Left_eyebrow">',
                    '<path stroke-linecap="round" d="M300,330 q30,-30 50,-20" style="fill:none;stroke-width:15;stroke:black" />',
                '</g>',
                '<g id="Right_eyebrow">',
                    '<path stroke-linecap="round" d="M500,330 q-30,-30 -50,-20" style="fill:none;stroke-width:15;stroke:black" />',
                '</g>'
            )); 
        }
        else if (Idx == 1) { 
            eyebrowString = string(abi.encodePacked(        
                eyebrowString,
                '<g id="Left_eyebrow">',
                    '<path d="M290,340 q60,-10 70,-30 q-25,-20 -70,30" style="fill:black;stroke-width:1;stroke:black" />',
                '</g>',
                '<g id="Right_eyebrow">',        
                    '<path d="M510,340 q-60,-10 -70,-30 q25,-20 70,30" style="fill:black;stroke-width:1;stroke:black" />',
                '</g>'
            ));
        }
        else if (Idx == 2) { 
            eyebrowString = string(abi.encodePacked(        
                eyebrowString,
                '<g id="Left_eyebrow">',
                    '<path d="M290,340 q60,-35 70,-30 q-30,-30 -70,30" style="fill:black;stroke-width:1;stroke:black" />',
                '</g>',                
                '<g id="Right_eyebrow">',      
                    '<path d="M510,340 q-60,-35 -70,-30 q30,-30 70,30" style="fill:black;stroke-width:1;stroke:black" />',
                '</g>'
            ));
        }        
        else if (Idx == 3) { 
            eyebrowString = string(abi.encodePacked(        
                eyebrowString,
                '<g id="Left_eyebrow">',
                    '<path d="M290,330 q60,-20 70,-40 q-10,50 -70,40" style="fill:black;stroke-width:1;stroke:black" />',
                '</g>',               
                '<g id="Right_eyebrow">',    
                    '<path d="M510,330 q-60,-20 -70,-40 q10,50 70,40" style="fill:black;stroke-width:1;stroke:black" />',
                '</g>'
            ));
        }
        return eyebrowString;
    }
    
    /*
    function NoseType(uint256 Idx) public view returns (string memory) {
        string memory noseString = '';
        
        if (Idx == 0) {
            noseString = string(abi.encodePacked(
                noseString,
                '<g id="Nose">',
                    '<ellipse cx="400" cy="450" rx="25" ry="15" style="fill:black;stroke:black;stroke-width:2" />',
                    '<ellipse cx="415" cy="448" rx="8" ry="5" style="fill:white;stroke:black;stroke-width:1" />',
                '</g>'
            )); 
        }
        else if (Idx == 1) { 
            noseString = string(abi.encodePacked(        
                noseString,
                '<g id="Nose">',
                    '<path d="M400,475 q25,-15 25,-30 q-25,-10 -50,0 q0,15 25,30" style="fill:black;stroke-width:1;stroke:black" />',
                '</g>'
            ));
        }
        else if (Idx == 2) { 
            noseString = string(abi.encodePacked(        
                noseString,
                '<g id="Nose">',                
                    '<path d="M370,440 q30,-30 60,0 q10,15 -5,30 q-10,5 -25,0 q-15,5 -25,0 q-15,-15 -5,-30z" style="fill:black;stroke:black;stroke-width:1" />',          
                    '<ellipse cx="385" cy="450" rx="8" ry="10" style="fill:white;stroke:none;stroke-width:1" />',
                    '<ellipse cx="415" cy="450" rx="8" ry="10" style="fill:white;stroke:none;stroke-width:1" />',
                '</g>'
            ));
        }        
        else if (Idx == 3) { 
            noseString = string(abi.encodePacked(        
                noseString,
                '<g id="Nose">',                
                    '<path d="M370,440 q30,-30 60,0 q10,15 0,30 q-30,30 -60,0 q-10,-15 0,-30z" style="fill:black;stroke:black;stroke-width:1" />',          
                    '<ellipse cx="385" cy="455" rx="8" ry="12" style="fill:white;stroke:none;stroke-width:1" />',
                    '<ellipse cx="415" cy="455" rx="8" ry="12" style="fill:white;stroke:none;stroke-width:1" />',
                '</g>'
            ));
        }
        return noseString;
    } 
    */ 
    
    function seededRandom(string memory seed, string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, input)));       // random number generated based on seed and input
    }

    function generateLineOfText(string memory text) internal pure returns (string memory) {
        bytes memory result = new bytes(LINE_LENGTH);
        bytes memory input = bytes(text);
        for (uint256 i = 0; i < LINE_LENGTH; i++) {
            result[i] = input[i % input.length];
        }
        return string(result);
    }
    
    function generateDNA(uint256 tokenId) public view returns (string memory) {
        string memory tokenIdStr = tokenId.toString();
        uint256 startNeucleotideIdx = seededRandom(tokenIdStr, "0") % neucleotideComb.length;
        string memory output = neucleotideComb[startNeucleotideIdx]; 
        //string memory output = startNeucleotideIdx.toString();
        for (uint256 i = 1; i < DNA_LENGTH; i ++) {
            string memory idxStr = i.toString(); 
            
            uint256 addNeucleotideIdx = seededRandom(tokenIdStr, idxStr) % neucleotideComb.length;
            //output = string(abi.encodePacked(output, addNeucleotideIdx.toString()));
            output = string(abi.encodePacked(output, neucleotideComb[addNeucleotideIdx]));
        }
        return output;
    } 

    function generateDNAarray(uint256 tokenId) public view returns (uint256[] memory) {
        string memory tokenIdStr = tokenId.toString();
        uint256[] memory neucleotideIdxArray = new uint[](DNA_LENGTH);
        uint256 startNeucleotideIdx = seededRandom(tokenIdStr, "0") % neucleotideComb.length;
        neucleotideIdxArray[0] = startNeucleotideIdx;
        //string memory output = neucleotideComb[startNeucleotideIdx]; 
        string memory output = startNeucleotideIdx.toString();
        for (uint256 i = 1; i < DNA_LENGTH; i ++) {
            string memory idxStr = i.toString(); 
            
            uint256 addNeucleotideIdx = seededRandom(tokenIdStr, idxStr) % neucleotideComb.length;
            output = string(abi.encodePacked(output, addNeucleotideIdx.toString()));
            //output = string(abi.encodePacked(output, neucleotideComb[addNeucleotideIdx]));
            neucleotideIdxArray[i] = addNeucleotideIdx;
        }
        return neucleotideIdxArray;
    }

    function st2num(string memory numString) public pure returns(uint) {
        uint  val=0;
        bytes memory stringBytes = bytes(numString);
        for (uint  i =  0; i<stringBytes.length; i++) {
            uint exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
           uint jval = uval - uint(0x30);
   
           val +=  (uint(jval) * (10**(exp-1))); 
        }
      return val;
    }

    /*
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        uint256 supply = totalSupply();
        string memory output;

        if (supply < 0) {
            output = _tokenURI;
        } else {
            //require(totalSupply >= 420, "All tokens not minted.");
            require(tokenId < 420, "Invalid token ID");
            string memory tokenIdStr = tokenId.toString();
            uint256 beTextIndex = seededRandom("BE-TEXT", tokenIdStr) % text_options.length;    // secondary term (small text)
            uint256 feTextIndex = seededRandom("FE-TEXT", tokenIdStr) % text_options.length;    // main term (big text)
            uint256 colorIndex = seededRandom("color", tokenIdStr) % color_options.length;      // color
            uint256 rotateIndex = seededRandom("rotate", tokenIdStr) % rotate_options.length;   // rotation  

            string memory lineOfText = generateLineOfText(text_options[beTextIndex]);
            
            
            output = '';
            output = string(abi.encodePacked(
                output, 
                '<svg preserveAspectRatio="xMinYMin meet" viewBox="0 0 800 800" ',  
                    'xmlns="http://www.w3.org/2000/svg" version="1.1">', 
                    '<g stroke="green">', 
                        '<line x1= "', 
                        rotate_options[0], 
                        '" y1="0" x2="50" y2="800" ', 
                        'stroke-width="5" />', 
                    '</g>', 
                '</svg>' 
            ));
                        
            string memory attributes = string(abi.encodePacked('[{"trait_type":"Main Term","value":"', text_options[feTextIndex],       // main term
                '"},{"trait_type":"Secondary Term","value":"', text_options[beTextIndex],       // bg term
                '"},{"trait_type":"Rotation","value":"', rotate_options[rotateIndex],       // rotate 
                '"},{"trait_type":"Font Color","value":"', color_options[colorIndex],       // font color
                '"},{"trait_type":"BG Color","value":"', bg_color_options[colorIndex],      // bg color
                '"}]'));
            string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "GM420 #', tokenIdStr,
                '", "description": "GM420 is a fully on-chain set of NFTs representing the Lingo that leads the NFT movement. 420 unique pieces of the different terms we all use everyday. The NFTs are fully created on-chain, during minting, and are all unique with basic traits such as Main Term, Secondary Term, Rotation, Font Color and BG Color. Owners of these NFTs will be the first to receive PUGS tokens when they are released.", "image": "data:image/svg+xml;base64,',
                Base64.encode(bytes(output)),
                '","attributes": ', attributes,
                '}'))));
            output = string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(bytes(output))));
        }

        return output;
    }*/

    function tokenURIDNA(uint256 tokenId) public view returns (string memory) {
        uint256 supply = totalSupply();
        string memory output;

        if (supply < 0) {
            output = _tokenURI;
        } else {
            //require(totalSupply >= 420, "All tokens not minted.");
            require(tokenId < 420, "Invalid token ID");
            uint256[] memory neucleotideIdxArray = generateDNAarray(tokenId);     

            
            output = '';

            //Initializing svg file
            //defining the colors for strands and shadow for strands
            output = string(abi.encodePacked(
                output, 
                    '<svg preserveAspectRatio="xMinYMin meet" viewBox="0 0 800 800" ',  
                        'xmlns:xlink="http://www.w3.org/1999/xlink" xmlns="http://www.w3.org/2000/svg">', 
                        '<style>',
                            '.color_1{stop-color:#', 
                            DNAColors[neucleotideIdxArray[0]],              // taking first element of dna for first color
                            ';stop-opacity:1}',
                            '.color_2{stop-color:#', 
                            DNAColors[neucleotideIdxArray[1]],
                            ';stop-opacity:1}',
                            '.color_3{fill:none;stroke-width:18;stroke:#',
                            DNAColors[neucleotideIdxArray[2]],      
                            '}',                     
                        '</style>'
            ));
            
            /*
            //randomizing color for cornea and pupil
            //currently not using this in the function of EyeType
            output = string(abi.encodePacked(
                output, 
                    '<style>',
                        '.corneaColor{fill:#', 
                        CorneaColor[neucleotideIdxArray[3]%CorneaColor.length],              // taking first element of dna for first color
                        ';stroke:#',
                        CorneaColor[neucleotideIdxArray[4]%CorneaColor.length],              // taking first element of dna for first color
                        '; stroke-width:2}'
                        '.pupilColor{fill:#', 
                        PupilColor[neucleotideIdxArray[5]%CorneaColor.length],              // taking first element of dna for first color
                        ';stroke:#',
                        PupilColor[neucleotideIdxArray[6]%CorneaColor.length],              // taking first element of dna for first color
                        '; stroke-width:1}',                       
                    '</style>'
            ));
            */

            //defining color gradient for the strands
            output = string(abi.encodePacked(
                output,   
                        '<defs>',
                            '<linearGradient id="grad1" x1="0%" y1="0%" x2="0%" y2="100%">',
                                '<stop offset="0%" class="color_1" />',
                                '<stop offset="100%" class="color_2" />',
                            '</linearGradient>',
                        '</defs>',
                        '<defs>',
                            '<linearGradient id="grad2" x1="0%" y1="0%" x2="0%" y2="100%">',
                                '<stop offset="0%" class="color_2" />',
                                '<stop offset="100%" class="color_1" />',
                            '</linearGradient>',
                        '</defs>',
                        '<style>',
                            '.style_strand_1{fill:none;stroke-width:30;stroke:url(#grad1)}',
                            '.style_strand_2{fill:none;stroke-width:30;stroke:url(#grad2)}',
                        '</style>'
            ));

            //Calling Ladder creation function
            output = string(abi.encodePacked(
                output, 
                GenerateLadder(tokenId)
            ));

            //DNA strand
            output = string(abi.encodePacked(
                output,                     
                        '<g id="Right_strand">',
                            '<path d="M525,50 q0,200 -125,210" class="style_strand_1" />',
                            '<path d="M400,260 q-125,10 -125,140" class="style_strand_2" />',
                            '<path d="M275,400 q0,130 125,140" class="style_strand_1" />',
                            '<path d="M400,540 q125,10 125,210" class="style_strand_2" />',
                        '</g>',
                        '<g id="Left_strand">',
                            '<path d="M275,50 q0,200 125,210" class="style_strand_1" />',
                            '<path d="M400,260 q125,10 125,140" class="style_strand_2" />',
                            '<path d="M525,400 q0,130 -125,140" class="style_strand_1" />',
                            '<path d="M400,540 q-125,10 -125,210" class="style_strand_2" />',
                        '</g>'
            ));

            //DNA strand overlap
            output = string(abi.encodePacked(
                output, 
                        '<g id="Right_strand_overlap">',
                            '<path d="M550,50 q0,200 -125,210" class="style_strand_1" />',
                            '<path d="M425,260 q-125,10 -125,140" class="style_strand_2" />',
                            '<path d="M300,400 q0,130 125,140" class="style_strand_1" />',    
                            '<path d="M425,540 q125,10 125,210" class="style_strand_2" />',
                        '</g>',                        
                        '<g id="Right_strand_overlap">',
                            '<path d="M250,50 q0,200 125,210" class="style_strand_1" />',
                            '<path d="M375,260 q125,10 125,140" class="style_strand_2" />',
                            '<path d="M500,400 q0,130 -125,140" class="style_strand_1" />',
                            '<path d="M375,540 q-125,10 -125,210" class="style_strand_2" />',
                        '</g>'
            ));

            //Eye of the DNA
            output = string(abi.encodePacked(
                output, 
                EyeType(neucleotideIdxArray[3]%eyeTypeNum)
            ));

            //Mouth of the DNA
            output = string(abi.encodePacked(
                output, 
                MouthType(neucleotideIdxArray[4]%mouthTypeNum)
            ));
            
            //Eyebrow of the DNA
            output = string(abi.encodePacked(
                output, 
                EyebrowType(neucleotideIdxArray[5]%eyebrowTypeNum)
            ));
            
            //Nose of the DNA
            /*
            output = string(abi.encodePacked(
                output, 
                NoseType(neucleotideIdxArray[6]%noseTypeNum)
            ));
            */

            //shodow for the strands
            output = string(abi.encodePacked(
                output, 
                        '<g id="Left_strand_shadow">',
                            '<path stroke-linecap="round" d="M262.5,80 q0,25 7.5,50" class="color_3" />',                            
                            '<path stroke-linecap="round" d="M278,160 q0,0 4,10" class="color_3" />',
                            '<path stroke-linecap="round" d="M262.5,720 q0,-25 7.5,-50" class="color_3" />',                                    
                            '<path stroke-linecap="round" d="M278,640 q0,0 4,-10" class="color_3" />',
                        '</g>',
                        '<g id="Right_strand_shadow">',
                            '<path stroke-linecap="round" d="M537.5,80 q0,25 -7.5,50" class="color_3" />',                            
                            '<path stroke-linecap="round" d="M522,160 q0,0 -4,10" class="color_3" />',
                            '<path stroke-linecap="round" d="M537.5,720 q0,-25 -7.5,-50" class="color_3" />',                                    
                            '<path stroke-linecap="round" d="M522,640 q0,0 -4,-10" class="color_3" />',
                        '</g>',
                    '</svg>'
            ));  
            
            output = string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(bytes(output))));
        }
        return output;
    }

    function claim(uint256 num) public {
        uint256 supply = totalSupply();
        // require( num < 2,                              "You can mint a maximum of 1 piece per tx" );
        require( supply + num - 1 < 420,               "Exceeds maximum supply" );
        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }      
    }

    function claimOwner(uint256 num) public onlyOwner {
        // require( num < 2,                              "You can mint a maximum of 1 piece per tx" );
        uint256 supply = totalSupply();
        require( supply + num - 1 < 420,                  "Exceeds maximum supply" );
        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    constructor() ERC721("DNA", "DNA") Ownable() {}

}