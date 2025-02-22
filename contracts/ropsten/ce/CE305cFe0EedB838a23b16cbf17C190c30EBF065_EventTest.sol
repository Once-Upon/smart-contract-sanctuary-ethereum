// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EventTest {
  event Minted(address _owner, uint256 _tokenid, bytes32 _background);
  function test(uint256 _tokenid) public {
      emit Minted(msg.sender, _tokenid, 0x20feefc1a5ac2e30b6b8cf926fb6df028a98666522440121640831c5f507dd03);
  }
}