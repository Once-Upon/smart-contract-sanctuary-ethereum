// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "P2PLoan.sol";

contract P2PLoanFactory{

    address public owner;
    //address[] public acceptableNFTs=[0xD5D986c7D25473375B84Be3Ae63c6c12261bDfA7];

    mapping (address => LoanFactoryObject) loanFactory;
    //mapping(address => uint256) public acceptableNFTsIndex;
    mapping ( address => bool ) acceptableNFTs;
    event LoanContract(P2PLoan _p2ploan, uint256 index);
    constructor () {
        owner = msg.sender;
    }

    struct LoanFactoryObject{
        address loanee;
        P2PLoan[] p2ploans;
        mapping (P2PLoan => uint256) p2ploanIndexFromCA;
        mapping (uint256 => P2PLoan) p2ploanCAFromIndex;
    }

    function createP2PLoanContract(address _NFTAddress) public {
        require(acceptableNFTs[_NFTAddress] == true, "NFT not supported at the moment.");
        P2PLoan p2ploanContract = new P2PLoan(_NFTAddress);
        loanFactory[msg.sender].loanee = msg.sender;
        loanFactory[msg.sender].p2ploans.push(p2ploanContract);
        loanFactory[msg.sender].p2ploanIndexFromCA[p2ploanContract] = loanFactory[msg.sender].p2ploans.length -1;
        loanFactory[msg.sender].p2ploanCAFromIndex[loanFactory[msg.sender].p2ploans.length-1] = p2ploanContract;
        // p2ploanContract.createLoan(_loanAmountInWEi, _durationOfLoan, _interestInWEI, _tokenID);
        emit LoanContract(p2ploanContract, loanFactory[msg.sender].p2ploanIndexFromCA[p2ploanContract]);
    }

    function LFCreateLoan(uint256 _index, 
    uint256 _loanAmountInWEi, 
    uint256 _durationOfLoan, 
    uint256 _interestInWEI, 
    uint256 _tokenID) public {
        P2PLoan p2pLoan = P2PLoan(address(getContractByIndex(_index)));
        p2pLoan.createLoan(_loanAmountInWEi, _durationOfLoan, _interestInWEI, _tokenID);
    }

    function LFUpdateLoanDetails(uint256 _index, 
    uint256 _updateDurationOfLoan, 
    uint256 _updateInterestInWEI, 
    uint256 _updateLoanAmount) public {
        P2PLoan p2ploan = P2PLoan(address(getContractByIndex(_index)));
        p2ploan.updateLoanDetail(_updateDurationOfLoan, _updateInterestInWEI, _updateLoanAmount);
    }

    function LFCancelLoan(uint _index) public {
        P2PLoan p2pLoan = P2PLoan(address(getContractByIndex(_index)));
        p2pLoan.cancelLoan();
    }

    function LFFundBorrower(uint256 _index) public {
        P2PLoan p2ploan = P2PLoan(address(getContractByIndex(_index)));
        p2ploan.fundBorrower();
    }

    function LFPayLoan(uint256 _index) public {
        P2PLoan p2ploan = P2PLoan(address(getContractByIndex(_index)));
        p2ploan.payLoan();
    }

    function getContractByIndex (uint256 _index) public view returns(address p2ploanContract){
        p2ploanContract = address((loanFactory[msg.sender].p2ploans[_index]));
        return p2ploanContract;
    }

    function getIndexByContract(P2PLoan _contractAddress) public view returns(uint256 p2ploanContractIndex){
        p2ploanContractIndex = loanFactory[msg.sender].p2ploanIndexFromCA[_contractAddress];
        return p2ploanContractIndex;
    }

    function loanList() public view returns(P2PLoan[] memory){
        return loanFactory[msg.sender].p2ploans;
    }

    // function getContractByContract(P2PLoan _contractAddress) public view returns(P2PLoan p2ploanContract) {
    //     uint256 p2ploanContractIndex = loanFactory[msg.sender].p2ploanIndexFromCA[_contractAddress];
    //     p2ploanContract = P2PLoan(address(loanFactory[msg.sender].p2ploans[p2ploanContractIndex]));

    //     return p2ploanContract;
    // }
    
    modifier onlyOwner {
        require(msg.sender ==owner);
        _;
    }

    function updateAcceptableNFTs(address _NFTAddress) public onlyOwner {
        acceptableNFTs[_NFTAddress] = true;
    }

    function removeNFT(address _removeNFT) public returns(address, string memory){
        //uint256 index = acceptableNFTsIndex[_removeNFT];
        delete acceptableNFTs[_removeNFT];

        return(_removeNFT, "Removed");
    }


}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC721.sol";
    //create Loan
    //quit loan if state is not change
    //deposit eth in relation to the amount of loan needed
    //see if the nft can back up the loan
    //deposit multiple NFTs

contract P2PLoan{

    address public borrower;
    address public lender;
    IERC721 public NFTContract;
    address public NFTContractAddress;
    uint256 public start;

    enum State{AWAITING_FUNDING, LOAN_FUNDED, LOAN_CANCLED, LOAN_PAYED, LOAN_EXPIRED}

    event CreatedLoan (uint256 loanAmount, uint256 durationOfLoan, uint256 interest, uint256 tokenID);
    event UpdatedLoan (uint256 updateDurationOfLoan, uint256 updateInterest, uint256 updateLoanAmount);

    State public current_state;

    mapping(address => uint256) public loanAmountDeposited;
    mapping(IERC721 => uint256) public NFTToTokenID; //map nft to tokenID

    struct LoanDetails{
        address borrowerAddress;
        uint256 loanAmount;
        uint256  durationOfLoan;
        uint256 interest;
        uint256 tokenId;
    }

    LoanDetails public loanDetail;

    constructor (address _nftContractAddress){
        borrower = msg.sender;
        current_state = State.AWAITING_FUNDING;
        NFTContract = IERC721(_nftContractAddress);
        NFTContractAddress = _nftContractAddress;
    }

    modifier onlyBorrower{
        require(msg.sender == borrower, "Only borrower can call this function.");
        _;
    }

    function createLoan(uint256 _loanAmountInWEi, uint256 _durationOfLoan, uint256 _interestInWEI, uint256 _tokenID) public onlyBorrower payable{
        require(current_state == State.AWAITING_FUNDING, "Loan already Created");
        NFTContract.transferFrom(msg.sender, address(this), _tokenID);
        NFTToTokenID[NFTContract] = _tokenID;
        loanDetail.borrowerAddress = borrower;
        loanDetail.loanAmount = _loanAmountInWEi;
        loanDetail.durationOfLoan = start + (_durationOfLoan * 1 minutes);
        loanDetail.interest = _interestInWEI;
        loanDetail.tokenId = _tokenID;
        start = block.timestamp;

        emit CreatedLoan(_loanAmountInWEi, _durationOfLoan, _interestInWEI, _tokenID);
    }

    // Update Loan loanDetail
    function updateLoanDetail(uint256 _updateDurationOfLoan, uint256 _updateInterestInWEI, uint256 _updateLoanAmount) public {
        require(current_state == State.AWAITING_FUNDING,"");
        loanDetail.durationOfLoan = start + (_updateDurationOfLoan * 1 minutes);
        loanDetail.loanAmount = _updateLoanAmount;
        loanDetail.interest = _updateInterestInWEI;

        emit UpdatedLoan(_updateDurationOfLoan, _updateInterestInWEI, _updateLoanAmount);
    }


    function cancelLoan() public onlyBorrower{
        //require(current_state == State.AWAITING_FUNDING , "Loan is already Funded");
        if (current_state == State.AWAITING_FUNDING || current_state ==State.LOAN_CANCLED){
            NFTContract.transferFrom(address(this), borrower, NFTToTokenID[NFTContract]);
            current_state = State.LOAN_CANCLED;
        }
    }


    function fundBorrower() public payable {
        require(msg.value == loanDetail.loanAmount, "Value has too be equal to loan Amount");
        require(current_state == State.AWAITING_FUNDING, "Loan already funded");
        lender = msg.sender;
        loanAmountDeposited[msg.sender] = msg.value;
        payable(borrower).transfer(msg.value);

        current_state = State.LOAN_FUNDED;
    }


    function payLoan() public onlyBorrower payable {
        require(current_state == State.LOAN_FUNDED, "Loan is yet to be funded.");
        
        require(msg.value == loanDetail.loanAmount + getInterest(), "Value has too be equal to loanAmount+interest");
        if (block.timestamp >= loanDetail.durationOfLoan) {
            loanExpired();
        }else{
            payable(lender).transfer(msg.value);
        }

        current_state = State.LOAN_PAYED;

        // send money back with interest

    }


    function loanExpired() public {
        require(block.timestamp >= loanDetail.durationOfLoan, "Time Is not over");
        require(current_state == State.LOAN_FUNDED);
        NFTContract.transferFrom(address(this), lender, NFTToTokenID[NFTContract]);
        // send nft to lender when loan expires
    }


    function getInterest() public view returns(uint256 interestToBePaid){
        //require (block.timestamp <= loanDetail.durationOfLoan, )
        if (block.timestamp < loanDetail.durationOfLoan) {
            uint256 timeRemaining = (loanDetail.durationOfLoan - block.timestamp);
            uint256 interestRate = loanDetail.interest;
            // startTime == interestRate
            // timeRemaining == newInterest;
            uint256 loanDuration = loanDetail.durationOfLoan - start;
            uint256 timeRemainingNow = loanDuration - timeRemaining;
            uint256 newInterest = (timeRemainingNow * interestRate)/loanDuration;
            interestToBePaid = (loanDetail.loanAmount * newInterest)/ 1 ether;
            return interestToBePaid;
        }else {
            uint256 newInterest = loanDetail.interest;
            interestToBePaid = (loanDetail.loanAmount * newInterest)/ 1 ether;
            return interestToBePaid;
        }
        // assume that the timestamp is in seconds
        // it's in wei
    }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "IERC165.sol";

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