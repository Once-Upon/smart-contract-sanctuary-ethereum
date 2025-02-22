// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
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
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
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
        require(paused(), "Pausable: not paused");
        _;
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
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

//*~~~> SPDX-License-Identifier: MIT OR Apache-2.0
/*~~~>
    Thank you Phunks, your inspiration and phriendship meant the world to me and helped me through hard times.
      Never stop phighting, never surrender, always stand up for what is right and make the best of all situations towards all people.
      Phunks are phreedom phighters!
        "When the power of love overcomes the love of power the world will know peace." - Jimi Hendrix <3

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################%%%%%@@@@@((((((((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################%%%%%@@@@@((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@########################################%%%%%@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@########################################%%%%%@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@###############@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@###############@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@@@@@%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@##########@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@@@@@%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@##########@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@#PHUNKYJON///////////////#PHUNKYJON//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@#PHUNKYJON///////////////#PHUNKYJON//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////@EYES////////////////////@EYES///////////////@@@@@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////@EYES////////////////////@EYES///////////////[email protected]@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////////////////////////////////////////////[email protected]@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////////////////////////////////////////////[email protected]@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@@@@@@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@@@@@@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////[email protected]@////////////////////#####@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////[email protected]@////////////////////#####@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@#####//////////////////////////////##########@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@#####//////////////////////////////##########@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@###################################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@###################################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((EMBER(((((,,,,,,,,,,,,,,,,,,,,,,,,,@@@@@MOUTH&&&&&####################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((EMBER(((((,,,,,,,,,,,,,,,,,,,,,,,,,@@@@@MOUTH&&&&&####################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@##############################/////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@##############################/////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@///////////////@@@@@%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@///////////////@@@@@%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 <~~~*/
pragma solidity  >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/*~~~>
Interface declarations for upgradable contracts
<~~~*/
interface NFTMkt {
  function transferNftForSale(address receiver, uint itemId) external;
}
interface Rewards {
  function depositERC20Rewards(uint amount, address tokenAdd) external;
}
interface IERC20 {
  function balanceOf(address account) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
interface RoleProvider {
  function hasTheRole(bytes32 role, address _address) external returns(bool);
  function fetchAddress(bytes32 _var) external returns(address);
  function getFee() external returns(uint);
}
interface Bids {
  function fetchBidId(uint marketId) external returns(uint);
  function refundBid(uint bidId) external;
}
interface Trades {
  function fetchTradeId(uint marketId) external returns(uint);
  function refundTrade(uint itemId, uint tradeId) external;
}
interface Collections {
  function fetchCollection(address nftContract) external returns(bool);
  function canOfferToken(address token) external returns(bool);
}

contract MarketOffers is ReentrancyGuard, Pausable {
  using SafeMath for uint;
  using Counters for Counters.Counter;
  //*~~~> counter increments NFTs Offers
  Counters.Counter private _offerIds;

  //*~~~> counter increments Blind Offers
  Counters.Counter private _blindOfferIds;

  //*~~~> Roles for designated accessibility
  bytes32 public constant PROXY_ROLE = keccak256("PROXY_ROLE"); 
  bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
  bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");
  modifier hasAdmin(){
    require(RoleProvider(roleAdd).hasTheRole(PROXY_ROLE, msg.sender), "DOES NOT HAVE ADMIN ROLE");
    _;
  }
  modifier hasContractAdmin(){
    require(RoleProvider(roleAdd).hasTheRole(CONTRACT_ROLE, msg.sender), "DOES NOT HAVE CONTRACT ROLE");
    _;
  }
  modifier hasDevAdmin(){
    require(RoleProvider(roleAdd).hasTheRole(DEV_ROLE, msg.sender), "DOES NOT HAVE DEV ROLE");
    _;
  }

  //*~~~> State variables
  address public roleAdd;
  uint[] private openStorage;
  uint[] private blindOpenStorage;

  //*~~~> global address variable from Role Provider contract
  bytes32 public constant NFTADD = keccak256("NFT");

  bytes32 public constant REWARDS = keccak256("REWARDS");

  bytes32 public constant MARKET = keccak256("MARKET");

  bytes32 public constant BIDS = keccak256("BIDS");
  
  bytes32 public constant TRADES = keccak256("TRADES");

  bytes32 public constant MINT = keccak256("MINT");

  bytes32 public constant COLLECTION = keccak256("COLLECTION");


  //*~~~> sets deployment address as default admin role
  constructor(address _role) {
    roleAdd = _role;
  }

  //*~~~> Declaring object structures for market item offers
  struct Offer {
    bool isActive;
    uint offerId;
    uint itemId;
    uint amount;
    address tokenCont;
    address payable offerer;
    address seller;
  }

  //*~~~> Declaring object structures for blind offers
  struct BlindOffer {
    bool isSpecific;
    uint amount1155;
    uint tokenId;
    uint blindOfferId;
    uint amount;
    address tokenCont;
    address collectionOffer;
    address payable offerer;
  }

  //*~~~> Mapping of all Offers
  mapping (uint => Offer) private idToMktOffer;
  //*~~~> Mapping of all Blind Offers
  mapping (uint => BlindOffer) private idToBlindOffer;
  //*~~~> Mapping of market itemId to offerId
  mapping (uint => uint) private marketIdToOfferId;

  //*~~~> Declaring event object struct for market item offers
  event Offered(
    uint offerId,
    uint indexed itemId,
    address indexed seller,
    address indexed offerer,
    uint amount
  );

  //*~~~> Declaring event object struct for blind offer
  event BlindOffered(
    bool isSpecific,
    uint tokenId,
    uint offerId,
    uint amount,
    address indexed offerer,
    address indexed collectionOffer
  );
  
  //*~~~> Declaring the object structure for offer withdrawn
  event OfferWithdrawn(
    uint indexed offerId,
    uint indexed itemId,
    address indexed offerer
  );

  //*~~~> Declaring the object structure for blind offer withdrawn
  event BlindOfferWithdrawn(
    uint indexed offerId,
    address indexed offerer
  );
  
  //*~~~> Declaring the object structure for offer accepted
  event OfferAccepted(
    uint offerId,
    uint indexed itemId,
    address indexed offerer,
    address indexed seller
  );

  //*~~~> Declaring event object structure for offer refund
  event OfferRefunded(
    uint indexed offerId,
    uint indexed itemId,
    address indexed offerer
  );

  /*~~~> Allowing for upgradability of proxy addresses <~~~*/
  function setRoleAdd(address _role) public hasAdmin returns(bool){
    roleAdd = _role;
    return true;
  }

  /// @notice 
  /*~~~> 
    Calculating the platform fee, 
      Base fee set at 2% (i.e. value * 200 / 10,000) 
      Future fees can be set by the controlling DAO 
    <~~~*/
  /// @return platform fee
  function calcFee(uint256 _value) public returns (uint256)  {
      uint fee = RoleProvider(roleAdd).getFee();
      uint256 percent = (_value.mul(fee)).div(10000);
      return percent;
    }

  ///@notice 
  /*~~~>
    Public function to offer ERC20 tokens to swap with any ERC721 or ERC1155
  <~~~*/
  ///@dev
  /*~~~>
    itemId: market item Id;
    amount: ERC20 amount;
    tokenCont: Contract of token to be offered;
    seller: ownerOf the NFT item listed for sale
  <~~~*/
  ///@return Bool
  function enterOfferForNft(
    uint256[] memory itemId,
    uint[] memory amount,
    address[] memory tokenCont,
    address[] memory seller
  ) public nonReentrant returns(bool){

    address collsAdd = RoleProvider(roleAdd).fetchAddress(COLLECTION);

      for (uint i; i< itemId.length; i++) {
      require(Collections(collsAdd).canOfferToken(tokenCont[i]),"Unknown token!");
      require (amount[i] > 0,"Amount needs to be > 0");
      
      IERC20 tokenContract = IERC20(tokenCont[i]);
      uint256 allowance = tokenContract.allowance(msg.sender, address(this));
      require(allowance >= amount[i], "Check the token allowance");
      (tokenContract).transferFrom(msg.sender, (address(this)), amount[i]);

      uint offerId;
      uint len = openStorage.length;
      if (len>=1) {
        offerId = openStorage[len-1];
        _remove(0);
      } else {
        _offerIds.increment();
        offerId = _offerIds.current();
      }
      idToMktOffer[offerId] = Offer(true, offerId, itemId[i], amount[i], tokenCont[i], payable(msg.sender), seller[i]);
      marketIdToOfferId[itemId[i]] = offerId;
      emit Offered(
        offerId, 
        itemId[i],
        seller[i],
        payable(msg.sender),
        amount[i]);
      }
    return true;
  }

  ///@notice
  /*~~~> 
    Public function to enter blind offer for specific or collection-wide NFT(s)
  <~~~*/
  ///@dev
  /*~~~>
    isSpecific: (true) if the offer is for a specific NFT, else false;
    amount1155: how many 1155 desired?
    tokenId: Id of specific NFT offered in exchange for ERC20;
    amount: amount of ERC20 tokens to offer;
    tokenCont: token contract address of the offer;
    collection: Collection address of the desired NFT(s)
  <~~~*/
  function enterBlindOffer(
    bool[] memory isSpecific,
    uint[] memory amount1155,
    uint[] memory tokenId,
    uint[] memory amount,
    address[] memory tokenCont,
    address[] memory collection
  ) public nonReentrant{
    for (uint i; i<tokenCont.length;i++){
      
      address collsAdd = RoleProvider(roleAdd).fetchAddress(COLLECTION);

      uint256 allowance = IERC20(tokenCont[i]).allowance(msg.sender, address(this));
      require(allowance >= amount[i], "Check the token allowance");
      require(Collections(collsAdd).fetchCollection(collection[i]) == false);
      IERC20(tokenCont[i]).transferFrom(msg.sender, (address(this)), amount[i]);

      uint offerId;
      uint len = blindOpenStorage.length;
      if (len>=1) {
        offerId = blindOpenStorage[len-1];
        _remove(1);
      } else {
        _blindOfferIds.increment();
        offerId = _blindOfferIds.current();
      }
      idToBlindOffer[offerId] = BlindOffer(isSpecific[i], amount1155[i], tokenId[i], offerId, amount[i], tokenCont[i], collection[i], payable(msg.sender));
      emit BlindOffered(
        isSpecific[i],
        tokenId[i],
        offerId,
        amount[i],
        payable(msg.sender),
        tokenCont[i]
      );
    }

  }

  ///@notice
  /*~~~>
    Public offer to accept blind offer in exchange for NFT;
    If specific, only the NFT owner can call.
      else, any collection holder can accept the offer;
  <~~~*/
  ///@dev 
  /*~~~>
    
    blindOfferId: internal Id of blind offer;
    tokenId: token Id of the NFT to swap;
    offerId: offer Id if the item is listed between the time the offer was made and accepted;
    listedId: listed items Id from the marketplace;
    isListed: (true) if item is listed on the marketplace;
    is1155: (true) if NFT desired is ERC1155;
  <~~~*/
  function acceptBlindOffer(
    uint[] memory blindOfferId,
    uint[] memory tokenId,
    uint[] memory offerId,
    uint[] memory listedId,
    bool[] memory isListed,
    bool[] memory is1155
  ) public nonReentrant returns(bool){

    address rewardsAdd = RoleProvider(roleAdd).fetchAddress(REWARDS);
    address mrktAdd = RoleProvider(roleAdd).fetchAddress(MARKET);

    uint balance = IERC721(RoleProvider(roleAdd).fetchAddress(NFTADD)).balanceOf(msg.sender);
    for (uint i; i<blindOfferId.length;i++){
      BlindOffer memory offer = idToBlindOffer[blindOfferId[i]];
      IERC20 tokenContract = IERC20(offer.tokenCont);
      if(balance<1){
        /// Calculate fee and send to rewards contract
        uint256 salefee = calcFee(offer.amount);
        uint256 userAmnt = offer.amount.sub(salefee);
        /// send (salefee) to rewards contract
        Rewards(rewardsAdd).depositERC20Rewards(salefee, offer.tokenCont);
         /// send (offerAmount - salefee) to user  
        (tokenContract).transfer(payable(msg.sender), userAmnt);
      } else {
        (tokenContract).transfer(payable(msg.sender), offer.amount);
      }
      if(offer.isSpecific){
        require(tokenId[i]==offer.tokenId,"Wrong item!");
      }
      if(isListed[i]){
        NFTMkt(mrktAdd).transferNftForSale(offer.offerer, listedId[i]);
      } else {
        if (is1155[i]){
          IERC1155(offer.collectionOffer).safeTransferFrom(address(this), msg.sender, tokenId[i], offer.amount1155, "");
        } else {
          transferFromERC721(offer.collectionOffer, tokenId[i], offer.offerer);
        }
      }
      blindOpenStorage.push(offerId[i]);
      idToBlindOffer[offerId[i]] = BlindOffer(false, 0, 0, offerId[i], 0, address(0x0), address(0x0), payable(0x0));
    }
    return true;
  }

  ///@notice
  /*~~~>
    public function to accept an offer for a listed NFT on the market
  <~~~*/
  ///@dev
  /*~~~>
    offerId: Internal id of offer;
  <~~~*/
  ///@return Bool
  function acceptOfferForNft(uint[] calldata offerId) public nonReentrant returns(bool){

    address mrktNft = RoleProvider(roleAdd).fetchAddress(NFTADD);
    address rewardsAdd = RoleProvider(roleAdd).fetchAddress(REWARDS);
    address bidsAdd = RoleProvider(roleAdd).fetchAddress(BIDS);
    address tradesAdd = RoleProvider(roleAdd).fetchAddress(TRADES);
    address mrktAdd = RoleProvider(roleAdd).fetchAddress(MARKET);

    uint balance = IERC721(mrktNft).balanceOf(msg.sender);
    for (uint i; i<offerId.length; i++) {
      Offer memory offer = idToMktOffer[offerId[i]];
      if (msg.sender != offer.seller) revert();
      IERC20 tokenContract = IERC20(offer.tokenCont);
      if(balance<1){
        /// Calculate fee and send to rewards contract
        uint256 fee = calcFee(offer.amount);
        uint256 userAmnt = offer.amount.sub(fee);
        Rewards(rewardsAdd).depositERC20Rewards(fee, offer.tokenCont);
        (tokenContract).transfer(rewardsAdd, fee);
        (tokenContract).transfer(payable(offer.seller), userAmnt);
      } else {
        (tokenContract).transfer(payable(offer.seller), offer.amount);
      }
      if (Bids(bidsAdd).fetchBidId(offer.itemId) > 0) {
      /*~~~> Kill bid and refund bidValue <~~~*/
        //~~~> Call the contract to refund the ETH offered for a bid
        Bids(bidsAdd).refundBid(Bids(bidsAdd).fetchBidId(offer.itemId));
      }
      /*~~~> Check for the case where there is an offer and refund it. <~~~*/
      if (Trades(tradesAdd).fetchTradeId(offer.itemId) > 0) {
      /*~~~> Kill offer and refund amount <~~~*/
        //*~~~> Call the contract to refund the ERC20 offered for trade
        Trades(tradesAdd).refundTrade(offer.itemId, Trades(tradesAdd).fetchTradeId(offer.itemId));
      }
      marketIdToOfferId[offer.itemId] = 0;
      openStorage.push(offerId[i]);
      idToMktOffer[offerId[i]] = Offer(false, offerId[i], 0, 0, address(0x0), payable(0x0), address(0x0));
      NFTMkt(mrktAdd).transferNftForSale(offer.offerer, offer.itemId);
      emit OfferAccepted(
        offerId[i],
        offer.itemId,
        offer.offerer,
        offer.seller
      );
    }
    return true;
  }

  ///@notice
  /*~~~>
    Public function to withdraw offers that only offer owners can call
  <~~~*/
  ///@dev
  /*~~~>
    offerId: internal Id of the offer item
    isBlind: external bool needed to determine type of offer
  <~~~*/
  function withdrawOffer(uint[] memory offerId, bool[] memory isBlind) public nonReentrant returns(bool){
    for (uint i; i< offerId.length; i++) {
    if (isBlind[i]){
      BlindOffer memory offer = idToBlindOffer[offerId[i]];
      ///*~~~> Require the message sender to be the offerer
      if (offer.offerer != msg.sender) revert();
      IERC20 tokenContract = IERC20(offer.tokenCont);
      (tokenContract).transfer(payable(offer.offerer), offer.amount);
      /// push old offerId to blind open storage
      blindOpenStorage.push(offerId[i]);
      idToBlindOffer[offerId[i]] = BlindOffer(false, 0, 0, offerId[i], 0, address(0x0), address(0x0), payable(0x0));
      emit BlindOfferWithdrawn(
        offerId[i],
        msg.sender);
    } else {
      Offer memory offer = idToMktOffer[offerId[i]];
      if (offer.offerer != msg.sender) revert();
      IERC20 tokenContract = IERC20(offer.tokenCont);
      (tokenContract).transfer(payable(offer.offerer), offer.amount);
      /// push old offerId to open storage
      openStorage.push(offerId[i]);
      /// reset offerId
      marketIdToOfferId[offer.itemId] = 0;
      idToMktOffer[offerId[i]] = Offer(false, offerId[i], 0, 0, address(0x0), payable(0x0), address(0x0));
      emit OfferWithdrawn(
        offerId[i], 
        offer.itemId,
        msg.sender);
      }
    }
    return true;
  }

  ///@notice 
  /*~~~>
    Only Contract function used for manually refunding offers when items sell
  <~~*/
  ///@dev
  /*~~~>
    itemId: Market storage Id of the item to be refunded
    offerId: Internal storage Id of the offer
  <~~~*/
  function refundOffer(uint itemId, uint offerId) public nonReentrant hasContractAdmin returns(bool){
      Offer memory _offer = idToMktOffer[itemId];
      /// verifying that the refunded offer is the correct one
      require(_offer.offerId == offerId);
      IERC20 tokenContract = IERC20(_offer.tokenCont);
      (tokenContract).transfer(payable(_offer.offerer), _offer.amount);
      /// recycle old offerId
      openStorage.push(offerId);
      /// reset internal memory of itemId
      marketIdToOfferId[itemId] = 0;
      idToMktOffer[offerId] = Offer(false, offerId, 0, 0, address(0x0), payable(address(0x0)), address(0x0));
      emit OfferRefunded(offerId, itemId, _offer.offerer);
    return true;
  }

  /// @notice 
    /*~~~> 
      Internal function to transfer ERC721 NFTs, including crypto kitties/punks
    <~~~*/
  /// @dev
    /*~~~>
      assetAddr: address of the token to be transfered;
      tokenId: Id of the token to be transfered;
    <~~~*/
function transferFromERC721(address assetAddr, uint256 tokenId, address to) internal virtual {
    address kitties = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;
    address punks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    bytes memory data;
    if (assetAddr == kitties) {
        //*~~~> Cryptokitties.
        data = abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, to, tokenId);
    } else if (assetAddr == punks) {
        //*~~~> CryptoPunks.
        bytes memory punkIndexToAddress = abi.encodeWithSignature("punkIndexToAddress(uint256)", tokenId);
        (bool checkSuccess, bytes memory result) = address(assetAddr).staticcall(punkIndexToAddress);
        (address nftOwner) = abi.decode(result, (address));
        require(checkSuccess && nftOwner == msg.sender, "Not the NFT owner");
        data = abi.encodeWithSignature("transferPunk(address,uint256)", msg.sender, tokenId);
    } else {
        //*~~~> Default.
        //*~~~> We push to avoid an unneeded transfer.
        data = abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", msg.sender, to, tokenId);
    }
    (bool success, bytes memory resultData) = address(assetAddr).call(data);
    require(success, string(resultData));
  }

  /// @notice 
  /*~~~> 
    Internal function for removing elements from an array
    Only used for internal storage array index recycling
      In order to reduce storage array size of listed items 
        while maintaining specific enumerable bidId's, 
        any sold or removed item spots are re-used by referring to their index,
        else a new storage spot is created;

        We use the last item in the storage (length of array - 1),
        in order to pop off the item and avoid rewriting 
  <~~~*/
  function _remove(uint store) internal {
      if (store==0){
        openStorage.pop();
      } else if (store==1){
        blindOpenStorage.pop();
      }
    }

  ///@notice //*~~~> Public read function of internal state
  function fetchOffers() public view returns (Offer[] memory) {
    uint itemCount = _offerIds.current();
    Offer[] memory items = new Offer[](itemCount);
    for (uint i; i < itemCount; i++) {
      if (idToMktOffer[i + 1].isActive == true) {
        Offer storage currentItem = idToMktOffer[i + 1];
        items[i] = currentItem;
      }
    }
  return items;
  }

  ///@notice //*~~~> Public read function of internal state
  function fetchOffersByItemId(uint itemId) public view returns (Offer[] memory) {
    uint itemCount = _offerIds.current();
    Offer[] memory items = new Offer[](itemCount);
    for (uint i; i < itemCount; i++) {
      if (idToMktOffer[i + 1].isActive == true) {
        if (idToMktOffer[i + 1].itemId == itemId){
          Offer storage currentItem = idToMktOffer[i + 1];
          items[i] = currentItem;
        }
      }
    }
  return items;
  }

  function fetchOffersByOfferer(address user) public view returns (Offer[] memory) {
    uint itemCount = _offerIds.current();
    Offer[] memory items = new Offer[](itemCount);
    for (uint i; i < itemCount; i++) {
      if (idToMktOffer[i + 1].isActive == true) {
        if (idToMktOffer[i + 1].offerer == user){
          Offer storage currentItem = idToMktOffer[i + 1];
          items[i] = currentItem;
        }
      }
    }
  return items;
  }

  function fetchBlindOffers() public view returns (BlindOffer[] memory) {
    uint itemCount = _blindOfferIds.current();
    BlindOffer[] memory items = new BlindOffer[](itemCount);
    for (uint i; i < itemCount; i++) {
      BlindOffer storage currentItem = idToBlindOffer[i + 1];
      items[i] = currentItem;
    }
  return items;
  }

  function fetchBlindOffersByOfferer(address user) public view returns (BlindOffer[] memory) {
    uint itemCount = _blindOfferIds.current();
    BlindOffer[] memory items = new BlindOffer[](itemCount);
    for (uint i; i < itemCount; i++) {
      if (idToBlindOffer[i + 1].offerer == user){
        BlindOffer storage currentItem = idToBlindOffer[i + 1];
        items[i] = currentItem;
      }
    }
  return items;
  }

  function fetchOfferId(uint itemId) public view returns (uint) {
    uint _id = marketIdToOfferId[itemId];
    return _id;
  }

  ///@notice DEV operations for emergency functions
  function pause() public hasDevAdmin {
      _pause();
  }
  function unpause() public hasDevAdmin {
      _unpause();
  }

  ///@notice
  /*~~~> External ETH transfer forwarded to role provider contract <~~~*/
  event FundsForwarded(uint value, address _from, address _to);
  receive() external payable {
    payable(roleAdd).transfer(msg.value);
      emit FundsForwarded(msg.value, msg.sender, roleAdd);
  }
}