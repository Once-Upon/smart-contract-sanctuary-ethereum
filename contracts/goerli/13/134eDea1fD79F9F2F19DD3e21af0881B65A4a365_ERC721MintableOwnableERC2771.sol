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

pragma solidity ^0.8.15;

/**
 * @title Contract ownership standard interface (event only)
 * @dev see https://eips.ethereum.org/EIPS/eip-173
 */
interface IERC173Events {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Context.sol";

import "./OwnableStorage.sol";
import "./IERC173Events.sol";

abstract contract OwnableInternal is IERC173Events, Context {
    using OwnableStorage for OwnableStorage.Layout;

    modifier onlyOwner() {
        require(_msgSender() == _owner(), "Ownable: sender must be owner");
        _;
    }

    function _owner() internal view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function _transferOwnership(address account) internal virtual {
        OwnableStorage.layout().setOwner(account);
        emit OwnershipTransferred(_msgSender(), account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

library OwnableStorage {
    struct Layout {
        address owner;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("openzeppelin.contracts.storage.Ownable");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function setOwner(Layout storage l, address owner) internal {
        l.owner = owner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * The caller must be the current contract itself.
 */
error ErrSenderIsNotSelf();

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Context.sol";

import "./ERC2771ContextStorage.sol";

abstract contract ERC2771ContextInternal is Context {
    function _isTrustedForwarder(address operator) internal view returns (bool) {
        return ERC2771ContextStorage.layout().trustedForwarder == operator;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (_isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (_isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

library ERC2771ContextStorage {
    struct Layout {
        address trustedForwarder;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("openzeppelin.contracts.storage.ERC2771Context");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @dev Extension of {ERC721A} that allows other facets from the diamond to mint tokens.
 */
interface IERC721MintableExtension {
    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC721A-_mint}.
     *
     * Requirements:
     *
     * - the caller must be diamond itself (other facets).
     */
    function mintByFacet(address to, uint256 amount) external;

    function mintByFacet(address[] memory tos, uint256[] memory amounts) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../../../../common/Errors.sol";
import "../../../../access/ownable/OwnableInternal.sol";
import "../../extensions/mintable/IERC721MintableExtension.sol";
import "./IERC721MintableOwnable.sol";

/**
 * @title ERC721 - Mint as owner
 * @notice Allow minting as contract owner with no restrictions (supports ERC721A).
 *
 * @custom:type eip-2535-facet
 * @custom:category NFTs
 * @custom:required-dependencies IERC721MintableExtension
 * @custom:provides-interfaces IERC721MintableOwnable
 */
contract ERC721MintableOwnable is IERC721MintableOwnable, OwnableInternal {
    /**
     * @inheritdoc IERC721MintableOwnable
     */
    function mintByOwner(address to, uint256 amount) public virtual onlyOwner {
        IERC721MintableExtension(address(this)).mintByFacet(to, amount);
    }

    /**
     * @inheritdoc IERC721MintableOwnable
     */
    function mintByOwner(address[] calldata tos, uint256[] calldata amounts) public virtual onlyOwner {
        IERC721MintableExtension(address(this)).mintByFacet(tos, amounts);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../../../../metatx/ERC2771ContextInternal.sol";
import "./ERC721MintableOwnable.sol";

/**
 * @title ERC721 - Mint as owner - With ERC2771 Context
 * @notice Allow minting as owner via meta transactions, signed by the owner private key. (supports ERC721A)
 *
 * @custom:type eip-2535-facet
 * @custom:category NFTs
 * @custom:required-dependencies IERC721MintableExtension
 * @custom:provides-interfaces IERC721MintableOwnable
 */
contract ERC721MintableOwnableERC2771 is ERC721MintableOwnable, ERC2771ContextInternal {
    function _msgSender() internal view virtual override(Context, ERC2771ContextInternal) returns (address) {
        return ERC2771ContextInternal._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771ContextInternal) returns (bytes calldata) {
        return ERC2771ContextInternal._msgData();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @dev Extension of {ERC721} that allows diamond owner to mint tokens.
 */
interface IERC721MintableOwnable {
    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must be diamond owner.
     */
    function mintByOwner(address to, uint256 amount) external;

    function mintByOwner(address[] calldata tos, uint256[] calldata amounts) external;
}