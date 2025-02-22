/**
 *Submitted for verification at Etherscan.io on 2023-02-07
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.4.16 <0.9.0;

contract SimpleStorage {
  uint storedData; 

  function set(uint x) public {  
    storedData = x;
  }

  function get() public view returns (uint) {  
    return storedData;
  }

}