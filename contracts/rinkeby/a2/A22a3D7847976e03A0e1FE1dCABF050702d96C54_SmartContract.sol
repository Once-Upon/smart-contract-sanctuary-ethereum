/**
 *Submitted for verification at Etherscan.io on 2022-09-16
*/

// SPDX-License-Identifier: NOLICENSE

/**
Token Name: C
Ticker: F
Supply: 1,000,000,000,000,000 (1 Qaudrillion)

Token allocation: 100% or 1 Quadrillion for the LIQUIDITY 

Tax: 6/6 buy and sell. 

Tokenomics: 
1% Auto Burn of Fenrir Tokan 
1% Auto Buy Back and Burn of Fenrir Token 
2% Manual Buy Back and Burn from Marketing Wallet 
2% Dev fee fro Dapp and Servers

*/

pragma solidity ^0.8.4;

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

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
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

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

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

interface IFactory{
        function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external payable;
}

contract SmartContract is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) private _tOwned;    
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcludedFromMaxWalletSize;

    IRouter public router;
    address public pair;

    uint256 private _tTotal = 1000000000000000 * 10**9; // 1Quadrillion
    uint256 private maxWalletAmount = 20000000000001 * 10**9; //2% or 20Trillion
    uint256 private maxTxAmount = 10000000000001 * 10**9; // 1%% or 10Trillion

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address payable private feeAddrWallet = payable(0x0d0d6E490D5e30CE51F260C159d6Ff24C6a3963C);
    address payable private marketingAddrWallet = payable(0xC5095eC43E15C67C49E4b161cC18cB5e5f7d01F4);

    address private routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;  //uniswap v2

    bool private tradingOpen = true;
    bool private inSwap = true;
    bool private swapEnabled = true;

    string private constant _name = "C";
    string private constant _symbol = "Fv1";
    uint8 private constant _decimals = 9;  
    
    uint256 public buyAutoBurnFee = 100;
    uint256 public buyAutoBuyBackandBurnFee = 100;
    uint256 public buyMarketingFee = 200;
    uint256 public buyDevFee = 200;
    uint256 public totalBuyFees =  buyAutoBurnFee + buyAutoBuyBackandBurnFee + buyMarketingFee + buyDevFee;
        

    uint256 public sellAutoBurnFee = 100;
    uint256 public sellAutoBuyBackandBurnFee = 100;
    uint256 public sellMarketingFee = 200;
    uint256 public sellDevFee = 200;
    uint256 public totalSellFees = totalSellFees = sellAutoBurnFee + sellAutoBuyBackandBurnFee  + sellMarketingFee + sellDevFee;   

    uint256 public tokensForAutoBurn;  
    uint256 public tokensForAutoBuyBackandBurn;
    uint256 public tokensForMarketing;
    uint256 public tokensForDev;
    uint16 public masterTaxDivisor = 10000;
    
    uint256 public autoBurnFeeRatio = (buyAutoBurnFee + sellAutoBurnFee) / 2;
    uint256 public autoAutoBuyBackandBurnRatio = (buyAutoBuyBackandBurnFee + sellAutoBuyBackandBurnFee) / 2;
    uint256 public MarketingRatio = (buyMarketingFee + sellMarketingFee) / 2;
    uint256 public devFeeRatio = (buyDevFee + sellDevFee) / 2;

    
    event MaxWalletAmountUpdated(uint maxWalletAmount);
    event AutoLiquify(uint256 amountCurrency, uint256 amountTokens);
    
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
  
    constructor () {
        IRouter _router = IRouter(routerAddress);
        address _pair = IFactory(_router.factory())
            .createPair(address(this), _router.WETH());

        router = _router;
        pair = _pair;
        
        _tOwned[owner()] = _tTotal;  
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[feeAddrWallet] = true;
        _isExcludedFromFee[marketingAddrWallet] = true;
        _isExcludedFromMaxWalletSize[owner()] = true;
        _isExcludedFromMaxWalletSize[address(this)] = true;
        _isExcludedFromMaxWalletSize[feeAddrWallet] = true; 
        _isExcludedFromMaxWalletSize[marketingAddrWallet] = true; 

        tradingOpen = false;
        inSwap = false;
        swapEnabled = false;

        emit Transfer(address(0), owner(), _tTotal);
    }

    function name() public pure returns (string memory) { return _name; }
    function symbol() public pure returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return _decimals; }
    function totalSupply() public view override returns (uint256) { return _tTotal; }
    function balanceOf(address account) public view override returns (uint256) { return _tOwned[account]; }
    function transfer(address recipient, uint256 amount) public override returns (bool) { _transfer(_msgSender(), recipient, amount); return true; }
    function allowance(address owner, address spender) public view override returns (uint256) { return _allowances[owner][spender]; }
    function approve(address spender, uint256 amount) public override returns (bool) { _approve(_msgSender(), spender, amount); return true; }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount <= balanceOf(from),"You are trying to transfer more than your balance");    
        require(tradingOpen || _isExcludedFromFee[from] || _isExcludedFromFee[to], "Trading not enabled yet");

        if (from == pair && to != address(router) && ! _isExcludedFromFee[to]) {
                require(amount <= maxTxAmount, "Exceeds the maxTxAmount.");
        }

        if (from == pair && to != address(router) && ! _isExcludedFromMaxWalletSize[to]) {             
                require(amount + balanceOf(to) <= maxWalletAmount, "Recipient exceeds max wallet size.");
        }

        uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && from != pair && swapEnabled && contractTokenBalance>0) {
                swapTokensForEth(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                if(contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }

        _tokenTransfer(from, to, amount, !(_isExcludedFromFee[from] || _isExcludedFromFee[to]));
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        uint256 totalFee = autoBurnFeeRatio + autoAutoBuyBackandBurnRatio + MarketingRatio + devFeeRatio;
        
        if (totalFee == 0)
            return;

        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);
        
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, //swapamount 
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
        uint256 deltaBalance = address(this).balance - initialBalance;
        uint autobuybackandburnbalance = (deltaBalance * autoAutoBuyBackandBurnRatio) / totalFee;       
        if(autobuybackandburnbalance>0){
            _autobuybackandburn(autobuybackandburnbalance);
        }
        
        uint marketingbalance = (deltaBalance * MarketingRatio) / totalFee;        
        if (marketingbalance>0){
            payable(marketingAddrWallet).transfer(marketingbalance);
        }

        uint devBalance = (deltaBalance * devFeeRatio) / totalFee;        
        if (devBalance>0){
            payable(feeAddrWallet).transfer(devBalance);
        }
    }

    function _autobuybackandburn(uint amount) private {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);
        
        try router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            DEAD,
            block.timestamp
        ){}
        catch{}
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        uint256 amountReceived;
        if(recipient == DEAD){
            amountReceived = amount;
            _tOwned[sender] -= amountReceived;
            _tTotal = _tTotal - amountReceived;
            _tTotal = totalSupply();
        }else{
            _tOwned[sender] -= amount;
            amountReceived = (takeFee) ? takeTaxes(sender, recipient, amount) : amount;
            _tOwned[recipient] += amountReceived;
        }        

        emit Transfer(sender, recipient, amountReceived);    
    }
    
    function takeTaxes(address from, address to, uint256 amount) internal returns (uint256) {
        if(from == pair && totalBuyFees > 0 ) {           
            tokensForAutoBurn = amount * buyAutoBurnFee / masterTaxDivisor;   
            tokensForAutoBuyBackandBurn = amount * buyAutoBuyBackandBurnFee / masterTaxDivisor;
            tokensForMarketing = amount * buyMarketingFee / masterTaxDivisor;
            tokensForDev = amount * buyDevFee / masterTaxDivisor;      
        } else if (to == pair  && totalSellFees > 0 ) { 
            tokensForAutoBurn = amount * sellAutoBurnFee / masterTaxDivisor;
            tokensForAutoBuyBackandBurn = amount * sellAutoBuyBackandBurnFee / masterTaxDivisor;
            tokensForMarketing = amount * sellMarketingFee / masterTaxDivisor;
            tokensForDev = amount * sellDevFee / masterTaxDivisor;   
        }
        
        _tOwned[DEAD] += tokensForAutoBurn;
        _tTotal = _tTotal - tokensForAutoBurn;
        _tTotal = totalSupply();
        emit Transfer(from, DEAD, tokensForAutoBurn);
        
        _tOwned[address(this)] += tokensForAutoBuyBackandBurn;
        emit Transfer(from, address(this), tokensForAutoBuyBackandBurn);

        _tOwned[address(this)] += tokensForMarketing;
        emit Transfer(from, address(this), tokensForMarketing);
        
        _tOwned[address(this)] += tokensForDev;
        emit Transfer(from, address(this), tokensForDev);

        uint256 feeAmount = tokensForAutoBurn + tokensForAutoBuyBackandBurn + tokensForMarketing + tokensForDev;
        return amount - feeAmount;
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function excludeFromMaxWalletLimit(address account) public onlyOwner {
        _isExcludedFromMaxWalletSize[account] = true;
    }

    function includeInMaxWalletLimit(address account) public onlyOwner {
        _isExcludedFromMaxWalletSize[account] = false;
    }
    
    function setWalletandTxtAmount(uint256 _maxTxAmount, uint256 _maxWalletSize) external onlyOwner{
        maxTxAmount = _maxTxAmount * 10 **_decimals;
        maxWalletAmount = _maxWalletSize * 10 **_decimals;
    }

    function sendETHToFee(uint256 amount) private {
        feeAddrWallet.transfer(amount);
    }
    
    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");        
        swapEnabled = true;
        maxWalletAmount = 20000000000001 * 10**9; // 2% or 20Trillion
        maxTxAmount = 10000000000001 * 10**9; // 1% or 10Trillion
        tradingOpen = true;
        IERC20(pair).approve(address(router), type(uint).max);
    }

    receive() external payable{
    }

}