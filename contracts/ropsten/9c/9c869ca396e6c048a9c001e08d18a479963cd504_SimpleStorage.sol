/**
 *Submitted for verification at Etherscan.io on 2022-09-20
*/

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.7.0 < 0.9.0;

contract SimpleStorage {
    uint storedData;

    function set(uint x) public
{
    storedData=x;
}
function get() public view returns(uint){
    return storedData;
}

}