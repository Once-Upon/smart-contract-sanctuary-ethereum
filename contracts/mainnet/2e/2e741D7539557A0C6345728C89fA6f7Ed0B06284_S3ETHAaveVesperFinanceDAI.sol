// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IUniswapConnector.sol";
import "./interfaces/IAave.sol";
import "./interfaces/IS3Proxy.sol";
import "./interfaces/IS3Admin.sol";
import "./proxies/S3ETHAaveVesperFinanceDAIProxy.sol";


interface IFees {
    function feeCollector(uint256 _index) external view returns (address);
    function depositStatus(uint256 _index) external view returns (bool);
    function calcFee(
        uint256 _strategyId,
        address _user,
        address _feeToken
    ) external view returns (uint256);
}


contract S3ETHAaveVesperFinanceDAI {
    uint8 public constant strategyIndex = 11;
    address public s3Admin;
    address public feesAddress;
    address public uniswapConnector;
    address public wethAddress;
    address public daiAddress;
    
    // protocols
    address public vPoolDAI;
    address public vPoolRewardsDAI;
    address public vspToken;
    mapping(address => address) public depositors; 

    constructor(
        address _s3Admin,
        address _feesAddress,
        address _uniswapConnector,
        address _wethAddress,
        address _daiAddress,
        address _vPoolDAI,
        address _vPoolRewardsDAI,
        address _vspToken
    ) {
        s3Admin = _s3Admin;
        feesAddress = _feesAddress;
        uniswapConnector = _uniswapConnector;
        wethAddress = _wethAddress;
        daiAddress = _daiAddress;
        vPoolDAI = _vPoolDAI;
        vPoolRewardsDAI = _vPoolRewardsDAI;
        vspToken = _vspToken;

        IERC20(daiAddress).approve(uniswapConnector, 2**256 - 1);
        IERC20(vspToken).approve(uniswapConnector, 2**256 - 1);
    }

    event Deposit(address indexed _depositor, address indexed _token, uint256 _amountIn);

    event Withdraw(address indexed _depositor, uint8 _percentage, uint256 _amount, uint256 _fee);

    event WithdrawCollateral(address indexed _depositor, uint8 _percentage, uint256 _amount, uint256 _fee);

    event ClaimAdditionalTokens(address indexed _depositor, uint256 _amount0, uint256 _amount1, address indexed _swappedTo);

    // Get the current unclaimed VSP tokens amount
    function getPendingAdditionalTokenClaims(address _address) external view returns(address[] memory _rewardTokens, uint256[] memory _claimableAmounts) {
        return IVPoolRewards(vPoolRewardsDAI).claimable(depositors[_address]);
    }   
    
    // Get the current Vesper Finance deposit
    function getCurrentDeposit(address _address) external view returns(uint256, uint256) {
        uint256 vaDAIShare = IERC20(vPoolDAI).balanceOf(depositors[_address]);
        uint256 daiEquivalent;
        if (vaDAIShare > 0) {
            uint256 pricePerShare = IVPoolDAI(vPoolDAI).pricePerShare();
            daiEquivalent = (pricePerShare * vaDAIShare) / 10 ** 18;
        }
        
        return (vaDAIShare, daiEquivalent);
    }

    function getCurrentDebt(address _address) external view returns(uint256) {
        return IERC20(IS3Admin(s3Admin).interestTokens(strategyIndex)).balanceOf(depositors[_address]);
    }

    function getMaxUnlockedCollateral(address _address) external view returns(uint256) {
        (, uint256 totalDebtETH, , uint256 currentLiquidationThreshold, , ) = IAave(IS3Admin(s3Admin).aave()).getUserAccountData(depositors[_address]);
        uint256 maxAmountToBeWithdrawn;
        if (totalDebtETH > 0) {
            maxAmountToBeWithdrawn = (10100 * totalDebtETH) / currentLiquidationThreshold;
            maxAmountToBeWithdrawn = IERC20(IS3Admin(s3Admin).aWETH()).balanceOf(depositors[_address]) - maxAmountToBeWithdrawn;
        } else {
            maxAmountToBeWithdrawn = IERC20(IS3Admin(s3Admin).aWETH()).balanceOf(depositors[_address]); 
        }
        return maxAmountToBeWithdrawn;
    }

    // Get the current Aave status
    function getAaveStatus(address _address) external view returns(uint256, uint256, uint256, uint256, uint256, uint256) {
        return IAave(IS3Admin(s3Admin).aave()).getUserAccountData(depositors[_address]); 
    }

    function depositETH(uint8 _borrowPercentage, bool _borrowAndDeposit) public payable {
        require(IFees(feesAddress).depositStatus(strategyIndex), "ERR: DEPOSITS_STOPPED");
        if (_borrowAndDeposit) {
            require(IS3Admin(s3Admin).whitelistedAaveBorrowPercAmounts(_borrowPercentage), "ERROR: INVALID_BORROW_PERC");
        }

        if (depositors[msg.sender] == address(0)) { 
            // deploy new proxy contract
            S3ETHAaveVesperFinanceDAIProxy s3proxy = new S3ETHAaveVesperFinanceDAIProxy(
                address(this),
                uniswapConnector,
                wethAddress,
                daiAddress,
                vPoolDAI, 
                vPoolRewardsDAI,
                vspToken,
                IS3Admin(s3Admin).aave(),
                IS3Admin(s3Admin).aaveEth(),
                IS3Admin(s3Admin).aWETH()
            );
            s3proxy.setupAddresses(
                IS3Admin(s3Admin).aavePriceOracle(),
                IS3Admin(s3Admin).interestTokens(strategyIndex),
                s3Admin
            );
            depositors[msg.sender] = address(s3proxy);
            s3proxy.depositETH{value: msg.value}(_borrowPercentage, _borrowAndDeposit);
        } else {
            // send the deposit to the existing proxy contract
            IS3Proxy(depositors[msg.sender]).depositETH{value: msg.value}(_borrowPercentage, _borrowAndDeposit); 
        }

        emit Deposit(msg.sender, wethAddress, msg.value);
    }

    // claim VSP tokens and withdraw them
    function claimRaw() external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");
        uint256 truTokens = IS3Proxy(depositors[msg.sender]).claimToDepositor(msg.sender); 

        emit ClaimAdditionalTokens(msg.sender, truTokens, 0, address(0));
    }

    // claim VSP tokens, swap them for ETH and withdraw
    function claimInETH(uint256 _amountOutMin) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");
        uint256 vspTokens = IS3Proxy(depositors[msg.sender]).claimToDeployer();

        uint256 wethAmount = IUniswapConnector(uniswapConnector).swapTokenForToken(
            vspToken,
            wethAddress,
            vspTokens,
            _amountOutMin,
            address(this)
        );

        // swap WETH for ETH
        IWETH(wethAddress).withdraw(wethAmount);
        // withdraw ETH
        (bool success, ) = payable(msg.sender).call{value: wethAmount}("");
        require(success, "ERR: FAIL_SENDING_ETH");

        emit ClaimAdditionalTokens(msg.sender, vspTokens, wethAmount, wethAddress);
    }

    // claim VSP tokens, swap them for _token and withdraw
    function claimInToken(address _token, uint256 _amountOutMin) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR"); 

        uint256 vspTokens = IS3Proxy(depositors[msg.sender]).claimToDeployer();
        uint256 tokenAmount = IUniswapConnector(uniswapConnector).swapTokenForToken(
            vspToken, 
            _token,
            vspTokens, 
            _amountOutMin, 
            msg.sender
        );

        emit ClaimAdditionalTokens(msg.sender, vspTokens, tokenAmount, _token);
    } 

    function withdraw(uint8 _percentage, address _feeToken) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR"); 

        (uint256 ethAmountToBeWithdrawn, uint256 amountOut) = IS3Proxy(depositors[msg.sender]).withdraw(_percentage); 
        if (amountOut > 0) {
            ethAmountToBeWithdrawn += _swapYieldProfitToCollateral(depositors[msg.sender], amountOut);
        }
        
        uint256 fee = (ethAmountToBeWithdrawn * IFees(feesAddress).calcFee(strategyIndex, msg.sender, _feeToken)) / 1000;
        if (fee > 0) {
            (bool success0, ) = payable(IFees(feesAddress).feeCollector(strategyIndex)).call{value: fee}("");
            require(success0, "ERR: FAIL_SENDING_FEE_ETH");
        }
        (bool success1, ) = payable(msg.sender).call{value: ethAmountToBeWithdrawn - fee}("");
        require(success1, "ERR: FAIL_SENDING_FEE_ETH");

        emit Withdraw(msg.sender, _percentage, ethAmountToBeWithdrawn, fee);
    }

    function withdrawCollateral(uint8 _percentage, address _feeToken) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");

        (uint256 ethAmountToBeWithdrawn, ) = IS3Proxy(depositors[msg.sender]).withdrawCollateral(_percentage);
        uint256 fee = (ethAmountToBeWithdrawn * IFees(feesAddress).calcFee(strategyIndex, msg.sender, _feeToken)) / 1000;
        if (fee > 0) {
            (bool success0, ) = payable(IFees(feesAddress).feeCollector(strategyIndex)).call{value: fee}("");
            require(success0, "ERR: FAIL_SENDING_FEE_ETH");
        }
        (bool success1, ) = payable(msg.sender).call{value: ethAmountToBeWithdrawn - fee}("");
        require(success1, "ERR: FAIL_SENDING_ETH");

        emit WithdrawCollateral(msg.sender, _percentage, ethAmountToBeWithdrawn, fee);
    }

    function emergencyWithdraw(address _token) external {
        require(!IFees(feesAddress).depositStatus(strategyIndex), "ERR: DEPOSITS_ARE_ON");
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");

        IS3Proxy(depositors[msg.sender]).emergencyWithdraw(_token, msg.sender);
    }

    function _swapYieldProfitToCollateral(address _proxy, uint256 _amountOutMin) private returns(uint256) {
        uint256 proxyDAIBalance = IERC20(daiAddress).balanceOf(_proxy);
        if (proxyDAIBalance > 0) {
            IERC20(daiAddress).transferFrom(_proxy, address(this), proxyDAIBalance);

            uint256 wethAmount = IUniswapConnector(uniswapConnector).swapTokenForToken(
                daiAddress, 
                wethAddress,
                IERC20(daiAddress).balanceOf(address(this)), 
                _amountOutMin, 
                address(this)
            );

            // swap WETH for ETH
            IWETH(wethAddress).withdraw(wethAmount);

            return wethAmount;
        } else {
            return 0;
        } 
    }

    receive() external payable {} 
}

// MN bby ¯\_(ツ)_/¯

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IERC20 {
    function decimals() external view returns (uint8);

    function balanceOf(address _owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external;

    function transfer(address recipient, uint256 amount) external;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IWETH {
    function withdraw(uint wad) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IS3Proxy {
    function depositETH(uint8 _borrowPercentage, bool _borrowAndDeposit) external payable;

    function deposit(address _token, uint256 _amount, uint8 _borrowPercentage, bool _borrowAndDeposit) external;

    function withdraw(uint8 _percentage) external returns(uint256, uint256);

    function withdrawCollateral(uint8 _percentage) external returns(uint256, uint256);

    function emergencyWithdraw(address _token, address _depositor) external;

    function claimToDepositor(address _depositor) external returns(uint256);

    function claimToDeployer() external returns(uint256);

    function setupAddresses(
        address _aavePriceOracle,
        address _aaveInterestDAI,
        address _s3Admin
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;


interface IS3Admin {
    function interestTokens(uint8 _strategyIndex) external view returns (address);
    function whitelistedAaveBorrowPercAmounts(uint8 _amount) external view returns (bool);
    function aave() external view returns (address);
    function aaveEth() external view returns (address);
    function aavePriceOracle() external view returns (address);
    function aWETH() external view returns (address);
    function slippage() external view returns (uint8);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IAave {
    function deposit(
        address asset, 
        uint256 amount, 
        address onBehalfOf, 
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount, 
        address to
    ) external returns (uint256);

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function swapBorrowRateMode(address asset, uint256 rateMode) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);

    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

interface IAaveETH {
    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;

    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address to
    ) external;
}

interface IPriceOracleGetter {
    function getAssetPrice(address asset) external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IUniswapConnector {
    function getTokenFee(address _token) external view returns(uint24);

    function uniswapV3Router02() external view returns (address);

    function swapTokenForToken(address _tokenIn, address _tokenOut, uint256 _amount, uint256 _amountOutMin, address _to) external returns(uint256);

    function swapTokenForTokenV3ExactOutput(address _tokenIn, address _tokenOut, uint256 _amount, uint256 _amountInMaximum, address _to) external payable returns(uint256);
    
    function swapETHForToken(address _tokenOut, uint256 _amount, uint256 _amountOutMin, address _to) external payable returns(uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IS3Admin.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IAave.sol";
import "../interfaces/IVesperFinance.sol";
import "../interfaces/IQuoter.sol";
import "../interfaces/IUniswapConnector.sol";


contract S3ETHAaveVesperFinanceDAIProxy {
    uint8 private constant defaultInterestRate = 2;
    address private quoterAddress = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address private deployer;
    address private uniswapConnector;
    address private wethAddress;
    address private daiAddress;
    address private vPoolDAI;
    address private vPoolRewardsDAI;
    address private vspToken;
    address private aave;
    address private aaveEth;
    address private aavePriceOracle;
    address private aWETH;
    address private aaveInterestDAI;
    address private s3Admin;

    constructor(
        address _deployer,
        address _uniswapConnector,
        address _wethAddress,
        address _daiAddress,
        address _vPoolDAI,
        address _vPoolRewardsDAI,
        address _vspToken,
        address _aave,
        address _aaveEth,
        address _aWETH
    ) {
        deployer = _deployer;
        uniswapConnector = _uniswapConnector;
        wethAddress = _wethAddress;
        daiAddress = _daiAddress;
        vPoolDAI = _vPoolDAI;
        vPoolRewardsDAI = _vPoolRewardsDAI;
        vspToken = _vspToken;
        aave = _aave;
        aaveEth = _aaveEth;
        aWETH = _aWETH;

        // Allow for ETH collateral withdrawals
        IERC20(aWETH).approve(aaveEth, 2**256 - 1);
        // Give Aave lending protocol approval - needed when repaying the DAI loan
        IERC20(daiAddress).approve(aave, 2**256 - 1);
        // Give S3AaveVesperFinanceDAI DAI approval - needed when sending the DAI rewards to the depositor
        IERC20(daiAddress).approve(deployer, 2**256 - 1);
        // Allow Vesper Finance protocol to take DAI from the proxy
        IERC20(daiAddress).approve(vPoolDAI, 2**256 - 1);
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, "ERR: WRONG_DEPLOYER");
        _;
    }

    function setupAddresses(
        address _aavePriceOracle,
        address _aaveInterestDAI,
        address _s3Admin
    ) external onlyDeployer {
        aavePriceOracle = _aavePriceOracle;
        aaveInterestDAI = _aaveInterestDAI;
        s3Admin = _s3Admin;
    }

    function depositETH(uint8 _borrowPercentage, bool _borrowAndDeposit) external payable onlyDeployer {
        (, , uint256 availableBorrowsETH, , ,) = IAave(aave).getUserAccountData(address(this));

        // supply to Aave protocol
        IAaveETH(aaveEth).depositETH{value: msg.value}(aave, address(this), 0); 

        // Aave borrow & TrueFi deposit
        if (_borrowAndDeposit) {
            (, , uint256 availableBorrowsETHAfterDeposit, , ,) = IAave(aave).getUserAccountData(address(this));
            // borrow DAI from Aave protocol
            uint256 maxAmountToBeBorrowedForThisDeposit = ((availableBorrowsETHAfterDeposit - availableBorrowsETH) * 10 ** IERC20(daiAddress).decimals()) / IPriceOracleGetter(aavePriceOracle).getAssetPrice(daiAddress); 
            IAave(aave).borrow(
                daiAddress,
                (maxAmountToBeBorrowedForThisDeposit * _borrowPercentage) / 100,
                defaultInterestRate,
                0,
                address(this)
            );

            // Vesper Finance deposit
            IVPoolDAI(vPoolDAI).deposit(IERC20(daiAddress).balanceOf(address(this)));
        }
    }

    function withdraw(uint8 _percentage) external onlyDeployer returns(uint256, uint256) {
        IVPoolDAI(vPoolDAI).withdraw((IERC20(vPoolDAI).balanceOf(address(this)) * _percentage) / 100);

        // repay the DAI loan to Aave protocol
        uint256 currentDebt = IERC20(aaveInterestDAI).balanceOf(address(this));
        uint256 borrowAssetBalance = IERC20(daiAddress).balanceOf(address(this));
        uint256 currentDebtAfterRepaying;
        if (borrowAssetBalance > (currentDebt * _percentage) / 100) {
            // full repay
            _aaveRepay((currentDebt * _percentage) / 100, address(this));
        } else {
            // partly repay
            _aaveRepay(borrowAssetBalance, address(this));
            currentDebtAfterRepaying = (currentDebt * _percentage) / 100 - borrowAssetBalance;
        }

        return _withdrawCollateral(
            _percentage,
            currentDebtAfterRepaying
        );
    }

    function withdrawCollateral(uint8 _percentage) external onlyDeployer returns(uint256, uint256) {
        return _withdrawCollateral(_percentage, 0);
    }

    function _withdrawCollateral(uint8 _percentage, uint256 _currentDebtAfterRepaying) private returns(uint256, uint256) {
        // if there is debt sell part of the collateral to cover it
        if (_currentDebtAfterRepaying > 0) {
            uint256 amountIn = IQuoter(quoterAddress).quoteExactOutput(
                abi.encodePacked(daiAddress, IUniswapConnector(uniswapConnector).getTokenFee(daiAddress), wethAddress), 
                _currentDebtAfterRepaying
            );
            amountIn = (amountIn * (100 + IS3Admin(s3Admin).slippage())) / 100;

            _aaveWithdraw(amountIn, address(this));
            
            IUniswapConnector(uniswapConnector).swapTokenForTokenV3ExactOutput{value: amountIn}(
                wethAddress, 
                daiAddress,
                _currentDebtAfterRepaying,
                amountIn,
                address(this)
            );

            _aaveRepay(IERC20(daiAddress).balanceOf(address(this)), address(this));
            uint256 maxAmountToBeWithdrawnAfterRepay = _calculateMaxAmountToBeWithdrawn();
            if (_percentage != 100) {
                maxAmountToBeWithdrawnAfterRepay = (maxAmountToBeWithdrawnAfterRepay * _percentage) / 100;
            }

            // withdraw rest of the unlocked collateral after repaying the loan
            _aaveWithdraw(maxAmountToBeWithdrawnAfterRepay, address(this));
            uint256 currentEthBalance = address(this).balance;
            payable(deployer).transfer(currentEthBalance);

            return (currentEthBalance, 0);
        } else {
            uint256 maxAmountToBeWithdrawn = _calculateMaxAmountToBeWithdrawn();
            if (_percentage != 100) {
                maxAmountToBeWithdrawn = (maxAmountToBeWithdrawn * _percentage) / 100;
            }

            uint256 amountOut;
            uint256 currentDAIBalance = IERC20(daiAddress).balanceOf(address(this));
            if (currentDAIBalance > 0) {
                amountOut = IQuoter(quoterAddress).quoteExactInput(
                    abi.encodePacked(daiAddress, IUniswapConnector(uniswapConnector).getTokenFee(daiAddress), wethAddress), 
                    currentDAIBalance
                );
                amountOut = (amountOut * (100 - IS3Admin(s3Admin).slippage())) / 100;
            }
                
            _aaveWithdraw(maxAmountToBeWithdrawn, deployer);
            return (maxAmountToBeWithdrawn, amountOut);
        }
    }

    function emergencyWithdraw(address _token, address _depositor) external onlyDeployer {
        IERC20(_token).transfer(_depositor, IERC20(_token).balanceOf(address(this)));
    }

    function _calculateMaxAmountToBeWithdrawn() private view returns(uint256) {
        (, uint256 totalDebtETH, , uint256 currentLiquidationThreshold, , ) = IAave(aave).getUserAccountData(address(this));
        uint256 maxAmountToBeWithdrawn;
        if (totalDebtETH > 0) {
            maxAmountToBeWithdrawn = (10100 * totalDebtETH) / currentLiquidationThreshold;
            maxAmountToBeWithdrawn = IERC20(aWETH).balanceOf(address(this)) - maxAmountToBeWithdrawn;
        } else {
            maxAmountToBeWithdrawn = IERC20(aWETH).balanceOf(address(this)); 
        }

        return maxAmountToBeWithdrawn;
    }

    function _aaveRepay(uint256 _amount, address _to) private {
        IAave(aave).repay(
            daiAddress, 
            _amount,
            defaultInterestRate, 
            _to
        );
    }

    function _aaveWithdraw(uint256 _amount, address _to) private {
        IAaveETH(aaveEth).withdrawETH(
            aave,
            _amount, 
            _to
        );
    }

    function claimToDepositor(address _depositor) external onlyDeployer returns(uint256) {
        return _claim(_depositor);
    }

    function claimToDeployer() external onlyDeployer returns(uint256) {
        return _claim(deployer);
    }

    function _claim(address _address) private returns(uint256) {
        // VSP tokens
        IVPoolRewards(vPoolRewardsDAI).claimReward(address(this));

        uint256 vspBalance = IERC20(vspToken).balanceOf(address(this));
        IERC20(vspToken).transfer(
            _address,
            vspBalance
        );

        return vspBalance;
    }

    receive() external payable {} 
    fallback() external payable {}
}

// MN bby ¯\_(ツ)_/¯

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IVPoolDAI {
    function deposit(uint256 _amount) external;

    function withdraw(uint256 _shares) external;

    function pricePerShare() external view returns (uint256);
}


interface IVPoolETH {
    function deposit() external payable;

    function withdrawETH(uint256 _shares) external;

    function pricePerShare() external view returns (uint256);
}


interface IVPoolRewards {
    function claimable(address _account) external view returns (
        address[] memory _rewardTokens,
        uint256[] memory _claimableAmounts
    );

    function claimReward(address _account) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);

    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountIn);

    function quoteExactInput(
        bytes memory path,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function quoteExactOutput(
        bytes memory path,
        uint256 amountOut
    ) external returns (uint256 amountIn);
}