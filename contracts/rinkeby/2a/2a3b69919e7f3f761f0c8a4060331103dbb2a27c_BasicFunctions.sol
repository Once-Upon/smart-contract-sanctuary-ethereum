/**
 *Submitted for verification at Etherscan.io on 2022-07-29
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 < 0.9.0;

contract BasicFunctions {

    // Setting things up
    string coinName = "Aladdin Coin";

    uint public myBalance = 1000;

    struct Coin {

        string name;
        string symbol;
        uint supply;

    }

    mapping (address => Coin) internal myCoins;

    // function (string memory _variable, int _variable2) public view/pure return(bool) {}
    function guessNumber(uint _guess) public pure returns(bool){

        if(_guess == 5) {
            return true;
        } else {
            return false;
        }

    }

    // return string
    function getmyCoinName() public view returns(string memory) {

        return coinName;

    }

    // that can only be called externally
    function multiplyBalance(uint _multiplier) external{

        myBalance = myBalance * _multiplier;

    }

    // that user a for loop and multiplies params and string comparsion
    function findCoinIndex(string[] memory _myCoins, string memory _find, uint _startFrom) public pure returns (uint) {
        for (uint i = _startFrom; i < _myCoins.length; i++) {
            string memory coin = _myCoins[i];
            if (keccak256(abi.encodePacked(coin)) == keccak256(abi.encodePacked(_find))) {
                return i;
            }
        }
        return 9999;
    }

    // update the mapping
    function addCoin(string memory _name, string memory _symbol, uint _supply) external {
        myCoins[msg.sender] = Coin(_name, _symbol, _supply);
    }

    // function get a coin from myCoin mapping
    function getMyCoin() public view returns (Coin memory) {
        return myCoins[msg.sender];
    }



}