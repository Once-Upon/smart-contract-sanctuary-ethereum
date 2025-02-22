/**
 *Submitted for verification at Etherscan.io on 2022-11-26
*/

//contracts/OceanToken.sol
//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

abstract contract Upgradeable{
    mapping(bytes4 => uint32) _sizes;
    address _dest;

    function initialize() virtual public;

    function replace(address target) public{
        _dest = target;
        target.delegatecall(abi.encodeWithSelector(bytes4(keccak256("initialize()"))));
    }
}

contract Dispatcher is Upgradeable{
    constructor(address target){
        replace(target);
    }

    function initialize() override public{
        assert(false);
    }

    fallback() external{
        bytes4 sig;
        assembly{ sig := calldataload(0)}
        uint len = _sizes[sig];
        address target = _dest;

        assembly{
            calldatacopy("0X0", "0X0", calldatasize())
            let result := delegatecall(sub(gas(), 10000), target, "0X0", calldatasize(), 0, len)
            return(0, len)
        }
    }
}

contract Example is Upgradeable{
    uint _value;

    function initialize() override public{
        _sizes[bytes4(keccak256("getUint()"))] = 32;
    }

    function getUint() public view returns (uint){
        return _value;
    }

    function setUint(uint value) public{
        _value = value;
    }
}