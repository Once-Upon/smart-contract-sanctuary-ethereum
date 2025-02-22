// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// import "../ido/DynamicIdo.sol";
import "../ido/IDO.sol";

// solhint-disable not-rely-on-time
contract IDOTest is IDO {
    constructor(
        uint256 _tokenPrice,
        address _rewardToken,
        address _USDTAddress, // solhint-disable-line var-name-mixedcase
        address _USDCAddress, // solhint-disable-line var-name-mixedcase
        uint256 _startTime,
        uint256 _endTime,
        uint256 _claimTime,
        uint256 _maxReward,
        uint256 _maxDistribution,
        address _treasury
    )
        IDO(
            _tokenPrice,
            _rewardToken,
            _USDTAddress,
            _USDCAddress,
            _startTime,
            _endTime,
            _claimTime,
            _maxReward,
            _maxDistribution,
            _treasury
        )
    {} // solhint-disable-line no-empty-blocks

    function testResetUser(address _user) external {
        UserInfo storage user = userInfo[_user];

        user.reward = 0;
        user.withdrawn = 0;
    }

    function testSetContractDistribution(uint256 _distribution) external {
        currentDistributed = _distribution;
    }

    function testBeforeStart() external {
        startTime = block.timestamp + 900;
        endTime = block.timestamp + 1800;
        claimTime = block.timestamp + 2100;
    }

    function testInProgress() external {
        startTime = block.timestamp - 300;
        endTime = block.timestamp + 900;
        claimTime = block.timestamp + 2100;
    }

    function testEndedNotClaimable() external {
        startTime = block.timestamp - 600;
        endTime = block.timestamp - 300;
        claimTime = block.timestamp + 900;
    }

    function testSetTimestamps(
        uint256 start,
        uint256 end,
        uint256 claim
    ) external {
        startTime = start;
        endTime = end;
        claimTime = claim;
    }

    function testClaimable() external {
        startTime = block.timestamp - 600;
        endTime = block.timestamp - 300;
        claimTime = block.timestamp;
    }

    function testFinishVesting() external {
        startTime = block.timestamp - 602 days;
        endTime = block.timestamp - 601 days;
        claimTime = block.timestamp - 600 days;
    }

    function testResetContract() external {
        currentDistributed = 0;
    }

    function testAddWhitelisted(address user) external {
        _whitelisted[user] = true;
    }

    function testRemoveWhitelisted(address user) external {
        _whitelisted[user] = false;
    }

    function testSetUserReward(address _user) external {
        UserInfo storage user = userInfo[_user];

        user.reward = 10000;
        user.withdrawn = 0;
    }

    // function testSetMaxRewardMultiple(
    //     address[] calldata _holders,
    //     uint256[] calldata _maxRewards
    // ) external {
    //     require(
    //         _holders.length == _maxRewards.length,
    //         "Arrays must have the same length"
    //     );

    //     for (uint256 i = 0; i < _holders.length; ) {
    //         setMaxReward(_holders[i], _maxRewards[i]);
    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../claim/Claim.sol";
import "../whitelisted/Whitelisted.sol";

// solhint-disable not-rely-on-time
contract IDO is Claim, Whitelisted {
    using SafeERC20 for ERC20;

    uint256 public immutable tokenPrice;

    ERC20 public immutable USDTAddress; // solhint-disable-line var-name-mixedcase
    ERC20 public immutable USDCAddress; // solhint-disable-line var-name-mixedcase

    uint256 public startTime;
    uint256 public endTime;
    uint256 public immutable _maxReward;
    uint256 public immutable maxDistribution;
    uint256 public currentDistributed;

    address public immutable treasury;

    event Bought(
        address indexed holder,
        uint256 depositedAmount,
        uint256 rewardAmount
    );

    constructor(
        uint256 _tokenPrice,
        address _rewardToken, // Provided by VestedClaim
        address _USDTAddress, // solhint-disable-line var-name-mixedcase
        address _USDCAddress, // solhint-disable-line var-name-mixedcase
        uint256 _startTime,
        uint256 _endTime,
        uint256 _claimTime,
        uint256 maxReward_,
        uint256 _maxDistribution,
        address _treasury
    ) Claim(_claimTime, _rewardToken) {
        require( // solhint-disable-line reason-string
            _startTime < _endTime,
            "Start timestamp must be less than finish timestamp"
        );
        require( // solhint-disable-line reason-string
            _endTime > block.timestamp,
            "Finish timestamp must be more than current block time"
        );

        tokenPrice = _tokenPrice;
        USDTAddress = ERC20(_USDTAddress);
        USDCAddress = ERC20(_USDCAddress);
        startTime = _startTime;
        endTime = _endTime;
        _maxReward = maxReward_;
        maxDistribution = _maxDistribution;
        treasury = _treasury;

        // Provided by VestedClaim
        claimTime = _claimTime;
    }

    modifier checkTimespan() {
        require(block.timestamp >= startTime, "Not started");
        require(block.timestamp < endTime, "Ended");
        _;
    }

    modifier checkPaymentTokenAddress(ERC20 addr) {
        require(addr == USDTAddress || addr == USDCAddress, "Unexpected token");
        _;
    }

    function getMaxReward(address) public view virtual returns (uint256) {
        return _maxReward;
    }

    function buy(ERC20 paymentToken, uint256 depositedAmount)
        external
        checkTimespan
        onlyWhitelisted(msg.sender)
    {
        uint256 rewardTokenAmount = getTokenAmount(
            paymentToken,
            depositedAmount
        );

        currentDistributed = currentDistributed + rewardTokenAmount;
        require(currentDistributed <= maxDistribution, "Overfilled");

        paymentToken.safeTransferFrom(msg.sender, treasury, depositedAmount);

        UserInfo storage user = userInfo[msg.sender];
        uint256 totalReward = user.reward + rewardTokenAmount;
        require(totalReward <= getMaxReward(msg.sender), "More then max amount");
        addUserReward(msg.sender, rewardTokenAmount);

        emit Bought(msg.sender, depositedAmount, rewardTokenAmount);
    }

    function getTokenAmount(ERC20 paymentToken, uint256 depositedAmount)
        public
        view
        checkPaymentTokenAddress(paymentToken)
        returns (uint256)
    {
        // Reward token has 18 decimals
        return (depositedAmount * 1e18) / tokenPrice;
    }

    function withdrawUnallocatedToken() external onlyOwner {
        require(block.timestamp > endTime, "Sale not ended");
        uint256 amount = maxDistribution - currentDistributed;

        rewardToken.safeTransfer(msg.sender, amount);
    }
}
// solhint-enable not-rely-on-time

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
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

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

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
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
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
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
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
pragma solidity 0.8.9;

import "./VestedClaim.sol";

contract Claim is VestedClaim {
    event ClaimantsAdded(
        address[] indexed claimants,
        uint256[] indexed amounts
    );

    event RewardsFrozen(address[] indexed claimants);

    constructor(uint256 _claimTime, address _token) VestedClaim(_token) {
        claimTime = _claimTime;
    }

    function updateClaimTimestamp(uint256 _claimTime) external onlyOwner {
        claimTime = _claimTime;
    }

    function addClaimants(
        address[] calldata _claimants,
        uint256[] calldata _claimAmounts
    ) external onlyOwner {
        require(
            _claimants.length == _claimAmounts.length,
            "Arrays do not have equal length"
        );

        for (uint256 i = 0; i < _claimants.length; i++) {
            setUserReward(_claimants[i], _claimAmounts[i]);
        }

        emit ClaimantsAdded(_claimants, _claimAmounts);
    }

    function freezeRewards(address[] memory _claimants) external onlyOwner {
        for (uint256 i = 0; i < _claimants.length; i++) {
            freezeUserReward(_claimants[i]);
        }

        emit RewardsFrozen(_claimants);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Whitelisted is Ownable {
    mapping(address => bool) internal _whitelisted;

    event AddressesWhitelisted(address[] indexed accounts);

    modifier onlyWhitelisted(address addr) virtual {
        require(whitelisted(addr), "Address has not been whitelisted");
        _;
    }

    function whitelisted(address _address) public view virtual returns (bool) {
        return _whitelisted[_address];
    }

    function addWhitelisted(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _whitelisted[addresses[i]] = true;
        }

        emit AddressesWhitelisted(addresses);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
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
pragma solidity 0.8.9;

import "./BaseClaim.sol";

contract VestedClaim is BaseClaim {
    uint256 public constant BASE_POINTS = 10000;
    uint256 public initialUnlock; // percentage unlocked at claimTime (100% = 10000)
    uint256 public cliff; // delay before gradual unlock
    uint256 public vesting; // total time of gradual unlock
    uint256 public vestingInterval; // interval of unlock

    constructor(address _rewardToken) BaseClaim(_rewardToken) {
        require(initialUnlock <= BASE_POINTS, "initialUnlock too high");

        initialUnlock = 2000; // = 20%
        cliff = 90 days;
        vesting = 455 days;
        vestingInterval = 1 days;
    } // solhint-disable-line no-empty-blocks

    // This is a timed vesting contract
    //
    // Claimants can claim 20% of ther claim upon claimTime.
    // After 90 days, there is a cliff that starts a gradual unlock. For ~15 months (455 days),
    // a relative amount of the remaining 80% is unlocked.
    //
    // At claimTime: 20%
    // At claimTime + 90, until claimTime + 455 days: daily unlock
    // After claimTime + 90 + 455: 100%
    function calculateUnlockedAmount(uint256 _totalAmount, uint256 _timestamp)
        internal
        view
        override
        returns (uint256)
    {
        if (_timestamp < claimTime) {
            return 0;
        }

        uint256 timeSinceClaim = _timestamp - claimTime;
        uint256 unlockedAmount = 0;

        if (timeSinceClaim <= cliff) {
            unlockedAmount = (_totalAmount * initialUnlock) / BASE_POINTS;
        } else if (timeSinceClaim > cliff + vesting) {
            unlockedAmount = _totalAmount;
        } else {
            uint256 unlockedOnClaim = (_totalAmount * initialUnlock) / BASE_POINTS;
            uint256 vestable = _totalAmount - unlockedOnClaim;
            uint256 intervalsSince = (timeSinceClaim - cliff) / vestingInterval;
            uint256 totalVestingIntervals = vesting / vestingInterval;

            unlockedAmount =
                ((vestable * intervalsSince) / totalVestingIntervals) +
                unlockedOnClaim;
        }

        return unlockedAmount;
    }

    function totalAvailableAfter() public view override returns (uint256) {
        return claimTime + cliff + vesting;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// solhint-disable not-rely-on-time
contract BaseClaim is Ownable {
    using SafeERC20 for ERC20;

    struct UserInfo {
        uint256 reward;
        uint256 withdrawn;
    }
    mapping(address => UserInfo) public userInfo;

    uint256 public claimTime; // Time at which claiming can start

    ERC20 public immutable rewardToken; // Token that is distributed

    event RewardClaimed(
        address indexed user,
        uint256 indexed withdrawAmount,
        uint256 totalWithdrawn
    );
    event ClaimsPaused();
    event ClaimsUnpaused();

    uint256 public totalRewards;
    uint256 public totalWithdrawn;

    bool public areClaimsPaused;

    constructor(address _rewardToken) {
        require(
            address(_rewardToken) != address(0),
            "Reward token must be set"
        );

        rewardToken = ERC20(_rewardToken);

        claimTime = block.timestamp;
    }

    ////
    // Modifiers
    ////
    modifier onlyWithRewards(address addr) {
        require(userInfo[addr].reward > 0, "Address has no rewards");
        _;
    }

    ////
    // Functions
    ////

    function pauseClaims() external onlyOwner {
        areClaimsPaused = true;

        emit ClaimsPaused();
    }

    function unPauseClaims() external onlyOwner {
        areClaimsPaused = false;

        emit ClaimsUnpaused();
    }

    function addUserReward(address _user, uint256 _amount) internal {
        UserInfo storage user = userInfo[_user];
        uint256 newReward = user.reward + _amount;

        totalRewards = totalRewards + _amount;
        user.reward = newReward;
    }

    function setUserReward(address _user, uint256 _amount) internal {
        UserInfo storage user = userInfo[_user];

        totalRewards = (totalRewards + _amount) - (user.reward);
        user.reward = _amount;

        require(user.reward >= user.withdrawn, "Invalid reward amount");
    }

    function freezeUserReward(address _user) internal {
        UserInfo storage user = userInfo[_user];

        uint256 change = user.reward - user.withdrawn;

        user.reward = user.withdrawn;
        totalRewards = totalRewards - change;
    }

    function claim() external onlyWithRewards(msg.sender) {
        require(!areClaimsPaused, "Claims are paused");

        UserInfo storage user = userInfo[msg.sender];

        uint256 withdrawAmount = getWithdrawableAmount(msg.sender);

        user.withdrawn = user.withdrawn + withdrawAmount;
        totalWithdrawn = totalWithdrawn + withdrawAmount;

        assert(user.withdrawn <= user.reward);

        rewardToken.safeTransfer(msg.sender, withdrawAmount);

        emit RewardClaimed(msg.sender, withdrawAmount, user.withdrawn);
    }

    function getWithdrawableAmount(address _user)
        public
        view
        returns (uint256)
    {
        UserInfo memory user = userInfo[_user];

        uint256 unlockedAmount = calculateUnlockedAmount(
            user.reward,
            block.timestamp
        );

        return unlockedAmount - user.withdrawn;
    }

    // This is a timed vesting contract
    //
    // Claimants can claim 100% of ther claim upon claimTime.
    //
    // Can be overriden in contracts that inherit from this one.
    function calculateUnlockedAmount(uint256 _totalAmount, uint256 _timestamp)
        internal
        view
        virtual
        returns (uint256)
    {
        return _timestamp > claimTime ? _totalAmount : 0;
    }

    function totalAvailableAfter() public view virtual returns (uint256) {
        return claimTime;
    }

    function withdrawRewardAmount() external onlyOwner {
        rewardToken.safeTransfer(
            msg.sender,
            rewardToken.balanceOf(address(this)) - totalRewards
        );
    }

    function emergencyWithdrawToken(ERC20 tokenAddress) external onlyOwner {
        tokenAddress.safeTransfer(
            msg.sender,
            tokenAddress.balanceOf(address(this))
        );
    }
}
// solhint-enable not-rely-on-time

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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