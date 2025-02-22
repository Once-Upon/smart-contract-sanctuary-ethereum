/**
 *Submitted for verification at Etherscan.io on 2022-12-05
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Transaction {
    uint256 numTransactions;
    mapping(address => uint256) balances;
    mapping(address => uint256) addressToNumTransactions;
    mapping(uint256 => bool) relayerSigns;
    uint256 fee;
    uint256 RevertAfter;

    address _contractOwner;

    event Transfer(address from, address to, uint256 amount);
    event Approval(uint256 _numTransactions);

    modifier onlyOwner() {
        require(_contractOwner == msg.sender, "sender is not contract owner.");
        _;
    }

    constructor() {
        _contractOwner = msg.sender;
    }

    function setFee(uint256 newFee) external onlyOwner {
        fee = newFee;
    }

    function setRevertAfter(uint256 newRevertAfter) external onlyOwner {
        RevertAfter = newRevertAfter;
    }

    function transferFrom(
        address payable from,
        address payable to,
        uint256 amount,
        uint256 _numTransactions
    ) external payable returns (bool success) {
        require(
            relayerSigns[_numTransactions],
            "Failed to send Ether because no Relayer signs."
        );
        // (bool sent, bytes memory data) = to.call{value: msg.value}("");
        // require(sent, "Failed to send Ether");
        emit Transfer(from, to, amount);
        numTransactions++;
        return true;
    }

    function setRelayerSign(uint256 _numTransactions)
        external
        returns (bool success)
    {
        relayerSigns[_numTransactions] = true;
        emit Approval(_numTransactions);
        return true;
    }

    function sendFrom(address payable to)
        external
        payable
        returns (uint256 numTransaction)
    {
        addressToNumTransactions[to] = numTransactions;
        return numTransactions;
    }

    function getBalance(address payable whose) external view returns (uint256 balance) {
        return whose.balance;
    }
}