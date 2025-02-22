// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading

contract ExampleExternalContract {
    bool public completed = false;

    function complete() public payable {
        completed = true;
    }

    function getComplete() public view returns (bool) {
        return completed;
    }
}