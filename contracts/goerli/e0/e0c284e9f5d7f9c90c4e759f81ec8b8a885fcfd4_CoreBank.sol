/**
 *Submitted for verification at Etherscan.io on 2022-09-11
*/

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5dfe7215a9156465d550030eadc08770503b2b2f/contracts/GSN/Context.sol

pragma solidity ^0.6.0;

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
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }

    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5dfe7215a9156465d550030eadc08770503b2b2f/contracts/ownership/Ownable.sol

pragma solidity ^0.6.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
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
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
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
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal virtual {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5dfe7215a9156465d550030eadc08770503b2b2f/contracts/math/SafeMath.sol

pragma solidity ^0.6.0;

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
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
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
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: SimpelBank1.sol

pragma solidity ^0.6.0;



contract CoreBank is Ownable{
    using SafeMath for uint256;
    mapping (address => uint256) public balances;

    address[] accounts;

    uint256 rate = 3;

    // address public owner;

    //Everts - user
    event DepositMade(address indexed accountAddress, uint256 amount);
    event WithdrawMade(address indexed accountAddress, uint256 amount);

    //Everts - system
    event SystemDepositMade(address indexed admin, uint256 amount);
    event SystemWithdrawMade(address  indexed admin, uint256 amount);
    event PayDividendMadeMade(address  indexed admin, uint256 totalInterest);


    // constructor() public {
    //     owner = msg.sender;
    // }

    function deposit() public payable returns (uint256) {
        if(0 == balances[msg.sender]) {
            accounts.push(msg.sender);
        }
        
    
        balances[msg.sender] = balances[msg.sender].add(msg.value);

        //Broadcast
        emit DepositMade(msg.sender, msg.value);

        return balances[msg.sender];
    }

    function withdraw(uint256 withDrawAmount) public returns (uint256 remainingBalance) {
        require(balances[msg.sender] >= withDrawAmount, "amount to withdraw is not enough!" );
        balances[msg.sender] = balances[msg.sender].sub(withDrawAmount);


        //Transfer ether back to user , revert on failed
        msg.sender.transfer(withDrawAmount);


        //return balances[msg.sender];
        remainingBalance = balances[msg.sender];
    
        //Broadcast
        emit WithdrawMade(msg.sender,withDrawAmount);
    }

    function systemBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function systemWithdraw(uint256 withDrawAmount) public onlyOwner returns(uint256){
        //Only Owner
        //require(owner == msg.sender, "you are not authorized to perform this function");
        require(systemBalance() >= withDrawAmount,"amont to withdraw is not enough !!!");

        msg.sender.transfer(withDrawAmount);


        emit SystemWithdrawMade(msg.sender,withDrawAmount);


        return systemBalance();
    }

    function systemDeposit() public payable onlyOwner returns(uint256){
        //require(owner == msg.sender, "you not owner");

        emit SystemDepositMade(msg.sender,msg.value);
        return systemBalance();
    }

    function calculateInterest(address _user, uint256 _rate) private view returns (uint256){
        uint256 interest = balances[_user].mul(_rate).div(100);
        return interest;
    }

    function totalInterestPerYear() external view returns(uint256){
        uint256 totalInterest = 0;
        for (uint256 i = 0; i < accounts.length; i++ ){
            address _account = accounts[i];
            uint256 _interest = calculateInterest(_account,rate);
            totalInterest = totalInterest.add(_interest);
        }

        return totalInterest;
    }


    function payDividendsPerYear() public payable onlyOwner {
        //require(owner == msg.sender, "you not owner");
        uint256 totalInterest = 0;
        for (uint256 i = 0; i < accounts.length; i++ ){
            address _account = accounts[i];
            uint256 _interest = calculateInterest(_account,rate);
            balances[_account] = balances[_account].add(_interest);
            totalInterest = totalInterest.add(_interest);
        }
        require(msg.value == totalInterest, "Not enough interest to pay");

        emit PayDividendMadeMade(msg.sender, totalInterest);
    }
}