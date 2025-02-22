/**
 *Submitted for verification at Etherscan.io on 2022-12-04
*/

//SPDX-License-Identifier : MIT
pragma solidity^0.8.0; // select complier: 0.8.7

contract Voting {
    string [] public candidateList;
    mapping(string=>uint) votesReceived;
    // A: 0, 1
    // B: 0, 1, 2
    
    //["Dog","PM","NET"]
    constructor(string[]memory candidateName){
        candidateList = candidateName;
    }
    function addNewCandidate(string memory candidateName)public{
        candidateList.push(candidateName);
    }
    //function removeCandidate(string memory candidateName)public{
    //    candidateName = "";
    //}
    function voteForCandidate(string memory candidate)public{
        votesReceived[candidate] +=1;
    }
 
    function totalVotesFor(string memory candidate)
    public view returns(uint256){
        return votesReceived[candidate];
    }
    function candidateCount() public view returns (uint256){
        return candidateList.length;
    }
}