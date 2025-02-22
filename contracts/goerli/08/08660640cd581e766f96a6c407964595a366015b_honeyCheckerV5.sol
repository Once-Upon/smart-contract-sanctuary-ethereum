/**
 *Submitted for verification at Etherscan.io on 2023-01-19
*/

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract honeyCheckerV5 {
    uint256 buyResult;
    uint256 tokenBalance2;
    uint256 sellResult;
    uint256 buyCost;
    uint256 sellCost;
    uint256 expectedAmount;

 struct HoneyResponse {
        uint256 buyResult;
        uint256 tokenBalance2;
        uint256 sellResult;
        uint256 buyCost;
        uint256 sellCost;
        uint256 expectedAmount;
    }
HoneyResponse   public responsestruct;

    uint256[] public result;

    constructor() {}

    function honeyCheck() public returns (uint256[] memory) {
        result =new uint256[](6) ;
        result[0] = 0;
        result[1] = 1;
        result[2] = 2;
        result[3] = 3;
        result[4] = 4;

        return (result);
    }

     function honeyCheck11() public returns (HoneyResponse memory) {
       
    buyResult=1;
         tokenBalance2=2;
         sellResult=3;
         buyCost=4;
         sellCost=5;
         expectedAmount=6;

 responsestruct  = HoneyResponse (
            buyResult,
            tokenBalance2,
            sellResult,
            buyCost,
            sellCost,
            expectedAmount
        );

        return (responsestruct);
    }
}