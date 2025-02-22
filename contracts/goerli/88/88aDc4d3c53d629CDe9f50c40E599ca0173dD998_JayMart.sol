//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

interface IERC1155 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}

interface IJAY {
    function sell(uint256 value) external;

    function buy(address reciever) external payable;

    function burnFrom(address account, uint256 amount) external;

    function ETHtoJAY(uint256 value) external view returns (uint256);
}

contract JayMart is Ownable {
    // Use SafeMath for all calculations including uint256's
    using SafeMath for uint256;

    // Define our price feed interface
    AggregatorV3Interface internal priceFeed;

    // Create variable to hold the team wallet address
    address payable private constant TEAM_WALLET =
        payable(0x985B6B9064212091B4b325F68746B77262801BcB);

    // Create variable to hold contract address
    address payable private JAY_ADDRESS;

    // Define new IJAY interface
    IJAY private JAY;

    // Define some constant variables
    uint256 private constant SELL_NFT_PAYOUT = 2;
    uint256 private constant SELL_NFT_FEE_VAULT = 4;
    uint256 private constant SELL_NFT_FEE_TEAM = 4;
    uint256 private constant BUY_NFT_FEE_VAULT = 2;
    uint256 private constant BUY_NFT_FEE_TEAM = 2;
    uint256 private constant USD_PRICE_SELL = 2 * 10 ** 18;
    uint256 private constant USD_PRICE_BUY = 10 * 10 ** 18;

    // Define variables for amount of NFTs bought/sold
    uint256 private nftsBought;
    uint256 private nftsSold;

    // Create variables for gas fee calculation
    uint256 private buyNftFeeEth = 0.01 * 10 ** 18;
    uint256 private buyNftFeeJay = 10 * 10 ** 18;
    uint256 private sellNftFeeEth = 0.001 * 10 ** 18;

    // Create variable to hold when the next fee update can occur
    uint256 private nextFeeUpdate = block.timestamp.add(7 days);

    // Constructor
    constructor(address _jayAddress) {
        JAY = IJAY(_jayAddress);
        priceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        ); //main
    }

    /*
     * Name: sendEth
     * Purpose: Tranfer ETH tokens
     * Parameters:
     *    - @param 1: Address
     *    - @param 2: Value
     * Return: n/a
     */
    function sendEth(address _address, uint256 _value) private {
        (bool success, ) = _address.call{value: _value}("");
        require(success, "ETH Transfer failed.");
    }

    /*
     * Name: buyNFTs
     * Purpose: Purchase NFTs with ETH
     * Parameters:
     *    - @param 1: ERC721 Token Address
     *    - @param 2: ERC721 IDs
     *    - @param 3: ERC1155 Token Address
     *    - @param 4: ERC1155 IDs
     *    - @param 5: ERC1155 Amounts
     * Return: n/a
     */
    function buyNFTs(
        address[] calldata erc721TokenAddress,
        uint256[] calldata erc721Ids,
        address[] calldata erc1155TokenAddress,
        uint256[] calldata erc1155Ids,
        uint256[] calldata erc1155Amounts
    ) public payable {
        // Calculate total
        uint256 total = erc721TokenAddress.length;

        // Transfer ERC721 NFTs
        buyERC721(erc721TokenAddress, erc721Ids);

        // Transfer ERC1155 NFTs
        total += buyERC1155(erc1155TokenAddress, erc1155Ids, erc1155Amounts);

        // Calculate Jay fee
        uint256 _fee = total.mul(buyNftFeeEth);

        // Make sure enough ETH is present
        require(msg.value >= _fee, "You need to pay more ETH.");

        // Send fees to designated wallets
        sendEth(TEAM_WALLET, msg.value.div(BUY_NFT_FEE_TEAM));
        sendEth(JAY_ADDRESS, address(this).balance);

        // Initiate burn method
        JAY.burnFrom(msg.sender, _fee);

        // Increase NFTs bought
        nftsBought += total;
    }

    /*
     * Name: buyJay
     * Purpose: Purchase JAY tokens by selling NFTs
     * Parameters:
     *    - @param 1: ERC721 Token Address
     *    - @param 2: ERC721 IDs
     *    - @param 3: ERC1155 Token Address
     *    - @param 4: ERC1155 IDs
     *    - @param 5: ERC1155 Amounts
     * Return: n/a
     */
    function buyJay(
        address[] calldata erc721TokenAddress,
        uint256[] calldata erc721Ids,
        address[] calldata erc1155TokenAddress,
        uint256[] calldata erc1155Ids,
        uint256[] calldata erc1155Amounts
    ) public payable {
        uint256 total = erc721TokenAddress.length;

        // Transfer ERC721 NFTs
        buyJayWithERC721(erc721TokenAddress, erc721Ids);

        // Transfer ERC1155 NFTs
        total += buyJayWithERC1155(
            erc1155TokenAddress,
            erc1155Ids,
            erc1155Amounts
        );

        // Calculate fee
        uint256 _fee = total >= 100
            ? (total).mul(sellNftFeeEth).div(2)
            : (total).mul(sellNftFeeEth);

        // Make sure enough ETH is present
        require(msg.value >= _fee, "You need to pay more ETH.");

        // Send fees to their designated wallets
        sendEth(TEAM_WALLET, msg.value.div(SELL_NFT_FEE_TEAM));
        sendEth(JAY_ADDRESS, msg.value.div(SELL_NFT_FEE_VAULT));

        // buy JAY
        JAY.buy{value: address(this).balance}(msg.sender);

        // Increase nftsSold variable

        nftsSold += total;
    }

    /*
     * Name: buyERC721
     * Purpose: Transfer ERC721 NFTs
     * Parameters:
     *    - @param 1: ERC721 Token Address
     *    - @param 2: ERC721 IDs
     * Return: n/a
     */
    function buyERC721(
        address[] calldata _tokenAddress,
        uint256[] calldata ids
    ) internal {
        for (uint256 id = 0; id < ids.length; id++) {
            IERC721(_tokenAddress[id]).safeTransferFrom(
                address(this),
                msg.sender,
                ids[id]
            );
        }
    }

    /*
     * Name: buyERC1155
     * Purpose: Transfer ERC1155 NFTs
     * Parameters:
     *    - @param 1: ERC1155 Token Address
     *    - @param 2: ERC1155 IDs
     *    - @param 3: ERC1155 Amounts
     * Return: Amount of NFTs bought
     */
    function buyERC1155(
        address[] calldata _tokenAddress,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal returns (uint256) {
        uint256 amount = 0;
        for (uint256 id = 0; id < ids.length; id++) {
            amount = amount.add(amounts[id]);
            IERC1155(_tokenAddress[id]).safeTransferFrom(
                address(this),
                msg.sender,
                ids[id],
                amounts[id],
                ""
            );
        }
        return amount;
    }

    /*
     * Name: buyJayWithERC721
     * Purpose: Buy JAY from selling ERC721 NFTs
     * Parameters:
     *    - @param 1: ERC721 Token Address
     *    - @param 2: ERC721 IDs
     *
     * Return: n/a
     */
    function buyJayWithERC721(
        address[] calldata _tokenAddress,
        uint256[] calldata ids
    ) internal {
        for (uint256 id = 0; id < ids.length; id++) {
            IERC721(_tokenAddress[id]).safeTransferFrom(
                msg.sender,
                address(this),
                ids[id]
            );
        }
    }

    /*
     * Name: buyJayWithERC1155
     * Purpose: Buy JAY from selling ERC1155 NFTs
     * Parameters:
     *    - @param 1: ERC1155 Token Address
     *    - @param 2: ERC1155 IDs
     *    - @param 3: ERC1155 Amounts
     *
     * Return: Number of NFTs sold
     */
    function buyJayWithERC1155(
        address[] calldata _tokenAddress,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal returns (uint256) {
        uint256 amount = 0;
        for (uint256 id = 0; id < ids.length; id++) {
            amount = amount.add(amounts[id]);
            IERC1155(_tokenAddress[id]).safeTransferFrom(
                msg.sender,
                address(this),
                ids[id],
                amounts[id],
                ""
            );
        }
        return amount;
    }

    // chainlink pricefeed / fee updater
    function getFees()
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        return (sellNftFeeEth, buyNftFeeEth, buyNftFeeJay, nextFeeUpdate);
    }

    function getTotals() public view returns (uint256, uint256) {
        return (nftsBought, nftsSold);
    }

    /*
     * Name: updateFees
     * Purpose: Update the NFT sales fees
     * Parameters: n/a
     * Return: Array of uint256: NFT Sell Fee (ETH), NFT Buy Fee (ETH), NFT Buy Fee (JAY), time of next update
     */
    function updateFees() public returns (uint256, uint256, uint256, uint256) {
        // Get latest price feed
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        uint256 _price = uint256(price).mul(1 * 10 ** 10);
        require(timeStamp > nextFeeUpdate, "Fee update every 24 hrs");

        uint256 _sellNftFeeEth;
        if (_price > USD_PRICE_SELL) {
            uint256 _p = _price.div(USD_PRICE_SELL);
            _sellNftFeeEth = uint256(1 * 10 ** 18).div(_p);
        } else {
            _sellNftFeeEth = USD_PRICE_SELL.div(_price);
        }

        require(
            owner() == msg.sender ||
                (sellNftFeeEth.div(2) < _sellNftFeeEth &&
                    sellNftFeeEth.mul(150) > _sellNftFeeEth),
            "Fee swing too high"
        );

        sellNftFeeEth = _sellNftFeeEth;

        if (_price > USD_PRICE_BUY) {
            uint256 _p = _price.div(USD_PRICE_BUY);
            buyNftFeeEth = uint256(1 * 10 ** 18).div(_p);
        } else {
            buyNftFeeEth = USD_PRICE_BUY.div(_price);
        }
        buyNftFeeJay = JAY.ETHtoJAY(buyNftFeeEth);

        nextFeeUpdate = timeStamp.add(24 hours);
        return (sellNftFeeEth, buyNftFeeEth, buyNftFeeJay, nextFeeUpdate);
    }

    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    //receiver helpers
    function deposit() public payable {}

    receive() external payable {}

    fallback() external payable {}

    function onERC1155Received(
        address,
        address from,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
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