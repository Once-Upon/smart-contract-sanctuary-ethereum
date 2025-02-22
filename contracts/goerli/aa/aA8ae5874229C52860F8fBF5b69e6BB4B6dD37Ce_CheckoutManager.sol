/**
 *Submitted for verification at Etherscan.io on 2021-03-30
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CheckoutManager is ReentrancyGuard {
    address public admin;
    address payable public vaultWallet;

    event BuyItems(
        string orderId,
        string buyerId,
        address buyer,
        string[] itemIds,
        uint256[] amounts
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(address payable _vaultWallet) {
        require(_vaultWallet != address(0), "Invalid vault address");
        admin = msg.sender;
        vaultWallet = _vaultWallet;
    }

    function buyItems(
        string calldata orderId,
        string calldata buyerId,
        string[] calldata itemIds,
        uint256[] calldata amounts
    ) external payable nonReentrant {
        require(msg.value > 0, "Wrong ETH value!");
        require(itemIds.length > 0, "No items");
        require(
            itemIds.length == amounts.length,
            "Items and amounts length should be the same"
        );

        (bool sent,) = vaultWallet.call{value: msg.value}("");
        require(sent, "buyItem: Failed to send Ether");

        emit BuyItems(orderId, buyerId, msg.sender, itemIds, amounts);
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");

        admin = _newAdmin;
    }

    function setVaultAddress(address payable _vaultWallet) public onlyAdmin {
        require(_vaultWallet != address(0), "Invalid vault address");

        vaultWallet = _vaultWallet;
    }
}

// SPDX-License-Identifier: MIT

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
     * by making the `nonReentrant` function external, and make it call a
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