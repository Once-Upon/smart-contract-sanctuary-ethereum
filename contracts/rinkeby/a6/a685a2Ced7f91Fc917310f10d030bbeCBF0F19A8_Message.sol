/**
 *Submitted for verification at Etherscan.io on 2022-09-10
*/

pragma solidity ^0.4.24;

contract Message {
    string myMessage;

    function setMessage(string x) public {
        myMessage = x;
    }

    function getMessage() public view returns (string) {
        return myMessage;
    }
}