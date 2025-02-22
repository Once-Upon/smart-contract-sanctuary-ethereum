/**
 *Submitted for verification at Etherscan.io on 2022-12-28
*/

// SPDX-License-Identifier: MIT

// File: WithoutCond/IERC20.sol


// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

interface IERC20Metadata {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 is IERC20Metadata {
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

// File: WithoutCond/PoolWC.sol


pragma solidity ^0.8.0;


contract PoolBet{

    address immutable admin;
    IERC20 public immutable token;

    constructor(){
        admin = payable(msg.sender);
        token = IERC20(0x11d1149202fbb7eeeA118BCEb85db1D7eAA3084A);
    }
    

    
    // mapping(address => mapping(string => uint)) public betidToStake;
    mapping(address => mapping(string => mapping(uint => uint))) public betidToStake;
    mapping(string => uint) public betIdtoTotal;
    mapping(string => uint) public betCount;
    mapping(address => mapping(string => mapping(uint => bool))) public betidToClaimed;
    mapping(address => mapping(string => mapping(uint => bool))) public staked;
    mapping(string => bool) public fullyClaimed;

    uint public adminTotaFee;
    uint private totalResiduals;


    receive() external payable{}
    

    function _stake(string calldata  betid, uint transactionID, uint stakeAmount, address staker) internal returns(bool success){
            require(msg.sender == staker, "Staker");

            token.transferFrom(staker, address(this), stakeAmount);
            staked[staker][betid][transactionID] = true;
            return true;
        
    }

    function Stake(string calldata  betid, uint transactionID, uint stakeAmount, address staker) external{
        require(msg.sender == staker, "Staker");

       bool success =  _stake(betid, transactionID, stakeAmount, staker);

       require(success, "transfer Failed");

        betCount[betid] ++;
        betidToStake[staker][betid][transactionID] += stakeAmount;
        betIdtoTotal[betid] += stakeAmount;

    }

    function getStaked(string calldata  betid, uint transactionID, address staker) external view returns(bool){
        return staked[staker][betid][transactionID];
    }

    function getFinalised(string calldata  betid, uint transactionID, address reciever) external view returns(bool){
        return betidToClaimed[reciever][betid][transactionID];
    }




    function finalise(string calldata  betid, uint transactionID, uint amount, address reciever, uint fee, bool last) external{
        require(msg.sender == reciever, "Not Reciever");

        require(!betidToClaimed[reciever][betid][transactionID], "Address already claimed");

        uint stake = betidToStake[reciever][betid][transactionID];
        uint totalStake = betIdtoTotal[betid];

        require(amount <= totalStake, "Insufficient Amount in balance");//Insufficient amount
        require(stake > 0, "Did Not Stake");//DId not stake


        bool success = _transfer(reciever, amount);

        require(success, "Transfer Not successful");

        betidToClaimed[reciever][betid][transactionID] = true;        
        delete betidToStake[reciever][betid][transactionID];
        amount+= fee;

        betIdtoTotal[betid] -= amount;

        adminTotaFee += fee;

        lastClaim(betid, last, betIdtoTotal[betid]);

    }

    function _transfer(address reciever, uint amount) internal returns(bool){
        require(msg.sender == reciever, "Not Reciever");

        token.transfer(reciever, amount);

        return true;

    }

    function lastClaim(string calldata betid, bool last, uint residual) internal{
        fullyClaimed[betid] = last;

        if(fullyClaimed[betid]){
            totalResiduals += residual;
        }
    }

    function getTotalResidue() external view returns(uint){
          require(msg.sender == admin, "Not Admin");
        return totalResiduals;
    }
            
     function adminWithdrawal(uint amount) external{
        require(msg.sender == admin, "Not Admin");
        require(amount <= adminTotaFee, "Insufficient Amount in Balance");

        adminTotaFee -= amount;

        token.transfer(admin, amount);

        
    }
    
    function adminResidualWithdraw() external{
          require(msg.sender == admin, "Not Admin");
          require(totalResiduals > 0, "No Residuals Available");

          uint residual = totalResiduals;

          delete totalResiduals;

          token.transfer(admin, residual);
    }
}