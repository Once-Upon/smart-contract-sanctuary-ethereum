// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibUtils } from "../libraries/LibUtils.sol";
import { LibERC721 } from "../libraries/LibERC721.sol";
import { LibMarketplace, Listing, MarketplaceLayout, TokenListingData } from "../libraries/LibMarketplace.sol";
import { IERC721 } from "../interfaces/IERC721.sol";

contract MarketplaceFacet {
  modifier listingCompliance(uint256 tokenId, uint256 price) {
    require(LibERC721.ownerOf(tokenId) == LibUtils.msgSender(), "MarketplaceFacet: Not owner of token");
    require(tokenId <= LibERC721.totalSupply(), "MarketplaceFacet: Token ID out of bounds");
    require(price > 0, "MarketplaceFacet: Price not set");
    _;
  }

  function createListing(uint256 tokenId, uint256 price) public listingCompliance(tokenId, price) {
    MarketplaceLayout storage ls = LibMarketplace.getStorage();
    require(!ls.token[tokenId].isListed, "MarketplaceFacet: Token is already listed");
    address sender = LibUtils.msgSender();
    uint256 time = block.timestamp;
    uint256 listingId = ls.listingCounts.totalListings;

    ls.listings[listingId] = Listing({
      id: listingId,
      seller: sender,
      sell_to: address(0),
      tokenId: tokenId,
      price: price,
      sold_on: 0,
      sold_to: address(0),
      cancelled: false,
      created_on: time,
      modified_on: time
    });

    ls.token[tokenId] = TokenListingData({ isListed: true, listingId: listingId });
    ls.userListings[sender].push(listingId);

    LibMarketplace.increaseCounters(ls.listingCounts, 1, 1);
    LibMarketplace.increaseCounters(ls.userCounts[sender], 1, 1);
  }

  function createPrivateListing(uint256 tokenId, uint256 price, address sell_to) public listingCompliance(tokenId, price) {
    MarketplaceLayout storage ls = LibMarketplace.getStorage();
    require(!ls.token[tokenId].isListed, "MarketplaceFacet: Token is already listed");
    require(sell_to != address(0), "MarketplaceFacet: Buyer not set");
    address sender = LibUtils.msgSender();
    uint256 time = block.timestamp;
    uint256 listingId = ls.listingCounts.totalListings;

    ls.listings[listingId] = Listing({
      id: listingId,
      seller: sender,
      sell_to: sell_to,
      tokenId: tokenId,
      price: price,
      sold_on: 0,
      sold_to: address(0),
      cancelled: false,
      created_on: time,
      modified_on: time
    });

    ls.token[tokenId] = TokenListingData({ isListed: true, listingId: listingId });
    ls.userListings[sender].push(listingId);

    LibMarketplace.increaseCounters(ls.listingCounts, 1, 1);
    LibMarketplace.increaseCounters(ls.userCounts[sender], 1, 1);
  }

  function cancelListing(uint256 listingId) public {
    Listing storage currentListing = LibMarketplace.getStorage().listings[listingId];
    require(currentListing.seller == LibUtils.msgSender(), "MarketplaceFacet: Not token seller");

    LibMarketplace.cancelListing(currentListing.tokenId);
  }

  function updateListingPrice(uint256 listingId, uint256 newPrice) public {
    Listing storage currentListing = LibMarketplace.getStorage().listings[listingId];
    require(currentListing.seller == LibUtils.msgSender(), "MarketplaceFacet: Not token seller");

    currentListing.price = newPrice;
    currentListing.modified_on = block.timestamp;
  }

  function buyToken(uint256 listingId) public payable {
    MarketplaceLayout storage ls = LibMarketplace.getStorage();
    Listing storage currentListing = ls.listings[listingId];
    TokenListingData storage currentToken = ls.token[currentListing.tokenId];

    require(currentListing.sell_to == address(0), "MarketplaceFacet: Listing is private");
    require(msg.value >= currentListing.price, "MarketplaceFacet: Not enough ether sent");

    address buyer = LibUtils.msgSender();
    currentListing.sold_to = buyer;
    currentListing.sold_on = block.timestamp;
    currentToken.isListed = false;
    currentToken.listingId = 0;

    LibMarketplace.decreaseCounters(ls.listingCounts, 0, 1);
    LibMarketplace.decreaseCounters(ls.userCounts[currentListing.seller], 0, 1);

    payable(currentListing.seller).transfer(msg.value);
    IERC721(address(this)).safeTransferFrom(currentListing.seller, buyer, currentListing.tokenId, "");
  }

  function buyPrivateToken(uint256 listingId) public payable {
    MarketplaceLayout storage ls = LibMarketplace.getStorage();
    Listing storage currentListing = ls.listings[listingId];
    TokenListingData storage currentToken = ls.token[currentListing.tokenId];

    address buyer = LibUtils.msgSender();
    require(currentListing.sell_to == buyer, "MarketplaceFacet: Reserved for different address");
    require(msg.value >= currentListing.price, "MarketplaceFacet: Not enough ether sent");

    currentListing.sold_to = buyer;
    currentListing.sold_on = block.timestamp;
    currentToken.isListed = false;
    currentToken.listingId = 0;

    LibMarketplace.decreaseCounters(ls.listingCounts, 0, 1);
    LibMarketplace.decreaseCounters(ls.userCounts[currentListing.seller], 0, 1);

    payable(currentListing.seller).transfer(msg.value);
    IERC721(address(this)).safeTransferFrom(currentListing.seller, buyer, currentListing.tokenId, "");
  }

  function getListings(uint256 startId, uint256 endId) public view returns (Listing[] memory) {
    unchecked {
      require(endId >= startId, "Invalid query range");
      MarketplaceLayout storage ls = LibMarketplace.getStorage();
      uint256 listingIdx;
      uint256 endIdLimit = ls.listingCounts.totalListings;

      if (endId > endIdLimit) {
        endId = endIdLimit;
      }

      if (startId < endId) {
        uint256 rangeLength = endId - startId;
        if (rangeLength < endIdLimit) {
          endIdLimit = rangeLength;
        }
      } else {
        endIdLimit = 0;
      }
      Listing[] memory listings = new Listing[](endIdLimit);
      if (endIdLimit == 0) {
        return listings;
      }

      for (uint256 i = startId; i != endId && listingIdx != endIdLimit; ++i) {
        listings[listingIdx++] = ls.listings[i];
      }
      assembly {
        mstore(listings, listingIdx)
      }
      return listings;
    }
  }

  function getActiveListings(uint256 startId, uint256 endId) public view returns (Listing[] memory) {
    unchecked {
      require(endId >= startId, "Invalid query range");
      MarketplaceLayout storage ls = LibMarketplace.getStorage();
      uint256 listingIdx;
      uint256 endIdLimit = ls.listingCounts.totalListings;
      uint256 listingsMaxLength = ls.listingCounts.activeListings;

      if (endId > endIdLimit) {
        endId = endIdLimit;
      }

      if (startId < endId) {
        uint256 rangeLength = endId - startId;
        if (rangeLength < listingsMaxLength) {
          listingsMaxLength = rangeLength;
        }
      } else {
        listingsMaxLength = 0;
      }
      Listing[] memory listings = new Listing[](listingsMaxLength);
      if (listingsMaxLength == 0) {
        return listings;
      }

      Listing memory currentListing;

      for (uint256 i = startId; i != endId && listingIdx != listingsMaxLength; ++i) {
        currentListing = ls.listings[i];
        if (currentListing.cancelled || currentListing.sold_on > 0) {
          continue;
        } else {
          listings[listingIdx++] = currentListing;
        }
      }
      assembly {
        mstore(listings, listingIdx)
      }
      return listings;
    }
  }

  function getListingsForAddress(address seller) public view returns (Listing[] memory) {
    unchecked {
      MarketplaceLayout storage ls = LibMarketplace.getStorage();
      uint256 listingIdx;
      uint256 endId = ls.userCounts[seller].totalListings;
      uint256[] memory userListings = ls.userListings[seller];

      Listing[] memory listings = new Listing[](endId);
      if (endId == 0) {
        return listings;
      }

      for (uint256 i = 0; i != endId && listingIdx != endId; ++i) {
        listings[listingIdx++] = ls.listings[userListings[i]];
      }
      assembly {
        mstore(listings, listingIdx)
      }
      return listings;
    }
  }

  function getActiveListingsForAddress(address seller) public view returns (Listing[] memory) {
    unchecked {
      MarketplaceLayout storage ls = LibMarketplace.getStorage();
      uint256 listingIdx;
      uint256 endId = ls.userCounts[seller].totalListings;
      uint256 listingsMaxLength = ls.userCounts[seller].activeListings;
      uint256[] memory userListings = ls.userListings[seller];

      Listing[] memory listings = new Listing[](listingsMaxLength);
      if (listingsMaxLength == 0) {
        return listings;
      }

      Listing memory currentListing;

      for (uint256 i = 0; i != endId && listingIdx != listingsMaxLength; ++i) {
        currentListing = ls.listings[userListings[i]];
        if (currentListing.cancelled || currentListing.sold_on > 0) {
          continue;
        } else {
          listings[listingIdx++] = currentListing;
        }
      }
      assembly {
        mstore(listings, listingIdx)
      }
      return listings;
    }
  }
}

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.3
// Creator: Chiru Labs

pragma solidity ^0.8.20;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721 {
  /**
   * The caller must own the token or be an approved operator.
   */
  error ApprovalCallerNotOwnerNorApproved();

  /**
   * The token does not exist.
   */
  error ApprovalQueryForNonexistentToken();

  /**
   * Cannot query the balance for the zero address.
   */
  error BalanceQueryForZeroAddress();

  /**
   * Cannot mint to the zero address.
   */
  error MintToZeroAddress();

  /**
   * The quantity of tokens minted must be more than zero.
   */
  error MintZeroQuantity();

  /**
   * The token does not exist.
   */
  error OwnerQueryForNonexistentToken();

  /**
   * The caller must own the token or be an approved operator.
   */
  error TransferCallerNotOwnerNorApproved();

  /**
   * The token must be owned by `from`.
   */
  error TransferFromIncorrectOwner();

  /**
   * Cannot safely transfer to a contract that does not implement the
   * ERC721Receiver interface.
   */
  error TransferToNonERC721ReceiverImplementer();

  /**
   * Cannot transfer to the zero address.
   */
  error TransferToZeroAddress();

  /**
   * The token does not exist.
   */
  error URIQueryForNonexistentToken();

  /**
   * The `extraData` cannot be set on an unintialized ownership slot.
   */
  error OwnershipNotInitializedForExtraData();

  // =============================================================
  //                            STRUCTS
  // =============================================================

  struct TokenOwnership {
    // The address of the owner.
    address addr;
    // Stores the start time of ownership with minimal overhead for tokenomics.
    uint64 startTimestamp;
    // Whether the token has been burned.
    bool burned;
    // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
    uint24 extraData;
  }

  // =============================================================
  //                         TOKEN COUNTERS
  // =============================================================

  /**
   * @dev Returns the total number of tokens in existence.
   * Burned tokens will reduce the count.
   * To get the total number of tokens minted, please see {_totalMinted}.
   */
  function totalSupply() external view returns (uint256);

  // =============================================================
  //                            IERC721
  // =============================================================

  /**
   * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
   */
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  /**
   * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
   */
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

  /**
   * @dev Emitted when `owner` enables or disables
   * (`approved`) `operator` to manage all of its assets.
   */
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  /**
   * @dev Returns the number of tokens in `owner`'s account.
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
   * @dev Safely transfers `tokenId` token from `from` to `to`,
   * checking first that contract recipients are aware of the ERC721 protocol
   * to prevent tokens from being forever locked.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must exist and be owned by `from`.
   * - If the caller is not `from`, it must be have been allowed to move
   * this token by either {approve} or {setApprovalForAll}.
   * - If `to` refers to a smart contract, it must implement
   * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external payable;

  /**
   * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId) external payable;

  /**
   * @dev Transfers `tokenId` from `from` to `to`.
   *
   * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
   * whenever possible.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must be owned by `from`.
   * - If the caller is not `from`, it must be approved to move this token
   * by either {approve} or {setApprovalForAll}.
   *
   * Emits a {Transfer} event.
   */
  function transferFrom(address from, address to, uint256 tokenId) external payable;

  /**
   * @dev Gives permission to `to` to transfer `tokenId` token to another account.
   * The approval is cleared when the token is transferred.
   *
   * Only a single account can be approved at a time, so approving the
   * zero address clears previous approvals.
   *
   * Requirements:
   *
   * - The caller must own the token or be an approved operator.
   * - `tokenId` must exist.
   *
   * Emits an {Approval} event.
   */
  function approve(address to, uint256 tokenId) external payable;

  /**
   * @dev Approve or remove `operator` as an operator for the caller.
   * Operators can call {transferFrom} or {safeTransferFrom}
   * for any token owned by the caller.
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
   * See {setApprovalForAll}.
   */
  function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibUtils } from "./LibUtils.sol";
import { LibIdentity } from "./LibIdentity.sol";
import { LibMarketplace } from "./LibMarketplace.sol";

interface IERC721Receiver {
  function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

struct TokenApprovalRef {
  address value;
}

struct StorageLayout {
  string name;
  string symbol;
  uint16 maxSupply;
  uint16 creatorSupply;
  uint16 creatorMaxSupply;
  bool burnActive;
  uint256 _currentIndex;
  uint256 _burnCounter;
  mapping(uint256 => uint256) _packedOwnerships;
  mapping(address => uint256) _packedAddressData;
  mapping(uint256 => TokenApprovalRef) _tokenApprovals;
  mapping(address => mapping(address => bool)) _operatorApprovals;
}

//solhint-disable no-inline-assembly, reason-string, no-empty-blocks
library LibERC721 {
  bytes32 internal constant STORAGE_SLOT = keccak256("ERC721A.contracts.storage.ERC721A");
  uint256 internal constant _BITMASK_ADDRESS_DATA_ENTRY = (1 << 64) - 1;
  uint256 internal constant _BITMASK_BURNED = 1 << 224;
  uint256 internal constant _BITPOS_NUMBER_BURNED = 128;
  uint256 internal constant _BITMASK_NEXT_INITIALIZED = 1 << 225;
  uint256 internal constant _BITMASK_ADDRESS = (1 << 160) - 1;

  function getStorage() internal pure returns (StorageLayout storage strg) {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      strg.slot := slot
    }
  }

  // =============================================================
  //                        MINT OPERATIONS
  // =============================================================

  function _mint(address to, uint256 quantity) internal {
    StorageLayout storage ds = getStorage();
    uint256 startTokenId = ds._currentIndex;

    require(quantity > 0, "LibERC721: Cant mint 0 tokens");
    bytes32 transferEventSig = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 bitMaskAddress = (1 << 160) - 1;
    _beforeTokenTransfers(address(0), to, startTokenId, quantity);

    unchecked {
      ds._packedAddressData[to] += quantity * ((1 << 64) | 1);
      ds._packedOwnerships[startTokenId] = _packOwnershipData(to, _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0));

      uint256 toMasked;
      uint256 end = startTokenId + quantity;

      assembly {
        toMasked := and(to, bitMaskAddress)
        log4(0, 0, transferEventSig, 0, toMasked, startTokenId)
        for {
          let tokenId := add(startTokenId, 1)
        } iszero(eq(tokenId, end)) {
          tokenId := add(tokenId, 1)
        } {
          log4(0, 0, transferEventSig, 0, toMasked, tokenId)
        }
      }
      require(toMasked != 0, "LibERC721: Cant mint to zero address");
      ds._currentIndex = end;
    }
    _afterTokenTransfers(address(0), to, startTokenId, quantity);
  }

  function _safeMint(address to, uint256 quantity, bytes memory _data) internal {
    StorageLayout storage ds = getStorage();
    _mint(to, quantity);

    unchecked {
      if (to.code.length != 0) {
        uint256 end = ds._currentIndex;
        uint256 index = end - quantity;
        do {
          if (!_checkContractOnERC721Received(address(0), to, index++, _data)) {
            revert("LibERC721: Transfer to non ERC721Receiver");
          }
        } while (index < end);
        // Reentrancy protection.
        // solhint-disable-next-line reason-string
        if (ds._currentIndex != end) revert();
      }
    }
  }

  function _safeMint(address to, uint256 quantity) internal {
    _safeMint(to, quantity, "");
  }

  // =============================================================
  //                        BURN OPERATIONS
  // =============================================================

  function _burn(uint256 tokenId) internal {
    _burn(tokenId, false);
  }

  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  function _burn(uint256 tokenId, bool approvalCheck) internal {
    StorageLayout storage ds = getStorage();
    uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);
    address from = address(uint160(prevOwnershipPacked));
    (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

    if (approvalCheck) {
      if (!_isSenderApprovedOrOwner(approvedAddress, from, LibUtils.msgSender()))
        if (!isApprovedForAll(from, LibUtils.msgSender())) revert("LibERC721: Call not authorized");
    }

    LibERC721._beforeTokenTransfers(from, address(0), tokenId, 1);

    assembly {
      if approvedAddress {
        sstore(approvedAddressSlot, 0)
      }
    }

    unchecked {
      ds._packedAddressData[from] += (1 << _BITPOS_NUMBER_BURNED) - 1;
      ds._packedOwnerships[tokenId] = LibERC721._packOwnershipData(
        from,
        (_BITMASK_BURNED | _BITMASK_NEXT_INITIALIZED) | LibERC721._nextExtraData(from, address(0), prevOwnershipPacked)
      );

      if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
        uint256 _nextTokenId = tokenId + 1;
        if (ds._packedOwnerships[_nextTokenId] == 0) {
          if (_nextTokenId != ds._currentIndex) {
            ds._packedOwnerships[_nextTokenId] = prevOwnershipPacked;
          }
        }
      }
    }

    emit Transfer(from, address(0), tokenId);
    LibERC721._afterTokenTransfers(from, address(0), tokenId, 1);

    unchecked {
      ds._burnCounter++;
    }
  }

  function transferFrom(address from, address to, uint256 tokenId) internal {
    StorageLayout storage ds = getStorage();
    uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

    if (address(uint160(prevOwnershipPacked)) != from) revert("LibERC721: Transfer from incorrect owner");

    (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

    if (!_isSenderApprovedOrOwner(approvedAddress, from, LibUtils.msgSender()))
      if (!isApprovedForAll(from, LibUtils.msgSender()) || LibUtils.msgSender() != address(this)) revert("LibERC721: Caller not owner nor approved");

    if (to == address(0)) revert("LibERC721: Transfer to zero address");

    _beforeTokenTransfers(from, to, tokenId, 1);

    assembly {
      if approvedAddress {
        sstore(approvedAddressSlot, 0)
      }
    }

    unchecked {
      --ds._packedAddressData[from];
      ++ds._packedAddressData[to];

      ds._packedOwnerships[tokenId] = _packOwnershipData(to, _BITMASK_NEXT_INITIALIZED | _nextExtraData(from, to, prevOwnershipPacked));

      if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
        uint256 _nextTokenId = tokenId + 1;
        if (ds._packedOwnerships[_nextTokenId] == 0) {
          if (_nextTokenId != ds._currentIndex) {
            ds._packedOwnerships[_nextTokenId] = prevOwnershipPacked;
          }
        }
      }
    }

    emit Transfer(from, to, tokenId);
    _afterTokenTransfers(from, to, tokenId, 1);
  }

  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) internal {
    transferFrom(from, to, tokenId);
    if (to.code.length != 0)
      if (!_checkContractOnERC721Received(from, to, tokenId, _data)) {
        revert("LibERC721: Transfer to non ERC721 receiver");
      }
  }

  function isApprovedForAll(address owner, address operator) internal view returns (bool) {
    return getStorage()._operatorApprovals[owner][operator];
  }

  function _isSenderApprovedOrOwner(address approvedAddress, address owner, address msgSender) internal pure returns (bool result) {
    assembly {
      owner := and(owner, _BITMASK_ADDRESS)
      msgSender := and(msgSender, _BITMASK_ADDRESS)
      result := or(eq(msgSender, owner), eq(msgSender, approvedAddress))
    }
  }

  function _checkContractOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) internal returns (bool) {
    try IERC721Receiver(to).onERC721Received(LibUtils.msgSender(), from, tokenId, _data) returns (bytes4 retval) {
      return retval == IERC721Receiver(to).onERC721Received.selector;
    } catch (bytes memory reason) {
      require(reason.length > 0, "LibERC721: Transfer to non ERC721Receiver");
      assembly {
        revert(add(32, reason), mload(reason))
      }
    }
  }

  function _beforeTokenTransfers(address from, address to, uint256 tokenId, uint256 quantity) internal {}

  function _afterTokenTransfers(address from, address, uint256 tokenId, uint256) internal {
    if (from != address(0)) {
      if (balanceOf(from) == 0) LibIdentity.nukeIdentity(from);
      if (LibMarketplace.isListed(tokenId)) LibMarketplace.cancelListing(tokenId);
    }
  }

  function _nextInitializedFlag(uint256 quantity) internal pure returns (uint256 result) {
    // For branchless setting of the `nextInitialized` flag.
    assembly {
      // `(quantity == 1) << _BITPOS_NEXT_INITIALIZED`.
      result := shl(225, eq(quantity, 1))
    }
  }

  function _nextExtraData(address from, address to, uint256 prevOwnershipPacked) internal view returns (uint256) {
    uint24 extraData = uint24(prevOwnershipPacked >> 232);
    return uint256(_extraData(from, to, extraData)) << 232;
  }

  function _extraData(address from, address to, uint24 previousExtraData) internal view returns (uint24) {}

  function _packOwnershipData(address owner, uint256 flags) internal view returns (uint256 result) {
    uint256 bitMaskAddress = (1 << 160) - 1;
    assembly {
      // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
      owner := and(owner, bitMaskAddress)
      // `owner | (block.timestamp << _BITPOS_START_TIMESTAMP) | flags`.
      result := or(owner, or(shl(160, timestamp()), flags))
    }
  }

  function _startTokenId() internal pure returns (uint256) {
    return 1;
  }

  function nextTokenId() internal view returns (uint256) {
    return getStorage()._currentIndex;
  }

  function balanceOf(address owner) internal view returns (uint256) {
    require(owner != address(0), "LibERC721: Invalid address");
    return LibERC721.getStorage()._packedAddressData[owner] & LibERC721._BITMASK_ADDRESS_DATA_ENTRY;
  }

  function ownerOf(uint256 tokenId) internal view returns (address) {
    return address(uint160(_packedOwnershipOf(tokenId)));
  }

  function totalSupply() internal view returns (uint256) {
    // Counter underflow is impossible as _burnCounter cannot be incremented
    // more than `_currentIndex - _startTokenId()` times.
    unchecked {
      return getStorage()._currentIndex - getStorage()._burnCounter - _startTokenId();
    }
  }

  function _packedOwnershipOf(uint256 tokenId) internal view returns (uint256 packed) {
    StorageLayout storage ds = LibERC721.getStorage();
    if (LibERC721._startTokenId() <= tokenId) {
      packed = ds._packedOwnerships[tokenId];
      if (packed & _BITMASK_BURNED == 0) {
        if (packed == 0) {
          if (tokenId >= ds._currentIndex) revert("LibERC721: Owner query for non existing token");
          for (;;) {
            unchecked {
              packed = ds._packedOwnerships[--tokenId];
            }
            if (packed == 0) continue;
            return packed;
          }
        }
        return packed;
      }
    }
    revert("LibERC721: Owner query for non existing token");
  }

  function _getApprovedSlotAndAddress(uint256 tokenId) internal view returns (uint256 approvedAddressSlot, address approvedAddress) {
    TokenApprovalRef storage tokenApproval = getStorage()._tokenApprovals[tokenId];
    assembly {
      approvedAddressSlot := tokenApproval.slot
      approvedAddress := sload(approvedAddressSlot)
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct IDField {
  string name;
  string data;
}

struct Identity {
  uint8 fieldCount;
  uint8 unlockedFields;
  uint16 assignedToken;
  uint256 scrollId;
  mapping(uint8 => IDField) fields;
}

struct IdentityExternal {
  uint8 fieldCount;
  uint8 unlockedFields;
  IDField[] fields;
}

struct IdentityLayout {
  uint8 maxFields;
  uint8 maxScrollsPerToken;
  uint16 identitiesRecorded;
  uint256 scrollSupply;
  mapping(uint256 => bool) usedScrolls;
  mapping(address => Identity) userIdentity;
}

library LibIdentity {
  bytes32 internal constant IDENTITY_DATA_SLOT = keccak256("user.identity.data.layout");

  function getStorage() internal pure returns (IdentityLayout storage strg) {
    bytes32 slot = IDENTITY_DATA_SLOT;
    assembly {
      strg.slot := slot
    }
  }

  function nukeIdentity(address user) internal {
    IdentityLayout storage idStorage = getStorage();

    for (uint8 i = 0; i < idStorage.userIdentity[user].fieldCount; i++) {
      delete idStorage.userIdentity[user].fields[i];
    }

    idStorage.identitiesRecorded--;
    delete idStorage.userIdentity[user].fieldCount;
    delete idStorage.userIdentity[user].unlockedFields;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Listing {
  uint256 id;
  address seller;
  address sell_to;
  uint256 tokenId;
  uint256 price;
  uint256 sold_on;
  address sold_to;
  bool cancelled;
  uint256 created_on;
  uint256 modified_on;
}

struct ListingCounters {
  uint256 totalListings;
  uint256 activeListings;
}

struct TokenListingData {
  bool isListed;
  uint256 listingId;
}

struct MarketplaceLayout {
  ListingCounters listingCounts;
  mapping(uint256 => Listing) listings;
  mapping(address => ListingCounters) userCounts;
  mapping(address => uint256[]) userListings;
  mapping(uint256 => TokenListingData) token;
}

library LibMarketplace {
  bytes32 internal constant MARKETPLACE_DATA_SLOT = keccak256("erc721.marketplace.storage.layout");

  function getStorage() internal pure returns (MarketplaceLayout storage strg) {
    bytes32 slot = MARKETPLACE_DATA_SLOT;
    assembly {
      strg.slot := slot
    }
  }

  function increaseCounters(ListingCounters storage strg, uint256 total, uint256 active) internal {
    strg.totalListings += total;
    strg.activeListings += active;
  }

  function decreaseCounters(ListingCounters storage strg, uint256 total, uint256 active) internal {
    strg.totalListings -= total;
    strg.activeListings -= active;
  }

  function cancelListing(uint256 tokenId) internal {
    MarketplaceLayout storage ls = getStorage();
    TokenListingData storage currentToken = ls.token[tokenId];
    Listing storage currentListing = ls.listings[currentToken.listingId];

    currentListing.cancelled = true;
    currentListing.modified_on = block.timestamp;
    ls.token[tokenId] = TokenListingData({ isListed: false, listingId: 0 });

    decreaseCounters(ls.listingCounts, 0, 1);
    decreaseCounters(ls.userCounts[currentListing.seller], 0, 1);
  }

  function isListed(uint256 tokenId) internal view returns (bool) {
    return getStorage().token[tokenId].isListed;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// solhint-disable no-inline-assembly
library LibUtils {
  function msgSender() internal view returns (address sender_) {
    if (msg.sender == address(this)) {
      bytes memory array = msg.data;
      uint256 index = msg.data.length;
      assembly {
        // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
        sender_ := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
      }
    } else {
      sender_ = msg.sender;
    }
  }

  function numberToString(uint256 value) internal pure returns (string memory str) {
    assembly {
      let m := add(mload(0x40), 0xa0)
      mstore(0x40, m)
      str := sub(m, 0x20)
      mstore(str, 0)

      let end := str

      // prettier-ignore
      // solhint-disable-next-line no-empty-blocks
      for { let temp := value } 1 {} {
        str := sub(str, 1)
        mstore8(str, add(48, mod(temp, 10)))
        temp := div(temp, 10)
        if iszero(temp) { break }
      }

      let length := sub(end, str)
      str := sub(str, 0x20)
      mstore(str, length)
    }
  }

  function addressToString(address _addr) internal pure returns (string memory) {
    bytes32 value = bytes32(uint256(uint160(_addr)));
    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(42);
    str[0] = "0";
    str[1] = "x";
    for (uint i = 0; i < 20; i++) {
      str[2 + i * 2] = alphabet[uint(uint8(value[i + 12] >> 4))];
      str[3 + i * 2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
    }
    return string(str);
  }

  function getMax(uint256[6] memory nums) internal pure returns (uint256 maxNum) {
    maxNum = nums[0];
    for (uint256 i = 1; i < nums.length; i++) {
      if (nums[i] > maxNum) maxNum = nums[i];
    }
  }

  function compareStrings(string memory str1, string memory str2) internal pure returns (bool) {
    return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
  }
}