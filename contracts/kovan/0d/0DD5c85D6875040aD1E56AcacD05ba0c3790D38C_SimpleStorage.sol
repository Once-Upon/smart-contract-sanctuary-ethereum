// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.0;

contract SimpleStorage{
    uint256 favoriteNumber;
    function store(uint256 _number) public {
        favoriteNumber = _number;
    }

    function retrieve() public view returns (uint256) {
        return favoriteNumber;
    }
}