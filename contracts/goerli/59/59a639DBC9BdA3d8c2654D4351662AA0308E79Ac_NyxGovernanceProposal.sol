// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NyxProposal.sol";
import "./interfaces/INyxGovernanceProposal.sol";

contract NyxGovernanceProposal is NyxProposal, INyxGovernanceProposal {
    string public constant name = "NyxAllocationProposal";
    uint256 public constant nparams = 4;

    // Constructor
    ////////////////////
    constructor()
    {
        
    }

    // Struct to bytes and vice-versa
    //////////////////////////////////////

    function parseProposalParams(bytes[] memory params)
        public pure
        returns (GovernanceProposalParams memory)
    {
        require(params.length == nparams, "wrong format");

        return GovernanceProposalParams(bytesToAddress(params[0]),
            GovernanceAddressAction(bytesToUint(params[1])),
            bytesToString(params[2]),
            bytesToString(params[3]));
    }

    function parseProposalParams(bytes memory params)
        public pure
        returns (GovernanceProposalParams memory)
    {
        if (keccak256(params) != keccak256(bytes("")))
        {
            (address param1, uint256 param2, string memory param3, string memory param4) = abi.decode(params, (address, uint256, string, string));
            return GovernanceProposalParams(param1, GovernanceAddressAction(param2), param3, param4);
        }
        else
        {
            GovernanceProposalParams memory nullProposal;
            return nullProposal;
        }
    }

    function proposalToBytes(GovernanceProposal memory proposal)
        public pure
        returns (bytes memory)
    {
        return abi.encode(proposal.ambassadorAddress, proposal.action, proposal.socialNetworkLink, proposal.ambassadorDescription);
    }

    // Proposal Creators
    /////////////////////

    function createProposal(uint256 proposalId, bytes[] memory params)
        public pure
        override
        returns (bytes memory)
    {
        GovernanceProposalParams memory parsedParams = parseProposalParams(params);
        GovernanceProposal memory proposal = GovernanceProposal(proposalId, parsedParams.ambassadorAddress, parsedParams.action,
            parsedParams.socialNetworkLink, parsedParams.ambassadorDescription);

        return proposalToBytes(proposal);
    }

    // Proposal Getters
    /////////////////////

    function getProposal(bytes memory proposalBytes)
        public pure
        override
        returns (bytes[] memory)
    {
        GovernanceProposalParams memory params = parseProposalParams(proposalBytes);
        bytes[] memory prop = new bytes[](nparams);
        prop[0] = abi.encode(params.ambassadorAddress);
        prop[1] = abi.encode(uint256(params.action));
        prop[2] = abi.encode(params.socialNetworkLink);
        prop[3] = abi.encode(params.ambassadorDescription);
        return prop;
    }
    
    function getProposals(bytes[] memory proposalBytesArr)
        public pure
        returns (bytes[nparams][] memory props)
    {
        props = new bytes[nparams][](proposalBytesArr.length);
        for (uint256 idx = 0; idx < proposalBytesArr.length; idx++)
        {
            GovernanceProposalParams memory params = parseProposalParams(proposalBytesArr[idx]);
            props[idx] = [abi.encode(params.ambassadorAddress), abi.encode(params.action), abi.encode(params.socialNetworkLink), abi.encode(params.ambassadorDescription)];
        }
    }

    // Proposal Setllers
    //////////////////////
    // function parseSettlementParams(bytes memory settlementParams)
    //     public
    //     returns (SettlementParams memory)
    // {
    //     if (keccak256(settlementParams) != keccak256(bytes("")))
    //     {
    //         (address param1, string memory param2, string[] memory param3) = abi.decode(settlementParams, (address, string, string[]));
    //         return SettlementParams(param1, param2, param3);
    //     }
    //     else
    //     {
    //         SettlementParams memory nullParams;
    //         return nullParams;
    //     }
    // }

    // function settleProposal(bytes memory proposalBytes, bytes memory settlementParams)
    //     public
    //     returns (bool, bytes memory)
    // {
    //     SettlementParams memory parsedParams = parseSettlementParams(settlementParams);
    // 
    //     // Building function signature string
    //     string memory functionSignature = parsedParams.settlementFunction;
    //     functionSignature = string(abi.encodePacked(functionSignature, "("));
    //     for (uint256 idx; idx < parsedParams.settlementFunctionParamTypes.length; idx++)
    //     {
    //         functionSignature = string(abi.encodePacked(functionSignature, parsedParams.settlementFunctionParamTypes[idx]));
    //         if (idx < parsedParams.settlementFunctionParamTypes.length  -1)
    //         {
    //             functionSignature = string(abi.encodePacked(functionSignature, ","));
    //         }
    //     }
    //     functionSignature = string(abi.encodePacked(functionSignature, ")"));
    // 
    //     // Building paramsBytes
    //     bytes memory paramsBytes = abi.encodeWithSignature(functionSignature, parsedParams.settlementFunctionParamTypes);
    //     // for (uint256 idx = 1; idx < parsedParams.settlementFunctionParamTypes.length; idx++)
    //     // {
    //     //     paramsBytes = abi.encodeWithSignature(paramsBytes, parsedParams.settlementFunctionParamTypes[idx]);
    //     // }
    // 
    //     (bool success, bytes memory result) = (0xDE5b6e9C6154e9FF2b50504C2E9f593A9D055873).call(paramsBytes);
    //     require(success, "contract call failed");
    //     return (success, result);
    // }
}

// SPDX-License-Identifier: MIT

// @title INyxGovernanceProposal for Nyx DAO
// @author TheV

//  ________       ___    ___ ___    ___      ________  ________  ________     
// |\   ___  \    |\  \  /  /|\  \  /  /|    |\   ___ \|\   __  \|\   __  \    
// \ \  \\ \  \   \ \  \/  / | \  \/  / /    \ \  \_|\ \ \  \|\  \ \  \|\  \   
//  \ \  \\ \  \   \ \    / / \ \    / /      \ \  \ \\ \ \   __  \ \  \\\  \  
//   \ \  \\ \  \   \/  /  /   /     \/        \ \  \_\\ \ \  \ \  \ \  \\\  \ 
//    \ \__\\ \__\__/  / /    /  /\   \         \ \_______\ \__\ \__\ \_______\
//     \|__| \|__|\___/ /    /__/ /\ __\         \|_______|\|__|\|__|\|_______|
//               \|___|/     |__|/ \|__|       

pragma solidity ^0.8.0;

interface INyxGovernanceProposal {
    // Enums
    ////////////////////
    enum GovernanceAddressAction{ADD, REMOVE}

    // Structs
    ////////////////////
    struct GovernanceProposal
    {
        uint256 id;
        address ambassadorAddress;
        GovernanceAddressAction action;
        string socialNetworkLink;
        string ambassadorDescription;
    }

    struct GovernanceProposalParams
    {
        address ambassadorAddress;
        GovernanceAddressAction action;
        string socialNetworkLink;
        string ambassadorDescription;
    }

    struct SettlementParams
    {
        address nftContractAddress;
        string settlementFunction;
        string[] settlementFunctionParamTypes;

    }

    function parseProposalParams(bytes[] memory params) external pure returns (GovernanceProposalParams memory);
    function parseProposalParams(bytes memory params) external pure returns (GovernanceProposalParams memory);
    function proposalToBytes(GovernanceProposal memory proposal) external pure returns (bytes memory);
    // function getProposals(bytes[] memory proposalBytesArr) external pure returns (bytes[nparams][] memory props);
}

// SPDX-License-Identifier: MIT

// @title NyxProposal for Nyx DAO
// @author TheV

//  ________       ___    ___ ___    ___      ________  ________  ________     
// |\   ___  \    |\  \  /  /|\  \  /  /|    |\   ___ \|\   __  \|\   __  \    
// \ \  \\ \  \   \ \  \/  / | \  \/  / /    \ \  \_|\ \ \  \|\  \ \  \|\  \   
//  \ \  \\ \  \   \ \    / / \ \    / /      \ \  \ \\ \ \   __  \ \  \\\  \  
//   \ \  \\ \  \   \/  /  /   /     \/        \ \  \_\\ \ \  \ \  \ \  \\\  \ 
//    \ \__\\ \__\__/  / /    /  /\   \         \ \_______\ \__\ \__\ \_______\
//     \|__| \|__|\___/ /    /__/ /\ __\         \|_______|\|__|\|__|\|_______|
//               \|___|/     |__|/ \|__|       

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../utils/converter_contract.sol";

abstract contract NyxProposal is Converter {
    // Proposal Creators
    /////////////////////

    function createProposal(uint256 proposalId, bytes[] memory params) external virtual pure returns (bytes memory);
    
    // Proposal Getters
    /////////////////////
    function getProposal(bytes memory proposalBytes) external virtual pure returns (bytes[] memory);
}

// SPDX-License-Identifier: MIT

// @title INyxDAO for Nyx DAO
// @author TheV

//  ________       ___    ___ ___    ___      ________  ________  ________     
// |\   ___  \    |\  \  /  /|\  \  /  /|    |\   ___ \|\   __  \|\   __  \    
// \ \  \\ \  \   \ \  \/  / | \  \/  / /    \ \  \_|\ \ \  \|\  \ \  \|\  \   
//  \ \  \\ \  \   \ \    / / \ \    / /      \ \  \ \\ \ \   __  \ \  \\\  \  
//   \ \  \\ \  \   \/  /  /   /     \/        \ \  \_\\ \ \  \ \  \ \  \\\  \ 
//    \ \__\\ \__\__/  / /    /  /\   \         \ \_______\ \__\ \__\ \_______\
//     \|__| \|__|\___/ /    /__/ /\ __\         \|_______|\|__|\|__|\|_______|
//               \|___|/     |__|/ \|__|       

pragma solidity ^0.8.0;

import "./IConverter.sol";

contract Converter is IConverter {
    function stringToBytes(string memory str)
        public pure
        returns (bytes memory)
    {
        return bytes(str);
    }

    function bytesToString(bytes memory strBytes)
        public pure
        returns (string memory)
    {
        return string(strBytes);
    }

    function stringArrayToBytesArray(string[] memory strArray)
        public pure
        returns (bytes[] memory)
    {
        bytes[] memory bytesArray = new bytes[](strArray.length);
        for (uint256 idx = 0; idx < strArray.length; idx++)
        {
            bytes memory bytesElem = bytes(strArray[idx]);
            bytesArray[idx] = bytesElem;
        }
        return bytesArray;
    }

    function bytesArrayToStringAray(bytes[] memory bytesArray)
        public pure
        returns (string[] memory)
    {
        string[] memory strArray = new string[](bytesArray.length);
        for (uint256 idx = 0; idx < bytesArray.length; idx++)
        {
            string memory strElem = string(bytesArray[idx]);
            strArray[idx] = strElem;
        }
        return strArray;
    }

    function intToBytes(int256 i)
        public pure
        returns (bytes memory)
    {
        return abi.encodePacked(i);
    }

    function bytesToUint(bytes memory iBytes)
        public pure
        returns (uint256)
    {
        uint256 i;
        for (uint idx = 0; idx < iBytes.length; idx++)
        {
            i = i + uint(uint8(iBytes[idx])) * (2**(8 * (iBytes.length - (idx + 1))));
        }
        return i;
    }

    // function addressToBytes(address addr)
    //     public pure
    //     returns (bytes memory)
    // {
    //     return bytes(bytes8(uint64(uint160(addr))));
    // }

    function bytesToAddress(bytes memory addrBytes)
        public pure
        returns (address)
    {
        address addr;
        assembly
        {
            addr := mload(add(addrBytes,20))
        }
        return addr;
    }

    function bytesToBool(bytes memory boolBytes)
        public pure
        returns (bool)
    {
        return abi.decode(boolBytes, (bool));
    }

    function boolToBytes(bool b)
        public pure
        returns (bytes memory)
    {
        return abi.encode(b);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

// @title IConverter for Nyx DAO
// @author TheV

//  ________       ___    ___ ___    ___      ________  ________  ________     
// |\   ___  \    |\  \  /  /|\  \  /  /|    |\   ___ \|\   __  \|\   __  \    
// \ \  \\ \  \   \ \  \/  / | \  \/  / /    \ \  \_|\ \ \  \|\  \ \  \|\  \   
//  \ \  \\ \  \   \ \    / / \ \    / /      \ \  \ \\ \ \   __  \ \  \\\  \  
//   \ \  \\ \  \   \/  /  /   /     \/        \ \  \_\\ \ \  \ \  \ \  \\\  \ 
//    \ \__\\ \__\__/  / /    /  /\   \         \ \_______\ \__\ \__\ \_______\
//     \|__| \|__|\___/ /    /__/ /\ __\         \|_______|\|__|\|__|\|_______|
//               \|___|/     |__|/ \|__|                       

pragma solidity ^0.8.0;

interface IConverter
{
    function stringToBytes(string memory str) external pure returns (bytes memory);
    function bytesToString(bytes memory strBytes) external pure returns (string memory);
    function stringArrayToBytesArray(string[] memory strArray) external pure returns (bytes[] memory);
    function bytesArrayToStringAray(bytes[] memory bytesArray) external pure returns (string[] memory);
    function intToBytes(int256 i) external pure returns (bytes memory);
    function bytesToUint(bytes memory iBytes) external pure returns (uint256);
    function bytesToAddress(bytes memory addrBytes) external pure returns (address);
    function bytesToBool(bytes memory boolBytes) external pure returns (bool);
    function boolToBytes(bool b) external pure returns (bytes memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}