// SPDX-License-Identifier: GPL-3.0



pragma solidity ^0.8.7;

//import "hardhat/console.sol";

// interface IUniswapV3SwapCallback {
//     function uniswapV3SwapCallback(
//         int256 amount0Delta,
//         int256 amount1Delta,
//         bytes calldata data
//     ) external;
// }


// library TransferHelper {
//     function safeTransferFrom(
//         address token,
//         address from,
//         address to,
//         uint256 value
//     ) internal {
//         (bool success, bytes memory data) =
//             token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
//         require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
//     }

//     function safeTransfer(
//         address token,
//         address to,
//         uint256 value
//     ) internal {
//         (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
//         require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
//     }

//     function safeApprove(
//         address token,
//         address to,
//         uint256 value
//     ) internal {
//         (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
//         require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
//     }

//     function safeTransferETH(address to, uint256 value) internal {
//         (bool success, ) = to.call{value: value}(new bytes(0));
//         require(success, 'STE');
//     }
// }

// interface ISwapRouter is IUniswapV3SwapCallback {
//     struct ExactInputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 deadline;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//         uint160 sqrtPriceLimitX96;
//     }

//     function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactInputParams {
//         bytes path;
//         address recipient;
//         uint256 deadline;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//     }

//     function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactOutputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 deadline;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//         uint160 sqrtPriceLimitX96;
//     }

//     function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

//     struct ExactOutputParams {
//         bytes path;
//         address recipient;
//         uint256 deadline;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//     }

//     function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
// }

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}





// interface IWETH9 {
//     function withdraw(uint wad) external ;
// }


contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract Daoclub is ReentrancyGuard, IERC20 {
    
    using SafeMath for uint256;

   // ISwapRouter public swapRouter;

    
    /* erc20 param */
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    /* erc20 param */

    /*遍历成员*/
    mapping(address => bool) private _inserted;
    address[] public _members;

    //todo 如何获取合约的所有代币
    //address[] public _tokenContracts;

    /* daoclub param */
    address private _owner;
    address private _summonerAddress;
    bool private _initialized;
    uint256 public _initTimestamp;
    uint8 public _daoStatus; //0: Fundraising,1: Fundraising completed operation,2: Liquidation in progress,3: Liquidation completed
    
    mapping(address => uint8) public _voteResult; //（0未投票 1yes 2no）
    uint256 public _yesShares;
    uint256 public _noShares;
    uint256 public _gasFeeLimit;
    uint8 public _liquidationPeriod;
    
    uint256 public _totalFund;
    uint256 public _actualFund;
    uint256 public _miniOffering;
    uint256 public _amountOfGrandTotalLiquidation;
    uint8 private _managementFee;
    uint8 private _profitDistribution;
    uint8 private _period;
    uint8 private _duration;
    string public _targetSymbol;  //ETH/USDT/USDC
    IERC20 public _targetToken;
    //IWETH9 private _targetWeth;
    uint256 public _receivableManagementFee;
    bool public _receivedManagementFee;
    
    
    /* daoclub param */


    /***********
    EVENT
    ***********/
    event BuyToken(address indexed buyer, uint256 amount);
    event FundraisingCompleted();
    event SubmitProposal(address indexed daoAddress, address indexed Submitter);
    event SubmitVote(address indexed daoAddress, address indexed voter, uint8 vote, uint256 shares);
    event ProposalSucceeded(address indexed daoAddress, address voter);
    event ProposalFailed(address indexed daoAddress, address voter);
    event LiquidationCompleted(address indexed daoAddress, address memberAddress, uint256 amount, uint256 totalAmount);


    /********
    MODIFIERS
    ********/
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier onlyMember {
        require(_balances[msg.sender] > 0, "Daoclub ::onlyMember - not a member");
        _;
    }

    modifier onlyGpAndLp {
        require(_balances[msg.sender] > 0 || _owner == msg.sender, "Daoclub :: onlyGpAndLp");
        _;
    }

    modifier possibleToByToken {
        require(_daoStatus == 0, "Daoclub Can not buy: status error");
        require(block.timestamp < (_initTimestamp + uint256(_period) * 24 * 3600), "Daoclub Can not buy: Time has expired");
        require(getBalance() <= _totalFund, "Daoclub Can not buy: enough to raise");
        _;
    }

    receive() external payable {
    }


    fallback() external payable {
    }

    function daoStatus() public view returns(uint8 daoStatus_) {
        if(_daoStatus == 0 && block.timestamp > (_initTimestamp + uint256(_period) * 24 * 3600)) {
            daoStatus_ = 1;
        }else {
            daoStatus_ = _daoStatus;
        }
    }

    /**测试完了记得删除**/
    function resetInitTimeStamp(uint256 initTimestamp) external {
        _initTimestamp = initTimestamp;
    }


    function init(
        address summoner,
        string memory tokenSymbol,
        uint256 totalSupply_,
        uint256 totalFund,
        uint256 miniOffering,
        uint8  managementFee,
        uint8  profitDistribution,
        uint8  period,
        uint8  duration,
        address summonerAddress,
        string memory targetSymbol
    ) external {
        require(_initialized == false, "Daoclub: cannot be initialized repeatedly ");
        _initialized = true;
        _owner = summoner;
        _daoStatus = 0;
        _name = tokenSymbol;
        _symbol = tokenSymbol;
        _miniOffering = miniOffering;
        _managementFee = managementFee;
        _profitDistribution = profitDistribution;
        _totalFund = totalFund;
        //铸币
        _mint(address(this), totalSupply_);
        _targetSymbol = targetSymbol;
        if (compareStr(targetSymbol, "USDT")) {
            _targetToken = IERC20(0xB61d1dB83E6478e3daDf22caEb79D1ceC613ab0e); //USDT主网合约地址0xdAC17F958D2ee523a2206206994597C13D831ec7 测试地址0xB61d1dB83E6478e3daDf22caEb79D1ceC613ab0e
        } else if(compareStr(targetSymbol, "USDC")) {
            _targetToken = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);  //USDC合约地址
        } else {
            //_targetToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);  //WETH合约地址 rinnkby 0xDf032Bc4B9dC2782Bb09352007D4C57B75160B15
            //_targetWeth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);   //WETH合约地址 rinnkby 0xDf032Bc4B9dC2782Bb09352007D4C57B75160B15
        }
        _period = period;
        _duration = duration;
        _summonerAddress = summonerAddress;
        _initTimestamp = block.timestamp;
        //swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //SwapRouter合约地址
    }
    


    function withdraw() onlyOwner external {
        if(isETH()) {
            payable(_summonerAddress).transfer(getBalance());
        }else {
            _targetToken.transferFrom(address(this), _summonerAddress, getBalance());
        }
    }



    function buyTokenByETH() possibleToByToken external payable {
        require(isETH(), "Daoclub: target token is not ETH");
        require(address(this).balance <= _totalFund, "Can not buy: enough to raise");
        require(_daoStatus == 0, "Daoclub: status can not buy");
        require(msg.value >= _miniOffering, "Daoclub: miniOffering are not met");
        _actualFund += msg.value;
        //send token
        _transfer(address(this), msg.sender, _totalSupply.mul(msg.value).div(_totalFund));

        emit BuyToken(msg.sender, msg.value);
        
        fundraisingCompleted();
    }


    function buyTokenByUSDTorUSDC(uint256 amount) possibleToByToken external {
        require(!isETH(), "Daoclub: target token is ETH");
        require(_targetToken.balanceOf(address(this)) + amount <= _totalFund, "Can not buy: enough to raise");
        require(_daoStatus == 0, "Daoclub: status can not buy");
        require(amount >= _miniOffering, "Daoclub: miniOffering are not met");
        
        _targetToken.transferFrom(msg.sender, address(this), amount); 
        _actualFund += amount;
        //send token
        _transfer(address(this), msg.sender, _totalSupply.mul(amount).div(_totalFund));

        emit BuyToken(msg.sender, amount);
    
        fundraisingCompleted();
    }

    //募集结束
    function fundraisingCompleted() onlyGpAndLp public {
        if(block.timestamp > (_initTimestamp + uint256(_period) * 24 * 3600) || _actualFund == _totalFund || _totalFund.sub(_actualFund) < _miniOffering) {
            _daoStatus = 1;
            //销毁剩余代币
            if(balanceOf(address(this)) > 0) {
                _burn(address(this), balanceOf(address(this)));
            }
            emit FundraisingCompleted();
        }
    }



    //发起提案
    function submitProposal(uint256 gasFeeLimit, uint8 liquidationPeriod) onlyGpAndLp external {
        require(daoStatus() == 1, " Proposal not allowed in current status ");
        _daoStatus = 2;
        _yesShares = 0;
        _noShares = 0;
        _gasFeeLimit = gasFeeLimit;
        _liquidationPeriod = liquidationPeriod;
        for(uint i = 0; i < _members.length; i++ ) {
            _voteResult[_members[i]] = 0;
        }
        emit SubmitProposal(address(this), msg.sender);
    }


    //提交投票
    function submitVote(uint8 vote) onlyMember external {
        require(_daoStatus == 2, "no Proposal");
        //判断是否投过票
        if(_voteResult[msg.sender] == 0) {
            //没投过
            _voteResult[msg.sender] = vote;
            if(vote == 1) {
                _voteYes();
            }else {
                _voteNo();
            }    
        }else {
            require(_voteResult[msg.sender] != vote, "Can't vote again");
            if(_voteResult[msg.sender] == 1) {
                _yesShares -= _balances[msg.sender];
                _voteNo();
            }else {
                _noShares -= _balances[msg.sender];
                _voteYes();
            }
        }
        
        emit SubmitVote(address(this), msg.sender, vote, _balances[msg.sender].mul(100).div(_totalSupply));

    }

    function _voteYes() internal { 
        _yesShares += _balances[msg.sender];
        if(_yesShares >= _totalSupply.mul(7).div(10)) {
            //投票成功 ， 触发清算， xx时间之后 自动清算 但是我不能在这sleep啊
            //状态变更 投票通过
            _daoStatus = 3;
            //计算应收管理费
            //首先计算管理天数
            uint256 managementDays_ = block.timestamp.sub(_initTimestamp).div(24 * 3600);
            if(managementDays_ > 365 * uint256(_duration)) {
                managementDays_ = 365 * uint256(_duration);
            }
            _receivableManagementFee = _actualFund.mul(_managementFee).div(36500).mul(managementDays_);
            _receivedManagementFee = false;
            

            emit ProposalSucceeded(address(this), msg.sender);
        }
    }

    function _voteNo() internal {
        _noShares += _balances[msg.sender];
        if(_noShares >= _totalSupply.mul(3).div(10)) {
            //本次提案失败，DAO状态回退
            _daoStatus = 1;
            emit ProposalFailed(address(this), msg.sender);
        }
    }

    


    function isETH() internal view returns(bool) {
        return compareStr(_targetSymbol, "ETH");
    }


    // function sellToken() internal returns (uint256 amountOut){
    //     //合约中的币 怎么获取 如果能获取
    //     //遍历目标币合约
    //     for(uint8 i = 0; i< _tokenContracts.length; i++) {
    //         //通过UNISWAP卖出币收回targetSymbol;
    //         // 将资产授权给 swapRouter
    //         TransferHelper.safeApprove(_tokenContracts[i], address(swapRouter), IERC20(_tokenContracts[i]).balanceOf(address(this)));
    //         // amountOutMinimum 在生产环境下应该使用 oracle 或者其他数据来源获取其值
    //         ISwapRouter.ExactInputSingleParams memory params =
    //             ISwapRouter.ExactInputSingleParams({
    //                 tokenIn: _tokenContracts[i],
    //                 tokenOut: address(_targetToken),
    //                 fee: 3000,
    //                 recipient: address(this),
    //                 deadline: block.timestamp,
    //                 amountIn: IERC20(_tokenContracts[i]).balanceOf(address(this)),
    //                 amountOutMinimum: 0,
    //                 sqrtPriceLimitX96: 0
    //             });

    //         amountOut = swapRouter.exactInputSingle(params);

    //     }
    //     if(isETH()) {
    //         //把weth拆封变成eth
    //         _targetWeth.withdraw(_targetToken.balanceOf(address(this)));
    //     }
        

    // }

    
    //清算
    function liquidate() onlyGpAndLp external {
        require(_daoStatus == 3, "Daoclub: yes shares less than 70%");
        //获取结算资金
        uint256 amountOfThisLiquidation_ = getBalance();
        if(!_receivedManagementFee) {    
            require(amountOfThisLiquidation_ > _receivableManagementFee, "Daoclub: Insufficient amount");
            if(isETH()) {
                payable(_summonerAddress).transfer(_receivableManagementFee);
            }else {
                _targetToken.transferFrom(address(this), _summonerAddress, _receivableManagementFee);
            }
            _receivedManagementFee = true;
            amountOfThisLiquidation_ = amountOfThisLiquidation_.sub(_receivableManagementFee);

        }

        //先来一波卖币逻辑
        //sellToken();

        
        uint256 gpProfit_ = 0;
        if((amountOfThisLiquidation_ + _amountOfGrandTotalLiquidation) > _actualFund) {
            //分利润
            uint256 profit_;
            if(_amountOfGrandTotalLiquidation < _actualFund) {
                profit_ = amountOfThisLiquidation_ + _amountOfGrandTotalLiquidation - _actualFund;
            }else {
                profit_ = amountOfThisLiquidation_;
            }
            //先分gp
            gpProfit_ = profit_.mul(_profitDistribution).div(100);
            if(isETH()) {
                payable(_summonerAddress).transfer(gpProfit_);
            }else {
                _targetToken.transferFrom(address(this), _summonerAddress, gpProfit_);
            }
            amountOfThisLiquidation_ -= gpProfit_;
            //emit LiquidationCompleted(address(this), _owner, gpProfit_, _fundShare());
        }
        for(uint i = 0; i < _members.length; i++ ) {
            if(_balances[_members[i]] > 0) {
                uint256 distributeProfit_ = amountOfThisLiquidation_.mul(_balances[_members[i]]).div(_totalSupply);
                if(isETH()) {
                    payable(_members[i]).transfer(distributeProfit_);
                }else {
                    _targetToken.transferFrom(address(this), _members[i], distributeProfit_);
                }
                emit LiquidationCompleted(address(this), _members[i], distributeProfit_, _fundShare(_members[i]));
            }
        }
        _amountOfGrandTotalLiquidation = _amountOfGrandTotalLiquidation + amountOfThisLiquidation_ + gpProfit_;
        

        
    }



    function getBalance() public view returns (uint256) {
        if(isETH()) {
            return address(this).balance;
        }else {
            return _targetToken.balanceOf(address(this));
        }
    }



    
    /* erc20 function */
    function name() public view virtual  returns (string memory) {
        return _name;
    }

    function symbol() public view virtual  returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual  returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
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

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
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
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(_daoStatus == 0 || _daoStatus == 1, "The current DAO state cannot be traded");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        if(!_inserted[to]) {
            _inserted[to] = true;
            _members.push(to);
        }
            
        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        if(!_inserted[account]) {
            _inserted[account] = true;
            _members.push(account);
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
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

    /* erc20 function */



    /* util function */

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function compareStr(string memory _str, string memory str) public pure returns (bool) {
        return keccak256(abi.encodePacked(_str)) == keccak256(abi.encodePacked(str));
    }

    function _checkOwner() internal view virtual {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
    }

    function _fundShare(address member) internal view returns (uint256) {
        return _actualFund.mul(_balances[member]).div(_totalSupply);
    }

    

    /* util function */
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {

        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }
}



/*
The MIT License (MIT)
Copyright (c) 2018 Murray Software, LLC.
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:
The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
contract CloneFactory { // implementation of eip-1167 - see https://eips.ethereum.org/EIPS/eip-1167
    function createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
    }
}

contract DaoclubSummoner is CloneFactory { 
    
    address public _template;
    address _owner;
    Daoclub private _daoclub; // daoclub contract
    address[] public _summonedDaoclub;
    uint public _daoIdx = 0;
    
    constructor(address template) {
        _template = payable(template);
        _owner = msg.sender;
    }
    
    event SummonComplete(address indexed daoclub, address summoner);
    


    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function resetTemplate(address template) onlyOwner external {
        _template = payable(template);
    }
    
     
    function summonDaoclub(
        address summoner,
        string memory tokenSymbol,
        uint256 totalSupply,
        uint256 totalFund,
        uint256 miniOffering,
        uint8  managementFee,
        uint8  profitDistribution,
        uint8  period,
        uint8  duration,
        address summonerAddress,
        string memory targetSymbol
    ) public returns (address) {
        _daoclub = Daoclub(payable(createClone(_template)));
        _daoclub.init(
            summoner,
            tokenSymbol,
            totalSupply,
            totalFund,
            miniOffering,
            managementFee,
            profitDistribution,
            period,
            duration,
            summonerAddress,
            targetSymbol
        );
        _summonedDaoclub.push(address(_daoclub));
        _daoIdx ++;
       
        emit SummonComplete(address(_daoclub), summoner);
        return address(_daoclub);
    }
    
}