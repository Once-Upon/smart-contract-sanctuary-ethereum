// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
pragma abicoder v2;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

library Status {

    function isAuctionOn(bool status) internal pure {
        require(!status, "Already auction created for this NFT!");
    }

    function isSaleOn(bool status) internal pure {
        require(!status, "Already sale created for this NFT!");
    }

    function isSaleOff(bool status) internal pure {
        require(status,"NFT is not on sale");
    }

    function isSaleOnOrisAuctionOn(bool _isSaleOn,bool _isAuctionOn) internal pure {
        require(!(_isSaleOn) || !(_isAuctionOn), "Already sale created for this NFT!");        
    }

}

library checkContract {
    
    function isContract(address _addr) internal view  {
        uint256 size = 1;
        assembly {
            size := extcodesize(_addr)
        }
        require((size > 0),"Invalid NFT Collection contract address");
    }

}

library Math {
    function isMax(uint x, uint y) internal pure {
        require((x>y) ,"Invalid data");
    }

    function isEqual(address x,address y) internal pure{
        require(x==y,"revert");
    }
}


interface IERC721AND1155  {

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );


    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    //721 

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);


    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

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

    function setApprovalForAll(address operator, bool _approved) external;

    function getApproved(uint256 tokenId) external view returns (address operator);

    function isApprovedForAll(address owner, address operator) external view returns (bool);
}



interface IERC20 {
    
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract TestUUPSMarketPlaceV1 is Initializable,IERC721Receiver, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    string public name;

    // Index of auctions
    uint256 private auctionIndex ;

    // Index of sales
    uint256 private saleIndex ;
    uint256 private SaleBatchIndex;
    uint256 public rateDecimals;
    uint256 public serviceFee;
    // uint256 public royaltyFee;
    address public serviceWallet;
    address public admin;



    function initialize(string memory _name) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        name = _name;
        auctionIndex = 0;
        saleIndex = 0 ;
        SaleBatchIndex=0;
        setAdmin(_msgSender());
        rateDecimals = 2;
        serviceFee = 250;
        // royaltyFee = 500;
        setServiceWalletAddress(_msgSender());
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}


    // Structure to define auction properties
    struct Auction {
        uint256 auctionIndex; // Auction Index
        address addressNFTCollection; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 nftId; // NFT Id
        address creator; // Creator of the Auction
        address payable currentBidOwner; // Address of the highest bider
        uint256 currentBidPrice; // Current highest bid for the auction
        uint256 endAuction; // Timestamp for the end day&time of the auction
        uint256 bidCount; // Number of bid placed on the auction
        bool isAuctionOn;
        bool isCurrentBidCancelled;
        uint256 reservePrice;
        uint256 royaltyFee;
    }

    mapping(uint256 => mapping(address => Auction)) public nftAuctionData;

    // Structure to define Sale properties
    struct Sale {
        uint256 saleIndex;
        address addressNFTCollection; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 nftId; // NFT Id
        address creator; // Creator of the Sale
        uint256 nftPrice;
        uint256 amount;
        uint256 nftCount; // count for nft that has been sale
        bool isOnSale;
        uint256 royaltyFee;

    }

    // Structure to define Sale properties
    struct SaleBatch {
        uint256 saleIndex;
        address addressNFTCollection; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 nftId; // NFT Id
        address creator; // Creator of the Sale
        uint256 nftPrice;
        uint256 amount;
        uint256 nftPurchasedCount; // count for nft that has been sale
        bool isOnSale;
        uint256 royaltyFee;
    }

    mapping(uint256 => SaleBatch) public nftSaleDataBatch;
    // uint SaleBatchIndex;

    mapping(uint256 => mapping(address => Sale)) public nftSaleData;

    // Array will store all auctions
    Auction[] private allAuctions;

    // Array will store all sales
    Sale[] private allSales;

    // Public event to notify that a new auction has been created
    event NewAuction(
        uint256 auctionIndex,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        address mintedBy,
        address currentBidOwner,
        uint256 currentBidPrice,
        uint256 endAuction,
        uint256 bidCount,
        bool isAuctionOn,
        uint256 reservePrice,
        uint256 royaltyFee
    );

    // Public event to notify that a new sale has been created
    event NewSale(
        uint256 saleIndex,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        address mintedBy,
        uint256 nftPrice,
        uint256 royaltyFee
    );

    event NewSaleBatch(
        uint256 saleIndex,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        address mintedBy,
        uint256 nftPrice,
        uint256 nftAmount,
        uint256 _collectionItemId,
        uint256 royaltyFee
    );

    // Public event to notify that a new bid has been placed
    event NewBidOnAuction(
        address _newBidOwner,
        uint256 _newBid,
        uint256 _nftId,
        address _nftCollection
    );

    // Public event to notify that winner of an
    // auction claimed his reward
    event NFTClaimed(
        address _nftCollection,
        uint256 _nftId,
        address _claimedBy,
        address _OwnedBy,
        uint256 _bidPrice,
        uint256 royaltyFee
        
    );

    // Public event to notify that a buyer bought an NFT
    event BoughtNFT(
        address collectionAddress,
        uint256 nftId,
        address soldBy,
        address boughtBy,
        uint256 price
    );

    event BoughtNFTBatch(
        address collectionAddress,
        uint256 nftId,
        address soldBy,
        address boughtBy,
        uint256 price,
        uint256 amounts,
        uint256 collectionItemId
    );

    // Public event to notify that the creator of
    // an auction claimed for his money(Tokens)
    event TokensClaimed(
        address _nftCollection,
        uint256 _nftId,
        address _claimedBy,
        address _OwnedBy,
        uint256 _bidPrice
    );

    // Public event to notify that an NFT has been refunded to the
    // creator of an auction
    event NFTRefunded(
        address _nftCollection,
        uint256 _nftId,
        address _claimedBy
    );

    event tokenTransferEvent(
        address collectionAddress,
        uint256 nftId,
        address soldBy,
        address boughtBy,
        uint256 price,
        uint256 amounts
    );

    modifier onlyOwnerAndAdmin() {
        require(
            owner() == _msgSender() || _msgSender() == admin,
            "Ownable: caller is not the owner or admin"
        );
        _;
    }

    /**
     * Check if a specific address is
     * a contract address
     * @param _addr: address to verify
    */

    /**
     * Create a new auction of a specific NFT
     * @param _addressNFTCollection address of the ERC721 NFT collection contract
     * @param _addressPaymentToken address of the ERC20 payment token contract
     * @param _nftId Id of the NFT for sale
     * @param _initialBid Inital bid decided by the creator of the auction
     * @param _endAuction Timestamp with the end date and time of the auction
    */

    function createAuction(
        address _addressNFTCollection,
        address _addressPaymentToken,
        uint256 _nftId,
        uint256 _initialBid,
        uint256 _endAuction,
        uint256 _reservePrice,
        uint256 _royaltyFee
    ) external returns (uint256) {

        Status.isSaleOnOrisAuctionOn(nftSaleData[_nftId][_addressNFTCollection].isOnSale,nftAuctionData[_nftId][_addressNFTCollection].isAuctionOn);
        //Check is addresses are valid
        checkContract.isContract(_addressNFTCollection);
        // Check if the endAuction time is valid
        // require(_endAuction > block.timestamp, "Invalid end date for auction");
        Math.isMax(_endAuction, block.timestamp);

        // Check if the initial bid price is > 0
        Math.isMax(_initialBid, 0);
        // require(_initialBid > 0, "Invalid initial bid price");

        // Get NFT collection contract
        IERC721AND1155 nftCollection = IERC721AND1155(_addressNFTCollection);

        // Make sure the sender that wants to create a new auction
        // for a specific NFT is the owner of this NFT
        // require(nftCollection.ownerOf(_nftId) == _msgSender(),"Caller is not the owner of the NFT");
        Math.isEqual(nftCollection.ownerOf(_nftId) , _msgSender());
        
        // Need to call APPROVE in the NFT collection contract

        // Make sure the owner of the NFT approved that the MarketPlace contract
        // is allowed to change ownership of the NFT
        // require(nftCollection.getApproved(_nftId) == address(this),"Require NFT ownership transfer approval");
        Math.isEqual(nftCollection.getApproved(_nftId),address(this));

        // Need to call TRANSFER_NFT in the NFT collection contract

        // Lock NFT in Marketplace contract
        nftCollection.safeTransferFrom(_msgSender(), address(this), _nftId);

        //Casting from address to address payable
        address payable currentBidOwner = payable(address(0));

        // Create new Auction object
        Auction memory newAuction = Auction({
            auctionIndex: auctionIndex,
            addressNFTCollection: _addressNFTCollection,
            addressPaymentToken: _addressPaymentToken,
            nftId: _nftId,
            creator: _msgSender(),
            currentBidOwner: currentBidOwner,
            currentBidPrice: _initialBid,
            endAuction: _endAuction,
            bidCount: 0,
            isAuctionOn: true,
            isCurrentBidCancelled:false,
            reservePrice:_reservePrice,
            royaltyFee :_royaltyFee

        });

        //update list
        allAuctions.push(newAuction);
        nftAuctionData[_nftId][_addressNFTCollection] = newAuction;

        // increment auction sequence
        auctionIndex++;

        // Trigger event and return index of new auction
        emit NewAuction(
            auctionIndex,
            _addressNFTCollection,
            _addressPaymentToken,
            _nftId,
            _msgSender(),
            currentBidOwner,
            _initialBid,
            _endAuction,
            0,
            true,
            newAuction.reservePrice,
            newAuction.royaltyFee
        );
        return auctionIndex;
    }

    //contract 
    function createSale(
        address _addressNFTCollection,
        address _addressPaymentToken,
        uint256 _nftId,
        uint256 _nftPrice,
        uint256 _royaltyFee
    ) external returns (uint256) {

        Status.isSaleOnOrisAuctionOn(nftSaleData[_nftId][_addressNFTCollection].isOnSale,nftAuctionData[_nftId][_addressNFTCollection].isAuctionOn);

        //Check is addresses are valid
        checkContract.isContract(_addressNFTCollection);


        // Get NFT collection contract
        // NFTCollection nftCollection = NFTCollection(_addressNFTCollection);
        IERC721AND1155 nftCollection = IERC721AND1155(_addressNFTCollection);


        // Make sure the sender is the owner of this NFT
        // require(
        //     nftCollection.ownerOf(_nftId) == _msgSender(),
        //     "Caller is not the owner of the NFT"
        // );
        Math.isEqual(nftCollection.ownerOf(_nftId) , _msgSender());
        // require(
        //     nftCollection.getApproved(_nftId) == address(this),
        //     "Require NFT ownership transfer approval"
        // );
        Math.isEqual(nftCollection.getApproved(_nftId) , address(this));
        

        // Need to call TRANSFER_NFT in the NFT collection contract
        // Lock NFT in Marketplace contract
        nftCollection.safeTransferFrom(_msgSender(), address(this), _nftId);


        // create new sale object
        Sale memory newSale = Sale({
            saleIndex: saleIndex,
            addressNFTCollection: _addressNFTCollection,
            addressPaymentToken: _addressPaymentToken,
            nftId: _nftId,
            creator: _msgSender(),
            nftPrice: _nftPrice,
            amount:0,
            nftCount:0,
            isOnSale: true,
            royaltyFee :_royaltyFee

        });

        allSales.push(newSale);
        nftSaleData[_nftId][_addressNFTCollection] = newSale;

        saleIndex++;

        emit NewSale(
            saleIndex,
            _addressNFTCollection,
            _addressPaymentToken,
            _nftId,
            _msgSender(),
            _nftPrice,
            _royaltyFee
        );
        return saleIndex;
    }


    function enableReAuction(address _addressNFTCollection,
            address _addressPaymentToken,
            uint256 _nftId,
            uint256 _initialBid,
            uint256 _endAuction,
            uint256 _reservePrice) external{

            Status.isSaleOnOrisAuctionOn(nftSaleData[_nftId][_addressNFTCollection].isOnSale,nftAuctionData[_nftId][_addressNFTCollection].isAuctionOn);

            //Check is addresses are valid
            checkContract.isContract(_addressNFTCollection);
            checkContract.isContract(_addressPaymentToken);



            // Check if the endAuction time is valid
            // require(_endAuction > block.timestamp, "Invalid end date for auction");
            Math.isMax(_endAuction, block.timestamp);


            // Check if the initial bid price is > 0
            // require(_initialBid > 0, "Invalid initial bid price");
            Math.isMax(_initialBid, 0);

            // Get NFT collection contract
            // NFTCollection nftCollection = NFTCollection(_addressNFTCollection);
            IERC721AND1155 nftCollection = IERC721AND1155(_addressNFTCollection);

            // Make sure the sender that wants to create a new auction
            // for a specific NFT is the owner of this NFT
            // require(nftCollection.ownerOf(_nftId) == _msgSender(),"Caller is not the owner of the NFT");
            Math.isEqual(nftCollection.ownerOf(_nftId),_msgSender());
            // require(nftCollection.getApproved(_nftId) == address(this),"Require NFT ownership transfer approval");
            Math.isEqual(nftCollection.getApproved(_nftId),address(this));

            nftCollection.safeTransferFrom(_msgSender(), address(this), _nftId);
            
            address payable _currentBidOwner = payable(address(0));

           
            nftAuctionData[_nftId][_addressNFTCollection].addressPaymentToken = _addressPaymentToken;
            nftAuctionData[_nftId][_addressNFTCollection].currentBidPrice = _initialBid;
            nftAuctionData[_nftId][_addressNFTCollection].isAuctionOn = true;
            nftAuctionData[_nftId][_addressNFTCollection].endAuction = _endAuction;
            nftAuctionData[_nftId][_addressNFTCollection].reservePrice = _reservePrice;
            nftAuctionData[_nftId][_addressNFTCollection].currentBidOwner = _currentBidOwner;

    }
    
    function createSaleForBatchTest(
        address _addressNFTCollection,
        address _addressPaymentToken,
        uint256 _nftId,
        uint256 _nftAmount,
        uint256 _nftPrice, 
        uint256 _collectionItemId,
        uint256 _royaltyFee
        ) public {
                    //Check is addresses are valid
        // require(isContract(_addressNFTCollection),"Invalid NFT Collection contract address");
        checkContract.isContract(_addressNFTCollection);

        require(IERC721AND1155(_addressNFTCollection).balanceOf(_msgSender(),_nftId) > 0 && IERC721AND1155(_addressNFTCollection).balanceOf(_msgSender(),_nftId)>=_nftAmount,"User Does not have enough tokens");
        SaleBatchIndex++;

        SaleBatch memory Data = SaleBatch({
            saleIndex: SaleBatchIndex,
            addressNFTCollection: _addressNFTCollection,
            addressPaymentToken: _addressPaymentToken,
            nftId: _nftId,
            creator: _msgSender(),
            nftPrice: _nftPrice,
            amount:_nftAmount,
            nftPurchasedCount:0,
            isOnSale: true,
            royaltyFee :_royaltyFee
            
        });

        nftSaleDataBatch[SaleBatchIndex] = Data;

        emit NewSaleBatch(
            SaleBatchIndex,
            _addressNFTCollection,
            _addressPaymentToken,
            _nftId,
            _msgSender(),
            _nftPrice,
            _nftAmount,
            _collectionItemId,
            _royaltyFee
        );
    }

    // contract 

    function buyNFT(uint256 _nftId, address _addressNFTCollection,uint256 _price,address _royaltyAddress) payable external {
        // require(isNFTOnSale(_nftId, _addressNFTCollection),"NFT is not on sale");
        Status.isSaleOff(nftSaleData[_nftId][_addressNFTCollection].isOnSale);


        Sale storage sale = nftSaleData[_nftId][_addressNFTCollection];

        require(_price >= sale.nftPrice,"Invalid NFT price");
        
        require(sale.creator != _msgSender(),"Caller shouldn't be the owner of the NFT");

        // Get NFT collection contract
        // NFTCollection nftCollection = NFTCollection(sale.addressNFTCollection);
        IERC721AND1155 nftCollection = IERC721AND1155(sale.addressNFTCollection);
        
        // Make sure the sender is the owner of this NFT
        require(nftCollection.ownerOf(sale.nftId) != _msgSender(),"Caller shouldn't be the owner of the NFT");
        nftCollection.safeTransferFrom(address(this), _msgSender(), sale.nftId);

        if(address(0)!=sale.addressPaymentToken){
            // Get ERC20 Payment token contract

            IERC20 paymentToken = IERC20(sale.addressPaymentToken);
            _royaltyAddress!= address(0) ? transferFromWithRoyalty(sale.creator,  _msgSender(),paymentToken,1,_price,_royaltyAddress,sale.royaltyFee) :transferFromToken(sale.creator,  _msgSender(),paymentToken,1,_price);
        }
        else{
            _royaltyAddress!= address(0) ? transferEthWithRoyalty(sale.creator,_price,_royaltyAddress,sale.royaltyFee) :transferEth(sale.creator,_price);
        }
        sale.isOnSale = false;
        emit BoughtNFT(
            sale.addressNFTCollection,
            sale.nftId,
            sale.creator,
            _msgSender(),
            _price
        );
    }

    function buyNftBatchTest(uint256 index,uint256 _nftId, address _addressNFTCollection,uint256 _nftAmount,uint256 _collectionItemId,address _royaltyAddress) payable external{
        
        // require(nftSaleDataBatch[index].isOnSale,"NFT is not on sale");
        Status.isSaleOff(nftSaleDataBatch[index].isOnSale);



        SaleBatch memory Data = nftSaleDataBatch[index];
        nftSaleDataBatch[index].nftPurchasedCount = nftSaleDataBatch[index].nftPurchasedCount + _nftAmount;
        nftSaleDataBatch[index].isOnSale = (nftSaleDataBatch[index].nftPurchasedCount>= nftSaleDataBatch[index].amount)?false:true;

        require(Data.creator != _msgSender(),"Caller shouldn't be the owner of the NFT");

        IERC721AND1155 nftCollection = IERC721AND1155(_addressNFTCollection);
        require(IERC721AND1155(_addressNFTCollection).balanceOf(Data.creator,_nftId) > 0 && IERC721AND1155(_addressNFTCollection).balanceOf(Data.creator,_nftId)>=_nftAmount,"User Doesn't have enough tokens");
        require(Data.nftPurchasedCount <= Data.amount,"Doesn't have enough tokens");

        nftCollection.safeTransferFrom(Data.creator, _msgSender(), _nftId, _nftAmount, "0x00");
        
        if(address(0)!=Data.addressPaymentToken){
            // Get IERC20 Payment token contract
            IERC20 paymentToken = IERC20(Data.addressPaymentToken);
            _royaltyAddress != address(0) ? transferFromWithRoyalty(Data.creator,  _msgSender(),paymentToken,_nftAmount,Data.nftPrice,_royaltyAddress,Data.royaltyFee) :transferFromToken(Data.creator,  _msgSender(),paymentToken,_nftAmount,Data.nftPrice);
        }else{
            _royaltyAddress != address(0) ? transferEthWithRoyalty(Data.creator,Data.nftPrice*_nftAmount,_royaltyAddress,Data.royaltyFee) :transferEth(Data.creator,Data.nftPrice*_nftAmount);
        }

        // Transfer tokens to NFT Owner
        emit BoughtNFTBatch(
            Data.addressNFTCollection,
            Data.nftId,
            Data.creator,
            _msgSender(),
            Data.nftPrice*_nftAmount,
            _nftAmount,
            _collectionItemId
        );
    }

    /**
    * Check if an auction is open
    */
    
    function checkAndCloseAuction(uint256 _nftId, address _nftCollection)
            internal
            returns (bool)
    {
            if (nftAuctionData[_nftId][_nftCollection].isAuctionOn) {
                if (block.timestamp >= nftAuctionData[_nftId][_nftCollection].endAuction) {
                    nftAuctionData[_nftId][_nftCollection].isAuctionOn = false;
                    return false;
                }
                return true;
            } else {
                return false;
            }
    }

    // function isAuctionOpen(uint256 _nftId, address _nftCollection) public view returns(bool){
    //     return nftAuctionData[_nftId][_nftCollection].isAuctionOn;
    // }

    // function isNFTOnSale(uint256 _nftId, address _nftCollection)
    //     public
    //     view
    //     returns (bool)
    // {
    //     return nftSaleData[_nftId][_nftCollection].isOnSale;
    // }

    /**
    * Return the address of the current highest bider
    * for a specific auction
    */

    // function getLatestBidOwner(uint256 _nftId, address _nftCollection)
    //     public
    //     view
    //     returns (address)
    // {
    //     return nftAuctionData[_nftId][_nftCollection].currentBidOwner;
    // }

    /**
    * Return the current highest bid price
    * for a specific auction
    */

    // function getCurrentBid(uint256 _nftId, address _nftCollection)
    //     public
    //     view
    //     returns (uint256)
    // {
    //     return nftAuctionData[_nftId][_nftCollection].currentBidPrice;
    // }

    /**
    * Place new bid on a specific auction
    */

    function bid(
            uint256 _nftId,
            address _nftCollection,
            uint256 _newBid
        ) payable external returns (bool _bidStatus) {

            Auction storage auction = nftAuctionData[_nftId][_nftCollection];

            if(auction.reservePrice == 0){
                                   
                // check if auction is still open
                require(checkAndCloseAuction(_nftId, _nftCollection), "Auction is not open");

                // check if new bid price is higher than the current one
                // require(_newBid > auction.currentBidPrice,"New bid price must be higher than the current bid");
                Math.isMax(_newBid, auction.currentBidPrice);


                // check if new bider is not the owner
                require(_msgSender() != auction.creator,"Creator of the auction cannot place new bid");
                
                if(auction.addressPaymentToken!=address(0)){

                    // get IERC20 token contract
                    IERC20 paymentToken = IERC20(auction.addressPaymentToken);
                    uint256 decimals = paymentToken.decimals();

                    // if new bid is better than current bid!,
                    // transfer token from new bider account to the marketplace account
                    // to lock the tokens
                    require(paymentToken.transferFrom(_msgSender(), address(this), _newBid *10**decimals),"Tranfer of token failed");

                    // new bid is valid so must refund the current bid owner (if there is one!)
                    if (auction.bidCount > 0 && !auction.isCurrentBidCancelled) {
                        paymentToken.transfer(
                            auction.currentBidOwner,
                            auction.currentBidPrice *10**decimals
                        );
                    }
                }else{

                    payable(address(this)).transfer(msg.value);
                    // new bid is valid so must refund the current bid owner (if there is one!)
                    if (auction.bidCount > 0 && !auction.isCurrentBidCancelled) {
                       payable(auction.currentBidOwner).transfer(auction.currentBidPrice);   
                    }
                }
                

                // update auction info
                address payable newBidOwner = payable(_msgSender());
                auction.currentBidOwner = newBidOwner;
                auction.currentBidPrice = _newBid;
                auction.bidCount++;

                // Trigger public event
                emit NewBidOnAuction(newBidOwner, _newBid, _nftId, _nftCollection);

                return true;
            }

            if(auction.reservePrice != 0){

                // check if auction is still open
                require(checkAndCloseAuction(_nftId, _nftCollection), "Auction is not open");

                // check if new bid price is higher than the current one
                // require(
                //     _newBid > auction.currentBidPrice,
                //     "New bid price must be higher than the current bid"
                // );
                Math.isMax(_newBid, auction.currentBidPrice);

                // check if new bider is not the owner
                require(
                    _msgSender() != auction.creator,
                    "Creator of the auction cannot place new bid"
                );

                if(auction.addressPaymentToken!=address(0)){
                    // get IERC20 token contract
                    IERC20 paymentToken = IERC20(auction.addressPaymentToken);

                    uint256 decimals = paymentToken.decimals();

                    // if new bid is better than current bid!,
                    // transfer token from new bider account to the marketplace account
                    // to lock the tokens
                    require(
                        paymentToken.transferFrom(_msgSender(), address(this), _newBid *10**decimals),
                        "Tranfer of token failed"
                    );


                    // new bid is valid so must refund the current bid owner (if there is one!)
                    if (auction.bidCount > 0 && !auction.isCurrentBidCancelled) {
                        paymentToken.transfer(
                            auction.currentBidOwner,
                            auction.currentBidPrice *10**decimals
                        );
                    }
                    
                }else{
                        payable(address(this)).transfer(msg.value);
                    // new bid is valid so must refund the current bid owner (if there is one!)
                    if (auction.bidCount > 0 && !auction.isCurrentBidCancelled) {
                       payable(auction.currentBidOwner).transfer(auction.currentBidPrice);   
                    }
                }

                
                // update auction info
                address payable newBidOwner = payable(_msgSender());
                auction.currentBidOwner = newBidOwner;
                auction.currentBidPrice = _newBid;
                auction.bidCount++;

                if(_newBid >= auction.reservePrice){
                    auction.isAuctionOn = false;
                }

                // Trigger public event
                emit NewBidOnAuction(newBidOwner, _newBid, _nftId, _nftCollection);

                return true;
            }
    }

    function cancelBid(uint256 _nftId, address _nftCollection) external {
        
        Auction storage auction = nftAuctionData[_nftId][_nftCollection];
        require(checkAndCloseAuction(_nftId, _nftCollection), "Auction is not open");
        require(
            _msgSender() != auction.creator,
            "Creator of the auction cannot cancel the bid"
        );
        // require(
        //     _msgSender() == auction.currentBidOwner,
        //     "Current bid Owner can only cancel the bid"
        // );
        Math.isEqual(auction.currentBidOwner,_msgSender() );


        if(auction.addressPaymentToken !=address(0)) {

            IERC20 paymentToken = IERC20(auction.addressPaymentToken);
            uint256 decimals = paymentToken.decimals();
            paymentToken.transfer(auction.currentBidOwner,auction.currentBidPrice*10**decimals);

        }else{
            payable(auction.currentBidOwner).transfer(auction.currentBidPrice);
        }

        auction.isCurrentBidCancelled = true;
    }

    /**
    * Function used by the winner of an auction
    * to withdraw his NFT.
    * When the NFT is withdrawn, the creator of the
    * auction will receive the payment tokens in his wallet
    */

    function claimNFT(uint256 _nftId, address _nftCollection,address _royaltyAddress) payable external {

        // Check if the auction is closed
        require(!checkAndCloseAuction(_nftId, _nftCollection), "Auction is still open");

        // Get auction
        Auction memory auction = nftAuctionData[_nftId][_nftCollection];

        // Check if the caller is the winner of the auction
        // require(
        //     auction.currentBidOwner == _msgSender(),
        //     "NFT can be claimed only by the current bid owner"
        // );
        Math.isEqual(auction.currentBidOwner,_msgSender() );


        IERC721AND1155 nftCollection = IERC721AND1155(auction.addressNFTCollection);     

        // NEED TO call NFT TRANSFER BEFORE THIS FUNCTION CALL

        // Transfer NFT from marketplace contract to the winner address
        nftCollection.safeTransferFrom(address(this),auction.currentBidOwner,auction.nftId);

        if(auction.addressPaymentToken !=address(0)){

            // Get IERC20 Payment token contract
            IERC20 paymentToken = IERC20(auction.addressPaymentToken);
            _royaltyAddress!=address(0)? transferTokenWithRoyalty(auction.creator,paymentToken,auction.currentBidPrice,_royaltyAddress,auction.royaltyFee) :transferToken(auction);

        }else{
            _royaltyAddress!=address(0)? transferEthWithRoyalty(auction.creator, auction.currentBidPrice,_royaltyAddress,auction.royaltyFee) :transferEth(auction.creator, auction.currentBidPrice);
        }
        
        emit NFTClaimed(
            auction.addressNFTCollection,
            auction.nftId,
            auction.creator,
            auction.currentBidOwner,
            auction.currentBidPrice,
            auction.royaltyFee
        );
    }

    /**
    * Function used by the creator of an auction
    * to withdraw his tokens when the auction is closed
    * When the Token are withdrawn, the winned of the
    * auction will receive the NFT in his walled
    */

    function claimToken(uint256 _nftId, address _nftCollection,address _royaltyAddress) payable external {
            // Check if the auction is closed
            require(!checkAndCloseAuction(_nftId, _nftCollection), "Auction is still open");

            // Get auction
            Auction storage auction = nftAuctionData[_nftId][_nftCollection];

            // Check if the caller is the creator of the auction
            // require(
            //     auction.creator == _msgSender(),
            //     "Tokens can be claimed only by the creator of the auction"
            // );
            Math.isEqual(auction.creator,_msgSender() );


            IERC721AND1155 nftCollection = IERC721AND1155(auction.addressNFTCollection);

            // Transfer NFT from marketplace contract
            // to the winned of the auction
            nftCollection.safeTransferFrom(address(this),auction.currentBidOwner,auction.nftId);

            if(address(0) != auction.addressPaymentToken ) {
                // Get IERC20 Payment token contract
                IERC20 paymentToken = IERC20(auction.addressPaymentToken);
                _royaltyAddress!=address(0)? transferTokenWithRoyalty(auction.creator,paymentToken,auction.currentBidPrice,_royaltyAddress,auction.royaltyFee) :transferToken(auction);

            }else{
                _royaltyAddress!=address(0)? transferEthWithRoyalty(auction.creator, auction.currentBidPrice,_royaltyAddress,auction.royaltyFee) :transferEth(auction.creator, auction.currentBidPrice);
            }

            emit TokensClaimed(
                auction.addressNFTCollection,
                auction.nftId,
                auction.creator,
                auction.currentBidOwner,
                auction.currentBidPrice
            );         

    }

    /**
    * Function used by the creator of an auction
    * to get his NFT back in case the auction is closed
    * but there is no bider to make the NFT won't stay locked
    * in the contract
    */

    function withdrawOnBidNFT(uint256 _nftId, address _nftCollection) external {
            // Check if the auction is closed
            require(!checkAndCloseAuction(_nftId, _nftCollection), "Auction is still open");

            // Get auction
            Auction storage auction = nftAuctionData[_nftId][_nftCollection];

            // Check if the caller is the creator of the auction
            // require(auction.creator == _msgSender(),"Tokens can be claimed only by the creator of the auction");
            Math.isEqual(auction.creator,_msgSender());

            // require(auction.currentBidOwner == address(0),"Existing bider for this auction");
            Math.isEqual(auction.currentBidOwner,address(0));

            // Get NFT Collection contract

            IERC721AND1155 nftCollection = IERC721AND1155(auction.addressNFTCollection);

            nftCollection.safeTransferFrom(address(this),auction.creator, auction.nftId);
            
            emit NFTRefunded(auction.addressNFTCollection,auction.nftId, _msgSender());
    }

    function cancelSaleOrAuction(uint256 _nftId, address _nftCollection) payable external {
        
        require(nftSaleData[_nftId][_nftCollection].isOnSale || checkAndCloseAuction(_nftId, _nftCollection), "Sale or Auction should be Opened!");

        if (nftSaleData[_nftId][_nftCollection].isOnSale) {

            // NFTCollection nftCollection = NFTCollection(nftSaleData[_nftId][_nftCollection].addressNFTCollection);
            IERC721AND1155 nftCollection = IERC721AND1155(nftSaleData[_nftId][_nftCollection].addressNFTCollection);
            Sale storage sale = nftSaleData[_nftId][_nftCollection];
            // require(sale.creator == _msgSender(),"Caller is not the owner of the NFT");
            Math.isEqual(sale.creator,_msgSender());
            nftCollection.safeTransferFrom(address(this),_msgSender(),nftSaleData[_nftId][_nftCollection].nftId);
            nftSaleData[_nftId][_nftCollection].isOnSale = false;
        }
        else if(checkAndCloseAuction(_nftId, _nftCollection)){

            Auction storage auction = nftAuctionData[_nftId][_nftCollection];

            // require(auction.creator == _msgSender(),"Caller is not the owner of the NFT");
            Math.isEqual(auction.creator,_msgSender());


            // NFTCollection nftCollection = NFTCollection(nftAuctionData[_nftId][_nftCollection].addressNFTCollection);
            IERC721AND1155 nftCollection = IERC721AND1155(nftAuctionData[_nftId][_nftCollection].addressNFTCollection);
            
            nftCollection.safeTransferFrom(
                address(this),
                _msgSender(),
                nftAuctionData[_nftId][_nftCollection].nftId
            );
            if(nftAuctionData[_nftId][_nftCollection].currentBidPrice >0 && nftAuctionData[_nftId][_nftCollection].currentBidOwner != address(0) ){
                if(nftAuctionData[_nftId][_nftCollection].addressPaymentToken !=address(0)){    
                    IERC20 paymentToken = IERC20(nftAuctionData[_nftId][_nftCollection].addressPaymentToken);
                    uint256 decimals = paymentToken.decimals();
                    paymentToken.transfer(_msgSender(),nftAuctionData[_nftId][_nftCollection].currentBidPrice*10**decimals);
                }else{
                    transferEth(_msgSender(),nftAuctionData[_nftId][_nftCollection].currentBidPrice);
                }
            }
            nftAuctionData[_nftId][_nftCollection].isAuctionOn = false;
        }
    }

    function onERC721Received(
            address,
            address,
            uint256,
            bytes memory
        ) public virtual override returns (bytes4) {
            return this.onERC721Received.selector;
    }

    function tokenTransferCentralize(address _addressNFTCollection,uint _nftId,address _creator,address _userAddress,uint _price ,uint _quantity,IERC20 _tokenAddress,address _royaltyAddress ,uint _royaltyFee) public {

        _royaltyAddress !=address(0)? transferFromWithRoyalty(_creator, _userAddress,_tokenAddress,_quantity,_price,_royaltyAddress,_royaltyFee):transferFromToken(_creator, _userAddress,_tokenAddress,_quantity,_price);

        emit tokenTransferEvent(
            _addressNFTCollection,
            _nftId,
            _creator,
            _userAddress,
            _price*_quantity,
            _quantity
        );
    }    

    function transferFromToken(address _creator,address _userAddress,IERC20 _paymentToken,uint _quantity,uint _price) public {

        IERC20 paymentToken = IERC20(_paymentToken);
        uint256 decimals = paymentToken.decimals();
        _quantity = _quantity>1?_quantity:1;

        (uint _serviceAmount,uint _paymentAmount) = calculationWithoutRoyalty((_quantity*_price)*10**(decimals));

        paymentToken.transferFrom(_userAddress,serviceWallet, _serviceAmount);
        paymentToken.transferFrom(_userAddress,_creator, _paymentAmount);
    
    }

    function transferFromWithRoyalty(address _creator,address _userAddress,IERC20 _paymentToken,uint _quantity,uint _price,address _royaltyAddress,uint256 _royaltyFee) public {

        IERC20 paymentToken = IERC20(_paymentToken);
        uint256 decimals = paymentToken.decimals();

        (uint _serviceAmount,uint _royaltyAmount,uint _paymentAmount) = calculationWithRoyalty((_quantity*_price)*10**(decimals),_royaltyFee);

        paymentToken.transferFrom(_userAddress,serviceWallet, _serviceAmount);
        paymentToken.transferFrom(_userAddress,_creator, _paymentAmount);
        paymentToken.transferFrom(_userAddress,_royaltyAddress,_royaltyAmount);
    }

    function transferToken(Auction memory auction) public {

        require(!checkAndCloseAuction(auction.nftId, auction.addressNFTCollection), "Auction is still open");
        // require(auction.currentBidOwner == _msgSender(),"NFT can be claimed only by the current bid owner");
         Math.isEqual(auction.currentBidOwner,_msgSender());
        IERC20 paymentToken = IERC20(auction.addressPaymentToken);
        // Get IERC20 Payment token contract
        uint256 decimals = paymentToken.decimals();
        // Transfer locked tokens from the market place contract
        // to the wallet of the creator of the auction
        (uint _serviceAmount,uint _paymentAmount) = calculationWithoutRoyalty((auction.currentBidPrice)*10**(decimals));

        paymentToken.transfer(serviceWallet, _serviceAmount);
        paymentToken.transfer(auction.creator, _paymentAmount);

    }

    function transferTokenWithRoyalty(address _creator,IERC20 _paymentToken,uint _price,address _royaltyAddress,uint256 _royaltyFee) public {

        // Get IERC20 Payment token contract
        IERC20 paymentToken = IERC20(_paymentToken);
        uint256 decimals = paymentToken.decimals();
        // Transfer locked tokens from the market place contract
        // to the wallet of the creator of the auction
        (uint _serviceAmount,uint _royaltyAmount,uint _paymentAmount) = calculationWithRoyalty((_price)*10**(decimals),_royaltyFee);

        paymentToken.transfer(serviceWallet, _serviceAmount);
        paymentToken.transfer(_creator, _paymentAmount);
        paymentToken.transfer(_royaltyAddress,_royaltyAmount);

    }

    function transferEth(address _creator,uint _price) payable public  {

        (uint _serviceAmount,uint _paymentAmount) = calculationWithoutRoyalty(_price);
        payable(_creator).transfer(_paymentAmount);
        payable(serviceWallet).transfer(_serviceAmount);

    }


    function transferEthWithRoyalty(address _creator,uint _price,address _royaltyAddress,uint256 _royaltyFee) payable public  {

        (uint _serviceAmount,uint _royaltyAmount,uint _paymentAmount) = calculationWithRoyalty(_price,_royaltyFee);

        payable(_creator).transfer(_paymentAmount);
        payable(serviceWallet).transfer(_serviceAmount);
        payable(_royaltyAddress).transfer(_royaltyAmount);

    }

    function calculationWithRoyalty(uint totalAmount,uint _royaltyFee) public view returns(uint _serviceAmount,uint _royaltyAmount,uint _paymentAmount) {

        _serviceAmount = (totalAmount *serviceFee)/(10**(2+rateDecimals));
        _royaltyAmount = (totalAmount * _royaltyFee)/(10**(2+rateDecimals));
        _paymentAmount = totalAmount - (_serviceAmount+_royaltyAmount);
    }
    
    function calculationWithoutRoyalty(uint _totalAmount) public view returns(uint _serviceAmount,uint _paymentAmount) {
        _serviceAmount = (_totalAmount *serviceFee)/(10**(2+rateDecimals));
        _paymentAmount = _totalAmount - _serviceAmount;      

    }
    
    function setAdmin(address _adminAddress) public onlyOwnerAndAdmin {
        admin = _adminAddress;
    }

    function setRateDecimals(uint8 _decimals) external onlyOwnerAndAdmin {
        rateDecimals = _decimals;
    }

    function setServiceFees(uint _serviceFee) public onlyOwnerAndAdmin {
        serviceFee = _serviceFee;
    }

    // function setRoyaltyFees(uint _Fee) public onlyOwnerAndAdmin {
    //     royaltyFee = _Fee;
    // }

    function setServiceWalletAddress(address _serviceWallet)public onlyOwnerAndAdmin {
        serviceWallet = _serviceWallet;
    }

    function resetPrice(address _addressNFTCollection,address _addressPaymentToken,uint256 _nftId,uint256 _nftPrice) public {

        checkContract.isContract(_addressNFTCollection);
        checkContract.isContract(_addressPaymentToken);
        // require(nftSaleData[_nftId][_addressNFTCollection].creator==_msgSender(),"Caller is not the Owner of NFT.");
        Math.isEqual(nftSaleData[_nftId][_addressNFTCollection].creator,_msgSender());
        nftSaleData[_nftId][_addressNFTCollection].nftPrice = _nftPrice;

    }

    function resetPriceBatch(uint256 index,address _addressNFTCollection,address _addressPaymentToken,uint256 _nftPrice) public {

        checkContract.isContract(_addressNFTCollection);
        checkContract.isContract(_addressPaymentToken);
        // require(nftSaleDataBatch[index].isOnSale,"NFT is not on sale");
        Status.isSaleOff(nftSaleDataBatch[index].isOnSale);
        // require(nftSaleDataBatch[index].creator==_msgSender(),"Caller is not the Owner of NFT.");
        Math.isEqual(nftSaleDataBatch[index].creator,_msgSender());
        nftSaleDataBatch[index].nftPrice = _nftPrice;

    }

    function updateAuction(uint256 _nftId, address _nftCollection,uint256 _nftPrice,uint256 _endAuction) public {
        Auction storage auction = nftAuctionData[_nftId][_nftCollection];
        
        // require(auction.creator==_msgSender(),"Caller is not the Owner of NFT.");
        Math.isEqual(auction.creator,_msgSender());

        auction.currentBidPrice = _nftPrice;
        auction.endAuction = _endAuction;
    }

    function withdrawEth() public onlyOwnerAndAdmin{
        payable(_msgSender()).transfer(address(this).balance);
    } 

    receive() external payable {}

     // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function ethTransferCentralize(address _addressNFTCollection,uint _nftId,address _creator,address _userAddress,uint _price ,uint _quantity,address _royaltyAddress ,uint _royaltyFee) payable public {

        _royaltyAddress !=address(0)? transferEthWithRoyalty(_creator,_price*_quantity,_royaltyAddress,_royaltyFee):transferEth(_creator,_price*_quantity);

        emit tokenTransferEvent(
            _addressNFTCollection,
            _nftId,
            _creator,
            _userAddress,
            _price*_quantity,
            _quantity
        );
    }    

   
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
 
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate that the this implementation remains valid after an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
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
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
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
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
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
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}