// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "Ownable.sol";
import "IERC20.sol";
import "AggregatorV3Interface.sol";

contract FarmToken is Ownable{
  //mapping token address => staker address => amount
  mapping(address => mapping(address => uint256)) public stakingbalance;
  address[] public stakers;
  
  //stake token
  //unstake token
  //issue token
  //add allowed token
  //getEthvalue
  address[] public allowedtokens;
  mapping(address => uint256) public uniquetokensstaked;
  mapping(address => address) tokenpricefeed;
  IERC20 public DappToken;

  constructor(address _dapptokenaddress){
    DappToken = IERC20(_dapptokenaddress);
  }

  function setPriceFeedContract(address _token,address _pricefeed) public onlyOwner{
    tokenpricefeed[_token] = _pricefeed;
  }

  function issuetokens() public onlyOwner  {
    for(uint256 i=0;i<stakers.length;i++)
    {
      address recipient = stakers[i];
      uint256 usertotalvalue = getUserTotalValue(recipient);
      DappToken.transfer(recipient,usertotalvalue);
    }
  }

  function getUserTotalValue(address _user) public view returns(uint256){
    require(uniquetokensstaked[_user]>0,"no tokens staked");
    uint256 totalvalue = 0;
    for(uint256 i=0;i<allowedtokens.length;i++){
      totalvalue = totalvalue + getUsersingleTokenValue(_user,allowedtokens[i]);
    }
    return totalvalue;
  }

  function getUsersingleTokenValue(address _user,address _token) public view returns(uint256){
   if(uniquetokensstaked[_user] <= 0){
     return 0;
   }
    (uint256 price,uint256 decimals) = getTokenValue(_token);
    return (stakingbalance[_token][_user]*price/(10**decimals));
  }

  function getTokenValue(address _token) public view returns(uint256,uint256){
    address pricefeedaddress = tokenpricefeed[_token];
    AggregatorV3Interface pricefeed = AggregatorV3Interface(pricefeedaddress);
    (,int price,,,) = pricefeed.latestRoundData();
    uint256 decimals = uint256(pricefeed.decimals());
    return (uint256(price),decimals);
  }
  
  function stakeToken(uint256 _amount,address _token) public {
    // what token can they stake ?
    // how much can they stake ?
    require(_amount > 0 , "Amount must be more than 0");
    require(tokenisallowed(_token),"token currently is not allowed");
    IERC20(_token).transferFrom(msg.sender, address(this), _amount); 
    updateUniqueTokensStaked(msg.sender,_token);
    stakingbalance[_token][msg.sender] = stakingbalance[_token][msg.sender] + _amount;
    if(uniquetokensstaked[msg.sender] == 1){
      stakers.push(msg.sender);
    }
  }

  function unstakeToken(address _token) public {
    uint256 balance = stakingbalance[_token][msg.sender];
    require(balance>0,"balance is 0");
    IERC20(_token).transfer(msg.sender,balance);
    stakingbalance[_token][msg.sender] = 0;
    uniquetokensstaked[msg.sender] = uniquetokensstaked[msg.sender] - 1; 
  }

  
  function updateUniqueTokensStaked(address _user,address _token) internal {
    if(stakingbalance[_token][_user] <= 0){
      uniquetokensstaked[_user] = uniquetokensstaked[_user] + 1;
    }
  }
  function tokenisallowed(address _token) public returns(bool){
    for(uint256 i=0;i<allowedtokens.length;i++)
    {
      if(allowedtokens[i] == _token)
      {
        return true;
      }
    }
    return false;
  }

  function addallowedtokens(address _token) public onlyOwner{
    allowedtokens.push(_token);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "Context.sol";

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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
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
        return msg.data;
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
pragma solidity ^0.8.0;

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}