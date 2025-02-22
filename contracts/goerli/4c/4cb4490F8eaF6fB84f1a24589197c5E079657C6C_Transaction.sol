/**
 *Submitted for verification at Etherscan.io on 2022-11-11
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract Transaction {

    uint256 buyDate;
    uint256 buyCoin;

    function store(uint256 date, uint256 coin) public {
        buyDate = date;
        buyCoin = coin;
    }

    function getDate() public view returns (uint256){
        return buyDate;
    }

    function getCoin() public view returns (uint256){
        return buyCoin;
    }
}