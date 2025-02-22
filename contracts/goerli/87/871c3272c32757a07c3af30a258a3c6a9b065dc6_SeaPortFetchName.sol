// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;


interface IERCToken {
    function name() external view returns (string memory);
}

contract SeaPortFetchName {
    string sigMessage =
        "This is a Seaport listing message, mostly used by OpenSea Dapp, be aware of the potential balance changes";

    enum ItemType
    // 0: ETH on mainnet, MATIC on polygon, etc.
    {
        NATIVE,
        // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
        ERC20,
        // 2: ERC721 items
        ERC721,
        // 3: ERC1155 items
        ERC1155,
        // 4: ERC721 items where a number of tokenIds are supported
        ERC721_WITH_CRITERIA,
        // 5: ERC1155 items where a number of ids are supported
        ERC1155_WITH_CRITERIA
    }

    enum OrderType
    // 0: no partial fills, anyone can execute
    {
        FULL_OPEN,
        // 1: partial fills supported, anyone can execute
        PARTIAL_OPEN,
        // 2: no partial fills, only offerer or zone can execute
        FULL_RESTRICTED,
        // 3: partial fills supported, only offerer or zone can execute
        PARTIAL_RESTRICTED
    }

    struct OfferItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }

    struct ConsiderationItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address payable recipient;
    }

    struct OrderComponents {
        address offerer;
        address zone;
        OfferItem[] offer;
        ConsiderationItem[] consideration;
        OrderType orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 counter;
    }

    struct BalanceOut {
        uint256 amount;
        address token;
    }

    struct BalanceIn {
        uint256 amount;
        address token;
    }


    struct BalanceInSimplifiedMessage {
        string inMessage;
    }

    struct BalanceOutSimplifiedMessage {
        string outMessage;
    }

    function toString(uint256 value) internal pure returns (string memory str) {
        assembly {
            let m := add(mload(0x40), 0xa0)
            mstore(0x40, m)
            str := sub(m, 0x20)
            mstore(str, 0)
            let end := str
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                mstore8(str, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            let length := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, length)
        }
    }

    function getTokenNameByAddress(address _token) private view returns (string memory) {
        if (_token == address(0)) {
            return "ETH";
        } else {
            (bool success, bytes memory returnData) =  _token.staticcall(abi.encodeWithSignature("name()"));
            if (success && returnData.length > 0) {
                return string(returnData);
            }
            else {
                return "Unknown";
            }
        }
    }

    // need to manage array length because of the fact that default array values are 0x0 which represents 'native token'
    function getElementIndexInArray(address addressToSearch, uint256 arrayLength, address[] memory visitedAddresses)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < arrayLength; i++) {
            if (addressToSearch == visitedAddresses[i]) {
                return i;
            }
        }
        return visitedAddresses.length + 1;
    }

    function evalEIP712Buffer(OrderComponents memory order)
        public
        view
        returns (
            string memory,
            BalanceOutSimplifiedMessage[] memory balanceOutSimplifiedMessage,
            BalanceInSimplifiedMessage[] memory balanceInSimplifiedMessage,
            uint256 expirationTime
        )
    {
        BalanceOut[] memory tempBalanceOut = new BalanceOut[](order.offer.length);
        BalanceIn[] memory tempBalanceIn = new BalanceIn[](order.consideration.length);
        address[] memory outTokenAddresses = new address[](order.offer.length);
        address[] memory inTokenAddresses = new address[](order.consideration.length);

        uint256 outLength;
        for (uint256 i; i < order.offer.length; i++) {
            uint256 index = getElementIndexInArray(order.offer[i].token, outLength, outTokenAddresses);
            if (index != outTokenAddresses.length + 1) {
                tempBalanceOut[index].amount += order.offer[i].startAmount;
            } else {
                outTokenAddresses[outLength] = order.offer[i].token;
                tempBalanceOut[outLength] = BalanceOut(order.offer[i].startAmount, order.offer[i].token);
                outLength++;
            }
        }

        uint256 inLength;
        for (uint256 i; i < order.consideration.length; i++) {
            if (order.offerer == order.consideration[i].recipient) {
                uint256 index = getElementIndexInArray(order.consideration[i].token, inLength, inTokenAddresses);
                if (index != inTokenAddresses.length + 1) {
                    tempBalanceIn[index].amount += order.consideration[i].startAmount;
                } else {
                    inTokenAddresses[inLength] = order.consideration[i].token;
                    tempBalanceIn[inLength] =
                        BalanceIn(order.consideration[i].startAmount, order.consideration[i].token);
                    inLength++;
                }
            }
        }
/*
        BalanceOutSimplified[] memory balanceOutSimplified = new BalanceOutSimplified[](outLength);
        for (uint256 i; i < outLength; i++) {
            balanceOutSimplified[i].token = getTokenNameByAddress(tempBalanceOut[i].token);
            balanceOutSimplified[i].amount = tempBalanceOut[i].amount;
        }

        BalanceInSimplified[] memory balanceInSimplified = new BalanceInSimplified[](inLength);
        for (uint256 i; i < inLength; i++) {
            balanceInSimplified[i].token = getTokenNameByAddress(tempBalanceIn[i].token);
            balanceInSimplified[i].amount = tempBalanceIn[i].amount;
        }
  */    
        balanceInSimplifiedMessage = new BalanceInSimplifiedMessage[](inLength);
        for (uint256 i; i < inLength; i++) {
            balanceInSimplifiedMessage[i].inMessage = string(abi.encodePacked("You will receive ", toString(tempBalanceIn[i].amount), " of ", getTokenNameByAddress(tempBalanceIn[i].token)));
        }

        balanceOutSimplifiedMessage = new BalanceOutSimplifiedMessage[](outLength);
        for (uint256 i; i < outLength; i++) {
            balanceOutSimplifiedMessage[i].outMessage = string(abi.encodePacked("You will list ", toString(tempBalanceOut[i].amount), " of ", getTokenNameByAddress(tempBalanceOut[i].token)));
        }

        return (sigMessage, balanceOutSimplifiedMessage, balanceInSimplifiedMessage, order.endTime);
    }
}