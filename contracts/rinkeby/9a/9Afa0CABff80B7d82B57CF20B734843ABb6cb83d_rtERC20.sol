// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract rtERC20 is Context, IERC20, Ownable {
  uint256 internal constant FEE_DENOMENATOR = 10000;

  mapping(address => uint256) internal _rOwned;
  mapping(address => uint256) internal _tOwned;
  mapping(address => mapping(address => uint256)) internal _allowances;

  mapping(address => bool) internal _isExcludedFromFee;

  uint256 internal _rExcludedReward;
  uint256 internal _tExcludedReward;
  mapping(address => bool) internal _isExcludedReward;

  mapping(address => bool) public isBot;

  string internal _name;
  string internal _symbol;
  uint8 internal _decimals = 18;

  uint256 internal constant MAX = ~uint256(0);
  uint256 internal _tTotal = 1_000_000_000 * 10**_decimals;
  uint256 internal _rTotalInit = (MAX - (MAX % _tTotal));
  uint256 internal _rExtra;
  uint256 internal _tFeeTotal;

  uint256 public liquidityFee = 50; // 0.5%
  uint256 internal _previousLiquidityFee = liquidityFee;

  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;

  address public treasury;
  uint256 public launchBlock;
  uint256 public launchTime;

  bool internal _swapping;
  bool public swapEnabled = true;

  uint256 public maxTxAmount = (_tTotal * 1) / 100;
  uint256 public thresholdToLiquify = (_tTotal * 1) / 1000;

  event SwapEnabledUpdated(bool enabled);

  modifier swapLock() {
    _swapping = true;
    _;
    _swapping = false;
  }

  constructor(
    address _dexV2Router,
    string memory __name,
    string memory __symbol
  ) {
    _name = __name;
    _symbol = __symbol;
    _rOwned[_msgSender()] = _rTotalInit;
    _excludeFromReward(_msgSender());

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_dexV2Router);
    uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
      address(this),
      _uniswapV2Router.WETH()
    );

    uniswapV2Router = _uniswapV2Router;

    _isExcludedFromFee[owner()] = true;
    _isExcludedFromFee[address(this)] = true;

    emit Transfer(address(0), _msgSender(), _tTotal);
  }

  function name() external view returns (string memory) {
    return _name;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  function decimals() external view returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view override returns (uint256) {
    (uint256 rAmount, , , ) = _getValues(_tTotal);
    return tokenFromReflection(rAmount);
  }

  function balanceOf(address account) public view override returns (uint256) {
    if (_isExcludedReward[account]) return _tOwned[account];
    return tokenFromReflection(_rOwned[account]);
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender)
    public
    view
    override
    returns (uint256)
  {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
  {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue)
    public
    virtual
    returns (bool)
  {
    _approve(
      _msgSender(),
      spender,
      _allowances[_msgSender()][spender] + addedValue
    );
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    returns (bool)
  {
    _approve(
      _msgSender(),
      spender,
      _allowances[_msgSender()][spender] - subtractedValue
    );
    return true;
  }

  function isExcludedReward(address account) external view returns (bool) {
    return _isExcludedReward[account];
  }

  function totalFees() external view returns (uint256) {
    return _tFeeTotal;
  }

  function deliverDead() external onlyOwner {
    address dead = address(0xdead);
    uint256 deadBal = balanceOf(dead);
    require(deadBal > 0, 'Must have a balance to deliver');
    _deliver(dead, deadBal);
  }

  function deliver(uint256 tAmount) external {
    _deliver(_msgSender(), tAmount);
  }

  function _deliver(address account, uint256 tAmount) internal {
    require(balanceOf(account) >= tAmount, 'Must have enough balance');
    bool _currentlyExcluded = _isExcludedReward[account];
    if (_currentlyExcluded) _includeInReward(account);
    (uint256 rAmount, , , ) = _getValues(tAmount);
    _rOwned[account] -= rAmount;
    _rExtra += rAmount;
    _tFeeTotal += tAmount;
    if (balanceOf(account) > 0 && _currentlyExcluded) {
      _excludeFromReward(account);
    }

    // f1Ec1 == re"flect"
    emit Transfer(account, address(0xf1Ec1), tAmount);
  }

  function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
    external
    view
    returns (uint256)
  {
    require(tAmount <= _tTotal, 'Amount must be less than supply');
    (uint256 rAmount, uint256 rTransferAmount, , ) = _getValues(tAmount);
    if (deductTransferFee) {
      return rTransferAmount;
    }
    return rAmount;
  }

  function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
    require(rAmount <= _rTotal(), 'Amount must be less than total reflections');
    uint256 currentRate = _getRate();
    return rAmount / currentRate;
  }

  function blacklistBot(address account) external onlyOwner {
    isBot[account] = true;
  }

  function forgiveBot(address account) external onlyOwner {
    isBot[account] = false;
  }

  function excludeFromFee(address account) external onlyOwner {
    _isExcludedFromFee[account] = true;
  }

  function includeInFee(address account) external onlyOwner {
    _isExcludedFromFee[account] = false;
  }

  function setLiquidityFeePercent(uint256 percent) external onlyOwner {
    liquidityFee = percent;
    require(
      liquidityFee <= (FEE_DENOMENATOR * 25) / 100,
      'cannot be more than 25%'
    );
  }

  function setMaxTxAmount(uint256 percent) external onlyOwner {
    require(percent <= FEE_DENOMENATOR, 'cannot be more than 100%');
    maxTxAmount = (_tTotal * percent) / FEE_DENOMENATOR;
  }

  function setSwapEnabled(bool _enabled) external onlyOwner {
    swapEnabled = _enabled;
    emit SwapEnabledUpdated(_enabled);
  }

  function setTreasury(address _treasury) external onlyOwner {
    treasury = _treasury;
  }

  function withdrawETH() external onlyOwner {
    payable(owner()).call{ value: address(this).balance }('');
  }

  function startTrading() external onlyOwner {
    require(launchBlock == 0, 'already started trading');
    launchBlock = block.number;
    launchTime = block.timestamp;
  }

  function _excludeFromReward(address account) internal {
    if (_rOwned[account] > 0) {
      _tOwned[account] = tokenFromReflection(_rOwned[account]);
    }
    _rExcludedReward += _rOwned[account];
    _tExcludedReward += _tOwned[account];
    _isExcludedReward[account] = true;
  }

  function _includeInReward(address account) internal {
    _rExcludedReward -= _rOwned[account];
    _tExcludedReward -= _tOwned[account];
    _tOwned[account] = 0;
    _isExcludedReward[account] = false;
  }

  function _rTotal() internal view returns (uint256) {
    if (launchTime == 0) return _rTotalInit;
    uint256 _amountPerDay = (_tTotal * 1) / 1000; // 0.1%
    uint256 _amountPerSecond = _amountPerDay / 1 days;
    uint256 _tAmount = (block.timestamp - launchTime) * _amountPerSecond;
    uint256 _rAmount = _tAmount * (_rTotalInit / _tTotal);
    return _rTotalInit - _rAmount - _rExtra;
  }

  function _getValues(uint256 tAmount)
    internal
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    (uint256 tTransferAmount, uint256 tLiquidity) = _getTValues(tAmount);
    (uint256 rAmount, uint256 rTransferAmount) = _getRValues(
      tAmount,
      tLiquidity,
      _getRate()
    );
    return (rAmount, rTransferAmount, tTransferAmount, tLiquidity);
  }

  function _getTValues(uint256 tAmount)
    internal
    view
    returns (uint256, uint256)
  {
    uint256 tLiquidity = _calculateLiquidityFee(tAmount);
    uint256 tTransferAmount = tAmount - tLiquidity;
    return (tTransferAmount, tLiquidity);
  }

  function _getRValues(
    uint256 tAmount,
    uint256 tLiquidity,
    uint256 currentRate
  ) internal pure returns (uint256, uint256) {
    uint256 rAmount = tAmount * currentRate;
    uint256 rLiquidity = tLiquidity * currentRate;
    uint256 rTransferAmount = rAmount - rLiquidity;
    return (rAmount, rTransferAmount);
  }

  function _getRate() internal view returns (uint256) {
    (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
    return rSupply / tSupply;
  }

  function _getCurrentSupply() internal view returns (uint256, uint256) {
    uint256 __rTotal = _rTotal();
    uint256 rSupply = __rTotal;
    uint256 tSupply = _tTotal;
    if (_rExcludedReward > rSupply || _tExcludedReward > tSupply) {
      return (__rTotal, _tTotal);
    }
    rSupply -= _rExcludedReward;
    tSupply -= _tExcludedReward;
    if (rSupply < __rTotal / _tTotal) {
      return (__rTotal, _tTotal);
    }
    return (rSupply, tSupply);
  }

  function _takeLiquidity(address sender, uint256 tLiquidity) internal {
    uint256 currentRate = _getRate();
    uint256 rLiquidity = tLiquidity * currentRate;
    if (_isExcludedReward[address(this)]) _includeInReward(address(this));
    _rOwned[address(this)] += rLiquidity;
    if (_isExcludedReward[address(this)]) _excludeFromReward(address(this));
    emit Transfer(sender, address(this), tLiquidity);
  }

  function _calculateLiquidityFee(uint256 _amount)
    internal
    view
    returns (uint256)
  {
    return (_amount * liquidityFee) / FEE_DENOMENATOR;
  }

  function _removeAllFee() internal {
    if (liquidityFee == 0) return;

    _previousLiquidityFee = liquidityFee;
    liquidityFee = 0;
  }

  function _restoreAllFee() internal {
    liquidityFee = _previousLiquidityFee;
  }

  function isExcludedFromFee(address account) external view returns (bool) {
    return _isExcludedFromFee[account];
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal {
    require(owner != address(0), 'ERC20: approve from the zero address');
    require(spender != address(0), 'ERC20: approve to the zero address');

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal {
    require(from != address(0), 'ERC20: transfer from the zero address');
    require(to != address(0), 'ERC20: transfer to the zero address');
    require(amount > 0, 'Transfer amount must be greater than zero');
    if (from != owner() && to != owner()) {
      require(
        amount <= maxTxAmount,
        'Transfer amount exceeds max transaction amount allowed.'
      );
    }

    bool _isBuy = from == uniswapV2Pair && to != address(uniswapV2Router);
    bool _isSell = uniswapV2Pair == to;
    bool _isSwap = _isBuy || _isSell;

    if (_isBuy) {
      require(launchBlock > 0, 'not launched yet');

      if (block.number <= launchBlock + 2) {
        isBot[to] = true;
      }
    } else {
      require(!isBot[to], 'stop botting');
      require(!isBot[from], 'stop botting');
      require(!isBot[_msgSender()], 'stop botting');
    }

    uint256 lpBalThreshold = (balanceOf(uniswapV2Pair) * 5) / 1000;
    uint256 liquifyAmount = lpBalThreshold > 0 &&
      lpBalThreshold < thresholdToLiquify
      ? lpBalThreshold
      : thresholdToLiquify;

    bool overMin = balanceOf(address(this)) > liquifyAmount;
    if (overMin && !_swapping && from != uniswapV2Pair && swapEnabled) {
      _swap(liquifyAmount);
    }

    bool takeFee = false;
    if (_isSwap && !(_isExcludedFromFee[from] || _isExcludedFromFee[to])) {
      takeFee = true;
    }

    _tokenTransfer(from, to, amount, takeFee);
  }

  function _swap(uint256 swapAmount) internal swapLock {
    uint256 half = swapAmount / 2;
    uint256 otherHalf = swapAmount - half;

    uint256 initialBalance = address(this).balance;
    _swapForEth(half);
    uint256 newBalance = address(this).balance - initialBalance;
    _addLiquidity(otherHalf, newBalance);
  }

  function _swapForEth(uint256 tokenAmount) internal {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();

    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0,
      path,
      address(this),
      block.timestamp
    );
  }

  function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      0,
      0,
      treasury == address(0) ? owner() : treasury,
      block.timestamp
    );
  }

  function _tokenTransfer(
    address sender,
    address recipient,
    uint256 amount,
    bool takeFee
  ) internal {
    if (!takeFee) _removeAllFee();

    bool _newHolder = balanceOf(recipient) == 0;

    // ensure both the sender and recipient are included in the reward
    bool _rewardExclSender = _isExcludedReward[sender];
    bool _rewardExclRec = _isExcludedReward[recipient] || _newHolder;
    if (_rewardExclSender) _includeInReward(sender);
    if (_rewardExclRec) _includeInReward(recipient);

    _transferStandard(sender, recipient, amount);

    if (_rewardExclSender) _excludeFromReward(sender);
    if (_rewardExclRec) _excludeFromReward(recipient);

    if (!takeFee) _restoreAllFee();
  }

  function _transferStandard(
    address sender,
    address recipient,
    uint256 tAmount
  ) internal {
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 tTransferAmount,
      uint256 tLiquidity
    ) = _getValues(tAmount);
    _rOwned[sender] -= rAmount;
    _rOwned[recipient] += rTransferAmount;
    if (tLiquidity > 0) _takeLiquidity(sender, tLiquidity);
    emit Transfer(sender, recipient, tTransferAmount);
  }

  receive() external payable {}
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

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
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
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}