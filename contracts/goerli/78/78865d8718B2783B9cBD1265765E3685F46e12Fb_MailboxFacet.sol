pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./interfaces/IAllowList.sol";

/// @author Matter Labs
abstract contract AllowListed {
    modifier senderCanCallFunction(IAllowList _allowList) {
        // Preventing the stack too deep error
        {
            require(_allowList.canCall(msg.sender, address(this), msg.sig), "nr");
        }
        _;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



interface IAllowList {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Access mode of target contract is changed
    event UpdateAccessMode(address indexed target, AccessMode previousMode, AccessMode newMode);

    /// @notice Permission to call is changed
    event UpdateCallPermission(address indexed caller, address indexed target, bytes4 indexed functionSig, bool status);

    /// @notice Type of access to a specific contract includes three different modes
    /// @param Closed No one has access to the contract
    /// @param SpecialAccessOnly Any address with granted special access can interact with a contract (see `hasSpecialAccessToCall`)
    /// @param Public Everyone can interact with a contract
    enum AccessMode {
        Closed,
        SpecialAccessOnly,
        Public
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/

    function getAccessMode(address _target) external view returns (AccessMode);

    function hasSpecialAccessToCall(
        address _caller,
        address _target,
        bytes4 _functionSig
    ) external view returns (bool);

    function canCall(
        address _caller,
        address _target,
        bytes4 _functionSig
    ) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                           ALLOW LIST LOGIC
    //////////////////////////////////////////////////////////////*/

    function setBatchAccessMode(address[] calldata _targets, AccessMode[] calldata _accessMode) external;

    function setAccessMode(address _target, AccessMode _accessMode) external;

    function setBatchPermissionToCall(
        address[] calldata _callers,
        address[] calldata _targets,
        bytes4[] calldata _functionSigs,
        bool[] calldata _enables
    ) external;

    function setPermissionToCall(
        address _caller,
        address _target,
        bytes4 _functionSig,
        bool _enable
    ) external;
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



interface IL2Messenger {
    function sendToL1(bytes memory _message) external returns (bytes32);
}

interface IContractDeployer {
    struct ForceDeployment {
        bytes32 bytecodeHash;
        address newAddress;
        uint256 value;
        bytes input;
    }

    function forceDeployOnAddresses(ForceDeployment[] calldata _deployParams) external;

    function create2(
        bytes32 _salt,
        bytes32 _bytecodeHash,
        bytes calldata _input
    ) external;
}

uint160 constant SYSTEM_CONTRACTS_OFFSET = 0x8000; // 2^15

address constant BOOTLOADER_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x01);

address constant DEPLOYER_SYSTEM_CONTRACT_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x06);

// A contract that is allowed to deploy any codehash
// on any address. To be used only during an upgrade.
address constant FORCE_DEPLOYER = address(SYSTEM_CONTRACTS_OFFSET + 0x07);

IL2Messenger constant L2_MESSENGER = IL2Messenger(address(SYSTEM_CONTRACTS_OFFSET + 0x08));

library L2ContractHelper {
    bytes32 constant CREATE2_PREFIX = keccak256("zksyncCreate2");

    function sendMessageToL1(bytes memory _message) internal returns (bytes32) {
        return L2_MESSENGER.sendToL1(_message);
    }

    function hashL2Bytecode(bytes memory _bytecode) internal pure returns (bytes32 hashedBytecode) {
        // Note that the length of the bytecode
        // must be provided in 32-byte words.
        require(_bytecode.length % 32 == 0, "po");

        uint256 bytecodeLenInWords = _bytecode.length / 32;
        require(bytecodeLenInWords < 2**16, "pp"); // bytecode length must be less than 2^16 words
        require(bytecodeLenInWords % 2 == 1, "pr"); // bytecode length in words must be odd
        hashedBytecode = sha256(_bytecode) & 0x00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        // Setting the version of the hash
        hashedBytecode = (hashedBytecode | bytes32(uint256(1 << 248)));
        // Setting the length
        hashedBytecode = hashedBytecode | bytes32(bytecodeLenInWords << 224);
    }

    /// @notice Validates the bytecodehash
    function validateBytecodeHash(bytes32 _bytecodeHash) internal pure {
        uint8 version = uint8(_bytecodeHash[0]);
        require(version == 1 && _bytecodeHash[1] == bytes1(0), "zf"); // Incorrectly formatted bytecodeHash

        require(bytecodeLen(_bytecodeHash) % 2 == 1, "uy"); // Code length in words must be odd
    }

    /// @notice returns the length of the bytecode
    function bytecodeLen(bytes32 _bytecodeHash) internal pure returns (uint256 codeLengthInWords) {
        codeLengthInWords = uint256(uint8(_bytecodeHash[2])) * 256 + uint256(uint8(_bytecodeHash[3]));
    }

    function computeCreate2Address(
        address _sender,
        bytes32 _salt,
        bytes32 _bytecodeHash,
        bytes32 _constructorInputHash
    ) internal pure returns (address) {
        bytes32 senderBytes = bytes32(uint256(uint160(_sender)));
        bytes32 data = keccak256(
            bytes.concat(CREATE2_PREFIX, senderBytes, _salt, _bytecodeHash, _constructorInputHash)
        );

        return address(uint160(uint256(data)));
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



library UncheckedMath {
    function uncheckedInc(uint256 _number) internal pure returns (uint256) {
        unchecked {
            return _number + 1;
        }
    }

    function uncheckedAdd(uint256 _lhs, uint256 _rhs) internal pure returns (uint256) {
        unchecked {
            return _lhs + _rhs;
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * _Since v2.5.0:_ this module is now much more gas efficient, given net gas
 * metering changes introduced in the Istanbul hardfork.
 */
abstract contract ReentrancyGuard {
    /// @dev Address of lock flag variable.
    /// @dev Flag is placed at random memory location to not interfere with Storage contract.
    uint256 private constant LOCK_FLAG_ADDRESS = 0x8e94fed44239eb2314ab7a406345e6c5a8f0ccedf3b600de3d004e672c33abf4; // keccak256("ReentrancyGuard") - 1;

    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/566a774222707e424896c0c390a84dc3c13bdcb2/contracts/security/ReentrancyGuard.sol
    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier reentrancyGuardInitializer() {
        _initializeReentrancyGuard();
        _;
    }

    function _initializeReentrancyGuard() private {
        uint256 lockSlotOldValue;

        // Storing an initial non-zero value makes deployment a bit more
        // expensive but in exchange every call to nonReentrant
        // will be cheaper.
        assembly {
            lockSlotOldValue := sload(LOCK_FLAG_ADDRESS)
            sstore(LOCK_FLAG_ADDRESS, _NOT_ENTERED)
        }

        // Check that storage slot for reentrancy guard is empty to rule out possibility of slot conflict
        require(lockSlotOldValue == 0, "1B");
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        uint256 _status;
        assembly {
            _status := sload(LOCK_FLAG_ADDRESS)
        }

        // On the first call to nonReentrant, _notEntered will be true
        require(_status == _NOT_ENTERED, "r1");

        // Any calls to nonReentrant after this point will fail
        assembly {
            sstore(LOCK_FLAG_ADDRESS, _ENTERED)
        }

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        assembly {
            sstore(LOCK_FLAG_ADDRESS, _NOT_ENTERED)
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



/// @dev `keccak256("")`
bytes32 constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

/// @dev Bytes in raw L2 log
/// @dev Equal to the bytes size of the tuple - (uint8 ShardId, bool isService, uint16 txNumberInBlock, address sender, bytes32 key, bytes32 value)
uint256 constant L2_TO_L1_LOG_SERIALIZE_SIZE = 88;

/// @dev The maximum length of the bytes array with L2 -> L1 logs
uint256 constant MAX_L2_TO_L1_LOGS_COMMITMENT_BYTES = 4 + L2_TO_L1_LOG_SERIALIZE_SIZE * 512;

/// @dev L2 -> L1 logs Merkle tree height
uint256 constant L2_TO_L1_LOG_MERKLE_TREE_HEIGHT = 9;

/// @dev The value of default leaf hash for L2 -> L1 logs Merkle tree
/// @dev An incomplete fixed-size tree is filled with this value to be a full binary tree
/// @dev Actually equal to the `keccak256(new bytes(L2_TO_L1_LOG_SERIALIZE_SIZE))`
bytes32 constant L2_L1_LOGS_TREE_DEFAULT_LEAF_HASH = 0x72abee45b59e344af8a6e520241c4744aff26ed411f4c4b00f8af09adada43ba;

/// @dev Number of bytes in a one initial storage change
/// @dev Equal to the bytes size of the tuple - (bytes32 key, bytes32 value)
uint256 constant INITIAL_STORAGE_CHANGE_SERIALIZE_SIZE = 64;

/// @dev The maximum length of the bytes array with initial storage changes
uint256 constant MAX_INITIAL_STORAGE_CHANGES_COMMITMENT_BYTES = 4 + INITIAL_STORAGE_CHANGE_SERIALIZE_SIZE * 4765;

/// @dev Number of bytes in a one repeated storage change
/// @dev Equal to the bytes size of the tuple - (bytes8 key, bytes32 value)
uint256 constant REPEATED_STORAGE_CHANGE_SERIALIZE_SIZE = 40;

/// @dev The maximum length of the bytes array with repeated storage changes
uint256 constant MAX_REPEATED_STORAGE_CHANGES_COMMITMENT_BYTES = 4 + REPEATED_STORAGE_CHANGE_SERIALIZE_SIZE * 7564;

// TODO: change constant to the real root hash of empty Merkle tree (SMA-184)
bytes32 constant DEFAULT_L2_LOGS_TREE_ROOT_HASH = bytes32(0);

/// @dev The address of the special smart contract that can send arbitrary length message as an L2 log
address constant L2_TO_L1_MESSENGER = address(0x8008);

/// @dev The address of the bootloader start program
address constant L2_BOOTLOADER_ADDRESS = address(0x8001);

/// @dev The address of the known code storage system contract
address constant L2_KNOWN_CODE_STORAGE_ADDRESS = address(0x8004);

/// @dev The address of the context system contract
address constant L2_SYSTEM_CONTEXT_ADDRESS = address(0x800b);

/// @dev Denotes the first byte of the zkSync transaction that came from L1.
uint256 constant PRIORITY_OPERATION_L2_TX_TYPE = 255;

/// @dev The amount of time in seconds the validator has to process the priority transaction
/// NOTE: The constant is set to zero for the Alpha release period
uint256 constant PRIORITY_EXPIRATION = 0 days;

/// @dev Notice period before activation preparation status of upgrade mode (in seconds)
/// @dev NOTE: we must reserve for users enough time to send full exit operation, wait maximum time for processing this operation and withdraw funds from it.
uint256 constant UPGRADE_NOTICE_PERIOD = 0;

/// @dev Timestamp - seconds since unix epoch
uint256 constant COMMIT_TIMESTAMP_NOT_OLDER = 365 days;

/// @dev Maximum available error between real commit block timestamp and analog used in the verifier (in seconds)
/// @dev Must be used cause miner's `block.timestamp` value can differ on some small value (as we know - 15 seconds)
uint256 constant COMMIT_TIMESTAMP_APPROXIMATION_DELTA = 365 days;

/// @dev Bit mask to apply for verifier public input before verifying.
uint256 constant INPUT_MASK = 452312848583266388373324160190187140051835877600158453279131187530910662655;

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "../Storage.sol";
import "../../common/ReentrancyGuard.sol";
import "../../common/AllowListed.sol";

/// @title Base contract containing functions accessible to the other facets.
/// @author Matter Labs
contract Base is ReentrancyGuard, AllowListed {
    AppStorage internal s;

    /// @notice Checks that the message sender is an active governor
    modifier onlyGovernor() {
        require(msg.sender == s.governor, "1g"); // only by governor
        _;
    }

    /// @notice Checks if validator is active
    modifier onlyValidator() {
        require(s.validators[msg.sender], "1h"); // validator is not active
        _;
    }

    modifier onlySecurityCouncil() {
        require(msg.sender == s.upgrades.securityCouncil, "a9"); // not a security council
        _;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "../interfaces/IMailbox.sol";
import "../libraries/Merkle.sol";
import "../libraries/PriorityQueue.sol";
import "../Storage.sol";
import "../Config.sol";
import "../../common/libraries/UncheckedMath.sol";
import "../../common/L2ContractHelper.sol";
import "./Base.sol";

/// @title zkSync Mailbox contract providing interfaces for L1 <-> L2 interaction.
/// @author Matter Labs
contract MailboxFacet is Base, IMailbox {
    using UncheckedMath for uint256;
    using PriorityQueue for PriorityQueue.Queue;

    /// @notice Prove that a specific arbitrary-length message was sent in a specific L2 block number
    /// @param _blockNumber The executed L2 block number in which the message appeared
    /// @param _index The position in the L2 logs Merkle tree of the l2Log that was sent with the message
    /// @param _message Information about the sent message: sender address, the message itself, tx index in the L2 block where the message was sent
    /// @param _proof Merkle proof for inclusion of L2 log that was sent with the message
    /// @return Whether the proof is valid
    function proveL2MessageInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _L2MessageToLog(_message), _proof);
    }

    /// @notice Prove that a specific L2 log was sent in a specific L2 block
    /// @param _blockNumber The executed L2 block number in which the log appeared
    /// @param _index The position of the l2log in the L2 logs Merkle tree
    /// @param _log Information about the sent log
    /// @param _proof Merkle proof for inclusion of the L2 log
    /// @return Whether the proof is correct and L2 log is included in block
    function proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _log, _proof);
    }

    /// @dev Prove that a specific L2 log was sent in a specific L2 block number
    function _proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) internal view returns (bool) {
        require(_blockNumber <= s.totalBlocksExecuted, "xx");

        bytes32 hashedLog = keccak256(
            abi.encodePacked(_log.l2ShardId, _log.isService, _log.txNumberInBlock, _log.sender, _log.key, _log.value)
        );
        // Check that hashed log is not the default one,
        // otherwise it means that the value is out of range of sent L2 -> L1 logs
        require(hashedLog != L2_L1_LOGS_TREE_DEFAULT_LEAF_HASH, "tw");
        // Check that the proof length is exactly the same as tree height, to prevent
        // any shorter/longer paths attack on the Merkle path validation
        require(_proof.length == L2_TO_L1_LOG_MERKLE_TREE_HEIGHT, "rz");

        bytes32 calculatedRootHash = Merkle.calculateRoot(_proof, _index, hashedLog);
        bytes32 actualRootHash = s.l2LogsRootHashes[_blockNumber];

        return actualRootHash == calculatedRootHash;
    }

    /// @dev Convert arbitrary-length message to the raw l2 log
    function _L2MessageToLog(L2Message calldata _message) internal pure returns (L2Log memory) {
        return
            L2Log({
                l2ShardId: 0,
                isService: true,
                txNumberInBlock: _message.txNumberInBlock,
                sender: L2_TO_L1_MESSENGER,
                key: bytes32(uint256(uint160(_message.sender))),
                value: keccak256(_message.data)
            });
    }

    /// @notice Estimates the cost in Ether of requesting execution of an L2 transaction from L1
    /// @return The estimated ergs
    function l2TransactionBaseCost(
        uint256, // _gasPrice
        uint256, // _ergsLimit
        uint32 // _calldataLength
    ) public pure returns (uint256) {
        // TODO: estimate gas for L1 execute
        return 0;
    }

    /// @notice Request execution of L2 transaction from L1.
    /// @param _contractL2 The L2 receiver address
    /// @param _l2Value `msg.value` of L2 transaction. Please note, this ether is not transferred with requesting priority op,
    /// but will be taken from the balance in L2 during the execution
    /// @param _calldata The input of the L2 transaction
    /// @param _ergsLimit Maximum amount of ergs that transaction can consume during execution on L2
    /// @param _factoryDeps An array of L2 bytecodes that will be marked as known on L2
    /// @return canonicalTxHash The hash of the requested L2 transaction. This hash can be used to follow the transaction status
    function requestL2Transaction(
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) external payable nonReentrant senderCanCallFunction(s.allowList) returns (bytes32 canonicalTxHash) {
        canonicalTxHash = _requestL2Transaction(msg.sender, _contractL2, _l2Value, _calldata, _ergsLimit, _factoryDeps);
    }

    function _requestL2Transaction(
        address _sender,
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) internal returns (bytes32 canonicalTxHash) {
        require(_ergsLimit <= s.priorityTxMaxErgsLimit, "ui");
        uint64 expirationTimestamp = uint64(block.timestamp + PRIORITY_EXPIRATION); // Safe to cast
        uint256 txId = s.priorityQueue.getTotalPriorityTxs();
        // TODO: Restore after stable priority op fee modeling. (SMA-1230)
        // uint256 baseCost = l2TransactionBaseCost(tx.gasprice, _ergsLimit, uint32(_calldata.length));
        // uint256 layer2Tip = msg.value - baseCost;

        canonicalTxHash = _writePriorityOp(
            _sender,
            txId,
            _l2Value,
            _contractL2,
            _calldata,
            expirationTimestamp,
            _ergsLimit,
            _factoryDeps
        );
    }

    /// @notice Stores a transaction record in storage & send event about that
    function _writePriorityOp(
        address _sender,
        uint256 _txId,
        uint256 _l2Value,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint64 _expirationTimestamp,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) internal returns (bytes32 canonicalTxHash) {
        L2CanonicalTransaction memory transaction = serializeL2Transaction(
            _txId,
            _l2Value,
            _sender,
            _contractAddressL2,
            _calldata,
            _ergsLimit,
            _factoryDeps
        );
        canonicalTxHash = keccak256(abi.encode(transaction));

        s.priorityQueue.pushBack(
            PriorityOperation({
                canonicalTxHash: canonicalTxHash,
                expirationTimestamp: _expirationTimestamp,
                layer2Tip: uint192(0) // TODO: Restore after fee modeling will be stable. (SMA-1230)
            })
        );

        // Data that is needed for the operator to simulate priority queue offchain
        emit NewPriorityRequest(_txId, canonicalTxHash, _expirationTimestamp, transaction, _factoryDeps);
    }

    /// @dev Accepts the parameters of the l2 transaction and converts it to the canonical form.
    /// @param _txId Priority operation ID, used as a unique identifier so that transactions always have a different hash
    /// @param _l2Value `msg.value` of L2 transaction. Please note, this ether is not transferred with requesting priority op,
    /// but will be taken from the balance in L2 during the execution
    /// @param _sender The L2 address of the account that initiates the transaction
    /// @param _contractAddressL2 The L2 receiver address
    /// @param _calldata The input of the L2 transaction
    /// @param _ergsLimit Maximum amount of ergs that transaction can consume during execution on L2
    /// @param _factoryDeps An array of L2 bytecodes that will be marked as known on L2
    /// @return The canonical form of the l2 transaction parameters
    function serializeL2Transaction(
        uint256 _txId,
        uint256 _l2Value,
        address _sender,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) public pure returns (L2CanonicalTransaction memory) {
        return
            L2CanonicalTransaction({
                txType: PRIORITY_OPERATION_L2_TX_TYPE,
                from: uint256(uint160(_sender)),
                to: uint256(uint160(_contractAddressL2)),
                ergsLimit: _ergsLimit,
                ergsPerPubdataByteLimit: uint256(30),
                maxFeePerErg: uint256(0),
                maxPriorityFeePerErg: uint256(0),
                paymaster: uint256(0),
                reserved: [uint256(_txId), _l2Value, 0, 0, 0, 0],
                data: _calldata,
                signature: new bytes(0),
                factoryDeps: _hashFactoryDeps(_factoryDeps),
                paymasterInput: new bytes(0),
                reservedDynamic: new bytes(0)
            });
    }

    /// @notice Hashes the L2 bytecodes and returns them in the format in which they are processed by the bootloader
    function _hashFactoryDeps(bytes[] calldata _factoryDeps)
        internal
        pure
        returns (uint256[] memory hashedFactoryDeps)
    {
        uint256 factoryDepsLen = _factoryDeps.length;
        hashedFactoryDeps = new uint256[](factoryDepsLen);
        for (uint256 i = 0; i < factoryDepsLen; i = i.uncheckedInc()) {
            bytes32 hashedBytecode = L2ContractHelper.hashL2Bytecode(_factoryDeps[i]);

            // Store the resulting hash sequentially in bytes.
            assembly {
                mstore(add(hashedFactoryDeps, mul(add(i, 1), 32)), hashedBytecode)
            }
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import {L2Log, L2Message} from "../Storage.sol";

interface IMailbox {
    /// @dev Structure that includes all fields of the L2 transaction
    /// @dev The hash of this structure is the "canonical L2 transaction hash" and can be used as a unique identifier of a tx
    /// @param txType The tx type number, depending on which the L2 transaction can be interpreted differently
    /// @param from The sender's address. `uint256` type for possible address format changes and maintaining backward compatibility
    /// @param to The recipient's address. `uint256` type for possible address format changes and maintaining backward compatibility
    /// @param ergsLimit Ergs limit on L2 transaction. Analog to the `gasLimit` on an L1 transactions
    /// @param ergsPerPubdataByteLimit Maximum number of ergs that will cost one byte of pubdata (every piece of data that will be stored on L1 as calldata)
    /// @param maxFeePerErg The absolute maximum sender willing to pay per unit of ergs to get the transaction included in a block. Analog to the EIP-1559 `maxFeePerGas` on an L1 transactions
    /// @param maxPriorityFeePerErg The additional fee that is paid directly to the validator to incentivize them to include the transaction in a block. Analog to the EIP-1559 `maxPriorityFeePerGas` on an L1 transactions
    /// @param paymaster The address of the EIP-4337 paymaster, that will pay fees for the transaction. `uint256` type for possible address format changes and maintaining backward compatibility
    /// @param reserved The fixed-length fields for usage in a future extension of transaction formats
    /// @param data The calldata that is transmitted for the transaction call
    /// @param signature An abstract set of bytes that are used for transaction authorization
    /// @param factoryDeps The set of L2 bytecode hashes whose preimages were shown on L1
    /// @param paymasterInput The arbitrary-length data that is used as a calldata to the paymaster pre-call
    /// @param reservedDynamic The arbitrary-length field for usage in a future extension of transaction formats
    struct L2CanonicalTransaction {
        uint256 txType;
        uint256 from;
        uint256 to;
        uint256 ergsLimit;
        uint256 ergsPerPubdataByteLimit;
        uint256 maxFeePerErg;
        uint256 maxPriorityFeePerErg;
        uint256 paymaster;
        // In the future, we might want to add some
        // new fields to the struct. The `txData` struct
        // is to be passed to account and any changes to its structure
        // would mean a breaking change to these accounts. To prevent this,
        // we should keep some fields as "reserved".
        // It is also recommended that their length is fixed, since
        // it would allow easier proof integration (in case we will need
        // some special circuit for preprocessing transactions).
        uint256[6] reserved;
        bytes data;
        bytes signature;
        uint256[] factoryDeps;
        bytes paymasterInput;
        // Reserved dynamic type for the future use-case. Using it should be avoided,
        // But it is still here, just in case we want to enable some additional functionality.
        bytes reservedDynamic;
    }

    function proveL2MessageInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function serializeL2Transaction(
        uint256 _txId,
        uint256 _l2Value,
        address _sender,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) external pure returns (L2CanonicalTransaction memory);

    function requestL2Transaction(
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) external payable returns (bytes32 canonicalTxHash);

    function l2TransactionBaseCost(
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _calldataLength
    ) external view returns (uint256);

    /// @notice New priority request event. Emitted when a request is placed into the priority queue
    /// @param txId Serial number of the priority operation
    /// @param txHash keccak256 hash of encoded transaction representation
    /// @param expirationTimestamp Timestamp up to which priority request should be processed
    /// @param transaction The whole transaction structure that is requested to be executed on L2
    /// @param factoryDeps An array of bytecodes that were shown in the L1 public data. Will be marked as known bytecodes in L2
    event NewPriorityRequest(
        uint256 txId,
        bytes32 txHash,
        uint64 expirationTimestamp,
        L2CanonicalTransaction transaction,
        bytes[] factoryDeps
    );
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "../../common/libraries/UncheckedMath.sol";

/// @author Matter Labs
library Merkle {
    using UncheckedMath for uint256;

    /// @dev Calculate Merkle root by the provided Merkle proof.
    /// NOTE: When using this function, check that the _path length is equal to the tree height to prevent shorter/longer paths attack
    /// @param _path Merkle path from the leaf to the root
    /// @param _index Leaf index in the tree
    /// @param _itemHash Hash of leaf content
    /// @return The Merkle root
    function calculateRoot(
        bytes32[] calldata _path,
        uint256 _index,
        bytes32 _itemHash
    ) internal pure returns (bytes32) {
        uint256 pathLength = _path.length;
        require(pathLength > 0, "xc");
        require(pathLength < 256, "bt");
        require(_index < (1 << pathLength), "pz");

        bytes32 currentHash = _itemHash;
        for (uint256 i; i < pathLength; i = i.uncheckedInc()) {
            currentHash = (_index % 2 == 0)
                ? _efficientHash(currentHash, _path[i])
                : _efficientHash(_path[i], currentHash);
            _index /= 2;
        }

        return currentHash;
    }

    /// @dev Keccak hash of the concatenation of two 32-byte words
    function _efficientHash(bytes32 _lhs, bytes32 _rhs) private pure returns (bytes32 result) {
        assembly {
            mstore(0x00, _lhs)
            mstore(0x20, _rhs)
            result := keccak256(0x00, 0x40)
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



library PairingsBn254 {
    uint256 constant q_mod = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint256 constant r_mod = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant bn254_b_coeff = 3;

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    struct Fr {
        uint256 value;
    }

    function new_fr(uint256 fr) internal pure returns (Fr memory) {
        require(fr < r_mod);
        return Fr({value: fr});
    }

    function copy(Fr memory self) internal pure returns (Fr memory n) {
        n.value = self.value;
    }

    function assign(Fr memory self, Fr memory other) internal pure {
        self.value = other.value;
    }

    function inverse(Fr memory fr) internal view returns (Fr memory) {
        require(fr.value != 0);
        return pow(fr, r_mod - 2);
    }

    function add_assign(Fr memory self, Fr memory other) internal pure {
        self.value = addmod(self.value, other.value, r_mod);
    }

    function sub_assign(Fr memory self, Fr memory other) internal pure {
        self.value = addmod(self.value, r_mod - other.value, r_mod);
    }

    function mul_assign(Fr memory self, Fr memory other) internal pure {
        self.value = mulmod(self.value, other.value, r_mod);
    }

    function pow(Fr memory self, uint256 power) internal view returns (Fr memory) {
        uint256[6] memory input = [32, 32, 32, self.value, power, r_mod];
        uint256[1] memory result;
        bool success;
        assembly {
            success := staticcall(gas(), 0x05, input, 0xc0, result, 0x20)
        }
        require(success);
        return Fr({value: result[0]});
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    function new_g1(uint256 x, uint256 y) internal pure returns (G1Point memory) {
        return G1Point(x, y);
    }

    // function new_g1_checked(uint256 x, uint256 y) internal pure returns (G1Point memory) {
    function new_g1_checked(uint256 x, uint256 y) internal pure returns (G1Point memory) {
        if (x == 0 && y == 0) {
            // point of infinity is (0,0)
            return G1Point(x, y);
        }

        // check encoding
        require(x < q_mod, "x axis isn't valid");
        require(y < q_mod, "y axis isn't valid");
        // check on curve
        uint256 lhs = mulmod(y, y, q_mod); // y^2

        uint256 rhs = mulmod(x, x, q_mod); // x^2
        rhs = mulmod(rhs, x, q_mod); // x^3
        rhs = addmod(rhs, bn254_b_coeff, q_mod); // x^3 + b
        require(lhs == rhs, "is not on curve");

        return G1Point(x, y);
    }

    function new_g2(uint256[2] memory x, uint256[2] memory y) internal pure returns (G2Point memory) {
        return G2Point(x, y);
    }

    function copy_g1(G1Point memory self) internal pure returns (G1Point memory result) {
        result.X = self.X;
        result.Y = self.Y;
    }

    function P2() internal pure returns (G2Point memory) {
        // for some reason ethereum expects to have c1*v + c0 form

        return
            G2Point(
                [
                    0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2,
                    0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed
                ],
                [
                    0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b,
                    0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa
                ]
            );
    }

    function negate(G1Point memory self) internal pure {
        // The prime q in the base field F_q for G1
        if (self.Y == 0) {
            require(self.X == 0);
            return;
        }

        self.Y = q_mod - self.Y;
    }

    function point_add(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        point_add_into_dest(p1, p2, r);
        return r;
    }

    function point_add_assign(G1Point memory p1, G1Point memory p2) internal view {
        point_add_into_dest(p1, p2, p1);
    }

    function point_add_into_dest(
        G1Point memory p1,
        G1Point memory p2,
        G1Point memory dest
    ) internal view {
        if (p2.X == 0 && p2.Y == 0) {
            // we add zero, nothing happens
            dest.X = p1.X;
            dest.Y = p1.Y;
            return;
        } else if (p1.X == 0 && p1.Y == 0) {
            // we add into zero, and we add non-zero point
            dest.X = p2.X;
            dest.Y = p2.Y;
            return;
        } else {
            uint256[4] memory input;

            input[0] = p1.X;
            input[1] = p1.Y;
            input[2] = p2.X;
            input[3] = p2.Y;

            bool success;
            assembly {
                success := staticcall(gas(), 6, input, 0x80, dest, 0x40)
            }
            require(success);
        }
    }

    function point_sub_assign(G1Point memory p1, G1Point memory p2) internal view {
        point_sub_into_dest(p1, p2, p1);
    }

    function point_sub_into_dest(
        G1Point memory p1,
        G1Point memory p2,
        G1Point memory dest
    ) internal view {
        if (p2.X == 0 && p2.Y == 0) {
            // we subtracted zero, nothing happens
            dest.X = p1.X;
            dest.Y = p1.Y;
            return;
        } else if (p1.X == 0 && p1.Y == 0) {
            // we subtract from zero, and we subtract non-zero point
            dest.X = p2.X;
            dest.Y = q_mod - p2.Y;
            return;
        } else {
            uint256[4] memory input;

            input[0] = p1.X;
            input[1] = p1.Y;
            input[2] = p2.X;
            input[3] = q_mod - p2.Y;

            bool success = false;
            assembly {
                success := staticcall(gas(), 6, input, 0x80, dest, 0x40)
            }
            require(success);
        }
    }

    function point_mul(G1Point memory p, Fr memory s) internal view returns (G1Point memory r) {
        // https://eips.ethereum.org/EIPS/eip-197
        // Elliptic curve points are encoded as a Jacobian pair (X, Y) where the point at infinity is encoded as (0, 0)
        // TODO
        if (p.X == 0 && p.Y == 1) {
            p.Y = 0;
        }
        point_mul_into_dest(p, s, r);
        return r;
    }

    function point_mul_assign(G1Point memory p, Fr memory s) internal view {
        point_mul_into_dest(p, s, p);
    }

    function point_mul_into_dest(
        G1Point memory p,
        Fr memory s,
        G1Point memory dest
    ) internal view {
        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s.value;
        bool success;
        assembly {
            success := staticcall(gas(), 7, input, 0x60, dest, 0x40)
        }
        require(success);
    }

    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint256 elements = p1.length;
        uint256 inputSize = elements * 6;
        uint256[] memory input = new uint256[](inputSize);
        for (uint256 i = 0; i < elements; ) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
            unchecked {
                ++i;
            }
        }
        uint256[1] memory out;
        bool success;
        assembly {
            success := staticcall(gas(), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        }
        require(success);
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



/// @notice The structure that contains meta information of the L2 transaction that was requested from L1
/// @dev The weird size of fields was selected specifically to minimize the structure storage size
/// @param canonicalTxHash Hashed L2 transaction data that is needed to process it
/// @param expirationTimestamp Expiration timestamp for this request (must be satisfied before)
/// @param layer2Tip Additional payment to the validator as an incentive to perform the operation
struct PriorityOperation {
    bytes32 canonicalTxHash;
    uint64 expirationTimestamp;
    uint192 layer2Tip;
}

/// @author Matter Labs
/// @dev The library provides the API to interact with the priority queue container
/// @dev Order of processing operations from queue - FIFO (Fist in - first out)
library PriorityQueue {
    using PriorityQueue for Queue;

    /// @notice Container that stores priority operations
    /// @param data The inner mapping that saves priority operation by its index
    /// @param head The pointer to the first unprocessed priority operation, equal to the tail if the queue is empty
    /// @param tail The pointer to the free slot
    struct Queue {
        mapping(uint256 => PriorityOperation) data;
        uint256 tail;
        uint256 head;
    }

    /// @notice Returns zero if and only if no operations were processed from the queue
    /// @return Index of the oldest priority operation that wasn't processed yet
    function getFirstUnprocessedPriorityTx(Queue storage _queue) internal view returns (uint256) {
        return _queue.head;
    }

    /// @return The total number of priority operations that were added to the priority queue, including all processed ones
    function getTotalPriorityTxs(Queue storage _queue) internal view returns (uint256) {
        return _queue.tail;
    }

    /// @return The total number of unprocessed priority operations in a priority queue
    function getSize(Queue storage _queue) internal view returns (uint256) {
        return uint256(_queue.tail - _queue.head);
    }

    /// @return Whether the priority queue contains no operations
    function isEmpty(Queue storage _queue) internal view returns (bool) {
        return _queue.tail == _queue.head;
    }

    /// @notice Add the priority operation to the end of the priority queue
    function pushBack(Queue storage _queue, PriorityOperation memory _operation) internal {
        // Save value into the stack to avoid double reading from the storage
        uint256 tail = _queue.tail;

        _queue.data[tail] = _operation;
        _queue.tail = tail + 1;
    }

    /// @return The first unprocessed priority operation from the queue
    function front(Queue storage _queue) internal view returns (PriorityOperation memory) {
        require(!_queue.isEmpty(), "D"); // priority queue is empty

        return _queue.data[_queue.head];
    }

    /// @notice Remove the first unprocessed priority operation from the queue
    /// @return priorityOperation that was popped from the priority queue
    function popFront(Queue storage _queue) internal returns (PriorityOperation memory priorityOperation) {
        require(!_queue.isEmpty(), "s"); // priority queue is empty

        // Save value into the stack to avoid double reading from the storage
        uint256 head = _queue.head;

        priorityOperation = _queue.data[head];
        delete _queue.data[head];
        _queue.head = head + 1;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./PairingsBn254.sol";

library TranscriptLib {
    // flip                    0xe000000000000000000000000000000000000000000000000000000000000000;
    uint256 constant FR_MASK = 0x1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    uint32 constant DST_0 = 0;
    uint32 constant DST_1 = 1;
    uint32 constant DST_CHALLENGE = 2;

    struct Transcript {
        bytes32 state_0;
        bytes32 state_1;
        uint32 challenge_counter;
    }

    function new_transcript() internal pure returns (Transcript memory t) {
        t.state_0 = bytes32(0);
        t.state_1 = bytes32(0);
        t.challenge_counter = 0;
    }

    function update_with_u256(Transcript memory self, uint256 value) internal pure {
        bytes32 old_state_0 = self.state_0;
        self.state_0 = keccak256(abi.encodePacked(DST_0, old_state_0, self.state_1, value));
        self.state_1 = keccak256(abi.encodePacked(DST_1, old_state_0, self.state_1, value));
    }

    function update_with_fr(Transcript memory self, PairingsBn254.Fr memory value) internal pure {
        update_with_u256(self, value.value);
    }

    function update_with_g1(Transcript memory self, PairingsBn254.G1Point memory p) internal pure {
        update_with_u256(self, p.X);
        update_with_u256(self, p.Y);
    }

    function get_challenge(Transcript memory self) internal pure returns (PairingsBn254.Fr memory challenge) {
        bytes32 query = keccak256(abi.encodePacked(DST_CHALLENGE, self.state_0, self.state_1, self.challenge_counter));
        self.challenge_counter += 1;
        challenge = PairingsBn254.Fr({value: uint256(query) & FR_MASK});
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./libraries/PairingsBn254.sol";
import "./libraries/TranscriptLib.sol";
import "../common/libraries/UncheckedMath.sol";

uint256 constant STATE_WIDTH = 4;
uint256 constant NUM_G2_ELS = 2;

struct VerificationKey {
    uint256 domain_size;
    uint256 num_inputs;
    PairingsBn254.Fr omega;
    PairingsBn254.G1Point[2] gate_selectors_commitments;
    PairingsBn254.G1Point[8] gate_setup_commitments;
    PairingsBn254.G1Point[STATE_WIDTH] permutation_commitments;
    PairingsBn254.G1Point lookup_selector_commitment;
    PairingsBn254.G1Point[4] lookup_tables_commitments;
    PairingsBn254.G1Point lookup_table_type_commitment;
    PairingsBn254.Fr[STATE_WIDTH - 1] non_residues;
    PairingsBn254.G2Point[NUM_G2_ELS] g2_elements;
}

contract Plonk4VerifierWithAccessToDNext {
    using PairingsBn254 for PairingsBn254.G1Point;
    using PairingsBn254 for PairingsBn254.G2Point;
    using PairingsBn254 for PairingsBn254.Fr;

    using TranscriptLib for TranscriptLib.Transcript;

    using UncheckedMath for uint256;

    struct Proof {
        uint256[] input_values;
        // commitments
        PairingsBn254.G1Point[STATE_WIDTH] state_polys_commitments;
        PairingsBn254.G1Point copy_permutation_grand_product_commitment;
        PairingsBn254.G1Point[STATE_WIDTH] quotient_poly_parts_commitments;
        // openings
        PairingsBn254.Fr[STATE_WIDTH] state_polys_openings_at_z;
        PairingsBn254.Fr[1] state_polys_openings_at_z_omega; // TODO: not use array while there is only D_next
        PairingsBn254.Fr[1] gate_selectors_openings_at_z;
        PairingsBn254.Fr[STATE_WIDTH - 1] copy_permutation_polys_openings_at_z;
        PairingsBn254.Fr copy_permutation_grand_product_opening_at_z_omega;
        PairingsBn254.Fr quotient_poly_opening_at_z;
        PairingsBn254.Fr linearization_poly_opening_at_z;
        // lookup commitments
        PairingsBn254.G1Point lookup_s_poly_commitment;
        PairingsBn254.G1Point lookup_grand_product_commitment;
        // lookup openings
        PairingsBn254.Fr lookup_s_poly_opening_at_z_omega;
        PairingsBn254.Fr lookup_grand_product_opening_at_z_omega;
        PairingsBn254.Fr lookup_t_poly_opening_at_z;
        PairingsBn254.Fr lookup_t_poly_opening_at_z_omega;
        PairingsBn254.Fr lookup_selector_poly_opening_at_z;
        PairingsBn254.Fr lookup_table_type_poly_opening_at_z;
        PairingsBn254.G1Point opening_proof_at_z;
        PairingsBn254.G1Point opening_proof_at_z_omega;
    }

    struct PartialVerifierState {
        PairingsBn254.Fr zero;
        PairingsBn254.Fr alpha;
        PairingsBn254.Fr beta;
        PairingsBn254.Fr gamma;
        PairingsBn254.Fr[9] alpha_values;
        PairingsBn254.Fr eta;
        PairingsBn254.Fr beta_lookup;
        PairingsBn254.Fr gamma_lookup;
        PairingsBn254.Fr beta_plus_one;
        PairingsBn254.Fr beta_gamma;
        PairingsBn254.Fr v;
        PairingsBn254.Fr u;
        PairingsBn254.Fr z;
        PairingsBn254.Fr z_omega;
        PairingsBn254.Fr z_minus_last_omega;
        PairingsBn254.Fr l_0_at_z;
        PairingsBn254.Fr l_n_minus_one_at_z;
        PairingsBn254.Fr t;
        PairingsBn254.G1Point tp;
    }

    function evaluate_l0_at_point(uint256 domain_size, PairingsBn254.Fr memory at)
        internal
        view
        returns (PairingsBn254.Fr memory num)
    {
        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);

        PairingsBn254.Fr memory size_fe = PairingsBn254.new_fr(domain_size);
        PairingsBn254.Fr memory den = at.copy();
        den.sub_assign(one);
        den.mul_assign(size_fe);

        den = den.inverse();

        num = at.pow(domain_size);
        num.sub_assign(one);
        num.mul_assign(den);
    }

    function evaluate_lagrange_poly_out_of_domain(
        uint256 poly_num,
        uint256 domain_size,
        PairingsBn254.Fr memory omega,
        PairingsBn254.Fr memory at
    ) internal view returns (PairingsBn254.Fr memory res) {
        // (omega^i / N) / (X - omega^i) * (X^N - 1)
        require(poly_num < domain_size);
        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);
        PairingsBn254.Fr memory omega_power = omega.pow(poly_num);
        res = at.pow(domain_size);
        res.sub_assign(one);
        require(res.value != 0); // Vanishing polynomial can not be zero at point `at`
        res.mul_assign(omega_power);

        PairingsBn254.Fr memory den = PairingsBn254.copy(at);
        den.sub_assign(omega_power);
        den.mul_assign(PairingsBn254.new_fr(domain_size));

        den = den.inverse();

        res.mul_assign(den);
    }

    function evaluate_vanishing(uint256 domain_size, PairingsBn254.Fr memory at)
        internal
        view
        returns (PairingsBn254.Fr memory res)
    {
        res = at.pow(domain_size);
        res.sub_assign(PairingsBn254.new_fr(1));
    }

    function initialize_transcript(Proof memory proof, VerificationKey memory vk)
        internal
        pure
        returns (PartialVerifierState memory state)
    {
        TranscriptLib.Transcript memory transcript = TranscriptLib.new_transcript();

        for (uint256 i = 0; i < vk.num_inputs; i = i.uncheckedInc()) {
            transcript.update_with_u256(proof.input_values[i]);
        }

        for (uint256 i = 0; i < STATE_WIDTH; i = i.uncheckedInc()) {
            transcript.update_with_g1(proof.state_polys_commitments[i]);
        }

        state.eta = transcript.get_challenge();
        transcript.update_with_g1(proof.lookup_s_poly_commitment);

        state.beta = transcript.get_challenge();
        state.gamma = transcript.get_challenge();

        transcript.update_with_g1(proof.copy_permutation_grand_product_commitment);
        state.beta_lookup = transcript.get_challenge();
        state.gamma_lookup = transcript.get_challenge();
        transcript.update_with_g1(proof.lookup_grand_product_commitment);
        state.alpha = transcript.get_challenge();

        for (uint256 i = 0; i < proof.quotient_poly_parts_commitments.length; i = i.uncheckedInc()) {
            transcript.update_with_g1(proof.quotient_poly_parts_commitments[i]);
        }
        state.z = transcript.get_challenge();

        transcript.update_with_fr(proof.quotient_poly_opening_at_z);

        for (uint256 i = 0; i < proof.state_polys_openings_at_z.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.state_polys_openings_at_z[i]);
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z_omega.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.state_polys_openings_at_z_omega[i]);
        }
        for (uint256 i = 0; i < proof.gate_selectors_openings_at_z.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.gate_selectors_openings_at_z[i]);
        }
        for (uint256 i = 0; i < proof.copy_permutation_polys_openings_at_z.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.copy_permutation_polys_openings_at_z[i]);
        }

        state.z_omega = state.z.copy();
        state.z_omega.mul_assign(vk.omega);

        transcript.update_with_fr(proof.copy_permutation_grand_product_opening_at_z_omega);

        transcript.update_with_fr(proof.lookup_t_poly_opening_at_z);
        transcript.update_with_fr(proof.lookup_selector_poly_opening_at_z);
        transcript.update_with_fr(proof.lookup_table_type_poly_opening_at_z);
        transcript.update_with_fr(proof.lookup_s_poly_opening_at_z_omega);
        transcript.update_with_fr(proof.lookup_grand_product_opening_at_z_omega);
        transcript.update_with_fr(proof.lookup_t_poly_opening_at_z_omega);
        transcript.update_with_fr(proof.linearization_poly_opening_at_z);

        state.v = transcript.get_challenge();

        transcript.update_with_g1(proof.opening_proof_at_z);
        transcript.update_with_g1(proof.opening_proof_at_z_omega);

        state.u = transcript.get_challenge();
    }

    // compute some powers of challenge alpha([alpha^1, .. alpha^8])
    function compute_powers_of_alpha(PartialVerifierState memory state) public pure {
        require(state.alpha.value != 0);
        state.alpha_values[0] = PairingsBn254.new_fr(1);
        state.alpha_values[1] = state.alpha.copy();
        PairingsBn254.Fr memory current_alpha = state.alpha.copy();
        for (uint256 i = 2; i < state.alpha_values.length; i = i.uncheckedInc()) {
            current_alpha.mul_assign(state.alpha);
            state.alpha_values[i] = current_alpha.copy();
        }
    }

    function verify(Proof memory proof, VerificationKey memory vk) internal view returns (bool) {
        // we initialize all challenges beforehand, we can draw each challenge in its own place
        PartialVerifierState memory state = initialize_transcript(proof, vk);
        if (verify_quotient_evaluation(vk, proof, state) == false) {
            return false;
        }
        require(proof.state_polys_openings_at_z_omega.length == 1); // TODO

        PairingsBn254.G1Point memory quotient_result = proof.quotient_poly_parts_commitments[0].copy_g1();
        {
            // block scope
            PairingsBn254.Fr memory z_in_domain_size = state.z.pow(vk.domain_size);
            PairingsBn254.Fr memory current_z = z_in_domain_size.copy();
            PairingsBn254.G1Point memory tp;
            // start from i =1
            for (uint256 i = 1; i < proof.quotient_poly_parts_commitments.length; i = i.uncheckedInc()) {
                tp = proof.quotient_poly_parts_commitments[i].copy_g1();
                tp.point_mul_assign(current_z);
                quotient_result.point_add_assign(tp);

                current_z.mul_assign(z_in_domain_size);
            }
        }

        Queries memory queries = prepare_queries(vk, proof, state);
        queries.commitments_at_z[0] = quotient_result;
        queries.values_at_z[0] = proof.quotient_poly_opening_at_z;
        queries.commitments_at_z[1] = aggregated_linearization_commitment(vk, proof, state);
        queries.values_at_z[1] = proof.linearization_poly_opening_at_z;

        require(queries.commitments_at_z.length == queries.values_at_z.length);

        PairingsBn254.G1Point memory aggregated_commitment_at_z = queries.commitments_at_z[0];

        PairingsBn254.Fr memory aggregated_opening_at_z = queries.values_at_z[0];
        PairingsBn254.Fr memory aggregation_challenge = PairingsBn254.new_fr(1);
        PairingsBn254.G1Point memory scaled;
        for (uint256 i = 1; i < queries.commitments_at_z.length; i = i.uncheckedInc()) {
            aggregation_challenge.mul_assign(state.v);
            scaled = queries.commitments_at_z[i].point_mul(aggregation_challenge);
            aggregated_commitment_at_z.point_add_assign(scaled);

            state.t = queries.values_at_z[i];
            state.t.mul_assign(aggregation_challenge);
            aggregated_opening_at_z.add_assign(state.t);
        }

        aggregation_challenge.mul_assign(state.v);

        PairingsBn254.G1Point memory aggregated_commitment_at_z_omega = queries.commitments_at_z_omega[0].point_mul(
            aggregation_challenge
        );
        PairingsBn254.Fr memory aggregated_opening_at_z_omega = queries.values_at_z_omega[0];
        aggregated_opening_at_z_omega.mul_assign(aggregation_challenge);
        for (uint256 i = 1; i < queries.commitments_at_z_omega.length; i = i.uncheckedInc()) {
            aggregation_challenge.mul_assign(state.v);

            scaled = queries.commitments_at_z_omega[i].point_mul(aggregation_challenge);
            aggregated_commitment_at_z_omega.point_add_assign(scaled);

            state.t = queries.values_at_z_omega[i];
            state.t.mul_assign(aggregation_challenge);
            aggregated_opening_at_z_omega.add_assign(state.t);
        }

        return
            final_pairing(
                vk.g2_elements,
                proof,
                state,
                aggregated_commitment_at_z,
                aggregated_commitment_at_z_omega,
                aggregated_opening_at_z,
                aggregated_opening_at_z_omega
            );
    }

    function verify_quotient_evaluation(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) internal view returns (bool) {
        uint256[] memory lagrange_poly_numbers = new uint256[](vk.num_inputs);
        for (uint256 i = 0; i < lagrange_poly_numbers.length; i = i.uncheckedInc()) {
            lagrange_poly_numbers[i] = i;
        }
        // require(vk.num_inputs > 0); // TODO

        PairingsBn254.Fr memory inputs_term = PairingsBn254.new_fr(0);
        for (uint256 i = 0; i < vk.num_inputs; i = i.uncheckedInc()) {
            // TODO we may use batched lagrange compputation
            state.t = evaluate_lagrange_poly_out_of_domain(i, vk.domain_size, vk.omega, state.z);
            state.t.mul_assign(PairingsBn254.new_fr(proof.input_values[i]));
            inputs_term.add_assign(state.t);
        }
        inputs_term.mul_assign(proof.gate_selectors_openings_at_z[0]);
        PairingsBn254.Fr memory result = proof.linearization_poly_opening_at_z.copy();
        result.add_assign(inputs_term);

        // compute powers of alpha
        compute_powers_of_alpha(state);
        PairingsBn254.Fr memory factor = state.alpha_values[4].copy();
        factor.mul_assign(proof.copy_permutation_grand_product_opening_at_z_omega);

        // - alpha_0 * (a + perm(z) * beta + gamma)*()*(d + gamma) * z(z*omega)
        require(proof.copy_permutation_polys_openings_at_z.length == STATE_WIDTH - 1);
        PairingsBn254.Fr memory t; // TMP;
        for (uint256 i = 0; i < proof.copy_permutation_polys_openings_at_z.length; i = i.uncheckedInc()) {
            t = proof.copy_permutation_polys_openings_at_z[i].copy();
            t.mul_assign(state.beta);
            t.add_assign(proof.state_polys_openings_at_z[i]);
            t.add_assign(state.gamma);

            factor.mul_assign(t);
        }

        t = proof.state_polys_openings_at_z[3].copy();
        t.add_assign(state.gamma);
        factor.mul_assign(t);
        result.sub_assign(factor);

        // - L_0(z) * alpha_1
        PairingsBn254.Fr memory l_0_at_z = evaluate_l0_at_point(vk.domain_size, state.z);
        l_0_at_z.mul_assign(state.alpha_values[4 + 1]);
        result.sub_assign(l_0_at_z);

        PairingsBn254.Fr memory lookup_quotient_contrib = lookup_quotient_contribution(vk, proof, state);
        result.add_assign(lookup_quotient_contrib);

        PairingsBn254.Fr memory lhs = proof.quotient_poly_opening_at_z.copy();
        lhs.mul_assign(evaluate_vanishing(vk.domain_size, state.z));
        return lhs.value == result.value;
    }

    function lookup_quotient_contribution(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) internal view returns (PairingsBn254.Fr memory result) {
        PairingsBn254.Fr memory t;

        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);
        state.beta_plus_one = state.beta_lookup.copy();
        state.beta_plus_one.add_assign(one);
        state.beta_gamma = state.beta_plus_one.copy();
        state.beta_gamma.mul_assign(state.gamma_lookup);

        // (s'*beta + gamma)*(zw')*alpha
        t = proof.lookup_s_poly_opening_at_z_omega.copy();
        t.mul_assign(state.beta_lookup);
        t.add_assign(state.beta_gamma);
        t.mul_assign(proof.lookup_grand_product_opening_at_z_omega);
        t.mul_assign(state.alpha_values[6]);

        // (z - omega^{n-1}) for this part
        PairingsBn254.Fr memory last_omega = vk.omega.pow(vk.domain_size - 1);
        state.z_minus_last_omega = state.z.copy();
        state.z_minus_last_omega.sub_assign(last_omega);
        t.mul_assign(state.z_minus_last_omega);
        result.add_assign(t);

        // - alpha_1 * L_{0}(z)
        state.l_0_at_z = evaluate_lagrange_poly_out_of_domain(0, vk.domain_size, vk.omega, state.z);
        t = state.l_0_at_z.copy();
        t.mul_assign(state.alpha_values[6 + 1]);
        result.sub_assign(t);

        // - alpha_2 * beta_gamma_powered L_{n-1}(z)
        PairingsBn254.Fr memory beta_gamma_powered = state.beta_gamma.pow(vk.domain_size - 1);
        state.l_n_minus_one_at_z = evaluate_lagrange_poly_out_of_domain(
            vk.domain_size - 1,
            vk.domain_size,
            vk.omega,
            state.z
        );
        t = state.l_n_minus_one_at_z.copy();
        t.mul_assign(beta_gamma_powered);
        t.mul_assign(state.alpha_values[6 + 2]);

        result.sub_assign(t);
    }

    function aggregated_linearization_commitment(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) internal view returns (PairingsBn254.G1Point memory result) {
        // qMain*(Q_a * A + Q_b * B + Q_c * C + Q_d * D + Q_m * A*B + Q_const + Q_dNext * D_next)
        result = PairingsBn254.new_g1(0, 0);
        // Q_a * A
        PairingsBn254.G1Point memory scaled = vk.gate_setup_commitments[0].point_mul(
            proof.state_polys_openings_at_z[0]
        );
        result.point_add_assign(scaled);
        // Q_b * B
        scaled = vk.gate_setup_commitments[1].point_mul(proof.state_polys_openings_at_z[1]);
        result.point_add_assign(scaled);
        // Q_c * C
        scaled = vk.gate_setup_commitments[2].point_mul(proof.state_polys_openings_at_z[2]);
        result.point_add_assign(scaled);
        // Q_d * D
        scaled = vk.gate_setup_commitments[3].point_mul(proof.state_polys_openings_at_z[3]);
        result.point_add_assign(scaled);
        // Q_m* A*B or Q_ab*A*B
        PairingsBn254.Fr memory t = proof.state_polys_openings_at_z[0].copy();
        t.mul_assign(proof.state_polys_openings_at_z[1]);
        scaled = vk.gate_setup_commitments[4].point_mul(t);
        result.point_add_assign(scaled);
        // Q_AC* A*C
        t = proof.state_polys_openings_at_z[0].copy();
        t.mul_assign(proof.state_polys_openings_at_z[2]);
        scaled = vk.gate_setup_commitments[5].point_mul(t);
        result.point_add_assign(scaled);
        // Q_const
        result.point_add_assign(vk.gate_setup_commitments[6]);
        // Q_dNext * D_next
        scaled = vk.gate_setup_commitments[7].point_mul(proof.state_polys_openings_at_z_omega[0]);
        result.point_add_assign(scaled);
        result.point_mul_assign(proof.gate_selectors_openings_at_z[0]);

        PairingsBn254.G1Point
            memory rescue_custom_gate_linearization_contrib = rescue_custom_gate_linearization_contribution(
                vk,
                proof,
                state
            );
        result.point_add_assign(rescue_custom_gate_linearization_contrib);
        require(vk.non_residues.length == STATE_WIDTH - 1);

        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);
        PairingsBn254.Fr memory factor = state.alpha_values[4].copy();
        for (uint256 i = 0; i < proof.state_polys_openings_at_z.length; ) {
            t = state.z.copy();
            if (i == 0) {
                t.mul_assign(one);
            } else {
                t.mul_assign(vk.non_residues[i - 1]); // TODO add one into non-residues during codegen?
            }
            t.mul_assign(state.beta);
            t.add_assign(state.gamma);
            t.add_assign(proof.state_polys_openings_at_z[i]);

            factor.mul_assign(t);
            unchecked {
                ++i;
            }
        }

        scaled = proof.copy_permutation_grand_product_commitment.point_mul(factor);
        result.point_add_assign(scaled);

        // - (a(z) + beta*perm_a + gamma)*()*()*z(z*omega) * beta * perm_d(X)
        factor = state.alpha_values[4].copy();
        factor.mul_assign(state.beta);
        factor.mul_assign(proof.copy_permutation_grand_product_opening_at_z_omega);
        for (uint256 i = 0; i < STATE_WIDTH - 1; i = i.uncheckedInc()) {
            t = proof.copy_permutation_polys_openings_at_z[i].copy();
            t.mul_assign(state.beta);
            t.add_assign(state.gamma);
            t.add_assign(proof.state_polys_openings_at_z[i]);

            factor.mul_assign(t);
        }
        scaled = vk.permutation_commitments[3].point_mul(factor);
        result.point_sub_assign(scaled);

        // + L_0(z) * Z(x)
        // TODO
        state.l_0_at_z = evaluate_lagrange_poly_out_of_domain(0, vk.domain_size, vk.omega, state.z);
        require(state.l_0_at_z.value != 0);
        factor = state.l_0_at_z.copy();
        factor.mul_assign(state.alpha_values[4 + 1]);
        scaled = proof.copy_permutation_grand_product_commitment.point_mul(factor);
        result.point_add_assign(scaled);

        PairingsBn254.G1Point memory lookup_linearization_contrib = lookup_linearization_contribution(proof, state);
        result.point_add_assign(lookup_linearization_contrib);
    }

    function rescue_custom_gate_linearization_contribution(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) public view returns (PairingsBn254.G1Point memory result) {
        PairingsBn254.Fr memory t;
        PairingsBn254.Fr memory intermediate_result;

        // a^2 - b = 0
        t = proof.state_polys_openings_at_z[0].copy();
        t.mul_assign(t);
        t.sub_assign(proof.state_polys_openings_at_z[1]);
        // t.mul_assign(challenge1);
        t.mul_assign(state.alpha_values[1]);
        intermediate_result.add_assign(t);

        // b^2 - c = 0
        t = proof.state_polys_openings_at_z[1].copy();
        t.mul_assign(t);
        t.sub_assign(proof.state_polys_openings_at_z[2]);
        t.mul_assign(state.alpha_values[1 + 1]);
        intermediate_result.add_assign(t);

        // c*a - d = 0;
        t = proof.state_polys_openings_at_z[2].copy();
        t.mul_assign(proof.state_polys_openings_at_z[0]);
        t.sub_assign(proof.state_polys_openings_at_z[3]);
        t.mul_assign(state.alpha_values[1 + 2]);
        intermediate_result.add_assign(t);

        result = vk.gate_selectors_commitments[1].point_mul(intermediate_result);
    }

    function lookup_linearization_contribution(Proof memory proof, PartialVerifierState memory state)
        internal
        view
        returns (PairingsBn254.G1Point memory result)
    {
        PairingsBn254.Fr memory zero = PairingsBn254.new_fr(0);

        PairingsBn254.Fr memory t;
        PairingsBn254.Fr memory factor;
        // s(x) from the Z(x*omega)*(\gamma*(1 + \beta) + s(x) + \beta * s(x*omega)))
        factor = proof.lookup_grand_product_opening_at_z_omega.copy();
        factor.mul_assign(state.alpha_values[6]);
        factor.mul_assign(state.z_minus_last_omega);

        PairingsBn254.G1Point memory scaled = proof.lookup_s_poly_commitment.point_mul(factor);
        result.point_add_assign(scaled);

        // Z(x) from - alpha_0 * Z(x) * (\beta + 1) * (\gamma + f(x)) * (\gamma(1 + \beta) + t(x) + \beta * t(x*omega))
        // + alpha_1 * Z(x) * L_{0}(z) + alpha_2 * Z(x) * L_{n-1}(z)

        // accumulate coefficient
        factor = proof.lookup_t_poly_opening_at_z_omega.copy();
        factor.mul_assign(state.beta_lookup);
        factor.add_assign(proof.lookup_t_poly_opening_at_z);
        factor.add_assign(state.beta_gamma);

        // (\gamma + f(x))
        PairingsBn254.Fr memory f_reconstructed;
        PairingsBn254.Fr memory current = PairingsBn254.new_fr(1);
        PairingsBn254.Fr memory tmp0;
        for (uint256 i = 0; i < STATE_WIDTH - 1; i = i.uncheckedInc()) {
            tmp0 = proof.state_polys_openings_at_z[i].copy();
            tmp0.mul_assign(current);
            f_reconstructed.add_assign(tmp0);

            current.mul_assign(state.eta);
        }

        // add type of table
        t = proof.lookup_table_type_poly_opening_at_z.copy();
        t.mul_assign(current);
        f_reconstructed.add_assign(t);

        f_reconstructed.mul_assign(proof.lookup_selector_poly_opening_at_z);
        f_reconstructed.add_assign(state.gamma_lookup);

        // end of (\gamma + f(x)) part
        factor.mul_assign(f_reconstructed);
        factor.mul_assign(state.beta_plus_one);
        t = zero.copy();
        t.sub_assign(factor);
        factor = t;
        factor.mul_assign(state.alpha_values[6]);

        // Multiply by (z - omega^{n-1})
        factor.mul_assign(state.z_minus_last_omega);

        // L_{0}(z) in front of Z(x)
        t = state.l_0_at_z.copy();
        t.mul_assign(state.alpha_values[6 + 1]);
        factor.add_assign(t);

        // L_{n-1}(z) in front of Z(x)
        t = state.l_n_minus_one_at_z.copy();
        t.mul_assign(state.alpha_values[6 + 2]);
        factor.add_assign(t);

        scaled = proof.lookup_grand_product_commitment.point_mul(factor);
        result.point_add_assign(scaled);
    }

    struct Queries {
        PairingsBn254.G1Point[13] commitments_at_z;
        PairingsBn254.Fr[13] values_at_z;
        PairingsBn254.G1Point[6] commitments_at_z_omega;
        PairingsBn254.Fr[6] values_at_z_omega;
    }

    function prepare_queries(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) public view returns (Queries memory queries) {
        // we set first two items in calee side so start idx from 2
        uint256 idx = 2;
        for (uint256 i = 0; i < STATE_WIDTH; i = i.uncheckedInc()) {
            queries.commitments_at_z[idx] = proof.state_polys_commitments[i];
            queries.values_at_z[idx] = proof.state_polys_openings_at_z[i];
            idx = idx.uncheckedInc();
        }
        require(proof.gate_selectors_openings_at_z.length == 1);
        queries.commitments_at_z[idx] = vk.gate_selectors_commitments[0];
        queries.values_at_z[idx] = proof.gate_selectors_openings_at_z[0];
        idx = idx.uncheckedInc();
        for (uint256 i = 0; i < STATE_WIDTH - 1; i = i.uncheckedInc()) {
            queries.commitments_at_z[idx] = vk.permutation_commitments[i];
            queries.values_at_z[idx] = proof.copy_permutation_polys_openings_at_z[i];
            idx = idx.uncheckedInc();
        }

        queries.commitments_at_z_omega[0] = proof.copy_permutation_grand_product_commitment;
        queries.commitments_at_z_omega[1] = proof.state_polys_commitments[STATE_WIDTH - 1];

        queries.values_at_z_omega[0] = proof.copy_permutation_grand_product_opening_at_z_omega;
        queries.values_at_z_omega[1] = proof.state_polys_openings_at_z_omega[0];

        PairingsBn254.G1Point memory lookup_t_poly_commitment_aggregated = vk.lookup_tables_commitments[0];
        PairingsBn254.Fr memory current_eta = state.eta.copy();
        for (uint256 i = 1; i < vk.lookup_tables_commitments.length; i = i.uncheckedInc()) {
            state.tp = vk.lookup_tables_commitments[i].point_mul(current_eta);
            lookup_t_poly_commitment_aggregated.point_add_assign(state.tp);

            current_eta.mul_assign(state.eta);
        }
        queries.commitments_at_z[idx] = lookup_t_poly_commitment_aggregated;
        queries.values_at_z[idx] = proof.lookup_t_poly_opening_at_z;
        idx = idx.uncheckedInc();
        queries.commitments_at_z[idx] = vk.lookup_selector_commitment;
        queries.values_at_z[idx] = proof.lookup_selector_poly_opening_at_z;
        idx = idx.uncheckedInc();
        queries.commitments_at_z[idx] = vk.lookup_table_type_commitment;
        queries.values_at_z[idx] = proof.lookup_table_type_poly_opening_at_z;
        queries.commitments_at_z_omega[2] = proof.lookup_s_poly_commitment;
        queries.values_at_z_omega[2] = proof.lookup_s_poly_opening_at_z_omega;
        queries.commitments_at_z_omega[3] = proof.lookup_grand_product_commitment;
        queries.values_at_z_omega[3] = proof.lookup_grand_product_opening_at_z_omega;
        queries.commitments_at_z_omega[4] = lookup_t_poly_commitment_aggregated;
        queries.values_at_z_omega[4] = proof.lookup_t_poly_opening_at_z_omega;
    }

    function final_pairing(
        // VerificationKey memory vk,
        PairingsBn254.G2Point[NUM_G2_ELS] memory g2_elements,
        Proof memory proof,
        PartialVerifierState memory state,
        PairingsBn254.G1Point memory aggregated_commitment_at_z,
        PairingsBn254.G1Point memory aggregated_commitment_at_z_omega,
        PairingsBn254.Fr memory aggregated_opening_at_z,
        PairingsBn254.Fr memory aggregated_opening_at_z_omega
    ) internal view returns (bool) {
        // q(x) = f(x) - f(z) / (x - z)
        // q(x) * (x-z)  = f(x) - f(z)

        // f(x)
        PairingsBn254.G1Point memory pair_with_generator = aggregated_commitment_at_z.copy_g1();
        aggregated_commitment_at_z_omega.point_mul_assign(state.u);
        pair_with_generator.point_add_assign(aggregated_commitment_at_z_omega);

        // - f(z)*g
        PairingsBn254.Fr memory aggregated_value = aggregated_opening_at_z_omega.copy();
        aggregated_value.mul_assign(state.u);
        aggregated_value.add_assign(aggregated_opening_at_z);
        PairingsBn254.G1Point memory tp = PairingsBn254.P1().point_mul(aggregated_value);
        pair_with_generator.point_sub_assign(tp);

        // +z * q(x)
        tp = proof.opening_proof_at_z.point_mul(state.z);
        PairingsBn254.Fr memory t = state.z_omega.copy();
        t.mul_assign(state.u);
        PairingsBn254.G1Point memory t1 = proof.opening_proof_at_z_omega.point_mul(t);
        tp.point_add_assign(t1);
        pair_with_generator.point_add_assign(tp);

        // rhs
        PairingsBn254.G1Point memory pair_with_x = proof.opening_proof_at_z_omega.point_mul(state.u);
        pair_with_x.point_add_assign(proof.opening_proof_at_z);
        pair_with_x.negate();
        // Pairing precompile expects points to be in a `i*x[1] + x[0]` form instead of `x[0] + i*x[1]`
        // so we handle it in code generation step
        PairingsBn254.G2Point memory first_g2 = g2_elements[0];
        PairingsBn254.G2Point memory second_g2 = g2_elements[1];
        PairingsBn254.G2Point memory gen2 = PairingsBn254.P2();

        return PairingsBn254.pairingProd2(pair_with_generator, first_g2, pair_with_x, second_g2);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./Verifier.sol";
import "../common/interfaces/IAllowList.sol";
import "./libraries/PriorityQueue.sol";

/// @notice Indicates whether an upgrade is initiated and if yes what type
/// @param None Upgrade is NOT initiated
/// @param Transparent Fully transparent upgrade is initiated, upgrade data is publicly known
/// @param Shadow Shadow upgrade is initiated, upgrade data is hidden
enum UpgradeState {
    None,
    Transparent,
    Shadow
}

/// @dev Logically separated part of the storage structure, which is responsible for everything related to proxy upgrades and diamond cuts
/// @param proposedUpgradeHash The hash of the current upgrade proposal, zero if there is no active proposal
/// @param state Indicates whether an upgrade is initiated and if yes what type
/// @param securityCouncil Address which has the permission to approve instant upgrades (expected to be a Gnosis multisig)
/// @param approvedBySecurityCouncil Indicates whether the security council has approved the upgrade
/// @param proposedUpgradeTimestamp The timestamp when the upgrade was proposed, zero if there are no active proposals
/// @param currentProposalId The serial number of proposed upgrades, increments when proposing a new one
struct UpgradeStorage {
    bytes32 proposedUpgradeHash;
    UpgradeState state;
    address securityCouncil;
    bool approvedBySecurityCouncil;
    uint40 proposedUpgradeTimestamp;
    uint40 currentProposalId;
}

/// @dev The log passed from L2
/// @param l2ShardId The shard identifier, 0 - rollup, 1 - porter. All other values are not used but are reserved for the future
/// @param isService A boolean flag that is part of the log along with `key`, `value`, and `sender` address.
/// This field is required formally but does not have any special meaning.
/// @param txNumberInBlock The L2 transaction number in a block, in which the log was sent
/// @param sender The L2 address which sent the log
/// @param key The 32 bytes of information that was sent in the log
/// @param value The 32 bytes of information that was sent in the log
// Both `key` and `value` are arbitrary 32-bytes selected by the log sender
struct L2Log {
    uint8 l2ShardId;
    bool isService;
    uint16 txNumberInBlock;
    address sender;
    bytes32 key;
    bytes32 value;
}

/// @dev An arbitrary length message passed from L2
/// @notice Under the hood it is `L2Log` sent from the special system L2 contract
/// @param txNumberInBlock The L2 transaction number in a block, in which the message was sent
/// @param sender The address of the L2 account from which the message was passed
/// @param data An arbitrary length message
struct L2Message {
    uint16 txNumberInBlock;
    address sender;
    bytes data;
}

/// @notice Part of the configuration parameters of ZKP circuits
struct VerifierParams {
    bytes32 recursionNodeLevelVkHash;
    bytes32 recursionLeafLevelVkHash;
    bytes32 recursionCircuitsSetVksHash;
}

/// @dev storing all storage variables for zkSync facets
/// NOTE: It is used in a proxy, so it is possible to add new variables to the end
/// NOTE: but NOT to modify already existing variables or change their order
/// NOTE: DiamondCutStorage is unused, but it must remain a member of AppStorage to not have storage collision
/// NOTE: instead UpgradeStorage is used that is appended to the end of the AppStorage struct
struct AppStorage {
    /// @dev Storage of variables needed for deprecated diamond cut facet
    uint256[7] __DEPRECATED_diamondCutStorage;
    /// @notice Address which will exercise governance over the network i.e. change validator set, conduct upgrades
    address governor;
    /// @notice Address that the governor proposed as one that will replace it
    address pendingGovernor;
    /// @notice List of permitted validators
    mapping(address => bool) validators;
    /// @dev Verifier contract. Used to verify aggregated proof for blocks
    Verifier verifier;
    /// @notice Total number of executed blocks i.e. blocks[totalBlocksExecuted] points at the latest executed block (block 0 is genesis)
    uint256 totalBlocksExecuted;
    /// @notice Total number of proved blocks i.e. blocks[totalBlocksProved] points at the latest proved block
    uint256 totalBlocksVerified;
    /// @notice Total number of committed blocks i.e. blocks[totalBlocksCommitted] points at the latest committed block
    uint256 totalBlocksCommitted;
    /// @dev Stored hashed StoredBlock for block number
    mapping(uint256 => bytes32) storedBlockHashes;
    /// @dev Stored root hashes of L2 -> L1 logs
    mapping(uint256 => bytes32) l2LogsRootHashes;
    /// @dev Container that stores transactions requested from L1
    PriorityQueue.Queue priorityQueue;
    /// @dev The smart contract that manages the list with permission to call contract functions
    IAllowList allowList;
    /// @notice Part of the configuration parameters of ZKP circuits. Used as an input for the verifier smart contract
    VerifierParams verifierParams;
    /// @notice Bytecode hash of bootloader program.
    /// @dev Used as an input to zkp-circuit.
    bytes32 l2BootloaderBytecodeHash;
    /// @notice Bytecode hash of default account (bytecode for EOA).
    /// @dev Used as an input to zkp-circuit.
    bytes32 l2DefaultAccountBytecodeHash;
    /// @dev Indicates that the porter may be touched on L2 transactions.
    /// @dev Used as an input to zkp-circuit.
    bool zkPorterIsAvailable;
    /// @dev The maximum number of ergs that a user can request for L1 -> L2 transactions
    uint256 priorityTxMaxErgsLimit;
    /// @dev Storage of variables needed for upgrade facet
    UpgradeStorage upgrades;
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./Plonk4VerifierWithAccessToDNext.sol";
import "../common/libraries/UncheckedMath.sol";

contract Verifier is Plonk4VerifierWithAccessToDNext {
    using UncheckedMath for uint256;

    function get_verification_key() public pure returns (VerificationKey memory vk) {
        vk.num_inputs = 1;
        vk.domain_size = 67108864;
        vk.omega = PairingsBn254.new_fr(0x1dba8b5bdd64ef6ce29a9039aca3c0e524395c43b9227b96c75090cc6cc7ec97);
        // coefficients
        vk.gate_setup_commitments[0] = PairingsBn254.new_g1(
            0x19af674d98a56e4b530aa94bf82df98768bb214aa1f261b1d1fb6789f9e66d67,
            0x0335e647418f85e76d27feca0cce7027b92b0eabf93888219b9beca066886730
        );
        vk.gate_setup_commitments[1] = PairingsBn254.new_g1(
            0x0503f826267486c0a6d73afb4d9a8f0ed019d5d129fcedcbfa0b2970c8a3d7fa,
            0x008af7d231afc190a96c02da5cc6721fcff5e01ba1ad65540a3fde576802d1cd
        );
        vk.gate_setup_commitments[2] = PairingsBn254.new_g1(
            0x0198011f9c1c53811036bc8e0e8002c1b8892001e9ce0cd18110af9a03087421,
            0x25933f6eb6db13720269a863a55db5dd31c96b1ee0da61e34e09f83a59297ca2
        );
        vk.gate_setup_commitments[3] = PairingsBn254.new_g1(
            0x17e76e39a1a2e71f32b5cab55c4eef178a632e7d907153e06f53e364dbd2cbc8,
            0x21fccb59891624d9d9d35d0f661afb120ca1f78628b8aa59beeefd4431107e88
        );
        vk.gate_setup_commitments[4] = PairingsBn254.new_g1(
            0x1b041d57c56b8521f2520442e462f755721ab4aeb573487618ce09910a8c6354,
            0x0e4ec17897446c4fd1c36559405a0d2def071c4ad5b9124116db5654129ffed5
        );
        vk.gate_setup_commitments[5] = PairingsBn254.new_g1(
            0x2a06f3104a04d0a5272f5e623cdecdce7e06b4aef361be0786f3a6814280d05b,
            0x21541f91d1e19e517d6471dba9f048355896e9a2bf7ececbecbdc63431ecb261
        );
        vk.gate_setup_commitments[6] = PairingsBn254.new_g1(
            0x204b887749553f1d24bec0f6066088454b586d25fc57d716679517d12082e1ed,
            0x27f989c5dd011c6aaf441068780f3b133eb2bde878843155c85abeec4ab91f11
        );
        vk.gate_setup_commitments[7] = PairingsBn254.new_g1(
            0x1a8cd862024729474b1b5ef122acf86f759433abaefdcfb8fa7e6ad761b112b2,
            0x2a80832c2d1f2e7aa625b720d14b93f628c107ef41d78d492aa123c75d97a848
        );
        // gate selectors
        vk.gate_selectors_commitments[0] = PairingsBn254.new_g1(
            0x1633993f359a7b1738f2fbd69ce7643e423570fb0a6fe55a244bea41596dfc3d,
            0x2cf6203dad1d1295d1793cdd114195c129b0ecc663f4e92917c1490980385a44
        );
        vk.gate_selectors_commitments[1] = PairingsBn254.new_g1(
            0x10f0ab2fda24f693b7851a3c626c5eb3dd1ef9bacc68fdbfe638466f8fc2b949,
            0x15fde64ce1ae3313f039d7b9b7f192fa5a7b0bd80307c67cfed47fae20f008e4
        );
        // permutation
        vk.permutation_commitments[0] = PairingsBn254.new_g1(
            0x03a5af959e223de35693573bc896f333fac84cfe4f272c4080bc102e4c4752b3,
            0x102cd8e77890c56a99a9cf9bb964ee3e3b60629e35f60b94a97932903b31cbc6
        );
        vk.permutation_commitments[1] = PairingsBn254.new_g1(
            0x0f4c46be8af3e4fa5e0ce6d2985b1db29177975309e55748da391d2b81c98288,
            0x1c5bed67fe034739a649e373e684120495431377c2d4e81689d678635ea737b2
        );
        vk.permutation_commitments[2] = PairingsBn254.new_g1(
            0x2a990254375e7cc9bec8ab68e5a5ec5ee49de5b2a6b0b33cecb557125aa93b43,
            0x046b3e9a530f72b2a8d3226b1285ce7b656bb112e243750664fe066423bcb4ca
        );
        vk.permutation_commitments[3] = PairingsBn254.new_g1(
            0x281baa0297d9c6d6a8d79caa59fa5dd78efe760dfd4a1ae7575b8b996497e4cc,
            0x22a32326f73a3d070184f7da88ebec776d1ef63207bb2b5e04d28307eeed9c47
        );
        // lookup table commitments
        vk.lookup_selector_commitment = PairingsBn254.new_g1(
            0x1035bcc4f67bc18af0db54384cc120d50060121d3b2a4e8698937756b3f73b54,
            0x1b1eebcd824d7b114cd230e0a450b63ff5218a6141bb5bf013a79ba2ab6f7ddb
        );
        vk.lookup_tables_commitments[0] = PairingsBn254.new_g1(
            0x0ebe0de4a2f39df3b903da484c1641ffdffb77ff87ce4f9508c548659eb22d3c,
            0x12a3209440242d5662729558f1017ed9dcc08fe49a99554dd45f5f15da5e4e0b
        );
        vk.lookup_tables_commitments[1] = PairingsBn254.new_g1(
            0x1b7d54f8065ca63bed0bfbb9280a1011b886d07e0c0a26a66ecc96af68c53bf9,
            0x2c51121fff5b8f58c302f03c74e0cb176ae5a1d1730dec4696eb9cce3fe284ca
        );
        vk.lookup_tables_commitments[2] = PairingsBn254.new_g1(
            0x0138733c5faa9db6d4b8df9748081e38405999e511fb22d40f77cf3aef293c44,
            0x269bee1c1ac28053238f7fe789f1ea2e481742d6d16ae78ed81e87c254af0765
        );
        vk.lookup_tables_commitments[3] = PairingsBn254.new_g1(
            0x1b1be7279d59445065a95f01f16686adfa798ec4f1e6845ffcec9b837e88372e,
            0x057c90cb96d8259238ed86b05f629efd55f472a721efeeb56926e979433e6c0e
        );
        vk.lookup_table_type_commitment = PairingsBn254.new_g1(
            0x011967367ae87879d15a58c58e4849bc897764ce3f016d5abc04bc7804d6bdf7,
            0x29775ffa2d2ddd439a664e165294f68ea17d6d754bcf4c20a52fbf766eeb1995
        );
        // non residues
        vk.non_residues[0] = PairingsBn254.new_fr(0x0000000000000000000000000000000000000000000000000000000000000005);
        vk.non_residues[1] = PairingsBn254.new_fr(0x0000000000000000000000000000000000000000000000000000000000000007);
        vk.non_residues[2] = PairingsBn254.new_fr(0x000000000000000000000000000000000000000000000000000000000000000a);

        // g2 elements
        vk.g2_elements[0] = PairingsBn254.new_g2(
            [
                0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2,
                0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed
            ],
            [
                0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b,
                0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa
            ]
        );
        vk.g2_elements[1] = PairingsBn254.new_g2(
            [
                0x260e01b251f6f1c7e7ff4e580791dee8ea51d87a358e038b4efe30fac09383c1,
                0x0118c4d5b837bcc2bc89b5b398b5974e9f5944073b32078b7e231fec938883b0
            ],
            [
                0x04fc6369f7110fe3d25156c1bb9a72859cf2a04641f99ba4ee413c80da6a5fe4,
                0x22febda3c0c0632a56475b4214e5615e11e6dd3f96e6cea2854a87d4dacc5e55
            ]
        );
    }

    function deserialize_proof(uint256[] calldata public_inputs, uint256[] calldata serialized_proof)
        internal
        pure
        returns (Proof memory proof)
    {
        // require(serialized_proof.length == 44); TODO
        proof.input_values = new uint256[](public_inputs.length);
        for (uint256 i = 0; i < public_inputs.length; i = i.uncheckedInc()) {
            proof.input_values[i] = public_inputs[i];
        }

        uint256 j;
        for (uint256 i = 0; i < STATE_WIDTH; i = i.uncheckedInc()) {
            proof.state_polys_commitments[i] = PairingsBn254.new_g1_checked(
                serialized_proof[j],
                serialized_proof[j.uncheckedInc()]
            );

            j = j.uncheckedAdd(2);
        }
        proof.copy_permutation_grand_product_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);

        proof.lookup_s_poly_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);

        proof.lookup_grand_product_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);
        for (uint256 i = 0; i < proof.quotient_poly_parts_commitments.length; i = i.uncheckedInc()) {
            proof.quotient_poly_parts_commitments[i] = PairingsBn254.new_g1_checked(
                serialized_proof[j],
                serialized_proof[j.uncheckedInc()]
            );
            j = j.uncheckedAdd(2);
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z.length; i = i.uncheckedInc()) {
            proof.state_polys_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z_omega.length; i = i.uncheckedInc()) {
            proof.state_polys_openings_at_z_omega[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        for (uint256 i = 0; i < proof.gate_selectors_openings_at_z.length; i = i.uncheckedInc()) {
            proof.gate_selectors_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        for (uint256 i = 0; i < proof.copy_permutation_polys_openings_at_z.length; i = i.uncheckedInc()) {
            proof.copy_permutation_polys_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        proof.copy_permutation_grand_product_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_s_poly_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_grand_product_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_t_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_t_poly_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_selector_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_table_type_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.quotient_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.linearization_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.opening_proof_at_z = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);
        proof.opening_proof_at_z_omega = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
    }

    function verify_serialized_proof(uint256[] calldata public_inputs, uint256[] calldata serialized_proof)
        public
        view
        returns (bool)
    {
        VerificationKey memory vk = get_verification_key();
        require(vk.num_inputs == public_inputs.length);

        Proof memory proof = deserialize_proof(public_inputs, serialized_proof);

        return verify(proof, vk);
    }
}