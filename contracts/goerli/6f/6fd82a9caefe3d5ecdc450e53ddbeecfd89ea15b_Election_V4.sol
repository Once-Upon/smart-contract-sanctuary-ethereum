/**
 *Submitted for verification at Etherscan.io on 2022-11-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Candidate {
    string name;   // ชื่อผู้สมัคร
    string party;  // พรรค
    string Image;
    string status;
    uint votecount;
}

struct Voter {
    bool isRegister;
    bool isVoted;
    string votewho;
}

struct Winner {
    bool isWinner;
    string name;
    string party;
    string Image;
    uint totalVote;
}

struct Start {
    bool isStart;
}




contract Election_V4 {
    address public Manager; // เจ้าหน้าที่
    Candidate [] public candidates;
    Winner [1] public winner;
    Start [1] public start;
    mapping(address=>Voter) public voter;
    
    
    constructor(){
        Manager = msg.sender;
       
    }
    //เป็นคำสั่งคนที่ใช่งาน function ได้แค่ manager เท่านั้น
    modifier onlyManager{
        require(msg.sender == Manager,"You Can't add Candidate Function");
        _;
    }
    // เพิ่มผู้สมัคร by Manager
    function AddCandidate(string memory name, string memory party , string memory Image) onlyManager public{
        require(!start[0].isStart,"Election already Start");
        
        candidates.push(Candidate(name,party,Image,"wait result",0));

    }
    //ลงทะเบียน voter
    function register(address person) onlyManager public{
        require(!winner[0].isWinner,"Election already end");
        require(!start[0].isStart,"Election already Start");
        voter[person].isRegister = true;
    }

     function StartElection() onlyManager public{
        start[0].isStart = true;

    }
    

    function vote(uint index) public{
        //check ว่าลงทะเบียนยัง
        require(voter[msg.sender].isRegister,"You Can't Vote");
        //check ลง vote หรือยัง
        require(!voter[msg.sender].isVoted,"You are Elected");
        require(!winner[0].isWinner,"Election already end");
        //เก็บเลข index ที่ vote
        voter[msg.sender].votewho = candidates[index].name;
        voter[msg.sender].isVoted = true;
        candidates[index].votecount +=1;
    }

    function maxVote() public view returns(uint){
        uint i;
        uint largest = 0;
        uint WinCandidate;
        uint secoundCandidate = 0;
        for(i = 0; i < candidates.length; i++){
            if(candidates[i].votecount > largest) {
                largest = candidates[i].votecount; 
                WinCandidate = i;
                secoundCandidate = 0;
            }
        }
        return WinCandidate;
        
    }

     function Checkequal() public view returns(bool){
        uint i;
        uint largest = 0;
        uint WinCandidate;
        bool Haveequalscore = false;
        for(i = 0; i < candidates.length; i++){
            if(candidates[i].votecount > largest) {
                largest = candidates[i].votecount; 
                WinCandidate = i;
                Haveequalscore = false;
            }else if(candidates[i].votecount == largest){
               Haveequalscore = true;
            }
        }
        return Haveequalscore;
        
    }

    function WinnerCandidate() onlyManager public{
        uint WinnerIndex = maxVote();
        bool Haveequalscore = Checkequal();
        require(Haveequalscore != true,"Don't Have Winner in Election");
        uint i;
        for(i = 0; i < candidates.length; i++){
            if(i == WinnerIndex) {
              candidates[WinnerIndex].status = "Winner";
            }else{
                candidates[i].status = "Lose";
            }
        }
        winner[0].isWinner = true;
        winner[0].name = candidates[WinnerIndex].name;
        winner[0].party = candidates[WinnerIndex].party;
        winner[0].Image = candidates[WinnerIndex].Image;
        winner[0].totalVote = candidates[WinnerIndex].votecount;   
        
        
    }
    
}