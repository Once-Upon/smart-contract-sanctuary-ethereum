// SPDX-License-Identifier: MIT

pragma solidity >=0.8.3;

import "./IApolloToken.sol";
import "./third-party/UniswapV2Library.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/// @title The DAO contract for the Apollo Inu token
contract ApolloDAO is Context {

    /// @notice The address & interface of the apollo token contract
    IApolloToken public immutable apolloToken;
    /// @notice The address of the wETH contract. Used to determine minimum balances.
    address public immutable wethAddress;
    /// @notice The addres of the USDC contract. Used to determine minimum balances.
    address public immutable usdcAddress;
    /// @notice Address of the Uniswap v2 factory used to create the pairs
    address public immutable uniswapFactory;

    /// @notice Event that is emitted when a new DAO is nominated
    event NewDAONomination(address indexed newDAO, address indexed nominator);
    /// @notice Event that is emitted when a new vote is submitted
    event VoteSubmitted(address indexed newDAO, address indexed voter, uint256 voteAmount, bool voteFor);
    /// @notice Event that is emitted when a vote is withdrawn
    event VoteWithdrawn(address indexed newDAO, address indexed voter);
    /// @notice Event that is emitted when voting is closed for a nominated DAO
    event VotingClosed(address indexed newDAO, bool approved);
    /// @notice Event that is emitted when a cycle has ended and a winner selected
    event CycleWinnerSelected(address winner, uint256 reward, string summary);
    /// @notice Event that is emitted when a creator has been nominated for the current cycle
    event CreatorNominated(address nominee, uint256 currentCycle);

    /// @notice A record of the current state of a DAO nomination
    struct DAONomination {
        /// The timestamp (i.e. `block.timestamp`) that the nomination was created
        uint256 timeOfNomination;
        /// The account that made the nomination
        address nominator;
        /// The total amount of votes in favor of the nomination
        uint256 votesFor;
        /// The total amount of votes against the nomination
        uint256 votesAgainst;
        /// Whether voting has closed for this nomination
        bool votingClosed;
    }

    /// @notice A description of a single vote record by a particular account for a nomination
    struct DAOVotes {
        /// The count of tokens committed to this vote
        uint256 voteCount;
        /// Whether an account voted in favor of the nomination
        bool votedFor;
    }

    struct Vote {
        uint256 voteBalance;
        uint256 voteCycle;
        bool withdrawn;
    }

    struct LeadCandidate {
        address candidate;
        uint256 voteCount;
        uint256 voteCycle;
    }

    struct VoteData{
        address nomination;
        address voter;
        uint256 apolloBalance; 
        uint256 voteCycle;
    }

    /// @dev A mapping of the contract address of a nomination to the nomination state
    mapping (address => DAONomination) private _newDAONominations;
    /// @dev A mapping of the vote record by an account for a nominated DAO
    mapping (address => mapping (address => DAOVotes)) private _lockedVotes;
    /// @dev A mapping of whether an account has voted in a particular cycle
    /// @dev account address -> cycle ID -> whether they have voted
    mapping (address => mapping (uint256 => bool)) private _hasVoted;

    /// @notice The minimum voting duration for a particular nomination (three days).
    uint256 public constant daoVotingDuration = 300;
    /// @notice The minimum amount of Apollo an account must hold to submit a new nomination
    uint256 public constant minimumDAOBalance = 20000000000 * 10**9;
    /// @notice The total amount of votes—and thus Apollo tokens—that are currently held by this DAO
    uint256 public totalLockedVotes;
    /// @notice The total number of DAO nominations that are open for voting
    uint256 public activeDAONominations;

    /// @notice The address of the new approved DAO that will be eligible to replace this DAO
    address public approvedNewDAO = address(0);
    /// @notice The address of the privileged owner that can decide contests
    address public immutable owner;
    /// @notice The minimum amount of time after a new DAO is approved before it can be activated as the
    /// next effective DAO (two days).
    uint256 public constant daoUpdateDelay = 300;
    /// @notice The timestamp when the new DAO was approved
    uint256 public daoApprovedTime;
    /// @notice Boolean to track when to stop contests
    bool public continueContests = true;
    /// @notice The IPFS summary of every cycle
    mapping(uint256 => string) public votingSummary;

    /// @notice The total duration in seconds of one voting cycle
    uint256 public constant votingCyleLength = 600;
    /// @notice The timestamp when the current voting cycle ends
    uint256 public currentVotingCycleEnd;

    mapping(uint256 => VoteData[]) public votingData;
    mapping (address => Vote[]) private _votesCast;
    mapping (address => mapping (uint256 => uint256)) private _votesReceived;
    mapping(address => uint256) private _nominations;
    mapping (uint256 => uint256) private _voteBalanceOfACycle;
    
    LeadCandidate public leadVoteRecipient;
    uint256 public constant minBalancePercentage = 1;
    /// @notice The amount of Apollo each vote is worth (5M Apollo)
    uint256 public constant voteAwardMultiplier = 5000000 * 10**9;
    /// @notice The % of the winnings to be burned. (1%)
    uint256 public constant awardBurnPercentage = 1;
    /// @notice The % of the DAO pool to be given to the DAO Administrator. (.5%)
    uint256 public constant daoAdministratorPercentage = 5;
    /// @notice The wallet used to fund the Apollo DAO development
    address public immutable daoAdministrator;
    /// @notice The minimum value of Apollo in USDC required to vote
    uint256 public constant minimumUSDValueToVote = 100 * 10**6;
    /// @notice The minimum value of Apollo in USDC required to nominate
    uint256 public constant minimumUSDValueToNominate = 100 * 10**6;

    constructor(address tokenAddress, address _wethAddress, address _usdcAddress, address administrator) {
        apolloToken = IApolloToken(tokenAddress);
        wethAddress = _wethAddress;
        usdcAddress = _usdcAddress;
        uniswapFactory = apolloToken.uniswapRouter().factory();
        daoAdministrator = administrator;
        owner = msg.sender;
        completeCycle(msg.sender, 0, "First");
    }

    // Modifiers

    modifier onlyOwner(){
        require(_msgSender()==owner,"Only owner can call this function");
        _;
    }

    // Public functions

    /// @notice The minimum amount of Apollo an account must hold to submit a vote
    function minimumVoteBalance() public view returns (uint256) {
        return _apolloAmountFromUSD(minimumUSDValueToVote);
    }

    /// @notice The minimum amount of Apollo an account must hold to submit a nomination
    function minimumNominationBalance() public view returns (uint256) {
        return _apolloAmountFromUSD(minimumUSDValueToNominate);
    }

    /// @notice Submit a nomination for the caller
    function nominate() external {
        require(apolloToken.balanceOf(_msgSender()) > minimumNominationBalance(), "Candidate does not hold enough Apollo");
        require(_nominations[_msgSender()] != currentVotingCycleEnd, "Candidate has already been nominated this cycle");
        emit CreatorNominated(_msgSender(), currentVotingCycleEnd);
        _nominations[_msgSender()] = currentVotingCycleEnd;
    }

    function vote(address candidate) external {
        require(block.timestamp < currentVotingCycleEnd, "A new cycle has not started yet");
        require(apolloToken.balanceOf(_msgSender()) > minimumVoteBalance(), "Candidate does not hold enough Apollo");
        require(_nominations[candidate] == currentVotingCycleEnd, "Candidate has not nominated themselves");

        if (_votesCast[_msgSender()].length > 0) {
            require(_votesCast[_msgSender()][_votesCast[_msgSender()].length - 1].voteCycle != currentVotingCycleEnd, "User has already voted");
        }

        uint256 voterBalance = apolloToken.balanceOf(_msgSender());
        require(voterBalance > 0, "Voter does not hold any apollo");

        _votesCast[_msgSender()].push(Vote(voterBalance, currentVotingCycleEnd, false));

        _voteBalanceOfACycle[currentVotingCycleEnd] += voterBalance;

        _votesReceived[candidate][currentVotingCycleEnd] += 1;
        _hasVoted[_msgSender()][currentVotingCycleEnd] = true;
        votingData[currentVotingCycleEnd].push(VoteData(candidate, _msgSender(), apolloToken.balanceOf(_msgSender()), currentVotingCycleEnd));
    }

    function completeCycle(address _candidate,uint256 _voteCount, string memory voteSummary) public  onlyOwner{
        require(block.timestamp > currentVotingCycleEnd, "Voting Cycle has not ended");
        require(continueContests, "Cannot complete new cycles after a new DAO is approved");
        leadVoteRecipient.candidate = _candidate;
        leadVoteRecipient.voteCount = _voteCount;
        leadVoteRecipient.voteCycle = currentVotingCycleEnd;

        uint256 minContractBalance = apolloToken.balanceOf(address(this)) * minBalancePercentage / 100;
        uint256 votesToAward = leadVoteRecipient.voteCount * voteAwardMultiplier;
        votingSummary[currentVotingCycleEnd] = voteSummary;

        uint256 winnings;

        if (minContractBalance < votesToAward) {
            winnings = minContractBalance;
        } else {
            winnings = votesToAward;
        }

        uint256 burnAmount = winnings * awardBurnPercentage / 100;
        uint256 daoOwnerTake = apolloToken.balanceOf(address(this)) * daoAdministratorPercentage / 1000;

        if (winnings > 0) {
            emit CycleWinnerSelected(leadVoteRecipient.candidate, winnings, voteSummary);

            apolloToken.transfer(_candidate, winnings - burnAmount);
            apolloToken.transfer(daoAdministrator, daoOwnerTake);
            apolloToken.burn(burnAmount);
        }
         

        if (approvedNewDAO == address(0)) {
            currentVotingCycleEnd = block.timestamp + votingCyleLength;
        } else {
            continueContests = false;
        }
    }

    /// @notice Cast a vote for an active nominated DAO
    /// @param voteAmount The amount of Apollo to commit to your vote
    /// @param newDAO The address of the nominated DAO to cast a vote for
    /// @param voteFor Whether you want to vote in favor of the nomination
    function voteForDAONomination(uint256 voteAmount, address newDAO, bool voteFor) external {
        require(_newDAONominations[newDAO].timeOfNomination > 0 , "There is no DAO Nomination for this address");
        require(_lockedVotes[_msgSender()][newDAO].voteCount == 0, "User already voted on this nomination");
        require(approvedNewDAO == address(0), "There is already an approved new DAO");
        apolloToken.transferFrom(_msgSender(), address(this), voteAmount);
        totalLockedVotes += voteAmount;
        _lockedVotes[_msgSender()][newDAO].voteCount += voteAmount;
        _lockedVotes[_msgSender()][newDAO].votedFor = voteFor;
        if(voteFor){
            _newDAONominations[newDAO].votesFor += voteAmount;
        } else {
            _newDAONominations[newDAO].votesAgainst += voteAmount;
        }
        emit VoteSubmitted(newDAO, _msgSender(), voteAmount, voteFor);
    }

    /// @notice Withdraw votes you have previously cast for a nomination. This can be called regardless of
    /// whether a nomination is active. If still active, your votes will no longer count in the final tally.
    /// @param newDAO The address of the nomination to withdraw your votes from
    function withdrawNewDAOVotes(address newDAO) external {
        uint256 currentVoteCount = _lockedVotes[_msgSender()][newDAO].voteCount;
        require(currentVoteCount > 0 , "You have not cast votes for this nomination");
        require((totalLockedVotes - currentVoteCount) >= 0, "Withdrawing would take DAO balance below expected rewards amount");

        apolloToken.transfer(_msgSender(), currentVoteCount);

        totalLockedVotes -= currentVoteCount;
        _lockedVotes[_msgSender()][newDAO].voteCount -= currentVoteCount;

        if(_lockedVotes[_msgSender()][newDAO].votedFor){
            _newDAONominations[newDAO].votesFor -= currentVoteCount;
        } else {
            _newDAONominations[newDAO].votesAgainst -= currentVoteCount;
        }
        emit VoteWithdrawn(newDAO, _msgSender());
    }

    /// @notice Submit a nomination for a new DAO contract
    /// @param newDAO The address of the new DAO contract you wish to nominate
    function nominateNewDAO(address newDAO) external {
        require(apolloToken.balanceOf(_msgSender()) >= minimumDAOBalance , "Nominator does not own enough APOLLO");
        _newDAONominations[newDAO] = DAONomination({
            timeOfNomination: block.timestamp,
            nominator: _msgSender(),
            votesFor: 0,
            votesAgainst: 0,
            votingClosed: false
        });
        activeDAONominations += 1;
        emit NewDAONomination(newDAO, _msgSender());
    }

    /// @notice Close voting for the provided nomination, preventing any future votes
    /// @param newDAO The address of the nomination to close voting for
    function closeNewDAOVoting(address newDAO) external {
        require(block.timestamp > (_newDAONominations[newDAO].timeOfNomination + daoVotingDuration), "We have not passed the minimum voting duration");
        require(!_newDAONominations[newDAO].votingClosed, "Voting has already closed for this nomination");
        require(approvedNewDAO == address(0), "There is already an approved new DAO");

        bool approved = (_newDAONominations[newDAO].votesFor > _newDAONominations[newDAO].votesAgainst);
        if (approved) {
            approvedNewDAO = newDAO;
            daoApprovedTime = block.timestamp;
        }
        activeDAONominations -= 1;
        _newDAONominations[newDAO].votingClosed = true;
        emit VotingClosed(newDAO, approved);
    }

    /// @notice Update the address of the active DAO in the Apollo token contract
    /// @dev This function may only be called after a new DAO is approved and after the update delay has elapsed
    function updateDAOAddress() external {
        require(approvedNewDAO != address(0), "There is not an approved new DAO");
        require(block.timestamp > (daoApprovedTime + daoUpdateDelay), "We have not finished the delay for an approved DAO");
        apolloToken.changeArtistAddress(approvedNewDAO);
    }

    /// @notice The time the provided DAO address was nominated
    /// @param dao The DAO address that was previously nominated
    function daoNominationTime(address dao) external view returns (uint256){
        return _newDAONominations[dao].timeOfNomination;
    }

    /// @notice The account that nominated the provided DAO address
    /// @param dao The DAO address that was previously nominated
    function daoNominationNominator(address dao) external view returns (address){
        return _newDAONominations[dao].nominator;
    }

    /// @notice The amount of votes in favor of a nomination
    /// @param dao The DAO address to check
    function daoNominationVotesFor(address dao) external view returns (uint256){
        return _newDAONominations[dao].votesFor;
    }

    /// @notice The amount of votes against a nomination
    /// @param dao The DAO address to check
    function daoNominationVotesAgainst(address dao) external view returns (uint256){
        return _newDAONominations[dao].votesAgainst;
    }

    /// @notice Whether voting is closed for the provided DAO address
    /// @param dao The DAO address that was previously nominated
    function daoNominationVotingClosed(address dao) external view returns (bool){
        return _newDAONominations[dao].votingClosed;
    }

    /// @notice The amount of votes pledged by the provided voter for the provided DAO nomination
    /// @param voter The address who cast a vote for the DAO
    /// @param dao The address of the nominated DAO to check
    function checkAddressVoteAmount(address voter, address dao) external view returns (uint256){
        return _lockedVotes[voter][dao].voteCount;
    }

    function totalVoteInCycle(uint256 _cycle_id) public view returns(uint256){
        return votingData[_cycle_id].length;
    }

    function checkDAOAddressVote(address voter, address dao) external view returns (bool){
        return _lockedVotes[voter][dao].votedFor;
    }

    function hasVotedForCreator(address voter,uint256 _cycleId) external view returns (bool) {
        return _hasVoted[voter][_cycleId];
    }

    function isNominated(address nominee) public view returns (bool) {
        return _nominations[nominee] == currentVotingCycleEnd;
    }

    function checkCreatorVotesReceived(address candidate, uint256 cycle) external view returns (uint256) {
        return _votesReceived[candidate][cycle];
    }

    function voteBalanceOfACycle(uint256 cycle) external view returns (uint256) {
        return _voteBalanceOfACycle[cycle];
    }

    function addressVoteBalance(address voter, uint256 cycle) external view returns (uint256) {
        uint256 numberOfVotes = _votesCast[voter].length;
        for (uint256 i = 0; i < numberOfVotes; i++) {
            if (_votesCast[voter][i].voteCycle == cycle) {
                return _votesCast[voter][i].voteBalance;
            }
        }
        return 0;
    }

    // Internal functions

    /// @notice The minimum amount of Apollo an account must hold to submit a vote
    function _apolloAmountFromUSD(uint256 _usdAmount) internal view returns (uint256) {
        (uint usdcReserve, uint wethToUSDCReserve) = UniswapV2Library.getReserves(uniswapFactory, usdcAddress, wethAddress);
        (uint apolloReserve, uint wethToApolloReserve) = UniswapV2Library.getReserves(uniswapFactory, address(apolloToken), wethAddress);
        uint wethAmount = UniswapV2Library.quote(_usdAmount, usdcReserve, wethToUSDCReserve);
        uint apolloAmount = UniswapV2Library.quote(wethAmount, wethToApolloReserve, apolloReserve);
        return apolloAmount;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

library SafeMath {
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

library UniswapV2Library {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IUniswapV2Router02 {
    function factory() external view returns (address);
}

interface IApolloToken {
    function changeArtistAddress(address newAddress) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function burn(uint256 burnAmount) external;
    function reflect(uint256 tAmount) external;
    function artistDAO() external view returns (address);
    function uniswapRouter() external view returns (IUniswapV2Router02);
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}