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

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
 //error
error NftMarketPlace_PriceMustBeAboveZero();
error NftMarketPlace_NotApprovedForMarketPlace();
error NftMarketPlace_AlreadyListed(address nftAddress,
uint256  tokenId);
error NftMarketPlace_NotListed(address nftAddress,uint256 tokenId);
error NftMarketPlace_NotOwner();
error NftMarketPlace_NoProceeds();
error NftMarketPlace_PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
contract NftMarketPlace{

    //events

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256  price);

        event ItemBought(
            address indexed buyer,
            address indexed nftAddress,
            uint256 indexed tokenId,
            uint256 price
            
        );
        event nftMarketPlace_ItemRemoved(
            address indexed seller,
            address indexed nftAddress,
            uint256 indexed tokenId


        );
        event ItemUpdated
        (address indexed seller, 
        address indexed nftAddress, 
        uint indexed tokenId, 
        uint256 newPrice);
        //struct

    struct Listing{
        uint256 price;
        address seller;
    }
    //mappings
    mapping(address => mapping(uint256 => Listing))
    private s_listings; 
    mapping(address => uint256) private s_proceeds;

   // modifiers
   modifier notListed(address nftAddress, uint256 tokenId, address owner){
    Listing memory listing = s_listings[nftAddress][tokenId];
    if(listing.price > 0){
        revert NftMarketPlace_AlreadyListed(nftAddress, tokenId);
    }
    _;
    
   }
   modifier isOwner(
        address nftAddress, 
        uint256 tokenId, 
        address spender){
            IERC721 nft = IERC721(nftAddress);
            address owner = nft.ownerOf(tokenId);
            if(spender != owner){
                revert NftMarketPlace_NotOwner();
            }
            _;
        }

        modifier isListed(address nftAddress, uint256 tokenId){
    Listing memory listing = s_listings[nftAddress][tokenId];
    if(listing.price <= 0){
        revert NftMarketPlace_NotListed(nftAddress, tokenId);
    }
    _;
    
   }
    //MainFunctions

    //listing the item

    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price) 
        external notListed(nftAddress, tokenId, msg.sender)
        isOwner(nftAddress, tokenId, msg.sender){

        if(price <= 0){
            revert NftMarketPlace_PriceMustBeAboveZero();

            //owner can give the contract approval to sell 
            //their NFT, for the marketplace contract to get approval,
            // we have to use IERC20 interface from openzeppelin
        }
        IERC721 nft = IERC721(nftAddress);
        if(nft.getApproved(tokenId) != address(this)){
            revert NftMarketPlace_NotApprovedForMarketPlace();
        }
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price );

    }
    //buying the item
    function buyitem(address nftAddress, uint256 tokenId) 
    external isListed (nftAddress, tokenId) payable{
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if(msg.value < listedItem.price){
            revert NftMarketPlace_PriceNotMet(nftAddress, tokenId, listedItem.price);
        }
        //updating the Nftowner's balance....
        s_proceeds[listedItem.seller] += msg.value;

        delete(s_listings[nftAddress][tokenId]);
        IERC721(nftAddress).safeTransferFrom(listedItem.seller,
        msg.sender, tokenId);

        emit ItemBought( msg.sender, nftAddress, tokenId, listedItem.price);


        

    }

    function cancelListing(address nftAddress, uint256 tokenId) 
    external 
    isListed(nftAddress, tokenId) isOwner(nftAddress, tokenId, msg.sender){
        delete(s_listings[nftAddress][tokenId]);
        emit nftMarketPlace_ItemRemoved(msg.sender, nftAddress, tokenId);
    }
    function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice) external isListed(nftAddress, tokenId)
     isOwner(nftAddress, tokenId, msg.sender){
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemUpdated(msg.sender, nftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() external{
        uint256 proceeds = s_proceeds[msg.sender];
        if(proceeds<=0){
            revert NftMarketPlace_NoProceeds();
        }
        s_proceeds[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: proceeds}("");
        require(success, "Transfer failed");
    }
    


    //getter functions

    
    function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}
//steps to do
//1: listItem: List Nfts on the marketplace
// 2: buyItem: Buy the NFTs
// 3:canceltem: Cancel a listing
// 4: updateListing: Update Price
// 5:withdrawProceeds: Withdraw payment for my bought NFTs