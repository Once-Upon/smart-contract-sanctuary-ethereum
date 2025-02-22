/**
 *Submitted for verification at Etherscan.io on 2023-03-23
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Counter {
    //event incrementoContador(uint);
    //event decrementoContador(uint);

    uint public count;

    // Function to get the current count
    function get() public view returns (uint) {
        return count;
    }

    // Function to increment count by 1
    function inc() public {
        count ++;
        //emit incrementoContador(count);
    }

    // Function to decrement count by 1
    function dec() public {
        // This function will fail if count = 0
        count --;
        //emit decrementoContador(count);
    }
}