// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be payed in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
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
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import {IMembershipPass} from "./interfaces/IMembershipPass.sol";

contract MembershipPass is IMembershipPass, ERC1155, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;

    /*╔═════════════════════════════╗
      ║   Private Stored Properties ║
      ╚═════════════════════════════╝*/
    uint256 private immutable _projectId;

    string private _baseURI;

    string private _baseContractURI;

    /*╔═════════════════════════════╗
      ║  Public Stored Properties   ║
      ╚═════════════════════════════╝*/
    // Tier capacity is zero-indexed
    mapping(uint256 => uint256) public tierCapacity;

    // Supplied amount by tier
    mapping(uint256 => uint256) public supplyByTier;

    // Royalty fee
    mapping(uint256 => uint256) public tierFee;

    // Contract-level metadata for OpenSea see https://docs.opensea.io/docs/contract-level-metadata

    // Fee collector to receive royalty fees
    address public override feeCollector;

    /*╔══════════════════╗
      ║   External VIEW  ║
      ╚══════════════════╝*/
    /**
        @notice
        Implement ERC2981, but actually the most marketplaces have their own royalty logic. Only LooksRare

        @param _tier The token ID of current saled item
        @param _salePrice The Sale price of current saled item
     */
    function royaltyInfo(uint256 _tier, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (feeCollector, _salePrice.mul(tierFee[_tier]).div(100));
    }

    function uri(uint256 _tokenId) public view override returns (string memory) {
        return
            bytes(_baseURI).length > 0
                ? string(
                    abi.encodePacked(_baseURI, _projectId.toString(), "/", _tokenId.toString())
                )
                : "";
    }

    /**
        @notice
        Return the contract-level metadata for opensea
        https://docs.opensea.io/docs/contract-level-metadata
     */
    function contractURI() public view returns (string memory) {
        return
            bytes(_baseContractURI).length > 0
                ? string(abi.encodePacked(_baseContractURI, _projectId.toString()))
                : "";
    }

    /**
        @notice
        Get remaining amount of giving toke id

        @dev
        RemainingAmount = capacity - supply    TODO: 還需要把社區 airdrop 票算進去

        @param _tier The token id
     */
    function getRemainingAmount(uint256 _tier) public view returns (uint256 _remainingAmount) {
        _remainingAmount = tierCapacity[_tier] - supplyByTier[_tier];
    }

    /*╔═════════════════════════╗
      ║   External Transaction  ║
      ╚═════════════════════════╝*/
    constructor(
        uint256 _daoId,
        string memory _uri,
        string memory _contractURI,
        address _feeCollector,
        uint256[] memory _tierFees,
        uint256[] memory _tierCapacities
    ) ERC1155("") {
        if (_tierFees.length == 0) revert TierNotSet();
        uint256 _tier = 0;
        for (uint256 i = 0; i < _tierFees.length; i++) {
            if (_tierCapacities[i] == 0) revert BadCapacity();
            if (_tierFees[i] > 10) revert BadFee();
            tierFee[_tier] = _tierFees[i];
            tierCapacity[_tier] = _tierCapacities[i];
            _tier ++;
        }

        _baseURI = _uri;
        _projectId = _daoId;
        feeCollector = _feeCollector;
        _baseContractURI = _contractURI;
    }

    /**
        @notice
        Mint token to giving address

        @param _recepient The recepient to be mint tokens
        @param _tier The token id
        @param _amount The amount to be mint
     */
    function mintPassForMember(
        address _recepient,
        uint256 _tier,
        uint256 _amount
    ) external override onlyOwner {
        if (tierCapacity[_tier] == 0) revert TierUnknow();
        if (_amount > getRemainingAmount(_tier)) revert InsufficientBalance();

        supplyByTier[_tier] = supplyByTier[_tier].add(_amount);
        _mint(_recepient, _tier, _amount, "");

        emit MintPass(_recepient, _tier, _amount);
    }

    /**
        @notice
        Batch mint tokens to giving address

        @param _recepient The recepient to be mint tokens
        @param _tiers The token ids
        @param _amounts The amounts to be mint
     */
    function batchMintPassForMember(
        address _recepient,
        uint256[] memory _tiers,
        uint256[] memory _amounts
    ) external override onlyOwner {
        for (uint256 i = 0; i < _tiers.length; i++) {
            uint256 _tier = _tiers[i];
            if (tierCapacity[_tier] == 0) revert TierUnknow();
            if (_amounts[i] > getRemainingAmount(_tier)) revert InsufficientBalance();

            supplyByTier[_tier] += _amounts[i];
        }
        _mintBatch(_recepient, _tiers, _amounts, "");

        emit BatchMintPass(_recepient, _tiers, _amounts);
    }

    /**
        @notice
        The owner can update the fee collector address

        @dev
        Only owner have access to operate

        @param _feeCollector The new fee collector
     */
    function updateFeeCollector(address _feeCollector) external override onlyOwner {
        feeCollector = _feeCollector;
    }

    function setBaseURI(string memory _uri) external override onlyOwner {
        _baseURI = _uri;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {MembershipPass, IMembershipPass} from "./MembershipPass.sol";
import {RoyaltyDistributor, IRoyaltyDistributor} from "./RoyaltyDistributor.sol";
import {TerminalUtility, ITerminalDirectory} from "./abstract/TerminalUtility.sol";
import {IMembershipPassBooth, PayInfoWithWeight, WeightInfo} from "./interfaces/IMembershipPassBooth.sol";

contract MembershipPassBooth is IMembershipPassBooth, Ownable, TerminalUtility {
    using SafeMath for uint256;

    /*╔═════════════════════════════╗
      ║  Public Stored Properties   ║
      ╚═════════════════════════════╝*/
    mapping(uint256 => uint256) public override tierSizeOf;

    mapping(uint256 => IMembershipPass) public override membershipPassOf;

    mapping(uint256 => IRoyaltyDistributor) public override royaltyDistributorOf;

    // total sqrt weight of each tiers by funding cycle
    // funding cycle id => (tier id => total sqrt weight)
    mapping(uint256 => mapping(uint256 => uint256)) public override totalSqrtWeightBy;

    // the weight details of each funding cycles by address
    // address => (funding cycyle id => (tier id => weight detail))
    mapping(address => mapping(uint256 => mapping(uint256 => WeightInfo)))
        public
        override depositedWeightBy;

    //  the claimed flag by funding cycle
    // address => (funding cycyle id =>  claimed)
    mapping(address => mapping(uint256 => bool)) public override claimedOf;

    //  the airdrop claimed flag by funding cycle
    // address => (funding cycyle id =>  claimed)
    mapping(address => mapping(uint256 => bool)) public override airdropClaimedOf;

    // funding cycyle id =>  tier id => claimed amount
    mapping(uint256 => mapping(uint256 => uint256)) public override airdropClaimedAmountOf;

    /*╔══════════════════╗
      ║   External VIEW  ║
      ╚══════════════════╝*/
    /**
        @notice
        Get allocations by funding cycle
        allocation 100000 means 0.1(10%), 1 meanss 0.000001(0.0001%), 1000000 means 1(100%)

        @param _user The address of the calling user
        @param _projectId The ID of the DAO being contribute to
        @param _fundingCycleId The funding cycle id
     */
    function getUserAllocation(
        address _user,
        uint256 _projectId,
        uint256 _fundingCycleId
    ) external view override returns (uint256[] memory _allocations) {
        _allocations = new uint256[](tierSizeOf[_projectId]);
        for (uint256 i = 0; i < tierSizeOf[_projectId]; i++) {
            _allocations[i] = depositedWeightBy[_user][_fundingCycleId][i]
                .sqrtWeight
                .mul(1e12)
                .div(totalSqrtWeightBy[_fundingCycleId][i])
                .div(1e6);
        }
    }

    /**
        @notice
        Get estimated allocations by funding cycle
        allocation 100000 means 0.1(10%), 1 meanss 0.000001(0.0001%), 1000000 means 1(100%)

        @param _projectId the project id of contribute dao
        @param _fundingCycleId the funding cycle id
        @param _weights ticket weights by tier
     */
    function getEstimatingUserAllocation(
        uint256 _projectId,
        uint256 _fundingCycleId,
        uint256[] memory _weights
    ) external view override returns (uint256[] memory _allocations) {
        _allocations = new uint256[](tierSizeOf[_projectId]);
        for (uint256 i = 0; i < tierSizeOf[_projectId]; i++) {
            uint256 _sqrtedWeight = _sqrt(_weights[i]);
            _allocations[i] = _sqrtedWeight
                .mul(1e12)
                .div(totalSqrtWeightBy[_fundingCycleId][i] + _sqrtedWeight)
                .div(1e6);
        }
    }

    /*╔═════════════════════════╗
      ║   External Transactions ║
      ╚═════════════════════════╝*/
    constructor(ITerminalDirectory _terminalDirectory, address _superAdmin)
        TerminalUtility(_terminalDirectory)
    {
        transferOwnership(_superAdmin);
    }

    /**
        @notice
        Initialize the membershiopass for dao

        @param _projectId The project ID
        @param _uri Metadata for membershippass nft
        @param _contractURI Contract level data, for intergrating the NFT to OpenSea
        @param _tierFees Royalty fees
        @param _tierCapacities Total supply for each token
     */
    function issue(
        uint256 _projectId,
        string memory _uri,
        string memory _contractURI,
        uint256[] memory _tierFees,
        uint256[] memory _tierCapacities
    ) external override onlyTerminal(_projectId) returns (address _membershipPass) {
        IRoyaltyDistributor royalty = new RoyaltyDistributor();
        MembershipPass membershipPass = new MembershipPass(
            _projectId,
            _uri,
            _contractURI,
            address(royalty),
            _tierFees,
            _tierCapacities
        );
        royaltyDistributorOf[_projectId] = royalty;
        membershipPassOf[_projectId] = membershipPass;
        tierSizeOf[_projectId] = _tierCapacities.length;
        _membershipPass = address(membershipPass);

        emit Issue(_projectId, _uri, _membershipPass, _tierFees, _tierCapacities);
    }

    /**
        @notice
        For the contribution that user need to deposit the fund to the pool
    
        @param _projectId The project ID
        @param _fundingCycleId The funding cycle ID
        @param _from The wallet address of the contributo
        @param _payInfos The payment information for this transaction
     */
    function stake(
        uint256 _projectId,
        uint256 _fundingCycleId,
        address _from,
        PayInfoWithWeight[] memory _payInfos
    ) external override onlyTerminal(_projectId) {
        for (uint256 i = 0; i < _payInfos.length; i++) {
            PayInfoWithWeight memory _payInfo = _payInfos[i];
            uint256 _baseWeight = _payInfo.amount.mul(_payInfo.weight);
            uint256 _sqrtedWeight = _sqrt(_baseWeight);
            totalSqrtWeightBy[_fundingCycleId][_payInfo.tier] += _sqrtedWeight;
            WeightInfo memory _weightByTier = depositedWeightBy[_from][_fundingCycleId][
                _payInfo.tier
            ];
            depositedWeightBy[_from][_fundingCycleId][_payInfo.tier] = WeightInfo({
                amount: _weightByTier.amount + _payInfo.amount,
                sqrtWeight: _weightByTier.sqrtWeight + _sqrtedWeight
            });
        }
    }

    /**
        @notice
        Batch mint tickets

        @param _projectId The ID of the DAO
        @param _fundingCycleId The ID of the funding cycle period
        @param _from The wallet address of owner
        @param _amounts The payment information for this transaction
     */
    function batchMintTicket(
        uint256 _projectId,
        uint256 _fundingCycleId,
        address _from,
        uint256[] memory _amounts
    ) external override onlyTerminal(_projectId) {
        claimedOf[_from][_fundingCycleId] = true;
        uint256[] memory tiers;
        for (uint256 i = 0; i < _amounts.length; i++) {
            tiers[i] = i;
        }
        membershipPassOf[_projectId].batchMintPassForMember(_from, tiers, _amounts);

        emit BatchMintTicket(_from, _projectId, tiers, _amounts);
    }

    /**
        @notice
        Batch mint special nfts for the address who have community token

        @param _projectId The ID of the DAO
        @param _fundingCycleId The ID of the funding cycle period
        @param _from The wallet address of owner
        @param _tierIds The special token ids
        @param _amounts The payment information for this transaction
     */
    function airdropBatchMintTicket(
        uint256 _projectId,
        uint256 _fundingCycleId,
        address _from,
        uint256[] memory _tierIds,
        uint256[] memory _amounts
    ) external override onlyTerminal(_projectId) {
        airdropClaimedOf[_from][_fundingCycleId] = true;
        for (uint256 i = 0; i < _tierIds.length; i++) {
            airdropClaimedAmountOf[_fundingCycleId][_tierIds[i]] += _amounts[i];
        }
        membershipPassOf[_projectId].batchMintPassForMember(_from, _tierIds, _amounts);

        emit AirdropBatchMintTicket(_from, _projectId, _tierIds, _amounts);
    }

    function setBaseURI(uint256 _projectId, string memory _uri) external override onlyOwner {
        membershipPassOf[_projectId].setBaseURI(_uri);
    }

    /*╔═════════════════════════════╗
      ║   Private Helper Functions  ║
      ╚═════════════════════════════╝*/
    /**
        @notice
        Calculates the square root of x, rounding down

        @dev
        Uses the Babylonian method (https://ethereum.stackexchange.com/a/97540/37941)

        @param x The uint256 number for which to calculate the square root
        @return result The result as an uint256
     */
    function _sqrt(uint256 x) private pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }
        // Calculate the square root of the perfect square of a power of two that is the closest to x.
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

pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IRoyaltyDistributor} from "./interfaces/IRoyaltyDistributor.sol";

// Collect the fees
// Calculate the share / percentage the user can get
// Distributed

contract RoyaltyDistributor is Ownable, IRoyaltyDistributor {
    uint256 public royaltyAggregationPeriod;

    constructor() {}

    function claimRoyalties() public override {
        //claim according to votes share
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/ITerminalUtility.sol";

abstract contract TerminalUtility is ITerminalUtility {
    modifier onlyTerminal(uint256 _projectId) {
        if (address(terminalDirectory.terminalOf(_projectId)) != msg.sender) revert UnAuthorized();
        _;
    }

    ITerminalDirectory public immutable override terminalDirectory;

    /** 
      @param _terminalDirectory A directory of a project's current terminal to receive payments in.
    */
    constructor(ITerminalDirectory _terminalDirectory) {
        terminalDirectory = _terminalDirectory;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IBluechipsBooster {
    event CreateProof(
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof,
        uint256 proofExpiry,
        uint256 weight
    );

    event CreateCustomizedProof(
        uint256 indexed projectId,
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof,
        uint256 proofExpiry,
        uint256 weight
    );

    event ChallengeProof(
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof
    );

    event ChallengeCustomizedProof(
        uint256 indexed projectId,
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof
    );

    event RedeemProof(
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof
    );

    event RedeemCustomizedProof(
        uint256 indexed projectId,
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof
    );

    event RenewProof(
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof,
        uint256 proofExpiry
    );

    event RenewCustomizedProof(
        uint256 indexed projectId,
        address indexed from,
        address indexed bluechip,
        uint256 tokenId,
        bytes32 proof,
        uint256 proofExpiry
    );

    event Remove(
        address indexed from,
        address beneficiary,
        bytes32 proof,
        address indexed bluechip,
        uint256 tokenId,
        uint256 weight
    );

    event RemoveCustomize(
        address indexed from,
        address beneficiary,
        uint256 projectId,
        bytes32 proof,
        address indexed bluechip,
        uint256 tokenId,
        uint256 weight
    );

    event AddBluechip(address bluechip, uint16 multiper);

    event AddCustomBooster(uint256 indexed projectId, address[] bluechips, uint16[] multipers);

    error SizeNotMatch();
    error BadMultiper();
    error ZeroAddress();
    error RenewFirst();
    error NotNFTOwner();
    error InsufficientBalance();
    error BoosterRegisterd();
    error BoosterNotRegisterd();
    error ProofNotRegisterd();
    error ChallengeFailed();
    error RedeemAfterExpired();
    error ForbiddenUpdate();
    error OnlyGovernor();
    error TransferDisabled();

    function count() external view returns (uint256);

    function tokenIdOf(bytes32 _proof) external view returns (uint256);

    function proofBy(bytes32 _proof) external view returns (address);

    function multiplierOf(address _bluechip) external view returns (uint16);

    function boosterWeights(address _bluechip) external view returns (uint256);

    function proofExpiryOf(bytes32 _proof) external view returns (uint256);

    function stakedOf(bytes32 _proof) external view returns (uint256);

    function customBoosterWeights(uint256 _projectId, address _bluechip)
        external
        view
        returns (uint256);

    function customMultiplierOf(uint256 _projectId, address _bluechip)
        external
        view
        returns (uint16);

    function createCustomBooster(
        uint256 _projectId,
        address[] memory _bluechips,
        uint16[] memory _multipers
    ) external;

    function createProof(address _bluechip, uint256 _tokenId) external payable;

    function createProof(
        address _bluechip,
        uint256 _tokenId,
        uint256 _projectId
    ) external payable;

    function challengeProof(address _bluechip, uint256 _tokenId) external;

    function challengeProof(
        address _bluechip,
        uint256 _tokenId,
        uint256 _projectId
    ) external;

    function renewProof(address _bluechip, uint256 _tokenId) external;

    function renewProof(
        address _bluechip,
        uint256 _tokenId,
        uint256 _projectId
    ) external;

    function redeemProof(address _bluechip, uint256 _tokenId) external;

    function redeemProof(
        address _bluechip,
        uint256 _tokenId,
        uint256 _projectId
    ) external;

    function addBlueChip(address _bluechip, uint16 _multiper) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IProjects.sol";
interface IDAOGovernorBooster {
    enum ProposalState {
    Pending,
    Active,
    Queued,
    Failed,
    Expired,
    Executed
}

struct Proposal {
    string uri;
    uint256 id;
    bytes32 hash;
    uint256 start;
    uint256 end;
    uint256 minVoters;
    uint256 minVotes;
    ProposalState state;
}

struct Vote {
    uint256 totalVoters;
    uint256 totalVotes;
}

struct PassStake {
    uint256 tier;
    uint256 amount; // ERC721: 1
    uint8 duration; // duartion in day
}

struct StakeRecord {
    uint256 tier;
    uint256 amount; // ERC721: 1
    uint256 point;
    uint256 stakeAt;
    uint256 expiry;
}


    /************************* EVENTS *************************/
    event CreateGovernor(uint256 indexed projectId, address membershipPass, address admin);

    event ProposalCreated(uint256 indexed projectId, address indexed from, uint256 proposalId);

    event ExecuteProposal(
        uint256 indexed projectId,
        address indexed from,
        uint256 proposalId,
        uint8 proposalResult
    );

    event StakePass(uint256 indexed projectId, address indexed from, uint256 points, uint256[] tierIds, uint256[] amounts);

    event UnStakePass(uint256 indexed projectId, address indexed from, uint256 points, uint256[] tierIds, uint256[] amounts);

    /************************* ERRORS *************************/
    error InsufficientBalance();
    error UnknowProposal();
    error BadPeriod();
    error InvalidSignature();
    error TransactionNotMatch();
    error TransactionReverted();
    error NotProjectOwner();
    error BadAmount();
    error NotExpired();
    error InvalidRecord();

    function createGovernor(
        uint256 _projectId,
        address _membershipPass,
        address _admin
    ) external;

    function propose(
        uint256 _projectId,
        address _proposer,
        Proposal memory _properties,
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata
    ) external payable returns (uint256);

    function execute(
        uint256 _projectId,
        uint256 _proposalId,
        uint8 _proposeResult,
        bytes memory _signatureBySigner,
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _data
    ) external returns (bytes memory);

    function stakePass(uint256 _projectId, PassStake[] memory _membershipPass)
        external
        returns (uint256);
    
    function unStakePass(uint256 _projectId, uint256[] memory _recordIds)
        external
        returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

enum FundingCycleState {
    WarmUp,
    Active,
    Expired
}

struct Metadata {
    // The unique handle name for the DAO
    bytes32 handle;
    // Contract level data, for intergrating the NFT to OpenSea
    string contractURI;
    // Metadata for membershippass nft
    string membershipPassURI;
    // The NFT token address of Customized Boosters
    address[] customBoosters;
    // The multipliers of customized NFT 
    uint16[] boosterMultipliers;
}

struct AuctionedPass {
    // tier id, indexed from 0
    uint256 id;
    uint256 weight;
    uint256 salePrice;
    // the amount of tickets open for sale in this round
    uint256 saleAmount;
    // the amount of tickets airdroped to community
    uint256 communityAmount;
    // who own the community vouchers can free mint the community ticket
    address communityVoucher;
    // the amount of tickets reserved to next round
    uint256 reservedAmount;
}

// 1st funding cycle:
// gold ticket (erc1155) :  11 salePrice 1 reserveampiunt

// silver ticket: 10 salePrice  2 reserveampiunt

struct FundingCycleProperties {
    uint256 id;
    uint256 projectId;
    uint256 previousId;
    uint256 start;
    uint256 target;
    uint256 lockRate;
    uint16 duration;
    bool isPaused;
    uint256 cycleLimit;
}

struct FundingCycleParameter {
    // rate to be locked in treasury 1000 -> 10% 9999 -> 99.99%
    uint16 lockRate;
    uint16 duration;
    uint256 cycleLimit;
    uint256 target;
}

interface IFundingCycles {
    event Configure(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        uint256 reconfigured,
        address caller
    );

    event FundingCycleExist(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        uint256 reconfigured,
        address caller
    );

    event Tap(
        uint256 indexed projectId,
        uint256 indexed fundingCycleId,
        uint256 tapAmount
    );

    event Unlock(
        uint256 indexed projectId,
        uint256 indexed fundingCycleId,
        uint256 unlockAmount,
        uint256 totalUnlockedAmount
    );

    event Init(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        uint256 previous,
        uint256 start,
        uint256 duration,
        uint256 target,
        uint256 lockRate
    );

    event InitAuctionedPass(
        uint256 indexed fundingCycleId,
        uint256 id,
        uint256 salePrice,
        uint256 saleAmount,
        uint256 communityAmount,
        address communityVoucher,
        uint256 reservedAmount
    );

    event UpdateLocked(
        uint256 indexed projectId,
        uint256 indexed fundingCycleId,
        uint256 depositAmount,
        uint256 totalDepositedAmount
    );

    error InsufficientBalance();
    error BadCycleLimit();
    error BadDuration();
    error BadLockRate();


    // === External View  === // 
    function latestIdFundingProject(uint256 _projectId) external view returns (uint256);

    function count() external view returns (uint256);

    function MAX_CYCLE_LIMIT() external view returns (uint8);

    function getFundingCycle(uint256 _fundingCycleId)
        external
        view
        returns (FundingCycleProperties memory);

    function configure(
        uint256 _projectId,
        uint16 _duration,
        uint256 _cycleLimit,
        uint256 _target,
        uint256 _lockRate,
        AuctionedPass[] memory _auctionedPass
    ) external returns (FundingCycleProperties memory);

    // === External Transactions === //
    function currentOf(uint256 _projectId) external view returns (FundingCycleProperties memory);

    function setPauseFundingCycle(uint256 _projectId, bool _paused) external returns (bool);

    function updateLocked(uint256 _projectId, uint256 _fundingCycleId, uint256 _amount) external;

    function tap(uint256 _projectId, uint256 _fundingCycleId, uint256 _amount) external;

    function unlock(uint256 _projectId, uint256 _fundingCycleId, uint256 _amount) external;

    function getTappableAmount(uint256 _fundingCycleId) external view returns (uint256);

    function getFundingCycleState(uint256 _fundingCycleId) external view returns (FundingCycleState);

    function getAutionedPass(uint256 _fundingCycleId, uint256 _tierId) external view returns(AuctionedPass memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

interface IMembershipPass is IERC1155, IERC2981 {
    event MintPass(address indexed recepient, uint256 indexed tier, uint256 amount);

    event BatchMintPass(address indexed recepient, uint256[] tiers, uint256[] amounts);

    error TierNotSet();
    error TierUnknow();
    error BadCapacity();
    error BadFee();
    error InsufficientBalance();

    function feeCollector() external view returns (address);

    /**
     * @notice
     * Implement ERC2981, but actually the most marketplaces have their own royalty logic
     */
    function royaltyInfo(uint256 _tier, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount);

    function mintPassForMember(
        address _recepient,
        uint256 _token,
        uint256 _amount
    ) external;

    function batchMintPassForMember(
        address _recepient,
        uint256[] memory _tokens,
        uint256[] memory _amounts
    ) external;

    function updateFeeCollector(address _feeCollector) external;

    function setBaseURI(string memory _uri) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IMembershipPass} from "./IMembershipPass.sol";
import {IRoyaltyDistributor} from "./IRoyaltyDistributor.sol";

struct PayInfoWithWeight {
    uint256 tier;
    uint256 amount;
    uint256 weight;
}
struct WeightInfo {
    uint256 amount;
    uint256 sqrtWeight;
}

interface IMembershipPassBooth {
    /************************* EVENTS *************************/
    event Issue(
        uint256 indexed projectId,
        string uri,
        address membershipPass,
        uint256[] tierFee,
        uint256[] tierCapacity
    );

    event BatchMintTicket(
        address indexed from,
        uint256 indexed projectId,
        uint256[] tiers,
        uint256[] amounts
    );

    event AirdropBatchMintTicket(
        address indexed from,
        uint256 indexed projectId,
        uint256[] tiers,
        uint256[] amounts
    );

    /************************* VIEW FUNCTIONS *************************/
    function tierSizeOf(uint256 _projectId) external view returns (uint256);

    function membershipPassOf(uint256 _projectId) external view returns (IMembershipPass);

    function royaltyDistributorOf(uint256 _projectId) external view returns (IRoyaltyDistributor);

    function totalSqrtWeightBy(uint256 _fundingCycleId, uint256 _tierId) external returns (uint256);

    function depositedWeightBy(
        address _from,
        uint256 _fundingCycleId,
        uint256 _tierId
    ) external view returns (uint256, uint256);

    function claimedOf(address _from, uint256 _fundingCycleId) external returns (bool);

    function airdropClaimedOf(address _from, uint256 _fundingCycleId) external returns (bool);

    function airdropClaimedAmountOf(uint256 _fundingCycleId, uint256 _tierId)
        external
        returns (uint256);

    function issue(
        uint256 _projectId,
        string memory _uri,
        string memory _contractURI,
        uint256[] memory _tierFees,
        uint256[] memory _tierCapacities
    ) external returns (address);

    function stake(
        uint256 _projectId,
        uint256 _fundingCycleId,
        address _from,
        PayInfoWithWeight[] memory _payInfo
    ) external;

    function batchMintTicket(
        uint256 _projectId,
        uint256 _fundingCycleId,
        address _from,
        uint256[] memory _amounts
    ) external;

    function airdropBatchMintTicket(
        uint256 _projectId,
        uint256 _fundingCycleId,
        address _from,
        uint256[] memory _tierIds,
        uint256[] memory _amounts
    ) external;

    function setBaseURI(uint256 _projectId, string memory _uri) external;

    function getUserAllocation(
        address _user,
        uint256 _projectId,
        uint256 _fundingCycleId
    ) external view returns (uint256[] memory);

    function getEstimatingUserAllocation(
        uint256 _projectId,
        uint256 _fundingCycleId,
        uint256[] memory _weights
    ) external view returns (uint256[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./ITerminal.sol";

interface IProjects is IERC721 {
    error EmptyHandle();
    error TakenedHandle();
    error UnAuthorized();

    event Create(
        uint256 indexed projectId,
        address indexed owner,
        bytes32 handle,
        address caller
    );

    event SetHandle(uint256 indexed projectId, bytes32 indexed handle, address caller);

    event SetBaseURI(string baseURI);

    function count() external view returns (uint256);

    function handleOf(uint256 _projectId) external returns (bytes32 handle);

    function projectFor(bytes32 _handle) external returns (uint256 projectId);

    function exists(uint256 _projectId) external view returns (bool);

    function create(
        address _owner,
        bytes32 _handle,
        ITerminal _terminal
    ) external returns (uint256 id);

    function setHandle(uint256 _projectId, bytes32 _handle) external;
    
    function setBaseURI(string memory _uri) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IRoyaltyDistributor {
	/**
	 * @notice
	 * Claim according to votes share
	 */
	function claimRoyalties() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IProjects.sol";
import "./IFundingCycles.sol";
import "./ITerminalDirectory.sol";
import "./IBluechipsBooster.sol";
import "./IDAOGovernorBooster.sol";
import "./IMembershipPassBooth.sol";

struct ImmutablePassTier {
    uint256 tierFee;
    uint256 multiplier;
    uint256 tierCapacity;
}

interface ITerminal {
    event Pay(
        uint256 indexed projectId,
        uint256 indexed fundingCycleId,
        address indexed beneficiary,
        uint256 amount,
        uint256[] tiers,
        uint256[] amounts,
        string note
    );

    event Airdrop(
        uint256 indexed projectId,
        uint256 indexed fundingCycleId,
        address indexed beneficiary,
        uint256[] tierIds,
        uint256[] amounts,
        string note
    );

    event Claim(
        uint256 indexed projectId,
        uint256 indexed fundingCycleId,
        address indexed beneficiary,
        uint256 refundAmount,
        uint256[] offeringAmounts
    );

    event Tap(
        uint256 indexed projectId,
        uint256 indexed fundingCycleId,
        address indexed beneficiary,
        uint256 govFeeAmount,
        uint256 netTransferAmount
    );

    event AddToBalance(uint256 indexed projectId, uint256 amount, address beneficiary);

    event UnlockTreasury(uint256 indexed projectId, uint256 unlockAmount);

    event SetTapFee(uint256 fee);

    event SetContributeFee(uint256 fee);

    event SetMinLockRate(uint256 minLockRate);

    error MultiplierNotMatch();
    error Voucher721(address _voucher);
    error NoCommunityTicketLeft();
    error AllReservedAmoungZero();
    error FundingCycleNotExist();
    error FundingCyclePaused();
    error FundingCycleActived();
    error InsufficientBalance();
    error AlreadyClaimed();
    error ZeroAddress();
    error BadOperationPeriod();
    error OnlyGovernor();
    error UnAuthorized();
    error LastWeightMustBe1();
    error BadPayment();
    error BadAmount();
    error BadLockRate();
    error BadTapFee();

    function superAdmin() external view returns (address);

    function tapFee() external view returns (uint256);

    function contributeFee() external view returns (uint256);

    function devTreasury() external view returns (address);

    function minLockRate() external view returns (uint256);

    function projects() external view returns (IProjects);

    function fundingCycles() external view returns (IFundingCycles);

    function membershipPassBooth() external view returns (IMembershipPassBooth);

    function daoGovernorBooster() external view returns (IDAOGovernorBooster);

    function bluechipsBooster() external view returns (IBluechipsBooster);

    function terminalDirectory() external view returns (ITerminalDirectory);

    function balanceOf(uint256 _projectId) external view returns (uint256);

    function addToBalance(uint256 _projectId) external payable;

    function setTapFee(uint256 _fee) external;

    function setContributeFee(uint256 _fee) external;

    function setMinLockRate(uint256 _minLockRate) external;

    function createDao(
        address _owner,
        Metadata memory _metadata,
        ImmutablePassTier[] calldata _tiers,
        FundingCycleParameter calldata _params,
        AuctionedPass[] calldata _auctionedPass
    ) external returns(uint256);

    function createNewFundingCycle(
        uint256 projectId,
        FundingCycleParameter calldata _params,
        AuctionedPass[] calldata _auctionedPass
    ) external;

    function contribute(
        uint256 _projectId,
        uint256[] memory _tiers,
        uint256[] memory _amounts,
        string memory _memo
    ) external payable;

    function communityContribute(
        uint256 _projectId,
        uint256 _fundingCycleId,
        string memory _memo
    ) external;

    function claimPassOrRefund(uint256 _projectId, uint256 _fundingCycleId) external;

    function tap(
        uint256 _projectId,
        uint256 _fundingCycleId,
        uint256 _amount
    ) external;

    function unLockTreasury(
        uint256 _projectId,
        uint256 _fundingCycleId,
        uint256 _unlockAmount
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ITerminal.sol";
import "./IProjects.sol";

interface ITerminalDirectory {
    event SetTerminal(
        uint256 indexed projectId,
        ITerminal indexed terminal,
        address caller
    );

    error ZeroAddress();
    error UnAuthorized();
    error UnknowTerminal();

    function projects() external view returns (IProjects);

    function terminalOf(uint256 _projectId) external view returns (ITerminal);

    function setTerminal(uint256 _projectId, ITerminal _terminal) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ITerminalDirectory.sol";

interface ITerminalUtility {
    error UnAuthorized();

    function terminalDirectory() external view returns (ITerminalDirectory);
}