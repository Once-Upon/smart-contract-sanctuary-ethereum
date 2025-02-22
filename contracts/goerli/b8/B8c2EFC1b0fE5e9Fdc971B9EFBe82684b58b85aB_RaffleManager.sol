// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

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
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// contract Raffle is IERC721Receiver, ReentrancyGuard{
//   using Counters for Counters.Counter;
// 	Counters.Counter private _itemIds;
// 	Counters.Counter private _itemsSold;
	
// 	address payable owner;
// 	uint256 public listingFee = 0.001 ether;

//   struct SimpleRaffleItem {
//     uint itemId;
//     uint256 tokenId;
//     address payable seller;
//     address payable owner;
//     uint256 price;
//   //   bool ended;
//     uint expiredAt;
//     uint ticketCap;
//   //   mapping(address => uint) gamblerTickets;
//   }

//   struct RaffleItem {
//     uint itemId;
//     uint256 tokenId;
//     address payable seller;
//     address payable owner;
//     uint256 price;
//     bool ended; // 티켓 다 팔리면 true 

//     uint expiredAt;
//     uint ticketCap;
//     mapping(address => uint) gamblerTickets;
//     address[] gamblerAddrs;
//   }

//   mapping(uint256 => RaffleItem) public vaultItems;

//   event NFTRaffleCreated (
//     uint indexed itemId,
//     uint256 indexed tokenId,
//     address seller,
//     address owner,
//     uint256 price,
//     bool ended,
//     uint expiredAt
//   );

//   function getListingFee() public view returns(uint256) {
//     return listingFee;
//   }

//   ERC721Enumerable nft;

//   // constructor(ERC721Enumerable _nft) {
//   //   owner = payable(msg.sender);
//   //   nft = _nft;
//   // }

//   function addRaffle(uint256 tokenId, uint256 price, uint expiredAt, uint ticketCap) public payable nonReentrant {
//     require(nft.ownerOf(tokenId) == msg.sender, "This NFT is not owned by this wallet.");
//     require(vaultItems[tokenId].tokenId == 0, "Already listed.");
//     require(price > 0, "Listing price must be higher than 0.");
//     require(msg.value == listingFee, "Not enough fee.");

//     // 래플 등록 때마다 itemId 번호 증가, 1번부터 시작
//     _itemIds.increment();
//     uint itemId = _itemIds.current();
//     // vaultItems[itemId] = RaffleItem(itemId, tokenId, payable(msg.sender), payable(address(this)), price, false, expiredAt, ticketCap);
//     RaffleItem storage raffleItem = vaultItems[itemId];
//     raffleItem.itemId = itemId;
//     raffleItem.tokenId = tokenId;
//     raffleItem.seller = payable(msg.sender);
//     raffleItem.owner = payable(address(this));
//     raffleItem.price = price;
//     raffleItem.ended = false;
//     raffleItem.expiredAt = expiredAt;
//     raffleItem.ticketCap = ticketCap;
    
//     // 컨트랙트에 해당 NFT 전송
//     nft.transferFrom(msg.sender, address(this), tokenId);
    
//     // Listing이 되면 event emit
//     emit NFTRaffleCreated(itemId, tokenId, msg.sender, address(this), price, false, expiredAt);
//   }

//   function buyNFT(uint256 itemId) public payable nonReentrant {
//     uint256 price = vaultItems[itemId].price;
//     uint256 tokenId = vaultItems[itemId].tokenId;

//     require(msg.value == price, "Exact amount of price is required.");
    
//     vaultItems[itemId].seller.transfer(msg.value);
//     payable(msg.sender).transfer(listingFee);
//     nft.transferFrom(address(this), msg.sender, tokenId);
//     vaultItems[itemId].ended = true;
//     _itemsSold.increment();

//     delete vaultItems[tokenId];
//     delete vaultItems[itemId];
//   }

//   function nftListings() public view returns (SimpleRaffleItem[] memory) {
//     uint itemCount = _itemIds.current();
//     uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
//     uint currentIndex = 0;

//     SimpleRaffleItem[] memory items = new SimpleRaffleItem[](unsoldItemCount);

//     for (uint i = 0; i < itemCount; i++) {
//       if (vaultItems[i+1].owner == address(this)) {
//         // uint currentId = i + 1;
//         // RaffleItem storage currentItem = vaultItems[currentId];
//         // items[currentIndex] = currentItem;
//         items[currentIndex] = SimpleRaffleItem(
//           vaultItems[i + 1].itemId, 
//           vaultItems[i + 1].tokenId, 
//           vaultItems[i + 1].seller, 
//           vaultItems[i + 1].owner, 
//           vaultItems[i + 1].price, 
//           vaultItems[i + 1].expiredAt, 
//           vaultItems[i + 1].ticketCap);
//         currentIndex += 1;
//       }
//     }
//     return items;
//   }

//   function onERC721Received(
//     address,
//     address from,
//     uint256,
//     bytes calldata
//   ) external pure override returns (bytes4) {
//     require(from == address(0x0), "Cannot send nfts to Vault directly");
//     return IERC721Receiver.onERC721Received.selector;
//   }

//   // 이더 전송 처리 부분 필요
//   function joinRaffle(uint256 tokenId, uint ticketNum) public {
//     uint ticketCap = vaultItems[tokenId].ticketCap;
//     uint currentTicketCap = 0;
//     for(uint i=0; i<vaultItems[tokenId].gamblerAddrs.length; i++) {
//       address addr = vaultItems[tokenId].gamblerAddrs[i];
//       currentTicketCap += vaultItems[tokenId].gamblerTickets[addr];
//     }

//     require(currentTicketCap + ticketNum <= ticketCap, "Gambler's tickets are too many to join");

//     // 최초 참가자라면 티켓 갯수가 0
//     if(vaultItems[tokenId].gamblerTickets[msg.sender] == 0) {
//       // msg.sender is Gambler?
//       vaultItems[tokenId].gamblerAddrs.push(msg.sender);
//     }
//     vaultItems[tokenId].gamblerTickets[msg.sender] += ticketNum;

//     // 티켓 캡이 다 차면 마감 처리
//     if(currentTicketCap + ticketNum == ticketCap) {
//       closeRaffle();
//     }
//   }

//   // 써드파티에서 이 함수를 주기적으로 호출
//   function checkExpiredRaffles() public {
//     require(owner == msg.sender, "Only owner can execute this.");
//     uint itemCount = _itemIds.current();

//     for (uint i = 1; i < itemCount - 1; i++) {
//       if(vaultItems[i].expiredAt <= block.timestamp) {
//         // 만료된 래플 처리
//         closeRaffle();
//       }
//     }

//   }

//   // case1. winner가 정해졌을 때 -> 우리가 직접 winner에게 전송
//   // case2. winner가 없을 때 -> 각각의 참여자들에게 claim할 수 있게
//   function closeRaffle() public {

//   }

// }

contract Raffle is IERC721Receiver, ReentrancyGuard{

  enum State {
    Ongoing,
    Soldout,
    Timeout,
    Cancelled,
    Completed
  }
  State private state;

  address payable public owner;
  address public nftContract;
  uint256 public nftTokenId;
  uint256 public nftTokenType;
  uint256 public expiredAt;
  uint16 public ticketCap;
  uint32 public ticketPrice;
  uint8 public ticketPricePointer;

  // address payable private seller;
  // address payable private owner;
  // uint256 price;
//   bool ended;

  struct Purchase {
    address purchaser;
    uint timestamp;
    uint16 tickets;
  }

  Purchase[] private purchases;

// payable nonReentrant
  constructor (
    address _owner,
    address _nftContract,
    uint256 _nftTokenId,
    uint256 _nftTokenType,
    uint256 _expiredAt,
    uint16 _ticketCap,
    uint32 _ticketPrice,
    uint8 _ticketPricePointer
  ) {
    owner = payable(_owner);
    nftContract = _nftContract;
    nftTokenId = _nftTokenId;
    nftTokenType = _nftTokenType;
    expiredAt = _expiredAt;
    ticketCap = _ticketCap;
    ticketPrice = _ticketPrice;
    ticketPricePointer = _ticketPricePointer;

    state = State.Ongoing;

    transferERC721(owner, address(this), nftTokenId);
    // IERC721 erc721 = IERC721(nftContract);
    // erc721.transferFrom(owner, address(this), nftTokenId);
  }

  function transferERC721(address from, address to, uint256 tokenId) public payable {
    IERC721 erc721 = IERC721(nftContract);
    erc721.transferFrom(from, to, tokenId);
    erc721.approve(to, tokenId); 
  }

  function cancelRaffle(address _owner) public {
    require(owner == _owner, "Only owner is able to cancel raffle.");

    state = State.Cancelled;

    transferERC721(address(this), owner, nftTokenId);

    // TODO 토큰 구매자들에게 다 돌려주기
  }

  function getRaffle() public view returns(
    address, 
    address, 
    uint256, 
    uint256, 
    string memory,
    string memory,
    string memory,
    uint256, 
    uint16, 
    uint32, 
    uint8
  ) {

    string memory nftName;
    string memory nftSymbol;
    string memory nftTokenURI;
    (nftName, nftSymbol, nftTokenURI) = getERC721Metadata();

    return(
      owner, 
      nftContract, 
      nftTokenId, 
      nftTokenType, 
      nftName,
      nftSymbol,
      nftTokenURI,
      expiredAt, 
      ticketCap, 
      ticketPrice, 
      ticketPricePointer
    );
  }

  function getPurchases() public view returns(Purchase[] memory) {
    return purchases;
  }

  function getSoldTicketsNum() external view returns(uint16) {
    uint16 total = 0;
    for(uint i=0; i<purchases.length; i++) {
      total += purchases[i].tickets;
    }
    return total;
  }

  function getERC721Metadata() public view returns(string memory, string memory, string memory) {
      IERC721Metadata erc721Metadata = IERC721Metadata(nftContract);
      string memory name = erc721Metadata.name();
      string memory symbol = erc721Metadata.symbol();
      string memory tokenURI = erc721Metadata.tokenURI(nftTokenId);

      return (name, symbol, tokenURI);
  }

  function getERC1155Metadata(address contractAddress, uint256 tokenId) public view returns(string memory) {
      IERC1155MetadataURI erc1155MetadataURI = IERC1155MetadataURI(contractAddress);
      string memory uri = erc1155MetadataURI.uri(tokenId);
      return uri;
  }

  // event NFTRaffleCreated (
  //   uint indexed itemId,
  //   uint256 indexed tokenId,
  //   address seller,
  //   address owner,
  //   uint256 price,
  //   bool ended,
  //   uint expiredAt
  // );

  // function getListingFee() public view returns(uint256) {
  //   return listingFee;
  // }

  // constructor(ERC721Enumerable _nft) {
  //   owner = payable(msg.sender);
  //   nft = _nft;
  // }

  // function buyNFT(uint256 itemId) public payable nonReentrant {
  //   uint256 price = vaultItems[itemId].price;
  //   uint256 tokenId = vaultItems[itemId].tokenId;

  //   require(msg.value == price, "Exact amount of price is required.");
    
  //   vaultItems[itemId].seller.transfer(msg.value);
  //   payable(msg.sender).transfer(listingFee);
  //   nft.transferFrom(address(this), msg.sender, tokenId);
  //   vaultItems[itemId].ended = true;
  //   _itemsSold.increment();

  //   delete vaultItems[tokenId];
  //   delete vaultItems[itemId];
  // }

  function onERC721Received(
    address,
    address from,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    require(from == address(0x0), "Cannot send nfts to Vault directly");
    return IERC721Receiver.onERC721Received.selector;
  }

  // 이더 전송 처리 부분 필요
  function purchaseTickets(uint16 tickets, uint256 cost) public {
    require(state == State.Ongoing, "Raffle state is not on sail");

    uint currentTicketCap = 0;
    for(uint i=0; i<purchases.length; i++) {
      currentTicketCap += purchases[i].tickets;
    }

    require(currentTicketCap + tickets <= ticketCap, "Purchaser's tickets are too many to join");

    // purchases.push(Purchase(purchaser, timestamp, tickets));
    purchases.push(Purchase(msg.sender, block.timestamp, tickets));

    // 티켓 캡이 다 차면 마감 처리
    if(currentTicketCap + tickets == ticketCap) {
      state = State.Soldout;
      // closeRaffle();
    }
  }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "contracts/Raffle.sol";

contract RaffleManager {

  address private owner;
  Raffle[] private raffles;
  Raffle[] private endedRaffles;

  struct SimpleNFT {
    address contractAddress;
    uint256 tokenId;
  }

  struct RaffleDetail {
    address owner;
    address raffleContract;
    address nftContract;
    uint256 nftTokenId;
    uint256 nftTokenType;
    string nftName;
    string nftSymbol;
    string nftTokenURI;
    uint256 expiredAt;
    uint16 ticketCap;
    uint16 soldTickets;
    uint32 ticketPrice;
    uint8 ticketPricePointer;
    uint32 index;
  }

  constructor() {
    owner = msg.sender;
  }

  event NFTRaffleCreated (
    address raffleOwner,
    address nftContract,
    uint256 nftTokenId,
    uint256 nftTokenType,
    uint256 expiredAt, 
    uint16 ticketCap, 
    uint32 ticketPrice,
    uint8 ticketPricePointer,
    address raffleAddress
  );

  function createRaffle(
    // address raffleOwner,
    address nftContract,
    uint256 nftTokenId,
    uint256 nftTokenType,
    uint256 expiredAt,
    uint16 ticketCap,
    uint32 ticketPrice,
    uint8 ticketPricePointer
  ) public {
    // require(nft.ownerOf(tokenId) == msg.sender, "This NFT is not owned by this wallet.");
    // require(vaultItems[tokenId].tokenId == 0, "Already listed.");
    // require(price > 0, "Listing price must be higher than 0.");
    // require(msg.value == listingFee, "Not enough fee.");
    require(nftTokenType == 721, "Currently only ERC721 token is supported.");

    require(!doesRaffleAlreadyExist(nftContract, nftTokenId), "This NFT Raffle is already created.");
    // for(uint i=0; i<raffles.length; i++) {
    //   require(raffles[i].nftContract() != nftContract && raffles[i].nftTokenId() != nftTokenId, "This NFT Raffle is already created.");
    // }

    Raffle raffle = new Raffle(
      // raffleOwner, 
      msg.sender,
      nftContract, 
      nftTokenId, 
      nftTokenType, 
      expiredAt, 
      ticketCap, 
      ticketPrice, 
      ticketPricePointer
    );
    raffles.push(raffle);

    emit NFTRaffleCreated(
      // raffleOwner, 
      msg.sender,
      nftContract, 
      nftTokenId, 
      nftTokenType, 
      expiredAt, 
      ticketCap, 
      ticketPrice, 
      ticketPricePointer,
      address(raffle)
    );
  }

  function getRaffles() public view returns(Raffle[] memory) {
    return raffles;
  }

  function getRafflesByIndex(uint256 index, uint256 itemNums) public view returns(RaffleDetail[] memory) {
    require(itemNums <= 100, "Too many items to request.");
    if(index >= raffles.length) {
      return new RaffleDetail[](0);
    }

    int256 diff = int256(raffles.length) - int256(itemNums + index);
    uint256 max = diff < 0 ? raffles.length : itemNums + index;
    uint256 size = diff < 0 ? max - index : itemNums;
    
    RaffleDetail[] memory details = new RaffleDetail[](size);
    for(uint i=index; i<max; i++) {
      uint256 tokenType = raffles[i].nftTokenType();
      if(tokenType == 721){
        string memory nftName;
        string memory nftSymbol;
        string memory nftTokenURI;
        (nftName, nftSymbol, nftTokenURI) = raffles[i].getERC721Metadata();

        details[i] = RaffleDetail(
          raffles[i].owner(),
          address(raffles[i]),
          raffles[i].nftContract(),
          raffles[i].nftTokenId(),
          raffles[i].nftTokenType(),
          nftName,
          nftSymbol,
          nftTokenURI,
          raffles[i].expiredAt(),
          raffles[i].ticketCap(),
          raffles[i].getSoldTicketsNum(),
          raffles[i].ticketPrice(),
          raffles[i].ticketPricePointer(),
          uint32(i)
        );
      } else if(tokenType == 1155) {

      }
      
    }

    return details;
  }

  function doesRaffleAlreadyExist(address nftContract, uint256 nftTokenId) private view returns(bool) {
    for(uint i=0; i<raffles.length; i++) {
      if(raffles[i].nftContract() == nftContract && raffles[i].nftTokenId() == nftTokenId) {
        return true;
      }
      return false;
    }
  }

  function getRaffleNFTsByOwner(address raffleOwner) public view returns(SimpleNFT[] memory) {
    uint size = 0;
    for(uint i=0; i < raffles.length; i++) {
      if(raffles[i].owner() == raffleOwner) {
        size += 1;
      }
    }

    SimpleNFT[] memory nfts = new SimpleNFT[](size);

    uint k=0;
    for(uint i=0; i < raffles.length; i++) {
      if(raffles[i].owner() == raffleOwner) {
        nfts[k++] = SimpleNFT(raffles[i].nftContract(), raffles[i].nftTokenId());
        // ownerRaffles[k++] = raffles[i];
      }
    }

    return nfts;
  }

  function getRaffleDetailsByOwner(address raffleOwner) public view returns(RaffleDetail[] memory) {
    uint size = 0;
    for(uint i=0; i < raffles.length; i++) {
      if(raffles[i].owner() == raffleOwner) {
        size += 1;
      }
    }

    RaffleDetail[] memory details = new RaffleDetail[](size);

    uint k=0;
    for(uint i=0; i < raffles.length; i++) {
      if(raffles[i].owner() == raffleOwner) {
        // details[k++] = RaffleDetail(
        //   raffles[i].owner(),
        //   address(raffles[i]),
        //   raffles[i].nftContract(),
        //   raffles[i].nftTokenId(),
        //   raffles[i].nftTokenType(),
        //   raffles[i].expiredAt(),
        //   raffles[i].ticketCap(),
        //   raffles[i].getSoldTicketsNum(),
        //   raffles[i].ticketPrice(),
        //   raffles[i].ticketPricePointer(),
        //   uint32(i)
        // );

        uint256 tokenType = raffles[i].nftTokenType();
        if(tokenType == 721){
          string memory nftName;
          string memory nftSymbol;
          string memory nftTokenURI;
          (nftName, nftSymbol, nftTokenURI) = raffles[i].getERC721Metadata();

          details[k++] = RaffleDetail(
            raffles[i].owner(),
            address(raffles[i]),
            raffles[i].nftContract(),
            raffles[i].nftTokenId(),
            raffles[i].nftTokenType(),
            nftName,
            nftSymbol,
            nftTokenURI,
            raffles[i].expiredAt(),
            raffles[i].ticketCap(),
            raffles[i].getSoldTicketsNum(),
            raffles[i].ticketPrice(),
            raffles[i].ticketPricePointer(),
            uint32(i)
          );
        } else if(tokenType == 1155) {

        }
      }
    }

    return details;
  }

  function deleteRaffle() public {

  }

  function checkExpiredRaffles() public {
    require(owner == msg.sender, "Only owner can execute this.");

    for (uint i = 0; i < raffles.length; i++) {
      if(raffles[i].expiredAt() <= block.timestamp) {
        // 만료된 래플 처리
        // closeRaffle();
      }
    }

  }

  // case1. winner가 정해졌을 때 -> 우리가 직접 winner에게 전송
  // case2. winner가 없을 때 -> 각각의 참여자들에게 claim할 수 있게
  function closeRaffle(address raffleAddr) public {

  }

  // mapping(uint256 => Raffle) raffleMap;

  // function cancelRaffle(address raffleOwner) public {
    
  // }

}