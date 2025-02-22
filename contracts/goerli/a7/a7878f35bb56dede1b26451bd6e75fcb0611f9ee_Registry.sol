// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Registry {
    uint256[] public fakeAUM;

    constructor() {
        fakeAUM = [
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18),
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18),
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18),
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18),
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18),
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18),
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18),
            uint256(100e18),
            uint256(200e18),
            uint256(500e18),
            uint256(10e18),
            uint256(300e18),
            uint256(1320e18),
            uint256(3200e18),
            uint256(1054e18),
            uint256(150e18),
            uint256(20e18),
            uint256(140e18),
            uint256(130e18),
            uint256(130e18),
            uint256(120e18),
            uint256(150e18),
            uint256(106e18),
            uint256(105e18)
        ];
    }

    function getAUM() external view returns (uint256) {
        uint256[] memory _fakeAUM = fakeAUM;
        uint256 aum;
        for (uint256 i = 0; i < _fakeAUM.length; i++) {
            aum += _fakeAUM[i];
        }
        return aum;
    }
}