/**
 *Submitted for verification at Etherscan.io on 2022-12-20
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract SimpleStorage {
    uint256 favoriteNumber;

    function store(uint256 _favoriteNumber) public {
        favoriteNumber = _favoriteNumber;
    }

    function retrieve() public view returns (uint256) {
        return favoriteNumber;
    }
}