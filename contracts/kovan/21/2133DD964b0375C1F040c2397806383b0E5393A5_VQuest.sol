/**
 *Submitted for verification at Etherscan.io on 2022-01-08
*/

pragma solidity ^0.8.0;

/* Local Imports */
/* import '../utils/openzeppelin-contracts/contracts/token//ERC721/extensions/ERC721URIStorage.sol';
import '../utils/openzeppelin-contracts/contracts/token//ERC721/extensions/ERC721Enumerable.sol';
import '../utils/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol';
import '../utils/openzeppelin-contracts/contracts/access/Ownable.sol'; */

/* IMPORTS */

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;

        _;
        _status = _NOT_ENTERED;
    }
}

library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    function toString(uint256 value) internal pure returns (string memory) {

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

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }


    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

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
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

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
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
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

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
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
        _setApprovalForAll(_msgSender(), operator, approved);
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
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
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
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
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
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
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
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
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
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
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
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

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
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
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


/* DONE IMPORTS */

contract VQuest is ERC721Enumerable, ReentrancyGuard, Ownable {

  /* EARN VGOLD */
  /* PVP */
  /* PVE ONCE A WEEK TO MINT NEW ONES */

  string[] private guildArray = [
      "Thief",
      "Knight",
      "Templar",
      "Mage",
      "Merchant"
  ];

  string[] private classArray = [
      "Thief",
      "Knight",
      "Templar",
      "Mage",
      "Merchant"
      /* new classes below, left field but I think the names are cool*/
      "Leponite"
      "Grelitian"
      "Varizci"
      "Haddza"
      "Naasaii"

  ];

  string[] private weaponArray = [
    "Greatsword",
    "Longsword",
    "Dagger",
    "Staff",
    "Fist",
    "Hammer",
    "Mace",
    "Straight Sword"
    /* new weapons below */
  ];

  string[] private armorArray = [
    "Demon",
    "Thief",
    "Hollow Thief",
    "Knight",
    "Mage"
  ];

  string[] private ringArray = [
    "Curse",
    "Blessing"
  ];

  string[] private suffixes = [
      "of Power",
      "of Hollowness",
      "of Bewilderment",
      "of Skill",
      "of an Alternate Reality",
      "of Brilliance",
      "of Enlightenment",
      "of Valor",
      "of Resentment",
      "of Rage",
      "of Fury",
      "of Belittlement",
      "of the Visionary",
      "of Benevolence",
      "of Reflection",
      "of Zen"
  ];

  string[] private namePrefixes = [
      "Agony", "Apocalypse", "Armageddon", "Beast", "Behemoth", "Blight", "Blood", "Bramble",
      "Brimstone", "Brood", "Carrion", "Cataclysm", "Chimeric", "Corpse", "Corruption", "Damnation",
      "Death", "Demon", "Dire", "Dragon", "Dread", "Doom", "Dusk", "Eagle", "Empyrean", "Fate", "Foe",
      "Gale", "Ghoul", "Gloom", "Glyph", "Golem", "Grim", "Hate", "Havoc", "Honour", "Horror", "Hypnotic",
      "Kraken", "Loath", "Maelstrom", "Mind", "Miracle", "Morbid", "Oblivion", "Onslaught", "Pain",
      "Pandemonium", "Phoenix", "Plague", "Rage", "Rapture", "Rune", "Skull", "Sol", "Soul", "Sorrow",
      "Spirit", "Storm", "Tempest", "Torment", "Vengeance", "Victory", "Viper", "Vortex", "Woe", "Wrath",
      "Light's", "Shimmering"
  ];

  string[] private nameSuffixes = [
      "Bane",
      "Root",
      "Bite",
      "Song",
      "Roar",
      "Grasp",
      "Instrument",
      "Glow",
      "Bender",
      "Shadow",
      "Whisper",
      "Shout",
      "Growl",
      "Tear",
      "Peak",
      "Form",
      "Sun",
      "Moon"
  ];

  struct Weapon {
    string name;
    uint256 greatness;
  }

  struct Armor {
    string name;
    uint256 greatness;
  }

  struct Ring {
    string name;
    string boostStat;
    uint256 greatness;
  }

  /* struct Potion {
    string name;
    string potionEffect;
  }

  struct Item {
    string name;
    string itemEffect;
  }
  uint private potionPointer = 0;
  uint private potionCount = 1;

  uint private itemPointer = 0;
  uint private itemCount = 1;
  mapping (uint => Potion) public potions;
  mapping (uint => Item) public items;
  potions[0] = pluck(tokenId, 'POTION', chestArmor)
  items[0] = pluck(tokenId, 'ITEM', chestArmor) */

  uint private randNonce ;
  uint public tokenCounter;
  string public baseURI;

  uint16 [] private vqLevels = [1,2,3,4,5];
  string [] private statuses = ['dead', 'resting'];
  string [] private statArray = ['attack', 'defense'];

  /* Static - store on NTFS */
  /* uint public level = 0; */
  /* mapping (uint => uint) public vqLevel; */

  /* Dynamic */
  mapping (uint => uint) public vqHealth;
  mapping (uint => string) public vqStatus;

  mapping (uint => uint) public vqEquippedWeapon;
  mapping (uint => Weapon[]) public vqWeapons;

  mapping (uint => uint) public vqEquippedArmor;
  mapping (uint  => Armor[]) public vqArmor;

  mapping (uint => uint) public vqEquippedRing;
  mapping (uint => Ring[]) public vqRings;

  function random(string memory input) internal pure returns (uint256) {
      return uint256(keccak256(abi.encodePacked(input)));
  }

  function randMod(uint _modulus) internal returns(uint) {
    // increase nonce
    randNonce++;
    return uint(keccak256(abi.encodePacked(block.timestamp,
      msg.sender,
      randNonce))) % _modulus;
  }

  function setHealth(uint tokenId, uint256 health) private {
    vqHealth[tokenId] = health;
  }

  function getHealth(uint tokenId) public view returns (uint health) {
    return vqHealth[tokenId];
  }

  function getStatus(uint tokenId) public view returns (string memory status) {
    return vqStatus[tokenId];
  }

  function getAttack(uint tokenId) public view returns (uint attack) {
    return equippedWeapon(tokenId).greatness;
  }

  function getDefense(uint tokenId) public view returns (uint defense) {
    return equippedArmor(tokenId).greatness;
  }

  function equippedWeapon(uint tokenId) public view returns (Weapon memory weapon) {
    return vqWeapons[tokenId][vqEquippedWeapon[tokenId]];
  }

  function equippedArmor(uint tokenId) public view returns (Armor memory armor) {
    return vqArmor[tokenId][vqEquippedArmor[tokenId]];
  }

  function equippedRing(uint tokenId) public view returns (Ring memory ring) {
    return vqRings[tokenId][vqEquippedRing[tokenId]];
  }

  function getWeapons(uint tokenId) public view returns (Weapon[] memory weapon) {
    return vqWeapons[tokenId];
  }

  function getArmor(uint tokenId) public view returns (Armor[] memory armor) {
    return vqArmor[tokenId];
  }

  function getRings(uint tokenId) public view returns (Ring[] memory ring) {
    return vqRings[tokenId];
  }

  function getClass(uint tokenId) public view returns (string memory class) {
      return pluck(tokenId, 'CLASS', classArray);
  }

  function getGuild(uint tokenId) public view returns (string memory guild) {
      return pluck(tokenId, 'GUILD', guildArray);
  }

  function getLevel(uint tokenId) public view returns (uint16 level) {
    uint256 rand = random(string(abi.encodePacked('LEVEL', toString(tokenId))));
    return vqLevels[rand % vqLevels.length];
  }

  function findWeapon(uint tokenId) public onlyOwner nonReentrant {
    vqWeapons[tokenId].push(pluckWeapon());
  }

  function findArmor(uint tokenId) public onlyOwner nonReentrant {
    vqArmor[tokenId].push(pluckArmor());
  }

  function findRing(uint tokenId) public onlyOwner nonReentrant {
    vqRings[tokenId].push(pluckRing());
  }

  /* function getWeapons(uint tokenId) public view returns (string memory weapons) {
    string memory ret = weapons[weaponPointer].name;
    for (uint j = weaponPointer + 1; j < weaponCount; j += 1) {
      ret = string(abi.encodePacked(ret, ', ', weapons[j].name));
    }
    return 'ret';
  } */

  /* function getArmor(uint tokenId) public view returns (string memory armor) {
    string memory ret = armor[armorPointer].name;
    for (uint j = armorPointer + 1; j < armorCount; j += 1) {
      ret = string(abi.encodePacked(ret, ', ', armor[j].name));
    }
    return 'ret';
  } */

  /* function getRings(uint tokenId) public view returns (string memory rings) {
    string memory ret = rings[ringPointer].name;
    for (uint j = ringPointer + 1; j < ringCount; j += 1) {
      ret = string(abi.encodePacked(ret, ', ', rings[j].name));
    }
    return 'ret';
  } */

  function equipWeapon(uint tokenId, uint weaponPointer) public onlyOwner nonReentrant {
    equipCore(tokenId, weaponPointer, vqEquippedWeapon[tokenId], vqWeapons[tokenId].length);
    vqEquippedWeapon[tokenId] = weaponPointer;
  }

  function equipArmor(uint tokenId, uint armorPointer) public onlyOwner nonReentrant {
    equipCore(tokenId, armorPointer, vqEquippedArmor[tokenId], vqArmor[tokenId].length);
    vqEquippedArmor[tokenId] = armorPointer;
  }

  function equipRing(uint tokenId, uint ringPointer) public onlyOwner nonReentrant {
    equipCore(tokenId, ringPointer, vqEquippedRing[tokenId], vqRings[tokenId].length);
    vqEquippedRing[tokenId] = ringPointer;
  }

  function equipCore(uint tokenId, uint newEquipPointer, uint currentEquipPointer, uint numEquipment) public onlyOwner nonReentrant {
    require(newEquipPointer != currentEquipPointer, 'Already equipped!');
    require(newEquipPointer >= 0 && newEquipPointer < numEquipment, 'Equipment does not exist!');
  }

  function getEquipment(uint tokenId) public view returns (string memory) {
    return string(abi.encodePacked(equippedWeapon(tokenId).name, ' ', equippedArmor(tokenId).name, ' ', equippedRing(tokenId).name));
  }

  function pluckWeapon() internal returns (Weapon memory) {
    uint rand = getRandom();
    Weapon memory w;
    w.greatness = rand % 100;
    w.name = getNamed(weaponArray[rand % weaponArray.length], w.greatness, rand);
    return w;
  }

  function pluckArmor() internal returns (Armor memory) {
    uint rand = getRandom();
    Armor memory a;
    a.greatness = rand % 100;
    a.name = getNamed(armorArray[rand % armorArray.length], a.greatness, rand);
    return a;
  }

  function pluckRing() internal returns (Ring memory) {
    uint rand = getRandom();
    Ring memory r;
    r.greatness = rand % 100;
    r.name = getNamed(ringArray[rand % ringArray.length], r.greatness, rand);
    r.boostStat = statArray[rand % statArray.length];
    return r;
  }

  function pluck(uint tokenId, string memory keyPrefix, string[] memory sourceArray) internal view returns (string memory) {
      uint256 rand = random(string(abi.encodePacked(keyPrefix, toString(tokenId))));
      string memory output = sourceArray[rand % sourceArray.length];
      uint256 greatness = rand % 21;
      if (greatness > 14) {
          output = string(abi.encodePacked(output, ' ', suffixes[rand % suffixes.length]));
      }
      if (greatness >= 19) {
          string[2] memory name;
          name[0] = namePrefixes[rand % namePrefixes.length];
          name[1] = nameSuffixes[rand % nameSuffixes.length];
          if (greatness == 19) {
              output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output));
          } else {
              output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output, " +1"));
          }
      }
      return output;
  }

  function getRandom() internal returns (uint) {
      randNonce++;
      return uint(keccak256(abi.encodePacked(block.timestamp,msg.sender,randNonce)));
  }

  function getNamed(string memory itemName, uint256 greatness, uint256 rand) internal view returns (string memory) {
    string memory output = itemName;
    if (greatness > 80) {
        output = string(abi.encodePacked(output, ' ', suffixes[rand % suffixes.length]));
    }
    if (greatness >= 95) {
        string[2] memory name;
        name[0] = namePrefixes[rand % namePrefixes.length];
        name[1] = nameSuffixes[rand % nameSuffixes.length];
        if (greatness >= 98) {
            output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output));
        } else {
            output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output, ' +1'));
        }
    }
    return output;
  }

  function compareStrings(string memory a, string memory b) public view returns (bool) {
      return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function guildAffinity(string memory itemName) public view returns (string memory) {
    if (compareStrings(itemName, 'Dagger')) {
        return 'thief';
    } else {
        return 'knight';
    }
  }

  function classAffinity(string memory itemName) public view returns (string memory) {
    if (compareStrings(itemName, 'Dagger')) {
        return 'thief';
    } else {
        return 'knight';
    }
  }

  function armorType(string memory itemName) public view returns (string memory) {
    /* Mapping of armorName => type (eg. Demon, Hidden, etc) */
    if (compareStrings(itemName, 'Armor')) {
        return 'Demon';
    } else {
        return 'Demon';
    }
  }

  function armorSlot(string memory itemName) public view returns (string memory) {
    /* Mapping of armorName => slot (eg. helmet, pants, chest, etc) */
    if (compareStrings(itemName, 'helm')) {
        return 'helmet';
    } else {
        return 'helmet';
    }
  }

  function tokenURI(uint256 tokenId) override public view returns (string memory) {
      /* string[17] memory parts;
      parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

      parts[1] = getWeapon(tokenId);

      parts[2] = '</text><text x="10" y="40" class="base">';

      parts[3] = getChest(tokenId);

      parts[4] = '</text><text x="10" y="60" class="base">';

      parts[5] = getHead(tokenId);

      parts[6] = '</text><text x="10" y="80" class="base">';

      parts[7] = getWaist(tokenId);

      parts[8] = '</text><text x="10" y="100" class="base">';

      parts[9] = getFoot(tokenId);

      parts[10] = '</text><text x="10" y="120" class="base">';

      parts[11] = getHand(tokenId);

      parts[12] = '</text><text x="10" y="140" class="base">';

      parts[13] = getNeck(tokenId);

      parts[14] = '</text><text x="10" y="160" class="base">';

      parts[15] = getRing(tokenId);

      parts[16] = '</text></svg>';

      string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
      output = string(abi.encodePacked(output, parts[9], parts[10], parts[11], parts[12], parts[13], parts[14], parts[15], parts[16]));

      string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Bag #', toString(tokenId), '", "description": "Vquest is an play to earn adventurer NFT game inspired by the LOOT NFT project and Zork. After initial drop, New NFT's can be minted through playing your nft's VQuest. Each NFT contains a character, items, and other gear to be used on the quest. Once a quest is finished, one can decide to respawn, or burn your existing nft in exchange for freshly minted and possibly more rare VQuest nft.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
      output = string(abi.encodePacked('data:application/json;base64,', json));

      return output; */



    return string(abi.encodePacked(tokenId, ''));
  }

  function claim(uint256 tokenId) public nonReentrant {
      require(tokenId > 0 && tokenId < 2000, 'Token ID invalid');
      _safeMint(_msgSender(), tokenId);
      tokenCounter += 1;
  }

  function ownerClaim(uint256 tokenId) public nonReentrant onlyOwner {
      require(tokenId > 7777 && tokenId < 8001, 'Token ID invalid');
      _safeMint(owner(), tokenId);
      tokenCounter += 1;
  }

  function toString(uint256 value) internal pure returns (string memory) {
  // Inspired by OraclizeAPI's implementation - MIT license
  // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

    if (value == 0) {
        return '0';
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

  function mintTokens(uint256 count) external {
      // Gas optimization
      uint256 _nextTokenId = tokenCounter + 1;

      for (uint256 ind = 0; ind < count; ind++) {
          _safeMint(_msgSender(), _nextTokenId + ind);
      }
      tokenCounter += count;
  }

  function setBaseURI(string memory baseURI_) external {
      baseURI = baseURI_;
  }

  function _baseURI() internal view override returns (string memory) {
      return baseURI;
  }

  function createCollectible() public returns (uint256) {
      uint256 newItemId = tokenCounter;
      _safeMint(_msgSender(), newItemId);
      tokenCounter = tokenCounter + 1;
      return newItemId;
  }

  constructor() ERC721('VQuest', 'VQUEST') Ownable() {
    tokenCounter = 0;
    randNonce = 0;
    /* findWeapon();
    findArmor();
    findRing(); */
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