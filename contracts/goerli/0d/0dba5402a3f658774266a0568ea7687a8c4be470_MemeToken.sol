/**
 *Submitted for verification at Etherscan.io on 2022-09-03
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
/*
Token contracts are smart contract that contains a mapping from account address to balance/token.
The unit of balance is called token
Balance can represent anything:
1. loyalty points
2. in-game items
3. digital collectible
4. coins
5. physical object(house, gold, licence, id, hotel voucher)
6. any asset with monetary value
7. etc

This token can be:
 1. claimed by an owner
 2. traded(sold/bought)
 3. spent
 4.


contract ERC20Interface {
    string public constant name = "Udacity Token";
    string public constant symbol = "UDC";
    uint8 public constant decimals = 18; // 18 is the most common number of decimal places

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
}
*/

contract MemeToken {
    string public constant name = "Meme Coin";
    string public constant symbol = "MEM";
    uint8 public constant decimals = 18;
    uint _totalSupply;

    // Balances for each account stored using a mapping
    mapping(address => uint256) balances;

    // Owner of the account approves the allowance of another account
    // Create an allowance mapping
    // The first key is the owner of the tokens
    // In the 2nd mapping, its says who can spend on your behalf, and how many
    // So, we are creating a mapping, where the kep is an address,
    // The value is further a mapping of address to amount
    mapping(address => mapping(address => uint256)) allowance;

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);


    // Called automatically when contract is initiated
    // Sets to total initial _totalSupply, as per the input argument
    // Also gives the initial supply to msg.sender...who creates the contract
    constructor(uint amount) {
        _totalSupply = amount;
        balances[msg.sender] = amount;
    }

    // Returns the total supply of tokens
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // Get the token balance for account `tokenOwner`
    // Anyone can query and find the balance of an address
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    // Transfer the balance from owner's account to another account
    // Decreases the balance of "from" account
    // Increases the balance of "to" account
    // Emits Transfer event
    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender] - tokens;
        balances[to] = balances[to] + tokens;
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    // Send amount of tokens from address `from` to address `to`
    // The transferFrom method is used to allow contracts to spend
    // tokens on your behalf
    // Decreases the balance of "from" account
    // Decreases the allowance of "msg.sender"
    // Increases the balance of "to" account
    // Emits Transfer event
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = balances[from] - tokens;
        allowance[from][msg.sender] = allowance[from][msg.sender] - tokens;
        balances[to] = balances[to] + tokens;
        emit Transfer(from, to, tokens);
        return true;
    }

    // Approves the `spender` to withdraw from your account, multiple times, up to the `tokens` amount.
    // So the msg.sender is approving the spender to spend these many tokens
    // from msg.sender's account
    // Setting up allowance mapping accordingly
    // Emits approval event
    function approve(address spender, uint tokens) public returns (bool success) {
        allowance[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
}