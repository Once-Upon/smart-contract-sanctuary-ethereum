// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/*
proxy --> implementation
  ^
  |
  |
proxy admin
*/

contract Box {
    uint public mewtwo;

    // constructor(uint _val) {
    //     val = _val;
    // }

    function initialize(uint _val) external {
        mewtwo = _val;
    }
}