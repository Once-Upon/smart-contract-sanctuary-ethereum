/**
 *Submitted for verification at Etherscan.io on 2022-09-18
*/

// File: contracts/IMoldNFT.sol

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IMoldNFT {
    function molds(uint256)
        external
        view
        returns (
            uint256,
            string memory,
            string memory
        );

    function totalMolds() external view returns (uint256);

    function ownerOf(uint256) external view returns (address);

    function transfer(uint256, address) external;
}

// File: @openzeppelin/contracts/utils/Context.sol



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

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/AuctionSea.sol

pragma solidity ^0.8.0;
contract AuctionSea is Ownable {
    struct Auction {
        uint256 highestBid;
        uint256 closingTime;
        address highestBidder;
        address originalOwner;
        bool isActive;
    }

    // NFT id => Auction data
    mapping(uint256 => Auction) public auctions;

    // MoldNFT contract interface
    IMoldNFT private sNft_;
    address public multiSigAddress;

    // ETH balance
    uint256 public balances;
    uint256 public gasPrice;

    event NewAuctionOpened(
        uint256 nftId,
        uint256 startingBid,
        uint256 closingTime,
        address originalOwner
    );

    event AuctionClosed(
        uint256 nftId,
        uint256 highestBid,
        address highestBidder
    );

    event BidPlaced(uint256 nftId, uint256 bidPrice, address bidder);

    modifier onlyMultiSig() {
        require(multiSigAddress == msg.sender, "not owner");
        _;
    }

    receive() external payable {
        balances += msg.value;
    }

    /**
     * @dev Receive ETH. msg.data is not empty
     */
    fallback() external payable {
        balances += msg.value;
    }

    function initialize(address _sNft) external onlyOwner {
        require(_sNft != address(0), "Invalid address");

        sNft_ = IMoldNFT(_sNft);

        balances = 0;
        gasPrice = 2500;
    }

    function setGasPrice(uint256 _gasPrice) external onlyOwner {
        gasPrice = _gasPrice;
    }

    function setMultiSigAddress(address _multiSig) external onlyOwner {
        multiSigAddress = _multiSig;
    }

    function openAuction(
        uint256 _nftId,
        uint256 _sBid,
        uint256 _duration
    ) external {
        require(auctions[_nftId].isActive == false, "Ongoing auction detected");
        require(_duration > 0 && _sBid > 0, "Invalid input");
        require(sNft_.ownerOf(_nftId) == msg.sender, "Not NFT owner");

        // NFT Transfer to contract
        sNft_.transfer(_nftId, address(this));

        // Opening new auction
        auctions[_nftId].highestBid = _sBid;
        auctions[_nftId].closingTime = block.timestamp + _duration;
        auctions[_nftId].highestBidder = msg.sender;
        auctions[_nftId].originalOwner = msg.sender;
        auctions[_nftId].isActive = true;

        emit NewAuctionOpened(
            _nftId,
            auctions[_nftId].highestBid,
            auctions[_nftId].closingTime,
            auctions[_nftId].highestBidder
        );
    }

    /**
     * @dev Place Bid
     * @param _nftId NFT id
     */
    function placeBid(uint256 _nftId) external payable onlyMultiSig {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(
            auctions[_nftId].closingTime > block.timestamp,
            "Auction is closed"
        );
        require(msg.value > auctions[_nftId].highestBid, "Bid is too low");

        if (auctions[_nftId].originalOwner != auctions[_nftId].highestBidder) {
            // Transfer ETH to Previous Highest Bidder
            (bool sent, ) = payable(auctions[_nftId].highestBidder).call{
                value: auctions[_nftId].highestBid
            }("");

            require(sent, "Transfer ETH failed");
        }

        auctions[_nftId].highestBid = msg.value;
        auctions[_nftId].highestBidder = msg.sender;

        emit BidPlaced(
            _nftId,
            auctions[_nftId].highestBid,
            auctions[_nftId].highestBidder
        );
    }

    /**
     * @dev Close Auction
     * @param _nftId NFT id
     */
    function closeAuction(uint256 _nftId) external {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(
            auctions[_nftId].closingTime <= block.timestamp,
            "Auction is not closed"
        );

        // Transfer ETH to NFT Owner
        if (auctions[_nftId].originalOwner != auctions[_nftId].highestBidder) {
            (bool sent, ) = payable(auctions[_nftId].originalOwner).call{
                value: auctions[_nftId].highestBid
            }("");

            require(sent, "Transfer ETH failed");
        }

        // Transfer NFT to Highest Bidder
        sNft_.transfer(_nftId, auctions[_nftId].highestBidder);

        // Close Auction
        auctions[_nftId].isActive = false;

        emit AuctionClosed(
            _nftId,
            auctions[_nftId].highestBid,
            auctions[_nftId].highestBidder
        );
    }

    function withdraw(address _target, uint256 _amount) external onlyOwner {
        require(_target != address(0), "Invalid address");
        require(_amount > 0 && _amount < balances, "Invalid amount");

        payable(_target).transfer(_amount);

        balances = balances - _amount;
    }
}