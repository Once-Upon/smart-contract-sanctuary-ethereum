/**
 *Submitted for verification at Etherscan.io on 2022-08-19
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
 
contract Box {
    uint256 private value;
 
    event ValueChanged(uint256 newValue);
 
    function store(uint256 newValue) public {
        value = newValue;
        emit ValueChanged(newValue);
    }
 
    function retrieve() public view returns (uint256) {
        return value;
    }
}