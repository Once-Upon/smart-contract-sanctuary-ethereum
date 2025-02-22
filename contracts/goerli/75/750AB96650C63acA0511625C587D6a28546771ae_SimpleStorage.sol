//SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

contract SimpleStorage {
    uint256 number;

    //Store the value of the contract
    function store(uint256 _number) public {
        number = _number;
    }

    //Return the values stored in the contract
    function retreive() public view returns (uint256) {
        return number;
    }
}