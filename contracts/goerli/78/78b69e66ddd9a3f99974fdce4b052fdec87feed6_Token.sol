/**
 *Submitted for verification at Etherscan.io on 2023-02-15
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract Token is IERC20{
 string public constant name = "Token";
 string public constant symbol = "TK";
 uint8 public decimals = 18;
 uint256 public totalSupply_ = 10000000000 * 1e18;
 mapping(address => uint256) balances;
 mapping(address => mapping (address => uint256)) allowed;


constructor(){
    balances[msg.sender] = totalSupply_;
}
function totalSupply()public override view returns(uint256){
    return totalSupply_;
}
function balanceOf(address tokenOwner)public override view returns(uint256){
    return balances[tokenOwner];
}
function transfer(address receiver, uint256 numTokens)public override returns(bool){
 require(numTokens <= balances[msg.sender]);
 balances[msg.sender] -= numTokens;
 balances[receiver] += numTokens;
 emit Transfer(msg.sender, receiver, numTokens);
 return true;
}
 function approve(address delegate, uint256 numTokens)public override returns(bool){
     allowed[msg.sender][delegate] += numTokens;
    emit Approval(msg.sender, delegate, numTokens);
    return true;
}
function allowance(address owner, address delegate) public view override returns(uint){
    return allowed[owner][delegate];
}
function transferFrom(address owner, address buyer, uint256 numTokens)public override returns(bool){
 require(numTokens <= balances[owner]);
 require(numTokens <= allowed[owner][msg.sender]);
 balances[owner] -= numTokens;
 allowed[owner][msg.sender] -= numTokens;
 balances[buyer]+= numTokens;
 emit Transfer(owner, buyer, numTokens);
 return true;
}
}