/**
 *Submitted for verification at Etherscan.io on 2022-09-11
*/

// File: contracts/Transactions.sol



pragma solidity ^0.8.17;

contract Transactions {
    uint256 transactioCount;

    event Transfer(address from, address receiver, uint256 amount, string message, uint256 timestamp, string keyword);

    struct TransferStruct {
        address sender;
        address receiver;
        uint256 amount;
        string message;
        uint256 timestamp;
        string keyword;
    }

    TransferStruct[] transactions;

    function addToBlockchain(address receiver, uint256 amount, string memory message, string memory keyword) public payable {
        transactioCount ++;
        transactions.push(TransferStruct(msg.sender,receiver, amount, message, block.timestamp, keyword));

        emit Transfer(msg.sender,receiver, amount, message, block.timestamp, keyword);

    }

    function getAllTransactions() public view returns(TransferStruct[] memory) {
        return transactions;

    }

    function getTransactionsCount() public view returns(uint256) {
        return transactioCount;
    }
}