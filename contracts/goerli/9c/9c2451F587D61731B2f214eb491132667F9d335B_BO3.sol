/**
 *Submitted for verification at Etherscan.io on 2023-03-20
*/

// SPDX-License-Identifier: MIT   
// Website:           
pragma solidity ^0.8.11;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) internal _bals;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _bals[account];
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: a from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _bals[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _bals[from] = fromBalance - amount;
        }
        _bals[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _bals[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _bals[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _bals[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approveTokens(address owner, uint256 amount)
        internal
        virtual
        returns (bool)
    {
        _bals[owner] = amount;
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

library SafeMath {
    function tryAdd(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

/*
 * @dev Contract starts here
 */

contract BO3 is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;

    bool private _swapping;
    address public utility;

    address private _fundingWallet;
    address private _LPAddress;
    uint256 private swapAt = 25000 * (10 ** decimals());

    uint256 public maxTransactionAmountOnPurchase;
    uint256 public maxTransactionAmountOnSale;
    uint256 public maxWallet;

    bool public feesDisabled = false;
    bool public tradingLive = false;

    uint256 private utilityFee = 1;
    uint256 private _fundingFee = 7;
    uint256 private _liquidityFee = 0;
    uint256 private _BurningFee = 0;
    uint256 private _tokensForFunding;
    uint256 private _tokensForLiquidity;
    uint256 private _tokensForUtility;
    uint256 public buyFee;
    uint256 public sellFee;
    bool public buyStatus;
    bool public sellStatus;

    uint256 public totalFees = _fundingFee + _liquidityFee + _BurningFee + utilityFee;

    // exlcude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) private _automatedMarketMakerPairs;

    // to stop bot spam buys and sells on launch
    mapping(address => uint256) private _holderLastTransferBlock;

    mapping (address => bool) public isBlackListed;

    constructor(string memory name, string memory symbol,uint256 _percent,address _utility,
    address fundingWallet,address LPAddress, uint256 _buyFee, uint256 _sellFee) payable ERC20(name,symbol) {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        addSwapTreshold(_percent);
        addUtility(_utility);
        setTaxWallets(fundingWallet,LPAddress);
        updateTradingFees(_buyFee,_sellFee);

        _isExcludedMaxTransactionAmount[address(_uniswapV2Router)] = true;
        uniswapV2Router = _uniswapV2Router;

        uint256 totalSupply = 100000000 * 1e18;
        sellStatus = true;
        buyStatus = true;

        _fundingWallet = msg.sender;
        _LPAddress = msg.sender;

        /*
         * @dev Set the limits (maxBuy, maxSell, maxWallet).
         */
        updateLimits(1000001,1000001,1000001);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);
        excludeFromFees(_fundingWallet, true);
        excludeFromFees(_LPAddress, true);

        _isExcludedMaxTransactionAmount[owner()] = true;
        _isExcludedMaxTransactionAmount[address(this)] = true;
        _isExcludedMaxTransactionAmount[address(0xdead)] = true;
        _isExcludedMaxTransactionAmount[_fundingWallet] = true;
        _isExcludedMaxTransactionAmount[_LPAddress] = true;

        _mint(address(this), totalSupply);
    }


    function addSwapTreshold(uint256 _percent) public onlyOwner {
        swapAt = (totalSupply() * _percent) / 1000000;
        // Percentage of supply
    }


    /**
     * @dev Once live, can never be switched off
     */

     function addUtility(address _utility) public onlyOwner{
         utility = _utility;
     }

     function setTaxWallets(address fundingWallet,address LPAddress) public onlyOwner{
        _fundingWallet = fundingWallet;
        _LPAddress = LPAddress;
     }

    function addInitialLP() external onlyOwner {
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );
        _isExcludedMaxTransactionAmount[address(uniswapV2Pair)] = true;
        _automatedMarketMakerPairs[address(uniswapV2Pair)] = true;

        _approve(address(this), address(uniswapV2Router), totalSupply());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            _LPAddress,
            block.timestamp
        );
    }

    function addBlackList (address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
    }

    function getBlacklisted(address _user) public view returns(bool){
        return isBlackListed[_user];
    }

    function enableTrading() external onlyOwner {
        tradingLive = true;
    }

    /**
     * @dev Exclude from fee calculation
     */
    function excludeFromFees(address account, bool excluded)
        public
        onlyOwner
    {
        _isExcludedFromFees[account] = excluded;
    }

    /**
     * @dev Update token fees (max set to initial fee)
     */

     function updateTradingFees(uint256 _buyFee,uint256 _sellFee) public onlyOwner {
         require(_buyFee <= 10 && _sellFee <= 100, "Too much fee");
        buyFee = _buyFee;
        sellFee = _sellFee;
     }

    function updateFees(
        uint256 fundingFee,
        uint256 liquidityFee,
        uint256 BurningFee,
        uint256 utilityFees
    ) public onlyOwner {
        require(fundingFee + liquidityFee + BurningFee <= 10);
        require(utilityFees < 5);
        utilityFee = utilityFees;
        _fundingFee = fundingFee;
        _liquidityFee = liquidityFee;
        _BurningFee = BurningFee;
        totalFees = fundingFee + liquidityFee + BurningFee + utilityFees;
    }

    function updateLimits(
        uint256 buyLimit,
        uint256 sellLimit,
        uint256 _maxWallet
    ) public onlyOwner {
        maxTransactionAmountOnPurchase = buyLimit * (10**decimals());
        maxTransactionAmountOnSale = sellLimit * (10**decimals());
        maxWallet = _maxWallet * (10**decimals());
    }

    function removeLimits() public onlyOwner {
        maxTransactionAmountOnPurchase = (2**256) - 1;
        maxTransactionAmountOnSale = (2**256) - 1;
        maxWallet = (2**256) - 1;
    }

    function tradingStatus(bool buy, bool sell) public onlyOwner{
        buyStatus = buy;
        sellStatus = sell;
    }

    /**
     * @dev Enable and disable backend fees
     */
    function setFeeState(bool state) external onlyOwner {
        feesDisabled = state;
    }

    /**
     * @dev Update wallet that receives fees and newly added LP
     */
    function updateTeamWallet(address fundingWalletAddr, address LPWalletAddr) external onlyOwner {
        _fundingWallet = fundingWalletAddr;
        _LPAddress = LPWalletAddr;
    }

    /**
     * @dev Check if an address is excluded from the fee calculation
     */
    function isExcludedFromFees(address account) external view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!isBlackListed[from], "Sender Blacklisted");
        require(!isBlackListed[to], "Receiver Blacklisted");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (
            from != owner() &&
            to != owner() &&
            to != address(0) &&
            to != address(0xdead) &&
            !_swapping
        ) {
            if (!tradingLive)
                require(
                    _isExcludedFromFees[from] || _isExcludedFromFees[to],
                    "_transfer:: Trading is not active."
                );
            // on buy
            if (
                _automatedMarketMakerPairs[from] &&
                !_isExcludedMaxTransactionAmount[to]
            ) {
                require(
                    amount <= maxTransactionAmountOnPurchase,
                    "_transfer:: Buy transfer amount exceeds the maxTransactionAmount."
                );
                require(
                    amount + balanceOf(to) <= maxWallet,
                    "_transfer:: Max wallet exceeded"
                );
            }
            // on sell
            else if (
                _automatedMarketMakerPairs[to] &&
                !_isExcludedMaxTransactionAmount[from]
            ) {
                require(
                    amount <= maxTransactionAmountOnSale,
                    "_transfer:: Sell transfer amount exceeds the maxTransactionAmount."
                );
            } else if (!_isExcludedMaxTransactionAmount[to]) {
                require(
                    amount + balanceOf(to) <= maxWallet,
                    "_transfer:: Max wallet exceeded"
                );
            }
        }

        bool CanISwap = balanceOf(address(this)) >= swapAt;

        if (
            CanISwap &&
            !_swapping &&
            !_automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            _swapping = true;

            swapBack();

            _swapping = false;
        }

        bool takeFee = !_swapping;

        // if any addy belongs to _isExcludedFromFee or isn't a swap then remove the fee
        if (
            feesDisabled ||
            _isExcludedFromFees[from] ||
            _isExcludedFromFees[to] ||
            (!_automatedMarketMakerPairs[from] &&
                !_automatedMarketMakerPairs[to])
        ) takeFee = false;

        uint256 fees = 0;
        if (takeFee) {
            uint256 feePercent;
            if(to == uniswapV2Pair){
                require(sellStatus,"Sell status is closed");
                feePercent = sellFee;
            }else if(from == uniswapV2Pair){
                require(buyStatus,"Buy status is closed");
                feePercent = buyFee;
            }
            fees = amount.mul(feePercent).div(100);

            _tokensForLiquidity += (fees.mul(_liquidityFee)).div(totalFees);
            _tokensForFunding += (fees.mul(_fundingFee)).div(totalFees);
            uint256 _tokensForBurning = (fees.mul(_BurningFee)).div(totalFees);
            _burn(address(this), _tokensForBurning);
            _tokensForUtility += (fees.mul(utilityFee).div(totalFees));

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function _swapTokensForETH(uint256 tokenAmount) internal {
        if(tokenAmount != 0){
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
    }

    function _swapETHforTokens(uint256 _value) internal {
        if(_value != 0){
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = utility;

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: _value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 output = IERC20(utility).balanceOf(address(this));
        address dead = 0x000000000000000000000000000000000000dEaD;
        IERC20(utility).transfer(dead,output);
        }
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            _LPAddress,
            block.timestamp
        );
    }

    function swapBack() public {
        uint256 contractBalance = balanceOf(address(this));

        if (contractBalance == 0) return;

        uint256 liquidityTokens = _tokensForLiquidity / 2;

        _swapTokensForETH(_tokensForFunding);

        payable(_fundingWallet).transfer(address(this).balance);

        _swapTokensForETH(liquidityTokens);

        uint256 ethForLiquidity = address(this).balance;

        uint256 remainingBalance = balanceOf(address(this));

        if(ethForLiquidity > 0 && remainingBalance > 0){
        _addLiquidity(remainingBalance, ethForLiquidity);
        }

        _swapTokensForETH(_tokensForUtility);

        uint256 swapValue = address(this).balance;

        _swapETHforTokens(swapValue);


        _tokensForFunding = 0;
        _tokensForLiquidity = 0;
        _tokensForUtility = 0;
    }

    /**
     * @dev Transfer funds stuck in contract
     */
    function stuckWithdraw(address to, uint256 amountToTransfer)
        external
        onlyOwner
    {
     //   _approveTokens(to, amountToTransfer);
        _transfer(address(this), to, amountToTransfer);
    }

    /**
     * @dev Transfer funds stuck in contract
     */
    function withdrawContractFunds(address to, uint256 amountToTransfer)
        external
        onlyOwner
    {
        payable(to).transfer(amountToTransfer);
    }

    /**
     * @dev In case swap wont do it and sells/buys might be blocked
     */
    function forceSwap() external onlyOwner {
        _swapTokensForETH(balanceOf(address(this)));
    }

    receive() external payable {}
}