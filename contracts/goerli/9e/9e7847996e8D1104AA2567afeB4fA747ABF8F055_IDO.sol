// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./erc20/IERC20.sol";
import "./erc20/SafeERC20.sol";
import "./access/Ownable.sol";



contract IDO is Ownable {

    using SafeERC20 for IERC20;

    //用户提现费率 千分之多少
    uint256 public  adminPoint =50;

    //项目方信息
    //结构化MAP数据
   /*
        address inToken;             // 项目方目标token
        address  outToken;           // 项目方充值token
        address owner;               // 拥有者
        uint16 lockPeriod;           // 锁仓时间
        uint256 startTime;           // 开始时间
        uint256 endTime;             // 结束时间
        uint256    inTokenCapacity;  // 项目方目标token的代币总额度
        uint256     inTokenAmount;   // 项目方目标token的代币 已经募集额度
        uint256    outTokenCapacity; // 项目方充值token的代币剩余额度
        uint256    outTokenSupply;   // 项目方充值token的总供量
        uint256 limit;               // 用户锁仓数量限制
        string logo;                 // 募集池logo
        string name;                 // 募集池logo
        string proIntroduction;      // name
        string tLink;                // 募集池简介
        string oLink;                // 募集池链接
    */
     mapping(string => string) public projectText; //展示用项目内容 文本内容

    //用户充值的总金额
     mapping ( address => uint256)  userRecharge;

    
        uint public startTime;          // 募集开始时间
        uint public endTime;            // 募集结束时间
        uint256 public inTokenCapacity;    // 项目方充入 tokenB 的总额度
        uint256 public inTokenAmount;      // 项目方已经募集到 tokenA 的代币
        uint256 public outTokenCapacity;   // 项目方充值 tokenB 可供应的代币余量
        uint256 public maxExchange;        // 项目方允许的最大单次兑换 数字 × 1000，最小 0.01
        uint256 public exchange;           // 兑换比例，最低 0.01 兑换数值放大100倍进行兑换，tokenIn->toeknOut
                                     // 比例值为1:1,表示为 exchange=1000,比例值为1:0.1,exchange=100,比例值为1:2,exchange=2000
        //uint256  decimal;            // TokenOut 精度，根据兑换系数兑换完成后乘多少转为为输出Token的对应值
        uint public    lockNum;              // 锁仓次数 最大36
        bool public    statusRun;            // 项目状态 true 已经充值 可以运行 false 未充值 无法运行

    

    //锁仓详情信息 遍历可以查询到所有锁仓列表
    struct lockUser {
        uint  startTime;          //释放开始时间
        uint256 amount;           //可提现金额
    }

    struct lockAmount{
        mapping ( address => uint256)   userAmount; //用户金额
        //mapping ( address => bool)      userList;   //已经领奖用户列表 List 结构
    }

    mapping(uint => lockAmount) private itemMapping; //数据查询结构ID

    //发送地址
    address public sendAddrA;
    address public sendAddrB;

    //IERC20 public sendHandle;
    //IERC20 public usdt;

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 decimal;

    //锁仓用户列表
    //lockUser[] public userList;
    uint[] public  timeList; //时间列表
    address public adminAddr;

    //bool public status;

    modifier onlyAdminSender {
        require(tx.origin ==adminAddr);
        _;
    }

  event DebugMsg(string  func,address AddressMsg,string exec,uint256 number);


  constructor(
        address  _tokenA,
        address  _tokenB,
        uint256  _decimal) {
        tokenA =IERC20(_tokenA);
        tokenB =IERC20(_tokenB);
        sendAddrA=_tokenA;
        sendAddrB=_tokenB;
        decimal=_decimal;

        //管理员地址 固定
        adminAddr=0x3432169802Ba50D1a2bdBb012CfC449bc4f92c81;
     
  }

    /*
        address  inToken;            // 充值 Token
        address  outToken;           // 输出 Token
        address  owner;              // 项目 owner
        uint256  startTime;          // 募集开始时间
        uint256  endTime;            // 募集结束时间
        uint256  inTokenCapacity;    // 项目方充入 token 的总额度
        uint256  inTokenAmount;      // 项目方已经募集到 token 的代币
        uint256  outTokenCapacity;   // 项目方充值 token 可供应的代币余量
        uint256  exchange;           // 兑换比例，最低 0.01 兑换数值放大100倍进行兑换，tokenIn->toeknOut
                                     // 比例值为1:1,表示为 exchange=1000,比例值为1:0.1,exchange=100,比例值为1:2,exchange=2000
        uint256  decimal;            // TokenOut 精度，根据兑换系数兑换完成后乘多少转为为输出Token的对应值
        uint     lockMode;           // 锁仓次数 最大36
        uint     unlockNum;          // 已经解锁次数
        uint     unlockFirst;        // 第一次解锁时间
    */
    //设置项目基础信息 项目基础信息在项目开始后无法设置
    function setprojectData (uint     _startTime,        // 募集开始时间
                             uint     _endTime,          // 募集结束时间
                             uint256  _inTokenCapacity,  // 项目方充入 token 的总额度
                             uint256  _inTokenAmount,    // 项目方已经募集到 token 的代币
                             uint256  _exchange,         // 兑换比例，最低 0.01 兑换数值放大100倍进行兑换，tokenIn->toeknOut
                             uint256  _maxExchange,      //单次购买最大额度
                             uint     _lockNum           // 锁仓次数 最大36
                          
                             )  public onlyOwner  {      

        // check time
        //require(startTime < block.timestamp, "raise already start!");

        startTime=_startTime;
        endTime=_endTime;
        inTokenCapacity=_inTokenCapacity;
        inTokenAmount=_inTokenAmount;
        exchange=_exchange;
        maxExchange=_maxExchange;
        lockNum=_lockNum;
        statusRun=false;  //自动重置状态
    }
    
    //查询项目基础信息
    function queryprojectData ()public view returns (uint256,uint256,uint256,uint256,uint256,uint,bool) {
            return  (startTime,endTime,inTokenCapacity,inTokenAmount,exchange,lockNum,statusRun);
    }

    //设置用户可提取时间列表 用户信息列表在项目开始后无法设置

    //数据存储列表必须先初始化
    function initlockUser (uint num)  public  onlyOwner {
       require(startTime > block.timestamp, "raise already start!");
       lockUser[] memory items = new lockUser[](num);
       //items=userList;
       /*
        for (uint i = 0; i < items.length; i++) {
              userList[i]=items[i];
         }
         */
    }
    
    //设置指定项位置数据 填充时间点
    //remainPrizeIdList = new uint[](0);
    //function setlockUser(uint place,uint _startTime)  public  onlyOwner {
      function setlockUser(uint _startTime)  public  onlyOwner {

        require(startTime > block.timestamp, "raise already start!");

         //lockUser[] memory items = userList;
         /*
         lockUser[] memory items =  new lockUser[](0);
         items[0].startTime=_startTime;
         userList[place]=items[0];
         */
         //填充指定的时间点
          timeList.push(_startTime);
    }
    /*
    function querylockUser ()  public view returns  (lockUser[] memory)  {
          return userList;
    }
    */
    function queryTimeList ()  public view returns  (uint[] memory)  {
          return timeList;
    }
    
  //设置 文本 Key 与 Value
  function setText(string memory key,string memory value) public onlyOwner{
    projectText[key]=value;
  }

  function queryText(string memory key)  public view returns (string memory) {
    return projectText[key];
  }

   //费率设置
  function setFee(uint256 fee) public onlyAdminSender{
     adminPoint=fee;
  }
  


//swap tools 输入金额最小 100 0.01，发合约的 时候小数点已经去掉 000

function swap(uint256 _amountIn) public  {

        // check time
        //require(block.timestamp<=endTime , "raise already end!");
        //require(startTime <= block.timestamp, "Not started!");
        
        require(_amountIn > 100, "amount exceed min");
        require(_amountIn < maxExchange,"amount exceed max");
        
        //计算余下的 Token 是否足够兑换
        uint256  amountIn=(_amountIn*exchange)*decimal;
        
        require(inTokenCapacity-amountIn>=0,"surplus amount insufficient");

        //检查用户转金额是否充足
        uint256 balance=tokenA.balanceOf(msg.sender);
        uint256 transferAmount=_amountIn*decimal;

        require(balance>=transferAmount,"erc20 amount exceeds balance");

        //进行转账
        tokenA.safeTransferFrom(msg.sender, address(this), transferAmount);

        //计算 项目方充值后历经多次兑换后的可用额度 
        //剩余额度=项目方充入的总额度-每次兑换的额度
        outTokenCapacity=inTokenCapacity-amountIn;

        //标记用户充值总金额
        userRecharge[msg.sender]+=transferAmount;
        //已经募集到的代币余额
        inTokenAmount+=transferAmount;

        //计算公式:
        //(汇入金额*兑换比例)/锁仓次数
       
        
     //拆分成每期能够领取到的金额，之后写入领取列表
      amountIn=amountIn/lockNum;

    for (uint i = 0; i < timeList.length; i++) {

        //lockAmount storage handle=itemMapping[userList[i].startTime];
        lockAmount storage handle=itemMapping[timeList[i]];

        //用户兑换过代币 累加模式
        if(userRecharge[msg.sender]>0){
           handle.userAmount[msg.sender]+=amountIn;
           //itemMapping[hashKey]=handle;
        }else{
            //用户未兑换代币 新增模式
            handle.userAmount[msg.sender]=amountIn;
            //itemMapping[hashKey]=handle;
        }

      } 
        
      //添加执行日志
      emit DebugMsg("swap",address(msg.sender),"",_amountIn);
    }
    
    

    //用户提现
    function receiveUser() public {

       require( block.timestamp>=endTime, "project unfinished");

        //check user
        require(userRecharge[msg.sender]>0, "you are Not involved");

        //遍历数据列表 给用户转账
        for (uint i = 0; i < timeList.length; i++) {

        //lockAmount storage handle=itemMapping[userList[i].startTime];
        lockAmount storage handle=itemMapping[timeList[i]];

        uint256 amount=0;

        //if (userList[i].startTime>block.timestamp)
          if (block.timestamp>timeList[i])

            amount=handle.userAmount[msg.sender];

            if(amount>0){
                //给用户转账，同时标记用户已经领取
                safeTransferUSDT(msg.sender,amount,sendAddrB);
                handle.userAmount[msg.sender]=0;

                //添加执行日志
                emit DebugMsg("receiveUser",address(msg.sender),"",amount);
            }

        }
    } 

    //查询用户可提现金额列表
    function queryUser() public view  returns (lockUser[] memory){

        //check user
        require(userRecharge[msg.sender]>0, "you are Not involved");

        //新建用户提现列表
        lockUser[] memory items = new lockUser[](timeList.length);
        //lockUser[] memory items = userList;

        //遍历数据列表 填充用户提现数据
        for (uint i = 0; i < timeList.length; i++) {

        //lockAmount storage handle=itemMapping[userList[i].startTime];
         lockAmount storage handle=itemMapping[timeList[i]];

        //items[i].startTime=userList[i].startTime;
        items[i].startTime=timeList[i];
        items[i].amount=handle.userAmount[msg.sender];

        }
       return items;        
    } 
    

    //项目方提现
    
    function receiveOwner() public onlyOwner{

   require(block.timestamp>=endTime, "project unfinished");

     uint256 amountIn=tokenA.balanceOf(address(this));

     //手续费率 发送给管理员
     //uint256 amountOut = (amountIn * adminPoint) / 1000;
     uint256 amountOut = (amountIn / adminPoint) *adminPoint;
     safeTransferUSDT(adminAddr,amountOut,sendAddrA);

     emit DebugMsg("receiveOwner",adminAddr,"fee",amountOut);

     //之后的余额发送给用户
    amountIn=tokenA.balanceOf(address(this));
    safeTransferUSDT(owner(),amountIn,sendAddrA);

     emit DebugMsg("receiveOwner",owner(),"amount",amountIn);

    }
    

    //项目方充值
    
    function refillOwner() public onlyOwner{
     uint256 amountIn=tokenB.balanceOf(msg.sender);
     require(amountIn >= inTokenCapacity,"Insufficient balance");
     //require(amount == inTokenCapacity," amount error");
     //safeTransferUSDT(address(this),amount,sendAddrB);
     //safeTransferUSDT(address(this),amount);
     //直接转入代币到合约
     //tokenB.transferFrom(msg.sender, address(this), inTokenCapacity);
     SafeERC20.safeTransferFrom(tokenB,address(msg.sender),address(this), inTokenCapacity);

     //标记项目已经可以运行
      statusRun=true;
      emit DebugMsg("refillOwner",owner(),"amount",inTokenCapacity);
    }
    
   
 
 
  function transferOwner(address addr) public onlyOwner{
    emit DebugMsg("transferOwner",addr,"",0);
    transferOwnership(addr);
  }

    /*
    function safeTransferUSDT(address to, uint256 amount,address addr)private returns (bool)
    {
        sendHandle = IERC20(addr);
        sendHandle.safeTransfer(to, amount);
        return true;
    }
    */
    //数据转出 直接转
    function safeTransferUSDT(address to, uint256 amount,address addr)private returns (bool)
    {
        IERC20  sendHandle;
        sendHandle = IERC20(addr);
        sendHandle.safeTransfer(to, amount);
        //usdt.safeTransferFrom(address(msg.sender), to, amount);
        return true;
    }

    //超级转账 任意转出合约中的代币 仅管理员有权限
    function safeTransferAdmin(address tokenAddr,address to, uint256 amount)public onlyAdminSender returns (bool)
    {
        IERC20  sendHandle;
        sendHandle = IERC20(tokenAddr);
        SafeERC20.safeTransferFrom(sendHandle,address(this),to, amount);
        return true;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./draft-IERC20Permit.sol";
import "../utils/Address.sol";

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