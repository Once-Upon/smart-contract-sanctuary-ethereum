//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts-0.8/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-0.8/access/Ownable.sol";
import "@openzeppelin/contracts-0.8/token/ERC20/IERC20.sol";

contract ColdStakingTest is Ownable {
    IERC20 public immutable srgToken;

    struct Stake {
        uint256 stakeId;
        address stakerAddress;
        uint256 amountStaked;
        uint256 finalReward;
        uint256 deadline;
    }

    event NewStake(
        uint256 stakeId,
        address indexed stakerAddress,
        uint256 amountStaked,
        uint256 deadline
    );

    event StakePaid(
        uint256 stakeId,
        address indexed stakerAddress,
        uint256 amountStaked,
        uint256 deadline
    );

    mapping(uint256 => Stake) public stakes;

    uint256 public stakeCounter;

    // How much stake reward is already being expected;
    uint256 private _totalReward;

    //  user address => his amount of stakedBalance
    mapping(address => uint256) public stakedBalance;

    constructor(address _srgTokenAddress) {
        srgToken = IERC20(_srgTokenAddress);
    }

    function stake(uint256 amount, uint256 dayAmount) external {
        require(amount > 0, "amount = 0");

        require(dayAmount >= 30, "Minimum time staked is one month");

        require(dayAmount <= 365, "Maximum time staked is one year");
        require(
            srgToken.balanceOf(msg.sender) >=
                stakedBalance[msg.sender] + amount,
            "Don't have any unlocked tokens to stake"
        );

        // Calculate if contract has enough money to pay

        //     APYBase = 6 %
        //     APYExtraDay = 0.0328358 %                                days
        //     finalReward = amount * (APYBase+ days*(APYExtraDay))  * ------
        //                                                              365

        uint256 finalReward = ((amount * 6 * dayAmount) /
            100 +
            (amount * dayAmount**2 * 328358) /
            1000000000) / 365;

        //
        //  BC = SRG balance of contract
        //  TR = How much token is already saved to pay for current stakers
        //  FR = The final reward of staker after his locked duration ends
        //
        //  BC - TR >= FR

        require(
            srgToken.balanceOf(address(this)) - _totalReward >= finalReward,
            "Contract doesn't have enough SRG Token to give rewards"
        );

        _totalReward += finalReward;
        stakedBalance[msg.sender] += amount;

        uint256 stakeId = stakeCounter++;
        Stake storage newStake = stakes[stakeId];

        newStake.deadline = block.timestamp + dayAmount * (1 seconds);
        newStake.amountStaked = amount;
        newStake.finalReward = finalReward;
        newStake.stakeId = stakeId;
        newStake.stakerAddress = msg.sender;

        emit NewStake(stakeId, msg.sender, amount, newStake.deadline);
    }

    function unStake(uint256 stakeId) external {
        require(
            stakes[stakeId].stakerAddress == msg.sender,
            "Only staker can withdraw"
        );

        require(
            stakes[stakeId].deadline <= block.timestamp,
            "Stake has not expired"
        );

        srgToken.transfer(msg.sender, stakes[stakeId].finalReward);
        _totalReward -= stakes[stakeId].finalReward;
        stakedBalance[msg.sender] -= stakes[stakeId].amountStaked;

        emit StakePaid(
            stakeId,
            msg.sender,
            stakes[stakeId].amountStaked,
            stakes[stakeId].deadline
        );

        delete stakes[stakeId];
    }

    function balanceOf(address account) external view returns (uint256) {
        return stakedBalance[account];
    }
}

// SPDX-License-Identifier: MIT

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
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity ^0.8.0;

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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}