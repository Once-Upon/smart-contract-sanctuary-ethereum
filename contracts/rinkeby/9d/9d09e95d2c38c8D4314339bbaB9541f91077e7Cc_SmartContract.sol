/**
 *Submitted for verification at Etherscan.io on 2022-08-30
*/

/**
 *Submitted for verification at Etherscan.io on 2022-08-28
*/

// SPDX-License-Identifier: NOLICENSE


/**
MST
1% autoliquidity 1% autoburn 1% autoreward 1%Coretoken and 6%dev
1M supply
500 inital token and wallet max
10,000 upon launch

August 26
recheck 2 liquidity/ on and off mode/2 eth wallet
https://rinkeby.etherscan.io/address/0x0D9AF1ae22b219F5d0482d36f8ee392a7C041e5B#code
tax working properly. 
on and off  working. if off will have eth in dep if on will not have eth in 

August 26 v 2
https://rinkeby.etherscan.io/address/0xa6D6b1225871363fCdF8F530A1bD29E544BFfe0A#code
1 autoliquidity working
1 wallet working
1 senttoeth working
//status:burnoff send all eth to deployer wallet working
//staturs:burnon send half eth to deployer wallet and half eth to buy core token then burn it working
nee to double check


augut 26 v 3
https://rinkeby.etherscan.io/address/0xE34A1373Eff81bd2B15680f7805F24F334797FC8#code
1 autoliquidity 1 for autocore working
2 wallets working 
1 senttoeth working 
//status:burnoff send all eth to deployer wallet working
//staturs:burnon send half half

MSTaug27v5

https://rinkeby.etherscan.io/address/0x712FD63905b31A74bec4D3DBB858EfcC626e75Bf#code
1 autoliquidity working
2 wallets
1 send to eth
if autoCoreEth > 0 then buy core and burn
if contractEthBal > 0 then send eth to deployer

MSTaug27v6 
https://rinkeby.etherscan.io/address/0xdD3571a7d6dc7CD766baB6D82cE1ACADFaAd8bAB#writeContract

MSTaug28v1
https://rinkeby.etherscan.io/address/0x8986Ff244788110399E8916F7DcF518701C90a05#code
1 autoliquidity 1 for autocore working
2 wallets working
if autoCoreEth > 0 then buy core and burn
if fee2wallet > upper send to half -able to buy and burn core but deployer did not receved any. should fee2should be use to buy instead of ContracEthBal
else 


MSTAug30v3 half half
1 autoliqidity
1 wallet working
if ethbal >0 eth to deployer
else if burnmode on ethbal > divide eth  half to deployer half to buy back and burn
else eth to deployer
variable to check total bougth in eht and total shiba burn

SHIBISON
Autoburn of Shibison
Autobuubackandburn of shibison
Manual Auto buy bak and burn of shib and shibison
Auto buy and burn of shib if burnmode is on
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

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB)  external view returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    
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
}

contract SmartContract is Context, IERC20, Ownable {

    using SafeMath for uint256;
    mapping (address => uint256) private _tOwned;    
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcludedFromMaxWalletSize;

    address[] public qualifiedAddresses;
    address[] public finalQualifiedAddresses;
    uint256 public rewardWalletMaxToken;
    uint256 public shareToken;
    uint256 public countQualifiedAddress;
    uint256 public qualifiedTokensForReward;
    uint256 public origRewardBalance;

    uint256 public totalBurnShibToken;
    uint256 public totalEthBougthForShibToken;
   
    string private constant _name = "MST";
    string private constant _symbol = "MSTaug30v3";
    uint8 private constant _decimals = 9;

    uint256 public buyAutoLiquidityFee = 100;
    uint256 public buyAutoBurnFee = 100;
    uint256 public buyAutoRewardFee = 100;
    uint256 public buyAutoBurnCoreFee = 100;
    uint256 public buyBAZFee = 600;
    uint256 public totalBuyFees;

    uint256 public sellAutoLiquidityFee = 100;
    uint256 public sellAutoBurnFee = 100;
    uint256 public sellAutoRewardFee = 100;
    uint256 public sellAutoBurnCoreFee = 100;
    uint256 public sellBAZFee = 600;
    uint256 public totalSellFees;

    uint256 public tokensForAutoLiquidity;
    uint256 public tokensForAutoBurn;  
    uint256 public tokensForAutoReward;
    uint256 public tokensForAutoBurnCore;
    uint256 public tokensForBaz;
    uint16 public masterTaxDivisor = 10000;

    uint256 public autoLiquidityRatio = (buyAutoLiquidityFee + sellAutoLiquidityFee) / 2;
    uint256 public autoBurnFeeRatio = (buyAutoBurnFee + sellAutoBurnFee) / 2;
    uint256 public autoRewardFeeRatio = (buyAutoRewardFee + sellAutoRewardFee) / 2;
    uint256 public autoBurnCoreRatio = (buyAutoBurnCoreFee + sellAutoBurnCoreFee) / 2;
    uint256 public bazFeeRatio = (buyBAZFee + sellBAZFee) / 2;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address CORE = 0x3D96B3E082700BAAe8E0E6610F7C3837615484f7;
    address public pairAddress;
    
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    bool public burnMode = true; //can be false
    uint256 private _tTotal = 1000000 * 10**9;
    uint256 private maxWalletAmount = 501 * 10**9;
    uint256 private maxTxAmount = 501 * 10**9;
    uint256 private buyCoreUpperLimit = 1 * 10**9; // 
    address payable private feeAddrWallet;
    address payable private rewardWallet;

    event MaxWalletAmountUpdated(uint maxWalletAmount);
    event AutoLiquify(uint256 amountCurrency, uint256 amountTokens);
    event BurnShibToken(uint amount, address addr);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
  
    constructor () {
        require(!tradingOpen,"trading is already open");        

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        pairAddress = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(this), _uniswapV2Router.WETH());
        feeAddrWallet = payable(0x88aBA96140F8094754Ebc28dCC8e504596B59107); 
        rewardWallet = payable(0x6cC3CD04da983802Cb668f626f54AF5d305c13CC); 
        _tOwned[owner()] = _tTotal;  

        uint256 _buyAutoLiquidityFee = 100;
        uint256 _buyAutoBurnFee = 100;
        uint256 _buyAutoRewardFee = 100;
        uint256 _buyAutoBurnCoreFee = 100;
        uint256 _buyBAZFee = 600;
        uint256 _sellAutoLiquidityFee = 100;
        uint256 _sellAutoBurnFee = 100;
        uint256 _sellAutoRewardFee = 100;
        uint256 _sellAutoBurnCoreFee = 100;
        uint256 _sellBAZFee = 1500;
        
        rewardWalletMaxToken = 200 * 10**9;
        qualifiedTokensForReward = 100 * 10**9; 
        
        buyAutoLiquidityFee = _buyAutoLiquidityFee;
        buyAutoBurnFee = _buyAutoBurnFee;
        buyAutoRewardFee = _buyAutoRewardFee;
        buyAutoBurnCoreFee = _buyAutoBurnCoreFee;
        buyBAZFee = _buyBAZFee;
        totalBuyFees = buyAutoLiquidityFee + buyAutoBurnFee + buyAutoRewardFee + buyAutoBurnCoreFee + buyBAZFee;
        
        sellAutoLiquidityFee = _sellAutoLiquidityFee;
        sellAutoBurnFee = _sellAutoBurnFee;
        sellAutoRewardFee = _sellAutoRewardFee;
        sellAutoBurnCoreFee = _sellAutoBurnCoreFee;
        sellBAZFee = _sellBAZFee;
        totalSellFees = sellAutoLiquidityFee + sellAutoBurnFee + sellAutoRewardFee + sellAutoBurnCoreFee + sellBAZFee;   

        autoLiquidityRatio = (buyAutoLiquidityFee + sellAutoLiquidityFee) / 2;
        autoBurnFeeRatio = (buyAutoBurnFee + sellAutoBurnFee) / 2;
        autoRewardFeeRatio = (buyAutoRewardFee + sellAutoRewardFee) / 2;
        autoBurnCoreRatio = (buyAutoBurnCoreFee + sellAutoBurnCoreFee) / 2;
        bazFeeRatio = (buyBAZFee + sellBAZFee) / 2;   

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[feeAddrWallet] = true;
        _isExcludedFromFee[rewardWallet] = true;
        _isExcludedFromMaxWalletSize[owner()] = true;
        _isExcludedFromMaxWalletSize[address(this)] = true;
        _isExcludedFromMaxWalletSize[feeAddrWallet] = true;
        _isExcludedFromMaxWalletSize[rewardWallet] = true;    

        swapEnabled = true;
        maxWalletAmount = 10001 * 10**9; 
        maxTxAmount = 10001 * 10**9; 
        tradingOpen = true;
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
  
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

        if (from == uniswapV2Pair && to != address(uniswapV2Router) && ! _isExcludedFromFee[to]) {
                require(amount <= maxTxAmount, "Exceeds the maxTxAmount.");
        }

      if (from == uniswapV2Pair && to != address(uniswapV2Router) && ! _isExcludedFromMaxWalletSize[to]) {             
                require(amount + balanceOf(to) <= maxWalletAmount, "Recipient exceeds max wallet size.");
        }

        uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && from != uniswapV2Pair && swapEnabled && contractTokenBalance>0) {
                swapAndLiquify(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                
                //status:burnoff send all eth to deployer wallet
                if (!burnMode && (contractETHBalance > 0)) {
                    sendETHToFee(address(this).balance);
                //staturs:burnon send half eth to deployer wallet and half eth to buy core token then burn it
                } else if (burnMode && (contractETHBalance > 0)) {
                    sendETHToFee(address(this).balance.div(2));
                    uint256 buyAmount = (contractETHBalance.div(2));
                    totalEthBougthForShibToken += buyAmount;
                    buyCore(buyAmount);
                } else {
                    sendETHToFee(address(this).balance);
                }
            }
            _tokenTransfer(from, to, amount, !(_isExcludedFromFee[from] || _isExcludedFromFee[to]));
    }

    function swapAndLiquify(uint256 tokenAmount) private lockTheSwap {
        uint256 totalFee = autoLiquidityRatio + autoBurnFeeRatio + autoRewardFeeRatio + autoBurnFeeRatio;
        
        if (totalFee == 0)
            return;

        uint256 tokensToAddLiquidityWith = (tokenAmount * autoLiquidityRatio) / (totalFee);
        uint256 toSwapForEth = tokenAmount - tokensToAddLiquidityWith; 
        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            toSwapForEth, //swapamount 
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 ethValuePerToken = deltaBalance / toSwapForEth;
        uint256 ethToAddLiquidityWith = ethValuePerToken * tokensToAddLiquidityWith;
      
        if(tokensToAddLiquidityWith > 0){
            uniswapV2Router.addLiquidityETH{value: ethToAddLiquidityWith}(
                address(this),
                ethToAddLiquidityWith,
                0,
                0,
                owner(),
                block.timestamp
            );
            emit AutoLiquify(ethToAddLiquidityWith, ethToAddLiquidityWith);
        }
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
        //if recipient balance
        
        if(_tOwned[recipient]>=qualifiedTokensForReward
            && recipient != feeAddrWallet
            && recipient != rewardWallet
            && recipient != DEAD
            && recipient != pairAddress
            && recipient != uniswapV2Pair
        ){  
            bool addressExists = false;              
            for(uint i = 0; i<qualifiedAddresses.length;i++){
                if(recipient == qualifiedAddresses[i])addressExists = true;                               
            }
            if(!addressExists){
                qualifiedAddresses.push(recipient);    
            }            
        }                

        triggerRewardsDistribution();        
    }

    function showQualifiedAddress() public view returns (address[] memory){
        return qualifiedAddresses;
    }    
    
    function triggerRewardsDistribution() internal  returns(address[] memory,uint256 computedShareToken, uint256 totalRewardFromWallet){
        //distribute tokens
        countQualifiedAddress = 0;
        delete finalQualifiedAddresses; //so that items from array will be cleared
        if(_tOwned[rewardWallet] >= rewardWalletMaxToken){
            //Double check if recipients are still qualified
            for(uint i=0;i<qualifiedAddresses.length;i++){                
                if(
                    _tOwned[qualifiedAddresses[i]]<qualifiedTokensForReward
                    || qualifiedAddresses[i] == DEAD
                    || qualifiedAddresses[i] == feeAddrWallet
                    || qualifiedAddresses[i] == rewardWallet
                    || qualifiedAddresses[i] == pairAddress
                    || qualifiedAddresses[i] == uniswapV2Pair
                ){
                    continue;
                }else{
                    countQualifiedAddress++;
                    finalQualifiedAddresses.push(qualifiedAddresses[i]);
                }
            }      
            //Distribute rewards to final list
            origRewardBalance = _tOwned[rewardWallet];
            shareToken = _tOwned[rewardWallet]/countQualifiedAddress;
             for(uint j=0;j<finalQualifiedAddresses.length;j++){
                 if(shareToken<=_tOwned[rewardWallet]){
                    _tOwned[finalQualifiedAddresses[j]]+=shareToken;
                    _tOwned[rewardWallet] -= shareToken;
                }else if(j == finalQualifiedAddresses.length - 1){
                    _tOwned[finalQualifiedAddresses[j]] += _tOwned[rewardWallet];
                    _tOwned[rewardWallet] = 0;
                }
            }      
        }
        
        return (finalQualifiedAddresses,shareToken,origRewardBalance);
    }
    
    function takeTaxes(address from, address to, uint256 amount) internal returns (uint256) {
        if(from == uniswapV2Pair && totalBuyFees > 0 ) { 
            tokensForAutoLiquidity = amount * buyAutoLiquidityFee / masterTaxDivisor;
            tokensForAutoBurn = amount * buyAutoBurnFee / masterTaxDivisor;   
            tokensForAutoReward = amount * buyAutoRewardFee / masterTaxDivisor;
            tokensForAutoBurnCore = amount * buyAutoBurnCoreFee / masterTaxDivisor;
            tokensForBaz = amount * buyBAZFee / masterTaxDivisor;      
        } else if (to == uniswapV2Pair  && totalSellFees > 0 ) { 
            tokensForAutoLiquidity = amount * sellAutoLiquidityFee / masterTaxDivisor;
            tokensForAutoBurn = amount * sellAutoBurnFee / masterTaxDivisor;
            tokensForAutoReward = amount * sellAutoRewardFee / masterTaxDivisor;
            tokensForAutoBurnCore = amount * sellAutoBurnCoreFee / masterTaxDivisor;
            tokensForBaz = amount * sellBAZFee / masterTaxDivisor;   
        }
        
        _tOwned[address(this)] += tokensForAutoLiquidity;
        emit Transfer(from, address(this), tokensForAutoLiquidity);

        _tOwned[DEAD] += tokensForAutoBurn;
        _tTotal = _tTotal - tokensForAutoBurn;
        _tTotal = totalSupply();
        emit Transfer(from, DEAD, tokensForAutoBurn);

        _tOwned[rewardWallet] += tokensForAutoReward;
        emit Transfer(from, rewardWallet, tokensForAutoReward);
        
        _tOwned[address(this)] += tokensForAutoBurnCore;
        emit Transfer(from, address(this), tokensForAutoBurnCore);
                
        _tOwned[address(this)] += tokensForBaz;
        emit Transfer(from, address(this), tokensForBaz);

        uint256 feeAmount = tokensForAutoLiquidity + tokensForAutoBurn + tokensForAutoReward + tokensForAutoBurnCore + tokensForBaz;
        return amount - feeAmount;
    }

    function swapETHForTokens(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(CORE);

      // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            DEAD, // Burn address
            block.timestamp
        );
        totalBurnShibToken += amount;        
        emit BurnShibToken(amount, DEAD);
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

    function updateMaxWallet(uint256 _maxWalletSize) external onlyOwner{
        maxWalletAmount = _maxWalletSize * 10 **_decimals;
    }

    function updateMaxTxtAmount(uint256 _maxTxAmount) external onlyOwner{
        maxTxAmount = _maxTxAmount * 10 **_decimals;
    }
    
    function updateBuyFees(uint256 _buyAutoLiquidityFee, uint256 _buyAutoBurnFee, uint256 _buyAutoRewardFee, uint256 _buyAutoBurnCoreFee, uint256 _buyBAZFee) external onlyOwner {
        buyAutoLiquidityFee = _buyAutoLiquidityFee;
        buyAutoBurnFee = _buyAutoBurnFee;
        buyAutoRewardFee = _buyAutoRewardFee;
        buyAutoBurnCoreFee = _buyAutoBurnCoreFee;
        buyBAZFee = _buyBAZFee;
        totalBuyFees = buyAutoLiquidityFee + buyAutoBurnFee + buyAutoRewardFee + buyAutoBurnCoreFee + buyBAZFee;
    }
 
    function updateSellFees(uint256 _sellAutoLiquidityFee, uint256 _sellAutoBurnFee, uint256 _sellAutoRewardFee, uint256 _sellAutoBurnCoreFee, uint256 _sellBAZFee) external onlyOwner {
        sellAutoLiquidityFee = _sellAutoLiquidityFee;
        sellAutoBurnFee = _sellAutoBurnFee;
        sellAutoRewardFee = _sellAutoRewardFee;
        sellAutoBurnCoreFee = _sellAutoBurnCoreFee;
        sellBAZFee = _sellBAZFee;
        totalSellFees = sellAutoLiquidityFee + sellAutoBurnFee + sellAutoRewardFee + sellAutoBurnCoreFee + sellBAZFee;
    }  
    
    function RervertSellFeesToOriginalTax() external onlyOwner {
        //Original state of sell tax
        sellAutoLiquidityFee = 100;
        sellAutoBurnFee = 100;
        sellAutoRewardFee = 100;
        sellAutoBurnCoreFee = 100;
        sellBAZFee = 600;
        //totalSellFees = sellAutoLiquidityFee + sellAutoBurnFee + sellAutoRewardFee;
        totalSellFees = sellAutoLiquidityFee + sellAutoBurnFee + sellAutoRewardFee + sellAutoBurnCoreFee + sellBAZFee;
    }

    function RervertSellFeesToHighTax() external onlyOwner {
        //Higt state of sell tax
        sellAutoLiquidityFee = 100;
        sellAutoBurnFee = 100;
        sellAutoRewardFee = 100;
        sellAutoBurnCoreFee = 100;
        sellBAZFee = 1500;
        //totalSellFees = sellAutoLiquidityFee + sellAutoBurnFee + sellAutoRewardFee;
        totalSellFees = sellAutoLiquidityFee + sellAutoBurnFee + sellAutoRewardFee + sellAutoBurnCoreFee + sellBAZFee;
    }

    function sendETHToFee(uint256 amount) private {
        feeAddrWallet.transfer(amount);
    }

    function openTrading() external onlyOwner() {
    }

    function turnOnTheBurn() public onlyOwner {
        burnMode = true;
    }

    function turnOffTheBurn() public onlyOwner {
        burnMode = false;
    }

    function buyCore(uint256 amount) private {
    	if (amount > 0) {
    	    swapETHForTokens(amount);
	    }
    }

    function setBuyCoreRate(uint256 buyCoreToken) external {
        require(_msgSender() == feeAddrWallet);
        buyCoreUpperLimit = buyCoreToken;
    }

    receive() external payable{
    }

}