/**
 *Submitted for verification at Etherscan.io on 2023-03-12
*/

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}




pragma solidity ^0.8.0;


contract StakingContract {

    address public tokenAddress;
    address payable public owner;
    
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public lastUpdateTime;

    uint256 public totalStakedAmount;
    
    uint256 public gasFee;
    
    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    
    constructor(address _tokenAddress, uint _gasFee) {
        tokenAddress = payable(_tokenAddress);
        owner = payable(msg.sender);
        gasFee = _gasFee;
    }
    
    function stake(uint256 _amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(_amount > 0, "Amount must be greater than zero");
        
        // Transfer USDT tokens from user to this contract
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        // Deduct gas fee from contract
        uint256 totalFee = gasFee * 2;
        require(token.transferFrom(address(this), owner, totalFee), "Fee transfer failed");
        
        // Update staked amount and last update time
        stakedAmount[msg.sender] += _amount;
        lastUpdateTime[msg.sender] = block.timestamp;
        totalStakedAmount += _amount;
        
        emit Staked(msg.sender, _amount);
    }
    
    function withdraw() external {
        IERC20 token = IERC20(tokenAddress);
        require(stakedAmount[msg.sender] > 0, "No staked amount found");
        
        // Calculate the amount to withdraw and update staked amount and last update time
        uint256 amountToWithdraw = stakedAmount[msg.sender];
        stakedAmount[msg.sender] = 0;
        lastUpdateTime[msg.sender] = 0;
        totalStakedAmount -= amountToWithdraw;
        
        // Transfer the USDT tokens to the user
        require(token.transfer(msg.sender, amountToWithdraw), "Transfer failed");
        
        emit Withdrawn(msg.sender, amountToWithdraw);
    }
    
    // function changeGasFee(uint256 _newGasFee) external {
    //     require(msg.sender == owner, "Only owner can change gas fee");
    //     gasFee = _newGasFee;
    // }
    
    function withdrawAll() external {
        IERC20 token = IERC20(tokenAddress);
        require(msg.sender == owner, "Only owner can withdraw all");
        
        // Transfer all USDT tokens to the owner
        require(token.transfer(owner, token.balanceOf(address(this))), "Transfer failed");

        totalStakedAmount = 0;
    }
}