/**
 *Submitted for verification at Etherscan.io on 2022-09-14
*/

// File: @openzeppelin/contracts/utils/Context.sol

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

// File: @openzeppelin/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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

// File: contracts/interfaces/IWalletManager.sol

// IWalletManager.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

/**
 * @title Particle Wallet Manager interface
 * @dev The wallet-manager for underlying assets attached to Charged Particles
 * @dev Manages the link between NFTs and their respective Smart-Wallets
 */
interface IWalletManager {
    event ControllerSet(address indexed controller);
    event ExecutorSet(address indexed executor);
    event PausedStateSet(bool isPaused);
    event NewSmartWallet(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed smartWallet,
        address creator,
        uint256 annuityPct
    );
    event WalletEnergized(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed assetToken,
        uint256 assetAmount,
        uint256 yieldTokensAmount
    );
    event WalletDischarged(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed assetToken,
        uint256 creatorAmount,
        uint256 receiverAmount
    );
    event WalletDischargedForCreator(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed assetToken,
        address creator,
        uint256 receiverAmount
    );
    event WalletReleased(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed receiver,
        address assetToken,
        uint256 principalAmount,
        uint256 creatorAmount,
        uint256 receiverAmount
    );
    event WalletRewarded(
        address indexed contractAddress,
        uint256 indexed tokenId,
        address indexed receiver,
        address rewardsToken,
        uint256 rewardsAmount
    );

    function isPaused() external view returns (bool);

    function isReserveActive(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external view returns (bool);

    function getReserveInterestToken(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external view returns (address);

    function getTotal(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external returns (uint256);

    function getPrincipal(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external returns (uint256);

    function getInterest(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external returns (uint256 creatorInterest, uint256 ownerInterest);

    function getRewards(
        address contractAddress,
        uint256 tokenId,
        address rewardToken
    ) external returns (uint256);

    function energize(
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        uint256 assetAmount
    ) external returns (uint256 yieldTokensAmount);

    function discharge(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        address creatorRedirect
    ) external returns (uint256 creatorAmount, uint256 receiverAmount);

    function dischargeAmount(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        uint256 assetAmount,
        address creatorRedirect
    ) external returns (uint256 creatorAmount, uint256 receiverAmount);

    function dischargeAmountForCreator(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address creator,
        address assetToken,
        uint256 assetAmount
    ) external returns (uint256 receiverAmount);

    function release(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        address creatorRedirect
    )
        external
        returns (
            uint256 principalAmount,
            uint256 creatorAmount,
            uint256 receiverAmount
        );

    function releaseAmount(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        uint256 assetAmount,
        address creatorRedirect
    )
        external
        returns (
            uint256 principalAmount,
            uint256 creatorAmount,
            uint256 receiverAmount
        );

    function withdrawRewards(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address rewardsToken,
        uint256 rewardsAmount
    ) external returns (uint256 amount);

    function executeForAccount(
        address contractAddress,
        uint256 tokenId,
        address externalAddress,
        uint256 ethValue,
        bytes memory encodedParams
    ) external returns (bytes memory);

    function refreshPrincipal(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external;

    function getWalletAddressById(
        address contractAddress,
        uint256 tokenId,
        address creator,
        uint256 annuityPct
    ) external returns (address);

    function withdrawEther(
        address contractAddress,
        uint256 tokenId,
        address payable receiver,
        uint256 amount
    ) external;

    function withdrawERC20(
        address contractAddress,
        uint256 tokenId,
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external;

    function withdrawERC721(
        address contractAddress,
        uint256 tokenId,
        address payable receiver,
        address nftTokenAddress,
        uint256 nftTokenId
    ) external;
}

// File: contracts/interfaces/ISmartWallet.sol

// ISmartWallet.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

/**
 * @title Charged Particles Smart Wallet
 * @dev Manages holding and transferring assets of an NFT to a specific LP for Yield (if any),
 */
interface ISmartWallet {
    function getAssetTokenCount() external view returns (uint256);

    function getAssetTokenByIndex(uint256 index)
        external
        view
        returns (address);

    function setNftCreator(address creator, uint256 annuityPct) external;

    function isReserveActive(address assetToken) external view returns (bool);

    function getReserveInterestToken(address assetToken)
        external
        view
        returns (address);

    function getPrincipal(address assetToken) external returns (uint256);

    function getInterest(address assetToken)
        external
        returns (uint256 creatorInterest, uint256 ownerInterest);

    function getTotal(address assetToken) external returns (uint256);

    function getRewards(address assetToken) external returns (uint256);

    function deposit(
        address assetToken,
        uint256 assetAmount,
        uint256 referralCode
    ) external returns (uint256);

    function withdraw(
        address receiver,
        address creatorRedirect,
        address assetToken
    ) external returns (uint256 creatorAmount, uint256 receiverAmount);

    function withdrawAmount(
        address receiver,
        address creatorRedirect,
        address assetToken,
        uint256 assetAmount
    ) external returns (uint256 creatorAmount, uint256 receiverAmount);

    function withdrawAmountForCreator(
        address receiver,
        address assetToken,
        uint256 assetAmount
    ) external returns (uint256 receiverAmount);

    function withdrawRewards(
        address receiver,
        address rewardsToken,
        uint256 rewardsAmount
    ) external returns (uint256);

    function executeForAccount(
        address contractAddress,
        uint256 ethValue,
        bytes memory encodedParams
    ) external returns (bytes memory);

    function refreshPrincipal(address assetToken) external;

    function withdrawEther(address payable receiver, uint256 amount) external;

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external;

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) external;
}

// File: @openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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

// File: @openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol

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

// File: @openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol

// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

// File: contracts/interfaces/IERC721Chargeable.sol

// IERC721Chargeable.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

interface IERC721Chargeable is IERC165Upgradeable {
    function owner() external view returns (address);

    function creatorOf(uint256 tokenId) external view returns (address);

    function balanceOf(address tokenOwner)
        external
        view
        returns (uint256 balance);

    function ownerOf(uint256 tokenId)
        external
        view
        returns (address tokenOwner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address tokenOwner, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// File: contracts/lib/TokenInfo.sol

// TokenInfo.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

library TokenInfo {
    function getTokenUUID(address contractAddress, uint256 tokenId)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(contractAddress, tokenId)));
    }

    /// @dev DEPRECATED; Prefer TokenInfoProxy
    function getTokenOwner(address contractAddress, uint256 tokenId)
        internal
        view
        returns (address)
    {
        IERC721Chargeable tokenInterface = IERC721Chargeable(contractAddress);
        return tokenInterface.ownerOf(tokenId);
    }

    /// @dev DEPRECATED; Prefer TokenInfoProxy
    function getTokenCreator(address contractAddress, uint256 tokenId)
        internal
        view
        returns (address)
    {
        IERC721Chargeable tokenInterface = IERC721Chargeable(contractAddress);
        return tokenInterface.creatorOf(tokenId);
    }

    /// @dev DEPRECATED; Prefer TokenInfoProxy
    /// @dev Checks if an account is the Owner of an External NFT contract
    /// @param contractAddress  The Address to the Contract of the NFT to check
    /// @param account          The Address of the Account to check
    /// @return True if the account owns the contract
    function isContractOwner(address contractAddress, address account)
        internal
        view
        returns (bool)
    {
        address contractOwner = IERC721Chargeable(contractAddress).owner();
        return contractOwner != address(0x0) && contractOwner == account;
    }

    /// @dev DEPRECATED; Prefer TokenInfoProxy
    /// @dev Checks if an account is the Creator of a Proton-based NFT
    /// @param contractAddress  The Address to the Contract of the Proton-based NFT to check
    /// @param tokenId          The Token ID of the Proton-based NFT to check
    /// @param sender           The Address of the Account to check
    /// @return True if the account is the creator of the Proton-based NFT
    function isTokenCreator(
        address contractAddress,
        uint256 tokenId,
        address sender
    ) internal view returns (bool) {
        IERC721Chargeable tokenInterface = IERC721Chargeable(contractAddress);
        address tokenCreator = tokenInterface.creatorOf(tokenId);
        return (sender == tokenCreator);
    }

    /// @dev DEPRECATED; Prefer TokenInfoProxy
    /// @dev Checks if an account is the Creator of a Proton-based NFT or the Contract itself
    /// @param contractAddress  The Address to the Contract of the Proton-based NFT to check
    /// @param tokenId          The Token ID of the Proton-based NFT to check
    /// @param sender           The Address of the Account to check
    /// @return True if the account is the creator of the Proton-based NFT or the Contract itself
    function isTokenContractOrCreator(
        address contractAddress,
        uint256 tokenId,
        address creator,
        address sender
    ) internal view returns (bool) {
        IERC721Chargeable tokenInterface = IERC721Chargeable(contractAddress);
        address tokenCreator = tokenInterface.creatorOf(tokenId);
        if (sender == contractAddress && creator == tokenCreator) {
            return true;
        }
        return (sender == tokenCreator);
    }

    /// @dev DEPRECATED; Prefer TokenInfoProxy
    /// @dev Checks if an account is the Owner or Operator of an External NFT
    /// @param contractAddress  The Address to the Contract of the External NFT to check
    /// @param tokenId          The Token ID of the External NFT to check
    /// @param sender           The Address of the Account to check
    /// @return True if the account is the Owner or Operator of the External NFT
    function isErc721OwnerOrOperator(
        address contractAddress,
        uint256 tokenId,
        address sender
    ) internal view returns (bool) {
        IERC721Chargeable tokenInterface = IERC721Chargeable(contractAddress);
        address tokenOwner = tokenInterface.ownerOf(tokenId);
        return (sender == tokenOwner ||
            tokenInterface.isApprovedForAll(tokenOwner, sender));
    }

    /**
     * @dev Returns true if `account` is a contract.
     * @dev Taken from OpenZeppelin library
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
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     * @dev Taken from OpenZeppelin library
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
    function sendValue(
        address payable recipient,
        uint256 amount,
        uint256 gasLimit
    ) internal {
        require(
            address(this).balance >= amount,
            "TokenInfo: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = (gasLimit > 0)
            ? recipient.call{value: amount, gas: gasLimit}("")
            : recipient.call{value: amount}("");
        require(
            success,
            "TokenInfo: unable to send value, recipient may have reverted"
        );
    }
}

// File: @openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
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
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
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
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
}

// File: @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol

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
interface IERC20Permit {
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

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(
                oldAllowance >= value,
                "SafeERC20: decreased allowance below zero"
            );
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
        }
    }

    function safePermit(
        IERC20Permit token,
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
        require(
            nonceAfter == nonceBefore + 1,
            "SafeERC20: permit did not succeed"
        );
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol

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

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

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
    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}

// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

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
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

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
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );

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
    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

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
    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool);

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

// File: contracts/lib/BlackholePrevention.sol

// BlackholePrevention.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

/**
 * @notice Prevents ETH or Tokens from getting stuck in a contract by allowing
 *  the Owner/DAO to pull them out on behalf of a user
 * This is only meant to contracts that are not expected to hold tokens, but do handle transferring them.
 */
contract BlackholePrevention {
    using Address for address payable;
    using SafeERC20 for IERC20;

    event WithdrawStuckEther(address indexed receiver, uint256 amount);
    event WithdrawStuckERC20(
        address indexed receiver,
        address indexed tokenAddress,
        uint256 amount
    );
    event WithdrawStuckERC721(
        address indexed receiver,
        address indexed tokenAddress,
        uint256 indexed tokenId
    );
    event WithdrawStuckERC1155(
        address indexed receiver,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 amount
    );

    function _withdrawEther(address payable receiver, uint256 amount)
        internal
        virtual
    {
        require(receiver != address(0x0), "BHP:E-403");
        if (address(this).balance >= amount) {
            receiver.sendValue(amount);
            emit WithdrawStuckEther(receiver, amount);
        }
    }

    function _withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) internal virtual {
        require(receiver != address(0x0), "BHP:E-403");
        if (IERC20(tokenAddress).balanceOf(address(this)) >= amount) {
            IERC20(tokenAddress).safeTransfer(receiver, amount);
            emit WithdrawStuckERC20(receiver, tokenAddress, amount);
        }
    }

    function _withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) internal virtual {
        require(receiver != address(0x0), "BHP:E-403");
        if (IERC721(tokenAddress).ownerOf(tokenId) == address(this)) {
            IERC721(tokenAddress).transferFrom(
                address(this),
                receiver,
                tokenId
            );
            emit WithdrawStuckERC721(receiver, tokenAddress, tokenId);
        }
    }

    function _withdrawERC1155(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) internal virtual {
        require(receiver != address(0x0), "BHP:E-403");
        if (
            IERC1155(tokenAddress).balanceOf(address(this), tokenId) >= amount
        ) {
            IERC1155(tokenAddress).safeTransferFrom(
                address(this),
                receiver,
                tokenId,
                amount,
                ""
            );
            emit WithdrawStuckERC1155(receiver, tokenAddress, tokenId, amount);
        }
    }
}

// File: contracts/lib/WalletManagerBase.sol

// WalletManagerBase.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

/**
 * @notice Wallet-Manager Base Contract
 * @dev Non-upgradeable Contract
 */
abstract contract WalletManagerBase is
    Ownable,
    BlackholePrevention,
    IWalletManager
{
    using TokenInfo for address;

    // The Controller Contract Address
    address internal _controller;

    // The Executor Contract Address
    address internal _executor;

    // Template Contract for creating Token Smart-Wallet Bridges
    address internal _walletTemplate;

    //       TokenID => Token Smart-Wallet Address
    mapping(uint256 => address) internal _wallets;

    // State of Wallet Manager
    bool internal _paused;

    /***********************************|
  |              Public               |
  |__________________________________*/

    function isPaused() external view override returns (bool) {
        return _paused;
    }

    /***********************************|
  |          Only Admin/DAO           |
  |__________________________________*/

    /**
     * @dev Sets the Paused-state of the Wallet Manager
     */
    function setPausedState(bool paused) external onlyOwner {
        _paused = paused;
        emit PausedStateSet(paused);
    }

    /**
     * @dev Connects to the Charged Particles Controller
     */
    function setController(address controller) external onlyOwner {
        _controller = controller;
        emit ControllerSet(controller);
    }

    /**
     * @dev Connects to the ExecForAccount Controller
     */
    function setExecutor(address executor) external onlyOwner {
        _executor = executor;
        emit ExecutorSet(executor);
    }

    function withdrawEther(
        address contractAddress,
        uint256 tokenId,
        address payable receiver,
        uint256 amount
    ) external virtual override onlyOwner {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        _withdrawEther(receiver, amount);
        return ISmartWallet(wallet).withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address contractAddress,
        uint256 tokenId,
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external virtual override onlyOwner {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        _withdrawERC20(receiver, tokenAddress, amount);
        return
            ISmartWallet(wallet).withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address contractAddress,
        uint256 tokenId,
        address payable receiver,
        address nftTokenAddress,
        uint256 nftTokenId
    ) external virtual override onlyOwner {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        _withdrawERC721(receiver, nftTokenAddress, nftTokenId);
        return
            ISmartWallet(wallet).withdrawERC721(
                receiver,
                nftTokenAddress,
                nftTokenId
            );
    }

    /***********************************|
  |         Private Functions         |
  |__________________________________*/

    function _getTokenUUID(address contractAddress, uint256 tokenId)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(contractAddress, tokenId)));
    }

    /**
     * @dev Creates Contracts from a Template via Cloning
     * see: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1167.md
     */
    function _createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
    }

    /***********************************|
  |             Modifiers             |
  |__________________________________*/

    /// @dev Throws if called by any account other than the Controller contract
    modifier onlyController() {
        require(_controller == msg.sender, "WMB:E-108");
        _;
    }

    /// @dev Throws if called by any account other than the Executor contract
    modifier onlyExecutor() {
        require(_executor == msg.sender, "WMB:E-108");
        _;
    }

    /// @dev Throws if called by any account other than the Controller or Executor contract
    modifier onlyControllerOrExecutor() {
        require(
            _executor == msg.sender || _controller == msg.sender,
            "WMB:E-108"
        );
        _;
    }

    // Throws if called by any account other than the Charged Particles Escrow Controller.
    modifier whenNotPaused() {
        require(_paused != true, "WMB:E-101");
        _;
    }
}

// File: @openzeppelin/contracts/utils/structs/EnumerableSet.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)

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
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
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
    function _contains(Set storage set, bytes32 value)
        private
        view
        returns (bool)
    {
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
    function _at(Set storage set, uint256 index)
        private
        view
        returns (bytes32)
    {
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
    function add(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool)
    {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool)
    {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value)
        internal
        view
        returns (bool)
    {
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
    function at(Bytes32Set storage set, uint256 index)
        internal
        view
        returns (bytes32)
    {
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
    function values(Bytes32Set storage set)
        internal
        view
        returns (bytes32[] memory)
    {
        return _values(set._inner);
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
    function add(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value)
        internal
        view
        returns (bool)
    {
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
    function at(AddressSet storage set, uint256 index)
        internal
        view
        returns (address)
    {
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
    function values(AddressSet storage set)
        internal
        view
        returns (address[] memory)
    {
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
    function remove(UintSet storage set, uint256 value)
        internal
        returns (bool)
    {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value)
        internal
        view
        returns (bool)
    {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
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
    function at(UintSet storage set, uint256 index)
        internal
        view
        returns (uint256)
    {
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
    function values(UintSet storage set)
        internal
        view
        returns (uint256[] memory)
    {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// File: contracts/interfaces/ISmartWalletB.sol

// ISmartWallet.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

/**
 * @title Charged Particles Smart Wallet
 * @dev Manages holding and transferring assets of an NFT to a specific LP for Yield (if any),
 */
interface ISmartWalletB {
    function getAssetTokenCount() external view returns (uint256);

    function getAssetTokenByIndex(uint256 index)
        external
        view
        returns (address);

    function isReserveActive(address assetToken) external view returns (bool);

    function getReserveInterestToken(address assetToken)
        external
        view
        returns (address);

    function getPrincipal(address assetToken) external returns (uint256);

    function getInterest(address assetToken, uint256 creatorPct)
        external
        returns (uint256 creatorInterest, uint256 ownerInterest);

    function getTotal(address assetToken) external returns (uint256);

    function getRewards(address assetToken) external returns (uint256);

    function deposit(
        address assetToken,
        uint256 assetAmount,
        uint256 referralCode
    ) external returns (uint256);

    function withdraw(
        address receiver,
        address creator,
        uint256 creatorPct,
        address assetToken
    ) external returns (uint256 creatorAmount, uint256 receiverAmount);

    function withdrawAmount(
        address receiver,
        address creator,
        uint256 creatorPct,
        address assetToken,
        uint256 assetAmount
    ) external returns (uint256 creatorAmount, uint256 receiverAmount);

    function withdrawAmountForCreator(
        address receiver,
        uint256 creatorPct,
        address assetToken,
        uint256 assetAmount
    ) external returns (uint256 receiverAmount);

    function withdrawRewards(
        address receiver,
        address rewardsToken,
        uint256 rewardsAmount
    ) external returns (uint256);

    function executeForAccount(
        address contractAddress,
        uint256 ethValue,
        bytes memory encodedParams
    ) external returns (bytes memory);

    function refreshPrincipal(address assetToken) external;

    function withdrawEther(address payable receiver, uint256 amount) external;

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external;

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) external;

    function withdrawERC1155(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external;
}

// File: contracts/lib/SmartWalletBaseB.sol

// SmartWalletBase.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

/**
 * @notice ERC20-Token Smart-Wallet Base Contract
 * @dev Non-upgradeable Contract
 */
abstract contract SmartWalletBaseB is ISmartWalletB, BlackholePrevention {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant PERCENTAGE_SCALE = 1e4; // 10000  (100%)

    address internal _walletManager;

    EnumerableSet.AddressSet internal _assetTokens;

    //   Asset Token => Principal Balance
    mapping(address => uint256) internal _assetPrincipalBalance;

    /***********************************|
  |          Initialization           |
  |__________________________________*/

    function initializeBase() public {
        require(_walletManager == address(0x0), "SWB:E-002");
        _walletManager = msg.sender;
    }

    /***********************************|
  |              Public               |
  |__________________________________*/

    function getAssetTokenCount()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _assetTokens.length();
    }

    function getAssetTokenByIndex(uint256 index)
        external
        view
        virtual
        override
        returns (address)
    {
        if (index >= _assetTokens.length()) {
            return address(0);
        }
        return _assetTokens.at(index);
    }

    function executeForAccount(
        address contractAddress,
        uint256 ethValue,
        bytes memory encodedParams
    ) external override onlyWalletManager returns (bytes memory) {
        (bool success, bytes memory result) = contractAddress.call{
            value: ethValue
        }(encodedParams);
        require(success, string(result));
        return result;
    }

    /***********************************|
  |          Only Admin/DAO           |
  |      (blackhole prevention)       |
  |__________________________________*/

    function withdrawEther(address payable receiver, uint256 amount)
        external
        virtual
        override
        onlyWalletManager
    {
        _withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external virtual override onlyWalletManager {
        _withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) external virtual override onlyWalletManager {
        _withdrawERC721(receiver, tokenAddress, tokenId);
    }

    function withdrawERC1155(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external virtual override onlyWalletManager {
        _withdrawERC1155(receiver, tokenAddress, tokenId, amount);
    }

    /***********************************|
  |         Private Functions         |
  |__________________________________*/

    function _getPrincipal(address assetToken)
        internal
        view
        virtual
        returns (uint256)
    {
        return _assetPrincipalBalance[assetToken];
    }

    function _trackAssetToken(address assetToken) internal virtual {
        if (!_assetTokens.contains(assetToken)) {
            _assetTokens.add(assetToken);
        }
    }

    /***********************************|
  |             Modifiers             |
  |__________________________________*/

    /// @dev Throws if called by any account other than the wallet manager
    modifier onlyWalletManager() {
        require(_walletManager == msg.sender, "SWB:E-109");
        _;
    }
}

// File: contracts/interfaces/ISafeERC20.sol

// Proton.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

// the EIP-165 interfaceId for this interface is 0x534f5876

interface ISafeERC20 is IERC20, IERC165 {
    function safeTransfer(address to, uint256 amount) external returns (bool);

    function safeTransfer(
        address to,
        uint256 amount,
        bytes memory data
    ) external returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) external returns (bool);
}

// File: contracts/yield/generic/ERC20/GenericSmartWalletB.sol

// GenericSmartWalletB.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/math/SafeMath.sol";

// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Generic ERC20-Token Smart-Wallet Bridge
 * @dev Non-upgradeable Contract
 */
contract GenericSmartWalletB is SmartWalletBaseB {
    // using SafeMath for uint256;
    // using SafeERC20 for IERC20;

    /***********************************|
  |          Initialization           |
  |__________________________________*/

    function initialize() public {
        SmartWalletBaseB.initializeBase();
    }

    function isReserveActive(address assetToken)
        external
        view
        override
        returns (bool)
    {
        return _getPrincipal(assetToken) == 0;
    }

    function getReserveInterestToken(address assetToken)
        external
        view
        override
        returns (address)
    {
        return assetToken;
    }

    function getPrincipal(address assetToken)
        external
        override
        returns (uint256)
    {
        return _getPrincipal(assetToken);
    }

    function getInterest(
        address, /* assetToken */
        uint256 /* creatorPct */
    )
        external
        override
        returns (uint256 creatorInterest, uint256 ownerInterest)
    {
        return (0, 0);
    }

    function getTotal(address assetToken) external override returns (uint256) {
        return _getPrincipal(assetToken);
    }

    function getRewards(address assetToken)
        external
        override
        returns (uint256)
    {
        return IERC20(assetToken).balanceOf(address(this));
    }

    function deposit(
        address assetToken,
        uint256 assetAmount,
        uint256 /* referralCode */
    ) external override onlyWalletManager returns (uint256) {
        // Track Principal
        _trackAssetToken(assetToken);
        _assetPrincipalBalance[assetToken] =
            _assetPrincipalBalance[assetToken] +
            (assetAmount);
    }

    function withdraw(
        address receiver,
        address, /* creator */
        uint256, /* creatorPct */
        address assetToken
    )
        external
        override
        onlyWalletManager
        returns (uint256 creatorAmount, uint256 receiverAmount)
    {
        creatorAmount = 0;
        receiverAmount = _getPrincipal(assetToken);
        // Track Principal
        _assetPrincipalBalance[assetToken] =
            _assetPrincipalBalance[assetToken] -
            (receiverAmount);
        ISafeERC20(assetToken).safeTransfer(receiver, receiverAmount);
    }

    function withdrawAmount(
        address receiver,
        address, /* creator */
        uint256, /* creatorPct */
        address assetToken,
        uint256 assetAmount
    )
        external
        override
        onlyWalletManager
        returns (uint256 creatorAmount, uint256 receiverAmount)
    {
        creatorAmount = 0;
        receiverAmount = _getPrincipal(assetToken);
        if (receiverAmount >= assetAmount) {
            receiverAmount = assetAmount;
        }
        // Track Principal
        _assetPrincipalBalance[assetToken] =
            _assetPrincipalBalance[assetToken] -
            (receiverAmount);
        ISafeERC20(assetToken).safeTransfer(receiver, receiverAmount);
    }

    function withdrawAmountForCreator(
        address, /* receiver */
        uint256, /* creatorPct */
        address, /* assetToken */
        uint256 /* assetID */
    ) external override onlyWalletManager returns (uint256 receiverAmount) {
        return 0;
    }

    function withdrawRewards(
        address receiver,
        address rewardsTokenAddress,
        uint256 rewardsAmount
    ) external override onlyWalletManager returns (uint256) {
        address self = address(this);
        ISafeERC20 rewardsToken = ISafeERC20(rewardsTokenAddress);

        uint256 walletBalance = rewardsToken.balanceOf(self);
        require(walletBalance >= rewardsAmount, "GSW:E-411");

        // Transfer Rewards to Receiver
        rewardsToken.safeTransfer(receiver, rewardsAmount);
        return rewardsAmount;
    }

    function refreshPrincipal(address assetToken)
        external
        virtual
        override
        onlyWalletManager
    {
        _assetPrincipalBalance[assetToken] = IERC20(assetToken).balanceOf(
            address(this)
        );
    }
}

// File: contracts/yield/generic/ERC20/GenericWalletManagerB.sol

// GenericWalletManagerB.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @notice Generic ERC20 Wallet Manager B
 * @dev Non-upgradeable Contract
 */
contract GenericWalletManagerB is WalletManagerBase {
    // using SafeMath for uint256;

    /***********************************|
  |          Initialization           |
  |__________________________________*/

    constructor() public {
        _walletTemplate = address(new GenericSmartWalletB());
    }

    /***********************************|
  |              Public               |
  |__________________________________*/

    function isReserveActive(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external view override returns (bool) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        if (_wallets[uuid] == address(0x0)) {
            return false;
        }
        return GenericSmartWalletB(_wallets[uuid]).isReserveActive(assetToken);
    }

    function getReserveInterestToken(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external view override returns (address) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        if (_wallets[uuid] == address(0x0)) {
            return address(0x0);
        }
        return
            GenericSmartWalletB(_wallets[uuid]).getReserveInterestToken(
                assetToken
            );
    }

    /**
     * @notice Gets the Available Balance of Assets held in the Token
     * @param contractAddress The Address to the External Contract of the Token
     * @param tokenId The ID of the Token within the External Contract
     * @return  The Available Balance of the Token
     */
    function getTotal(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external override returns (uint256) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        if (_wallets[uuid] == address(0x0)) {
            return 0;
        }
        return GenericSmartWalletB(_wallets[uuid]).getTotal(assetToken);
    }

    /**
     * @notice Gets the Principal-Amount of Assets held in the Smart-Wallet
     * @param contractAddress The Address to the External Contract of the Token
     * @param tokenId The ID of the Token within the External Contract
     * @return  The Principal-Balance of the Smart-Wallet
     */
    function getPrincipal(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external override returns (uint256) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        if (_wallets[uuid] == address(0x0)) {
            return 0;
        }
        return GenericSmartWalletB(_wallets[uuid]).getPrincipal(assetToken);
    }

    /**
     * @notice Gets the Interest-Amount that the Token has generated
     * @param contractAddress The Address to the External Contract of the Token
     * @param tokenId The ID of the Token within the External Contract
     * @return creatorInterest The NFT Creator's portion of the Interest
     * @return ownerInterest The NFT Owner's portion of the Interest
     */
    function getInterest(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    )
        external
        override
        returns (uint256 creatorInterest, uint256 ownerInterest)
    {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        if (_wallets[uuid] != address(0x0)) {
            return
                GenericSmartWalletB(_wallets[uuid]).getInterest(assetToken, 0);
        }
    }

    function getRewards(
        address contractAddress,
        uint256 tokenId,
        address rewardToken
    ) external override returns (uint256) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        if (_wallets[uuid] == address(0x0)) {
            return 0;
        }
        return GenericSmartWalletB(_wallets[uuid]).getRewards(rewardToken);
    }

    function energize(
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        uint256 assetAmount
    ) external override onlyController returns (uint256 yieldTokensAmount) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];

        // Deposit into Smart-Wallet
        yieldTokensAmount = GenericSmartWalletB(wallet).deposit(
            assetToken,
            assetAmount,
            0
        );

        // Log Event
        emit WalletEnergized(
            contractAddress,
            tokenId,
            assetToken,
            assetAmount,
            yieldTokensAmount
        );
    }

    function discharge(
        address, /* receiver */
        address, /* contractAddress */
        uint256, /* tokenId */
        address, /* assetToken */
        address /* creatorRedirect */
    )
        external
        override
        onlyController
        returns (uint256 creatorAmount, uint256 receiverAmount)
    {
        return (0, 0);
    }

    function dischargeAmount(
        address, /* receiver */
        address, /* contractAddress */
        uint256, /* tokenId */
        address, /* assetToken */
        uint256, /* assetAmount */
        address /* creatorRedirect */
    )
        external
        override
        onlyController
        returns (uint256 creatorAmount, uint256 receiverAmount)
    {
        return (0, 0);
    }

    function dischargeAmountForCreator(
        address, /* receiver */
        address, /* contractAddress */
        uint256, /* tokenId */
        address, /* creator */
        address, /* assetToken */
        uint256 /* assetAmount */
    ) external override onlyController returns (uint256 receiverAmount) {
        return 0;
    }

    function release(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        address creatorRedirect
    )
        external
        override
        onlyController
        returns (
            uint256 principalAmount,
            uint256 creatorAmount,
            uint256 receiverAmount
        )
    {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        require(wallet != address(0x0), "GWM:E-403");

        // Release Principal + Interest
        principalAmount = GenericSmartWalletB(wallet).getPrincipal(assetToken);
        (creatorAmount, receiverAmount) = GenericSmartWalletB(wallet).withdraw(
            receiver,
            creatorRedirect,
            0,
            assetToken
        );

        // Log Event
        emit WalletReleased(
            contractAddress,
            tokenId,
            receiver,
            assetToken,
            principalAmount,
            creatorAmount,
            receiverAmount
        );
    }

    function releaseAmount(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address assetToken,
        uint256 assetAmount,
        address creatorRedirect
    )
        external
        override
        onlyController
        returns (
            uint256 principalAmount,
            uint256 creatorAmount,
            uint256 receiverAmount
        )
    {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        require(wallet != address(0x0), "GWM:E-403");

        // Release from interest first + principal if needed
        principalAmount = GenericSmartWalletB(wallet).getPrincipal(assetToken);
        (creatorAmount, receiverAmount) = GenericSmartWalletB(wallet)
            .withdrawAmount(
                receiver,
                creatorRedirect,
                0,
                assetToken,
                assetAmount
            );

        // Log Event
        emit WalletReleased(
            contractAddress,
            tokenId,
            receiver,
            assetToken,
            principalAmount,
            creatorAmount,
            receiverAmount
        );
    }

    function withdrawRewards(
        address receiver,
        address contractAddress,
        uint256 tokenId,
        address rewardsToken,
        uint256 rewardsAmount
    ) external override onlyControllerOrExecutor returns (uint256 amount) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        require(wallet != address(0x0), "GWM:E-403");

        // Withdraw Rewards to Receiver
        amount = GenericSmartWalletB(wallet).withdrawRewards(
            receiver,
            rewardsToken,
            rewardsAmount
        );

        // Log Event
        emit WalletRewarded(
            contractAddress,
            tokenId,
            receiver,
            rewardsToken,
            amount
        );
    }

    function executeForAccount(
        address contractAddress,
        uint256 tokenId,
        address externalAddress,
        uint256 ethValue,
        bytes memory encodedParams
    ) external override onlyControllerOrExecutor returns (bytes memory) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        return
            GenericSmartWalletB(wallet).executeForAccount(
                externalAddress,
                ethValue,
                encodedParams
            );
    }

    function refreshPrincipal(
        address contractAddress,
        uint256 tokenId,
        address assetToken
    ) external override onlyControllerOrExecutor {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];
        GenericSmartWalletB(wallet).refreshPrincipal(assetToken);
    }

    function getWalletAddressById(
        address contractAddress,
        uint256 tokenId,
        address, /* creator */
        uint256 /* annuityPct */
    ) external override onlyControllerOrExecutor returns (address) {
        uint256 uuid = _getTokenUUID(contractAddress, tokenId);
        address wallet = _wallets[uuid];

        // Create Smart-Wallet if none exists
        if (wallet == address(0x0)) {
            wallet = _createWallet();
            _wallets[uuid] = wallet;
            emit NewSmartWallet(
                contractAddress,
                tokenId,
                wallet,
                address(0),
                0
            );
        }

        return wallet;
    }

    /***********************************|
  |         Private Functions         |
  |__________________________________*/

    function _createWallet() internal returns (address) {
        address newWallet = _createClone(_walletTemplate);
        GenericSmartWalletB(newWallet).initialize();
        return newWallet;
    }
}