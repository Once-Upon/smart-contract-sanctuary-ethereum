/**
 *Submitted for verification at Etherscan.io on 2023-06-01
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Company{
    string public boss_name;
    address payable public boss_address;
    struct Sales{
        string name;
        address payable sales_address;
        uint256 performance;
        uint256 salary;
        uint256 withdrawn;
    }
    mapping(address=>string) address_name;
    mapping(string=>Sales) name_sales;
}