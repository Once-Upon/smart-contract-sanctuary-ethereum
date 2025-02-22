/**
 *Submitted for verification at Etherscan.io on 2022-08-20
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/*
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

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

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
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
}

interface IJetNft is IERC721{

     /// @notice Returns all the relevant information about a specific jet.
    /// @param _id The ID of the jet of interest.
    function getJet(uint256 _id)
        external
        view
        returns (
        bool isProcessing,
        bool isReady,
        uint256 recoveryIndex,
        uint256 nextActionAt,
        uint256 ProcessingWithId,
        uint256 buildTime,
        uint256 inventorModelId,
        uint256 architectModelId,
        uint256 generation
    ) ;
}

contract OsizJetRace is Ownable {

    enum RaceStatus { Begun, Ended, Canceled }

    // All the needed info about race
    struct Race {
        uint256 cost;               // Cost per member. 0 means free race.
        uint256 totalAmount;        // Total amount.
        uint256[12] contestant;     // Total Participants.
        uint32[12] winners;         // Winning jetIds.
        uint8 count;                // Total participants count
        RaceStatus status;                // Race status 
        uint256 level;              // 4.Cadet (initial level) 3.Engineer(0-40)
                                      // 2.Astronaut(40-60) 1.Elonet (60 above) 
    }

    // All the needed info about jet
    struct jet {
        uint256 rating;
        uint256 raceID; 
    }

    mapping(uint256 => Race) public raceInfo;
    // JetId => rating and raceID
    mapping(uint256 => jet) public jetInfo;
    // raceId => winnerof race
    mapping(uint256 => mapping(uint256 => bool)) public winnerInfo;

    // Instance of token
    IJetNft public nftToken;
    // Total race counter
    uint256 public totalRace;
    // Winning percentages
    uint32[3] public pcent = [60, 25, 15];

    // The gasFee amount receiving address
    address public organizer;
    uint32 public fee = 10; // 10%
    uint256 public points = 2; // negative points
    // responsible for announcing result
    address public operator;

    // Event details
    event NewRace(uint256 raceId, uint256 levelType, uint256 totalRaceAmount);
    event EnterRace(
        uint256 raceID,
        uint256 tokenId,
        uint256 index,
        address caller
    );
    event RaceResult(uint256 raceId, uint256 timestamp, uint32[3] winnerIndex);
    event SetOrganizer(address _newOrganizer);
    event SetOperator(address _addr);
    event SetPoints(uint256 newPoints);
    event CancelRace(uint256 _raceId);
    event ReFunded(uint256 raceId, uint256 jetId, uint256 amount, address receiver);

    constructor(
        IJetNft _nftToken,
        address _organizer,
        address _operator
    ) {
        nftToken = _nftToken;
        organizer = _organizer;
        operator = _operator;
        emit SetOperator(_operator);
        emit SetOrganizer(_organizer);
    }

    modifier isRaceExist(uint256 _raceId) {
        require((_raceId > 0) && (_raceId <= totalRace), "Race is not exist");
        require(
            (raceInfo[_raceId].count < 12),
            "Invalid time"
        );

        require(
           raceInfo[_raceId].status ==  RaceStatus.Begun, "Race must be started"
        );
        _;
    }

    modifier isJetEligible(uint256 _tokenId) {
        require(nftToken.ownerOf(_tokenId) == msg.sender, "Invalid Jet owner");
        require(
            (jetInfo[_tokenId].raceID == 0) ||
                (raceInfo[jetInfo[_tokenId].raceID].status == RaceStatus.Ended
                    || raceInfo[jetInfo[_tokenId].raceID].status == RaceStatus.Canceled
                ),
            "Already participated"
        );
        _;
    }

    modifier isOwnerOrOperator(){
        require( (owner() == msg.sender) || (operator == msg.sender) , "owner or operator");
        _;
    }

    function updateNFTtoken(address _nftToken) external onlyOwner {
        nftToken = IJetNft(_nftToken);
    }

    function createNewRace(
        uint256 _cost,
        uint256 _level
    ) external isOwnerOrOperator {
        require(
            (_cost > 0),
            "Invalid amount or time"
        );
        require((_level <= 4), "Invalid level");

        totalRace++;
        uint256 raceId = totalRace;
        raceInfo[raceId].cost = _cost;
        raceInfo[raceId].totalAmount = _cost * 12;
        raceInfo[raceId].level = _level;
        raceInfo[raceId].status = RaceStatus.Begun;

        emit NewRace(raceId, _level, _cost * 12);
    }

    function enterRace(
        uint256 _raceId,
        uint256 _index,
        uint256 _tokenId
    ) external payable isRaceExist(_raceId) isJetEligible(_tokenId) {
        require(isEligible(_tokenId, raceInfo[_raceId].level), "Not eligible");
        require(
            (_index < 12) && (raceInfo[_raceId].contestant[_index] == 0),
            "Invalid index"
        );

        require(raceInfo[_raceId].cost <= msg.value,"Invalid cost");

        raceInfo[_raceId].contestant[_index] = _tokenId;
        jetInfo[_tokenId].raceID = _raceId;
        raceInfo[_raceId].count++;

        emit EnterRace(_raceId, _tokenId, _index, msg.sender);
    }

    function isEligible(uint _tokenId, uint _level) internal view returns(bool){

        if(_level == 0){
            return true;
        } else if(_level == 1){
            if(jetInfo[_tokenId].rating > 60){return true;} else {return false;}
        }else if(_level == 2){
            if( (jetInfo[_tokenId].rating > 40) && (jetInfo[_tokenId].rating <= 60) ){return true;} else {return false;}
        }else if(_level == 3){
            if((jetInfo[_tokenId].rating > 0) && (jetInfo[_tokenId].rating <= 40)){return true;} else {return false;}
        }else if(_level == 4){
            if(jetInfo[_tokenId].rating == 0 ){return true;} else {return false;}
        } else { return false;}
    }

    function announceRaceResult(uint256 _raceId, uint32[12] calldata result) external isOwnerOrOperator {
        require(
            (raceInfo[_raceId].count == 12),
            "Race not yet Finished"
        );
        require(raceInfo[_raceId].status ==  RaceStatus.Begun, "Race must be started");
        require(raceInfo[_raceId].count == 12, "Race not filled yet");
        
        raceInfo[_raceId].winners = result;
        uint256 totalAmount = raceInfo[_raceId].totalAmount;
        uint32[3] memory _pcent = pcent;

        if(fee > 0){
            require(payable(organizer).send((totalAmount * fee) / 100),"Organizer transaction failed");
            totalAmount = totalAmount - ((totalAmount * fee) / 100);
        }

        require(payable(nftToken.ownerOf(result[0])).send((totalAmount * _pcent[0]) / 100),"Organizer transaction failed");
        require(payable(nftToken.ownerOf(result[1])).send((totalAmount * _pcent[1]) / 100),"Organizer transaction failed");
        require(payable(nftToken.ownerOf(result[2])).send((totalAmount * _pcent[2]) / 100),"Organizer transaction failed");

        setRating(_raceId);
        raceInfo[_raceId].status = RaceStatus.Ended;


        emit RaceResult(_raceId, block.timestamp, [result[0],result[1],result[2]]);
    }

    function setRating(uint256 _raceId) internal {
        if (raceInfo[_raceId].level == 4) {
            initialLevel(_raceId);
        } else {
            updateRating(_raceId);
        }
    }

    function initialLevel(uint256 _raceId) internal {
        uint256 tokenId;
        for (uint256 i = 0; i < 12; i++) {
            tokenId = raceInfo[_raceId].contestant[i];
            jetInfo[tokenId].rating = genRating(tokenId);
        }
        updateRating(_raceId);
    }

    function updateRating(uint256 _raceId) internal {
        uint32[12] memory result = raceInfo[_raceId].winners;

        jetInfo[result[0]].rating = jetInfo[result[0]].rating + 6;
        jetInfo[result[1]].rating = jetInfo[result[1]].rating + 4;
        jetInfo[result[2]].rating = jetInfo[result[2]].rating + 2;

        for(uint i=6; i<12; i++){
            if(jetInfo[result[i]].rating < points){
                jetInfo[result[i]].rating = 0;
            }else {
                jetInfo[result[i]].rating = jetInfo[result[i]].rating - points;
            }
        }
    }

    function genRating(uint256 tokenId) internal view returns (uint256) {
        if (getGen(tokenId) <= 4) {
            return 27;
        } else if (getGen(tokenId) <= 9) {
            return 17;
        } else {
            return 7;
        }
    }

    function getGen(uint _tokenId) internal view returns (uint generation) {
        (,,,,,,,,generation) = nftToken.getJet(_tokenId); 
    }

    function raceDetaild(uint256 raceId) external view returns (Race memory) {
        return raceInfo[raceId];
    }

    function setOrganizer(address _addr) external onlyOwner{
        organizer = _addr;
        emit SetOrganizer(_addr);
    }

    function setOperator(address _addr) external onlyOwner{
        operator = _addr;
        emit SetOperator(_addr);
    }

    function setPoints(uint256 _points) external onlyOwner{
        points = _points;
        emit SetPoints(_points);
    }

    function cancelRace(uint256 _raceId) external isOwnerOrOperator isRaceExist(_raceId){
        Race storage race = raceInfo[_raceId];
        race.status = RaceStatus.Canceled;
        for(uint8 i = 0; i < 12; i++){
            if(race.contestant[i] != 0){
                uint jetID = race.contestant[i];
                address nftOwner = nftToken.ownerOf(jetID);
                race.contestant[i] = 0;
                require(payable(nftOwner).send(race.cost),"Organizer transaction failed");
            }
        }
        emit CancelRace(_raceId);
    }

    function getReFund(uint256 _raceId, uint256 _participationIndex, uint256 _jetId) external {
        require(
           raceInfo[_raceId].status ==  RaceStatus.Canceled, "Race not closed"
        );

        require( raceInfo[_raceId].contestant[_participationIndex] == _jetId, "Not participated");

        require(nftToken.ownerOf(_jetId) == msg.sender, "Invalid Jet owner");
        raceInfo[_raceId].contestant[_participationIndex] = 0;
        require(payable(msg.sender).send(raceInfo[_raceId].cost),"transaction failed");

        emit ReFunded(_raceId, _jetId, raceInfo[_raceId].cost ,msg.sender);
    }

    function recover(address _token, address _receiver, uint256 _amount) external onlyOwner {
        if(_token == address(0x0)){
            require(payable(_receiver).send(_amount),"Organizer transaction failed");
        }else {
            IERC20(_token).transfer(_receiver, _amount);
        }
    }
}