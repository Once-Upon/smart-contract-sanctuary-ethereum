/**
 *Submitted for verification at Etherscan.io on 2022-12-16
*/

pragma solidity >=0.7.0 <0.9.0;

contract Hello {

uint256 number;

function store(uint256 num) public {

    number= num ;
}

function retrieve() public view returns (uint256) {
    return number;
}

}