/**
 *Submitted for verification at Etherscan.io on 2022-10-04
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

contract Lottery{
    address public manager;
    string public officiant = "Dr. Zichao Yang";
    string public groom = "Haoyan Min";
    string public bride = "Yilan Ji";
    address payable[] public players;

    constructor(){
        manager = msg.sender;
    }

    function enter() public payable {
        require(msg.value > .01 ether);
        players.push(payable(msg.sender));
    }

    function random() private view returns (uint){
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, players)));
    }

    function pickWinner() public restricted{
        uint index = random() % players.length;
        players[index].transfer(address(this).balance);
        players = new address payable[](0);
    }

    modifier restricted(){
        require(msg.sender == manager);
        _;
    }

    function getPlayers() public view returns(address payable[] memory){
        return players;
    }
}