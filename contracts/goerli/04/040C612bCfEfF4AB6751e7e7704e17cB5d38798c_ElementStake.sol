// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IERC1155Stone {
    function mintBaseElements(address to, uint256 amount, uint256 elementId) external;
}

interface IERC721Crystal {
    function elementIds(uint256) external view returns (uint256);

    function burnBatch(uint256[] calldata tokenIds) external;

    function safeTransferFrom(address, address, uint256) external payable;
}

contract ElementStake is Ownable, ReentrancyGuard, IERC721Receiver {
    IERC721Crystal public nftToken;
    IERC1155Stone public rewardToken;

    struct StakeData {
        uint256[] stakedTokenIds;
        uint256 lastStakeTime;
    }

    // staked elementId -> stake result elementId
    mapping(uint256 => uint256) public stakingMap;

    // staker address -> (elementId -> staked tokens data)
    mapping(address => mapping(uint256 => StakeData)) public stakeInfo;

    // todo: stake claim in 24 hours for example
    uint256 rewardTokenCount = 1; // token count per timePerReward
    uint256 timePerReward = 1; // 24 hours - rewardTokenCount per timePerReward

    constructor(IERC721Crystal _nftToken, IERC1155Stone _rewardToken) {
        nftToken = _nftToken;
        rewardToken = _rewardToken;
    }

    // ----------------------------------------------------
    //                      internal tools
    // ----------------------------------------------------
    function removeTokenId(uint256 index, uint256 elementId) internal {
        uint256[] storage tokenIds = stakeInfo[msg.sender][elementId].stakedTokenIds;
        tokenIds[index] = tokenIds[tokenIds.length - 1];
        tokenIds.pop();
    }

    function calculateReward(address staker, uint256 stakedElementId) public view returns (uint256 rewardCount) {
        StakeData storage stakeData = stakeInfo[staker][stakedElementId];

        uint256 pastTime = block.timestamp - stakeData.lastStakeTime;

        rewardCount = 0;
        if (pastTime >= timePerReward) {
            rewardCount = stakeData.stakedTokenIds.length * (pastTime / timePerReward);
        }

        return rewardCount;
    }

    function claimReward(address staker, uint256 stakedElementId) internal {
        uint256 rewardCount = calculateReward(staker, stakedElementId);

        rewardToken.mintBaseElements(staker, rewardCount, stakingMap[stakedElementId]);

        emit Claimed(staker, rewardCount, stakingMap[stakedElementId]);
    }

    // ----------------------------------------------------
    //                      main
    // ----------------------------------------------------
    function stakeMult(uint256 elementId, uint256[] calldata tokenIds) public nonReentrant {
        require(stakingMap[elementId] > 0, "Wrong elementId pool selected to stake");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                elementId == nftToken.elementIds(tokenIds[i]),
                "Wrong token: elementId and stake pool is not match"
            );
            stakeInfo[msg.sender][elementId].stakedTokenIds.push(tokenIds[i]);
            stakeInfo[msg.sender][elementId].lastStakeTime = block.timestamp;

            nftToken.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }

        emit NFTStake(msg.sender, elementId, tokenIds);
    }

    function unstake(uint256 elementId, uint256[] calldata tokenIds) public nonReentrant {
        StakeData storage staked = stakeInfo[msg.sender][elementId];

        require(
            staked.stakedTokenIds.length >= tokenIds.length,
            "Token count is wrong or This tokens not staked in this pool"
        );

        bool isTokenStaked;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            isTokenStaked = false;
            for (uint256 j = 0; j < staked.stakedTokenIds.length; j++) {
                if (tokenIds[i] == staked.stakedTokenIds[j]) {
                    removeTokenId(j, elementId);
                    isTokenStaked = true;
                    break;
                }
            }
            require(isTokenStaked, "This token not staked");
        }
        nftToken.burnBatch(tokenIds);
        claimReward(msg.sender, elementId);

        emit NFTUnstake(msg.sender, elementId, tokenIds);
    }

    // ----------------------------------------------------
    //                      admin
    // ----------------------------------------------------

    function updateReward(uint256 _rewardTokenCount, uint256 _timePerReward) external onlyOwner {
        rewardTokenCount = _rewardTokenCount;
        timePerReward = _timePerReward;
        emit RewardUpdate(_rewardTokenCount, _timePerReward);
    }

    // [[stake elementId, result elementId], [...]]
    function setStakeMap(uint256[2][] calldata elements) external onlyOwner {
        for (uint256 i = 0; i < elements.length; i++) {
            stakingMap[elements[i][0]] = elements[i][1];
        }
    }

    // events
    event NFTStake(address staker, uint256 stakingElementId, uint256[] tokenIds);
    event NFTUnstake(address staker, uint256 stakingElementId, uint256[] tokenIds);
    event Claimed(address staker, uint256 rewardTokenCount, uint256 rewardElementId);
    event RewardUpdate(uint256 rewardTokenCount, uint256 timePerReward);

    // -------------------------------------------------------------
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
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