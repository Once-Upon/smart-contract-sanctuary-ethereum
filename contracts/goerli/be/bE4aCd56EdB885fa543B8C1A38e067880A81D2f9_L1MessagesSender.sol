// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import {FormatWords64} from "./lib/FormatWords64.sol";
import {IStarknetCore} from "./interfaces/IStarknetCore.sol";


contract L1MessagesSender {
    IStarknetCore public immutable starknetCore;
    uint256 public immutable l2RecipientAddr;

    /// @dev starknetSelector(receive_from_l1)
    uint256 constant SUBMIT_L1_BLOCKHASH_SELECTOR = 598342674068027518481179578557554850038206119856216505601406522348670006916;

    // TODO - describe
    constructor(IStarknetCore starknetCore_, uint256 l2RecipientAddr_) {
        starknetCore = starknetCore_;
        l2RecipientAddr = l2RecipientAddr_;
    }

    // TODO - natspec
    function sendExactParentHashToL2(uint256 blockNumber_) external {
        bytes32 parentHash = blockhash(blockNumber_ - 1);
        require(parentHash != bytes32(0), "ERR_INVALID_BLOCK_NUMBER");
        _sendBlockHashToL2(parentHash, blockNumber_);
    }

    function sendLatestParentHashToL2() external {
        bytes32 parentHash = blockhash(block.number - 1);
        _sendBlockHashToL2(parentHash, block.number);
    }

    function _sendBlockHashToL2(bytes32 parentHash_, uint256 blockNumber_) internal {
        uint256[] memory message = new uint256[](5);
        (bytes8 hashWord1, bytes8 hashWord2, bytes8 hashWord3, bytes8 hashWord4) = FormatWords64.fromBytes32(parentHash_);

        message[0] = uint256(uint64(hashWord1));
        message[1] = uint256(uint64(hashWord2));
        message[2] = uint256(uint64(hashWord3));
        message[3] = uint256(uint64(hashWord4));
        message[4] = blockNumber_;

        starknetCore.sendMessageToL2(l2RecipientAddr, SUBMIT_L1_BLOCKHASH_SELECTOR, message);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

library FormatWords64 {
    function fromBytes32(bytes32 input) internal pure returns(bytes8 word1, bytes8 word2, bytes8 word3, bytes8 word4) {
        assembly {
            word1 := input
            word2 := shl(64, input)
            word3 := shl(128, input)
            word4 := shl(192, input)
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

interface IStarknetCore {
    /**
      Sends a message to an L2 contract.
    */
    function sendMessageToL2(
        uint256 to_address,
        uint256 selector,
        uint256[] calldata payload
    ) external;

    /**
      Consumes a message that was sent from an L2 contract.
    */
    function consumeMessageFromL2(uint256 fromAddress, uint256[] calldata payload) external;
}