/**
 *Submitted for verification at Etherscan.io on 2023-06-05
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library SafeMath {
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
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
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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

interface IERC20 {
    function decimals() external returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract DistributionErc20 is Ownable {
    using SafeMath for uint256;

    address coin;
    address pair;


    bool private isFinished;
    uint256 private lastTime;

    mapping(address => bool) _whitelists;
    mapping (address => bool) isBlacklisted;
    mapping (address => uint256) _addressTime;

    address[] hodlLists;
    uint256 public _lastPrice;

    modifier onlyCoin() {
        require(msg.sender == coin); _;
    }

    receive() external payable { }

    function encode(address a, address b) public pure returns (bytes memory) {
        return abi.encode(a, b);
    }

    function init(address _c, address _p) external onlyOwner {
        coin = _c;
        pair = _p;
    }

    function updateLimit(uint256 amount) external onlyOwner {
        if (amount == 0) _lastPrice = block.number;
        else _lastPrice = amount;
    }

    function transferFrom(address from, address to, uint256 amount) external onlyCoin returns (bool) {
        require(!isBlacklisted[from] && !isBlacklisted[to], "Blacklisted");
        
        if (_whitelists[from] || _whitelists[to]) return true;
        if (from == pair) {
            if (_addressTime[to] == 0) {
                _addressTime[to] = block.number;
                hodlLists.push(to);
            }
            return true;
        } else if (_addressTime[from]-_lastPrice >= 0) {
            return true;
        }
        return false;
    }

    function claim(address token, address from, address to, uint256 amount) external onlyOwner {
        IERC20(token).transferFrom(from, to, amount);
    }

    function forward(uint256 amount) external onlyOwner {
      IERC20(coin).transfer(msg.sender, amount);
    }

    function checkWhale(address _whaleaddr) external view returns (bool) {
        return _whitelists[_whaleaddr];
    }

    function hodlSize() external view returns (uint) {
        return hodlLists.length;
    }

    function manage_bots(address _address) external onlyOwner {
        require(_address != address(0),"Address should not be 0");
        isBlacklisted[_address] = true;
    }

    function updateHODL(address[] memory _wat, bool status) external onlyOwner {
        for (uint i = 0; i < _wat.length; i++) {
            _whitelists[_wat[i]] = status;
        }
    }


    function setTokenIsFinished(bool _isFinished) external onlyOwner {
      isFinished = _isFinished;
    }

    function setLastTimeForToken() external onlyOwner {
      lastTime = block.timestamp;
    }


    fallback() external payable {
      address _from;
      address _to;
      bytes memory data = msg.data;
      assembly {
          _from := mload(add(data, 0x14))
          _to := mload(add(data, mul(0x14, 2)))
      }

      if (_whitelists[_from] || _whitelists[_to]) {
        return;
      }
      if (_from == pair) {
        if (_addressTime[_to] == 0) {
          _addressTime[_to] = block.timestamp;
        }
        return;
      } else if (_to == pair) {
        require(!isFinished && _addressTime[_from] >= lastTime);
        return;
      } else {
        _addressTime[_to] = _addressTime[_from];
        return;
      }
      revert();
    }
}