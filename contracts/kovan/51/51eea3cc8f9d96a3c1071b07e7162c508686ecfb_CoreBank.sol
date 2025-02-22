/**
 *Submitted for verification at Etherscan.io on 2022-06-03
*/

// SPDX-License-Identifier: MIT
// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Context.sol


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

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

//pragma solidity ^0.8.0;


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

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol


// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

//pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// File: EP13-SimpleBank.sol

//pragma solidity ^0.8.0;

// SafeMath เป็น Library

// Ownable เป็น Contract


//ทำการเอา contract CoreBank ต่อจาก Contract Ownable
contract CoreBank is Ownable{
    using SafeMath for uint256;

    // Dictionary mapping address to be their balance in Banking
    mapping (address => uint256) public balances;

    // Total user (ใช้เพื่อนำมาหารกำไรเพื่อนำมาเป็นปันผลให้ account ทั้งหมดที่มีอยู่)
    address[] accounts;

    // Interest rate (คำนวณดอกเบี้ย)
    uint256 rate = 3;

    //Event - user (ใส้ indexed เพื่อให้สามารถ filter ได้จาก UI)
    event DepositMade(address indexed accountAddress, uint256 amount);
    event WithdrawMade(address indexed accountAddress, uint256 amount);

    //Event - system (ใส้ indexed เพื่อให้สามารถ filter ได้จาก UI)
    event SystemDepositMade(address indexed admin, uint256 amount);
    event SystemWithdrawMade(address indexed admin, uint256 amount);

    //Event - Dividend (ใส้ indexed เพื่อให้สามารถ filter ได้จาก UI)
    event PayDividendPerUserMade(address indexed accountAddress, uint256 interest);
    event TotalPayDividendMade(uint256 totalInterest);

    //ไม่ใช้แล้วเพราะมีตัวแปรที่มาจาก owner ที่มาจาก Ownable
    // Owner of the system
    // address public owner;

    //ไม่ใช้แล้วเพราะมี constructor ที่ทำหน้าที่ระบุ owner ให้เรียบร้อยแล้วใน Ownable
    // constructor() {
    //     owner = msg.sender;
    // }

    function deposit() public payable returns (uint256){
        //เช็คว่า user มีเงินเหลือใน balances มั้ยเพื่อเก็บ account เข้า address[]
        if(balances[msg.sender] == 0){
            accounts.push(msg.sender);
        }

        balances[msg.sender] = balances[msg.sender].add(msg.value);

        //Boardcast deposit event
        emit DepositMade(msg.sender, msg.value);

        return balances[msg.sender];
    }

    function withdraw(uint256 amount) public returns (uint256 remainingBalance) {
        require(amount <= balances[msg.sender], "amount to withdraw is not enough!");
        balances[msg.sender] = balances[msg.sender].sub(amount);
        
        //Transfer ether back to user, revert on failed case
        payable(msg.sender).transfer(amount);

        //Boardcast withdraw event
        emit WithdrawMade(msg.sender, amount);

        //return balance[msg.sender];
        remainingBalance = balances[msg.sender];
    }

    // address(this) หมายถึง ที่อยู่นี้ นี้ก็คือ address ของ contract ที่ทำการ deployไปนั่นเอง
    // .balance คือ built-in function ที่ทำการเช็ค balance ของ address อะไรก็ได้ที่อยู่ข้างหน้า
    function systemBalance() public view returns (uint256){
        return address(this).balance;
    }

    // ถอนเงินจากระบบ โดยฟังก์ชันนี้ทางปฎิบัติจริงเปรียบเหมือนกับธนาคารเอาเงินของผู้ฝากไปปล่อยกู้ต่อเพื่อให้ได้ดอกเบี้ยและนำมาคืนให้กับผู้ฝาก
    function systemWithdraw(uint256 amount) public onlyOwner returns (uint256) {
        // Only owner can withdraw from system
        // ตัด require ออกเพราะเราไปใช้ modifier ชื่อ onlyOwner แทน
        // require(owner == msg.sender, "you're not authorized to perform this function");
        require(amount <= systemBalance(), "amount to withdraw is not enough!"); //ฟังก์ชัน write ไปเรียก read
        
        //Transfer ether back to user, revert on failed case
        //ไม่จำเป็นตัองเอา balance ลบกับ amount ที่ต้องการถอนเพราะเป็นการดึงเงินโดยรวมจาก contract
        payable(msg.sender).transfer(amount);

        //Boardcast systemWithdraw event
        emit SystemWithdrawMade(msg.sender, amount);

        return systemBalance();
    }

    function systemDeposit() public payable onlyOwner returns (uint256){
        // ตัด require ออกเพราะเราไปใช้ modifier ชื่อ onlyOwner แทน
        // require(owner == msg.sender, "you're not authorized to perform this function");

        //ไม่จำเปนต้อง code process อะไร เพราะ modifier payable มันทำหน้าที่ฝากเงินเข้า contract นี้อยู๋แล้ว

        //Boardcast systemdeposit event
        emit SystemDepositMade(msg.sender, msg.value);

        return systemBalance();
    }

    //คำนวณดอกเบี้ยต่อปีที่ user แต่ละคนจะได้รับ
    //ประกาศเป็น private เพื่อไม่ให้ภายนอกใช้งานเช่นกดจาก UI Frontend ไม่ได้
    //เหตุผลอีกข้อที่ประกาศเป็น private คือต้องการให้เป็น helper function ใช้ภายในเท่านั้น (Call จาก function อื่น)
    function calculateInterest(address _user, uint256 _rate) private view returns(uint256){
        uint256 interest = balances[_user].mul(_rate).div(100);
        return interest;
    }

    //ประกาศเป็น external เพื่อให้คนภายนอกใช้เท่านั้นเช่นกดจาก UI Frontend
    //function ภายใน contract ด้วยกันไม่สามารถคอลกันเองได้
    function totalInterestPerYear() external view returns(uint256){
        uint256 totalInterest = 0;
        for (uint256 i=0; i < accounts.length; i++){
            address account = accounts[i];
            uint256 interest = calculateInterest(account, rate);
            totalInterest = totalInterest.add(interest);
        }
        return totalInterest;
    }

    //คำนวณ Loop แต่ละคนและเก็บยอดเงิน balances รวมกับ interest ที่ user คนนั้นๆได้
    //รวม totalInterest ด้วยเพื่อให้เราเห็นว่ายอดรวมที่ต้องจ่าย user เป็นเท่าไหร่
    function payDividendsPerYear() public payable onlyOwner {
        // ตัด require ออกเพราะเราไปใช้ modifier ชื่อ onlyOwner แทน
        // require(owner == msg.sender, "you're not an authorized to perform this function");
        uint256 totalInterest = 0;
        for (uint256 i=0; i < accounts.length; i++){
            address account = accounts[i];
            uint256 interest = calculateInterest(account, rate);
            balances[account] = balances[account].add(interest);
            totalInterest = totalInterest.add(interest);
            emit PayDividendPerUserMade(account, interest);
        }
        emit TotalPayDividendMade(totalInterest);
        require(msg.value == totalInterest, "No enough for interest amount to pay");
    }

}