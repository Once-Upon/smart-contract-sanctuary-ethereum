// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

contract HBank {
    mapping(address => uint) accounts;

    receive() external payable {
        accounts[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external payable {
        require(amount <= accounts[msg.sender], "Insufficient balance");
        accounts[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function withdrawAll() external payable {
        require(0 == accounts[msg.sender], "balance must be zero");
        accounts[msg.sender] -= accounts[msg.sender];
        (bool success, ) = msg.sender.call{value: accounts[msg.sender]}("");
        require(success, "Transfer failed");
    }

    function getMyBalance() external view returns (uint256) {
        return accounts[msg.sender];
    }
}