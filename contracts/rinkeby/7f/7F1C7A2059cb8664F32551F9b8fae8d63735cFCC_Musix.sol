/**
 *Submitted for verification at Etherscan.io on 2022-08-03
*/

// SPDX-License-Identifier: NONE

pragma solidity 0.8.13;



// Part: IERC20

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

// Part: OpenZeppelin/[email protected]/Context

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

// Part: OpenZeppelin/[email protected]/Ownable

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

// File: Musix.sol

contract Musix is Ownable {
    /* WTF does this do?
        A platform where users are incentived to find lit content before they get mass adoption.
        WHY?. i think its pretty cool when you have a chance to earn for finding a cool song from early on
        - A cool way to discover music,
        - Get rewarded for your sweet music taste
        - Promotes underground artist work
    */

    uint256 public  constant MUL = 10 ** 18;

    
    uint256 public proposalCost = 20 * MUL; // 20 rank tokens
    uint256 public upvoteCost = 10 * MUL;   // 10 rank tokens
    address public tokenAddress;
    IERC20 underlying;

    struct Song {
        // Tracks the time when the song was initially submitted
        uint256 submittedTime;
        // Tracks the block when the song was initially submitted (to facilitate calculating a score that decays over time)
        uint256 submittedInBlock;
        // Tracks the number of tokenized votes not yet withdrawn from the song.  We use this to calculate withdrawable amounts.
        uint256 currentUpvotes;
        // Tracks the total number of tokenized votes this song has received.  We use this to rank songs.
        uint256 allTimeUpvotes;
        // Tracks the number of upvoters (!= allTimeUpvotes when upvoteCost != 1)
        uint256 numUpvoters;
        // the proposer
        address proposer;
        // Maps a user's address to their place in the "queue" of users who have upvoted this song.  Used to calculate withdrawable amounts.
        mapping(address => Upvote) upvotes;
    }


    struct Upvote {
        uint index; // 1-based index
        uint withdrawnAmount;
    }

    mapping(string => Song) public songs;

    // This mapping tracks which addresses we've seen before.  If an address has never been seen, and
    // its balance is 0, then it receives a token grant the first time it proposes or upvotes a song.
    // This helps us prevent users from re-upping on tokens every time they hit a 0 balance.
    mapping(address => bool) public receivedTokenGrant;
    // uint public tokenGrantSize = 100 * (10 ** DECIMALS);


    /**** ****** ******* ****** ****** 
                EVENTS
    ****** ******* ****** ****** ****/


    event SongProposed(address indexed proposer, string cid);
    event SongUpvoted(address indexed upvoter, string cid, uint256 amount);
    event Withdrawal(address indexed withdrawer, string cid, uint tokens);
    event UpdateProposalCost(address indexed proposer, uint amount);
    event UpdateUpvoteCost(address indexed proposer, uint amount);
    constructor(address _address) {
        tokenAddress = _address;
        underlying = IERC20(_address);
    }


    /**** ****** ******* ****** ****** 
                INITS
    ****** ******* ****** ****** ****/

    function setProposalCost(uint256 _amount)  public onlyOwner {
        proposalCost = _amount * MUL;
        emit UpdateProposalCost(msg.sender, _amount);

    }

    function setUpvoteCost(uint256 _amount)  public onlyOwner {
        upvoteCost = _amount * MUL;
        emit UpdateUpvoteCost(msg.sender, _amount);

    }
    
    /**** ****** ******* ****** ****** 
              PROPOSE &  UPVOTE LOGIC SER
    ****** ******* ****** ****** ****/



    function propose(string calldata cid, uint256 _amount) payable public {
        require(songs[cid].numUpvoters == 0, "already proposed");
        require(underlying.balanceOf(msg.sender) >= _amount, "sorry bro, not enough tokens to propose");
        

        underlying.transferFrom(msg.sender, address(this), _amount);
        
        Song storage song = songs[cid];
        song.submittedInBlock = block.number;
        song.submittedTime = block.timestamp;
        song.currentUpvotes += proposalCost;
        song.allTimeUpvotes += proposalCost;
        song.numUpvoters++;
        song.upvotes[msg.sender].index = song.numUpvoters;
        song.proposer = msg.sender;

        emit SongProposed(msg.sender, cid);


    }

        function upvote(string calldata cid, uint256 amount) external payable {
        // require(msg.value >= upvoteCost, "Musix: Not enough tokens to upvote");
        require(underlying.balanceOf(msg.sender) >= upvoteCost, "Musix: Not enough tokens to upvote");

        Song storage song = songs[cid];
        // uint256 amount = msg.value;
        underlying.transferFrom(msg.sender, address(this), amount);

        require(song.upvotes[msg.sender].index == 0, "Musix: you have already upvoted this song");

        song.currentUpvotes += amount;
        song.allTimeUpvotes += amount;
        song.numUpvoters++;
        song.upvotes[msg.sender].index = song.numUpvoters;

        emit SongUpvoted(msg.sender, cid, msg.value);
    }




    






 }