// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Kenomi is Ownable {
    struct WhiteListItem {
        uint256 supply;
        uint256 pricePerItem;
        string description;
        string title;
    }
    mapping(address => bool) public adminMapping;

    WhiteListItem[] public whiteListItems;
    mapping(uint256 => WhiteListItem) public whiteListItemsMapping;

    mapping(address => WhiteListItem[]) public ownedItems;

    function addAdmin(address _address) external onlyOwner {
        adminMapping[_address] = true;
    }

    function removeAdmin(address _address) external onlyOwner {
        adminMapping[_address] = false;
    }

    modifier onlyOwnerOrAdmin() {
        require(
            msg.sender == owner() || adminMapping[msg.sender],
            "Function only accessible to Admin and Owner"
        );
        _;
    }

    function getAllItems() external view returns(WhiteListItem[] memory) {
        return whiteListItems;
    }

    function addItem(WhiteListItem memory whiteListItem)
        external
        onlyOwnerOrAdmin
    {
        whiteListItems.push(whiteListItem);
        whiteListItemsMapping[whiteListItems.length-1] = whiteListItem;
    }

    function buyItem(uint256 itemIndex, uint256 amount) external payable {
        WhiteListItem memory item = whiteListItemsMapping[itemIndex];

        require(item.supply >= amount, "Not enough supply");
        require(msg.value == item.pricePerItem * amount, "Not enough value");

        whiteListItemsMapping[itemIndex].supply -= amount;
        whiteListItems[itemIndex].supply -= amount;

        WhiteListItem memory owned = WhiteListItem(
            amount,
            item.pricePerItem,
            item.description,
            item.title
        );
        ownedItems[msg.sender].push(owned);
    }

    function withDraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

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