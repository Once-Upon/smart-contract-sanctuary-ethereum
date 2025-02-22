/**
 *Submitted for verification at Etherscan.io on 2023-06-08
*/

pragma solidity 0.8.18;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}


contract XCMGRefund {
    mapping(uint256 => address) public tokenIdAddrMap;
    mapping(uint256 => bool) public isRefund;
    uint256 public tokenRefundPrice = 15 * 10**17;
    
    IERC721 public nftContract;
    address public nftReceiver;
    address private owner;
    
    uint256 public refundStartTime = 1686549600;
    uint256 public refundEndTime = 1686621600;

    constructor(
        address _nftContract,
        address _nftReceiver
    ) {
        nftContract = IERC721(_nftContract);
        nftReceiver = _nftReceiver;
        owner = msg.sender;

        tokenIdAddrMap[2821] = 0x337b29C2fa24820dDb85784AfaDC83a6660Ab3CE;
        tokenIdAddrMap[2822] = 0xfad51A8D2a2DCA20ff53C6F26a91E102446f478b;
        tokenIdAddrMap[2823] = 0x31E47Cee4F85b5d4DB4c9A86D9eA4934c698ec4E;
        tokenIdAddrMap[2824] = 0x636fc58699d4C42c63397D3532257AB6d421660f;
    }

    modifier isOwner() {
        require(msg.sender == owner,"NOT OWNER");
        _;
    }

    fallback() external payable {}
    receive() external payable {}

    function setTime(uint256 start, uint256 end) external isOwner{
        require(end > start, "TIME INVALID");

        refundStartTime = start;
        refundEndTime = end;
    }

    function setTokenIdMap(uint256[] memory tokenIds, address[] memory addrs) external isOwner{
        require(tokenIds.length == addrs.length,"PARAM INVALID");
        for(uint256 i = 0; i<tokenIds.length;i++) {
            tokenIdAddrMap[tokenIds[i]] = addrs[i];
        }
    }

    function setPriceAndNftReceiver(uint256 _price, address _receiver) external isOwner {
        tokenRefundPrice = _price;
        nftReceiver = _receiver;
    }

    function withLeftOverFund() external isOwner {
        uint256 currentBalance = address(this).balance;
        require(currentBalance > 0, "Current balance is zero");
        payable(owner).transfer(currentBalance);
    }

    function refund(uint256 tokenId) public {
        require(nftContract.ownerOf(tokenId) == msg.sender, "TokenId Not Belong to you");
        require(msg.sender == tokenIdAddrMap[tokenId], "Address corresponding to tokenId is incorrect");
        require(isRefund[tokenId] == false, "TokenId Already Refunded");
        
        nftContract.safeTransferFrom(msg.sender, nftReceiver, tokenId);

        isRefund[tokenId] = true;
        
        require(address(this).balance >= tokenRefundPrice, "Insufficient contract balance");
        payable(msg.sender).transfer(tokenRefundPrice);
    }

    function batchRefund(uint256[] memory tokenIds) external {
        for(uint256 i = 0; i<tokenIds.length; i++) {
            refund(tokenIds[i]);
        }
    }
}