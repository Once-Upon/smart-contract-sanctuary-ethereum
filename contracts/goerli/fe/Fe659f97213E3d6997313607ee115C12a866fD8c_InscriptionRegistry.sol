// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

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
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

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
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

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
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
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
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
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
     * @dev Returns the number of values in the set. O(1).
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

// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.17;

import "./IDelegationRegistry.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title DelegationRegistry
 * @custom:version 1.0
 * @notice An immutable registry contract to be deployed as a standalone primitive.
 * @dev See EIP-5639, new project launches can read previous cold wallet -> hot wallet delegations
 * from here and integrate those permissions into their flow.
 * @custom:coauthor foobar (0xfoobar)
 * @custom:coauthor wwchung (manifoldxyz)
 * @custom:coauthor purplehat (artblocks)
 * @custom:coauthor ryley-o (artblocks)
 * @custom:coauthor andy8052 (tessera)
 * @custom:coauthor punk6529 (open metaverse)
 * @custom:coauthor loopify (loopiverse)
 * @custom:coauthor emiliano (nftrentals)
 * @custom:coauthor arran (proof)
 * @custom:coauthor james (collabland)
 * @custom:coauthor john (gnosis safe)
 * @custom:coauthor 0xrusowsky
 */
contract DelegationRegistry is IDelegationRegistry, ERC165 {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice The global mapping and single source of truth for delegations
    /// @dev vault -> vaultVersion -> delegationHash
    mapping(address => mapping(uint256 => EnumerableSet.Bytes32Set))
        internal delegations;

    /// @notice A mapping of wallets to versions (for cheap revocation)
    mapping(address => uint256) internal vaultVersion;

    /// @notice A mapping of wallets to delegates to versions (for cheap revocation)
    mapping(address => mapping(address => uint256)) internal delegateVersion;

    /// @notice A secondary mapping to return onchain enumerability of delegations that a given address can perform
    /// @dev delegate -> delegationHashes
    mapping(address => EnumerableSet.Bytes32Set) internal delegationHashes;

    /// @notice A secondary mapping used to return delegation information about a delegation
    /// @dev delegationHash -> DelegateInfo
    mapping(bytes32 => IDelegationRegistry.DelegationInfo)
        internal delegationInfo;

    /**
     * @inheritdoc ERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165)
        returns (bool)
    {
        return
            interfaceId == type(IDelegationRegistry).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * -----------  WRITE -----------
     */

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForAll(address delegate, bool value) external override {
        bytes32 delegationHash = _computeAllDelegationHash(
            msg.sender,
            delegate
        );
        _setDelegationValues(
            delegate,
            delegationHash,
            value,
            IDelegationRegistry.DelegationType.ALL,
            msg.sender,
            address(0),
            0
        );
        emit IDelegationRegistry.DelegateForAll(msg.sender, delegate, value);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForContract(
        address delegate,
        address contract_,
        bool value
    ) external override {
        bytes32 delegationHash = _computeContractDelegationHash(
            msg.sender,
            delegate,
            contract_
        );
        _setDelegationValues(
            delegate,
            delegationHash,
            value,
            IDelegationRegistry.DelegationType.CONTRACT,
            msg.sender,
            contract_,
            0
        );
        emit IDelegationRegistry.DelegateForContract(
            msg.sender,
            delegate,
            contract_,
            value
        );
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function delegateForToken(
        address delegate,
        address contract_,
        uint256 tokenId,
        bool value
    ) external override {
        bytes32 delegationHash = _computeTokenDelegationHash(
            msg.sender,
            delegate,
            contract_,
            tokenId
        );
        _setDelegationValues(
            delegate,
            delegationHash,
            value,
            IDelegationRegistry.DelegationType.TOKEN,
            msg.sender,
            contract_,
            tokenId
        );
        emit IDelegationRegistry.DelegateForToken(
            msg.sender,
            delegate,
            contract_,
            tokenId,
            value
        );
    }

    /**
     * @dev Helper function to set all delegation values and enumeration sets
     */
    function _setDelegationValues(
        address delegate,
        bytes32 delegateHash,
        bool value,
        IDelegationRegistry.DelegationType type_,
        address vault,
        address contract_,
        uint256 tokenId
    ) internal {
        if (value) {
            delegations[vault][vaultVersion[vault]].add(delegateHash);
            delegationHashes[delegate].add(delegateHash);
            delegationInfo[delegateHash] = DelegationInfo({
                vault: vault,
                delegate: delegate,
                type_: type_,
                contract_: contract_,
                tokenId: tokenId
            });
        } else {
            delegations[vault][vaultVersion[vault]].remove(delegateHash);
            delegationHashes[delegate].remove(delegateHash);
            delete delegationInfo[delegateHash];
        }
    }

    /**
     * @dev Helper function to compute delegation hash for wallet delegation
     */
    function _computeAllDelegationHash(address vault, address delegate)
        internal
        view
        returns (bytes32)
    {
        uint256 vaultVersion_ = vaultVersion[vault];
        uint256 delegateVersion_ = delegateVersion[vault][delegate];
        return
            keccak256(
                abi.encode(delegate, vault, vaultVersion_, delegateVersion_)
            );
    }

    /**
     * @dev Helper function to compute delegation hash for contract delegation
     */
    function _computeContractDelegationHash(
        address vault,
        address delegate,
        address contract_
    ) internal view returns (bytes32) {
        uint256 vaultVersion_ = vaultVersion[vault];
        uint256 delegateVersion_ = delegateVersion[vault][delegate];
        return
            keccak256(
                abi.encode(
                    delegate,
                    vault,
                    contract_,
                    vaultVersion_,
                    delegateVersion_
                )
            );
    }

    /**
     * @dev Helper function to compute delegation hash for token delegation
     */
    function _computeTokenDelegationHash(
        address vault,
        address delegate,
        address contract_,
        uint256 tokenId
    ) internal view returns (bytes32) {
        uint256 vaultVersion_ = vaultVersion[vault];
        uint256 delegateVersion_ = delegateVersion[vault][delegate];
        return
            keccak256(
                abi.encode(
                    delegate,
                    vault,
                    contract_,
                    tokenId,
                    vaultVersion_,
                    delegateVersion_
                )
            );
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeAllDelegates() external override {
        ++vaultVersion[msg.sender];
        emit IDelegationRegistry.RevokeAllDelegates(msg.sender);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeDelegate(address delegate) external override {
        _revokeDelegate(delegate, msg.sender);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function revokeSelf(address vault) external override {
        _revokeDelegate(msg.sender, vault);
    }

    /**
     * @dev Revoke the `delegate` hotwallet from the `vault` coldwallet.
     */
    function _revokeDelegate(address delegate, address vault) internal {
        ++delegateVersion[vault][delegate];
        // For enumerations, filter in the view functions
        emit IDelegationRegistry.RevokeDelegate(vault, msg.sender);
    }

    /**
     * -----------  READ -----------
     */

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegationsByDelegate(address delegate)
        external
        view
        returns (IDelegationRegistry.DelegationInfo[] memory info)
    {
        EnumerableSet.Bytes32Set
            storage potentialDelegationHashes = delegationHashes[delegate];
        uint256 potentialDelegationHashesLength = potentialDelegationHashes
            .length();
        uint256 delegationCount = 0;
        info = new IDelegationRegistry.DelegationInfo[](
            potentialDelegationHashesLength
        );
        for (uint256 i = 0; i < potentialDelegationHashesLength; ) {
            bytes32 delegateHash = potentialDelegationHashes.at(i);
            IDelegationRegistry.DelegationInfo
                memory delegationInfo_ = delegationInfo[delegateHash];
            address vault = delegationInfo_.vault;
            IDelegationRegistry.DelegationType type_ = delegationInfo_.type_;
            bool valid = false;
            if (type_ == IDelegationRegistry.DelegationType.ALL) {
                if (
                    delegateHash == _computeAllDelegationHash(vault, delegate)
                ) {
                    valid = true;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.CONTRACT) {
                if (
                    delegateHash ==
                    _computeContractDelegationHash(
                        vault,
                        delegate,
                        delegationInfo_.contract_
                    )
                ) {
                    valid = true;
                }
            } else if (type_ == IDelegationRegistry.DelegationType.TOKEN) {
                if (
                    delegateHash ==
                    _computeTokenDelegationHash(
                        vault,
                        delegate,
                        delegationInfo_.contract_,
                        delegationInfo_.tokenId
                    )
                ) {
                    valid = true;
                }
            }
            if (valid) {
                info[delegationCount++] = delegationInfo_;
            }
            unchecked {
                ++i;
            }
        }
        if (potentialDelegationHashesLength > delegationCount) {
            assembly {
                let decrease := sub(
                    potentialDelegationHashesLength,
                    delegationCount
                )
                mstore(info, sub(mload(info), decrease))
            }
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegatesForAll(address vault)
        external
        view
        returns (address[] memory delegates)
    {
        return
            _getDelegatesForLevel(
                vault,
                IDelegationRegistry.DelegationType.ALL,
                address(0),
                0
            );
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegatesForContract(address vault, address contract_)
        external
        view
        override
        returns (address[] memory delegates)
    {
        return
            _getDelegatesForLevel(
                vault,
                IDelegationRegistry.DelegationType.CONTRACT,
                contract_,
                0
            );
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getDelegatesForToken(
        address vault,
        address contract_,
        uint256 tokenId
    ) external view override returns (address[] memory delegates) {
        return
            _getDelegatesForLevel(
                vault,
                IDelegationRegistry.DelegationType.TOKEN,
                contract_,
                tokenId
            );
    }

    function _getDelegatesForLevel(
        address vault,
        IDelegationRegistry.DelegationType delegationType,
        address contract_,
        uint256 tokenId
    ) internal view returns (address[] memory delegates) {
        EnumerableSet.Bytes32Set storage delegationHashes_ = delegations[vault][
            vaultVersion[vault]
        ];
        uint256 potentialDelegatesLength = delegationHashes_.length();
        uint256 delegatesCount = 0;
        delegates = new address[](potentialDelegatesLength);
        for (uint256 i = 0; i < potentialDelegatesLength; ) {
            bytes32 delegationHash = delegationHashes_.at(i);
            DelegationInfo storage delegationInfo_ = delegationInfo[
                delegationHash
            ];
            if (delegationInfo_.type_ == delegationType) {
                if (delegationType == IDelegationRegistry.DelegationType.ALL) {
                    // check delegate version by validating the hash
                    if (
                        delegationHash ==
                        _computeAllDelegationHash(
                            vault,
                            delegationInfo_.delegate
                        )
                    ) {
                        delegates[delegatesCount++] = delegationInfo_.delegate;
                    }
                } else if (
                    delegationType ==
                    IDelegationRegistry.DelegationType.CONTRACT
                ) {
                    if (delegationInfo_.contract_ == contract_) {
                        // check delegate version by validating the hash
                        if (
                            delegationHash ==
                            _computeContractDelegationHash(
                                vault,
                                delegationInfo_.delegate,
                                contract_
                            )
                        ) {
                            delegates[delegatesCount++] = delegationInfo_
                                .delegate;
                        }
                    }
                } else if (
                    delegationType == IDelegationRegistry.DelegationType.TOKEN
                ) {
                    if (
                        delegationInfo_.contract_ == contract_ &&
                        delegationInfo_.tokenId == tokenId
                    ) {
                        // check delegate version by validating the hash
                        if (
                            delegationHash ==
                            _computeTokenDelegationHash(
                                vault,
                                delegationInfo_.delegate,
                                contract_,
                                tokenId
                            )
                        ) {
                            delegates[delegatesCount++] = delegationInfo_
                                .delegate;
                        }
                    }
                }
            }
            unchecked {
                ++i;
            }
        }
        if (potentialDelegatesLength > delegatesCount) {
            assembly {
                let decrease := sub(potentialDelegatesLength, delegatesCount)
                mstore(delegates, sub(mload(delegates), decrease))
            }
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getContractLevelDelegations(address vault)
        external
        view
        returns (
            IDelegationRegistry.ContractDelegation[] memory contractDelegations
        )
    {
        EnumerableSet.Bytes32Set storage delegationHashes_ = delegations[vault][
            vaultVersion[vault]
        ];
        uint256 potentialLength = delegationHashes_.length();
        uint256 delegationCount = 0;
        contractDelegations = new IDelegationRegistry.ContractDelegation[](
            potentialLength
        );
        for (uint256 i = 0; i < potentialLength; ) {
            bytes32 delegationHash = delegationHashes_.at(i);
            DelegationInfo storage delegationInfo_ = delegationInfo[
                delegationHash
            ];
            if (
                delegationInfo_.type_ ==
                IDelegationRegistry.DelegationType.CONTRACT
            ) {
                // check delegate version by validating the hash
                if (
                    delegationHash ==
                    _computeContractDelegationHash(
                        vault,
                        delegationInfo_.delegate,
                        delegationInfo_.contract_
                    )
                ) {
                    contractDelegations[delegationCount++] = IDelegationRegistry
                        .ContractDelegation({
                            contract_: delegationInfo_.contract_,
                            delegate: delegationInfo_.delegate
                        });
                }
            }
            unchecked {
                ++i;
            }
        }
        if (potentialLength > delegationCount) {
            assembly {
                let decrease := sub(potentialLength, delegationCount)
                mstore(
                    contractDelegations,
                    sub(mload(contractDelegations), decrease)
                )
            }
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function getTokenLevelDelegations(address vault)
        external
        view
        returns (IDelegationRegistry.TokenDelegation[] memory tokenDelegations)
    {
        EnumerableSet.Bytes32Set storage delegationHashes_ = delegations[vault][
            vaultVersion[vault]
        ];
        uint256 potentialLength = delegationHashes_.length();
        uint256 delegationCount = 0;
        tokenDelegations = new IDelegationRegistry.TokenDelegation[](
            potentialLength
        );
        for (uint256 i = 0; i < potentialLength; ) {
            bytes32 delegationHash = delegationHashes_.at(i);
            DelegationInfo storage delegationInfo_ = delegationInfo[
                delegationHash
            ];
            if (
                delegationInfo_.type_ ==
                IDelegationRegistry.DelegationType.TOKEN
            ) {
                // check delegate version by validating the hash
                if (
                    delegationHash ==
                    _computeTokenDelegationHash(
                        vault,
                        delegationInfo_.delegate,
                        delegationInfo_.contract_,
                        delegationInfo_.tokenId
                    )
                ) {
                    tokenDelegations[delegationCount++] = IDelegationRegistry
                        .TokenDelegation({
                            contract_: delegationInfo_.contract_,
                            tokenId: delegationInfo_.tokenId,
                            delegate: delegationInfo_.delegate
                        });
                }
            }
            unchecked {
                ++i;
            }
        }
        if (potentialLength > delegationCount) {
            assembly {
                let decrease := sub(potentialLength, delegationCount)
                mstore(tokenDelegations, sub(mload(tokenDelegations), decrease))
            }
        }
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForAll(address delegate, address vault)
        public
        view
        override
        returns (bool)
    {
        bytes32 delegateHash = keccak256(
            abi.encode(
                delegate,
                vault,
                vaultVersion[vault],
                delegateVersion[vault][delegate]
            )
        );
        return delegations[vault][vaultVersion[vault]].contains(delegateHash);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForContract(
        address delegate,
        address vault,
        address contract_
    ) public view override returns (bool) {
        bytes32 delegateHash = keccak256(
            abi.encode(
                delegate,
                vault,
                contract_,
                vaultVersion[vault],
                delegateVersion[vault][delegate]
            )
        );
        return
            delegations[vault][vaultVersion[vault]].contains(delegateHash)
                ? true
                : checkDelegateForAll(delegate, vault);
    }

    /**
     * @inheritdoc IDelegationRegistry
     */
    function checkDelegateForToken(
        address delegate,
        address vault,
        address contract_,
        uint256 tokenId
    ) public view override returns (bool) {
        bytes32 delegateHash = keccak256(
            abi.encode(
                delegate,
                vault,
                contract_,
                tokenId,
                vaultVersion[vault],
                delegateVersion[vault][delegate]
            )
        );
        return
            delegations[vault][vaultVersion[vault]].contains(delegateHash)
                ? true
                : checkDelegateForContract(delegate, vault, contract_);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ICryptoPunksMarket {
    function punkIndexToAddress(uint256 _tokenId)
        external
        view
        returns (address);

    function balanceOf(address _address) external view returns (uint256);
}

// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.17;

/**
 * @title An immutable registry contract to be deployed as a standalone primitive
 * @dev See EIP-5639, new project launches can read previous cold wallet -> hot wallet delegations
 *      from here and integrate those permissions into their flow
 */
interface IDelegationRegistry {
    /// @notice Delegation type
    enum DelegationType {
        NONE,
        ALL,
        CONTRACT,
        TOKEN
    }

    /// @notice Info about a single delegation, used for onchain enumeration
    struct DelegationInfo {
        DelegationType type_;
        address vault;
        address delegate;
        address contract_;
        uint256 tokenId;
    }

    /// @notice Info about a single contract-level delegation
    struct ContractDelegation {
        address contract_;
        address delegate;
    }

    /// @notice Info about a single token-level delegation
    struct TokenDelegation {
        address contract_;
        uint256 tokenId;
        address delegate;
    }

    /// @notice Emitted when a user delegates their entire wallet
    event DelegateForAll(address vault, address delegate, bool value);

    /// @notice Emitted when a user delegates a specific contract
    event DelegateForContract(
        address vault,
        address delegate,
        address contract_,
        bool value
    );

    /// @notice Emitted when a user delegates a specific token
    event DelegateForToken(
        address vault,
        address delegate,
        address contract_,
        uint256 tokenId,
        bool value
    );

    /// @notice Emitted when a user revokes all delegations
    event RevokeAllDelegates(address vault);

    /// @notice Emitted when a user revoes all delegations for a given delegate
    event RevokeDelegate(address vault, address delegate);

    /**
     * -----------  WRITE -----------
     */

    /**
     * @notice Allow the delegate to act on your behalf for all contracts
     * @param delegate The hotwallet to act on your behalf
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForAll(address delegate, bool value) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific contract
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForContract(
        address delegate,
        address contract_,
        bool value
    ) external;

    /**
     * @notice Allow the delegate to act on your behalf for a specific token
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
     */
    function delegateForToken(
        address delegate,
        address contract_,
        uint256 tokenId,
        bool value
    ) external;

    /**
     * @notice Revoke all delegates
     */
    function revokeAllDelegates() external;

    /**
     * @notice Revoke a specific delegate for all their permissions
     * @param delegate The hotwallet to revoke
     */
    function revokeDelegate(address delegate) external;

    /**
     * @notice Remove yourself as a delegate for a specific vault
     * @param vault The vault which delegated to the msg.sender, and should be removed
     */
    function revokeSelf(address vault) external;

    /**
     * -----------  READ -----------
     */

    /**
     * @notice Returns all active delegations a given delegate is able to claim on behalf of
     * @param delegate The delegate that you would like to retrieve delegations for
     * @return info Array of DelegationInfo structs
     */
    function getDelegationsByDelegate(address delegate)
        external
        view
        returns (DelegationInfo[] memory);

    /**
     * @notice Returns an array of wallet-level delegates for a given vault
     * @param vault The cold wallet who issued the delegation
     * @return addresses Array of wallet-level delegates for a given vault
     */
    function getDelegatesForAll(address vault)
        external
        view
        returns (address[] memory);

    /**
     * @notice Returns an array of contract-level delegates for a given vault and contract
     * @param vault The cold wallet who issued the delegation
     * @param contract_ The address for the contract you're delegating
     * @return addresses Array of contract-level delegates for a given vault and contract
     */
    function getDelegatesForContract(address vault, address contract_)
        external
        view
        returns (address[] memory);

    /**
     * @notice Returns an array of contract-level delegates for a given vault's token
     * @param vault The cold wallet who issued the delegation
     * @param contract_ The address for the contract holding the token
     * @param tokenId The token id for the token you're delegating
     * @return addresses Array of contract-level delegates for a given vault's token
     */
    function getDelegatesForToken(
        address vault,
        address contract_,
        uint256 tokenId
    ) external view returns (address[] memory);

    /**
     * @notice Returns all contract-level delegations for a given vault
     * @param vault The cold wallet who issued the delegations
     * @return delegations Array of ContractDelegation structs
     */
    function getContractLevelDelegations(address vault)
        external
        view
        returns (ContractDelegation[] memory delegations);

    /**
     * @notice Returns all token-level delegations for a given vault
     * @param vault The cold wallet who issued the delegations
     * @return delegations Array of TokenDelegation structs
     */
    function getTokenLevelDelegations(address vault)
        external
        view
        returns (TokenDelegation[] memory delegations);

    /**
     * @notice Returns true if the address is delegated to act on the entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForAll(address delegate, address vault)
        external
        view
        returns (bool);

    /**
     * @notice Returns true if the address is delegated to act on your behalf for a token contract or an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForContract(
        address delegate,
        address vault,
        address contract_
    ) external view returns (bool);

    /**
     * @notice Returns true if the address is delegated to act on your behalf for a specific token, the token's contract or an entire vault
     * @param delegate The hotwallet to act on your behalf
     * @param contract_ The address for the contract you're delegating
     * @param tokenId The token id for the token you're delegating
     * @param vault The cold wallet who issued the delegation
     */
    function checkDelegateForToken(
        address delegate,
        address vault,
        address contract_,
        uint256 tokenId
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICryptoPunksMarket.sol";
import "./DelegationRegistry.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title InscriptionRegistry v1.1
 * @author Arkaydeus
 * @notice A registry of ETH NFT inscriptions on ordinals
 * This registry stores a record of BTC inscriptions that ETH tokenholders
 * have authorised in relation to their tokens.
 * Please visit https://app.bitcoll.org/collect/ethbtcmint for more information.
 */

contract InscriptionRegistry is Ownable {
    /// @notice Mapping from token to inscription Id
    mapping(address => mapping(uint256 => string)) public inscriptionByToken;

    /// @notice Mapping from token id to registrant address
    mapping(address => mapping(uint256 => address)) public addressByToken;

    /// @notice CrypptoPunksMarket contract address
    address public punkContractAddress;

    /// @notice Delegate.Cash contract address
    address public delegateCashAddress;

    /// @notice Emitted when a user sets an inscription
    event SetInscription(
        uint256 indexed tokenId,
        address indexed contractAddress,
        string inscription,
        address indexed registrant
    );

    constructor(address _punkContractAddress, address _delegateCashAddress) {
        punkContractAddress = _punkContractAddress;
        delegateCashAddress = _delegateCashAddress;
    }

    /// @notice Sets an inscription for a token id and contract address
    /// @notice Private function to be called by other functions
    /// @param _tokenId The token id
    /// @param _contractAddress The contract address for the NFT
    /// @param _inscription The inscription id to set
    function setInscription(
        uint256 _tokenId,
        address _contractAddress,
        string memory _inscription
    ) private {
        require(
            bytes(inscriptionByToken[_contractAddress][_tokenId]).length == 0,
            "Inscription already set"
        );

        inscriptionByToken[_contractAddress][_tokenId] = _inscription;
        addressByToken[_contractAddress][_tokenId] = msg.sender;

        emit SetInscription(
            _tokenId,
            _contractAddress,
            _inscription,
            msg.sender
        );
    }

    /// @notice Sets an inscription where the sender owns an ERC721
    /// @param _tokenId The token id
    /// @param _contractAddress The contract address for the NFT
    /// @param _inscription The inscription id to set
    function setInscriptionWithToken(
        uint256 _tokenId,
        address _contractAddress,
        string memory _inscription
    ) external {
        if (_contractAddress == punkContractAddress) {
            require(
                isWithPunk(_tokenId, msg.sender),
                "Punk not owned by sender"
            );
        } else {
            require(
                isWithERC721(_tokenId, _contractAddress, msg.sender),
                "Token not owned by sender"
            );
        }

        setInscription(_tokenId, _contractAddress, _inscription);
    }

    /// @notice Sets an inscription where the sender has a token delegated
    /// @param _tokenId The token id
    /// @param _contractAddress The contract address for the NFT
    /// @param _inscription The inscription id to set
    /// @param _tokenHolderAddress The address with the token in
    function setInscriptionWithDelegation(
        uint256 _tokenId,
        address _contractAddress,
        string memory _inscription,
        address _tokenHolderAddress
    ) external {
        if (_contractAddress == punkContractAddress) {
            require(
                isWithPunk(_tokenId, _tokenHolderAddress),
                "Punk not owned by address"
            );
        } else {
            require(
                isWithERC721(_tokenId, _contractAddress, _tokenHolderAddress),
                "Token not owned by address"
            );
        }

        require(
            isWithDelegation(_tokenId, _contractAddress, _tokenHolderAddress),
            "Token not delegated to sender"
        );

        setInscription(_tokenId, _contractAddress, _inscription);
    }

    /// @notice Checks if a punk is owned by a given address
    /// @param _tokenId The token id
    /// @param _punkHolderAddress The address to check
    function isWithPunk(uint256 _tokenId, address _punkHolderAddress)
        private
        view
        returns (bool)
    {
        return
            ICryptoPunksMarket(punkContractAddress).punkIndexToAddress(
                _tokenId
            ) == _punkHolderAddress;
    }

    /// @notice Checks if an ERC721 is owned by a given address
    /// @param _tokenId The token id
    /// @param _contractAddress The contract address for the NFT
    /// @param _tokenHolderAddress The address to check
    function isWithERC721(
        uint256 _tokenId,
        address _contractAddress,
        address _tokenHolderAddress
    ) private view returns (bool) {
        return
            IERC721(_contractAddress).ownerOf(_tokenId) == _tokenHolderAddress;
    }

    /// @notice Checks if a token is delegated to a given address
    /// @param _tokenId The token id
    /// @param _contractAddress The contract address for the NFT
    /// @param _tokenHolderAddress The address to check
    function isWithDelegation(
        uint256 _tokenId,
        address _contractAddress,
        address _tokenHolderAddress
    ) private view returns (bool) {
        return
            IDelegationRegistry(delegateCashAddress).checkDelegateForToken(
                msg.sender,
                _tokenHolderAddress,
                _contractAddress,
                _tokenId
            );
    }
}