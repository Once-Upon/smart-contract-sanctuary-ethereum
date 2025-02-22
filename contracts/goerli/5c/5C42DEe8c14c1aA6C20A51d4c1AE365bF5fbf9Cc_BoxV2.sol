// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract BoxV2 {
    uint256 private value;

    event Valuechanged(uint256 newValue);

    function store(uint256 newValue) public {
        value = newValue;
        emit Valuechanged(newValue);
    }

    function retrieve() public view returns (uint256) {
        return value;
    }

    function increment() public {
        value = value + 1;
        return Valuechanged(value);
    }
}