// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "../base/Executor.sol";

/**
 * @title Simulate Transaction Accessor.
 * @notice Can be used with StorageAccessible to simulate Safe transactions.
 * @author Richard Meissner - @rmeissner
 */
contract SimulateTxAccessor is Executor {
    address private immutable accessorSingleton;

    constructor() {
        accessorSingleton = address(this);
    }

    /**
     * @notice Modifier to make a function callable via delegatecall only.
     * If the function is called via a regular call, it will revert.
     */
    modifier onlyDelegateCall() {
        require(address(this) != accessorSingleton, "SimulateTxAccessor should only be called via delegatecall");
        _;
    }

    /**
     * @notice Simulates a Safe transaction and returns the used gas, success boolean and the return data.
     * @dev Executes the specified operation {Call, DelegateCall} and returns operation-specific data.
     *      Has to be called via delegatecall.
     *      This returns the data equal to `abi.encode(uint256(etimate), bool(success), bytes(returnData))`.
     *      Specifically, the returndata will be:
     *      `estimate:uint256 || success:bool || returnData.length:uint256 || returnData:bytes`.
     * @param to Destination address .
     * @param value Native token value.
     * @param data Data payload.
     * @param operation Operation type {Call, DelegateCall}.
     * @return estimate Gas used.
     * @return success Success boolean value.
     * @return returnData Return data.
     */
    function simulate(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external onlyDelegateCall returns (uint256 estimate, bool success, bytes memory returnData) {
        uint256 startGas = gasleft();
        success = execute(to, value, data, operation, gasleft());
        estimate = startGas - gasleft();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Load free memory location
            let ptr := mload(0x40)
            // We allocate memory for the return data by setting the free memory location to
            // current free memory location + data size + 32 bytes for data size value
            mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
            // Store the size
            mstore(ptr, returndatasize())
            // Store the data
            returndatacopy(add(ptr, 0x20), 0, returndatasize())
            // Point the return data to the correct memory location
            returnData := ptr
        }
    }
}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;
import "../common/Enum.sol";

/**
 * @title Executor - A contract that can execute transactions
 * @author Richard Meissner - @rmeissner
 */
abstract contract Executor {
    /**
     * @notice Executes either a delegatecall or a call with provided parameters.
     * @param to Destination address.
     * @param value Ether value.
     * @param data Data payload.
     * @param operation Operation type.
     * @return success boolean flag indicating if the call succeeded.
     */
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 txGas
    ) internal returns (bool success) {
        if (operation == Enum.Operation.DelegateCall) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
            }
        } else {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
            }
        }
    }
}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Enum - Collection of enums used in Safe contracts.
 * @author Richard Meissner - @rmeissner
 */
abstract contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}