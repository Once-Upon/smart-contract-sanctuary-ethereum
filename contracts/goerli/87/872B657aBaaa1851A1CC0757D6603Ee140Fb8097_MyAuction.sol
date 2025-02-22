/**
 *Submitted for verification at Etherscan.io on 2023-02-17
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Auction {
    
address internal auction_owner;
uint256 public auction_start;
uint256 public auction_end;
uint256 public highestBid;
address public highestBidder;
 

enum auction_state{
    CANCELLED,STARTED
}

struct car {
    string  Brand;
    string  Rnumber;
}
    car public Mycar;
    address[] bidders;

    mapping(address => uint) public bids;

    auction_state public STATE;


    modifier an_ongoing_auction(){
        require(block.timestamp <= auction_end);
        _;
    }
    
    modifier only_owner(){
        require(msg.sender==auction_owner);
        _;
    }
    
    function bid(uint256 _bid) public payable virtual returns (bool){}
    function withdraw() public virtual returns (bool){}
    function cancel_auction() external virtual returns (bool){}
    
    event BidEvent(address indexed highestBidder, uint256 highestBid);
    event WithdrawalEvent(address withdrawer, uint256 amount);
    event CanceledEvent(string message, uint256 time);  
    
}


contract MyAuction is Auction {
  
constructor (uint _biddingTime, address _owner,string memory _brand,string memory _Rnumber) {
        auction_owner = _owner;
        auction_start= block.timestamp;
        auction_end = auction_start + _biddingTime*1  hours;
        STATE=auction_state.STARTED;
        Mycar.Brand=_brand;
        Mycar.Rnumber=_Rnumber;
        
    }
 

 function bid(uint256 _bid) public override payable an_ongoing_auction returns (bool){
      
        require(bids[msg.sender]+ _bid> highestBid,"You can't bid, Make a higher Bid");
        highestBidder = msg.sender;
        highestBid = _bid;
        bidders.push(msg.sender);
        bids[msg.sender]=  bids[msg.sender] + _bid;
        emit BidEvent(highestBidder,  highestBid);

        return true;
    }
    
 
  
function cancel_auction() external override only_owner  an_ongoing_auction returns (bool){
    
        STATE=auction_state.CANCELLED;
        emit CanceledEvent("Auction Cancelled", block.timestamp);
        return true;
     }
    
    
    
function destruct_auction() external only_owner returns (bool){
        
    require(block.timestamp > auction_end,"You can't destruct the contract,The auction is still open");
     for(uint i=0;i<bidders.length;i++)
    {
        assert(bids[bidders[i]]==0);
    }

    selfdestruct(payable(auction_owner));
    return true;
    
    }

    
function withdraw() public override returns (bool){
        require(block.timestamp > auction_end ,"You can't withdraw, the auction is still open");
        uint amount;

        amount=bids[msg.sender];
        bids[msg.sender]=0;
        payable(msg.sender).transfer(amount);
        emit WithdrawalEvent(msg.sender, amount);
        return true;
      
    }
    
function get_owner() public view returns(address){
        return auction_owner;
    }
}