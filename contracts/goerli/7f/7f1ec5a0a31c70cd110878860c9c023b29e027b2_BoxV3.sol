/**
 *Submitted for verification at Etherscan.io on 2022-10-15
*/

/**
 *Submitted for verification at Etherscan.io on 2022-10-15
*/

// contracts/Box.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Box {
    uint256 private value;

    // Emitted when the stored value changes
    event ValueChanged(uint256 newValue);

    // Stores a new value in the contract
    function store(uint256 newValue) public {
        value = newValue;
        emit ValueChanged(newValue);
    }

    // Reads the last stored value
    function retrieve() public view returns (uint256) {
        return value;
    }
}


contract BoxV2 is Box{
    // Increments the stored value by 1
    function increment() public {
        store(retrieve()+1);
    }
}

contract BoxV3 is BoxV2{
    string public name;

    event NameChanged(string name);
    function setName(string memory _name) public {
        name = _name;
        emit NameChanged(name);
    }
}