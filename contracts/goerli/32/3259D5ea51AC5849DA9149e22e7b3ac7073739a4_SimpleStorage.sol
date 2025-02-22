/**
 *Submitted for verification at Etherscan.io on 2022-10-22
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

contract SimpleStorage {
    uint256 favouriteNumber;

    struct People {
        uint256 favouriteNumber;
        string name;
    }

    People[] public people;

    mapping(string => uint256) public nameToFavouriteNumber;

    function store(uint256 _fav) public {
        favouriteNumber = _fav;
    }

    function retrive() public view returns(uint256) {
        return favouriteNumber;
    }

    function addPerson(string memory _name, uint256 _fav) public {
        people.push(People(_fav,_name));
        nameToFavouriteNumber[_name] = _fav;
    }

}