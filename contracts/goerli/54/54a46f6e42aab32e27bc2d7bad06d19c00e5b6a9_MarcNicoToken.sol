/**
 *Submitted for verification at Etherscan.io on 2022-12-22
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
contract MarcNicoToken {
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    string public constant name = "MarcNicoToken";
    string public constant symbol = "MNT";
    uint8 public constant decimals = 18;
    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    uint256 totalSupply_;
    constructor(uint256 total) {
      totalSupply_ = total;
      balances[msg.sender] = totalSupply_;
    }
    function totalSupply() public view returns (uint256) {
      return totalSupply_;
    }
    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances[tokenOwner];
    }
    function transfer(address receiver, uint numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] -= numTokens;
        balances[receiver] += numTokens;
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }
    function approve(address delegate, uint numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }
    function allowance(address owner, address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }
    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);

        balances[owner] -= numTokens;
        allowed[owner][msg.sender] -= numTokens;
        balances[buyer] += numTokens;
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
    function transferTwoReceivers(address receiverOne, address receiverTwo, uint numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] -= numTokens;
        uint numTokensDivided = uint(numTokens/2);
        if (numTokens % 2 == 0) {
            balances[receiverOne] += numTokensDivided;
            balances[receiverTwo] += numTokensDivided;
            emit Transfer(msg.sender, receiverOne, numTokensDivided);
            emit Transfer(msg.sender, receiverTwo, numTokensDivided);
        } else {
            balances[receiverOne] += numTokensDivided+1;
            balances[receiverTwo] += numTokensDivided;
            emit Transfer(msg.sender, receiverOne, numTokensDivided+1);
            emit Transfer(msg.sender, receiverTwo, numTokensDivided);
        }
        return true;
    }
}