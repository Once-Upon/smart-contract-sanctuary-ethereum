/**
 *Submitted for verification at Etherscan.io on 2022-11-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Random {
    function random () public view returns (uint) {
        return uint(blockhash(block.number - 1));
    }
}