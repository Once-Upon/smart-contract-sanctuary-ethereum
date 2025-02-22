/**
 *Submitted for verification at Etherscan.io on 2022-10-21
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract PersonalInfo {

    struct Person {
        string name;
        uint256 age;
        string nationality;
        address public_address;
    }

    Person person;

    constructor(){
        person.public_address = msg.sender;
    }

    function setAge(uint256 age) public {
        person.age = age;
    }

    function setName(string memory name) public {
        person.name = name;
    }

    function setNationality(string memory nat) public {
        person.nationality = nat;
    }

    function getPerson() public view returns (Person memory){
        return person;
    }
}