/**
 *Submitted for verification at Etherscan.io on 2022-08-09
*/

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Bank {
    
    mapping(address => uint) private _balanceByAddress;
    uint _totalSupply;

    function deposit() public payable {
        _balanceByAddress[msg.sender] += msg.value;
        _totalSupply += msg.value;
    }

    function withdraw(uint amount) public payable {
        require(amount <= _balanceByAddress[msg.sender], "not enough money");

        payable(msg.sender).transfer(amount);
        _balanceByAddress[msg.sender] -= amount;
        _totalSupply -= amount;
    }

    function checkBalance() public view returns(uint balance) {
        return _balanceByAddress[msg.sender];
    }

    function checkTotalSupply() public view returns(uint totalSupply) {
        return _totalSupply;
    }

}