// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    //using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract
	
	uint256 public totalLiquidity;
	mapping(address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address ethSender, string details, uint256 ethInput, uint256 tokenOutput);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address tokenSender, string details, uint256 ethOutput, uint256 tokenInput);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address liqSender, uint256 liquidityMinted, uint256 ethInput, uint256 tokenDeposit);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(address requestedByUser, uint256 _amount, uint256 ethWithdrawn, uint256 tokenAmount);

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) public {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
		require(totalLiquidity == 0, "DEX: init - already has liquidity");
		totalLiquidity = address(this).balance;
		liquidity[msg.sender] = totalLiquidity;
		require(token.transferFrom(msg.sender, address(this), tokens), "DEX: init - transfer did not transact");
		return totalLiquidity;
	}

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
		// 997 = 0,3% trading fees
		uint256 xInputWithFee = xInput * 997;
		uint256 numerator = xInputWithFee * yReserves;
		uint256 denominator = (xReserves * 1000) + xInputWithFee;
        return (numerator / denominator);
	}

    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     */
    /*function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }*/

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
		require(msg.value > 0, "Cannot swap 0 ETH");
		//ethReserve need to subtract the current msg.value from the ETH contract reserve, cause when this function is called msg.value it's immediately added to the reserve.
		uint256 ethReserve = address(this).balance - msg.value;
		uint256 token_reserve = token.balanceOf(address(this));
		uint256 tokenOutput = price(msg.value, ethReserve, token_reserve);
		
		require(token.transfer(msg.sender, tokenOutput), "ethToToken(): reverted swap.");
		emit EthToTokenSwap(msg.sender, "Eth to Balloons", msg.value, tokenOutput);
        return tokenOutput;
	}

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 _tokenInput) public returns (uint256 ethOutput) {
		require(_tokenInput > 0, "Cannot swap 0 tokens");
		uint256 token_reserve = token.balanceOf(address(this));
		uint256 ethOutput = price(_tokenInput, token_reserve, address(this).balance);
		require(token.transferFrom(msg.sender, address(this), _tokenInput), "tokenToEth(): reverted swap.");
        (bool sent, ) = msg.sender.call{ value: ethOutput }("");
        require(sent, "tokenToEth: revert in transferring eth to you!");
        emit TokenToEthSwap(msg.sender, "Balloons to ETH", ethOutput, _tokenInput);
        return ethOutput;
	}

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
		uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokenDeposit;

        tokenDeposit = ((msg.value * tokenReserve) / ethReserve) + 1;
        uint256 liquidityMinted = (msg.value * totalLiquidity) / ethReserve;
        liquidity[msg.sender] = liquidity[msg.sender] + liquidityMinted;
        totalLiquidity = totalLiquidity + liquidityMinted;

        require(token.transferFrom(msg.sender, address(this), tokenDeposit));
        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenDeposit);
        return tokenDeposit;
	}

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 _amount) public returns (uint256 eth_amount, uint256 token_amount) {
		require(liquidity[msg.sender] >= _amount, "withdraw: sender does not have enough liquidity to withdraw.");
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethWithdrawn;

        ethWithdrawn = (_amount * ethReserve) / totalLiquidity;

        uint256 tokenAmount = (_amount * tokenReserve) / totalLiquidity;
        liquidity[msg.sender] = liquidity[msg.sender] - _amount;
        totalLiquidity = totalLiquidity - _amount;
        (bool sent, ) = payable(msg.sender).call{ value: ethWithdrawn }("");
        require(sent, "withdraw(): revert in transferring eth to you!");
        require(token.transfer(msg.sender, tokenAmount));
        emit LiquidityRemoved(msg.sender, _amount, ethWithdrawn, tokenAmount);
        return (ethWithdrawn, tokenAmount);
	}
}