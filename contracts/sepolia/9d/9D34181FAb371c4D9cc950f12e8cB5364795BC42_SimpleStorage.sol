// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.0;

contract SimpleStorage {
    
    uint256 favoriteNumber;

    struct People{
        uint256 favoriteNumber;
        string name;
    }

    People[] public people;
    
    mapping(string => uint256) public nameToFavoriteNumber;

    function store(uint256 _favoriteNumber) public{
        favoriteNumber = _favoriteNumber;
    }

    function retrieve() public view returns(uint256){
        return favoriteNumber;
    }

    function addPerson(uint256 _favoriteNumber, string memory _name)public {
       people.push(People(_favoriteNumber,_name));
       nameToFavoriteNumber[_name] = _favoriteNumber; 
    }
}