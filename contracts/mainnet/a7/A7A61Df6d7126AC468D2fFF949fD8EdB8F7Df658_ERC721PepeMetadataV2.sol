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

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./HexStringsV2.sol";
import "./interfaces/IERC721PepeMetadataV2.sol";
import "./interfaces/IMetadataOverrides.sol";


contract ERC721PepeMetadataV2 is IERC721PepeMetadataV2, Ownable {
    using HexStringsV2 for uint256;

    address public metadataOverridesContract;
    address public pepeContract;
    string public baseURI = "";
    mapping(address => bool) public mcManagers;

    event McManagerAdded(address newMcManager, address owner);
    event McManagerRemoved(address removedMcManager, address owner);

    constructor(string memory baseURI_) {
        baseURI = baseURI_;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function setPepeContract(address _pepeContract) external onlyOwner {
        pepeContract = _pepeContract;
    }

    function setMetadataOverridesContract(address _metadataOverridesContract) external onlyOwner {
        metadataOverridesContract = _metadataOverridesContract;
    }

    function overrideMetadata(uint256 hash, string memory uri, string memory reason) external {
        require(msg.sender == owner() || mcManagers[msg.sender], "Only owner or McManager may override metadata");
        IMetadataOverrides(metadataOverridesContract).overrideMetadata(hash, uri, reason);
    }

    function overrideMetadataBulk(uint256[] memory hashes, string[] memory uris, string[] memory reasons) external {
        require(msg.sender == owner() || mcManagers[msg.sender], "Only owner or McManager may override metadata");
        IMetadataOverrides(metadataOverridesContract).overrideMetadataBulk(hashes, uris, reasons);
    }

    function addMcManager(address newMcManager) public onlyOwner {
        emit McManagerAdded(newMcManager, owner());
        mcManagers[newMcManager] = true;
    }

    function removeMcManager(address removedMcManager) public onlyOwner {
        emit McManagerRemoved(removedMcManager, owner());
        mcManagers[removedMcManager] = false;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     * https://docs.ipfs.tech/concepts/hashing/
     */
    function tokenURI(uint256 hash) public view returns (string memory) {
        // check for uri override, and return that instead
        string memory metadataOverride = IMetadataOverrides(metadataOverridesContract).metadataOverrides(hash);
        if (bytes(metadataOverride).length != 0) {
            return metadataOverride;
        }

        return string(abi.encodePacked(baseURI, hash.uint2hexstr(), ".json"));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library HexStringsV2 {
    function uint2hexstr(uint256 i) internal pure returns (string memory) {
        if (i == 0) return "0000000000000000000000000000000000000000000000000000000000000000";
        uint256 length = 64;
        uint256 mask = 15;
        bytes memory bstr = new bytes(length);
        uint256 j = length;
        while (j != 0) {
            uint256 curr = (i & mask);
            bstr[--j] = curr > 9 ? bytes1(uint8(87 + curr)) : bytes1(uint8(48 + curr));
            i = i >> 4;
        }
        return string(bstr);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.9;

interface IERC721PepeMetadataV2 {
	
	function setBaseURI(string memory uri) external;
	
	function setPepeContract(address _pepe) external;
	
	function tokenURI(uint256 hash) external view returns (string memory);
			
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IMetadataOverrides {
    function metadataOverrides(uint hash) external view returns (string memory);
    function overrideMetadata(uint256 hash, string memory uri, string memory reason) external;
    function overrideMetadataBulk(uint256[] memory hashes, string[] memory uris, string[] memory reasons) external;
}