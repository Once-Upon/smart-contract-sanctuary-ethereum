// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "@solidstate/contracts/access/ownable/Ownable.sol";
import "./LibKoboldMultipliers.sol";
import {KoboldStakingMultiplier}  from "./IKoboldMultiplier.sol";

contract KoboldItemsFacet is Ownable {
    

    function test() external view onlyOwner returns(address) {
        return owner();
    }

    function setMultiplier(uint _price, uint _multiplier, string memory _name) external onlyOwner  {
        LibKoboldMultipliers.setMultiplier(_price,_multiplier,_name);

    }

    function getKoboldMultiplier(uint koboldMultiplierId) external view returns(KoboldStakingMultiplier memory) {
       return LibKoboldMultipliers.getKoboldMultiplier(koboldMultiplierId);
    }

 
}

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;   
    struct KoboldStakingMultiplier {
        uint price;
        uint multiplier; //5  = 5%
        string name;
    }

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;
import {KoboldStakingMultiplier}  from "./IKoboldMultiplier.sol";
library LibKoboldMultipliers {
    //Storage
    bytes32 internal constant NAMESPACE = keccak256("titanforge.kobold.multipliers");

    struct Storage{
        mapping(uint => KoboldStakingMultiplier) multipliers;
        mapping(address => mapping(uint => uint)) balanceOf;
        mapping(address => bool) approvedPurchaser;
        uint koboldMultiplierIdTracker;
    }
    
    function getStorage() internal pure returns(Storage storage s)  {
        bytes32 position = NAMESPACE;
        assembly{
            s.slot := position
        }
    }
    function purchaseMultiplier(address from,uint koboldMultiplierId,uint numMultipliersToBuy) internal {
        Storage storage s = getStorage();
        require(s.approvedPurchaser[msg.sender]);
        s.balanceOf[from][koboldMultiplierId] += numMultipliersToBuy;
    }
    function spendMultiplier(address from,uint koboldMultiplierId,uint numMultipliersToSpend) internal {
        Storage storage s = getStorage();
        require(s.approvedPurchaser[msg.sender]);
        if(numMultipliersToSpend > s.balanceOf[from][koboldMultiplierId]) revert ("Kobold Multiplier: Insufficient Multiplier Balance");
        s.balanceOf[from][koboldMultiplierId] -= numMultipliersToSpend;
    }
    function getKoboldMultiplier(uint koboldMultiplierId) internal view returns(KoboldStakingMultiplier memory) {
        Storage storage s = getStorage();
        return s.multipliers[koboldMultiplierId];
    }
    function setMultiplier(uint _price, uint _multiplier, string memory _name) internal {
        Storage storage s = getStorage();
        s.multipliers[s.koboldMultiplierIdTracker] = KoboldStakingMultiplier({
            price:_price,
            multiplier:_multiplier,
            name:_name
        });
        ++s.koboldMultiplierIdTracker;
    }
    function overrideExistingMultiplier(uint multiplierId,uint _price, uint _multiplier, string memory _name) internal {
        Storage storage s = getStorage();
          s.multipliers[multiplierId] = KoboldStakingMultiplier({
            price:_price,
            multiplier:_multiplier,
            name:_name
        });
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173 } from '../IERC173.sol';
import { IOwnable } from './IOwnable.sol';
import { OwnableInternal } from './OwnableInternal.sol';
import { OwnableStorage } from './OwnableStorage.sol';

/**
 * @title Ownership access control based on ERC173
 */
abstract contract Ownable is IOwnable, OwnableInternal {
    using OwnableStorage for OwnableStorage.Layout;

    /**
     * @inheritdoc IERC173
     */
    function owner() public view virtual returns (address) {
        return _owner();
    }

    /**
     * @inheritdoc IERC173
     */
    function transferOwnership(address account) public virtual onlyOwner {
        _transferOwnership(account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library OwnableStorage {
    struct Layout {
        address owner;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.Ownable');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function setOwner(Layout storage l, address owner) internal {
        l.owner = owner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { AddressUtils } from '../../utils/AddressUtils.sol';
import { IERC173 } from '../IERC173.sol';
import { IOwnableInternal } from './IOwnableInternal.sol';
import { OwnableStorage } from './OwnableStorage.sol';

abstract contract OwnableInternal is IOwnableInternal {
    using AddressUtils for address;
    using OwnableStorage for OwnableStorage.Layout;

    modifier onlyOwner() {
        require(msg.sender == _owner(), 'Ownable: sender must be owner');
        _;
    }

    modifier onlyTransitiveOwner() {
        require(
            msg.sender == _transitiveOwner(),
            'Ownable: sender must be transitive owner'
        );
        _;
    }

    function _owner() internal view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function _transitiveOwner() internal view virtual returns (address) {
        address owner = _owner();

        while (owner.isContract()) {
            try IERC173(owner).owner() returns (address transitiveOwner) {
                owner = transitiveOwner;
            } catch {
                return owner;
            }
        }

        return owner;
    }

    function _transferOwnership(address account) internal virtual {
        OwnableStorage.layout().setOwner(account);
        emit OwnershipTransferred(msg.sender, account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173 } from '../IERC173.sol';

interface IOwnable is IERC173 {}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173Internal } from './IERC173Internal.sol';

/**
 * @title Contract ownership standard interface
 * @dev see https://eips.ethereum.org/EIPS/eip-173
 */
interface IERC173 is IERC173Internal {
    /**
     * @notice get the ERC173 contract owner
     * @return conrtact owner
     */
    function owner() external view returns (address);

    /**
     * @notice transfer contract ownership to new account
     * @param account address of new owner
     */
    function transferOwnership(address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173Internal } from '../IERC173Internal.sol';

interface IOwnableInternal is IERC173Internal {}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { UintUtils } from './UintUtils.sol';

library AddressUtils {
    using UintUtils for uint256;

    function toString(address account) internal pure returns (string memory) {
        return uint256(uint160(account)).toHexString(20);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable account, uint256 amount) internal {
        (bool success, ) = account.call{ value: amount }('');
        require(success, 'AddressUtils: failed to send value');
    }

    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionCall(target, data, 'AddressUtils: failed low-level call');
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory error
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, error);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                'AddressUtils: failed low-level call with value'
            );
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory error
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            'AddressUtils: insufficient balance for call'
        );
        return _functionCallWithValue(target, data, value, error);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory error
    ) private returns (bytes memory) {
        require(
            isContract(target),
            'AddressUtils: function call to non-contract'
        );

        (bool success, bytes memory returnData) = target.call{ value: value }(
            data
        );

        if (success) {
            return returnData;
        } else if (returnData.length > 0) {
            assembly {
                let returnData_size := mload(returnData)
                revert(add(32, returnData), returnData_size)
            }
        } else {
            revert(error);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC173 interface needed by internal functions
 */
interface IERC173Internal {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title utility functions for uint256 operations
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts/ (MIT license)
 */
library UintUtils {
    bytes16 private constant HEX_SYMBOLS = '0123456789abcdef';

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return '0';
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return '0x00';
        }

        uint256 length = 0;

        for (uint256 temp = value; temp != 0; temp >>= 8) {
            unchecked {
                length++;
            }
        }

        return toHexString(value, length);
    }

    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = '0';
        buffer[1] = 'x';

        unchecked {
            for (uint256 i = 2 * length + 1; i > 1; --i) {
                buffer[i] = HEX_SYMBOLS[value & 0xf];
                value >>= 4;
            }
        }

        require(value == 0, 'UintUtils: hex length insufficient');

        return string(buffer);
    }
}