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
    event Approval(address indexed owner, address indexed spender, uint256 value);

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
    function allowance(address owner, address spender) external view returns (uint256);

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

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



contract createAuctionContract is IERC721Receiver, Ownable {

    //Name of the marketplace 
     string public name;
     address public CubeContractAddress;
     address public PaymentTokenContractAddress;
    //Index of Auction
    uint256 public index =0;
    //Struct for bids
    struct Bid{
        uint256 newbid;
    }
    //Mapping to check bid against address 
    mapping (uint256=> mapping(address => Bid)) public bidByUser;

    //Structure to define auction properties 
    struct auction{
        uint256 index; //Auction index or in our project drop Id 
        uint256 nftId; //NFT id
        address auctioneer; // address of creator of auctioneer 
        address payable currentBidOwner; // Address of highhest bid owner
        uint256 currentBidPrice; // Current highest bid for the auction
        uint256 startAuctionTimestamp; // Timestamp of when auction start
        uint256 endAuctionTimestamp; // Timestamp of when auction will end 
        uint256 bidCount; // Number of bid placed on the auction 
    }
    //Array of all auction 
    auction[] private allAuctions;

    //Public event to notify that a new auction has been created 
     event newAuctions (
        uint256 index,
        uint256 nftId,
        address auctioneer,
        address currentBidOwner,
        uint256 currentBidPrice,
        uint256 startAuctionTimestamp,
        uint256 endAuctionTimestamp,
        uint256 bidCount
     );

    //Public event to notify that a new bid has been placed 
     event newBidonAuction(
        uint256 auctionIndex,
        address bidder,
        uint256 newBid
     );

    //Public event to notify the winner has calimed the NFT 
    event claimedNFT(
        uint256 auctionIndex,
        uint256 nftId,
        address winner
    );

    //Public event that Auctioneer has claimed funds
    event claimedFunds(
        uint256 auctionIndex,
        uint256 nftId,
        address auctioneer
    );

    //Public event to notfiy that NFT has be refunded by the auctioneer
    event refundedNFT(
        uint256 auctionIndex,
        uint256 nftId,
        address auctioneer
    );

    //constructor of the contract
    constructor(string memory _name,  address _CubeContractAddress, address _PaymentTokenContractAddress)
    {
        name = _name;
        CubeContractAddress= _CubeContractAddress;
        PaymentTokenContractAddress=_PaymentTokenContractAddress; 
    }
    /**
     * Check if the addres is a contract address
     * @param _addr address to verify
     */
    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
  
    function newAuction(
        uint256 _nftId,
        uint256 _minBid,
        uint256 _startAuction,
        uint256 _endAuction
    ) external returns (uint256) {

        //check the minimun bid validity 
        require(_minBid > 0, "Invalid minimum bid");

        //check the startAuction and endAuction Timestamp
        require(_startAuction <= block.timestamp, "Invalid start auction timestamp");
        require(_endAuction > block.timestamp, "Invaid end auction timestamp");

        //Get the NFT Contract 
        IERC721 cubeNFT = IERC721(CubeContractAddress);

        //Confirm that msg sender is owner of the NFT 
        require(
            cubeNFT.ownerOf(_nftId) == msg.sender,
            "You are not the owner of the NFT"
        );

        /**
         * Transfer NFT from msg sender to this contract
         * Only possible if the owner of NFT has approved this contract 
         * We can use setApprovalForAll since only adimn will be creating NFT
         */
        cubeNFT.transferFrom(msg.sender, address(this), _nftId);

        //Casting from address to address payable 
        address payable currentBidOwner = payable(address(0));

        //New object of struct auction 
        auction memory newAuc = auction({
         index: index,
         nftId: _nftId,
         auctioneer: msg.sender,
         currentBidOwner: currentBidOwner,
         currentBidPrice: _minBid,
         startAuctionTimestamp: _startAuction,
         endAuctionTimestamp: _endAuction,
         bidCount: 0
        });
   
        allAuctions.push(newAuc);
      
        //Emit the newAuction Eveny 
        emit newAuctions(
        index,
        _nftId,
        msg.sender,
        currentBidOwner,
        _minBid,
        _startAuction,
        _endAuction,
        0 
        );
        //Increment auction index
        index++;

        return index;

    }

    /**
     * Check if the auction is still open 
     * @param _auctionIndex is index of current auction
     */
    function isOpen(
        uint256 _auctionIndex
        ) public view returns(bool)
        {
            auction storage Auction = allAuctions[_auctionIndex];
            if(block.timestamp >= Auction.endAuctionTimestamp){
                return false;
            }else {
                return true;
            }
        }
        
    /**
     * Return the address of the current highest bider
     * for a specific auction
     * @param _auctionIndex Index of the auction
     */
    function getCurrentBidOwner(
        uint256 _auctionIndex)
        public
        view
        returns (address)
    {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].currentBidOwner;
    }

    /**
     * Return the current highest bid price
     * for a specific auction
     * @param _auctionIndex Index of the auction
     */
    function getCurrentBid(uint256 _auctionIndex)
        public
        view
        returns (uint256)
    {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].currentBidPrice;
    }

    /**
     * Place new bid on a specific auction
     * @param _auctionIndex Index of auction
     * @param _newBid New bid price
     */
    function bid(uint256 _auctionIndex, uint256 _newBid)
        external
        returns (bool)
    {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        auction storage Auction = allAuctions[_auctionIndex];

        // check if auction is still open
        require(isOpen(_auctionIndex), "Auction is not open");

        // check if new bid price is higher than the current one
        require(
            _newBid > Auction.currentBidPrice,
            "New bid price must be higher than the current bid"
        );

        // check if new bider is not the owner
        require(
            msg.sender != Auction.auctioneer,
            "Creator of the auction cannot place new bid"
        );

        //get Weth ERC20 token contract
        IERC20 paymentToken = IERC20(PaymentTokenContractAddress);

        //transfer token from new bider account to the marketplace account
        //to lock the tokens
        paymentToken.transferFrom(msg.sender, address(this), _newBid);
       
        //new bid is valid so must refund the current bid owner (if there is one!)
        if (Auction.bidCount != 0) {
            paymentToken.transfer(
                Auction.currentBidOwner,
                Auction.currentBidPrice
            );
        //update auction info
        address payable newBidOwner = payable(msg.sender);
        Auction.currentBidOwner = newBidOwner;
        Auction.currentBidPrice = _newBid;
        Auction.bidCount++;

        //Trigger public event
        emit newBidonAuction(_auctionIndex, msg.sender, _newBid);
       
        }
      else{
        //update auction info
        address payable newBidOwner = payable(msg.sender);
        Auction.currentBidOwner = newBidOwner;
        Auction.currentBidPrice = _newBid;
        Auction.bidCount++;
        //Trigger public event
        emit newBidonAuction(_auctionIndex, msg.sender, _newBid);
      }
      //storing bid data
       Bid storage bidbyuser= bidByUser[_auctionIndex][msg.sender];
       bidbyuser.newbid= _newBid;
       return true;
    }

    /**
     * Function used by the winner of an auction
     * to withdraw his NFT.
     * When the NFT is withdrawn, the creator of the
     * auction will receive the payment tokens in his wallet
     * @param _auctionIndex Index of auction
     */
    function claimNFT(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");

        // Check if the auction is closed
        require(!isOpen(_auctionIndex), "Auction is still open");

        // Get auction
        auction storage Auction = allAuctions[_auctionIndex];

        // Check if the caller is the winner of the auction
        require(
            Auction.currentBidOwner == msg.sender,
            "Only highest current bidder can claim NFT"
        );

        // Get NFT collection contract
        IERC721 cubeNFT = IERC721(
            CubeContractAddress
        );
        // Transfer NFT from marketplace contract
        // to the winner address
   
            cubeNFT.transferFrom(
                address(this),
                Auction.currentBidOwner,
                Auction.nftId
            );

        emit claimedNFT(_auctionIndex, Auction.nftId, msg.sender);
    }

    /**
     * Function used by the creator of an auction
     * to withdraw his tokens when the auction is closed
     * creator will get highest bid incase of there is a bidder 
     * otherwise creator will get his NFT back
     * When the Token are withdrawn, the winned of the
     * auction will receive the NFT in his wallet
     * @param _auctionIndex Index of the auction
     */
    function claimFunds(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index"); 

        // Check if the auction is closed
        require(!isOpen(_auctionIndex), "Auction is still open");

        // Get auction
        auction storage Auction = allAuctions[_auctionIndex];

        // Check if the caller is the creator of the auction
        require(
            Auction.auctioneer == msg.sender,
            "Only Auction creator can claim funds"
        );

        // Get ERC20 Payment token contract
        IERC20 paymentToken = IERC20(PaymentTokenContractAddress);
        // Transfer locked tokens from the market place contract
        // to the wallet of the creator of the auction
        paymentToken.transfer(Auction.auctioneer, Auction.currentBidPrice);

        emit claimedFunds(_auctionIndex, Auction.nftId, msg.sender);
        
    }

    /**
     * Function used by the creator of an auction
     * to get his NFT back in case the auction is closed
     * but there is no bider to make the NFT won't stay locked
     * in the contract
     * @param _auctionIndex Index of the auction
     */
    function refundNFT(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");

        // Check if the auction is closed
        require(!isOpen(_auctionIndex), "Auction is still open");

        // Get auction
        auction storage Auction = allAuctions[_auctionIndex];

        // Check if the caller is the creator of the auction
        require(
            Auction.auctioneer == msg.sender,
            "Tokens can be claimed only by the creator of the auction"
        );

        require(
            Auction.currentBidOwner == address(0),
            "Existing bider for this auction"
        );

        // Get NFT Collection contract
        IERC721 cubeNFT = IERC721(
            CubeContractAddress
        );
        // Transfer NFT back from marketplace contract
        // to the creator of the auction
        cubeNFT.transferFrom(
            address(this),
            Auction.auctioneer,
            Auction.nftId
        );

        emit refundedNFT(_auctionIndex, Auction.nftId, msg.sender);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    //Function to replace the cube token contract address with the new address
    function setCubeContractAddress(address _newAddress) external onlyOwner{
        CubeContractAddress= _newAddress;
    }

    //Function to replace the payment token contract address with the new address
    function setPaymentTokenContractAddress(address _newAddress) external onlyOwner{
        PaymentTokenContractAddress= _newAddress;
    }
    
    //Function to get bid by bidder on the particular auction
    function bidByUsers(uint256 _auctionIndex) public view returns(uint256){
         Bid storage user= bidByUser[_auctionIndex][msg.sender];
        return user.newbid;
    }
}