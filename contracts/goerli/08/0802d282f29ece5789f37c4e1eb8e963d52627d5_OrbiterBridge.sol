/**
 *Submitted for verification at Etherscan.io on 2022-12-05
*/

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


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

// File: contracts/XVM.sol

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;


interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract OrbiterBridge is ReentrancyGuard {
    constructor() {}

    event SwapEvent(address maker, address token, uint256 value, bytes[] data);
    event SwapFailEvent(
        bytes32 tradeId,
        address token,
        address to,
        uint256 value
    );

    event SwapOKEvent(
        bytes32 tradeId,
        address token,
        address to,
        uint256 value
    );

    function transfer(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "ERROR");
    }

    function transferERC20(
        address token,
        address to,
        uint256 value
    ) internal {
        bool success = IERC20(token).transferFrom(msg.sender, to, value);
        require(success, "ERROR");
    }

    function swap(
        address payable maker,
        address token,
        uint256 value,
        bytes[] calldata data
    ) external payable nonReentrant {
        //  expect=> chainId,token,address,value
        if (token == address(0)) {
            transfer(maker, msg.value);
            emit SwapEvent(maker, address(0), msg.value, data);
        } else {
            transferERC20(token, maker, value);
            emit SwapEvent(maker, token, value, data);
        }
    }

    function swapFail(
        bytes32 tradeId,
        address token,
        address to,
        uint256 value
    ) external payable nonReentrant {
        if (token == address(0)) {
            transfer(to, msg.value);
            emit SwapFailEvent(tradeId, address(0), to, msg.value);
        } else {
            transferERC20(token, to, value);
            emit SwapFailEvent(tradeId, token, to, value);
        }
    }

    function swapOK(
        bytes32 tradeId,
        address token,
        address to,
        uint256 value
    ) external payable nonReentrant {
        if (token == address(0)) {
            transfer(to, msg.value);
            emit SwapOKEvent(tradeId, address(0), to, msg.value);
        } else {
            transferERC20(token, to, value);
            emit SwapOKEvent(tradeId, token, to, value);
        }
    }
}