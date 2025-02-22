// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

error ChunkAlreadyProcessed();
error MismatchedArrays();

contract CBAirdropper {
    constructor() {
        owner = msg.sender;
    }

    address public owner;
    address public CB_ADDRESS;
    uint public START_ID;
    mapping(uint256 => bool) private processedChunksForAirdrop;

    function setOwnerAddress(address _address) public {
        require(msg.sender == owner, "Not owner");
        owner = _address;
    }

    function setCBAddress(address _address) public {
        require(msg.sender == owner, "Not owner");
        CB_ADDRESS = _address;
    }

    function setStartId(uint _startId) public {
        require(msg.sender == owner, "Not owner");
        START_ID = _startId;
    }

    function airdrop(
        address[] calldata receivers,
        uint256[] calldata numTokens,
        uint256 chunkNum
    ) public {
        require(msg.sender == owner, "Not owner");
        if (receivers.length != numTokens.length || receivers.length == 0)
            revert MismatchedArrays();
        if (
            processedChunksForAirdrop[chunkNum]
        ) revert ChunkAlreadyProcessed();

        for (uint256 i; i < receivers.length; i++) {
            for (uint256 j; j < numTokens[i]; j++) {
                ICBToken(CB_ADDRESS).transferFrom(owner, receivers[i], START_ID);
                unchecked {
                    ++START_ID;
                }
            }
        }
        processedChunksForAirdrop[chunkNum] = true;
    }
}

interface ICBToken {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function balanceOf(address owner) external;
}