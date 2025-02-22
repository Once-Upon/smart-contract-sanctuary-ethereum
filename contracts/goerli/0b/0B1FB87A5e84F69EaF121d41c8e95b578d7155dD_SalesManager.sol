// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

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
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155Upgradeable.sol";
import "./IERC1155ReceiverUpgradeable.sol";
import "./extensions/IERC1155MetadataURIUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155Upgradeable, IERC1155MetadataURIUpgradeable {
    using AddressUpgradeable for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    function __ERC1155_init(string memory uri_) internal onlyInitializing {
        __ERC1155_init_unchained(uri_);
    }

    function __ERC1155_init_unchained(string memory uri_) internal onlyInitializing {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC1155Upgradeable).interfaceId ||
            interfaceId == type(IERC1155MetadataURIUpgradeable).interfaceId ||
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
        require(account != address(0), "ERC1155: address zero is not a valid owner");
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
            "ERC1155: caller is not token owner or approved"
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
            "ERC1155: caller is not token owner or approved"
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
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

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

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

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
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
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

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Emits a {TransferSingle} event.
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
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
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

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
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
     * transfers, the length of the `ids` and `amounts` arrays will be 1.
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

    /**
     * @dev Hook that is called after any token transfer. This includes minting
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
    function _afterTokenTransfer(
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
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
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
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155Upgradeable.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURIUpgradeable is IERC1155Upgradeable {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
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
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

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
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../StringsUpgradeable.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", StringsUpgradeable.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
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
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

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

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

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

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "./libraries/LibIMPT.sol";
import "./libraries/SigRecovery.sol";

import "../interfaces/ICarbonCreditNFT.sol";

contract CarbonCreditNFT is
  ICarbonCreditNFT,
  IERC1155MetadataURIUpgradeable,
  ERC1155Upgradeable,
  PausableUpgradeable
{
  using StringsUpgradeable for uint256;

  IMarketplace public override MarketplaceContract;
  IInventory public override InventoryContract;
  ISoulboundToken public override SoulboundContract;
  IAccessManager public override AccessManager;

  string private _name;
  string private _symbol;

  function initialize(ConstructorParams memory _params) public initializer {
    __ERC1155_init(_formatBaseUri(_params.baseURI));
    __Pausable_init();

    LibIMPT._checkZeroAddress(address(_params.AccessManager));

    AccessManager = _params.AccessManager;

    _name = _params.name;
    _symbol = _params.symbol;
  }

  function name() public view virtual override returns (string memory) {
    return _name;
  }

  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }

  function uri(
    uint256 id
  )
    public
    view
    override(
      ICarbonCreditNFT,
      ERC1155Upgradeable,
      IERC1155MetadataURIUpgradeable
    )
    returns (string memory)
  {
    return string.concat(super.uri(id), "/", id.toString());
  }

  function _verifyTransferRequest(
    TransferAuthorisationParams calldata _transferAuthParams,
    bytes calldata _transferAuthSignature
  ) internal view {
    bytes memory encodedTransferRequest = abi.encode(
      _transferAuthParams.expiry,
      _transferAuthParams.to
    );

    address recoveredAddress = SigRecovery.recoverAddressFromMessage(
      encodedTransferRequest,
      _transferAuthSignature
    );

    if (!AccessManager.hasRole(LibIMPT.IMPT_BACKEND_ROLE, recoveredAddress)) {
      revert LibIMPT.InvalidSignature();
    }

    if (_transferAuthParams.expiry < block.timestamp) {
      revert LibIMPT.SignatureExpired();
    }
  }

  function retire(uint256 _tokenId, uint256 _amount) external whenNotPaused {
    _burn(msg.sender, _tokenId, _amount);

    SoulboundContract.incrementRetireCount(msg.sender, _tokenId, _amount);
    InventoryContract.incrementBurnCount(_tokenId, _amount);
  }

  function _isMarketplace(address _address) internal view {
    if (_address != address(MarketplaceContract)) {
      revert TransferMethodDisabled();
    }
  }

  modifier onlyMarketplace() {
    _isMarketplace(msg.sender);
    _;
  }

  modifier onlyIMPTRole(bytes32 _role, IAccessManager _AccessManager) {
    LibIMPT._hasIMPTRole(_role, msg.sender, AccessManager);
    _;
  }

  /// @dev The safeTransferFrom and safeBatchTransferFrom methods are disabled for users, this is because only KYCed user's can hold CarbonCreditNFT's. This KYC status is checked via a centralised backend and a signature is then generated that is validated by the contract. The methods transferFromBackendAuth and batchTransferFromBackendAuth allow this functionality.
  /// @dev Separately the safeTransferFrom and safeBatchTransferFrom are enabled for the MarketplaceContract as that contract will be handling the validation of sale orders and also has it's own checks for the backend signature auth

  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  )
    public
    virtual
    override(ERC1155Upgradeable, IERC1155Upgradeable)
    whenNotPaused
    onlyMarketplace
  {
    super.safeTransferFrom(from, to, id, amount, data);
  }

  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  )
    public
    virtual
    override(ERC1155Upgradeable, IERC1155Upgradeable)
    whenNotPaused
    onlyMarketplace
  {
    super.safeBatchTransferFrom(from, to, ids, amounts, data);
  }

  function transferFromBackendAuth(
    address from,
    uint256 id,
    uint256 amount,
    TransferAuthorisationParams calldata transferAuthParams,
    bytes calldata backendSignature
  ) public virtual override whenNotPaused {
    _verifyTransferRequest(transferAuthParams, backendSignature);

    super.safeTransferFrom(from, transferAuthParams.to, id, amount, "");
  }

  function batchTransferFromBackendAuth(
    address from,
    uint256[] memory ids,
    uint256[] memory amounts,
    TransferAuthorisationParams calldata transferAuthParams,
    bytes calldata backendSignature
  ) public virtual override whenNotPaused {
    _verifyTransferRequest(transferAuthParams, backendSignature);

    super.safeBatchTransferFrom(from, transferAuthParams.to, ids, amounts, "");
  }

  function mint(
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) external virtual override whenNotPaused onlyIMPTRole(LibIMPT.IMPT_MINTER_ROLE, AccessManager) {
    InventoryContract.updateTotalMinted(id, amount);
    _mint(to, id, amount, data);
  }

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) external virtual override whenNotPaused onlyIMPTRole(LibIMPT.IMPT_MINTER_ROLE, AccessManager) {
    for (uint8 i = 0; i < ids.length; i++) {
      InventoryContract.updateTotalMinted(ids[i], amounts[i]);
    }
    _mintBatch(to, ids, amounts, data);
  }

  /// @dev Concats the provided baseUri with the address of the contract in the following form: `${baseURL}/${address(this)}`
  /// @param _baseUri The base uri to use
  /// @return formattedBaseUri The formatted base uri
  function _formatBaseUri(
    string memory _baseUri
  ) internal view returns (string memory formattedBaseUri) {
    formattedBaseUri = string.concat(
      _baseUri,
      "/",
      StringsUpgradeable.toHexString(uint256(uint160(address(this))), 20)
    );
  }

  function setBaseUri(
    string calldata _baseUri
  ) external override onlyIMPTRole(LibIMPT.DEFAULT_ADMIN_ROLE, AccessManager) {
    string memory formattedBaseUri = _formatBaseUri(_baseUri);
    // Set the URI on the base ERC1155 contract and pull it from there using the uri() method when needed
    super._setURI(formattedBaseUri);

    emit BaseUriUpdated(formattedBaseUri);
  }

  function setMarketplaceContract(
    IMarketplace _marketplaceContract
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_marketplaceContract));

    MarketplaceContract = _marketplaceContract;

    emit MarketplaceContractChanged(_marketplaceContract);
  }

  function setSoulboundContract(
    ISoulboundToken _soulboundContract
  ) public override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_soulboundContract));

    SoulboundContract = _soulboundContract;

    emit SoulboundContractChanged(_soulboundContract);
  }

  function setInventoryContract(
    IInventory _inventoryContract
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_inventoryContract));

    InventoryContract = _inventoryContract;

    emit InventoryContractChanged(_inventoryContract);
  }

  function pause() external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    _pause();
  }

  function unpause() external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    _unpause();
  }

  function isApprovedForAll(
    address _owner,
    address _operator
  )
    public
    view
    override(ERC1155Upgradeable, IERC1155Upgradeable)
    returns (bool isOperator)
  {
    // This allows the marketplace contract to manage user's NFTs during sales without users having to approve their NFTs to the marketplace contract
    if (msg.sender == address(MarketplaceContract)) {
      return true;
    }

    // otherwise, use the default ERC1155.isApprovedForAll()
    return ERC1155Upgradeable.isApprovedForAll(_owner, _operator);
  }

  function supportsInterface(
    bytes4 interfaceId
  )
    public
    view
    virtual
    override(
      ERC1155Upgradeable,
      IERC165Upgradeable
    )
    returns (bool)
  {
    return
      ERC1155Upgradeable.supportsInterface(interfaceId);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../../interfaces/IAccessManager.sol";

/// @title LibIMPT
/// @author Github: Labrys-Group
/// @dev Library for implementing frequently re-used functions, errors, events and data structures / state in IMPT
library LibIMPT {
  //######################
  //#### PUBLIC STATE ####

  bytes32 public constant IMPT_ADMIN_ROLE = keccak256("IMPT_ADMIN_ROLE");
  bytes32 public constant IMPT_BACKEND_ROLE = keccak256("IMPT_BACKEND_ROLE");
  bytes32 public constant IMPT_APPROVED_DEX = keccak256("IMPT_APPROVED_DEX");
  bytes32 public constant IMPT_MINTER_ROLE = keccak256("IMPT_MINTER_ROLE");
  bytes32 public constant IMPT_SALES_MANAGER = keccak256("IMPT_SALES_MANAGER");
  bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);

  //################
  //#### ERRORS ####

  ///@dev Thrown when _checkZeroAddress is called with the zero addres.
  error CannotBeZeroAddress();
  ///@dev Thrown when an auth signature from the IMPT back-end is invalid
  error InvalidSignature();
  ///@dev Thrown when an auth signature from the IMPT back-end  has expired
  error SignatureExpired();

  /// @dev Thrown when a custom checkRole function is used and the caller does not have the required role
  error MissingRole(bytes32 _role, address _account);

  ///@dev Emitted when the IMPT treasury changes
  event IMPTTreasuryChanged(address implementation);

  //############################
  //#### INTERNAL FUNCTIONS ####

  ///@dev Internal function that checks if an address is zero and reverts if it is.
  ///@param _address The address to check.
  function _checkZeroAddress(address _address) internal pure {
    if (_address == address(0)) {
      revert CannotBeZeroAddress();
    }
  }

  function _hasIMPTRole(
    bytes32 _role,
    address _address,
    IAccessManager _AccessManager
  ) internal view {
    if (!(_AccessManager.hasRole(_role, _address))) {
      revert MissingRole(_role, msg.sender);
    }
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/// @title SigRecovery
/// @dev This contract provides some helpers for signature recovery
library SigRecovery {
  /// @dev This method prefixes the provided message parameter with the message signing prefix, it also hashes the result as this hash is used in signature recovery
  /// @param message The message to prefix
  function prefixMessageHash(
    bytes32 message
  ) internal pure returns (bytes32 prefixedMessageHash) {
    prefixedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
    );
  }

  /// @dev This method splits the signature, extracting the r, s and v values
  /// @param sig The signature to split
  function splitSignature(
    bytes memory sig
  ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
    require(sig.length == 65, "Sig: Invalid signature length");

    assembly {
      // First 32 bytes holds the signature length, skips first 32 bytes as that is the prefix
      r := mload(add(sig, 32))
      // Gets the following 32 bytes of the signature
      s := mload(add(sig, 64))
      // Get the final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(sig, 96)))
    }
  }

  /// @dev This method prefixes the provided message hash, splits the signature and uses ecrecover to return the signing address
  /// @param _message The message that was signed
  /// @param _signature The signature
  function recoverAddressFromMessage(
    bytes memory _message,
    bytes memory _signature
  ) internal pure returns (address recoveredAddress) {
    bytes32 hashOfMessage = prefixMessageHash(keccak256(_message));

    (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

    recoveredAddress = ecrecover(hashOfMessage, v, r, s);
  }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "../interfaces/ISalesManager.sol";
import "./libraries/LibIMPT.sol";

import "./libraries/SigRecovery.sol";

contract SalesManager is ISalesManager, PausableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable public override IMPTAddress;
  IERC20Upgradeable public override USDCAddress;
  IWETH public override WETHAddress;
  ICarbonCreditNFT public override CarbonCreditNFTContract;
  ISoulboundToken public override SoulboundToken;
  IAccessManager public override AccessManager;

  address public override IMPTTreasuryAddress;

  //Request ID (from back-end) => used
  mapping(bytes24 => bool) public override usedRequests;

  function initialize(ConstructorParams memory _params) public initializer {
    PausableUpgradeable.__Pausable_init();
    LibIMPT._checkZeroAddress(address(_params.IMPTAddress));
    LibIMPT._checkZeroAddress(address(_params.USDCAddress));
    LibIMPT._checkZeroAddress(address(_params.WETHAddress));
    LibIMPT._checkZeroAddress(address(_params.CarbonCreditNFTContract));
    LibIMPT._checkZeroAddress(address(_params.AccessManager));
    LibIMPT._checkZeroAddress(address(_params.SoulboundToken));
    LibIMPT._checkZeroAddress(_params.IMPTTreasuryAddress);

    IMPTAddress = _params.IMPTAddress;
    USDCAddress = _params.USDCAddress;
    WETHAddress = _params.WETHAddress;
    IMPTTreasuryAddress = _params.IMPTTreasuryAddress;
    CarbonCreditNFTContract = _params.CarbonCreditNFTContract;
    AccessManager = _params.AccessManager;
    SoulboundToken = _params.SoulboundToken;
  }

  //############################
  //#### INTERNAL-FUNCTIONS ####

  /// @dev Verifies the purchase signature of the given authorisation parameters.
  /// @param _authorisationParams Authorisation parameters to verify the signature of.
  function _verifyPurchaseSignature(
    AuthorisationParams calldata _authorisationParams
  ) internal {
    bytes memory encodedTransferRequest = abi.encode(
      _authorisationParams.requestId,
      _authorisationParams.expiry,
      msg.sender
    );
    if (_authorisationParams.expiry < block.timestamp) {
      revert LibIMPT.SignatureExpired();
    }

    if (usedRequests[_authorisationParams.requestId]) {
      revert LibIMPT.InvalidSignature();
    }

    address recoveredAddress = SigRecovery.recoverAddressFromMessage(
      encodedTransferRequest,
      _authorisationParams.signature
    );

    if (!AccessManager.hasRole(LibIMPT.IMPT_BACKEND_ROLE, recoveredAddress)) {
      revert LibIMPT.InvalidSignature();
    }

    usedRequests[_authorisationParams.requestId] = true;
  }

  /// @dev Calls the given DEX swap contract with the given parameters and audits the results.
  /// @param _swapParams Swap parameters to pass to the DEX contract.
  /// @return  swapReturn The resulting swap data.
  function _callDEXSwap(
    SwapParams calldata _swapParams
  ) internal returns (SwapReturnData memory swapReturn) {
    //Sticking these in memory so we don't repetitively read storage
    IERC20Upgradeable USDCToken = USDCAddress;
    IERC20Upgradeable IMPTToken = IMPTAddress;

    if (
      !(
        AccessManager.hasRole(LibIMPT.IMPT_APPROVED_DEX, _swapParams.swapTarget)
      )
    ) {
      revert UnauthorisedSwapTarget();
    }
    //If the DEX being utilised for the swap will take the funds from an address other than the call target, grant it a temporary allowance
    if (_swapParams.swapTarget != _swapParams.spender) {
      IMPTToken.approve(_swapParams.spender, type(uint256).max);
    }

    uint256 USDCBefore = USDCToken.balanceOf(address(this));
    uint256 IMPTBefore = IMPTToken.balanceOf(address(this));

    (bool success, ) = _swapParams.swapTarget.call(_swapParams.swapCallData);

    if (!success) {
      revert ZeroXSwapFailed();
    }
    swapReturn.USDCDelta = USDCToken.balanceOf(address(this)) - USDCBefore;
    swapReturn.IMPTDelta = IMPTBefore - IMPTToken.balanceOf(address(this));

    if (_swapParams.swapTarget != _swapParams.spender) {
      IMPTToken.approve(_swapParams.spender, uint256(0));
    }
  }

  /// @dev Audits the results of a swap to ensure that the correct amounts of sell and buy tokens were transferred.
  /// @param _swapReturnData Swap data to audit.
  /// @param _sellAmount Amount of sell tokens that should have been transferred.
  function _auditSwap(
    SwapReturnData memory _swapReturnData,
    uint256 _sellAmount
  ) internal pure {
    if (_swapReturnData.IMPTDelta != _sellAmount) {
      revert WrongSellTokenChange();
    }
    if (!(_swapReturnData.USDCDelta > 0)) {
      revert WrongBuyTokenChange();
    }
  }

  modifier onlyIMPTRole(bytes32 _role, IAccessManager _AccessManager) {
    LibIMPT._hasIMPTRole(_role, msg.sender, AccessManager);
    _;
  }

  //###################
  //#### FUNCTIONS ####

  receive() external payable override {}

  function purchaseWithIMPT(
    AuthorisationParams calldata _authorisationParams,
    SwapParams calldata _swapParams
  ) external whenNotPaused {
    _verifyPurchaseSignature(_authorisationParams);

    IMPTAddress.safeTransferFrom(
      msg.sender,
      address(this),
      _authorisationParams.sellAmount
    );

    SwapReturnData memory swapReturn = _callDEXSwap(_swapParams);
    _auditSwap(swapReturn, _authorisationParams.sellAmount);

    emit PurchaseCompleted(
      _authorisationParams.requestId,
      swapReturn.USDCDelta
    );

    USDCAddress.transfer(IMPTTreasuryAddress, swapReturn.USDCDelta);

    CarbonCreditNFTContract.mint(
      msg.sender,
      _authorisationParams.tokenId,
      _authorisationParams.amount,
      _authorisationParams.signature
    );
  }

  function purchaseWithIMPTWithoutSwap(
    AuthorisationParams calldata _authorisationParams
  ) external whenNotPaused {
    _verifyPurchaseSignature(_authorisationParams);
    IMPTAddress.safeTransferFrom(
      msg.sender,
      address(this),
      _authorisationParams.sellAmount
    );
    CarbonCreditNFTContract.mint(
      msg.sender,
      _authorisationParams.tokenId,
      _authorisationParams.amount,
      ""
    );
  }

  // TODO: Update this function with correct specs-- need auth, signature, price?
  function purchaseSoulboundToken(
    string memory _imageURI
  ) external whenNotPaused {
    uint256 tokenId = SoulboundToken.getCurrentTokenId();
    emit SoulboundTokenMinted(msg.sender, tokenId);

    SoulboundToken.mint(msg.sender, _imageURI);
  }

  //##########################
  //#### SETTER-FUNCTIONS ####
  function pause()
    external
    override
    onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager)
  {
    _pause();
  }

  function unpause()
    external
    override
    onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager)
  {
    _unpause();
  }

  function setPlatformToken(
    IERC20Upgradeable _implementation
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_implementation));
    IMPTAddress = _implementation;
    emit PlatformTokenChanged(_implementation);
  }

  function setUSDC(
    IERC20Upgradeable _implementation
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_implementation));
    USDCAddress = _implementation;
    emit USDCChanged(_implementation);
  }

  function setWETH(
    IWETH _implementation
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_implementation));
    WETHAddress = _implementation;
    emit WETHChanged(_implementation);
  }

  function addSwapTarget(
    address _implementation
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_implementation));
    AccessManager.grantRole(LibIMPT.IMPT_APPROVED_DEX, _implementation);
    IMPTAddress.approve(_implementation, type(uint256).max);
  }

  function removeSwapTarget(
    address _implementation
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_implementation));
    AccessManager.revokeRole(LibIMPT.IMPT_APPROVED_DEX, _implementation);
    IMPTAddress.approve(_implementation, uint256(0));
  }

  function setIMPTTreasury(
    address _implementation
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(_implementation);
    IMPTTreasuryAddress = _implementation;
    emit LibIMPT.IMPTTreasuryChanged(_implementation);
  }

  function setCarbonCreditNFT(
    ICarbonCreditNFT _carbonCreditNFT
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_carbonCreditNFT));
    CarbonCreditNFTContract = _carbonCreditNFT;
    emit CarbonCreditNFTContractChanged(_carbonCreditNFT);
  }

  function setSoulboundToken(
    ISoulboundToken _soulboundToken
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_soulboundToken));
    SoulboundToken = _soulboundToken;
    emit SoulboundTokenContractChanged(_soulboundToken);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";

/// @title Interface for the AccessManager Smart Contract
/// @author Github: Labrys-Group
/// @notice Utilised to house all authorised accounts within the IMPT contract eco-system
interface IAccessManager is IAccessControlEnumerable {
  struct ConstructorParams {
    address superUser;
  }

  function bulkGrantRoles(
    bytes32[] calldata _roles,
    address[] calldata _addresses
  ) external;

  function transferDEXRoleAdmin() external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

import "./IMarketplace.sol";
import "../interfaces/IAccessManager.sol";
import "./IInventory.sol";
import "./ISoulboundToken.sol";

/// @title ICarbonCreditNFT
/// @author Github: Labrys-Group
/// @dev This interface represents a carbon credit non-fungible token (NFT). It extends the IERC1155 interface to allow for the creation and management of carbon credits.
interface ICarbonCreditNFT is
  IERC1155Upgradeable
{
  /// @dev The `TransferAuthorisationParams` struct holds the parameters required to authorisation a token transfer, this struct will be signed by a backend wallet. Only KYCed users can hold CarbonCreditNFT's and this authorisation ensures that the Backend has checked that the 'to' address belongs to a KYCed user
  /// @param expiry representing the request UNIX expiry time
  /// @param to The receiver of the transfer
  struct TransferAuthorisationParams {
    uint40 expiry;
    address to;
  }

  /// @dev The `ConstructorParams` struct holds the parameters that are required to be passed to the contract's constructor.
  /// @param superUser The address of the superuser of the contract.
  /// @param baseURI The base URI for the NFT contract
  struct ConstructorParams {
    address superUser;
    address platformAdmin;
    string baseURI;
    IAccessManager AccessManager;
    string name;
    string symbol;
  }

  //################
  //#### ERRORS ####
  //

  /// @dev The `MustBeMarketplaceContract` error is thrown if the contract being interacted with is not the marketplace contract
  error MustBeMarketplaceContract();

  /// @dev This error is thrown when calling the safeTransferFrom or safeBatchTransferFrom with the standard ERC1155 transfer parameters. This is disabled because we require a backend signature in order to transfer tokens, this requires disabling the base method and overloading it with a new one that includes the additional parameters
  error TransferMethodDisabled();

  //###################
  //#### FUNCTIONS ####
  //

  /// @dev Returns the token uri for the provided token id
  /// @param id The token id for which the URI is being retrieved.
  /// @return The token URI for the provided token id.
  function uri(uint256 id) external view returns (string memory);

  /// @dev Allows user's with the IMPT_MINTER_ROLE to mint tokens. This function creates new tokens and assigns them to the specified address.
  /// @param to The address to which the new tokens should be assigned.
  /// @param id The token id for the new tokens being minted.
  /// @param amount The number of tokens being minted.
  /// @param data Optional data pass through incase we develop the token hooks later on
  function mint(
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) external;

  /// @dev Allows user's with the IMPT_MINTER_ROLE to batch mint multiple token id's with varying amounts to a specified user. This function creates new tokens and assigns them to the specified address.
  /// @param to The address to which the new tokens should be assigned.
  /// @param ids An array of token id's for the new tokens being minted.
  /// @param amounts An array of the number of tokens being minted for each corresponding token id in the ids array.
  /// @param data Optional data pass through incase we develop the token hooks later on
  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) external;

  /// @dev Allows user's to transfer their CarbonCreditNFT to a KYCed user. The TransferAuthorisationParams contains the destination to address and the backendSignature ensures that the backend has validated the address to be a KYCed user.
  /// @param from The from address
  /// @param id The tokenId to transfer
  /// @param amount The amount of tokenId's to transfer
  /// @param backendSignature The signed TransferAuthorisationParams by the backend
  /// @param transferAuthParams The transfer parameters
  function transferFromBackendAuth(
    address from,
    uint256 id,
    uint256 amount,
    TransferAuthorisationParams calldata transferAuthParams,
    bytes calldata backendSignature
  ) external;

  /// @dev Allows user's to transfer multiple CarbonCreditNFT's to a KYCed user. The TransferAuthorisationParams contains the destination to address and the backendSignature ensures that the backend has validated the address to be a KYCed user.
  /// @param from The from address
  /// @param ids The id's to transfer
  /// @param amounts Equivalent length array containing the amount of each tokenId to transfer
  /// @param backendSignature The signed TransferAuthorisationParams by the backend
  /// @param transferAuthParams The transfer parameters
  function batchTransferFromBackendAuth(
    address from,
    uint256[] memory ids,
    uint256[] memory amounts,
    TransferAuthorisationParams calldata transferAuthParams,
    bytes calldata backendSignature
  ) external;

  //################
  //#### EVENTS ####
  //

  /// @dev The `MarketplaceContractChanged` event is emitted whenever the contract's associated marketplace contract is changed.
  /// @param implementation The new implementation of the marketplace contract.
  event MarketplaceContractChanged(IMarketplace implementation);

  /// @dev The `InventoryContractChanged` event is emitted whenever the contract's associated inventory contract is changed.
  /// @param implementation The new implementation of the inventory contract.
  event InventoryContractChanged(IInventory implementation);

  /// @dev The `SoulboundContractChanged` event is emitted whenever the contract's associated soulbound token contract is changed.
  /// @param implementation The new implementation of the soulbound contract.
  event SoulboundContractChanged(ISoulboundToken implementation);

  /// @dev The `BaseURIUpdated` event is emitted whenever the contract's baseUri is updated
  /// @param _baseUri The new baseUri to set
  event BaseUriUpdated(string _baseUri);

  //##########################
  //#### SETTER-FUNCTIONS ####
  /**
   * @dev Returns the name of the token.
   */
  function name() external view returns (string memory);

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name.
   */
  function symbol() external view returns (string memory);

  /// @dev The `setBaseUri` function sets the baseURI for the contract, the provided baseUri is concatted with the address of the contract so that the uri for tokens is: `${baseUri}/${address(this)}/${tokenId}`
  /// @param _baseUri The new base uri for the contract
  function setBaseUri(string calldata _baseUri) external;

  /// @dev The `setMarketplaceContract` function sets the marketplace contract
  /// @param _marketplaceContract The new implementation of the marketplace contract.
  function setMarketplaceContract(IMarketplace _marketplaceContract) external;

  /// @dev The `setInventoryContract` function sets the inventory contract
  /// @param _inventoryContract The new implementation of the inventory contract.
  function setInventoryContract(IInventory _inventoryContract) external;

  /// @dev The `setSoulboundContract` function sets the soulbound token contract
  /// @param _soulboundContract The new implementation of the soulbound token contract.
  function setSoulboundContract(ISoulboundToken _soulboundContract) external;

  /// @dev This function allows the platform admin to pause the contract.
  function pause() external;

  /// @dev This function allows the platform admin to unpause the contract.
  function unpause() external;

  //################################
  //#### AUTO-GENERATED GETTERS ####

  /// @dev The `MarketplaceContract` function returns the address of the contract's associated marketplace contract.
  ///@return implementation The address of the contract's associated marketplace contract.
  function MarketplaceContract()
    external
    view
    returns (IMarketplace implementation);

  /// @dev This function returns the address of the IMPT Access Manager contract
  ///@return implementation The address of the contract's associated AccessManager contract.
  function AccessManager()
    external
    view
    returns (IAccessManager implementation);

  /// @dev The `InventoryContract` function returns the address of the contract's associated inventory contract.
  ///@return implementation The address of the contract's associated inventory contract.
  function InventoryContract()
    external
    view
    returns (IInventory implementation);

  /// @dev The `SoulboundContract` function returns the address of the contract's associated inventory contract.
  ///@return implementation The address of the contract's associated inventory contract.
  function SoulboundContract()
    external
    view
    returns (ISoulboundToken implementation);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;
import "../implementations/CarbonCreditNFT.sol";

interface IInventory {
  struct InventoryConstructorParams {
    address stableWallet;
    CarbonCreditNFT nftContract;
  }

  /// @dev stores the starge details for a particular token ID
  struct TokenDetails {
    uint256 totalSupply;
    uint256 tokensMinted;
    uint256 imptBurnCount;
  }

  //####################################
  //#### ERRORS #######################
  //####################################
  /// @dev reverts if the function is called by an unauthorized address
  error UnauthorizedCall();

  /// @dev reverts function if updating totals will result in negatives (to be used where functions might panic instead)
  error TotalMismatch();

  /// @dev reverts function if amount is less than 0
  error AmountMustBeMoreThanZero();

  /// @dev reverts a function if there is not enough total supply for a given token
  error NotEnoughSupply();

  //###################################
  //#### EVENTS #######################
  //###################################
  /// @dev emits when the burn count has been updated
  /// @param _tokenId the id of the token whose burn count has been updated
  /// @param _amount the number of tokens burned
  event BurnCountUpdated(uint256 _tokenId, uint256 _amount);

  /// @dev emits when the burn count has been sent to Thallo
  /// @param _tokenId the id of the token whose burn count has been sent
  /// @param _amount the number of tokens sent to be burned by Thallo
  event BurnSent(uint256 _tokenId, uint256 _amount);

  /// @dev emits when the burn count has been confirmed by Thallo
  /// @param _tokenId the id of the token whose burn count is confirmed
  /// @param _amount the amount of tokens confirmed burned by Thallo
  event BurnConfirmed(uint256 _tokenId, uint256 _amount);

  /// @dev emits when the total supply has been sent by Thallo
  /// @param _tokenId the id of the token whose supply has been updated
  /// @param _newSupply the updated total supply of the token
  event TotalSupplyUpdated(uint256 indexed _tokenId, uint256 _newSupply);

  /// @dev emits when the stable wallet has been updated
  /// @param _newStableWallet the address of the new stable walelt
  event UpdateWallet(address _newStableWallet);

  //####################################
  //#### FUNCTIONS #####################
  //####################################
  /// @dev updates the total supply of a given token ID, as given by Thallo
  /// @param _tokenId the Carbon Credit NFT's token ID (ERC-1155)
  /// @param _amount the amount that the total will be set to
  function updateTotalSupply(uint256 _tokenId, uint256 _amount) external;

  /// @dev updates the total supply of a given token ID, as given by Thallo
  /// @param _tokenIds an array of the Carbon Credit NFT's token IDs (ERC-1155)
  /// @param _amounts an array of the amounts that the total will be set to
  function updateBulkTotalSupply(
    uint256[] memory _tokenIds,
    uint256[] memory _amounts
  ) external;

  /// @dev returns the total supply of a given token ID
  /// @param _tokenIds an array of the Carbon Credit NFT's token IDs (ERC-1155)
  function getAllTokenDetails(
    uint256[] memory _tokenIds
  ) external view returns (TokenDetails[] memory);

  /// @dev updates the IMPT burn count when a carbon NFT is retired
  /// @param _tokenId the token ID for update burn counts for
  /// @param _amount the amount to increment the burn count by
  function incrementBurnCount(uint256 _tokenId, uint256 _amount) external;

  /// @dev this function calls the confirm burn counts and update total supply functions in a single transaction
  /// @param _tokenId the Carbon Credit NFT token ID
  /// @param _newTotalSupply the amount to which to total supply will be set
  /// @param _confirmedBurned the amount that Thallo has confirmed burned on their end
  function confirmAndUpdate(
    uint256 _tokenId,
    uint256 _newTotalSupply,
    uint256 _confirmedBurned
  ) external;

  function bulkConfirmAndUpdate(
    uint256[] memory _tokenIds,
    uint256[] memory _newTotalSupplies,
    uint256[] memory _confirmedBurns
  ) external;

  /// @dev Updates total when Thallo confirms the number of tokens burned to IMPT
  /// @param _tokenId the Carbon Credit NFT's token ID (ERC-1155)
  /// @param _amount the amount of tokens Thallo has burned
  function confirmBurnCounts(uint256 _tokenId, uint256 _amount) external;

  /// @dev Updates totals in bulk when Thallo confirms the number of tokens burned to IMPT
  /// @param _tokenIds the Carbon Credit NFT's token IDs (ERC-1155)
  /// @param _amounts the amounts of tokens Thallo has burned
  function bulkConfirmBurnCounts(uint256[] memory _tokenIds, uint256[] memory _amounts) external;

  /// @dev The wallet that is able to sign contracts on behalf of IMPT
  /// @param _stableWallet the wallet address
  function setStableWallet(address _stableWallet) external;

  /// @dev The wallet that is able to sign contracts on behalf of IMPT
  /// @param _nftContract the address of the carbon credit NFT
  function setNftContract(CarbonCreditNFT _nftContract) external;

  /// @dev decrements the total supply, to be called whenever carbon credit tokens are minted
  /// @param _tokenId the id of the token id that needs to be decremented
  /// @param _amount the amount by which to decrement the total supply
  function updateTotalMinted(uint256 _tokenId, uint256 _amount) external;

  //####################################
  //#### GETTERS #######################
  //####################################
  function stableWallet() external returns (address);

  function nftContract() external returns (CarbonCreditNFT);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/ICarbonCreditNFT.sol";
import "../interfaces/IAccessManager.sol";

/// @title Interface for the IMarketplace Smart Contract
/// @author Github: Labrys-Group
interface IMarketplace {
  //################
  //#### STRUCTS ###

  /// @dev This struct represents the parameters required to construct a marketplace contract.
  /// @param superUser The address of the superuser of the contract
  /// @param platformAdmin The address of the platform admin of the contract
  /// @param CarbonCreditNFT The address of the carbon credit NFT contract
  /// @param IMPTAddress The address of the IMPT ERC20 contract
  /// @param IMPTTreasuryAddress The address of the IMPT treasury contract
  struct ConstructorParams {
    ICarbonCreditNFT CarbonCreditNFT;
    IERC20 IMPTAddress;
    address IMPTTreasuryAddress;
    IAccessManager AccessManager;
  }

  /// @dev This struct represents a sale order for carbon credits
  /// @param saleOrderId The unique identifier for this sale order, this will be invalidated within the method to ensure no double-spends
  /// @param tokenId The token ID of the carbon credit being sold
  /// @param amount The amount of carbon credits being sold
  /// @param salePrice The price at which the carbon credits are being sold
  /// @param expiry The expiration timestamp for this sale order
  /// @param seller The address of the seller
  struct SaleOrder {
    bytes24 saleOrderId;
    uint256 tokenId;
    uint256 amount;
    uint256 salePrice;
    uint40 expiry;
    address seller;
  }

  /// @dev This struct contains the authorisation parameters for a sale request, this will be provided along with a SaleOrder. This struct will be signed by the backend, as it will check if the 'to' address is KYCed and the expiry will ensure the request cannot live too long
  /// @param expiry This authorisation expiry will be a short duration ~5 mins and allows users to delist their tokens or change the sell order without risking another user saving the sellerSignature to be executed later on
  /// @param to The address that will receive the purchased tokens
  struct AuthorisationParams {
    uint40 expiry;
    address to;
  }

  //####################################
  //#### ERRORS #######################
  //####################################

  /// @dev This error is thrown when a sale order has expired.
  error SaleOrderExpired();

  /// @dev This error is thrown when the seller does not have sufficient carbon credits to fulfill the sale.
  error InsufficientSellerCarbonCreditBalance();

  /// @dev This error is thrown when the buyer does not have sufficient balance of IMPT to fulfill the purchase.
  error InsufficientTokenBalance();

  /// @dev This error is thrown when a sale order with the same ID has already been used.
  error SaleOrderIdUsed();

  /// @dev This error is thrown when a user is trying to use AuthorisationParams where the to address doesn't match the msg.sender
  error InvalidBuyer();

  //####################################
  //#### EVENTS #######################
  //####################################

  /// @dev This event is emitted when a carbon credit sale is completed.
  /// @param saleOrderId The unique identifier for the sale order.
  /// @param tokenId The token ID of the carbon credit being sold.
  /// @param amount The amount of carbon credits being sold.
  /// @param salePrice The price at which the carbon credits were sold.
  /// @param seller The address of the seller.
  /// @param buyer The address of the buyer.
  event CarbonCreditSaleCompleted(
    bytes24 saleOrderId,
    uint256 tokenId,
    uint256 amount,
    uint256 salePrice,
    address indexed seller,
    address indexed buyer
  );

  /// @dev This event is emitted when the royalty percentage changes.
  /// @param royaltyPercentage The new royalty percentage.
  event RoyaltyPercentageChanged(uint256 royaltyPercentage);

  //####################################
  //#### SETTER-FUNCTIONS #############
  //####################################

  /// @dev This function allows the platform admin to set the address of the IMPT treasury contract.
  /// @param _implementation The address of the IMPT treasury contract.
  function setIMPTTreasury(address _implementation) external;

  /// @dev This function allows the platform admin to set the royalty percentage.
  /// @param _royaltyPercentage The new royalty percentage.
  function setRoyaltyPercentage(uint256 _royaltyPercentage) external;

  /// @dev This function allows the platform admin to pause the contract.
  function pause() external;

  /// @dev This function allows the platform admin to unpause the contract.
  function unpause() external;

  //####################################
  //#### AUTO-GENERATED GETTERS #######
  //####################################

  /// @dev This function returns the address of the IMPT ERC20 contract.
  /// @return implementation The address of the IMPT ERC20 contract.
  function IMPTAddress() external returns (IERC20 implementation);

  /// @dev This function returns the address of the carbon credit NFT contract.
  /// @return implementation The address of the carbon credit NFT contract.
  function CarbonCreditNFT() external returns (ICarbonCreditNFT implementation);

  /// @dev This function returns the address of the IMPT treasury contract.
  /// @return implementation The address of the IMPT treasury contract.
  function IMPTTreasuryAddress() external returns (address implementation);

  /// @dev This function returns whether the specified sale order ID has been used.
  /// @param _saleOrderId The sale order ID to check.
  /// @return used True if the sale order ID has been used, false otherwise.
  function usedSaleOrderIds(bytes24 _saleOrderId) external returns (bool used);

  /// @dev This function returns the address of the IMPT Access Manager contract
  function AccessManager() external returns (IAccessManager implementation);

  /// @dev This method executes the provided sale order, charging the seller their sale amount and transferring the msg.sender the tokens. It also takes a royalty percentage from the sale and transfers it to the IMPT treasury. This method also ensures that the _authorisationParams.to == msg.sender
  /// @param _authorisationParams The authorisation parameters from the backend
  /// @param _authorisationSignature The signed saleOrder + authorisationParams
  /// @param _saleOrder The sale order details
  /// @param _sellerOrderSignature The seller's signature
  function purchaseToken(
    AuthorisationParams calldata _authorisationParams,
    bytes calldata _authorisationSignature,
    SaleOrder calldata _saleOrder,
    bytes calldata _sellerOrderSignature
  ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./ICarbonCreditNFT.sol";
import "./ISoulboundToken.sol";
import "../vendors/IWETH.sol";

/// @title Interface for the SalesManager Smart Contract
/// @author Github: Labrys-Group
/// @notice Utilised to correctly route a user's swap transaction, enforcing constraints on permitted swapTargets and balance changes of known tokens.
/// @dev Checks balance change of IMPTToken == sellAmount
/// @dev Checks balance change of USDC is more than zero
/// @dev Utilises the internal Solidity Library `LibIMPT`
interface ISalesManager  {
  //################
  //#### STRUCTS ###

  /// @dev Struct to hold authorisation parameters
  /// @param requestId bytes24 representing the request identifier from the IMPT back-end
  /// @param expiry uint40 representing the request UNIX expiry time
  /// @param sellAmount uint256 representing the amount of tokens to be sold
  /// @param tokenId the tokenId the user is purchasing
  /// @param amount amount of tokenId's to purchase
  /// @param expiry uint40 representing the request UNIX expiry time
  /// @param signature bytes representing the user's signature
  struct AuthorisationParams {
    bytes24 requestId;
    uint40 expiry;
    uint256 sellAmount;
    uint256 tokenId;
    uint256 amount;
    bytes signature;
  }

  /// @dev Struct to hold swap parameters
  /// @param spender address of the spender
  /// @param swapTarget address of the swap target
  /// @param swapCallData data for the swap call
  struct SwapParams {
    address spender;
    address swapTarget;
    bytes swapCallData;
  }

  /// @dev Struct to hold constructor parameters
  /// @param IMPTAddress address of the IMPT token contract
  /// @param USDCAddress address of the USDC token contract
  /// @param WETHAddress address of the WETH token contract
  /// @param CarbonCreditNFTContract address of the CarbonCreditNFT contract
  /// @param IMPTTreasuryAddress address of the IMPT treasury contract
  /// @param AccessManager  address of the IMPT Access Manager
  /// @param SoulboundToken address of the soulbound token contract
  struct ConstructorParams {
    IERC20Upgradeable IMPTAddress;
    IERC20Upgradeable USDCAddress;
    IWETH WETHAddress;
    ICarbonCreditNFT CarbonCreditNFTContract;
    address IMPTTreasuryAddress;
    IAccessManager AccessManager;
    ISoulboundToken SoulboundToken;
  }

  /// @dev Struct to hold swap return data
  /// @param IMPTDelta uint256 representing the change in the IMPT balance
  /// @param USDCDelta uint256 representing the change in the USDC balance
  struct SwapReturnData {
    uint256 IMPTDelta;
    uint256 USDCDelta;
  }

  //################
  //#### EVENTS ####

  /// @dev Event emitted when purchase is completed
  /// @param requestId bytes24 representing the request identifier
  /// @param purchaseAmount uint256 representing the amount of tokens purchased
  event PurchaseCompleted(bytes24 requestId, uint256 purchaseAmount);

  /// @dev Event emitted when the platform token is changed
  /// @param implementation address of the new platform token contract
  event PlatformTokenChanged(IERC20Upgradeable implementation);

  /// @dev Event emitted when the USDC token is changed
  /// @param implementation address of the new USDC token contract
  event USDCChanged(IERC20Upgradeable implementation);

  /// @dev Event emitted when the WETH token is changed
  /// @param implementation address of the new WETH token contract
  event WETHChanged(IWETH implementation);

  /// @dev Event emitted when the IMPT treasury is changed
  /// @param implementation address of the new IMPT treasury contract
  event IMPTTreasuryChanged(address implementation);

  /// @dev Event emitted whenever the CarbonCreditNFT contract is changed
  /// @param implementation The new implementation of the CarbonCreditNFTcontract
  event CarbonCreditNFTContractChanged(ICarbonCreditNFT implementation);

  /// @dev Event emitted whenever the Soulbound Token contract is changed
  /// @param implementation The new implementation of the Soulbound Token contract
  event SoulboundTokenContractChanged(ISoulboundToken implementation);

  /// @dev Event emitted when a soulbound token has been minted
  /// @param _owner the owner of a brand new soulbound token!
  /// @param _tokenId the soulbound token ID
  event SoulboundTokenMinted(address _owner, uint256 _tokenId);

  //################
  //#### ERRORS ####

  /// @dev Thrown when a swapTarget attemts to be called that doesn't hold IMPT_APPROVED_DEX role
  error UnauthorisedSwapTarget();
  /// @dev Thrown when the low-level call to the swapTarget fails
  error ZeroXSwapFailed();
  /// @dev Thrown if SwapReturnData.USDCDelta isn't > 0
  error WrongBuyTokenChange();
  /// @dev Thrown if IMPTDelta != AuthorisationParams.sellAmount
  error WrongSellTokenChange();

  //###################
  //#### FUNCTIONS ####
  //

  /// @dev Fallback function to receive payments
  receive() external payable;

  /// @notice Function to purchase tokens with IMPT
  /// @param _authorisationParams AuthorisationParams struct representing the authorisation parameters
  /// @param _swapParams SwapParams struct representing the swap parameters
  /// @dev Checks balance change of IMPT token == sellAmount
  /// @dev Checks balance change of USDC is more than zero
  /// @dev Uses OpenZeppelin AccessControl to restrict approved Decentralised Exchanges
  /// @dev Uses OpenZeppelin AccessControl to restrict approved IMPT Admins for setter functions
  /// @dev Utilises the internal Solidity Library `LibIMPT`
  function purchaseWithIMPT(
    AuthorisationParams calldata _authorisationParams,
    SwapParams calldata _swapParams
  ) external;

  /// @notice Function to add a swap target
  /// @param _implementation address of the swap target contract
  /// @dev Can only be called by an approved IMPT admin
  function addSwapTarget(address _implementation) external;

  /// @notice Function to remove a swap target
  /// @param _implementation address of the swap target contract
  /// @dev Can only be called by an approved IMPT admin
  function removeSwapTarget(address _implementation) external;

  //##########################
  //#### SETTER-FUNCTIONS ####

  /// @notice Function to set the platform token contract
  /// @param _implementation address of the new platform token contract
  /// @dev Can only be called by an approved IMPT admin
  function setPlatformToken(IERC20Upgradeable _implementation) external;

  /// @notice Function to set the USDC token contract
  /// @param _implementation address of the new USDC token contract
  /// @dev Can only be called by an approved IMPT admin
  function setUSDC(IERC20Upgradeable _implementation) external;

  /// @notice Function to set the WETH token contract
  /// @param _implementation address of the new WETH token contract
  /// @dev Can only be called by an approved IMPT admin
  function setWETH(IWETH _implementation) external;

  /// @notice Function to set the IMPT treasury contract
  /// @param _implementation address of the new IMPT treasury contract
  /// @dev Can only be called by an approved IMPT admin
  function setIMPTTreasury(address _implementation) external;

  /// @dev Function to set the CarbonCreditNFT contract
  /// @param _carbonCreditNFT The new implementation of the CarbonCreditNFT contract.
  function setCarbonCreditNFT(ICarbonCreditNFT _carbonCreditNFT) external;

  /// @dev Function to set the Soulbound Token contract
  /// @param _soulboundToken The new implementation of the Soulbound Token contract.
  function setSoulboundToken(ISoulboundToken _soulboundToken) external;

  /// @dev This function allows the platform admin to pause the contract.
  function pause() external;

  /// @dev This function allows the platform admin to unpause the contract.
  function unpause() external;

  //################################
  //#### AUTO-GENERATED GETTERS ####

  /// @notice Function to get the address of the carbon credit NFT contract
  /// @return implementation address of the carbon credit NFT contract
  function CarbonCreditNFTContract()
    external
    returns (ICarbonCreditNFT implementation);

  /// @notice Function to get the address of the soulbound token contract
  /// @return implementation address of the soulbound token contract
  function SoulboundToken() external returns (ISoulboundToken implementation);

  /// @notice Function to get the address of the current platform token contract
  /// @return implementation address of the current platform token contract
  function IMPTAddress() external returns (IERC20Upgradeable implementation);

  /// @notice Function to get the address of the current USDC token contract
  /// @return implementation address of the current USDC token contract
  function USDCAddress() external returns (IERC20Upgradeable implementation);

  /// @notice Function to get the address of the current WETH token contract
  /// @return implementation address of the current WETH token contract
  function WETHAddress() external returns (IWETH implementation);

  /// @notice Function to get the address of the current IMPT treasury contract
  /// @return implementation address of the current IMPT treasury contract
  function IMPTTreasuryAddress() external returns (address implementation);

  /// @notice Function to check if a request has been used
  /// @param _requestId bytes24 representing the request identifier
  /// @return used bool indicating whether the request has been used or not
  function usedRequests(bytes24 _requestId) external returns (bool used);

  /// @dev This function returns the address of the IMPT Access Manager contract
  function AccessManager() external returns (IAccessManager implementation);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../interfaces/ICarbonCreditNFT.sol";
import "../interfaces/IAccessManager.sol";

/// @dev Interface for a soulbound token which is non-transferrable and closely follows the 721 standard.
/// @dev It also manages the token types and formatting of metadata responses
interface ISoulboundToken is IERC165 {
  //################
  //#### STRUCTS ####
  /// @dev The `ConstructorParams` struct holds the parameters that are required to be passed to the contract's constructor.
  /// @param name_ The token name
  /// @param symbol_ The token symbol
  /// @param description_ The description of the token
  /// @param _carbonCreditContract The address of the carbon credit contract (must match interface specs)
  /// @param adminAddress The address that will be assigned to the role IMPT_ADMIN
  struct ConstructorParams {
    string name_;
    string symbol_;
    string description_;
    ICarbonCreditNFT _carbonCreditContract;
    IAccessManager AccessManager;
  }

  /// @dev The required fields for each tokenType. Each tokenType exists in the CarbonCreditNFT contract as a subcollection
  /// @param displayName Unique display name for the token type
  /// @param tokenId The id of the TokenType in the CarbonCreditNFT contract
  struct TokenType {
    string displayName;
    uint256 tokenId;
  }

  //################
  //#### EVENTS ####
  /// @dev This emits ONLY when token `_tokenId` is minted from the zero address and is used to conform closely to ERC721 standards
  event Transfer(
    address indexed _from,
    address indexed _to,
    uint256 indexed _tokenId
  );

  /// @dev Emits when the Carbon Credit contract has been updated
  event CarbonNftContractUpdated(ICarbonCreditNFT newAddress);

  /// @dev Emits when the user's retire count for a given token ID is updated
  event RetireCountUpdated(address owner, uint256 tokenId, uint256 amount);

  /// @dev Emits when a new token type is added
  event TokenTypeAdded(ISoulboundToken.TokenType _tokenType);

  /// @dev Emits when a new token type is removed
  event TokenTypeRemoved(uint256 tokenId);

  //################
  //#### ERRORS ####
  error UnauthorizedCall();
  error HasToken();
  error TokenIdNotFound();
  error ContractInitialized();
  error NoTokenTypes();

  //##########################
  //#### CUSTOM FUNCTIONS ####
  /// @notice mints a new soulbound token
  /// @param to the address to send the token to
  /// @param imageURI the image URI for the token, to be included in the metadata
  function mint(address to, string calldata imageURI) external;

  /// @notice Increments the user's burned token count to be displayed in soulbound token metadata
  /// @param user Address of the user whos burned count needs to be updated
  /// @param tokenId The soulbound token ID owned by the user above
  /// @param amount The amount by which to increase the user burned count
  function incrementRetireCount(
    address user,
    uint256 tokenId,
    uint256 amount
  ) external;

  /// @notice returns all the current token types
  function getAllTokenTypes()
    external
    view
    returns (ISoulboundToken.TokenType[] memory);

  /// @notice adds a new token type
  /// @param _tokenType the data to add to the end of the token types array
  function addTokenType(TokenType calldata _tokenType) external;

  /// @notice removes token type from the array. If the token is not at the end of the array, the element at the end of the array is moved to the deleted item's position
  /// @param _tokenId the token ID of the token type, as from the CarbonCreditNFT
  function removeTokenType(uint256 _tokenId) external;

  /// @notice updates the carbon credit contract implementation
  /// @param _carbonCreditContract the new implementation of the carbon credit NFT
  function setCarbonCreditContract(
    ICarbonCreditNFT _carbonCreditContract
  ) external;

  function getCurrentTokenId() external view returns (uint256);

  //###########################
  //#### ERC-721 FUNCTIONS ####
  /// @notice Returns the total amount of tokens for the provided user, can only ever be 0 or 1
  /// @param _owner An address for whom to query the balance
  /// @return The number of tokens owned by `_owner`, possibly zero
  function balanceOf(address _owner) external view returns (uint256);

  /// @notice Find the owner of a token
  /// @dev tokens assigned to zero address are considered invalid, and queries
  ///  about them do throw.
  /// @param _tokenId The identifier for a token
  /// @return The address of the owner of the token
  function ownerOf(uint256 _tokenId) external view returns (address);

  /// @notice The name of the Account Bound Token contract
  function name() external view returns (string memory);

  /// @notice The symbol of the Account Bound Token contract
  function symbol() external view returns (string memory);

  /// @notice The symbol of the Account Bound Token contract
  function description() external view returns (string memory);

  /// @notice TokenURI contains metadata for the individual token as base64 encoded JSON object
  /// @param _tokenId The token to retrieve a metadata URI for
  function tokenURI(uint256 _tokenId) external view returns (string memory);

  //################################
  //#### AUTO-GENERATED GETTERS ####
  /// @dev This function returns the address of the IMPT Access Manager contract
  ///@return implementation The address of the contract's associated AccessManager contract.
  function AccessManager()
    external
    view
    returns (IAccessManager implementation);

  function carbonCreditContract() external view returns (ICarbonCreditNFT);

  function usersBurnedCounts(
    address owner,
    uint256 tokenId
  ) external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
  function deposit() external payable;

  function withdraw(uint256 amount) external;
}