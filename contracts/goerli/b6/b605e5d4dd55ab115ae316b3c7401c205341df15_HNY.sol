// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: HANNYA
/// @author: manifold.xyz

import "./manifold/ERC721Creator.sol";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                            //
//                                                                                                            //
//    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~~~~~~~~~!!!    //
//    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~~~~~~~!!!!!!    //
//    ~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^:7?:^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~^^^^^^~~~~~~~~!!!!!!    //
//    ~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^::^^^^^^P?:^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^77^^~~~~~~~~~~~!!!!!!    //
//    ~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^::::~!!^^^^^^BY:^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~5~^^^~~~~~~~~~~~!!!!    //
//    ~~~~~~^^^^^^^^^^^^^^^^^^^^:::^7?YP#&#G55J!7#G7!~^^::^^^^^^^^^^^^^^^^^^^^^^^^^^^^JY^^~~~~~~~~~~~!!!!!    //
//    ~~~~~~~^^^^^^^^^^^^^^^^^^^?JYB##&@&#BB#B#B&#GBBGG5YJ~:^^^^^^^^^^^^^^^^^^^^^^^^^^~G?^~~~~~~~~~~!!!!!!    //
//    ~~~~~~^^^^^^^^^^^^^^^^^^[email protected]&@&#&&####B#B#B##PB#B##@@B!^^^^^^^^^^^^^^^^^^^^^^^^^^^PP!^~~~~~~~~~!!!!!!    //
//    ~~~~~~~^^^^^^^^^^^^^^^^:7&&&&&&&&&&&&#####&#PG###BBB#BP5J!^^^^^^^^^^^^^^^^^^^^^^7PP7^~~~~~~~~~~~!!!!    //
//    ~~~~~~~^^^^^^^^^^^^^^^~Y#&&&&&#&&@&&&&&&#B&&BPGGGGBGGGBBBGJ~^^^^^^^^^^^^^^^^^^^75PP!^~~~~~~~~~~!!!!!    //
//    ~~~~~~~^^^^^^^^^^^^^^[email protected]&&&&@&&@&&&&&&&#B#&&#PPBGGB#BBBBGGBP~:^^^^^^^^^^^^^^^~J55P?^~~~~~~~~~~!!!!!!    //
//    ~~^^^^^^^^^^^^^^^^^^?#@&@&&@@&&@&&@&&&&&&#B&&#GPBBB#&###&###G7?J7^^^^^^^^^^~?Y55PJ^^~~~~~~~~~!!!!!!!    //
//    ~~^^^^^^~^^^^^^^^^^Y&&&@@@@@&&&@&@@@@@&&#BB&@@#BGB&&&&&&&&&@&##&B^^^^^^^^^7YJJ5GJ^^~~~~~~~~~~~~!!!!!    //
//    ~~~^^^^^^^^^^^^^^^[email protected]&&@@&@@&&&@@@@@@@&&&&###@@@&BBGB#BGGGGB##&##G7~^^^^~7J555PG7^^^~~~~~~~~~~~~~~!!!    //
//    ~~~^^^^^^^^^^^^^^^?&&&@@&@&&&@@@@@@@@@&&&&###@@@#GPY5BBGGGPPGB##GGP5J!755YYPBP!^^^^~~~~~~~~~~~~~~!!!    //
//    ~~~~~~^^^^^^^^^^^^~#@@&@@@@&&@@@@&@@@&&&##BBB&@@@#5JY5G#BGGGGPPB#GGGBGYJYPGBY^^^^^~~~~~~~~~~~~~~~!!!    //
//    ~~~~^^^^^^^^^^^^^?#@&@@@@@&&@@&@@@@@@&&####&&@@@@@#GP5G##BBBBBGGG#BGGGBGGB#7^^^~~~~~~~~~~~~~~~!!!!!!    //
//    ~~~~~^^^^^^^^^^^!&@@@@@@@&&&@@@@@@@@@&&&&&&&@@@@@&&#GBBBBB###BBBBB#BBG#BB#?:^^^~~~~~~~~~~~~~~!!!!!!!    //
//    ~~~~~~~^^^^^^^^^^5#@@@@@@@&&@@@@@@@@@@@&&&&&&@@&&##&#BBBBBBB&&&&&&&##BBGGBB?^^^^~~~~~~~~~~~~~~~!!!!!    //
//    ~~~~~~~~~^^^^^^^^^[email protected]@@@@@@&@@@@@@@@@@@@@&&&&&&&&&&&###BB##&#G5JYGB&@&##&#GB&Y^^^~~~~~~~~~~~~~~!!!!!!    //
//    ~~~~~~~~~~~^^~^^^^[email protected]@@@&@@&&@@@@@@@@@@@@@@@@@&&&&&&&##&#&G?^.. ...^5P:^7G&B#&?^~~~~~~~~~~~~~~~!!!!!!    //
//    ~~~~~~~~^^^^^^^^JB&@@@@@@@@@@@@@@@@@@@@@@@@@@@@&&&&&&&&#?:.........:5. .:[email protected]###!^^~~~~~~~~~~~~~!!!!!!    //
//    ~~~~~^^^^^^^^^^!&@&@@@@@@@@@@@@@@@@@@@&@@@@@@@@@&&&&&&G~...........:[email protected]&#&P^^~~~~~~~~~~~~~~~!!!!    //
//    ~~~~~~~^~~^^^^^!&@@@@@@@@@@@@@@@@@@@@#PGG#@@&&&&&&&&&&~ ......... .J! ...~&@#&#~^~~~~~~~~~~~~~~~!!!!    //
//    ~~~~~~~~~~~^~^^^7&BY#@@@@@@@@@@@@@@@@[email protected]&&&@&&@@@#:...     . .Y7 ....~&@&#&!^~~~~~~~~~~~~~~~~!!!    //
//    ~~~~~~~~~~~~^[email protected]:!&@@@@@@@@@@@@@@@#7!GG?&&@@@@&@&@B:^~!!!~:..~Y~  [email protected]@&#&7^~~~~~~~~~~~~~~~~~!!    //
//    ~~~~~~~~~~~~^Y&GYJ~^^[email protected]@@@@@@@@@@@@@@Y!YYJ&@@@@&&&&&&^....:~7J5Y: :[email protected]@#&@J^~~~~~~~~~~~~~~~!!!!    //
//    ~~~~~~~~~~~~^J&J~~^~^^[email protected]@@@@@@@@@@@@@@@Y!?G&@@@@&&&&&&#BPY?7::^~:..:^:::!&@&#&&B~^~~~~~~~~~~~~!!!!!!    //
//    ~~~~~~~~~~~~~~?Y5GJ^~^[email protected]@@@@@@@@@@@@@@@@#YG&@@@&&&&@&?P5GBGGY:::..:~YG#&@@@&#&&&Y^~~~~~~~~~~~!!!!!!!    //
//    ~~~~~~~~~~~~~^^^7PJ^~!#@@@@@@@@@@@@@@@@@@JG&@@@&&@@@G !: .........:[email protected]@@#&&#&B7^~~~~~~~~~!!!!!!!!    //
//    ~~~~~~~~~~~~~7???~^[email protected]@@@@@@@@@@@@@@@@@Y5#@@@&&@@&7 .:..........:... ~&@@##&#&B5~~~~~~~~~~~!!!!!!!    //
//    ~~~~~~~~~~~~7?!~^^^7G&@@@@@@@@@@@@@@@@@@&[email protected]@@@&&@#^........... .:.. :[email protected]&@&##&#G57~~~~~~~~~~~~!!!!!    //
//    ~~~~~~~~~~~~~~~^!5G&@@@@@@[email protected]@@@@@@@@@@&?J7?#@@@&&@#~ .......:~7~7:[email protected]&&&&&#&#PY?~~~~~~~~~~~~!!!!!    //
//    !!!~~~~~~~~~~~~?#@@@&@@&#P!~7J&@@@@@@@@[email protected]@@&&&B~.  ... .:~^..:[email protected]@&&&&&&&&#YJ!~~~~~~~~~~~!!!!!!    //
//    [email protected]&&&@57!~~~~~^[email protected]@@@@@P...:~~!?G&@@#GG7^:.:^?5GPJ:^JGG&GG&@&#@#Y!7~~~~~~~~~~~~!!!!!!    //
//    !!!!~~~~~~~~~~~G&&&&#7^[email protected]@&@@P. ....::::[email protected]@BBY^^. .5GPY!~~~~7#7B&GY##7~!~~~~~~~~~!!!!!!!!!!    //
//    !!!!!!!!!!!!!~~P&&&&J~~~~~~~~~~5&&&#J..     ..::::[email protected]!#GJ!^~??!~~~~~~B5J57~P#!~~~~~~~~~~~~~~!!!!!!!!    //
//    !!!!!!!!!!!!!~?&&&&&#GGBG5?~~~~~J#&BGBGP5?~:...:::[email protected][email protected]@@5~7!~~~~~~?&J!~^?#7~~~~~~~~~~~~~~~!!!!!!!!    //
//    !!!!!!!!!!!!!!~J&&&&@@@&&&&5~~~7B&#####&&&&#GY7^[email protected]?:JB&#YJ?!~~~~~J&7~!~5?~~~~~~~~~~~~~~!!!!!!!!!7    //
//    !!!!!!!!!!!!!!!!?5PP5Y5#&&&&?~Y#&#####BBB###&&&#P?:YB~:.^5#&###5!~~~7#!~!!P!~!~~~~~~~~~~!!!!!!!!!!77    //
//    !!!!!!!!!!!!!!!!!!!!~~!G&#B57P&&################&&B5#Y....P#&#&&G7~~~PY~!!G7~!!!!!!!!!!!!!!!!!!!!!77    //
//    !!!!!!!!!!!!!!!!!!!!77J&&G!!P&&&&&&&&&############&##&5:  !&&&#&&#Y!~7Y?!!YP!!!!!!!!!!!!!!!!!!!!!!!7    //
//    7!77!!7!777!!7!75PGGB#&&&P!5&&&&&&&&&&############&&&#&B?.:#&&&&&&&BJ?77!!!PY!!!!!!!!!!!!!!!!!!!!!77    //
//    77777777777777?#G55J7?JJ?!Y&&&&&&&&&&&&&#&&&#######&&&&&&G7#&&&#&&&&&&BJ!!!!YJ!!!!!!!!!!!!!!!!!!!777    //
//    77777777777777?&Y!!77777!5&&&&&&&&&&&&&&&&&&#&&&&&&&#&&&&&&&&&&&&&&&&&&&G7!!7Y?!!!!!!!!!!!!!!!!77777    //
//    777777777777777J5YJ?77775&@&&&&&&@&&&&&&&&&&&&&&&&&&&##&&&&&&&&&&&&&&&&&#7!!7??!!!!!!!7!7!77777J?JJ7    //
//    [email protected]@&&&&&&&@&&&&&&&&&&&&&&&&#&&&&&#&&&&&&&&&&&&@&&#?77!J?!77777777777777?J?JJ?    //
//    ?????????????????777?B&&&&&&&&@&&@&@@&@@@@@@&&&&&&&&&&&&&&&&@&&&&&&&@@&&@@P!7?J7777777777777777?YY?7    //
//    ?????????????????77!P&&&&&&&@&@@@&&@@&@@@&&&&&&&&@@@&&&&&&&&&@@&&&@@@&@@@@#?77?Y?7777777777777?5YPJ7    //
//                                                                                                            //
//                                                                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////


contract HNY is ERC721Creator {
    constructor() ERC721Creator("HANNYA", "HNY") {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

contract ERC721Creator is Proxy {
    
    constructor(string memory name, string memory symbol) {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = 0xEB067AfFd7390f833eec76BF0C523Cf074a7713C;
        Address.functionDelegateCall(
            0xEB067AfFd7390f833eec76BF0C523Cf074a7713C,
            abi.encodeWithSignature("initialize(string,string)", name, symbol)
        );
    }
        
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
     function implementation() public view returns (address) {
        return _implementation();
    }

    function _implementation() internal override view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }    

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}