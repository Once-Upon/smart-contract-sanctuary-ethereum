/**
 *Submitted for verification at Etherscan.io on 2023-01-19
*/

/**

THE WAR
Long ago, in a realm known as Etheria, lived 8888 Knights in harmony. Each Knight had their place in Etheria with a common goal to unite the realm against those whom sought to destroy it and keep the power equal among all the knights.
​
However, malicious intent soon grew among some of the Knights within the realm. They yearned for chaos and soon joined together to become known as the Realm Lords.
​
The Realm Lords had but one goal. Destroy the peace the other Knights fought so hard to achieve and lay claim to all of Etheria for themselves. The Knights laid siege to the kingdoms the lords had took domain over, but it was to no avail. The lords came across a form of dark magic once thought gone in Etheria. They combined their new powers and cast a spell upon of Etheria ripping the souls from the Knights, plunging the realm into darkness and decay. The Knights were under the control of the Lords. 
​
With Etheria under centralized control, all hope was lost.
It wasn't until the common folk and citizens of the realm had enough of the centralized rule. They sought out magic that could help reverse the dark magic and bring the soul and life back to the Knights. 

https://t.me/EthereumKnights

*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {return a + b;}
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {return a - b;}
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {return a * b;}
    function div(uint256 a, uint256 b) internal pure returns (uint256) {return a / b;}
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {return a % b;}
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {uint256 c = a + b; if(c < a) return(false, 0); return(true, c);}}
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {if(b > a) return(false, 0); return(true, a - b);}}
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {if (a == 0) return(true, 0); uint256 c = a * b;
        if(c / a != b) return(false, 0); return(true, c);}}
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {if(b == 0) return(false, 0); return(true, a / b);}}
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {if(b == 0) return(false, 0); return(true, a % b);}}
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked{require(b <= a, errorMessage); return a - b;}}
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked{require(b > 0, errorMessage); return a / b;}}
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked{require(b > 0, errorMessage); return a % b;}}}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);}

abstract contract Ownable {
    address internal owner;
    constructor(address _owner) {owner = _owner;}
    modifier onlyOwner() {require(isOwner(msg.sender), "!OWNER"); _;}
    function isOwner(address account) public view returns (bool) {return account == owner;}
    function transferOwnership(address payable adr) public onlyOwner {owner = adr; emit OwnershipTransferred(adr);}
    event OwnershipTransferred(address owner);
}

interface IZODIAC {
    function distributeZodiac(uint256 previousBalance) external;
    function currentBalance() external view returns (uint256);
}

interface IFactory{
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
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

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external;
}

// File: ETHKnights.sol



pragma solidity 0.8.15;


contract EthereumKnights is IERC20, Ownable {
    using SafeMath for uint256;
    string private constant _name = 'Ethereum Knights';
    string private constant _symbol = 'ETH Knights';
    uint8 private constant _decimals = 9;
    uint256 private _totalSupply = 1 * 10**8 * (10 ** _decimals);
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public _maxTxAmount = ( _totalSupply * 200 ) / 10000;
    uint256 public _maxWalletToken = ( _totalSupply * 400 ) / 10000;
    mapping (address => uint256) _balances;
    mapping(address => bool) isFeeExempt;
    mapping (address => mapping (address => uint256)) private _allowances;
    IRouter router;
    address public pair;
    uint256 liquidityFee = 100;
    uint256 tokenFee = 200;
    uint256 zodiacFee = 200;
    uint256 totalFee = 2000;
    uint256 sellFee = 2000;
    uint256 transferFee = 0;
    uint256 feeDenominator = 10000;
    bool swapEnabled = true;
    bool tradingAllowed = false;
    address liquidity;
    address zodiac;
    IZODIAC hub;
    uint256 swapThreshold = ( _totalSupply * 900 ) / 100000;
    uint256 minSwapAmount = ( _totalSupply * 20 ) / 100000;
    modifier isSwap {swapping = true; _; swapping = false;}
    uint256 swapAmount; 
    bool swapping;

    constructor() Ownable(msg.sender) {
        IRouter _router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        address _pair = IFactory(_router.factory()).createPair(address(this), _router.WETH());
        router = _router;
        pair = _pair;
        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
        liquidity = msg.sender;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function name() public pure returns (string memory) {return _name;}
    function symbol() public pure returns (string memory) {return _symbol;}
    function decimals() public pure returns (uint8) {return _decimals;}
    function getOwner() external view override returns (address) {return owner; }
    function totalSupply() public view override returns (uint256) {return _totalSupply;}
    function balanceOf(address account) public view override returns (uint256) {return _balances[account];}
    function transfer(address recipient, uint256 amount) public override returns (bool) {_transfer(msg.sender, recipient, amount);return true;}
    function allowance(address owner, address spender) public view override returns (uint256) {return _allowances[owner][spender];}
    function approve(address spender, uint256 amount) public override returns (bool) {_approve(msg.sender, spender, amount);return true;}
    function getCirculatingSupply() public view returns (uint256) {return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(address(0)));}

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        checkValidTrade(sender, recipient, amount);
        checkStartTrading(sender, recipient);
        checkMaxWallet(sender, recipient, amount);
        swapbackCounters(sender, recipient);
        checkTxLimit(sender, recipient, amount);
        swapBack(sender, recipient, amount);
        _balances[sender] = _balances[sender].sub(amount);
        uint256 amountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, recipient, amount) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);
        emit Transfer(sender, recipient, amountReceived);
    }

    function checkValidTrade(address sender, address recipient, uint256 amount) internal view {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount <= balanceOf(sender),"You are trying to transfer more than your balance");
    }

    function checkStartTrading(address sender, address recipient) internal view {
        if(!isFeeExempt[sender] && !isFeeExempt[recipient]){require(tradingAllowed, "startSwap");}
    }
    
    function checkMaxWallet(address sender, address recipient, uint256 amount) internal view {
        if(!isFeeExempt[sender] && !isFeeExempt[recipient] && recipient != address(DEAD) && recipient != pair){ 
            require((_balances[recipient].add(amount)) <= _maxWalletToken, "Exceeds maximum wallet amount.");}
    }

    function swapbackCounters(address sender, address recipient) internal {
        if(recipient == pair && !isFeeExempt[sender]){swapAmount = swapAmount.add(1);}
    }

    function shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        return !isFeeExempt[sender] && !isFeeExempt[recipient];
    }

    function getTotalFee(address sender, address recipient) internal view returns (uint256) {
        if(recipient == pair){return sellFee;}
        if(sender == pair){return totalFee;}
        return transferFee;
    }

    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        if(getTotalFee(sender, recipient) > 0){  
        uint256 feeAmount = amount.div(feeDenominator).mul(getTotalFee(sender, recipient));
        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount); 
        _transfer(address(this), address(zodiac), amount.div(feeDenominator).mul(tokenFee)); 
        return amount.sub(feeAmount);} return amount;
    }

    function checkTxLimit(address sender, address recipient, uint256 amount) internal view {
        require(amount <= _maxTxAmount || isFeeExempt[sender] || isFeeExempt[recipient], "TX Limit Exceeded");
    }

    function startTrading(address _zodiac, address _liquidity, address _staking) external onlyOwner {
        liquidity = _liquidity;
        zodiac = _zodiac;
        hub = IZODIAC(_zodiac);
        isFeeExempt[_liquidity] = true;
        isFeeExempt[_zodiac] = true;
        isFeeExempt[_staking] = true;
        tradingAllowed = true;
    }

    function shouldSwapBack(address sender, address recipient, uint256 amount) internal view returns (bool) {
        bool aboveMin = amount >= minSwapAmount;
        bool canSwap = balanceOf(address(this)) >= swapThreshold;
        return !swapping && swapEnabled && aboveMin && !isFeeExempt[sender]
            && !isFeeExempt[recipient] && swapAmount >= 1 && canSwap;
    }

    function swapBack(address sender, address recipient, uint256 amount) internal {
        if(shouldSwapBack(sender, recipient, amount)){swapAndLiquify(swapThreshold); swapAmount = 0;}
    }

    function swapAndLiquify(uint256 tokens) private isSwap {
        uint256 denominator = zodiacFee.mul(2).add(tokenFee).add(liquidityFee).mul(2);
        uint256 tokensToAddLiquidityWith = tokens.mul(liquidityFee).div(denominator);
        uint256 toSwap = tokens.sub(tokensToAddLiquidityWith);
        uint256 initialBalance = address(this).balance;
        swapTokensForETH(toSwap);
        uint256 deltaBalance = address(this).balance.sub(initialBalance);
        uint256 unitBalance= deltaBalance.div(denominator.sub(liquidityFee));
        uint256 ETHToAddLiquidityWith = unitBalance.mul(liquidityFee);
        uint256 zBalance = hub.currentBalance();
        if(ETHToAddLiquidityWith > 0){
            addLiquidity(tokensToAddLiquidityWith, ETHToAddLiquidityWith);}
        if(unitBalance.mul(2).mul(zodiacFee) > 0){
            payable(zodiac).transfer(unitBalance.mul(2).mul(zodiacFee)); 
            hub.distributeZodiac(zBalance);}
        if(address(this).balance > 0){payable(liquidity).transfer(address(this).balance);}
    }

    function addLiquidity(uint256 tokenAmount, uint256 ETHAmount) private {
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: ETHAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidity,
            block.timestamp);
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp);
    }
}