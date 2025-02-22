// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Payments is Ownable, ReentrancyGuard {
    struct Plan {
        uint256 price;
        uint256 duration;
    }

    uint256 immutable daysToSeconds = 86400;
    bool saleLive = true;

    mapping(string => Plan) public paymentPlan;
    mapping(address => uint256) public expirationTime;

    event PlanPurchased(address indexed buyer, uint256 duration, uint256 purchaseTimestamp);

    constructor() {
        paymentPlan["1 day"] = Plan(0.015 ether, 1 * 86400);
        paymentPlan["30 days"] = Plan(0.08 ether, 30 * 86400);
        paymentPlan["90 days"] = Plan(0.2 ether, 90 * 86400);
        paymentPlan["180 days"] = Plan(0.35 ether, 180 * 86400);
    }

    function addExpirationTime(
        address _address, 
        uint256 _expTimestamp, 
        uint256 _days
    ) internal {
        // Method #1
        if (_expTimestamp > block.timestamp){
            expirationTime[_address] = _expTimestamp + _days * daysToSeconds;
        } else {
            expirationTime[_address] = block.timestamp + _days * daysToSeconds;
        }

        // Method #2
        expirationTime[_address] = _expTimestamp > block.timestamp 
            ? _expTimestamp + _days * daysToSeconds 
            : block.timestamp + _days * daysToSeconds;
    }

    function buySub(
        address _address, 
        string memory _plan
    ) public payable {
        uint256 expTimestamp = expirationTime[_address];
        // Sale is always open for users that already have a subscription
        if (expTimestamp == 0) {
            require(saleLive, "Sale is not live for new users.");
        }
        uint256 duration = paymentPlan[_plan].duration;
        require(duration > 0, "Plan does not exist.");
        require(msg.value == paymentPlan[_plan].price, "Incorrect value sent. Please send the correct value for the chosen Plan.");
        addExpirationTime(_address, expTimestamp, duration);
        emit PlanPurchased(_address, duration, block.timestamp);
    }

    function giftSub(
        address[] calldata _addresses, 
        uint256 _days
    ) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            address _address = _addresses[i];
            uint256 expTimestamp = expirationTime[_address];
            addExpirationTime(_address, expTimestamp, _days);
        }
    }

    function giftSubGPT(
        address[] calldata _addresses, 
        uint256 _days
    ) public onlyOwner {
        uint256 newExpirationTime;
        uint256 daysInSeconds = _days * daysToSeconds;
        for (uint256 i = 0; i < _addresses.length; i++) {
            address _address = _addresses[i];
            uint256 expTimestamp = expirationTime[_address];
            newExpirationTime = expTimestamp > block.timestamp ? expTimestamp + daysInSeconds : block.timestamp + daysInSeconds;
            expirationTime[_address] = newExpirationTime;
        }
    }

    function editPlan(
        string calldata _name, 
        uint256 _price, 
        uint256 _days
    ) public onlyOwner {
        uint256 _seconds = _days * daysToSeconds;
        paymentPlan[_name] = Plan(_price, _seconds);
    }

    function removeSub(
        address[] calldata _addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            address _address = _addresses[i];
            expirationTime[_address] = 0;
        }
    }

    function toggleSale() public onlyOwner {
	    saleLive = !saleLive;
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdraw failed. Please try again.");
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