/**
 *Submitted for verification at Etherscan.io on 2022-08-05
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;

contract WriteBlocks{
    string texto; 

    function Write(string calldata _texto) public{
        texto = _texto;
    }

    function Read() public view returns(string memory){
        return texto;
    }
}