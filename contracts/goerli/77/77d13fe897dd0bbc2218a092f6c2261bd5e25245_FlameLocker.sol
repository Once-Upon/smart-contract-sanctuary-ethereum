/**
 *Submitted for verification at Etherscan.io on 2022-10-15
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
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
    constructor () internal {
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

/**
 * @dev Interface of the BEP20 standard as defined in the EIP.
 */
interface IBEP20 {
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

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// FlameToken locker contract.
contract FlameLocker is Ownable {
    using SafeMath for uint256;
    IBEP20 flameToken;
    address emergencyAddress;
    bool emergencyFlag = false;

    struct LockInfo{
        uint256 _amount;
        uint256 _timestamp;
        bool _isDev;
    }

    uint256 public lockingPeriod;
    uint256 public devLockingPeriod;

    mapping (address => LockInfo[]) public lockInfoByUser;
    mapping (address => uint256) public latestCounterByUser;
    mapping (address => uint256) public unclaimedTokensByUser;

    event LockingPeriod(address indexed user, uint newLockingPeriod, uint newDevLockingPeriod);

    constructor(address _flameToken, address _emergencyAddress, uint256 _lockingPeriodInDays, uint256 _devLockingPeriodInDays) public {
        require(address(_flameToken) != address(0), "_flame token is a zero address");
        require(address(_emergencyAddress) != address(0), "_emergencyAddress is a zero address");
        flameToken = IBEP20(_flameToken);
        emergencyAddress = _emergencyAddress;
        lockingPeriod = _lockingPeriodInDays * 1 days;
        devLockingPeriod = _devLockingPeriodInDays * 1 days;
    }

    // function to lock user reward flame tokens in token contract, called by onlyOwner that would be TopDog.sol
    function lock(address _holder, uint256 _amount, bool _isDev) external onlyOwner {
        require(_holder != address(0), "Invalid user address");
        require(_amount > 0, "Invalid amount entered");

        lockInfoByUser[_holder].push(LockInfo(_amount, now, _isDev));
        unclaimedTokensByUser[_holder] = unclaimedTokensByUser[_holder].add(_amount);
    }

    // function to claim all the tokens locked for a user, after the locking period
    function claimAllForUser(uint256 r, address user) public {
        require(!emergencyFlag, "Emergency mode, cannot access this function");
        require(r>latestCounterByUser[user], "Increase right header, already claimed till this");
        require(r<=lockInfoByUser[user].length, "Decrease right header, it exceeds total length");
        LockInfo[] memory lockInfoArrayForUser = lockInfoByUser[user];
        uint256 totalTransferableAmount = 0;
        uint i;
        for (i=latestCounterByUser[user]; i<r; i++){
            uint256 lockingPeriodHere = lockingPeriod;
            if(lockInfoArrayForUser[i]._isDev){
                lockingPeriodHere = devLockingPeriod;
            }
            if(now >= (lockInfoArrayForUser[i]._timestamp.add(lockingPeriodHere))){
                totalTransferableAmount = totalTransferableAmount.add(lockInfoArrayForUser[i]._amount);
                unclaimedTokensByUser[user] = unclaimedTokensByUser[user].sub(lockInfoArrayForUser[i]._amount);
                latestCounterByUser[user] = i.add(1);
            } else {
                break;
            }
        }
        flameToken.transfer(user, totalTransferableAmount);
    }

    // function to claim all the tokens locked by user, after the locking period
    function claimAll(uint256 r) external {
        claimAllForUser(r, msg.sender);
    }

    // function to get claimable amount for any user
    function getClaimableAmount(address _user) external view returns(uint256) {
        LockInfo[] memory lockInfoArrayForUser = lockInfoByUser[_user];
        uint256 totalTransferableAmount = 0;
        uint i;
        for (i=latestCounterByUser[_user]; i<lockInfoArrayForUser.length; i++){
            uint256 lockingPeriodHere = lockingPeriod;
            if(lockInfoArrayForUser[i]._isDev){
                lockingPeriodHere = devLockingPeriod;
            }
            if(now >= (lockInfoArrayForUser[i]._timestamp.add(lockingPeriodHere))){
                totalTransferableAmount = totalTransferableAmount.add(lockInfoArrayForUser[i]._amount);
            } else {
                break;
            }
        }
        return totalTransferableAmount;
    }

    // get the left and right headers for a user, left header is the index counter till which we have already iterated, right header is basically the length of user's lockInfo array
    function getLeftRightCounters(address _user) external view returns(uint256, uint256){
        return(latestCounterByUser[_user], lockInfoByUser[_user].length);
    }

    // in cases of emergency, emergency address can set this to true, which will enable emergencyWithdraw function
    function setEmergencyFlag(bool _emergencyFlag) external {
        require(msg.sender == emergencyAddress, "This function can only be called by emergencyAddress");
        emergencyFlag = _emergencyFlag;
    }

    // function for owner to transfer all tokens to another address
    function emergencyWithdrawOwner(address _to) external onlyOwner{
        uint256 amount = flameToken.balanceOf(address(this));
        require(flameToken.transfer(_to, amount), 'MerkleDistributor: Transfer failed.');
    }

    // emergency address can be updated from here
    function setEmergencyAddr(address _newAddr) external {
        require(msg.sender == emergencyAddress, "This function can only be called by emergencyAddress");
        require(_newAddr != address(0), "_newAddr is a zero address");
        emergencyAddress = _newAddr;
    }

    // function to update/change the normal & dev locking period
    function setLockingPeriod(uint256 _newLockingPeriod, uint256 _newDevLockingPeriod) external onlyOwner {
        lockingPeriod = _newLockingPeriod;
        devLockingPeriod = _newDevLockingPeriod;
        emit LockingPeriod(msg.sender, _newLockingPeriod, _newDevLockingPeriod);
    }
}