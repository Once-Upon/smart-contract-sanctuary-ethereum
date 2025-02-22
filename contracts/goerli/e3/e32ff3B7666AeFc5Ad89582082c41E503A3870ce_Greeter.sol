/**
 *Submitted for verification at Etherscan.io on 2023-03-19
*/

pragma solidity ^0.4.21;

contract Mortal {
    /* Define variable owner of the type address */
    address owner;

    /* This function is executed at initialization and sets the owner of the contract */
    constructor() public { owner = msg.sender; }

    /* Function to recover the funds on the contract */
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract Greeter is Mortal {
    /* Define variable greeting of the type string */
    string greeting;

    /* This runs when the contract is executed */
    constructor() public {
        greeting = "Hello World!";
    }

    /* Main function */
    function greet() public view returns (string) {
        return greeting;
    }
}