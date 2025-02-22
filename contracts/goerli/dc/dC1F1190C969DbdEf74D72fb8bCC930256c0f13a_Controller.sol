// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./mocks/MockToken.sol";
import "./Pool.sol";
import "./RewardToken.sol";
import "./ChadsToken.sol";
// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Controller is ReentrancyGuard {
    using SafeERC20 for Pool;
    using SafeERC20 for IERC20;
    using SafeERC20 for RewardToken;
    using SafeERC20 for ChadsToken;

    RewardToken public rewardToken;
    ChadsToken public depositToken;

    Pool public poolA;
    Pool public poolB;

    Pool public winningPool;
    Pool public losingPool;

    // addresses not allowed to stake:
    mapping(address => bool) public blacklist;

    // the current epoch:
    uint256 public epoch;

    // an mapping to check if the user has already claimed the reward
    mapping(uint => mapping(address => bool)) public claimedEpoch;

    enum Phase {
        Cooldown,
        Staking,
        Claim,
        Swap,
        Trade
    }

    Phase public currentPhase = Phase.Cooldown;

    // timestamp when the current phase started
    uint public currentPhaseStart;

    // used for internal calculations to avoid precision loss:
    uint internal constant PRECISION = 10_000;

    // map of contract admins:
    mapping(address => bool) public admins;

    // the amount of reward tokens to be distributed in the current epoch:
    uint256 public rewardAmount;

    error InvalidPool();
    error InsufficientBalance(uint256 userBalance, uint256 amount);
    error NotStakedInLoosingPool();
    error NoRewardToSwap();
    error NotStakedInWinningPool();
    error AlreadyClaimed();
    error ClaimPeriodEnded();
    error ClaimPeriodNotEnded();
    error SwapPeriodEnded();
    error InsufficientRewardBalance();
    error StakingPeriodNotEnded();
    error InsufficientReward(uint256 tokenAmountSent, uint256 rewardNeededAmount);
    error InsufficientApproval(uint256 allowanceAvailable, uint256 amount);
    error PhaseAlreadyStarted();
    error NoStakers(uint256 winners, uint256 loosers);
    error WithdrawPendingReward();
    error NowAllowedToRecoverThisToken();
    error Blacklisted();
    error InvalidPhase(Phase current, Phase expected);
    error EtherNotAccepted();
    error InvalidRewardAmount();
    error AlreadyStakedInOtherPool();
    error OnlyAdmin();

    event CurrentPhase(Phase phase);
    event Deposit(address indexed user, address indexed pool, uint256 amount);
    event RewardDeposited(
        uint users,
        uint256 rewardDeposited
    );
    event RewardClaimed(address indexed user, uint256 rewardClaimed);
    event RewardSentToLoser(
        address indexed from,
        address indexed to,
        uint256 rewardSent
    );
    event RewardSwapped(
        address indexed user,
        uint256 userStakedBalance,
        uint256 userRewardBalance,
        uint256 rewardAmount
    );

    event Withdraw(address indexed user, uint balanceA, uint balanceB);

    event RewardAmount(uint256 amount);

    event SetBlacklistStatus(address indexed user, bool status);

    event SetAdmin(address indexed admin, bool status);

    /**
     * @dev Constructor function for the Controller contract.
     * @param _admin The address of the admin of the contract.
     * @param _router The address of the router contract.
     */
    constructor( address _admin, address _router ) {

        admins[_admin] = true;
        admins[msg.sender] = true;

        emit SetAdmin(_admin, true);
        emit SetAdmin(msg.sender, true);

        // Create a new ChadsToken contract
        depositToken = new ChadsToken(_admin, _router, "CZ VS SEK", "REGULATETHIS");

        // Create a new RewardToken contract and allow transfers to this contract
        rewardToken = new RewardToken();
        rewardToken.allowTransfer(address(this), true);

        // Create two new Pool contracts for Alpha Pool A and Alpha Pool B
        poolA = new Pool(payable(depositToken), "Pool A", "Pool-A");
        poolB = new Pool(payable(depositToken), "Pool B", "Pool-B");

        // allow to call views:
        winningPool = poolA;
        losingPool = poolB;

        // set default phase to cooldown, so admin can start Stake phase later:
        currentPhase = Phase.Cooldown;

    }

    fallback() external payable {
        revert EtherNotAccepted();
    }

    receive() external payable {
        revert EtherNotAccepted();
    }

    modifier onlyPhase(Phase phase) {
        if (currentPhase != phase) {
            revert InvalidPhase(currentPhase, phase);
        }
        _;
    }

    modifier onlyAdmin() {
        if(!admins[msg.sender])
            revert OnlyAdmin();
        _;
    }

    function setAdmin(address _minter, bool _status) external onlyAdmin {
        admins[_minter] = _status;
        emit SetAdmin(_minter, _status);
    }

    modifier isBlacklisted() {
        if (blacklist[msg.sender] == true)
            revert Blacklisted();
        _;
    }

    function recover(address tokenAddress) external onlyAdmin {
        if (
            tokenAddress == address(poolA) ||
            tokenAddress == address(poolB) ||
            tokenAddress == address(rewardToken)
        ) revert NowAllowedToRecoverThisToken();
        IERC20 token = IERC20(tokenAddress);
        token.transfer(
            msg.sender,
            token.balanceOf(address(this))
        );
    }

    function recoverFromPool(Pool pool, address tokenAddress) external onlyAdmin {
        pool.recover(tokenAddress, msg.sender);
    }

    function recoverFromRewardToken(address tokenAddress) external onlyAdmin {
        rewardToken.recover(tokenAddress, msg.sender);
    }

    /**
     * @dev Sets the current phase of the contract.
     * Only the contract owner can call this function.
     * @param phase The new phase to set.
     */
    function _setPhase(Phase phase) internal {
        /// Check that the new phase is different from the current phase
        if (phase == currentPhase) revert PhaseAlreadyStarted();

        // Update the current phase

        if (phase == Phase.Cooldown) {
            // during cooldown we disable deposits and enable withdraws,

            // this allow users to exit on any emergency:
            poolA.setDepositEnabled(false);
            poolB.setDepositEnabled(false);

            poolA.setWithdrawStatus(true);
            poolB.setWithdrawStatus(true);

        }else if (phase == Phase.Staking) {
            // during staking we enable deposits and disable withdraws:

            // set the epoch:
            ++epoch;

            poolA.setDepositEnabled(true);
            poolB.setDepositEnabled(true);

            poolA.setWithdrawStatus(false);
            poolB.setWithdrawStatus(false);

        } else if (phase == Phase.Trade) {
            // during trade we disable deposits and withdraws:

            poolA.setDepositEnabled(false);
            poolB.setDepositEnabled(false);

            winningPool.setWithdrawStatus(true);
            losingPool.setWithdrawStatus(true);

        }
        currentPhaseStart = block.timestamp;
        currentPhase = phase;
        emit CurrentPhase(currentPhase);
    }

    // 1 - People stake $PSYFLOP in pool A and pool B and staking is frozen by admin.
    function adminStartStakingPhase() external onlyAdmin {
        _setPhase(Phase.Staking);
    }

    function adminRestartProcess() external onlyAdmin onlyPhase(Phase.Trade) {
        _setPhase(Phase.Staking);
    }

    // 2 - Pools accept deposit up to 24 hours after staking phase is started.
    function stakeInPoolA(uint256 amount) external nonReentrant {
        _stakesInPool(poolA, amount);
    }

    function stakeInPoolB(uint256 amount) external nonReentrant {
        _stakesInPool(poolB, amount);
    }

    function stake(Pool pool, uint256 amount) external nonReentrant {
        _stakesInPool(pool, amount);
    }

    function _stakesInPool(Pool pool, uint256 amount) internal isBlacklisted onlyPhase(Phase.Staking) {
        // insure that the pool is valid
        if (pool != poolA && pool != poolB) revert InvalidPool();

        // check if user already have deposit in the other pool:
        Pool otherPool = pool == poolA ? poolB : poolA;
        if( otherPool.balanceOf(msg.sender) > 0 )
            revert AlreadyStakedInOtherPool();

        // insure that the user has enough balance
        uint256 userBalance = depositToken.balanceOf(msg.sender);
        if (userBalance < amount)
            revert InsufficientBalance(userBalance, amount);

        // insure that the user has approved the controller to transfer the amount
        uint256 allowance = depositToken.allowance(msg.sender, address(this));
        if (allowance < amount) revert InsufficientApproval(allowance, amount);

        // transfer the amount from the user to the controller
        uint256 _before = depositToken.balanceOf(address(this));
        depositToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 _after = depositToken.balanceOf(address(this));
        amount = _after - _before; // Additional check for deflationary tokens

        // approve the pool to transfer the amount from controller
        depositToken.approve(address(pool), amount);

        // deposit the amount in the pool
        pool.deposit(msg.sender, amount);

        emit Deposit(msg.sender, address(pool), amount);
    }

    // At Claim phase, we choose the winner and mint the RWD to be claimed.
    function adminChooseWinnerAndStartClaim(uint256 _rewardAmount) external onlyAdmin onlyPhase(Phase.Staking) {

        if (_rewardAmount < 1 ether) {
            // just to be safe during the mint share calculation:
            revert InvalidRewardAmount();
        }

        rewardAmount = _rewardAmount;

        // simple random number generation, as this is only callable by owner wallet, it reasonable safe:
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        if (random % 2 == 0) {
            winningPool = poolA;
        } else {
            winningPool = poolB;
        }
        losingPool = winningPool == poolA ? poolB : poolA;

        if (winningPool.usersLength() == 0 || losingPool.usersLength() == 0) {
            // prevent starting claim phase without sufficient stakers in the pools:
            revert NoStakers(
                winningPool.usersLength(),
                losingPool.usersLength()
            );
        }

        // mint the reward tokens to the controller to be distributed to winners:
        rewardToken.mint(address(this), _rewardAmount);

        // we only change phase in the end to set correct pool info:
        _setPhase(Phase.Claim);

        emit RewardDeposited(
            winningPool.usersLength(),
            _rewardAmount
        );
    }

    // return the amount of claimable reward:
    function claimable(address user) public view returns (uint256) {
        if (currentPhase != Phase.Claim) return 0;
        if (winningPool.balanceOf(user) == 0) return 0;
        if (claimedEpoch[epoch][user] == true) return 0;

        uint256 userStakedBalance = winningPool.balanceOf(user);
        uint256 winningSupply = winningPool.totalSupply();
        uint256 reward = ((userStakedBalance * rewardAmount) / winningSupply);

        return reward;
    }
    // 4 - Pool A and pool B stay untouched. If winner A, winner A addresses get to claim 100000 $X tokens.
    function claim() external nonReentrant onlyPhase(Phase.Claim) {

        // ensure that the user has staked in the winning pool

        if (winningPool.balanceOf(msg.sender) == 0)
            revert NotStakedInWinningPool();

        // prevent double claiming by checking the epoch:
        if( claimedEpoch[epoch][msg.sender] == true)
            revert AlreadyClaimed();

        // calculate user share:
        uint256 reward = claimable(msg.sender);

        if (reward == 0)
            revert InsufficientRewardBalance();

        // transfer reward to user
        rewardToken.safeTransfer(msg.sender, reward);

        // set current epoch as claimed:
        claimedEpoch[epoch][msg.sender] = true;

        emit RewardClaimed(msg.sender, reward);
    }

    // 6 - Team B addresses get to claim 100000 $Y tokens.
    function sendAllRewardToLoser(address to) external nonReentrant {
        _sendRewardToLoser(rewardToken.balanceOf(msg.sender), to);
    }

    function sendRewardFromWinnerToLoser(uint256 amount, address to) external nonReentrant {
        _sendRewardToLoser(amount, to);
    }

    function _sendRewardToLoser(uint256 amount, address to) internal onlyPhase(Phase.Claim) {

        // ensure that the user has enough balance
        if (rewardToken.balanceOf(msg.sender) == 0)
            revert InsufficientRewardBalance();

        // ensure that the user has staked in the winning pool
        if (losingPool.balanceOf(to) == 0) revert NotStakedInLoosingPool();

        // send the reward from the winner to the looser
        rewardToken.otcTransfer(msg.sender, to, amount);

        emit RewardSentToLoser(msg.sender, to, amount);
    }

    function adminStartTradePhase( uint _rewardAmount) external onlyAdmin onlyPhase(Phase.Claim) {

        if (_rewardAmount < 1 ether) {
            // just to be safe during the mint share calculation:
            revert InvalidRewardAmount();
        }

        // check approval to transfer reward to this contract:
        uint256 allowance = depositToken.allowance(msg.sender, address(this));
        if (allowance < _rewardAmount)
            revert InsufficientApproval(allowance, _rewardAmount);

        // transfer the reward to this contract:
        depositToken.safeTransferFrom(msg.sender, address(this), _rewardAmount);

        _setPhase(Phase.Trade);
    }

    function swapRewardToToken() external nonReentrant onlyPhase(Phase.Trade) {

        // ensure that the user has staked in the losing pool, this prevent
        // user transferring the reward to another address:
        if (rewardToken.balanceOf(msg.sender) == 0)
            revert InsufficientRewardBalance();

        uint256 userStakedBalance = losingPool.balanceOf(msg.sender);

        uint256 userRewardBalance = rewardToken.balanceOf(msg.sender); // 666.60 $RWD

        uint256 totalRewards = rewardToken.totalSupply(); // 1000

        uint256 availableRewards = depositToken.balanceOf(address(this)); // 2000

        if (userRewardBalance == 0)
            revert NoRewardToSwap();

        // // Player_A_1 can claim 700/1000 * 2000 = 1400 $PSYFLOP
        uint256 _rewardAmount = (((userRewardBalance*PRECISION)/totalRewards)*availableRewards/PRECISION);

        depositToken.safeTransfer(msg.sender, _rewardAmount);

        // burn the X token from user:
        rewardToken.burn(msg.sender, userRewardBalance);

        emit RewardSwapped(
            msg.sender,
            userStakedBalance,
            userRewardBalance,
            _rewardAmount
        );
    }

    function withdraw() external nonReentrant onlyPhase(Phase.Trade) {
        // revert if user has any pending claim:
        if (rewardToken.balanceOf(msg.sender) > 0)
            revert WithdrawPendingReward();
        uint balanceA = poolA.balanceOf(msg.sender);
        uint balanceB = poolB.balanceOf(msg.sender);
        if (balanceA > 0) {
            poolA.withdrawFromController(msg.sender);
        }
        if (balanceB > 0) {
            poolB.withdrawFromController(msg.sender);
        }
        emit Withdraw(msg.sender, balanceA, balanceB);
    }

    // set Cooldown, use to stop the contract:
    function adminSetCooldownPhase() external onlyAdmin {
        _setPhase(Phase.Cooldown);
    }

    // prevent a certain address to deposit:
    function adminSetBlacklist(address user, bool status) external onlyAdmin {
        blacklist[user] = status;
        emit SetBlacklistStatus(user, status);
    }

    // VIEWS
    // return total of users that staked in both pools:
    function getTotalStakedUsers() external view returns (uint256 poolAUsers, uint256 poolBUsers) {
        return (poolA.usersLength(), poolB.usersLength());
    }

    // return the total amount of token staked in both pools:
    function getTotalStaked() external view returns (uint256 poolAStaked, uint256 poolBStaked) {
        return (poolA.totalSupply(), poolB.totalSupply());
    }

    // return the amount of user token and reward tokens:
    function getUserBalance(address user) external view returns (uint256 poolABalance, uint256 poolBBalance, uint256 rewardBalance) {
        return (
            poolA.balanceOf(user),
            poolB.balanceOf(user),
            rewardToken.balanceOf(user)
        );
    }

    // return the amount of reward token that user can claim:
    function getUserPendingReward(address user) external view returns (uint256) {
        return rewardToken.balanceOf(user);
    }

    // return info about winner and looser pool that user staked in:
    function getUserPoolInfo(address user)
    external view returns (Pool.PoolInfo memory winner, Pool.PoolInfo memory looser) {
        if (winningPool.balanceOf(user) > 0) {
            winner = winningPool.getPoolInfo(user);
            looser = losingPool.getPoolInfo(user);
        } else {
            winner = losingPool.getPoolInfo(user);
            looser = winningPool.getPoolInfo(user);
        }
    }

    // get current phase:
    function getPhase() external view returns (Phase phase, uint startedIn) {
        return (currentPhase, currentPhaseStart);
    }

}

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
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// Uncomment this line to use console.log
//import "hardhat/console.sol";

contract ChadsToken is ERC20 {
    error EtherNotAccepted();
    error NowAllowedToRecoverThisToken();
    error NotAllowedToTransfer(address from, address to);
    error NotPublicLaunched();
    error OnlyAdmin();
    error MaxBuyLimit();
    error MaxWalletLimit();

    event SetAdmin(address indexed admin, bool status);

    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;
    mapping(address => bool) public admins;

    IUniswapV2Router02 public immutable router;
    address public pair;
    bool public isPublicLaunched = false;

    // max buy limit:
    uint256 public maxBuyLimit = 1_000 ether;

    // max wallet limit:
    uint256 public maxWalletLimit = 10_000 ether;

    constructor(address _admin, address _router, string memory _name, string memory _symbol)
    ERC20(_name, _symbol)
    {
        admins[msg.sender] = true;
        admins[_admin] = true;

        emit SetAdmin(msg.sender, true);
        emit SetAdmin(_admin, true);

        router = IUniswapV2Router02(_router);
        pair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH());

        // mint initial supply and send to admin for distribution:
        _mint(_admin, 1_000_000 ether);

    }

    function publicLaunch() external onlyAdmin {
        isPublicLaunched = true;
    }

    fallback() external payable {
        revert EtherNotAccepted();
    }
    receive() external payable {
        revert EtherNotAccepted();
    }

    modifier onlyAdmin() {
        if(!admins[msg.sender])
            revert OnlyAdmin();
        _;
    }

    function setAdmin(address _minter, bool _status) external onlyAdmin {
        admins[_minter] = _status;
        emit SetAdmin(_minter, _status);
    }

    function recover(address tokenAddress, address to) external onlyAdmin {
        if (tokenAddress == address(this))
            revert NowAllowedToRecoverThisToken();
        IERC20(tokenAddress).transfer(to, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function setBlacklist(address user, bool status) external onlyAdmin {
        blacklist[user] = status;
    }

    // add batch of users to whitelist:
    function addBatchToWhitelist(address[] calldata users, bool status) external onlyAdmin {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = status;
        }
    }
    function setWhitelist(address user, bool status) external onlyAdmin {
        whitelist[user] = status;
    }

    function setMaxBuyLimit(uint256 _maxBuyLimit) external onlyAdmin {
        maxBuyLimit = _maxBuyLimit;
    }

    function setMaxWalletLimit(uint256 _maxWalletLimit) external onlyAdmin {
        maxWalletLimit = _maxWalletLimit;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view override {

        // where are minting/burning tokens
        if (from == address(0) || to == address(0))
            return;

        // user is privileged
        if( whitelist[from] || whitelist[to] )
            return;

        // allow us to add liquidity:
        if( admins[from] || admins[to] )
            return;

        // check on blacklist for rogue users:
        if (blacklist[from] || blacklist[to])
            revert NotAllowedToTransfer(from, to);

        // see if public launch has active to allow users to swap:
        if ((from == pair || to == pair)) {

            // check if public launch has started:
            if (!isPublicLaunched)
                revert NotPublicLaunched();

        }

        // check max buy limit:
        if (from == pair && amount > maxBuyLimit){
            revert MaxBuyLimit();
        }

        // check max wallet limit:
        if (from == pair && balanceOf(to) + amount > maxWalletLimit){
            revert MaxWalletLimit();
        }
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken is Ownable, ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {

    }
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ChadsToken.sol";
// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Pool is ERC20, ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;
    using SafeERC20 for ChadsToken;
    using EnumerableSet for EnumerableSet.AddressSet;

    ChadsToken public token;
    EnumerableSet.AddressSet private _users;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event WithdrawStatus(bool enabled);
    event DepositStatus(bool enabled);

    error DepositDisabled();
    error WithdrawDisabled();
    error NotInStakingPhase();
    error StakingPeriodEnded();
    error NotInClaimPhase();
    error NotInSwapPhase();
    error NotInWithdrawPhase();
    error NotAllowedToTransfer(address from);
    error NowAllowedToRecoverThisToken();

    bool public IsWithdrawEnabled = false;
    bool public IsDepositEnabled = false;
    mapping (address => bool) public allowTransfer;

    constructor(address payable _token, string memory name, string memory symbol)
    ERC20(name, symbol)
    {
        token = ChadsToken(_token);
        allowTransfer[msg.sender] = true;
    }
    function recover(address tokenAddress, address to) external onlyOwner {
        if (tokenAddress == address(this) || tokenAddress == address(token) )
            revert NowAllowedToRecoverThisToken();
        IERC20 _token = IERC20(tokenAddress);
        _token.transfer(to, _token.balanceOf(address(this)));
        payable(to).transfer(address(this).balance);
    }

    // only controller can transfer tokens
    function _beforeTokenTransfer(address from, address to, uint256 /*amount*/ ) internal view override {
        // only allow transfer from controller or if we are minting or burning:
        // should allow when burning or minting:
        if (allowTransfer[msg.sender] == false && from != address(0) && to != address(0) ) {
            revert NotAllowedToTransfer(msg.sender);
        }
    }

    function deposit(address user, uint _amount) external onlyOwner {

        if( !IsDepositEnabled )
            revert DepositDisabled();

        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after - _before; // Additional check for deflationary tokens

        _mint(user, _amount);

        _users.add(user);

        emit Deposit(user, _amount);
    }

    function withdrawFromController(address user) external onlyOwner {
        _withdraw(user, balanceOf(user));
    }

    function withdraw() external nonReentrant {
        // for safety reasons only, use withdraw from controller,
        // to allow reward collection.
        _withdraw(msg.sender, balanceOf(msg.sender));
    }

    function _withdraw(address user, uint _amount) internal {

        if (!IsWithdrawEnabled)
            revert WithdrawDisabled();

        token.safeTransfer(user, _amount);
        _burn(user, _amount);

        if( balanceOf(address(this)) == 0 )
            _users.remove(user);

        emit Withdraw(user, _amount);
    }

    // TODO: check if necessary
    function setDepositEnabled(bool status) external onlyOwner {
        IsDepositEnabled = status;
        emit DepositStatus(IsDepositEnabled);
    }
    function setWithdrawStatus(bool status) external onlyOwner {
        IsWithdrawEnabled = status;
        emit WithdrawStatus(IsWithdrawEnabled);
    }

    function usersLength() external view returns (uint256) {
        return _users.length();
    }
    function getUserAt(uint256 index) external view returns (address) {
        return _users.at(index);
    }

    struct PoolInfo {
        uint256 totalSupply;
        uint256 balanceOfUser;
        uint256 totalUsers;
        bool IsDepositEnabled;
        bool IsWithdrawEnabled;
        string symbol;
    }
    // get pool info:
    function getPoolInfo(address user) external view returns (PoolInfo memory poolInfo) {
        poolInfo.totalSupply = totalSupply();
        poolInfo.balanceOfUser = balanceOf(user);
        poolInfo.totalUsers = _users.length();
        poolInfo.IsDepositEnabled = IsDepositEnabled;
        poolInfo.IsWithdrawEnabled = IsWithdrawEnabled;
        poolInfo.symbol = symbol();
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract RewardToken is ERC20, Ownable {
    mapping(address => bool) private _allowTransfer;
    error NotAllowedToTransfer(address from);
    error NowAllowedToRecoverThisToken();
    error EtherNotAccepted();

    constructor() ERC20("Reward Token", "RWD") {}

    fallback() external payable {
        revert EtherNotAccepted();
    }
    receive() external payable {
        revert EtherNotAccepted();
    }

    function recover(address tokenAddress, address to) external onlyOwner {
        if (tokenAddress == address(this))
            revert NowAllowedToRecoverThisToken();
        IERC20(tokenAddress).transfer(to, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function otcTransfer(
        address from,
        address to,
        uint256 amount
    ) external onlyOwner {
        _transfer(from, to, amount);
    }

    function allowTransfer(address to, bool status) external onlyOwner {
        _allowTransfer[to] = status;
    }

    function _beforeTokenTransfer(
        address /*from*/,
        address /*to*/,
        uint256 /* amount*/
    ) internal view override {
        if (_allowTransfer[msg.sender] == false)
            revert NotAllowedToTransfer(msg.sender);
    }

}