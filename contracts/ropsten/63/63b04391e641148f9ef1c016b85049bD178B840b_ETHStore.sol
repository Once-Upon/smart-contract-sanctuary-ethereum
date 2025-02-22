// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.7.6;

contract ETHStore {
    mapping(address => uint256) public balance;

    function deposit() public payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw(uint256 withdrawWei) public {
        require(balance[msg.sender] >= withdrawWei);
        msg.sender.call{ value: withdrawWei };
        balance[msg.sender] -= withdrawWei;
    }

    function withdraw1(uint256 withdrawWei) public {
        require(balance[msg.sender] >= withdrawWei);
        payable(msg.sender).transfer(withdrawWei);
        balance[msg.sender] -= withdrawWei;
    }
}