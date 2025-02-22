/**
 *Submitted for verification at Etherscan.io on 2023-03-20
*/

/**
 *Submitted for verification at Etherscan.io on 2021-09-24
 */

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// File: contracts/thirdparty/loopring-wallet/ILoopringWalletV2.sol

// Taken from: https://github.com/Loopring/protocols/tree/master/packages/hebao_v2/contracts/iface/ILoopringWalletV2.sol
// Copyright 2017 Loopring Technology Limited.

/// @title Loopring SmartWallet V2 interface
/// @author Brecht Devos - <[email protected]>
abstract contract ILoopringWalletV2 {
    /// @dev Initializes the smart wallet.
    /// @param owner The wallet owner address.
    /// @param guardians The initial wallet guardians.
    /// @param quota The initial wallet quota.
    /// @param inheritor The inheritor of the wallet.
    /// @param feeRecipient The address receiving the fee for creating the wallet.
    /// @param feeToken The token to use for the fee payment.
    /// @param feeAmount The amount of tokens paid to the fee recipient.
    function initialize(
        address owner,
        address[] calldata guardians,
        uint256 quota,
        address inheritor,
        address feeRecipient,
        address feeToken,
        uint256 feeAmount
    ) external virtual;

    /// @dev Returns the timestamp the wallet was created.
    /// @return The timestamp the wallet was created.
    function getCreationTimestamp() public view virtual returns (uint64);

    /// @dev Returns the current wallet owner.
    /// @return The current wallet owner.
    function getOwner() public view virtual returns (address);
}

// File: contracts/thirdparty/Create2.sol

// Taken from: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/970f687f04d20e01138a3e8ccf9278b1d4b3997b/contracts/utils/Create2.sol

/**
 * @dev Helper to make usage of the `CREATE2` EVM opcode easier and safer.
 * `CREATE2` can be used to compute in advance the address where a smart
 * contract will be deployed, which allows for interesting new mechanisms known
 * as 'counterfactual interactions'.
 *
 * See the https://eips.ethereum.org/EIPS/eip-1014#motivation[EIP] for more
 * information.
 */
library Create2 {
    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}. Note that
     * a contract cannot be deployed twice using the same salt.
     */
    function deploy(bytes32 salt, bytes memory bytecode)
        internal
        returns (address payable)
    {
        address payable addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "CREATE2_FAILED");
        return addr;
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the `bytecode`
     * or `salt` will result in a new destination address.
     */
    function computeAddress(bytes32 salt, bytes memory bytecode)
        internal
        view
        returns (address)
    {
        return computeAddress(salt, bytecode, address(this));
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    function computeAddress(
        bytes32 salt,
        bytes memory bytecodeHash,
        address deployer
    ) internal pure returns (address) {
        bytes32 bytecodeHashHash = keccak256(bytecodeHash);
        bytes32 _data = keccak256(
            abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHashHash)
        );
        return address(bytes20(_data << 96));
    }
}

// File: contracts/thirdparty/proxies/WalletProxy.sol

// Taken from: https://github.com/gnosis/safe-contracts/blob/development/contracts/proxies/GnosisSafeProxy.sol

/// @title IProxy - Helper interface to access masterCopy of the Proxy on-chain
/// @author Richard Meissner - <[email protected]>
interface IProxy {
    function masterCopy() external view returns (address);
}

/// @title WalletProxy - Generic proxy contract allows to execute all transactions applying the code of a master contract.
/// @author Stefan George - <[email protected]>
/// @author Richard Meissner - <[email protected]>
contract WalletProxy {
    // masterCopy always needs to be first declared variable, to ensure that it is at the same location in the contracts to which calls are delegated.
    // To reduce deployment costs this variable is internal and needs to be retrieved via `getStorageAt`
    address internal masterCopy;

    /// @dev Constructor function sets address of master copy contract.
    /// @param _masterCopy Master copy address.
    constructor(address _masterCopy) {
        require(
            _masterCopy != address(0),
            "Invalid master copy address provided"
        );
        masterCopy = _masterCopy;
    }

    /// @dev Fallback function forwards all transactions and returns all received return data.
    fallback() external payable {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let _masterCopy := and(
                sload(0),
                0xffffffffffffffffffffffffffffffffffffffff
            )
            // 0xa619486e == keccak("masterCopy()"). The value is right padded to 32-bytes with 0s
            if eq(
                calldataload(0),
                0xa619486e00000000000000000000000000000000000000000000000000000000
            ) {
                mstore(0, _masterCopy)
                return(0, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(
                gas(),
                _masterCopy,
                0,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}

// File: contracts/thirdparty/loopring-wallet/WalletDeploymentLib.sol

// Taken from: https://github.com/Loopring/protocols/tree/master/packages/hebao_v2/contracts/base/WalletDeploymentLib.sol
// Copyright 2017 Loopring Technology Limited.

/// @title WalletDeploymentLib
/// @dev Functionality to compute wallet addresses and to deploy wallets
/// @author Brecht Devos - <[email protected]>
contract WalletDeploymentLib {
    address public immutable walletImplementation;

    string public constant WALLET_CREATION = "WALLET_CREATION";

    constructor(address _walletImplementation) {
        walletImplementation = _walletImplementation;
    }

    function getWalletCode() public view returns (bytes memory) {
        return
            hex"608060405234801561001057600080fd5b5060405161016f38038061016f8339818101604052602081101561003357600080fd5b50516001600160a01b03811661007a5760405162461bcd60e51b815260040180806020018281038252602481526020018061014b6024913960400191505060405180910390fd5b600080546001600160a01b039092166001600160a01b031990921691909117905560a2806100a96000396000f3fe6080604052600073ffffffffffffffffffffffffffffffffffffffff8154167fa619486e0000000000000000000000000000000000000000000000000000000082351415604e57808252602082f35b3682833781823684845af490503d82833e806067573d82fd5b503d81f3fea264697066735822122024cc448ad2b3c46cf2c4df5ec3cad75b28457ba4e489b5b9baf3c46a61ac576664736f6c63430007060033496e76616c6964206d617374657220636f707920616464726573732070726f766964656400000000000000000000000066e230202d16ccf00658350ccc1117def73cd0bb";
    }

    function computeWalletSalt(address owner, uint256 salt)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(WALLET_CREATION, owner, salt));
    }

    function _deploy(address owner, uint256 salt)
        internal
        returns (address payable wallet)
    {
        wallet = Create2.deploy(
            computeWalletSalt(owner, salt),
            getWalletCode()
        );
    }

    function _computeWalletAddress(
        address owner,
        uint256 salt,
        address deployer
    ) internal view returns (address) {
        return
            Create2.computeAddress(
                computeWalletSalt(owner, salt),
                getWalletCode(),
                deployer
            );
    }
}

// File: contracts/lib/AddressUtil.sol

// Copyright 2017 Loopring Technology Limited.

/// @title Utility Functions for addresses
/// @author Daniel Wang - <[email protected]>
/// @author Brecht Devos - <[email protected]>
library AddressUtil {
    using AddressUtil for *;

    function isContract(address addr) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(addr)
        }
        return (codehash != 0x0 &&
            codehash !=
            0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470);
    }

    function toPayable(address addr) internal pure returns (address payable) {
        return payable(addr);
    }

    // Works like address.send but with a customizable gas limit
    // Make sure your code is safe for reentrancy when using this function!
    function sendETH(
        address to,
        uint256 amount,
        uint256 gasLimit
    ) internal returns (bool success) {
        if (amount == 0) {
            return true;
        }
        address payable recipient = to.toPayable();
        /* solium-disable-next-line */
        (success, ) = recipient.call{value: amount, gas: gasLimit}("");
    }

    // Works like address.transfer but with a customizable gas limit
    // Make sure your code is safe for reentrancy when using this function!
    function sendETHAndVerify(
        address to,
        uint256 amount,
        uint256 gasLimit
    ) internal returns (bool success) {
        success = to.sendETH(amount, gasLimit);
        require(success, "TRANSFER_FAILURE");
    }

    // Works like call but is slightly more efficient when data
    // needs to be copied from memory to do the call.
    function fastCall(
        address to,
        uint256 gasLimit,
        uint256 value,
        bytes memory data
    ) internal returns (bool success, bytes memory returnData) {
        if (to != address(0)) {
            assembly {
                // Do the call
                success := call(
                    gasLimit,
                    to,
                    value,
                    add(data, 32),
                    mload(data),
                    0,
                    0
                )
                // Copy the return data
                let size := returndatasize()
                returnData := mload(0x40)
                mstore(returnData, size)
                returndatacopy(add(returnData, 32), 0, size)
                // Update free memory pointer
                mstore(0x40, add(returnData, add(32, size)))
            }
        }
    }

    // Like fastCall, but throws when the call is unsuccessful.
    function fastCallAndVerify(
        address to,
        uint256 gasLimit,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory returnData) {
        bool success;
        (success, returnData) = fastCall(to, gasLimit, value, data);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }
}

// File: contracts/thirdparty/BytesUtil.sol

//Mainly taken from https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol

library BytesUtil {
    function concat(bytes memory _preBytes, bytes memory _postBytes)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory tempBytes;

        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(tempBytes, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, length)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                // Write the _preBytes data into the tempBytes memory 32 bytes
                // at a time.
                mstore(mc, mload(cc))
            }

            // Add the length of _postBytes to the current length of tempBytes
            // and store it as the new length in the first 32 bytes of the
            // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            // Move the memory counter back from a multiple of 0x20 to the
            // actual end of the _preBytes data.
            mc := end
            // Stop copying when the memory counter reaches the new combined
            // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            // Update the free-memory pointer by padding our last write location
            // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
            // next 32 byte block, then round down to the nearest multiple of
            // 32. If the sum of the length of the two arrays is zero then add
            // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(
                0x40,
                and(
                    add(add(end, iszero(add(length, mload(_preBytes)))), 31),
                    not(31) // Round down to the nearest 32 bytes.
                )
            )
        }

        return tempBytes;
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_bytes.length >= (_start + _length));

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(
                    add(tempBytes, lengthmod),
                    mul(0x20, iszero(lengthmod))
                )
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(
                        add(
                            add(_bytes, lengthmod),
                            mul(0x20, iszero(lengthmod))
                        ),
                        _start
                    )
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (address)
    {
        require(_bytes.length >= (_start + 20));
        address tempAddress;

        assembly {
            tempAddress := div(
                mload(add(add(_bytes, 0x20), _start)),
                0x1000000000000000000000000
            )
        }

        return tempAddress;
    }

    function toUint8(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint8)
    {
        require(_bytes.length >= (_start + 1));
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    function toUint16(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint16)
    {
        require(_bytes.length >= (_start + 2));
        uint16 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }

        return tempUint;
    }

    function toUint24(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint24)
    {
        require(_bytes.length >= (_start + 3));
        uint24 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x3), _start))
        }

        return tempUint;
    }

    function toUint32(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint32)
    {
        require(_bytes.length >= (_start + 4));
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function toUint64(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint64)
    {
        require(_bytes.length >= (_start + 8));
        uint64 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x8), _start))
        }

        return tempUint;
    }

    function toUint96(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint96)
    {
        require(_bytes.length >= (_start + 12));
        uint96 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0xc), _start))
        }

        return tempUint;
    }

    function toUint128(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint128)
    {
        require(_bytes.length >= (_start + 16));
        uint128 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x10), _start))
        }

        return tempUint;
    }

    function toUint(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint256)
    {
        require(_bytes.length >= (_start + 32));
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function toBytes4(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes4)
    {
        require(_bytes.length >= (_start + 4));
        bytes4 tempBytes4;

        assembly {
            tempBytes4 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes4;
    }

    function toBytes20(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes20)
    {
        require(_bytes.length >= (_start + 20));
        bytes20 tempBytes20;

        assembly {
            tempBytes20 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes20;
    }

    function toBytes32(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes32)
    {
        require(_bytes.length >= (_start + 32));
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }

    function toAddressUnsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (address)
    {
        address tempAddress;

        assembly {
            tempAddress := div(
                mload(add(add(_bytes, 0x20), _start)),
                0x1000000000000000000000000
            )
        }

        return tempAddress;
    }

    function toUint8Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint8)
    {
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    function toUint16Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint16)
    {
        uint16 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }

        return tempUint;
    }

    function toUint24Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint24)
    {
        uint24 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x3), _start))
        }

        return tempUint;
    }

    function toUint32Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint32)
    {
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function toUint64Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint64)
    {
        uint64 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x8), _start))
        }

        return tempUint;
    }

    function toUint96Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint96)
    {
        uint96 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0xc), _start))
        }

        return tempUint;
    }

    function toUint128Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint128)
    {
        uint128 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x10), _start))
        }

        return tempUint;
    }

    function toUintUnsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint256)
    {
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function toBytes4Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes4)
    {
        bytes4 tempBytes4;

        assembly {
            tempBytes4 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes4;
    }

    function toBytes20Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes20)
    {
        bytes20 tempBytes20;

        assembly {
            tempBytes20 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes20;
    }

    function toBytes32Unsafe(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes32)
    {
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }

    function fastSHA256(bytes memory data) internal view returns (bytes32) {
        bytes32[] memory result = new bytes32[](1);
        bool success;
        assembly {
            let ptr := add(data, 32)
            success := staticcall(
                sub(gas(), 2000),
                2,
                ptr,
                mload(data),
                add(result, 32),
                32
            )
        }
        require(success, "SHA256_FAILED");
        return result[0];
    }
}

// File: contracts/lib/MathUint.sol

// Copyright 2017 Loopring Technology Limited.

/// @title Utility Functions for uint
/// @author Daniel Wang - <[email protected]>
library MathUint {
    using MathUint for uint256;

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a * b;
        require(a == 0 || c / a == b, "MUL_OVERFLOW");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SUB_UNDERFLOW");
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a, "ADD_OVERFLOW");
    }

    function add64(uint64 a, uint64 b) internal pure returns (uint64 c) {
        c = a + b;
        require(c >= a, "ADD_OVERFLOW");
    }
}

// File: contracts/lib/ERC1271.sol

// Copyright 2017 Loopring Technology Limited.

abstract contract ERC1271 {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant ERC1271_MAGICVALUE = 0x1626ba7e;

    function isValidSignature(bytes32 _hash, bytes memory _signature)
        public
        view
        virtual
        returns (bytes4 magicValueB32);
}

// File: contracts/lib/SignatureUtil.sol

// Copyright 2017 Loopring Technology Limited.

/// @title SignatureUtil
/// @author Daniel Wang - <[email protected]>
/// @dev This method supports multihash standard. Each signature's last byte indicates
///      the signature's type.
library SignatureUtil {
    using BytesUtil for bytes;
    using MathUint for uint256;
    using AddressUtil for address;

    enum SignatureType {
        ILLEGAL,
        INVALID,
        EIP_712,
        ETH_SIGN,
        WALLET // deprecated
    }

    bytes4 internal constant ERC1271_MAGICVALUE = 0x1626ba7e;

    function verifySignatures(
        bytes32 signHash,
        address[] memory signers,
        bytes[] memory signatures
    ) internal view returns (bool) {
        require(signers.length == signatures.length, "BAD_SIGNATURE_DATA");
        address lastSigner;
        for (uint256 i = 0; i < signers.length; i++) {
            require(signers[i] > lastSigner, "INVALID_SIGNERS_ORDER");
            lastSigner = signers[i];
            if (!verifySignature(signHash, signers[i], signatures[i])) {
                return false;
            }
        }
        return true;
    }

    function verifySignature(
        bytes32 signHash,
        address signer,
        bytes memory signature
    ) internal view returns (bool) {
        if (signer == address(0)) {
            return false;
        }

        return
            signer.isContract()
                ? verifyERC1271Signature(signHash, signer, signature)
                : verifyEOASignature(signHash, signer, signature);
    }

    function recoverECDSASigner(bytes32 signHash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        if (signature.length != 65) {
            return address(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;
        // we jump 32 (0x20) as the first slot of bytes contains the length
        // we jump 65 (0x41) per signature
        // for v we load 32 bytes ending with v (the first 31 come from s) then apply a mask
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := and(mload(add(signature, 0x41)), 0xff)
        }
        // See https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            return address(0);
        }
        if (v == 27 || v == 28) {
            return ecrecover(signHash, v, r, s);
        } else {
            return address(0);
        }
    }

    function verifyEOASignature(
        bytes32 signHash,
        address signer,
        bytes memory signature
    ) private pure returns (bool success) {
        if (signer == address(0)) {
            return false;
        }

        uint256 signatureTypeOffset = signature.length.sub(1);
        SignatureType signatureType = SignatureType(
            signature.toUint8(signatureTypeOffset)
        );

        // Strip off the last byte of the signature by updating the length
        assembly {
            mstore(signature, signatureTypeOffset)
        }

        if (signatureType == SignatureType.EIP_712) {
            success = (signer == recoverECDSASigner(signHash, signature));
        } else if (signatureType == SignatureType.ETH_SIGN) {
            bytes32 hash = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", signHash)
            );
            success = (signer == recoverECDSASigner(hash, signature));
        } else {
            success = false;
        }

        // Restore the signature length
        assembly {
            mstore(signature, add(signatureTypeOffset, 1))
        }

        return success;
    }

    function verifyERC1271Signature(
        bytes32 signHash,
        address signer,
        bytes memory signature
    ) private view returns (bool) {
        bytes memory callData = abi.encodeWithSelector(
            ERC1271.isValidSignature.selector,
            signHash,
            signature
        );
        (bool success, bytes memory result) = signer.staticcall(callData);
        return (success &&
            result.length == 32 &&
            result.toBytes4(0) == ERC1271_MAGICVALUE);
    }
}

// File: contracts/core/iface/IAgentRegistry.sol

// Copyright 2017 Loopring Technology Limited.

interface IAgent {

}

abstract contract IAgentRegistry {
    /// @dev Returns whether an agent address is an agent of an account owner
    /// @param owner The account owner.
    /// @param agent The agent address
    /// @return True if the agent address is an agent for the account owner, else false
    function isAgent(address owner, address agent)
        external
        view
        virtual
        returns (bool);

    /// @dev Returns whether an agent address is an agent of all account owners
    /// @param owners The account owners.
    /// @param agent The agent address
    /// @return True if the agent address is an agent for the account owner, else false
    function isAgent(address[] calldata owners, address agent)
        external
        view
        virtual
        returns (bool);

    /// @dev Returns whether an agent address is a universal agent.
    /// @param agent The agent address
    /// @return True if the agent address is a universal agent, else false
    function isUniversalAgent(address agent) public view virtual returns (bool);
}

// File: contracts/lib/Ownable.sol

// Copyright 2017 Loopring Technology Limited.

/// @title Ownable
/// @author Brecht Devos - <[email protected]>
/// @dev The Ownable contract has an owner address, and provides basic
///      authorization control functions, this simplifies the implementation of
///      "user permissions".
contract Ownable {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /// @dev The Ownable constructor sets the original `owner` of the contract
    ///      to the sender.
    constructor() {
        owner = msg.sender;
    }

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "UNAUTHORIZED");
        _;
    }

    /// @dev Allows the current owner to transfer control of the contract to a
    ///      new owner.
    /// @param newOwner The address to transfer ownership to.
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "ZERO_ADDRESS");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

// File: contracts/lib/Claimable.sol

// Copyright 2017 Loopring Technology Limited.

/// @title Claimable
/// @author Brecht Devos - <[email protected]>
/// @dev Extension for the Ownable contract, where the ownership needs
///      to be claimed. This allows the new owner to accept the transfer.
contract Claimable is Ownable {
    address public pendingOwner;

    /// @dev Modifier throws if called by any account other than the pendingOwner.
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner, "UNAUTHORIZED");
        _;
    }

    /// @dev Allows the current owner to set the pendingOwner address.
    /// @param newOwner The address to transfer ownership to.
    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0) && newOwner != owner, "INVALID_ADDRESS");
        pendingOwner = newOwner;
    }

    /// @dev Allows the pendingOwner address to finalize the transfer.
    function claimOwnership() public onlyPendingOwner {
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }
}

// File: contracts/core/iface/IBlockVerifier.sol

// Copyright 2017 Loopring Technology Limited.

/// @title IBlockVerifier
/// @author Brecht Devos - <[email protected]>
abstract contract IBlockVerifier is Claimable {
    // -- Events --

    event CircuitRegistered(
        uint8 indexed blockType,
        uint16 blockSize,
        uint8 blockVersion
    );

    event CircuitDisabled(
        uint8 indexed blockType,
        uint16 blockSize,
        uint8 blockVersion
    );

    // -- Public functions --

    /// @dev Sets the verifying key for the specified circuit.
    ///      Every block permutation needs its own circuit and thus its own set of
    ///      verification keys. Only a limited number of block sizes per block
    ///      type are supported.
    /// @param blockType The type of the block
    /// @param blockSize The number of requests handled in the block
    /// @param blockVersion The block version (i.e. which circuit version needs to be used)
    /// @param vk The verification key
    function registerCircuit(
        uint8 blockType,
        uint16 blockSize,
        uint8 blockVersion,
        uint256[18] calldata vk
    ) external virtual;

    /// @dev Disables the use of the specified circuit.
    /// @param blockType The type of the block
    /// @param blockSize The number of requests handled in the block
    /// @param blockVersion The block version (i.e. which circuit version needs to be used)
    function disableCircuit(
        uint8 blockType,
        uint16 blockSize,
        uint8 blockVersion
    ) external virtual;

    /// @dev Verifies blocks with the given public data and proofs.
    ///      Verifying a block makes sure all requests handled in the block
    ///      are correctly handled by the operator.
    /// @param blockType The type of block
    /// @param blockSize The number of requests handled in the block
    /// @param blockVersion The block version (i.e. which circuit version needs to be used)
    /// @param publicInputs The hash of all the public data of the blocks
    /// @param proofs The ZK proofs proving that the blocks are correct
    /// @return True if the block is valid, false otherwise
    function verifyProofs(
        uint8 blockType,
        uint16 blockSize,
        uint8 blockVersion,
        uint256[] calldata publicInputs,
        uint256[] calldata proofs
    ) external view virtual returns (bool);

    /// @dev Checks if a circuit with the specified parameters is registered.
    /// @param blockType The type of the block
    /// @param blockSize The number of requests handled in the block
    /// @param blockVersion The block version (i.e. which circuit version needs to be used)
    /// @return True if the circuit is registered, false otherwise
    function isCircuitRegistered(
        uint8 blockType,
        uint16 blockSize,
        uint8 blockVersion
    ) external view virtual returns (bool);

    /// @dev Checks if a circuit can still be used to commit new blocks.
    /// @param blockType The type of the block
    /// @param blockSize The number of requests handled in the block
    /// @param blockVersion The block version (i.e. which circuit version needs to be used)
    /// @return True if the circuit is enabled, false otherwise
    function isCircuitEnabled(
        uint8 blockType,
        uint16 blockSize,
        uint8 blockVersion
    ) external view virtual returns (bool);
}

// File: contracts/core/iface/IDepositContract.sol

// Copyright 2017 Loopring Technology Limited.

/// @title IDepositContract.
/// @dev   Contract storing and transferring funds for an exchange.
///
///        ERC1155 tokens can be supported by registering pseudo token addresses calculated
///        as `address(keccak256(real_token_address, token_params))`. Then the custom
///        deposit contract can look up the real token address and paramsters with the
///        pseudo token address before doing the transfers.
/// @author Brecht Devos - <[email protected]>
interface IDepositContract {
    /// @dev Returns if a token is suppoprted by this contract.
    function isTokenSupported(address token) external view returns (bool);

    /// @dev Transfers tokens from a user to the exchange. This function will
    ///      be called when a user deposits funds to the exchange.
    ///      In a simple implementation the funds are simply stored inside the
    ///      deposit contract directly. More advanced implementations may store the funds
    ///      in some DeFi application to earn interest, so this function could directly
    ///      call the necessary functions to store the funds there.
    ///
    ///      This function needs to throw when an error occurred!
    ///
    ///      This function can only be called by the exchange.
    ///
    /// @param from The address of the account that sends the tokens.
    /// @param token The address of the token to transfer (`0x0` for ETH).
    /// @param amount The amount of tokens to transfer.
    /// @param extraData Opaque data that can be used by the contract to handle the deposit
    /// @return amountReceived The amount to deposit to the user's account in the Merkle tree
    function deposit(
        address from,
        address token,
        uint96 amount,
        bytes calldata extraData
    ) external payable returns (uint96 amountReceived);

    /// @dev Transfers tokens from the exchange to a user. This function will
    ///      be called when a withdrawal is done for a user on the exchange.
    ///      In the simplest implementation the funds are simply stored inside the
    ///      deposit contract directly so this simply transfers the requested tokens back
    ///      to the user. More advanced implementations may store the funds
    ///      in some DeFi application to earn interest so the function would
    ///      need to get those tokens back from the DeFi application first before they
    ///      can be transferred to the user.
    ///
    ///      This function needs to throw when an error occurred!
    ///
    ///      This function can only be called by the exchange.
    ///
    /// @param from The address from which 'amount' tokens are transferred.
    /// @param to The address to which 'amount' tokens are transferred.
    /// @param token The address of the token to transfer (`0x0` for ETH).
    /// @param amount The amount of tokens transferred.
    /// @param extraData Opaque data that can be used by the contract to handle the withdrawal
    function withdraw(
        address from,
        address to,
        address token,
        uint256 amount,
        bytes calldata extraData
    ) external payable;

    /// @dev Transfers tokens (ETH not supported) for a user using the allowance set
    ///      for the exchange. This way the approval can be used for all functionality (and
    ///      extended functionality) of the exchange.
    ///      Should NOT be used to deposit/withdraw user funds, `deposit`/`withdraw`
    ///      should be used for that as they will contain specialised logic for those operations.
    ///      This function can be called by the exchange to transfer onchain funds of users
    ///      necessary for Agent functionality.
    ///
    ///      This function needs to throw when an error occurred!
    ///
    ///      This function can only be called by the exchange.
    ///
    /// @param from The address of the account that sends the tokens.
    /// @param to The address to which 'amount' tokens are transferred.
    /// @param token The address of the token to transfer (ETH is and cannot be suppported).
    /// @param amount The amount of tokens transferred.
    function transfer(
        address from,
        address to,
        address token,
        uint256 amount
    ) external payable;

    /// @dev Checks if the given address is used for depositing ETH or not.
    ///      Is used while depositing to send the correct ETH amount to the deposit contract.
    ///
    ///      Note that 0x0 is always registered for deposting ETH when the exchange is created!
    ///      This function allows additional addresses to be used for depositing ETH, the deposit
    ///      contract can implement different behaviour based on the address value.
    ///
    /// @param addr The address to check
    /// @return True if the address is used for depositing ETH, else false.
    function isETH(address addr) external view returns (bool);
}

// File: contracts/core/iface/ILoopringV3.sol

// Copyright 2017 Loopring Technology Limited.

/// @title ILoopringV3
/// @author Brecht Devos - <[email protected]>
/// @author Daniel Wang  - <[email protected]>
abstract contract ILoopringV3 is Claimable {
    // == Events ==
    event ExchangeStakeDeposited(address exchangeAddr, uint256 amount);
    event ExchangeStakeWithdrawn(address exchangeAddr, uint256 amount);
    event ExchangeStakeBurned(address exchangeAddr, uint256 amount);
    event SettingsUpdated(uint256 time);

    // == Public Variables ==
    mapping(address => uint256) internal exchangeStake;

    uint256 public totalStake;
    address public blockVerifierAddress;
    uint256 public forcedWithdrawalFee;
    uint256 public tokenRegistrationFeeLRCBase;
    uint256 public tokenRegistrationFeeLRCDelta;
    uint8 public protocolTakerFeeBips;
    uint8 public protocolMakerFeeBips;

    address payable public protocolFeeVault;

    // == Public Functions ==

    /// @dev Returns the LRC token address
    /// @return the LRC token address
    function lrcAddress() external view virtual returns (address);

    /// @dev Updates the global exchange settings.
    ///      This function can only be called by the owner of this contract.
    ///
    ///      Warning: these new values will be used by existing and
    ///      new Loopring exchanges.
    function updateSettings(
        address payable _protocolFeeVault, // address(0) not allowed
        address _blockVerifierAddress, // address(0) not allowed
        uint256 _forcedWithdrawalFee
    ) external virtual;

    /// @dev Updates the global protocol fee settings.
    ///      This function can only be called by the owner of this contract.
    ///
    ///      Warning: these new values will be used by existing and
    ///      new Loopring exchanges.
    function updateProtocolFeeSettings(
        uint8 _protocolTakerFeeBips,
        uint8 _protocolMakerFeeBips
    ) external virtual;

    /// @dev Gets the amount of staked LRC for an exchange.
    /// @param exchangeAddr The address of the exchange
    /// @return stakedLRC The amount of LRC
    function getExchangeStake(address exchangeAddr)
        public
        view
        virtual
        returns (uint256 stakedLRC);

    /// @dev Burns a certain amount of staked LRC for a specific exchange.
    ///      This function is meant to be called only from exchange contracts.
    /// @return burnedLRC The amount of LRC burned. If the amount is greater than
    ///         the staked amount, all staked LRC will be burned.
    function burnExchangeStake(uint256 amount)
        external
        virtual
        returns (uint256 burnedLRC);

    /// @dev Stakes more LRC for an exchange.
    /// @param  exchangeAddr The address of the exchange
    /// @param  amountLRC The amount of LRC to stake
    /// @return stakedLRC The total amount of LRC staked for the exchange
    function depositExchangeStake(address exchangeAddr, uint256 amountLRC)
        external
        virtual
        returns (uint256 stakedLRC);

    /// @dev Withdraws a certain amount of staked LRC for an exchange to the given address.
    ///      This function is meant to be called only from within exchange contracts.
    /// @param  recipient The address to receive LRC
    /// @param  requestedAmount The amount of LRC to withdraw
    /// @return amountLRC The amount of LRC withdrawn
    function withdrawExchangeStake(address recipient, uint256 requestedAmount)
        external
        virtual
        returns (uint256 amountLRC);

    /// @dev Gets the protocol fee values for an exchange.
    /// @return takerFeeBips The protocol taker fee
    /// @return makerFeeBips The protocol maker fee
    function getProtocolFeeValues()
        public
        view
        virtual
        returns (uint8 takerFeeBips, uint8 makerFeeBips);
}

// File: contracts/core/iface/ExchangeData.sol

// Copyright 2017 Loopring Technology Limited.

/// @title ExchangeData
/// @dev All methods in this lib are internal, therefore, there is no need
///      to deploy this library independently.
/// @author Daniel Wang  - <[email protected]>
/// @author Brecht Devos - <[email protected]>
library ExchangeData {
    // -- Enums --
    enum TransactionType {
        NOOP,
        DEPOSIT,
        WITHDRAWAL,
        TRANSFER,
        SPOT_TRADE,
        ACCOUNT_UPDATE,
        AMM_UPDATE,
        SIGNATURE_VERIFICATION,
        NFT_MINT, // L2 NFT mint or L1-to-L2 NFT deposit
        NFT_DATA
    }

    enum NftType {
        ERC1155,
        ERC721
    }

    // -- Structs --
    struct Token {
        address token;
    }

    struct ProtocolFeeData {
        uint32 syncedAt; // only valid before 2105 (85 years to go)
        uint8 takerFeeBips;
        uint8 makerFeeBips;
        uint8 previousTakerFeeBips;
        uint8 previousMakerFeeBips;
    }

    // General auxiliary data for each conditional transaction
    struct AuxiliaryData {
        uint256 txIndex;
        bool approved;
        bytes data;
    }

    // This is the (virtual) block the owner  needs to submit onchain to maintain the
    // per-exchange (virtual) blockchain.
    struct Block {
        uint8 blockType;
        uint16 blockSize;
        uint8 blockVersion;
        bytes data;
        uint256[8] proof;
        // Whether we should store the @BlockInfo for this block on-chain.
        bool storeBlockInfoOnchain;
        // Block specific data that is only used to help process the block on-chain.
        // It is not used as input for the circuits and it is not necessary for data-availability.
        // This bytes array contains the abi encoded AuxiliaryData[] data.
        bytes auxiliaryData;
        // Arbitrary data, mainly for off-chain data-availability, i.e.,
        // the multihash of the IPFS file that contains the block data.
        bytes offchainData;
    }

    struct BlockInfo {
        // The time the block was submitted on-chain.
        uint32 timestamp;
        // The public data hash of the block (the 28 most significant bytes).
        bytes28 blockDataHash;
    }

    // Represents an onchain deposit request.
    struct Deposit {
        uint96 amount;
        uint64 timestamp;
    }

    // A forced withdrawal request.
    // If the actual owner of the account initiated the request (we don't know who the owner is
    // at the time the request is being made) the full balance will be withdrawn.
    struct ForcedWithdrawal {
        address owner;
        uint64 timestamp;
    }

    struct Constants {
        uint256 SNARK_SCALAR_FIELD;
        uint256 MAX_OPEN_FORCED_REQUESTS;
        uint256 MAX_AGE_FORCED_REQUEST_UNTIL_WITHDRAW_MODE;
        uint256 TIMESTAMP_HALF_WINDOW_SIZE_IN_SECONDS;
        uint256 MAX_NUM_ACCOUNTS;
        uint256 MAX_NUM_TOKENS;
        uint256 MIN_AGE_PROTOCOL_FEES_UNTIL_UPDATED;
        uint256 MIN_TIME_IN_SHUTDOWN;
        uint256 TX_DATA_AVAILABILITY_SIZE;
        uint256 MAX_AGE_DEPOSIT_UNTIL_WITHDRAWABLE_UPPERBOUND;
    }

    // This is the prime number that is used for the alt_bn128 elliptic curve, see EIP-196.
    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 public constant MAX_OPEN_FORCED_REQUESTS = 4096;
    uint256 public constant MAX_AGE_FORCED_REQUEST_UNTIL_WITHDRAW_MODE =
        15 days;
    uint256 public constant TIMESTAMP_HALF_WINDOW_SIZE_IN_SECONDS = 7 days;
    uint256 public constant MAX_NUM_ACCOUNTS = 2**32;
    uint256 public constant MAX_NUM_TOKENS = 2**16;
    uint256 public constant MIN_AGE_PROTOCOL_FEES_UNTIL_UPDATED = 7 days;
    uint256 public constant MIN_TIME_IN_SHUTDOWN = 30 days;
    // The amount of bytes each rollup transaction uses in the block data for data-availability.
    // This is the maximum amount of bytes of all different transaction types.
    uint32 public constant MAX_AGE_DEPOSIT_UNTIL_WITHDRAWABLE_UPPERBOUND =
        15 days;
    uint32 public constant ACCOUNTID_PROTOCOLFEE = 0;

    uint256 public constant TX_DATA_AVAILABILITY_SIZE = 68;
    uint256 public constant TX_DATA_AVAILABILITY_SIZE_PART_1 = 29;
    uint256 public constant TX_DATA_AVAILABILITY_SIZE_PART_2 = 39;

    uint256 public constant NFT_TOKEN_ID_START = 2**15;

    struct AccountLeaf {
        uint32 accountID;
        address owner;
        uint256 pubKeyX;
        uint256 pubKeyY;
        uint32 nonce;
        uint256 feeBipsAMM;
    }

    struct BalanceLeaf {
        uint16 tokenID;
        uint96 balance;
        uint256 weightAMM;
        uint256 storageRoot;
    }

    struct Nft {
        address minter; // Minter address for a L2 mint or
        // the NFT's contract address in the case of a L1-to-L2 NFT deposit.
        NftType nftType;
        address token;
        uint256 nftID;
        uint8 creatorFeeBips;
    }

    struct MerkleProof {
        ExchangeData.AccountLeaf accountLeaf;
        ExchangeData.BalanceLeaf balanceLeaf;
        ExchangeData.Nft nft;
        uint256[48] accountMerkleProof;
        uint256[24] balanceMerkleProof;
    }

    struct BlockContext {
        bytes32 DOMAIN_SEPARATOR;
        uint32 timestamp;
        Block block;
        uint256 txIndex;
    }

    // Represents the entire exchange state except the owner of the exchange.
    struct State {
        uint32 maxAgeDepositUntilWithdrawable;
        bytes32 DOMAIN_SEPARATOR;
        ILoopringV3 loopring;
        IBlockVerifier blockVerifier;
        IAgentRegistry agentRegistry;
        IDepositContract depositContract;
        // The merkle root of the offchain data stored in a Merkle tree. The Merkle tree
        // stores balances for users using an account model.
        bytes32 merkleRoot;
        // List of all blocks
        mapping(uint256 => BlockInfo) blocks;
        uint256 numBlocks;
        // List of all tokens
        Token[] tokens;
        // A map from a token to its tokenID + 1
        mapping(address => uint16) tokenToTokenId;
        // A map from an accountID to a tokenID to if the balance is withdrawn
        mapping(uint32 => mapping(uint16 => bool)) withdrawnInWithdrawMode;
        // A map from an account to a token to the amount withdrawable for that account.
        // This is only used when the automatic distribution of the withdrawal failed.
        mapping(address => mapping(uint16 => uint256)) amountWithdrawable;
        // A map from an account to a token to the forced withdrawal (always full balance)
        // The `uint16' represents ERC20 token ID (if < NFT_TOKEN_ID_START) or
        // NFT balance slot (if >= NFT_TOKEN_ID_START)
        mapping(uint32 => mapping(uint16 => ForcedWithdrawal)) pendingForcedWithdrawals;
        // A map from an address to a token to a deposit
        mapping(address => mapping(uint16 => Deposit)) pendingDeposits;
        // A map from an account owner to an approved transaction hash to if the transaction is approved or not
        mapping(address => mapping(bytes32 => bool)) approvedTx;
        // A map from an account owner to a destination address to a tokenID to an amount to a storageID to a new recipient address
        mapping(address => mapping(address => mapping(uint16 => mapping(uint256 => mapping(uint32 => address))))) withdrawalRecipient;
        // Counter to keep track of how many of forced requests are open so we can limit the work that needs to be done by the owner
        uint32 numPendingForcedTransactions;
        // Cached data for the protocol fee
        ProtocolFeeData protocolFeeData;
        // Time when the exchange was shutdown
        uint256 shutdownModeStartTime;
        // Time when the exchange has entered withdrawal mode
        uint256 withdrawalModeStartTime;
        // Last time the protocol fee was withdrawn for a specific token
        mapping(address => uint256) protocolFeeLastWithdrawnTime;
        // Duplicated loopring address
        address loopringAddr;
        // AMM fee bips
        uint8 ammFeeBips;
        // Enable/Disable `onchainTransferFrom`
        bool allowOnchainTransferFrom;
        // owner => NFT type => token address => nftID => Deposit
        mapping(address => mapping(NftType => mapping(address => mapping(uint256 => Deposit)))) pendingNFTDeposits;
        // owner => minter => NFT type => token address => nftID => amount withdrawable
        // This is only used when the automatic distribution of the withdrawal failed.
        mapping(address => mapping(address => mapping(NftType => mapping(address => mapping(uint256 => uint256))))) amountWithdrawableNFT;
    }
}

// File: contracts/core/iface/IExchangeV3.sol

// Copyright 2017 Loopring Technology Limited.

/// @title IExchangeV3
/// @dev Note that Claimable and RentrancyGuard are inherited here to
///      ensure all data members are declared on IExchangeV3 to make it
///      easy to support upgradability through proxies.
///
///      Subclasses of this contract must NOT define constructor to
///      initialize data.
///
/// @author Brecht Devos - <[email protected]>
/// @author Daniel Wang  - <[email protected]>
abstract contract IExchangeV3 is Claimable {
    // -- Events --

    event ExchangeCloned(
        address exchangeAddress,
        address owner,
        bytes32 genesisMerkleRoot
    );

    event TokenRegistered(address token, uint16 tokenId);

    event Shutdown(uint256 timestamp);

    event WithdrawalModeActivated(uint256 timestamp);

    event BlockSubmitted(
        uint256 indexed blockIdx,
        bytes32 merkleRoot,
        bytes32 publicDataHash
    );

    event DepositRequested(
        address from,
        address to,
        address token,
        uint16 tokenId,
        uint96 amount
    );

    event NFTDepositRequested(
        address from,
        address to,
        uint8 nftType,
        address token,
        uint256 nftID,
        uint96 amount
    );

    event ForcedWithdrawalRequested(
        address owner,
        uint16 tokenID,
        uint32 accountID
    );

    event WithdrawalCompleted(
        uint8 category,
        address from,
        address to,
        address token,
        uint256 amount
    );

    event WithdrawalFailed(
        uint8 category,
        address from,
        address to,
        address token,
        uint256 amount
    );

    event NftWithdrawalCompleted(
        uint8 category,
        address from,
        address to,
        uint16 tokenID,
        address token,
        uint256 nftID,
        uint256 amount
    );

    event NftWithdrawalFailed(
        uint8 category,
        address from,
        address to,
        uint16 tokenID,
        address token,
        uint256 nftID,
        uint256 amount
    );

    event ProtocolFeesUpdated(
        uint8 takerFeeBips,
        uint8 makerFeeBips,
        uint8 previousTakerFeeBips,
        uint8 previousMakerFeeBips
    );

    event TransactionApproved(address owner, bytes32 transactionHash);

    // -- Initialization --
    /// @dev Initializes this exchange. This method can only be called once.
    /// @param  loopring The LoopringV3 contract address.
    /// @param  owner The owner of this exchange.
    /// @param  genesisMerkleRoot The initial Merkle tree state.
    function initialize(
        address loopring,
        address owner,
        bytes32 genesisMerkleRoot
    ) external virtual;

    /// @dev Initialized the agent registry contract used by the exchange.
    ///      Can only be called by the exchange owner once.
    /// @param agentRegistry The agent registry contract to be used
    function setAgentRegistry(address agentRegistry) external virtual;

    /// @dev Gets the agent registry contract used by the exchange.
    /// @return the agent registry contract
    function getAgentRegistry() external view virtual returns (IAgentRegistry);

    ///      Can only be called by the exchange owner once.
    /// @param depositContract The deposit contract to be used
    function setDepositContract(address depositContract) external virtual;

    /// @dev refresh the blockVerifier contract which maybe changed in loopringV3 contract.
    function refreshBlockVerifier() external virtual;

    /// @dev Gets the deposit contract used by the exchange.
    /// @return the deposit contract
    function getDepositContract()
        external
        view
        virtual
        returns (IDepositContract);

    // @dev Exchange owner withdraws fees from the exchange.
    // @param token Fee token address
    // @param feeRecipient Fee recipient address
    function withdrawExchangeFees(address token, address feeRecipient)
        external
        virtual;

    // -- Constants --
    /// @dev Returns a list of constants used by the exchange.
    /// @return constants The list of constants.
    function getConstants()
        external
        pure
        virtual
        returns (ExchangeData.Constants memory);

    // -- Mode --
    /// @dev Returns hether the exchange is in withdrawal mode.
    /// @return Returns true if the exchange is in withdrawal mode, else false.
    function isInWithdrawalMode() external view virtual returns (bool);

    /// @dev Returns whether the exchange is shutdown.
    /// @return Returns true if the exchange is shutdown, else false.
    function isShutdown() external view virtual returns (bool);

    // -- Tokens --
    /// @dev Registers an ERC20 token for a token id. Note that different exchanges may have
    ///      different ids for the same ERC20 token.
    ///
    ///      Please note that 1 is reserved for Ether (ETH), 2 is reserved for Wrapped Ether (ETH),
    ///      and 3 is reserved for Loopring Token (LRC).
    ///
    ///      This function is only callable by the exchange owner.
    ///
    /// @param  tokenAddress The token's address
    /// @return tokenID The token's ID in this exchanges.
    function registerToken(address tokenAddress)
        external
        virtual
        returns (uint16 tokenID);

    /// @dev Returns the id of a registered token.
    /// @param  tokenAddress The token's address
    /// @return tokenID The token's ID in this exchanges.
    function getTokenID(address tokenAddress)
        external
        view
        virtual
        returns (uint16 tokenID);

    /// @dev Returns the address of a registered token.
    /// @param  tokenID The token's ID in this exchanges.
    /// @return tokenAddress The token's address
    function getTokenAddress(uint16 tokenID)
        external
        view
        virtual
        returns (address tokenAddress);

    // -- Stakes --
    /// @dev Gets the amount of LRC the owner has staked onchain for this exchange.
    ///      The stake will be burned if the exchange does not fulfill its duty by
    ///      processing user requests in time. Please note that order matching may potentially
    ///      performed by another party and is not part of the exchange's duty.
    ///
    /// @return The amount of LRC staked
    function getExchangeStake() external view virtual returns (uint256);

    /// @dev Withdraws the amount staked for this exchange.
    ///      This can only be done if the exchange has been correctly shutdown:
    ///      - The exchange owner has shutdown the exchange
    ///      - All deposit requests are processed
    ///      - All funds are returned to the users (merkle root is reset to initial state)
    ///
    ///      Can only be called by the exchange owner.
    ///
    /// @return amountLRC The amount of LRC withdrawn
    function withdrawExchangeStake(address recipient)
        external
        virtual
        returns (uint256 amountLRC);

    /// @dev Can by called by anyone to burn the stake of the exchange when certain
    ///      conditions are fulfilled.
    ///
    ///      Currently this will only burn the stake of the exchange if
    ///      the exchange is in withdrawal mode.
    function burnExchangeStake() external virtual;

    // -- Blocks --

    /// @dev Gets the current Merkle root of this exchange's virtual blockchain.
    /// @return The current Merkle root.
    function getMerkleRoot() external view virtual returns (bytes32);

    /// @dev Gets the height of this exchange's virtual blockchain. The block height for a
    ///      new exchange is 1.
    /// @return The virtual blockchain height which is the index of the last block.
    function getBlockHeight() external view virtual returns (uint256);

    /// @dev Gets some minimal info of a previously submitted block that's kept onchain.
    ///      A DEX can use this function to implement a payment receipt verification
    ///      contract with a challange-response scheme.
    /// @param blockIdx The block index.
    function getBlockInfo(uint256 blockIdx)
        external
        view
        virtual
        returns (ExchangeData.BlockInfo memory);

    /// @dev Sumbits new blocks to the rollup blockchain.
    ///
    ///      This function can only be called by the exchange operator.
    ///
    /// @param blocks The blocks being submitted
    ///      - blockType: The type of the new block
    ///      - blockSize: The number of onchain or offchain requests/settlements
    ///        that have been processed in this block
    ///      - blockVersion: The circuit version to use for verifying the block
    ///      - storeBlockInfoOnchain: If the block info for this block needs to be stored on-chain
    ///      - data: The data for this block
    ///      - offchainData: Arbitrary data, mainly for off-chain data-availability, i.e.,
    ///        the multihash of the IPFS file that contains the block data.
    function submitBlocks(ExchangeData.Block[] calldata blocks)
        external
        virtual;

    /// @dev Gets the number of available forced request slots.
    /// @return The number of available slots.
    function getNumAvailableForcedSlots()
        external
        view
        virtual
        returns (uint256);

    // -- Deposits --

    /// @dev Deposits Ether or ERC20 tokens to the specified account.
    ///
    ///      This function is only callable by an agent of 'from'.
    ///
    ///      The operator is not forced to do the deposit.
    ///
    /// @param from The address that deposits the funds to the exchange
    /// @param to The account owner's address receiving the funds
    /// @param tokenAddress The address of the token, use `0x0` for Ether.
    /// @param amount The amount of tokens to deposit
    /// @param extraData Optional extra data used by the deposit contract
    function deposit(
        address from,
        address to,
        address tokenAddress,
        uint96 amount,
        bytes calldata extraData
    ) external payable virtual;

    /// @dev Deposits an NFT to the specified account.
    ///
    ///      This function is only callable by an agent of 'from'.
    ///
    ///      The operator is not forced to do the deposit.
    ///
    /// @param from The address that deposits the funds to the exchange
    /// @param to The account owner's address receiving the funds
    /// @param nftType The type of NFT contract address (ERC721/ERC1155/...)
    /// @param tokenAddress The address of the token, use `0x0` for Ether.
    /// @param nftID The token type 'id`.
    /// @param amount The amount of tokens to deposit.
    /// @param extraData Optional extra data used by the deposit contract.
    function depositNFT(
        address from,
        address to,
        ExchangeData.NftType nftType,
        address tokenAddress,
        uint256 nftID,
        uint96 amount,
        bytes calldata extraData
    ) external virtual;

    /// @dev Gets the amount of tokens that may be added to the owner's account.
    /// @param owner The destination address for the amount deposited.
    /// @param tokenAddress The address of the token, use `0x0` for Ether.
    /// @return The amount of tokens pending.
    function getPendingDepositAmount(address owner, address tokenAddress)
        public
        view
        virtual
        returns (uint96);

    /// @dev Gets the amount of tokens that may be added to the owner's account.
    /// @param owner The destination address for the amount deposited.
    /// @param tokenAddress The address of the token, use `0x0` for Ether.
    /// @param nftType The type of NFT contract address (ERC721/ERC1155/...)
    /// @param nftID The token type 'id`.
    /// @return The amount of tokens pending.
    function getPendingNFTDepositAmount(
        address owner,
        address tokenAddress,
        ExchangeData.NftType nftType,
        uint256 nftID
    ) public view virtual returns (uint96);

    // -- Withdrawals --

    /// @dev Submits an onchain request to force withdraw Ether, ERC20 and NFT tokens.
    ///      This request always withdraws the full balance.
    ///
    ///      This function is only callable by an agent of the account.
    ///
    ///      The total fee in ETH that the user needs to pay is 'withdrawalFee'.
    ///      If the user sends too much ETH the surplus is sent back immediately.
    ///
    ///      Note that after such an operation, it will take the owner some
    ///      time (no more than MAX_AGE_FORCED_REQUEST_UNTIL_WITHDRAW_MODE) to process the request
    ///      and create the deposit to the offchain account.
    ///
    /// @param owner The expected owner of the account
    /// @param tokenID The tokenID to withdraw from
    /// @param accountID The address the account in the Merkle tree.
    function forceWithdrawByTokenID(
        address owner,
        uint16 tokenID,
        uint32 accountID
    ) external payable virtual;

    /// @dev Submits an onchain request to force withdraw Ether or ERC20 tokens.
    ///      This request always withdraws the full balance.
    ///
    ///      This function is only callable by an agent of the account.
    ///
    ///      The total fee in ETH that the user needs to pay is 'withdrawalFee'.
    ///      If the user sends too much ETH the surplus is sent back immediately.
    ///
    ///      Note that after such an operation, it will take the owner some
    ///      time (no more than MAX_AGE_FORCED_REQUEST_UNTIL_WITHDRAW_MODE) to process the request
    ///      and create the deposit to the offchain account.
    ///
    /// @param owner The expected owner of the account
    /// @param tokenAddress The address of the token, use `0x0` for Ether.
    /// @param accountID The address the account in the Merkle tree.
    function forceWithdraw(
        address owner,
        address tokenAddress,
        uint32 accountID
    ) external payable virtual;

    /// @dev Checks if a forced withdrawal is pending for an account balance.
    /// @param  accountID The accountID of the account to check.
    /// @param  token The token address
    /// @return True if a request is pending, false otherwise
    function isForcedWithdrawalPending(uint32 accountID, address token)
        external
        view
        virtual
        returns (bool);

    /// @dev Submits an onchain request to withdraw Ether or ERC20 tokens from the
    ///      protocol fees account. The complete balance is always withdrawn.
    ///
    ///      Anyone can request a withdrawal of the protocol fees.
    ///
    ///      Note that after such an operation, it will take the owner some
    ///      time (no more than MAX_AGE_FORCED_REQUEST_UNTIL_WITHDRAW_MODE) to process the request
    ///      and create the deposit to the offchain account.
    ///
    /// @param tokenAddress The address of the token, use `0x0` for Ether.
    function withdrawProtocolFees(address tokenAddress)
        external
        payable
        virtual;

    /// @dev Gets the time the protocol fee for a token was last withdrawn.
    /// @param tokenAddress The address of the token, use `0x0` for Ether.
    /// @return The time the protocol fee was last withdrawn.
    function getProtocolFeeLastWithdrawnTime(address tokenAddress)
        external
        view
        virtual
        returns (uint256);

    /// @dev Allows anyone to withdraw funds for a specified user using the balances stored
    ///      in the Merkle tree. The funds will be sent to the owner of the acount.
    ///
    ///      Can only be used in withdrawal mode (i.e. when the owner has stopped
    ///      committing blocks and is not able to commit any more blocks).
    ///
    ///      This will NOT modify the onchain merkle root! The merkle root stored
    ///      onchain will remain the same after the withdrawal. We store if the user
    ///      has withdrawn the balance in State.withdrawnInWithdrawMode.
    ///
    /// @param  merkleProof The Merkle inclusion proof
    function withdrawFromMerkleTree(
        ExchangeData.MerkleProof calldata merkleProof
    ) external virtual;

    /// @dev Checks if the balance for the account was withdrawn with `withdrawFromMerkleTree`.
    /// @param  accountID The accountID of the balance to check.
    /// @param  token The token address
    /// @return True if it was already withdrawn, false otherwise
    function isWithdrawnInWithdrawalMode(uint32 accountID, address token)
        external
        view
        virtual
        returns (bool);

    /// @dev Allows withdrawing funds deposited to the contract in a deposit request when
    ///      it was never processed by the owner within the maximum time allowed.
    ///
    ///      Can be called by anyone. The deposited tokens will be sent back to
    ///      the owner of the account they were deposited in.
    ///
    /// @param  owner The address of the account the withdrawal was done for.
    /// @param  token The token address
    function withdrawFromDepositRequest(address owner, address token)
        external
        virtual;

    /// @dev Allows withdrawing funds deposited to the contract in a deposit request when
    ///      it was never processed by the owner within the maximum time allowed.
    ///
    ///      Can be called by anyone. The deposited tokens will be sent back to
    ///      the owner of the account they were deposited in.
    ///
    /// @param owner The address of the account the withdrawal was done for.
    /// @param token The token address
    /// @param nftType The type of NFT contract address (ERC721/ERC1155/...)
    /// @param nftID The token type 'id`.
    function withdrawFromNFTDepositRequest(
        address owner,
        address token,
        ExchangeData.NftType nftType,
        uint256 nftID
    ) external virtual;

    /// @dev Allows withdrawing funds after a withdrawal request (either onchain
    ///      or offchain) was submitted in a block by the operator.
    ///
    ///      Can be called by anyone. The withdrawn tokens will be sent to
    ///      the owner of the account they were withdrawn out.
    ///
    ///      Normally it is should not be needed for users to call this manually.
    ///      Funds from withdrawal requests will be sent to the account owner
    ///      immediately by the owner when the block is submitted.
    ///      The user will however need to call this manually if the transfer failed.
    ///
    ///      Tokens and owners must have the same size.
    ///
    /// @param  owners The addresses of the account the withdrawal was done for.
    /// @param  tokens The token addresses
    function withdrawFromApprovedWithdrawals(
        address[] calldata owners,
        address[] calldata tokens
    ) external virtual;

    /// @dev Allows withdrawing funds after an NFT withdrawal request (either onchain
    ///      or offchain) was submitted in a block by the operator.
    ///
    ///      Can be called by anyone. The withdrawn tokens will be sent to
    ///      the owner of the account they were withdrawn out.
    ///
    ///      Normally it is should not be needed for users to call this manually.
    ///      Funds from withdrawal requests will be sent to the account owner
    ///      immediately by the owner when the block is submitted.
    ///      The user will however need to call this manually if the transfer failed.
    ///
    ///      All input arrays must have the same size.
    ///
    /// @param  owners The addresses of the accounts the withdrawal was done for.
    /// @param  minters The addresses of the minters.
    /// @param  nftTypes The NFT token addresses types
    /// @param  tokens The token addresses
    /// @param  nftIDs The token ids
    function withdrawFromApprovedWithdrawalsNFT(
        address[] memory owners,
        address[] memory minters,
        ExchangeData.NftType[] memory nftTypes,
        address[] memory tokens,
        uint256[] memory nftIDs
    ) external virtual;

    /// @dev Gets the amount that can be withdrawn immediately with `withdrawFromApprovedWithdrawals`.
    /// @param  owner The address of the account the withdrawal was done for.
    /// @param  token The token address
    /// @return The amount withdrawable
    function getAmountWithdrawable(address owner, address token)
        external
        view
        virtual
        returns (uint256);

    /// @dev Gets the amount that can be withdrawn immediately with `withdrawFromApprovedWithdrawalsNFT`.
    /// @param  owner The address of the account the withdrawal was done for.
    /// @param  token The token address
    /// @param  nftType The NFT token address types
    /// @param  nftID The token id
    /// @param  minter The NFT minter
    /// @return The amount withdrawable
    function getAmountWithdrawableNFT(
        address owner,
        address token,
        ExchangeData.NftType nftType,
        uint256 nftID,
        address minter
    ) external view virtual returns (uint256);

    /// @dev Notifies the exchange that the owner did not process a forced request.
    ///      If this is indeed the case, the exchange will enter withdrawal mode.
    ///
    ///      Can be called by anyone.
    ///
    /// @param  accountID The accountID the forced request was made for
    /// @param  tokenID The tokenID of the the forced request
    function notifyForcedRequestTooOld(uint32 accountID, uint16 tokenID)
        external
        virtual;

    /// @dev Allows a withdrawal to be done to an adddresss that is different
    ///      than initialy specified in the withdrawal request. This can be used to
    ///      implement functionality like fast withdrawals.
    ///
    ///      This function can only be called by an agent.
    ///
    /// @param from The address of the account that does the withdrawal.
    /// @param to The address to which 'amount' tokens were going to be withdrawn.
    /// @param token The address of the token that is withdrawn ('0x0' for ETH).
    /// @param amount The amount of tokens that are going to be withdrawn.
    /// @param storageID The storageID of the withdrawal request.
    /// @param newRecipient The new recipient address of the withdrawal.
    function setWithdrawalRecipient(
        address from,
        address to,
        address token,
        uint96 amount,
        uint32 storageID,
        address newRecipient
    ) external virtual;

    /// @dev Gets the withdrawal recipient.
    ///
    /// @param from The address of the account that does the withdrawal.
    /// @param to The address to which 'amount' tokens were going to be withdrawn.
    /// @param token The address of the token that is withdrawn ('0x0' for ETH).
    /// @param amount The amount of tokens that are going to be withdrawn.
    /// @param storageID The storageID of the withdrawal request.
    function getWithdrawalRecipient(
        address from,
        address to,
        address token,
        uint96 amount,
        uint32 storageID
    ) external view virtual returns (address);

    /// @dev Allows an agent to transfer ERC-20 tokens for a user using the allowance
    ///      the user has set for the exchange. This way the user only needs to approve a single exchange contract
    ///      for all exchange/agent features, which allows for a more seamless user experience.
    ///
    ///      This function can only be called by an agent.
    ///
    /// @param from The address of the account that sends the tokens.
    /// @param to The address to which 'amount' tokens are transferred.
    /// @param token The address of the token to transfer (ETH is and cannot be suppported).
    /// @param amount The amount of tokens transferred.
    function onchainTransferFrom(
        address from,
        address to,
        address token,
        uint256 amount
    ) external virtual;

    /// @dev Allows an agent to approve a rollup tx.
    ///
    ///      This function can only be called by an agent.
    ///
    /// @param owner The owner of the account
    /// @param txHash The hash of the transaction
    function approveTransaction(address owner, bytes32 txHash) external virtual;

    /// @dev Allows an agent to approve multiple rollup txs.
    ///
    ///      This function can only be called by an agent.
    ///
    /// @param owners The account owners
    /// @param txHashes The hashes of the transactions
    function approveTransactions(
        address[] calldata owners,
        bytes32[] calldata txHashes
    ) external virtual;

    /// @dev Checks if a rollup tx is approved using the tx's hash.
    ///
    /// @param owner The owner of the account that needs to authorize the tx
    /// @param txHash The hash of the transaction
    /// @return True if the tx is approved, else false
    function isTransactionApproved(address owner, bytes32 txHash)
        external
        view
        virtual
        returns (bool);

    // -- Admins --
    /// @dev Sets the max time deposits have to wait before becoming withdrawable.
    /// @param newValue The new value.
    /// @return  The old value.
    function setMaxAgeDepositUntilWithdrawable(uint32 newValue)
        external
        virtual
        returns (uint32);

    /// @dev Returns the max time deposits have to wait before becoming withdrawable.
    /// @return The value.
    function getMaxAgeDepositUntilWithdrawable()
        external
        view
        virtual
        returns (uint32);

    /// @dev Shuts down the exchange.
    ///      Once the exchange is shutdown all onchain requests are permanently disabled.
    ///      When all requirements are fulfilled the exchange owner can withdraw
    ///      the exchange stake with withdrawStake.
    ///
    ///      Note that the exchange can still enter the withdrawal mode after this function
    ///      has been invoked successfully. To prevent entering the withdrawal mode before the
    ///      the echange stake can be withdrawn, all withdrawal requests still need to be handled
    ///      for at least MIN_TIME_IN_SHUTDOWN seconds.
    ///
    ///      Can only be called by the exchange owner.
    ///
    /// @return success True if the exchange is shutdown, else False
    function shutdown() external virtual returns (bool success);

    /// @dev Gets the protocol fees for this exchange.
    /// @return syncedAt The timestamp the protocol fees were last updated
    /// @return takerFeeBips The protocol taker fee
    /// @return makerFeeBips The protocol maker fee
    /// @return previousTakerFeeBips The previous protocol taker fee
    /// @return previousMakerFeeBips The previous protocol maker fee
    function getProtocolFeeValues()
        external
        view
        virtual
        returns (
            uint32 syncedAt,
            uint8 takerFeeBips,
            uint8 makerFeeBips,
            uint8 previousTakerFeeBips,
            uint8 previousMakerFeeBips
        );

    /// @dev Gets the domain separator used in this exchange.
    function getDomainSeparator() external view virtual returns (bytes32);

    /// @dev set amm pool feeBips value.
    function setAmmFeeBips(uint8 _feeBips) external virtual;

    /// @dev get amm pool feeBips value.
    function getAmmFeeBips() external view virtual returns (uint8);
}

// File: contracts/amm/libamm/IAmmSharedConfig.sol

// Copyright 2017 Loopring Technology Limited.

interface IAmmSharedConfig {
    function maxForcedExitAge() external view returns (uint256);

    function maxForcedExitCount() external view returns (uint256);

    function forcedExitFee() external view returns (uint256);
}

// File: contracts/amm/libamm/AmmData.sol

// Copyright 2017 Loopring Technology Limited.

/// @title AmmData
library AmmData {
    uint256 public constant POOL_TOKEN_BASE = 100 * (10**8);
    uint256 public constant POOL_TOKEN_MINTED_SUPPLY = uint96(-1);

    enum PoolTxType {
        NOOP,
        JOIN,
        EXIT
    }

    struct PoolConfig {
        address sharedConfig;
        address exchange;
        string poolName;
        uint32 accountID;
        address[] tokens;
        uint96[] weights;
        uint8 feeBips;
        string tokenSymbol;
    }

    struct PoolJoin {
        address owner;
        uint96[] joinAmounts;
        uint32[] joinStorageIDs;
        uint96 mintMinAmount;
        uint96 fee;
        uint32 validUntil;
    }

    struct PoolExit {
        address owner;
        uint96 burnAmount;
        uint32 burnStorageID; // for pool token withdrawal from user to the pool
        uint96[] exitMinAmounts; // the amount to receive BEFORE paying the fee.
        uint96 fee;
        uint32 validUntil;
    }

    struct PoolTx {
        PoolTxType txType;
        bytes data;
        bytes signature;
    }

    struct Token {
        address addr;
        uint96 weight;
        uint16 tokenID;
    }

    struct Context {
        // functional parameters
        uint256 txIdx;
        // AMM pool state variables
        bytes32 domainSeparator;
        uint32 accountID;
        uint16 poolTokenID;
        uint8 feeBips;
        uint256 totalSupply;
        Token[] tokens;
        uint96[] tokenBalancesL2;
    }

    struct State {
        // Pool token state variables
        string poolName;
        string symbol;
        uint256 _totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
        mapping(address => uint256) nonces;
        // AMM pool state variables
        IAmmSharedConfig sharedConfig;
        Token[] tokens;
        // The order of the following variables important to minimize loads
        bytes32 exchangeDomainSeparator;
        bytes32 domainSeparator;
        IExchangeV3 exchange;
        uint32 accountID;
        uint16 poolTokenID;
        uint8 feeBips;
        address exchangeOwner;
        uint64 shutdownTimestamp;
        uint16 forcedExitCount;
        // A map from a user to the forced exit.
        mapping(address => PoolExit) forcedExit;
        mapping(bytes32 => bool) approvedTx;
    }
}

// File: contracts/aux/access/IBlockReceiver.sol

// Copyright 2017 Loopring Technology Limited.

/// @title IBlockReceiver
/// @author Brecht Devos - <[email protected]>
abstract contract IBlockReceiver {
    function beforeBlockSubmission(
        bytes calldata txsData,
        bytes calldata callbackData
    ) external virtual;
}

// File: contracts/lib/EIP712.sol

// Copyright 2017 Loopring Technology Limited.

library EIP712 {
    struct Domain {
        string name;
        string version;
        address verifyingContract;
    }

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    string internal constant EIP191_HEADER = "\x19\x01";

    function hash(Domain memory domain) internal pure returns (bytes32) {
        uint256 _chainid;
        assembly {
            _chainid := chainid()
        }

        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(domain.name)),
                    keccak256(bytes(domain.version)),
                    _chainid,
                    domain.verifyingContract
                )
            );
    }

    function hashPacked(bytes32 domainSeparator, bytes32 dataHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(EIP191_HEADER, domainSeparator, dataHash)
            );
    }
}

// File: contracts/thirdparty/SafeCast.sol

// Taken from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/SafeCast.sol

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value < 2**128, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value < 2**96, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value < 2**64, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value < 2**32, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value < 2**40, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value < 2**16, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value < 2**8, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(
            value >= -2**127 && value < 2**127,
            "SafeCast: value doesn't fit in 128 bits"
        );
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(
            value >= -2**63 && value < 2**63,
            "SafeCast: value doesn't fit in 64 bits"
        );
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(
            value >= -2**31 && value < 2**31,
            "SafeCast: value doesn't fit in 32 bits"
        );
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(
            value >= -2**15 && value < 2**15,
            "SafeCast: value doesn't fit in 16 bits"
        );
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(
            value >= -2**7 && value < 2**7,
            "SafeCast: value doesn't fit in 8 bits"
        );
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2**255, "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// File: contracts/lib/FloatUtil.sol

// Copyright 2017 Loopring Technology Limited.

/// @title Utility Functions for floats
/// @author Brecht Devos - <[email protected]>
library FloatUtil {
    using MathUint for uint256;
    using SafeCast for uint256;

    // Decodes a decimal float value that is encoded like `exponent | mantissa`.
    // Both exponent and mantissa are in base 10.
    // Decoding to an integer is as simple as `mantissa * (10 ** exponent)`
    // Will throw when the decoded value overflows an uint96
    /// @param f The float value with 5 bits for the exponent
    /// @param numBits The total number of bits (numBitsMantissa := numBits - numBitsExponent)
    /// @return value The decoded integer value.
    function decodeFloat(uint256 f, uint256 numBits)
        internal
        pure
        returns (uint96 value)
    {
        if (f == 0) {
            return 0;
        }
        uint256 numBitsMantissa = numBits.sub(5);
        uint256 exponent = f >> numBitsMantissa;
        // log2(10**77) = 255.79 < 256
        require(exponent <= 77, "EXPONENT_TOO_LARGE");
        uint256 mantissa = f & ((1 << numBitsMantissa) - 1);
        value = mantissa.mul(10**exponent).toUint96();
    }

    // Decodes a decimal float value that is encoded like `exponent | mantissa`.
    // Both exponent and mantissa are in base 10.
    // Decoding to an integer is as simple as `mantissa * (10 ** exponent)`
    // Will throw when the decoded value overflows an uint96
    /// @param f The float value with 5 bits exponent, 11 bits mantissa
    /// @return value The decoded integer value.
    function decodeFloat16(uint16 f) internal pure returns (uint96) {
        uint256 value = ((uint256(f) & 2047) * (10**(uint256(f) >> 11)));
        require(value < 2**96, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    // Decodes a decimal float value that is encoded like `exponent | mantissa`.
    // Both exponent and mantissa are in base 10.
    // Decoding to an integer is as simple as `mantissa * (10 ** exponent)`
    // Will throw when the decoded value overflows an uint96
    /// @param f The float value with 5 bits exponent, 19 bits mantissa
    /// @return value The decoded integer value.
    function decodeFloat24(uint24 f) internal pure returns (uint96) {
        uint256 value = ((uint256(f) & 524287) * (10**(uint256(f) >> 19)));
        require(value < 2**96, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }
}

// File: contracts/core/impl/libexchange/ExchangeSignatures.sol

// Copyright 2017 Loopring Technology Limited.

/// @title ExchangeSignatures.
/// @dev All methods in this lib are internal, therefore, there is no need
///      to deploy this library independently.
/// @author Brecht Devos - <[email protected]>
/// @author Daniel Wang  - <[email protected]>
library ExchangeSignatures {
    using SignatureUtil for bytes32;

    function requireAuthorizedTx(
        ExchangeData.State storage S,
        address signer,
        bytes memory signature,
        bytes32 txHash // inline call
    ) internal {
        require(signer != address(0), "INVALID_SIGNER");
        // Verify the signature if one is provided, otherwise fall back to an approved tx
        if (signature.length > 0) {
            require(
                txHash.verifySignature(signer, signature),
                "INVALID_SIGNATURE"
            );
        } else {
            require(S.approvedTx[signer][txHash], "TX_NOT_APPROVED");
            delete S.approvedTx[signer][txHash];
        }
    }
}

// File: contracts/core/impl/libtransactions/AccountUpdateTransaction.sol

// Copyright 2017 Loopring Technology Limited.

/// @title AccountUpdateTransaction
/// @author Brecht Devos - <[email protected]>
library AccountUpdateTransaction {
    using BytesUtil for bytes;
    using FloatUtil for uint16;
    using ExchangeSignatures for ExchangeData.State;

    bytes32 public constant ACCOUNTUPDATE_TYPEHASH =
        keccak256(
            "AccountUpdate(address owner,uint32 accountID,uint16 feeTokenID,uint96 maxFee,uint256 publicKey,uint32 validUntil,uint32 nonce)"
        );

    struct AccountUpdate {
        address owner;
        uint32 accountID;
        uint16 feeTokenID;
        uint96 maxFee;
        uint96 fee;
        uint256 publicKey;
        uint32 validUntil;
        uint32 nonce;
    }

    // Auxiliary data for each account update
    struct AccountUpdateAuxiliaryData {
        bytes signature;
        uint96 maxFee;
        uint32 validUntil;
    }

    function process(
        ExchangeData.State storage S,
        ExchangeData.BlockContext memory ctx,
        bytes memory data,
        uint256 offset,
        bytes memory auxiliaryData
    ) internal {
        // Read the account update
        AccountUpdate memory accountUpdate;
        readTx(data, offset, accountUpdate);
        AccountUpdateAuxiliaryData memory auxData = abi.decode(
            auxiliaryData,
            (AccountUpdateAuxiliaryData)
        );

        // Fill in withdrawal data missing from DA
        accountUpdate.validUntil = auxData.validUntil;
        accountUpdate.maxFee = auxData.maxFee == 0
            ? accountUpdate.fee
            : auxData.maxFee;
        // Validate
        require(
            ctx.timestamp < accountUpdate.validUntil,
            "ACCOUNT_UPDATE_EXPIRED"
        );
        require(
            accountUpdate.fee <= accountUpdate.maxFee,
            "ACCOUNT_UPDATE_FEE_TOO_HIGH"
        );

        // Calculate the tx hash
        bytes32 txHash = hashTx(ctx.DOMAIN_SEPARATOR, accountUpdate);

        // Check onchain authorization
        S.requireAuthorizedTx(accountUpdate.owner, auxData.signature, txHash);
    }

    function readTx(
        bytes memory data,
        uint256 offset,
        AccountUpdate memory accountUpdate
    ) internal pure {
        uint256 _offset = offset;

        require(
            data.toUint8Unsafe(_offset) ==
                uint8(ExchangeData.TransactionType.ACCOUNT_UPDATE),
            "INVALID_TX_TYPE"
        );
        _offset += 1;

        // Check that this is a conditional offset
        require(data.toUint8Unsafe(_offset) == 1, "INVALID_AUXILIARYDATA_DATA");
        _offset += 1;

        // Extract the data from the tx data
        // We don't use abi.decode for this because of the large amount of zero-padding
        // bytes the circuit would also have to hash.
        accountUpdate.owner = data.toAddressUnsafe(_offset);
        _offset += 20;
        accountUpdate.accountID = data.toUint32Unsafe(_offset);
        _offset += 4;
        accountUpdate.feeTokenID = data.toUint16Unsafe(_offset);
        _offset += 2;
        accountUpdate.fee = data.toUint16Unsafe(_offset).decodeFloat16();
        _offset += 2;
        accountUpdate.publicKey = data.toUintUnsafe(_offset);
        _offset += 32;
        accountUpdate.nonce = data.toUint32Unsafe(_offset);
        _offset += 4;
    }

    function hashTx(
        bytes32 DOMAIN_SEPARATOR,
        AccountUpdate memory accountUpdate
    ) internal pure returns (bytes32) {
        return
            EIP712.hashPacked(
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        ACCOUNTUPDATE_TYPEHASH,
                        accountUpdate.owner,
                        accountUpdate.accountID,
                        accountUpdate.feeTokenID,
                        accountUpdate.maxFee,
                        accountUpdate.publicKey,
                        accountUpdate.validUntil,
                        accountUpdate.nonce
                    )
                )
            );
    }
}

// File: contracts/aux/agents/LoopringWalletAgent.sol

// Copyright 2017 Loopring Technology Limited.

/// @title LoopringWalletAgent
/// @dev Agent to allow authorizing L2 transactions using an undeployed Loopring Smart Wallet
/// @author Brecht Devos - <[email protected]>
contract LoopringWalletAgent is WalletDeploymentLib, IBlockReceiver {
    using AddressUtil for address;
    using SignatureUtil for bytes32;

    // Maximum amount of time this agent can still authorize transactions
    // approved by the initial wallet owner after the wallet has been deployed.
    uint256 public constant MAX_TIME_VALID_AFTER_CREATION = 7 days;

    address public immutable deployer;
    IExchangeV3 public immutable exchange;
    bytes32 public immutable EXCHANGE_DOMAIN_SEPARATOR;

    struct WalletSignatureData {
        bytes signature;
        uint96 maxFee;
        uint32 validUntil;
        address walletOwner;
        uint256 salt;
    }

    constructor(
        address _walletImplementation,
        address _deployer,
        IExchangeV3 _exchange
    ) WalletDeploymentLib(_walletImplementation) {
        deployer = _deployer;
        exchange = _exchange;
        EXCHANGE_DOMAIN_SEPARATOR = _exchange.getDomainSeparator();
    }

    // Allows authorizing transactions in an independent transaction
    function approveTransactionsFor(
        address[] calldata wallets,
        bytes32[] calldata txHashes,
        bytes[] calldata signatures
    ) external virtual {
        require(txHashes.length == wallets.length, "INVALID_DATA");
        require(signatures.length == wallets.length, "INVALID_DATA");

        // Verify the signatures
        for (uint256 i = 0; i < wallets.length; i++) {
            WalletSignatureData memory data = abi.decode(
                signatures[i],
                (WalletSignatureData)
            );
            require(
                _canInitialOwnerAuthorizeTransactions(
                    wallets[i],
                    msg.sender,
                    data.salt
                ) || _isUsableSignatureForWallet(wallets[i], txHashes[i], data),
                "INVALID_SIGNATURE"
            );
        }

        // Approve the transactions on the exchange
        exchange.approveTransactions(wallets, txHashes);
    }

    // Allow transactions to be authorized while submitting a block
    function beforeBlockSubmission(
        bytes calldata txsData,
        bytes calldata callbackData
    ) external virtual override {
        _beforeBlockSubmission(txsData, callbackData);
    }

    // Returns true if the signature can be used for authorizing the transaction
    function isUsableSignatureForWallet(
        address wallet,
        bytes32 hash,
        bytes memory signature
    ) public view returns (bool) {
        WalletSignatureData memory data = abi.decode(
            signature,
            (WalletSignatureData)
        );
        return _isUsableSignatureForWallet(wallet, hash, data);
    }

    // Returns true if just the signature is valid (but it may have expired)
    function isValidSignatureForWallet(
        address wallet,
        bytes32 hash,
        bytes memory signature
    ) public view returns (bool) {
        WalletSignatureData memory data = abi.decode(
            signature,
            (WalletSignatureData)
        );
        return _isValidSignatureForWallet(wallet, hash, data);
    }

    // Returns the timestamp up until the signature can be used
    function getSignatureExpiry(
        address wallet,
        bytes32 hash,
        bytes memory signature
    ) public view returns (uint256) {
        WalletSignatureData memory data = abi.decode(
            signature,
            (WalletSignatureData)
        );
        if (!_isValidSignatureForWallet(wallet, hash, data)) {
            return 0;
        } else {
            return getInitialOwnerExpiry(wallet);
        }
    }

    // Returns the timestamp up until the initial owner can authorize transactions
    function getInitialOwnerExpiry(address walletAddress)
        public
        view
        returns (uint256)
    {
        // Always allowed when the smart wallet hasn't been deployed yet
        if (!walletAddress.isContract()) {
            return type(uint256).max;
        }

        ILoopringWalletV2 wallet = ILoopringWalletV2(walletAddress);

        // Allow the initial wallet owner to sign transactions after deployment for some limited time
        return wallet.getCreationTimestamp() + MAX_TIME_VALID_AFTER_CREATION;
    }

    // == Internal Functions ==

    function _beforeBlockSubmission(
        bytes calldata txsData,
        bytes calldata callbackData
    )
        internal
        view
        returns (AccountUpdateTransaction.AccountUpdate memory accountUpdate)
    {
        WalletSignatureData memory data = abi.decode(
            callbackData,
            (WalletSignatureData)
        );

        // Read the AccountUpdate transaction
        AccountUpdateTransaction.readTx(txsData, 0, accountUpdate);

        // Fill in withdrawal data missing from DA
        accountUpdate.validUntil = data.validUntil;
        accountUpdate.maxFee = data.maxFee == 0
            ? accountUpdate.fee
            : data.maxFee;
        // Validate
        require(
            block.timestamp < accountUpdate.validUntil,
            "ACCOUNT_UPDATE_EXPIRED"
        );
        require(
            accountUpdate.fee <= accountUpdate.maxFee,
            "ACCOUNT_UPDATE_FEE_TOO_HIGH"
        );

        // Calculate the transaction hash
        bytes32 txHash = AccountUpdateTransaction.hashTx(
            EXCHANGE_DOMAIN_SEPARATOR,
            accountUpdate
        );

        // Verify the signature
        require(
            _isUsableSignatureForWallet(accountUpdate.owner, txHash, data),
            "INVALID_SIGNATURE"
        );

        // Make sure we have consumed exactly the expected number of transactions
        require(
            txsData.length == ExchangeData.TX_DATA_AVAILABILITY_SIZE,
            "INVALID_NUM_TXS"
        );
    }

    function _isUsableSignatureForWallet(
        address wallet,
        bytes32 hash,
        WalletSignatureData memory data
    ) internal view returns (bool) {
        // Verify that the signature is valid and the initial owner is still allowed
        // to authorize transactions for the wallet.
        return
            _isValidSignatureForWallet(wallet, hash, data) &&
            _isInitialOwnerUsable(wallet);
    }

    function _isValidSignatureForWallet(
        address wallet,
        bytes32 hash,
        WalletSignatureData memory data
    ) internal view returns (bool) {
        // Verify that the account owner is the initial owner of the smart wallet
        // and that the signature is a valid signature from the initial owner.
        return
            _isInitialOwner(wallet, data.walletOwner, data.salt) &&
            hash.verifySignature(data.walletOwner, data.signature);
    }

    function _canInitialOwnerAuthorizeTransactions(
        address wallet,
        address walletOwner,
        uint256 salt
    ) internal view returns (bool) {
        // Verify that the initial owner is the owner of the wallet
        // and can still be used to authorize transactions
        return
            _isInitialOwner(wallet, walletOwner, salt) &&
            _isInitialOwnerUsable(wallet);
    }

    function _isInitialOwnerUsable(address wallet)
        internal
        view
        virtual
        returns (bool)
    {
        return block.timestamp <= getInitialOwnerExpiry(wallet);
    }

    function _isInitialOwner(
        address wallet,
        address walletOwner,
        uint256 salt
    ) internal view returns (bool) {
        return _computeWalletAddress(walletOwner, salt, deployer) == wallet;
    }
}

// File: contracts/aux/agents/DestroyableWalletAgent.sol

// Copyright 2017 Loopring Technology Limited.

/// @title DestroyableWalletAgent
/// @dev Agent that allows setting up accounts that can easily be rendered unusable
/// @author Brecht Devos - <[email protected]>
contract DestroyableWalletAgent is LoopringWalletAgent {
    struct WalletData {
        uint32 accountID;
        bool destroyed;
    }
    mapping(address => WalletData) public walletData;

    constructor(
        address _walletImplementation,
        address _deployer,
        IExchangeV3 exchange
    ) LoopringWalletAgent(_walletImplementation, _deployer, exchange) {}

    function beforeBlockSubmission(
        bytes calldata txsData,
        bytes calldata callbackData
    ) external override {
        AccountUpdateTransaction.AccountUpdate memory accountUpdate;
        accountUpdate = LoopringWalletAgent._beforeBlockSubmission(
            txsData,
            callbackData
        );

        WalletData storage wallet = walletData[accountUpdate.owner];
        if (wallet.accountID == 0) {
            // First use of this wallet, store the accountID
            wallet.accountID = accountUpdate.accountID;
        } else {
            // Only allow a single account on L2 to ever sign L2 transactions
            // for this wallet address
            require(
                wallet.accountID == accountUpdate.accountID,
                "ACCOUNT_ALREADY_EXISTS_FOR_WALLET"
            );
        }
        // Destroy the wallet if the EdDSA public key is set to 0
        if (accountUpdate.publicKey == 0) {
            wallet.destroyed = true;
        }
    }

    /// @dev Computes the destructable wallet address
    /// @param owner The owner.
    /// @param salt A salt.
    /// @return The wallet address
    function computeWalletAddress(address owner, uint256 salt)
        public
        view
        returns (address)
    {
        return _computeWalletAddress(owner, salt, deployer);
    }

    /// @dev Checks if the wallet can still be used
    /// @param wallet The wallet address.
    /// @return Returns true if destroyed, else false
    function isDestroyed(address wallet) public view returns (bool) {
        return walletData[wallet].destroyed;
    }

    // Disable `approveTransactionsFor`
    function approveTransactionsFor(
        address[] calldata, /*wallets*/
        bytes32[] calldata, /*txHashes*/
        bytes[] calldata /*signatures*/
    ) external pure override {
        revert("UNSUPPORTED");
    }

    // == Internal Functions ==

    function _isInitialOwnerUsable(address wallet)
        internal
        view
        override
        returns (bool)
    {
        // Also disallow the owner to use the wallet when destroyed
        return
            LoopringWalletAgent._isInitialOwnerUsable(wallet) &&
            !isDestroyed(wallet);
    }
}