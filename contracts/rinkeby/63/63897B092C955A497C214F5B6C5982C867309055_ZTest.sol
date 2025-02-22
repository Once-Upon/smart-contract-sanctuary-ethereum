/*
 //SPDX-License-Identifier: UNLICENSED
*/


pragma solidity ^0.8.4;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
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

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

}  

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
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

contract ZTest is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private bots;
    mapping (address => uint) private cooldown;
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 100000000000000000000;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    
    uint256 private _feeAddr1;
    uint256 private _feeAddr2;
    address payable private _feeAddrWallet1;
    address public _lastBuyer;
    uint256 public _minBuyToParticipate = 4000000000000000000;
    uint256 public _feeTotal;
    uint256 public _timer;
    uint256 public _prize = 20000000000000000;
    uint256 public _totalToBePaid;
    uint256 public _holdTime = 900;
    uint256 public _competitionTime = 120;
    bool public _iscompetitionOn = true;
    //Winners
    address[] public _winners;
    mapping (address => bool) public _isInvalidWinner;
    //Winners buy map
    mapping (address => uint256) public _winnersBuyTimestamp;
    //Winners Amount map
    mapping (address => uint256) public _winnersAmountToBePaid;
    
    string private constant _name = "ZTEST24";
    string private constant _symbol = "ZTEST24";
    uint8 private constant _decimals = 18;
    
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    bool private cooldownEnabled = false;
    uint256 private _maxTxAmount = _tTotal;
    event UpdateTaxPercentage(uint256 _newFee);
    event UpdatePrize(uint256 _prize);
    event UpdateHoldTime(uint256 _holdTime);
    event UpdateMinBuyToParticipate(uint256 _minBuyToParticipate);
    event UpdateCompetitionTime(uint256 _competitionTime);
    event CurrentWinning(address _address,uint256 _timer);
    event NewWinner(address _winner,uint256 _buyTimestamp);
    event RemoveWinner(address _winner);
    event UpdateAmountToBePaid(address _winner, uint256 _amount);
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
    constructor () {
        _feeAddrWallet1 = payable(owner());
        _rOwned[_msgSender()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_feeAddrWallet1] = true;
        emit Transfer(address(owner()), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function setCooldownEnabled(bool onoff) external onlyOwner() {
        cooldownEnabled = onoff;
    }


    function tokenFromReflection(uint256 rAmount) private view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
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

        if (from != owner() && to != owner()) {
            require(!bots[from] && !bots[to]);
            if (from == uniswapV2Pair && to != address(uniswapV2Router) && ! _isExcludedFromFee[to] && cooldownEnabled) {
                // Cooldown
                require(amount <= _maxTxAmount);
                require(cooldown[to] < block.timestamp);
                cooldown[to] = block.timestamp + (30 seconds);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && from != uniswapV2Pair && swapEnabled) {
                if(_feeAddr2 > 0){
                    swapTokensForEth(contractTokenBalance);
                    uint256 contractETHBalance = address(this).balance;
                    if(contractETHBalance > 0 && contractETHBalance > _totalToBePaid) {
                        sendETHToFee(address(this).balance.sub(_totalToBePaid));
                    }
                }

                if(_iscompetitionOn){
                      //check if address is one of the winners
                    if(_winnersAmountToBePaid[from] != 0){

                        uint256 amountAfterTx = balanceOf(from).sub(amount);

                        if(amountAfterTx >= _minBuyToParticipate){
                            //keep as winner

                            //update winners amount to be paid
                            uint256 newAmountToBePaid = amountAfterTx.div(_minBuyToParticipate);
                            newAmountToBePaid = newAmountToBePaid.mul(_prize);

                            //check if is participating, if so must hold new amount + min buy to keep  
                            if(_lastBuyer == from && _timer != 0 && newAmountToBePaid < _winnersAmountToBePaid[from].add(_prize)){
                                //Not participating anymore
                                _lastBuyer = address(0);
                                _timer = 0;
                                emit CurrentWinning(_lastBuyer, _timer);
                            }

                            if(newAmountToBePaid < _winnersAmountToBePaid[from]){
                                _totalToBePaid -= _winnersAmountToBePaid[from].sub(newAmountToBePaid);
                                _winnersAmountToBePaid[from] = newAmountToBePaid;
                                emit UpdateAmountToBePaid(from ,newAmountToBePaid);
                            }
                        }else{
                            //not a winner anymore

                            //remove payment from total
                            _totalToBePaid -= _winnersAmountToBePaid[from];

                            //reset winner
                            _winnersBuyTimestamp[from] = 0;
                            _winnersAmountToBePaid[from] = 0;
                            emit UpdateAmountToBePaid(from, 0);

                            //set as invalid winner
                            _isInvalidWinner[from] = true;
                        }
                    }
                    
                    //check if is participating
                    if(_lastBuyer == from && _timer != 0){
                        //check if address is participating
                        uint256 amountAfterTx = balanceOf(from).sub(amount);

                        if(amountAfterTx < _minBuyToParticipate){
                            //Not participating anymore
                            _lastBuyer = address(0);
                            _timer = 0;
                            emit CurrentWinning(_lastBuyer, _timer);
                        }
                    }
                }
            }

            if(_iscompetitionOn && from == uniswapV2Pair && to != address(uniswapV2Router) && amount >= _minBuyToParticipate){
                checkWinner();
                _lastBuyer = to;
                _timer = block.timestamp + _competitionTime;
                emit CurrentWinning(_lastBuyer, _timer);
            }

        }
		
        _tokenTransfer(from,to,amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
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
        
    function sendETHToFee(uint256 amount) private {
        _feeAddrWallet1.transfer(amount);
    }

    function checkWinner() public{
        if(_timer != 0 && block.timestamp >= _timer){
            if( _winnersBuyTimestamp[_lastBuyer] == 0){
                if(!_isInvalidWinner[_lastBuyer]){
                    //first time winning
                    _winners.push(_lastBuyer);
                    emit NewWinner(_lastBuyer, _timer);
                }
                _winnersBuyTimestamp[_lastBuyer] = _timer;
            }
            _winnersAmountToBePaid[_lastBuyer] += _prize;
            _totalToBePaid += _prize;
            //reset timer and lastBuyer
            _timer = 0;
            _lastBuyer = address(0);

            emit CurrentWinning(_lastBuyer, _timer);
        }
    }

    function claimPrize() public {
        require(_winnersAmountToBePaid[msg.sender] > 0, "No money to claim!");
        require(block.timestamp >= _winnersBuyTimestamp[msg.sender] + _holdTime, "Can't claim yet!");
        require(address(this).balance >= _winnersAmountToBePaid[msg.sender], "Not enough funds to pay winner!");
        //pay winner
        payable(msg.sender).transfer(_winnersAmountToBePaid[msg.sender]);
        //remove paid amount from total
        _totalToBePaid -= _winnersAmountToBePaid[msg.sender];
        //reset winner

        address[] storage _winnersCopy = _winners;
        for( uint256 winnerIndex = 0; winnerIndex < _winnersCopy.length; winnerIndex++){
            address winner = _winnersCopy[winnerIndex];
            if(_isInvalidWinner[winner] || _winners[winnerIndex] == msg.sender){
                //remove invalid winner or winner from list 
                _winners[winnerIndex] = _winners[_winners.length - 1];
                _winners.pop();
                _isInvalidWinner[winner] = false;
                emit RemoveWinner(_winners[winnerIndex]);
            }
        }

        _winnersBuyTimestamp[msg.sender] = 0;
        _winnersAmountToBePaid[msg.sender] = 0;
    }

    
    function setFee(uint256 newFeeAddr1, uint256 newFeeAddr2) external onlyOwner {
        uint256 newFee = newFeeAddr1 + newFeeAddr2;
        //total fee can't be higher than 20%
        require(newFee <= 20);
        _feeAddr1 = newFeeAddr1;
        _feeAddr2 = newFeeAddr2;

        _feeTotal = newFee;
        emit UpdateTaxPercentage(newFee);
    }

    function setCompetitionOnOff(bool onOff) external onlyOwner {
        _iscompetitionOn = onOff;
    }

    function setHoldTime(uint256 newHoldTime) external onlyOwner {
        _holdTime = newHoldTime;
        emit UpdateHoldTime(newHoldTime);
    }

    function setCompetitionTime(uint256 newCompetitonTime) external onlyOwner {
        _competitionTime = newCompetitonTime;
        emit UpdateCompetitionTime(newCompetitonTime);
    }

    function setMinBuyToParticipate(uint256 newMinBuy) external onlyOwner {
        _minBuyToParticipate = newMinBuy;
        emit UpdateMinBuyToParticipate(newMinBuy);
    }

    function setPrize(uint256 newPrize) external onlyOwner {
        _prize = newPrize;
        emit UpdatePrize(newPrize);
    }
    
    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = _uniswapV2Router;
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        swapEnabled = true;
        cooldownEnabled = true;
        _maxTxAmount = 10000000000000000000;
        _feeAddr1 = 5;
        _feeAddr2 = 5;
        _feeTotal = _feeAddr1 + _feeAddr2;
        tradingOpen = true;
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
    }
    
    function setBots(address[] memory bots_) public onlyOwner {
        for (uint i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }
    
    function delBot(address notbot) public onlyOwner {
        bots[notbot] = false;
    }
        
    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        _transferStandard(sender, recipient, amount);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount); 
        _takeTeam(tTeam);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeTeam(uint256 tTeam) private {
        uint256 currentRate =  _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    receive() external payable {}
    
    function manualswap() external {
        require(_msgSender() == _feeAddrWallet1);
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }
    
    function manualsend() external {
        require(_msgSender() == _feeAddrWallet1);
        uint256 contractETHBalance = address(this).balance;
        sendETHToFee(contractETHBalance);
    }
    

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getTValues(tAmount, _feeAddr1, _feeAddr2);
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tTeam, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tTeam);
    }

    function _getTValues(uint256 tAmount, uint256 taxFee, uint256 TeamFee) private pure returns (uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(taxFee).div(100);
        uint256 tTeam = tAmount.mul(TeamFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tTeam);
        return (tTransferAmount, tFee, tTeam);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tTeam, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTeam = tTeam.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rTeam);
        return (rAmount, rTransferAmount, rFee);
    }

	function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _getWinnersLength() public view returns (uint256) {
        return _winners.length;
    }
}