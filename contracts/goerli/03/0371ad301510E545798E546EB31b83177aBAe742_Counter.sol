// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable not-rely-on-time
// solhint-disable no-empty-blocks
contract Counter {
    uint256 public count;
    uint256 public lastExecuted;

    function increaseCount(uint256 amount) external {
        count += amount;
        lastExecuted = block.timestamp;
    }

    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        canExec = (block.timestamp - lastExecuted) > 180;

        execPayload = abi.encodeCall(this.increaseCount, (1));
    }
}