//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ballot.sol";

/**
 * @author Panxora
 */

contract BallotFactory is AccessControl {
    event BallotCreated(
        address indexed ballotAddress,
        string title,
        uint256 dateToStart,
        uint256 dateToEnd,
        uint8 options,
        uint256 ballotCount
    );

    event Voted(address voter, uint8 option, uint256 amount);

    event VotedRemaining(address voter, uint8 option);

    bytes32 public constant TEAM_MEMBER = keccak256("TEAM_MEMBER");

    address public immutable token;

    address[] public ballots;

    uint256 public ballotCount;

    constructor(address tokenAddress) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEAM_MEMBER, msg.sender);

        token = tokenAddress;
    }

    /* ====== CREATE BALLOT CONTRACT ====== */

    function createBallot(
        string memory title,
        uint256 dateToStart,
        uint256 dateToEnd,
        uint8 options
    ) public onlyRole(TEAM_MEMBER) {
        ballotCount++;

        Ballot ballot = new Ballot(
            title,
            dateToStart,
            dateToEnd,
            options,
            ballotCount,
            token
        );

        ballots.push(address(ballot));

        Token(token).addTeamMember(address(ballot));

        emit BallotCreated(
            address(ballot),
            title,
            dateToStart,
            dateToEnd,
            options,
            ballotCount
        );
    }

    /* ====== INTERACT WITH BALLOT CONTRACT ====== */

    function editBallot(
        uint256 ballotID,
        string memory title,
        uint256 dateToStart,
        uint256 dateToEnd,
        uint8 options
    ) public onlyRole(TEAM_MEMBER) {
        address ballotAddress = ballots[ballotID];

        Ballot(ballotAddress).editBallot(
            title,
            dateToStart,
            dateToEnd,
            options
        );
    }

    function addTitleToOption(
        uint256 ballotID,
        uint8 option,
        string memory title
    ) public onlyRole(TEAM_MEMBER) {
        address ballotAddress = ballots[ballotID];

        Ballot(ballotAddress).addTitleToOption(option, title);
    }

    function vote(
        uint256 ballotID,
        uint8 option,
        uint256 amount
    ) public {
        address ballotAddress = ballots[ballotID];

        Ballot(ballotAddress).vote(option, amount, msg.sender);

        emit Voted(msg.sender, option, amount);
    }

    function voteRemaining(uint256 ballotID, uint8 option) public {
        address ballotAddress = ballots[ballotID];

        Ballot(ballotAddress).voteRemaining(option, msg.sender);

        emit VotedRemaining(msg.sender, option);
    }

    function sealABallot(uint256 ballotID) public onlyRole(TEAM_MEMBER) {
        address ballotAddress = ballots[ballotID];
        Ballot(ballotAddress).sealBallot();
    }

    function closeABallot(uint256 ballotID) public onlyRole(TEAM_MEMBER) {
        address ballotAddress = ballots[ballotID];
        Ballot(ballotAddress).closeBallot();
    }

    function defineWinner(uint256 ballotID) public onlyRole(TEAM_MEMBER) {
        address ballotAddress = ballots[ballotID];
        Ballot(ballotAddress).defineWinner();
    }

    /* ====== READ A BALLOT CONTRACT ====== */

    function getBallot(uint256 ballotID)
        public
        view
        returns (
            string memory title,
            uint256 dateToStart,
            uint256 dateToEnd,
            uint8 options,
            bool isSealed
        )
    {
        address ballotAddress = ballots[ballotID];

        Ballot ballot = Ballot(ballotAddress);

        return (
            ballot.title(),
            ballot.dateToStart(),
            ballot.dateToEnd(),
            ballot.options(),
            ballot.isSealed()
        );
    }

    function viewAllBallotsAddresses() public view returns (address[] memory) {
        return ballots;
    }

    function viewVoters(uint256 ballotID)
        public
        view
        returns (address[] memory)
    {
        address ballotAddress = ballots[ballotID];

        Ballot ballot = Ballot(ballotAddress);

        return ballot.viewVoters();
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Token.sol";

/**
 * @author Panxora
 */

contract Ballot is AccessControl {
    event Voted(address voter, uint8 option, uint256 amount);

    event OptionAdded(uint8 option, string optionName);

    event BallotSealed(bool wasSealed);

    event BallotClosed(bool wasClosed);

    event WinnerDefined(uint8 winner);

    event BallotEdited(
        string title,
        uint256 dateToStart,
        uint256 dateToEnd,
        uint8 options
    );

    bytes32 public constant TEAM_MEMBER = keccak256("TEAM_MEMBER");

    address public immutable token;

    address[] public voters;

    string public title;

    uint256 public ballotCount;
    uint256 public dateToStart;
    uint256 public dateToEnd;
    uint256 public totalVotes;
    uint256 public totalTokens;
    uint8 public options;

    uint8 public optionWinner;

    bool public isSealed;

    mapping(address => uint256) public tokensUsed;
    mapping(uint8 => uint256) public optionVotes;
    mapping(uint8 => string) public optionName;

    mapping(address => bool) private _voted;

    constructor(
        string memory setTitle,
        uint256 setDateToStart,
        uint256 setDateToEnd,
        uint8 setOptions,
        uint256 setBallotCount,
        address setTokenAddress
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEAM_MEMBER, msg.sender);

        title = setTitle;
        dateToStart = setDateToStart;
        dateToEnd = setDateToEnd;
        options = setOptions;

        ballotCount = setBallotCount;

        token = setTokenAddress;
    }

    function vote(
        uint8 option,
        uint256 amount,
        address from
    ) public onlyRole(TEAM_MEMBER) isBallotValid(true) {
        require(amount > 0, "You must vote for at least 1 token");

        uint256 tokensLeft = IERC20(token).balanceOf(from) - tokensUsed[from];
        require(tokensLeft > 0, "You have no tokens left to vote");

        require(
            IERC20(token).balanceOf(from) >= amount,
            "You do not have enough tokens"
        );

        require(option <= options, "Invalid option");

        tokensUsed[from] += amount;
        optionVotes[option] += amount;

        Token(token).addTokensUsedBallot(from, amount);

        if (!_voted[from]) {
            voters.push(from);
            totalVotes++;
        }

        _voted[from] = true;

        emit Voted(from, option, amount);
    }

    function voteRemaining(uint8 option, address from)
        public
        onlyRole(TEAM_MEMBER)
        isBallotValid(true)
    {
        uint256 remainingTokens = IERC20(token).balanceOf(msg.sender) -
            tokensUsed[msg.sender];

        require(remainingTokens > 0, "You have no tokens left to vote");

        vote(option, remainingTokens, from);
    }

    function editBallot(
        string memory newTitle,
        uint256 newDateToStart,
        uint256 newDateToEnd,
        uint8 newOptions
    ) public onlyRole(TEAM_MEMBER) isBallotValid(false) {
        title = newTitle;
        dateToStart = newDateToStart;
        dateToEnd = newDateToEnd;
        options = newOptions;

        emit BallotEdited(title, dateToStart, dateToEnd, options);
    }

    function addTitleToOption(uint8 option, string memory name)
        public
        onlyRole(TEAM_MEMBER)
        isBallotValid(false)
    {
        require(option <= options, "Invalid option");
        optionName[option] = name;

        emit OptionAdded(option, name);
    }

    function closeBallot() public onlyRole(TEAM_MEMBER) isBallotValid(true) {
        uint256 users = voters.length;

        for (uint256 i = 0; i < users; i++) {
            address user = voters[i];
            uint256 tokens = tokensUsed[voters[i]];

            Token(token).removeTokensUsedBallot(user, tokens);
        }

        emit BallotClosed(true);
    }

    function sealBallot() public onlyRole(TEAM_MEMBER) isBallotValid(false) {
        isSealed = true;
        emit BallotSealed(isSealed);
    }

    function defineWinner() public onlyRole(TEAM_MEMBER) isBallotValid(true) {
        optionWinner = _getWinner();
        emit WinnerDefined(optionWinner);
    }

    function viewVoters() public view returns (address[] memory) {
        return voters;
    }

    function _getWinner() private view returns (uint8) {
        uint8 winner = 0;
        uint256 maxVotes = 0;

        for (uint8 i = 1; i <= options; i++) {
            if (optionVotes[i] > maxVotes) {
                maxVotes = optionVotes[i];
                winner = i;
            }
        }

        return winner;
    }

    modifier isBallotValid(bool _isSealed) {
        require(isSealed == _isSealed, "Ballot is not valid");

        if (isSealed) {
            uint256 lastBlockTime = block.timestamp;

            require(
                dateToStart > 0 &&
                    dateToEnd > 0 &&
                    dateToStart <= dateToEnd &&
                    lastBlockTime < dateToEnd &&
                    lastBlockTime > dateToStart,
                "This Ballot is not Valid"
            );
        }

        _;
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

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @author Panxora
 */

contract Token is ERC20, AccessControl {
    bytes32 public constant TEAM_MEMBER = keccak256("TEAM_MEMBER");

    string public constant NAME = "AICoin";
    string public constant SYMBOL = "XAI";

    uint256 public constant INITIAL_SUPPLY = 1 * 10**6 * 10**8;

    address private _deployer;

    constructor() ERC20(NAME, SYMBOL) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEAM_MEMBER, msg.sender);

        _mint(msg.sender, INITIAL_SUPPLY);

        _deployer = msg.sender;
    }

    /* ======== TOKEN FUNCTIONS ========*/

    function mint(address to, uint256 amount) public onlyRole(TEAM_MEMBER) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(TEAM_MEMBER) {
        _burn(from, amount);
    }

    function decimals() public view virtual override(ERC20) returns (uint8) {
        return 8;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        uint256 balance = balanceOf(from);
        uint256 tokensLocked = tokensUsedLock[from];
        uint256 tokensLeft = balance - tokensLocked;

        uint256 tokensLeftBallot = balanceOf(from) - tokensUsedBallot[from];

        if (
            !((_deployer == from) ||
                hasRole(TEAM_MEMBER, from) ||
                from == address(0))
        ) {
            require(tokensLeft > 0, "Token: No tokens left");
            require(tokensLeftBallot > 0, "Token: No tokens left");
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    /* ======== BOOKEEPER ========*/

    mapping(address => uint256) public tokensUsedBallot;
    mapping(address => uint256) public tokensUsedLock;

    function addTokensUsedBallot(address to, uint256 amount)
        public
        onlyRole(TEAM_MEMBER)
    {
        tokensUsedBallot[to] += amount;
    }

    function removeTokensUsedBallot(address from, uint256 amount)
        public
        onlyRole(TEAM_MEMBER)
    {
        tokensUsedBallot[from] -= amount;
    }

    /* ======== LOCK TOKENS ======== */

    event TokensLocked(address indexed user, uint256 amount);
    event TokensUnlocked(address indexed user, uint256 amount);
    event Rewarded(address indexed user, uint256 amount);

    uint256 public totalLockedTokens;
    uint256 public rewardPerSecond;

    mapping(address => uint256) public timeLocked;
    mapping(address => uint256) public reward;

    function lockTokens(uint256 amount) public {
        uint256 balance = balanceOf(msg.sender);
        uint256 tokensLocked = tokensUsedLock[msg.sender];
        uint256 tokensLeft = balance - tokensLocked;

        require(tokensLeft > 0, "Token: No tokens left");
        require(amount <= tokensLeft, "Token: Not enough tokens left");

        tokensUsedLock[msg.sender] += amount;
        totalLockedTokens += amount;

        uint256 beforeLock = tokensUsedLock[msg.sender] - amount;

        if (beforeLock > 0) {
            uint256 timePassed = block.timestamp - timeLocked[msg.sender];
            reward[msg.sender] += (timePassed * rewardPerSecond * tokensLocked);
        }

        timeLocked[msg.sender] = block.timestamp;

        emit TokensLocked(msg.sender, amount);
    }

    function unlockTokens(uint256 amount) public {
        uint256 tokensLocked = tokensUsedLock[msg.sender];

        require(amount <= tokensLocked, "Token: Not enough tokens locked");

        tokensUsedLock[msg.sender] -= amount;
        totalLockedTokens -= amount;

        emit TokensUnlocked(msg.sender, amount);
    }

    function getReward() public {
        uint256 timePassed = block.timestamp - timeLocked[msg.sender];

        require(tokensUsedLock[msg.sender] > 0, "Token: No tokens locked");
        require(timePassed > 0, "Token: No time passed");

        uint256 rewardAmount = reward[msg.sender] +
            (timePassed * rewardPerSecond);

        _mint(msg.sender, rewardAmount);

        reward[msg.sender] = 0;
        timeLocked[msg.sender] = block.timestamp;

        emit Rewarded(msg.sender, rewardAmount);
    }

    function setReward(uint256 amount) public onlyRole(TEAM_MEMBER) {
        rewardPerSecond = amount;
    }

    /* ======== ACCESS CONTROL ======== */

    function addTeamMember(address addr) public onlyRole(TEAM_MEMBER) {
        _setupRole(TEAM_MEMBER, addr);
    }

    function removeTeamMember(address addr) public onlyRole(TEAM_MEMBER) {
        revokeRole(TEAM_MEMBER, addr);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

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
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
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
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
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
        }
        _balances[to] += amount;

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
        _balances[account] += amount;
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
        }
        _totalSupply -= amount;

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
// OpenZeppelin Contracts (last updated v4.6.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
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