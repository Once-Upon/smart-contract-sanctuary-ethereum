/**
 *Submitted for verification at Etherscan.io on 2022-09-23
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Counter {
    uint256 internal counter;
    function increment() external {
        unchecked {
            ++counter;
        }
    }

    function getCurrent() external view returns(uint256) {
        return counter;
    }
}