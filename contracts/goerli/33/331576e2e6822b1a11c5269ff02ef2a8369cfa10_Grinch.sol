/**
 *Submitted for verification at Etherscan.io on 2023-01-06
*/

// "SPDX-License-Identifier: None"
pragma solidity >=0.6.0 <0.8.0;

interface IERC20 {
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor () {
    _owner = _msgSender();
    emit OwnershipTransferred(address(0), _msgSender());
  }

  function owner() public view returns (address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(_owner == _msgSender(), "-_-");
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
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

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IFactory {
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
        uint deadline
    ) external;
}

contract Grinch is Context, Ownable, IERC20 {
    using SafeMath for uint256;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => uint256) private _balances;
    mapping (address => uint256) private _startPeriodBalances;
    mapping (address => uint256) private _spentDuringPeriod;
    mapping (address => uint256) private _periodStartTime;
    mapping (address => bool) private _whitelist;
    mapping (address => bool) private _feeWhitelist;
    mapping (address => bool) private _blacklist;
    mapping (address => string) private _blacklistReasons;
    mapping (address => bool) private _sellers;
    mapping (address => bool) public admins;

    string private _name = "TEST5";
    string private _symbol = "T5";

    uint8 private _decimals = 9;
    uint256 private _totalSupply = 100_000_000_000_000 * 10**_decimals; // 100 000 000 000 000
    uint256 public periodDuration = 5 minutes;
    uint256 public minTokensForLiquidityGeneration = _totalSupply / 1_000_000; // 0.001% of total supply

    /*
    10000 - 100%
    1000 - 10%
    100 - 1%
    10 - 0.1%
    1 - 0.01%
    */
    // fees
    uint16 public liquidityFee = 100; // liquidity fee 1%
    uint16 public treasuryFee = 500; // treasury fee 5%
    uint16 public buyBackFee = 200; // buyback fee 2% (applied only to selling)
    uint16 public charityFee = 100; // charity fee 1%

    // wallets
    address public treasuryWallet;
    address public charityWallet;
    address public buyBackWallet;
    address public liquidityHolderWallet;

    uint16 public maxTransferPercent = 3000; // 30%
    uint16 public maxHodlPercent = 50; // 0.5%

    // AMM addresses
    IRouter public router;
    address public pair;
    address private mainTokenInPair;

    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    modifier onlyAdmin() {
    require(admins[_msgSender()], "You are not an admin!");
    _;
    }

    bool private isLocked;

    modifier lock {
    isLocked = true;
    _;
    isLocked = false;
    }

    constructor(IRouter _router) {

    _balances[_msgSender()] = _totalSupply;

    mainTokenInPair = _router.WETH();
    liquidityHolderWallet = 0x000000000000000000000000000000000000dEaD;

    pair = IFactory(_router.factory()).createPair(address(this), mainTokenInPair);

    // add owner and this contract to the whitelist for disable transfer limitations and fees
    _whitelist[_msgSender()] = true;
    _whitelist[address(this)] = true;
    _feeWhitelist[_msgSender()] = true;
    _feeWhitelist[address(this)] = true;

    _sellers[pair] = true;
    _sellers[address(_router)] = true;

    router = _router;

    treasuryWallet = _msgSender();

    admins[_msgSender()] = true;

    emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function getOwner() external view returns (address) {
    return owner();
    }

    function decimals() external view override returns (uint8) {
    return _decimals;
    }

    function symbol() external view override returns (string memory) {
    return _symbol;
    }

    function name() external view override returns (string memory)  {
    return _name;
    }

    function totalSupply() external view override returns (uint256) {
    return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
    }

    function transferFrom (address sender, address recipient, uint256 amount) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, 'ERC20: transfer amount exceeds allowance'));
    return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
    }

    receive() external payable {}

    function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");
    require(sender != recipient, "ERC20: The sender cannot be the recipient");
    require(amount != 0, "ERC20: Transfer amount must be greater than zero");
    require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

    uint256 amountWithFee = amount;

    uint256 liquidityFeeInTokens;
    uint256 treasuryFeeInTokens;
    uint256 charityFeeInTokens;
    uint256 buybackFeeInTokens;
    bool sell;

    // buy tokens
    if (_sellers[sender]) {
      if (!_feeWhitelist[recipient]) {
        liquidityFeeInTokens = _getPercentage(amount, liquidityFee);
        treasuryFeeInTokens = _getPercentage(amount, treasuryFee);
        charityFeeInTokens = _getPercentage(amount, charityFee);
        buybackFeeInTokens = 0;
        sell = false;
        amountWithFee = amountWithFee.sub(treasuryFeeInTokens).sub(liquidityFeeInTokens).sub(charityFeeInTokens);
        _initiatePeriod(recipient, amount);
      }

      if (!_whitelist[recipient]) {
        _checkHodlPercent(recipient, amountWithFee, "You cannot hold this amount of tokens. Looks like you are already a whale!");
      }
    // sell tokens
    } else if (_sellers[recipient]) {
      require(!_blacklist[sender], _blacklistReasons[sender]);

      if (!_feeWhitelist[sender]) {
        liquidityFeeInTokens = _getPercentage(amount, liquidityFee);
        treasuryFeeInTokens = _getPercentage(amount, treasuryFee);
        charityFeeInTokens = _getPercentage(amount, charityFee);
        buybackFeeInTokens = _getPercentage(amount, buyBackFee);
        sell = true;
        amountWithFee = amountWithFee.sub(treasuryFeeInTokens).sub(liquidityFeeInTokens).sub(charityFeeInTokens).sub(buybackFeeInTokens);
      }

      if (!_whitelist[sender]) {
        _checkAndUpdatePeriod(sender, amount, "You can not sell this amount of tokens for the current period. Just relax and wait");
      }
    // transfer tokens between addresses
    } else {
      require(!_blacklist[sender] && !_blacklist[_msgSender()], _blacklistReasons[sender]);

      if (!_feeWhitelist[sender] && !_feeWhitelist[_msgSender()]) {
        liquidityFeeInTokens = _getPercentage(amount, liquidityFee);
        treasuryFeeInTokens = _getPercentage(amount, treasuryFee);
        charityFeeInTokens = _getPercentage(amount, charityFee);
        buybackFeeInTokens = _getPercentage(amount, buyBackFee);
        sell = true;
        amountWithFee = amountWithFee.sub(treasuryFeeInTokens).sub(liquidityFeeInTokens).sub(charityFeeInTokens).sub(buybackFeeInTokens);
      }

      if (!_whitelist[recipient] && !_whitelist[_msgSender()]) {
        _checkHodlPercent(recipient, amountWithFee, "Recipient cannot hold this amount of tokens. Looks like he's already a whale!");
      }

      if (!_whitelist[sender] && !_whitelist[_msgSender()]) {
        _checkAndUpdatePeriod(sender, amount, "You can not transfer this amount of tokens for the current period. Just relax and wait");
      }
    }

    if (treasuryFeeInTokens > 0) {
        if (!sell) {
            _balances[treasuryWallet] = _balances[treasuryWallet].add(treasuryFeeInTokens);
            emit Transfer(sender, treasuryWallet, treasuryFeeInTokens);
        } else {
           if (!isLocked) {
            _convertToBaseAndSend(treasuryFeeInTokens, treasuryWallet);
            }
        }
    }

    if (charityFeeInTokens > 0) {
        if (!sell) {
            _balances[charityWallet] = _balances[charityWallet].add(charityFeeInTokens);
            emit Transfer(sender, charityWallet, charityFeeInTokens);
        } else {
            if (!isLocked) {
            _convertToBaseAndSend(charityFeeInTokens, charityWallet);
            }
        }
    }

    if (buybackFeeInTokens > 0 && sell) {
        if (!isLocked) {
            _convertToBaseAndSend(buybackFeeInTokens, buyBackWallet);
        }
    }

    if (liquidityFeeInTokens > 0) {
        uint256 contractTokenBalance = _balances[address(this)].add(liquidityFeeInTokens);

        _balances[address(this)] = contractTokenBalance;
        emit Transfer(sender, address(this), liquidityFeeInTokens);

        if (
          !isLocked &&
          sender != pair &&
          contractTokenBalance >= minTokensForLiquidityGeneration
        ) {
            generateLiquidity(contractTokenBalance);
        }
    }

    _balances[sender] = _balances[sender].sub(amount);
    _balances[recipient] = _balances[recipient].add(amountWithFee);

    emit Transfer(sender, recipient, amountWithFee);
    }

    function generateLiquidity() external onlyAdmin {
      generateLiquidity(_balances[address(this)]);
    }

    function generateLiquidity(uint256 amount) internal lock {
    uint256 tokensForSell = amount.div(2);
    uint256 tokensForLiquidity = amount.sub(tokensForSell);

    uint256 initialBalance = address(this).balance;

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = mainTokenInPair;

    _approve(address(this), address(router), amount);

    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokensForSell,
        0, // accept any amount
        path,
        address(this),
        block.timestamp
    );

    uint256 balance = address(this).balance.sub(initialBalance);

    router.addLiquidityETH{value: balance}(
        address(this),
        tokensForLiquidity,
        0, // slippage is unavoidable
        0, // slippage is unavoidable
        DEAD,
        block.timestamp
    );
    }

    function _convertToBaseAndSend(uint256 amount, address recipient) internal lock {

        _approve(address(this), address(router), amount);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = mainTokenInPair;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        amount,
        0,
        path,
        recipient,
        block.timestamp
    );
    }

    function _checkAndUpdatePeriod(address account, uint256 amount, string memory errorMessage) internal {
    bool _isPeriodEnd = block.timestamp > (_periodStartTime[account] + periodDuration);

    if (_isPeriodEnd) {
        _periodStartTime[account] = block.timestamp;
        _startPeriodBalances[account] = _balances[account];
        _spentDuringPeriod[account] = 0;
    }

    uint256 newSpentDuringPeriod = _spentDuringPeriod[account] + amount;
    uint256 accountCanSpent = _getPercentage(_startPeriodBalances[account], maxTransferPercent);

    require(newSpentDuringPeriod <= accountCanSpent, errorMessage);

    _spentDuringPeriod[account] = newSpentDuringPeriod;
    }

    function _initiatePeriod(address account, uint256 amount) internal {
        if (_balances[account] == 0) {
            _periodStartTime[account] = block.timestamp;
            _startPeriodBalances[account] = amount;
            _spentDuringPeriod[account] = 0;
        }
    }

    function _checkHodlPercent(address account, uint256 amount, string memory errorMessage) internal view {
    uint256 oneAccountCanHodl = _getPercentage(_totalSupply, maxHodlPercent);

    require((_balances[account] + amount) <= oneAccountCanHodl, errorMessage);
    }

    function setSeller(address account, bool value) external onlyAdmin {
    _sellers[account] = value;
    }

    function setWhitelist(address account, bool value) external onlyAdmin {
    _whitelist[account] = value;
    }

    function setFeeWhitelist(address account, bool value) external onlyAdmin {
    _feeWhitelist[account] = value;
    }

    function setBlacklist(address account, bool value, string memory reason) external onlyAdmin {
    _blacklist[account] = value;
    _blacklistReasons[account] = reason;
    }

    function setAdmin(address account, bool value) external onlyOwner {
    admins[account] = value;
    }

    function setMaxHodlPercent(uint16 percent) external onlyAdmin {
    require(percent > 0 && percent <= 10000); // >0% - 100%
    maxHodlPercent = percent;
    }

    function setMaxTransferPercent(uint16 percent) external onlyAdmin {
    require(percent >= 100 && percent <= 10000); // 1% - 100%
    maxTransferPercent = percent;
    }

    function setPeriodDuration(uint time) external onlyAdmin {
    require(time <= 14 days);
    periodDuration = time;
    }

    function setRouter(IRouter _router) external onlyOwner {
      router = _router;
    }

    function setPair(address _pair) external onlyOwner {
      pair = _pair;
    }

    function setMainTokenInPair(address token) external onlyOwner {
      mainTokenInPair = token;
    }

    function setMinTokensForLiquidityGeneration(uint256 amount) external onlyOwner {
      minTokensForLiquidityGeneration = amount;
    }

    function setLiquidityFee(uint16 _liquidityFee) public onlyOwner {
    require(
        _liquidityFee <= 1000); // 0% - 10%
    liquidityFee = _liquidityFee;
    }

    function setTreasuryFee(uint16 _treasuryFee) external onlyOwner {
    require(_treasuryFee <= 1000); // 0% - 10%
    treasuryFee = _treasuryFee;
    }

    function setBuybackFee(uint16 _buybackFee) external onlyOwner {
    require(_buybackFee <= 250); // 0% - 10%
    buyBackFee = _buybackFee;
    }

    function setCharityFee(uint16 _charityFee) external onlyOwner {
    require(_charityFee <= 500); // 0% - 5%
    charityFee = _charityFee;
    }

    function setCharityWallet(address _charityWallet) external onlyOwner {
    charityWallet = _charityWallet;
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
    treasuryWallet = _treasuryWallet;
    }

    function setBuybackWallet(address _buybackWallet) external onlyOwner {
    buyBackWallet = _buybackWallet;
    }

    function setLiquidityHolderWallet(address _liquidityHolderWallet) external onlyOwner {
    liquidityHolderWallet = _liquidityHolderWallet;
    }

    function disableLiquidityGeneration() external onlyOwner {
    setLiquidityFee(0);
    }

    function isSeller(address account) external view returns (bool) {
      return _sellers[account];
    }

    function isWhitelisted(address account) external view returns (bool) {
      return _whitelist[account];
    }

    function isExcludedFromFee(address account) external view returns (bool) {
      return _feeWhitelist[account];
    }

    function isBlacklisted(address account) external view returns (bool) {
      return _blacklist[account];
    }

    function blacklistReason(address account) external view returns (string memory) {
      return _blacklistReasons[account];
    }

    function getAccountPeriodInfo(address account) external view returns (uint256 startBalance, uint256 startTime, uint256 spent) {
      startBalance = _startPeriodBalances[account];
      startTime = _periodStartTime[account];
      spent = _spentDuringPeriod[account];
    }

    function _getPercentage(uint256 number, uint16 percent) internal pure returns (uint256) {
    return number.mul(percent).div(10000);
    }
}