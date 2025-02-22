/**
 *Submitted for verification at Etherscan.io on 2022-09-04
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Expl0rer {
    string private FLAG;

    constructor(string memory flag) {
        FLAG = flag;
    }

    function getFlag() view public returns (string memory) {
        return FLAG;
    }
}