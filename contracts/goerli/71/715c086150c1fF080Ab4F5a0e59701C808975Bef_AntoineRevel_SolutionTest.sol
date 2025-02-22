pragma solidity ^0.6.2;
import "./Evaluator.sol";
import "./DummyToken.sol";

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AntoineRevel_SolutionTest {
    Evaluator evaluator;
    ERC20 tdToken;
    IExerciceSolution solution;
    bool isStarted;

    IUniswapV2Router02 uniswapRouter;
    DummyToken dummyToken;
    IERC20 private weth;


    constructor(IExerciceSolution _solution, Evaluator _evaluator,address _uniswapRouterAddress,DummyToken _dummyToken,address _tdToken) public{
        evaluator = _evaluator;
        tdToken=ERC20(_tdToken);
        solution = _solution;
        isStarted=false;
        uniswapRouter=IUniswapV2Router02(_uniswapRouterAddress);
        dummyToken=_dummyToken;
        weth=IERC20(uniswapRouter.WETH());
    }

    function startClaimPoint() public {
        require(!isStarted,"Already started !");
        isStarted=true;

        evaluator.ex1_showIHaveTokens();
        //evaluator.submitExercice(solution);
    }

    function buyToken() public payable {

        address [] memory path  = new address[](2);
        path[0] = address(weth);
        path[1]= address(dummyToken);
        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{ value: address(this).balance }(0, path, address(this), block.timestamp + 15);

    }


    function getPoint() public view returns (uint256){
        return tdToken.balanceOf(address(this));
    }

    function getFactory() public view returns (address){
        return uniswapRouter.factory();
    }

    receive() external payable {}
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
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

pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRichERC20 is IERC20 
{

  function symbol() external view returns (string memory);
}

pragma solidity ^0.6.0;

interface IExerciceSolution 
{
	function addLiquidity() external;

	function withdrawLiquidity() external;

	function swapYourTokenForDummyToken() external;

	function swapYourTokenForEth() external;
}

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./ERC20TD.sol";
import "./IExerciceSolution.sol";
import "./IRichERC20.sol";
import "./utils/IUniswapV2Factory.sol";
import "./utils/IUniswapV2Pair.sol";

contract Evaluator 
{

	mapping(address => bool) public teachers;
	ERC20TD public TDAMM;

	ERC20 public dummyToken;
	IUniswapV2Factory public uniswapV2Factory;
	address public WETH;

	uint256[20] private randomSupplies;
	string[20] private randomTickers;
 	uint public nextValueStoreRank;

 	mapping(address => string) public assignedTicker;
 	mapping(address => uint256) public assignedSupply;
 	mapping(address => mapping(uint256 => bool)) public exerciceProgression;
 	mapping(address => IRichERC20) public studentErc20;
 	mapping(address => IExerciceSolution) public studentExercice;
 	mapping(address => bool) public hasBeenPaired;

 	event newRandomTickerAndSupply(string ticker, uint256 supply);
 	event constructedCorrectly(address erc20Address, address dummyTokenAddress, address uniFactoryAddress, address wethAddress);
	constructor(ERC20TD _TDAMM, ERC20 _dummyToken, IUniswapV2Factory _uniswapV2Factory, address _WETH) 
	public 
	{
		TDAMM = _TDAMM;
		dummyToken = _dummyToken;
		uniswapV2Factory = _uniswapV2Factory;
		WETH = _WETH;
		emit constructedCorrectly(address(TDAMM), address(_dummyToken), address(_uniswapV2Factory), _WETH);

	}

	fallback () external payable 
	{}

	receive () external payable 
	{}

	function ex1_showIHaveTokens()
	public
	{
		require(dummyToken.balanceOf(msg.sender) > 0, "You do not hold dummyTokens. Buy them on Uniswap");

		if (!exerciceProgression[msg.sender][1])
		{
			exerciceProgression[msg.sender][1] = true;
			TDAMM.distributeTokens(msg.sender, 2);
		}

	}

	function ex2_showIProvidedLiquidity()
	public
	{
		// Getting address from factory for pair dummyToken / WETH
		(address token0, address token1) = address(dummyToken) < WETH ? (address(dummyToken), WETH) : (WETH, address(dummyToken));
		address dummyTokenAndWethPair = uniswapV2Factory.getPair(token0, token1);

		// Checking if caller holds LP token
		ERC20 dummyTokenAndWethPairAsERC20 = ERC20(dummyTokenAndWethPair);
		require(dummyTokenAndWethPairAsERC20.balanceOf(msg.sender) > 0, "You do not hold liquidity in the required pool");
		if (!exerciceProgression[msg.sender][2])
		{
			exerciceProgression[msg.sender][2] = true;
			TDAMM.distributeTokens(msg.sender, 2);
		}
	}

	function ex6a_getTickerAndSupply()
	public
	{
		assignedSupply[msg.sender] = randomSupplies[nextValueStoreRank]*1000000000000000000;
		// assignedTicker[msg.sender] = bytes32ToString(randomTickers[nextValueStoreRank]);
		assignedTicker[msg.sender] = randomTickers[nextValueStoreRank];

		nextValueStoreRank += 1;
		if (nextValueStoreRank >= 20)
		{
			nextValueStoreRank = 0;
		}

		// Crediting points
		if (!exerciceProgression[msg.sender][5])
		{
			exerciceProgression[msg.sender][5] = true;
			TDAMM.distributeTokens(msg.sender, 2);
		}
	}

	function ex6b_testErc20TickerAndSupply()
	public
	{
		// Checking ticker and supply were received
		require(exerciceProgression[msg.sender][5]);

		// Checking ticker was set properly
		require(_compareStrings(assignedTicker[msg.sender], studentErc20[msg.sender].symbol()), "Incorrect ticker");
		// Checking supply was set properly
		require(assignedSupply[msg.sender] == studentErc20[msg.sender].totalSupply(), "Incorrect supply");
		// Checking some ERC20 functions were created
		require(studentErc20[msg.sender].allowance(address(this), msg.sender) == 0, "Allowance not implemented or incorrectly set");
		require(studentErc20[msg.sender].balanceOf(address(this)) == 0, "BalanceOf not implemented or incorrectly set");
		require(studentErc20[msg.sender].approve(msg.sender, 10), "Approve not implemented");

		// Crediting points
		if (!exerciceProgression[msg.sender][6])
		{
			exerciceProgression[msg.sender][6] = true;
			// Creating ERC20
			TDAMM.distributeTokens(msg.sender, 2);
		}

	}

	function ex7_tokenIsTradableOnUniswap()
	public
	{
		// Retrieving address of pair from library
		(address token0, address token1) = address(studentErc20[msg.sender]) < WETH ? (address(studentErc20[msg.sender]), WETH) : (WETH, address(studentErc20[msg.sender]));
		address studentTokenAndWethPair = uniswapV2Factory.getPair(token0, token1);

		require(studentTokenAndWethPair != address(0));

		// Crediting points
		if (!exerciceProgression[msg.sender][7])
		{
			exerciceProgression[msg.sender][7] = true;
			// Creating ERC20
			TDAMM.distributeTokens(msg.sender, 5);
		}

	}

	function ex8_contractCanSwapVsEth()
	public
	{
		// Retrieving address of pair from library
		(address token0, address token1) = address(studentErc20[msg.sender]) < WETH ? (address(studentErc20[msg.sender]), WETH) : (WETH, address(studentErc20[msg.sender]));
		address studentTokenAndWethPair = uniswapV2Factory.getPair(token0, token1);

		// Checking pair balance before calling exercice contract
		IUniswapV2Pair studentTokenAndWethPairInstance = IUniswapV2Pair(studentTokenAndWethPair);
		(uint112 reserve0, uint112 reserve1, ) = studentTokenAndWethPairInstance.getReserves();

		// Checking caller balance before executing contract
		uint initBalance = studentErc20[msg.sender].balanceOf(address(studentExercice[msg.sender]));

		// Calling student contract to tell him to provide liquidity
		studentExercice[msg.sender].swapYourTokenForEth();

		// Checking pair balance after calling exercice contract
		(uint112 reserve3, uint112 reserve4,) = studentTokenAndWethPairInstance.getReserves();
		require((reserve0 != reserve3) && (reserve1 != reserve4), "No liquidity change in your token's pool");

		// Checking your token balance after calling the exercice
		uint endBalance = studentErc20[msg.sender].balanceOf(address(studentExercice[msg.sender]));
		require(initBalance != endBalance, "You still have the same amount of tokens");

		// Crediting points
		if (!exerciceProgression[msg.sender][8])
		{
			exerciceProgression[msg.sender][8] = true;
			// Creating ERC20
			TDAMM.distributeTokens(msg.sender, 1);
		}

	}

	function ex9_contractCanSwapVsDummyToken()
	public
	{
		// Retrieving address of pair from library
		(address token0, address token1) = address(studentErc20[msg.sender]) < address(dummyToken) ? (address(studentErc20[msg.sender]), address(dummyToken)) : (address(dummyToken), address(studentErc20[msg.sender]));
		address studentTokenAndWethPair = uniswapV2Factory.getPair(token0, token1);

		// Checking pair balance before calling exercice contract
		IUniswapV2Pair studentTokenAndWethPairInstance = IUniswapV2Pair(studentTokenAndWethPair);
		(uint112 reserve0, uint112 reserve1, ) = studentTokenAndWethPairInstance.getReserves();
		
		// Checking caller balance before executing contract
		uint initTokenBalance = studentErc20[msg.sender].balanceOf(address(studentExercice[msg.sender]));
		uint initDummyBalance = dummyToken.balanceOf(address(studentExercice[msg.sender]));

		// Calling student contract to tell him to provide liquidity
		studentExercice[msg.sender].swapYourTokenForDummyToken();

		// Checking pair balance after calling exercice contract
		(uint112 reserve3, uint112 reserve4,) = studentTokenAndWethPairInstance.getReserves();
		require((reserve0 != reserve3) && (reserve1 != reserve4), "No liquidity change in your token's pool");

		// Checking your token balance after calling the exercice
		uint endTokenBalance = studentErc20[msg.sender].balanceOf(address(studentExercice[msg.sender]));
		require(initTokenBalance != endTokenBalance, "You still have the same amount of your tokens");
		uint endDummyBalance = dummyToken.balanceOf(address(studentExercice[msg.sender]));
		require(initDummyBalance != endDummyBalance, "You still have the same amount of dummy tokens");

		// Crediting points
		if (!exerciceProgression[msg.sender][9])
		{
			exerciceProgression[msg.sender][9] = true;
			// Creating ERC20
			TDAMM.distributeTokens(msg.sender, 2);
		}

	}
	function ex10_contractCanProvideLiquidity()
	public
	{
		// Retrieving address of pair from library
		(address token0, address token1) = address(studentErc20[msg.sender]) < WETH ? (address(studentErc20[msg.sender]), WETH) : (WETH, address(studentErc20[msg.sender]));
		address studentTokenAndWethPair = uniswapV2Factory.getPair(token0, token1);

		// Checking pair balance before calling exercice contract
		IUniswapV2Pair studentTokenAndWethPairInstance = IUniswapV2Pair(studentTokenAndWethPair);
		(uint112 reserve0, uint112 reserve1, ) = studentTokenAndWethPairInstance.getReserves();

		// Calling student contract to tell him to provide liquidity
		studentExercice[msg.sender].addLiquidity();

		// Checking pair balance after calling exercice contract
		(uint112 reserve3, uint112 reserve4,) = studentTokenAndWethPairInstance.getReserves();

		require((reserve0 < reserve3) && (reserve1 < reserve4), "No liquidity change in your token's pool");

		// Crediting points
		if (!exerciceProgression[msg.sender][10])
		{
			exerciceProgression[msg.sender][10] = true;
			// Creating ERC20
			TDAMM.distributeTokens(msg.sender, 2);
		}

	}

	function ex11_contractCanWithdrawLiquidity()
	public
	{
		// Retrieving address of pair from library
		(address token0, address token1) = address(studentErc20[msg.sender]) < WETH ? (address(studentErc20[msg.sender]), WETH) : (WETH, address(studentErc20[msg.sender]));
		address studentTokenAndWethPair = uniswapV2Factory.getPair(token0, token1);

		// Checking pair balance before calling exercice contract
		IUniswapV2Pair studentTokenAndWethPairInstance = IUniswapV2Pair(studentTokenAndWethPair);
		(uint112 reserve0, uint112 reserve1, ) = studentTokenAndWethPairInstance.getReserves();

		// Calling student contract to tell him to provide liquidity
		studentExercice[msg.sender].withdrawLiquidity();

		// Checking pair balance after calling exercice contract
		(uint112 reserve3, uint112 reserve4,) = studentTokenAndWethPairInstance.getReserves();

		require((reserve0 > reserve3) && (reserve1 > reserve4), "No liquidity change in your token's pool");

		// Crediting points
		if (!exerciceProgression[msg.sender][11])
		{
			exerciceProgression[msg.sender][11] = true;
			// Creating ERC20
			TDAMM.distributeTokens(msg.sender, 2);
		}

	}


	modifier onlyTeachers() 
	{

	    require(TDAMM.teachers(msg.sender));
	    _;
	}

	function submitExercice(IExerciceSolution studentExercice_)
	public
	{
		// Checking this contract was not used by another group before
		require(!hasBeenPaired[address(studentExercice_)]);

		// Assigning passed ERC20 as student ERC20
		studentExercice[msg.sender] = studentExercice_;
		hasBeenPaired[address(studentExercice_)] = true;
			
	}

	function submitErc20(IRichERC20 studentErc20_)
	public
	{
		// Checking this contract was not used by another group before
		require(!hasBeenPaired[address(studentErc20_)]);
		// Assigning passed ERC20 as student ERC20
		studentErc20[msg.sender] = studentErc20_;
		hasBeenPaired[address(studentErc20_)] = true;
			
	}

	function _compareStrings(string memory a, string memory b) 
	internal 
	pure 
	returns (bool) 
	{
    	return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
	}

	function bytes32ToString(bytes32 _bytes32) 
	public 
	pure returns (string memory) 
	{
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

	function readTicker(address studentAddres)
	public
	view
	returns(string memory)
	{
		return assignedTicker[studentAddres];
	}

	function readSupply(address studentAddres)
	public
	view
	returns(uint256)
	{
		return assignedSupply[studentAddres];
	}

	function setRandomTickersAndSupply(uint256[20] memory _randomSupplies, string[20] memory _randomTickers) 
	public 
	onlyTeachers
	{
		randomSupplies = _randomSupplies;
		randomTickers = _randomTickers;
		nextValueStoreRank = 0;
		for (uint i = 0; i < 20; i++)
		{
			emit newRandomTickerAndSupply(randomTickers[i], randomSupplies[i]);
		}
	}

}

pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20TD is ERC20 {

mapping(address => bool) public teachers;
event DenyTransfer(address recipient, uint256 amount);
event DenyTransferFrom(address sender, address recipient, uint256 amount);

constructor(string memory name, string memory symbol,uint256 initialSupply) public ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        teachers[msg.sender] = true;
    }

function distributeTokens(address tokenReceiver, uint256 amount) 
public
onlyTeachers
{
	uint256 decimals = decimals();
	uint256 multiplicator = 10**decimals;
  _mint(tokenReceiver, amount * multiplicator);
}

function setTeacher(address teacherAddress, bool isTeacher) 
public
onlyTeachers
{
  teachers[teacherAddress] = isTeacher;
}

modifier onlyTeachers() {

    require(teachers[msg.sender]);
    _;
  }

function transfer(address recipient, uint256 amount) public override returns (bool) {
	emit DenyTransfer(recipient, amount);
        return false;
    }

  function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
  emit DenyTransferFrom(sender, recipient, amount);
        return false;
    }

}

pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DummyToken is ERC20 {

    constructor(string memory name, string memory symbol,uint256 initialSupply) public ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}