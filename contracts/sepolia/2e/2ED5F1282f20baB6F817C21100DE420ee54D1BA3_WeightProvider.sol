// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Functions, FunctionsClient} from "./dev/functions/FunctionsClient.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IWeightProvider} from "./IWeightProvider.sol";
import {INotary} from "./INotary.sol";

/**
 * @dev Notary contract registers and authenticates Positions.
 *
 * This contract allows users to open positions, which can be verified
 * during the minting of the stablecoin.
 */
contract WeightProvider is Ownable, IWeightProvider, FunctionsClient {
    using Functions for Functions.Request;

    string public source =
        "const b=Functions.makeHttpRequest({ url:'https://www.signdb.com/.netlify/functions/optimize'});const c=Promise.resolve(b);return Functions.encodeUint256(Math.round(c.data['weight']));";
    INotary notary;
    uint64 subId;
    address wethAddress;
    uint24 poolFee = 3000;
    uint32 functionsGasLimit = 500_000;
    uint256 mostRecentWeight;

    constructor(address _oracleAddress, address _notaryAddress, address _wethAddress) FunctionsClient(_oracleAddress) {
        notary = INotary(_notaryAddress);
        wethAddress = _wethAddress;
    }

    function setSubId(uint64 _subId) public onlyOwner {
        subId = _subId;
    }

    function setFunctionsGasLimit(uint32 _functionsGasLimit) public onlyOwner {
        functionsGasLimit = _functionsGasLimit;
    }

    function executeRequest() external override returns (bytes32) {
        require(subId != 0, "Subscription ID must be set before redeeming");
        Functions.Request memory req;
        req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
        return sendRequest(req, subId, functionsGasLimit);
    }

    /**
     * @notice User defined function to handle a response
     * @param requestId The request ID, returned by sendRequest()
     * @param response Aggregated response from the user code
     * @param err Aggregated error from the user code or from the execution pipeline
     * Either response or error parameter will be set, but never both
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        uint256 weight = uint256(bytes32(response));
        uint256[] memory weights;
        weights[0] = weight;
        weights[1] = 1 - weight;
        mostRecentWeight = weight;
        notary.updateAssetsAndPortfolioTestnet(weights);
        //        notary.updateAssetsAndPortfolioTestnet(weights, wethAddress, poolFee);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./Functions.sol";
import "../interfaces/FunctionsClientInterface.sol";
import "../interfaces/FunctionsOracleInterface.sol";

/**
 * @title The Chainlink Functions client contract
 * @notice Contract writers can inherit this contract in order to create Chainlink Functions requests
 */
abstract contract FunctionsClient is FunctionsClientInterface {
    FunctionsOracleInterface internal s_oracle;
    mapping(bytes32 => address) internal s_pendingRequests;

    event RequestSent(bytes32 indexed id);
    event RequestFulfilled(bytes32 indexed id);

    error SenderIsNotRegistry();
    error RequestIsAlreadyPending();
    error RequestIsNotPending();

    constructor(address oracle) {
        setOracle(oracle);
    }

    /**
     * @inheritdoc FunctionsClientInterface
     */
    function getDONPublicKey() external view override returns (bytes memory) {
        return s_oracle.getDONPublicKey();
    }

    /**
     * @notice Estimate the total cost that will be charged to a subscription to make a request: gas re-imbursement, plus DON fee, plus Registry fee
     * @param req The initialized Functions.Request
     * @param subscriptionId The subscription ID
     * @param gasLimit gas limit for the fulfillment callback
     * @return billedCost Cost in Juels (1e18) of LINK
     */
    function estimateCost(Functions.Request memory req, uint64 subscriptionId, uint32 gasLimit, uint256 gasPrice)
        public
        view
        returns (uint96)
    {
        return s_oracle.estimateCost(subscriptionId, Functions.encodeCBOR(req), gasLimit, gasPrice);
    }

    /**
     * @notice Sends a Chainlink Functions request to the stored oracle address
     * @param req The initialized Functions.Request
     * @param subscriptionId The subscription ID
     * @param gasLimit gas limit for the fulfillment callback
     * @return requestId The generated request ID
     */
    function sendRequest(Functions.Request memory req, uint64 subscriptionId, uint32 gasLimit)
        internal
        returns (bytes32)
    {
        bytes32 requestId = s_oracle.sendRequest(subscriptionId, Functions.encodeCBOR(req), gasLimit);
        s_pendingRequests[requestId] = s_oracle.getRegistry();
        emit RequestSent(requestId);
        return requestId;
    }

    /**
     * @notice User defined function to handle a response
     * @param requestId The request ID, returned by sendRequest()
     * @param response Aggregated response from the user code
     * @param err Aggregated error from the user code or from the execution pipeline
     * Either response or error parameter will be set, but never both
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal virtual;

    /**
     * @inheritdoc FunctionsClientInterface
     */
    function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err)
        external
        override
        recordChainlinkFulfillment(requestId)
    {
        fulfillRequest(requestId, response, err);
    }

    /**
     * @notice Sets the stored Oracle address
     * @param oracle The address of Functions Oracle contract
     */
    function setOracle(address oracle) internal {
        s_oracle = FunctionsOracleInterface(oracle);
    }

    /**
     * @notice Gets the stored address of the oracle contract
     * @return The address of the oracle contract
     */
    function getChainlinkOracleAddress() internal view returns (address) {
        return address(s_oracle);
    }

    /**
     * @notice Allows for a request which was created on another contract to be fulfilled
     * on this contract
     * @param oracleAddress The address of the oracle contract that will fulfill the request
     * @param requestId The request ID used for the response
     */
    function addExternalRequest(address oracleAddress, bytes32 requestId) internal notPendingRequest(requestId) {
        s_pendingRequests[requestId] = oracleAddress;
    }

    /**
     * @dev Reverts if the sender is not the oracle that serviced the request.
     * Emits RequestFulfilled event.
     * @param requestId The request ID for fulfillment
     */
    modifier recordChainlinkFulfillment(bytes32 requestId) {
        if (msg.sender != s_pendingRequests[requestId]) {
            revert SenderIsNotRegistry();
        }
        delete s_pendingRequests[requestId];
        emit RequestFulfilled(requestId);
        _;
    }

    /**
     * @dev Reverts if the request is already pending
     * @param requestId The request ID for fulfillment
     */
    modifier notPendingRequest(bytes32 requestId) {
        if (s_pendingRequests[requestId] != address(0)) {
            revert RequestIsAlreadyPending();
        }
        _;
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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IWeightProvider {
    function executeRequest() external returns (bytes32);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface INotary {
    function updateAssetsAndPortfolioTestnet(uint256[] memory _targetWeights) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {CBOR, Buffer} from "../vendor/solidity-cborutils/2.0.0/CBOR.sol";

/**
 * @title Library for Chainlink Functions
 */
library Functions {
    uint256 internal constant DEFAULT_BUFFER_SIZE = 256;

    using CBOR for Buffer.buffer;

    enum Location {
        Inline,
        Remote
    }

    enum CodeLanguage {JavaScript}
    // In future version we may add other languages

    struct Request {
        Location codeLocation;
        Location secretsLocation;
        CodeLanguage language;
        string source; // Source code for Location.Inline or url for Location.Remote
        bytes secrets; // Encrypted secrets blob for Location.Inline or url for Location.Remote
        string[] args;
    }

    error EmptySource();
    error EmptyUrl();
    error EmptySecrets();
    error EmptyArgs();
    error NoInlineSecrets();

    /**
     * @notice Encodes a Request to CBOR encoded bytes
     * @param self The request to encode
     * @return CBOR encoded bytes
     */
    function encodeCBOR(Request memory self) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buffer;
        Buffer.init(buffer.buf, DEFAULT_BUFFER_SIZE);

        CBOR.writeString(buffer, "codeLocation");
        CBOR.writeUInt256(buffer, uint256(self.codeLocation));

        CBOR.writeString(buffer, "language");
        CBOR.writeUInt256(buffer, uint256(self.language));

        CBOR.writeString(buffer, "source");
        CBOR.writeString(buffer, self.source);

        if (self.args.length > 0) {
            CBOR.writeString(buffer, "args");
            CBOR.startArray(buffer);
            for (uint256 i = 0; i < self.args.length; i++) {
                CBOR.writeString(buffer, self.args[i]);
            }
            CBOR.endSequence(buffer);
        }

        if (self.secrets.length > 0) {
            if (self.secretsLocation == Location.Inline) {
                revert NoInlineSecrets();
            }
            CBOR.writeString(buffer, "secretsLocation");
            CBOR.writeUInt256(buffer, uint256(self.secretsLocation));
            CBOR.writeString(buffer, "secrets");
            CBOR.writeBytes(buffer, self.secrets);
        }

        return buffer.buf.buf;
    }

    /**
     * @notice Initializes a Chainlink Functions Request
     * @dev Sets the codeLocation and code on the request
     * @param self The uninitialized request
     * @param location The user provided source code location
     * @param language The programming language of the user code
     * @param source The user provided source code or a url
     */
    function initializeRequest(Request memory self, Location location, CodeLanguage language, string memory source)
        internal
        pure
    {
        if (bytes(source).length == 0) revert EmptySource();

        self.codeLocation = location;
        self.language = language;
        self.source = source;
    }

    /**
     * @notice Initializes a Chainlink Functions Request
     * @dev Simplified version of initializeRequest for PoC
     * @param self The uninitialized request
     * @param javaScriptSource The user provided JS code (must not be empty)
     */
    function initializeRequestForInlineJavaScript(Request memory self, string memory javaScriptSource) internal pure {
        initializeRequest(self, Location.Inline, CodeLanguage.JavaScript, javaScriptSource);
    }

    /**
     * @notice Adds Remote user encrypted secrets to a Request
     * @param self The initialized request
     * @param encryptedSecretsURLs Encrypted comma-separated string of URLs pointing to off-chain secrets
     */
    function addRemoteSecrets(Request memory self, bytes memory encryptedSecretsURLs) internal pure {
        if (encryptedSecretsURLs.length == 0) revert EmptySecrets();

        self.secretsLocation = Location.Remote;
        self.secrets = encryptedSecretsURLs;
    }

    /**
     * @notice Adds args for the user run function
     * @param self The initialized request
     * @param args The array of args (must not be empty)
     */
    function addArgs(Request memory self, string[] memory args) internal pure {
        if (args.length == 0) revert EmptyArgs();

        self.args = args;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/**
 * @title Chainlink Functions client interface.
 */
interface FunctionsClientInterface {
    /**
     * @notice Returns the DON's secp256k1 public key used to encrypt secrets
     * @dev All Oracles nodes have the corresponding private key
     * needed to decrypt the secrets encrypted with the public key
     * @return publicKey DON's public key
     */
    function getDONPublicKey() external view returns (bytes memory);

    /**
     * @notice Chainlink Functions response handler called by the designated transmitter node in an OCR round.
     * @param requestId The requestId returned by FunctionsClient.sendRequest().
     * @param response Aggregated response from the user code.
     * @param err Aggregated error either from the user code or from the execution pipeline.
     * Either response or error parameter will be set, but never both.
     */
    function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./FunctionsBillingRegistryInterface.sol";

/**
 * @title Chainlink Functions oracle interface.
 */
interface FunctionsOracleInterface {
    /**
     * @notice Gets the stored billing registry address
     * @return registryAddress The address of Chainlink Functions billing registry contract
     */
    function getRegistry() external view returns (address);

    /**
     * @notice Sets the stored billing registry address
     * @param registryAddress The new address of Chainlink Functions billing registry contract
     */
    function setRegistry(address registryAddress) external;

    /**
     * @notice Returns the DON's secp256k1 public key that is used to encrypt secrets
     * @dev All nodes on the DON have the corresponding private key
     * needed to decrypt the secrets encrypted with the public key
     * @return publicKey the DON's public key
     */
    function getDONPublicKey() external view returns (bytes memory);

    /**
     * @notice Sets DON's secp256k1 public key used to encrypt secrets
     * @dev Used to rotate the key
     * @param donPublicKey The new public key
     */
    function setDONPublicKey(bytes calldata donPublicKey) external;

    /**
     * @notice Sets a per-node secp256k1 public key used to encrypt secrets for that node
     * @dev Callable only by contract owner and DON members
     * @param node node's address
     * @param publicKey node's public key
     */
    function setNodePublicKey(address node, bytes calldata publicKey) external;

    /**
     * @notice Deletes node's public key
     * @dev Callable only by contract owner or the node itself
     * @param node node's address
     */
    function deleteNodePublicKey(address node) external;

    /**
     * @notice Return two arrays of equal size containing DON members' addresses and their corresponding
     * public keys (or empty byte arrays if per-node key is not defined)
     */
    function getAllNodePublicKeys() external view returns (address[] memory, bytes[] memory);

    /**
     * @notice Determine the fee charged by the DON that will be split between signing Node Operators for servicing the request
     * @param data Encoded Chainlink Functions request data, use FunctionsClient API to encode a request
     * @param billing The request's billing configuration
     * @return fee Cost in Juels (1e18) of LINK
     */
    function getRequiredFee(bytes calldata data, FunctionsBillingRegistryInterface.RequestBilling calldata billing)
        external
        view
        returns (uint96);

    /**
     * @notice Estimate the total cost that will be charged to a subscription to make a request: gas re-imbursement, plus DON fee, plus Registry fee
     * @param subscriptionId A unique subscription ID allocated by billing system,
     * a client can make requests from different contracts referencing the same subscription
     * @param data Encoded Chainlink Functions request data, use FunctionsClient API to encode a request
     * @param gasLimit Gas limit for the fulfillment callback
     * @return billedCost Cost in Juels (1e18) of LINK
     */
    function estimateCost(uint64 subscriptionId, bytes calldata data, uint32 gasLimit, uint256 gasPrice)
        external
        view
        returns (uint96);

    /**
     * @notice Sends a request (encoded as data) using the provided subscriptionId
     * @param subscriptionId A unique subscription ID allocated by billing system,
     * a client can make requests from different contracts referencing the same subscription
     * @param data Encoded Chainlink Functions request data, use FunctionsClient API to encode a request
     * @param gasLimit Gas limit for the fulfillment callback
     * @return requestId A unique request identifier (unique per DON)
     */
    function sendRequest(uint64 subscriptionId, bytes calldata data, uint32 gasLimit) external returns (bytes32);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@ensdomains/buffer/0.1.0/Buffer.sol";

/**
 * @dev A library for populating CBOR encoded payload in Solidity.
 *
 * https://datatracker.ietf.org/doc/html/rfc7049
 *
 * The library offers various write* and start* methods to encode values of different types.
 * The resulted buffer can be obtained with data() method.
 * Encoding of primitive types is staightforward, whereas encoding of sequences can result
 * in an invalid CBOR if start/write/end flow is violated.
 * For the purpose of gas saving, the library does not verify start/write/end flow internally,
 * except for nested start/end pairs.
 */

library CBOR {
    using Buffer for Buffer.buffer;

    struct CBORBuffer {
        Buffer.buffer buf;
        uint256 depth;
    }

    uint8 private constant MAJOR_TYPE_INT = 0;
    uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
    uint8 private constant MAJOR_TYPE_BYTES = 2;
    uint8 private constant MAJOR_TYPE_STRING = 3;
    uint8 private constant MAJOR_TYPE_ARRAY = 4;
    uint8 private constant MAJOR_TYPE_MAP = 5;
    uint8 private constant MAJOR_TYPE_TAG = 6;
    uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

    uint8 private constant TAG_TYPE_BIGNUM = 2;
    uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;

    uint8 private constant CBOR_FALSE = 20;
    uint8 private constant CBOR_TRUE = 21;
    uint8 private constant CBOR_NULL = 22;
    uint8 private constant CBOR_UNDEFINED = 23;

    function create(uint256 capacity) internal pure returns (CBORBuffer memory cbor) {
        Buffer.init(cbor.buf, capacity);
        cbor.depth = 0;
        return cbor;
    }

    function data(CBORBuffer memory buf) internal pure returns (bytes memory) {
        require(buf.depth == 0, "Invalid CBOR");
        return buf.buf.buf;
    }

    function writeUInt256(CBORBuffer memory buf, uint256 value) internal pure {
        buf.buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_BIGNUM));
        writeBytes(buf, abi.encode(value));
    }

    function writeInt256(CBORBuffer memory buf, int256 value) internal pure {
        if (value < 0) {
            buf.buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_NEGATIVE_BIGNUM));
            writeBytes(buf, abi.encode(uint256(-1 - value)));
        } else {
            writeUInt256(buf, uint256(value));
        }
    }

    function writeUInt64(CBORBuffer memory buf, uint64 value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_INT, value);
    }

    function writeInt64(CBORBuffer memory buf, int64 value) internal pure {
        if (value >= 0) {
            writeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(value));
        } else {
            writeFixedNumeric(buf, MAJOR_TYPE_NEGATIVE_INT, uint64(-1 - value));
        }
    }

    function writeBytes(CBORBuffer memory buf, bytes memory value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_BYTES, uint64(value.length));
        buf.buf.append(value);
    }

    function writeString(CBORBuffer memory buf, string memory value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_STRING, uint64(bytes(value).length));
        buf.buf.append(bytes(value));
    }

    function writeBool(CBORBuffer memory buf, bool value) internal pure {
        writeContentFree(buf, value ? CBOR_TRUE : CBOR_FALSE);
    }

    function writeNull(CBORBuffer memory buf) internal pure {
        writeContentFree(buf, CBOR_NULL);
    }

    function writeUndefined(CBORBuffer memory buf) internal pure {
        writeContentFree(buf, CBOR_UNDEFINED);
    }

    function startArray(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
        buf.depth += 1;
    }

    function startFixedArray(CBORBuffer memory buf, uint64 length) internal pure {
        writeDefiniteLengthType(buf, MAJOR_TYPE_ARRAY, length);
    }

    function startMap(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
        buf.depth += 1;
    }

    function startFixedMap(CBORBuffer memory buf, uint64 length) internal pure {
        writeDefiniteLengthType(buf, MAJOR_TYPE_MAP, length);
    }

    function endSequence(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
        buf.depth -= 1;
    }

    function writeKVString(CBORBuffer memory buf, string memory key, string memory value) internal pure {
        writeString(buf, key);
        writeString(buf, value);
    }

    function writeKVBytes(CBORBuffer memory buf, string memory key, bytes memory value) internal pure {
        writeString(buf, key);
        writeBytes(buf, value);
    }

    function writeKVUInt256(CBORBuffer memory buf, string memory key, uint256 value) internal pure {
        writeString(buf, key);
        writeUInt256(buf, value);
    }

    function writeKVInt256(CBORBuffer memory buf, string memory key, int256 value) internal pure {
        writeString(buf, key);
        writeInt256(buf, value);
    }

    function writeKVUInt64(CBORBuffer memory buf, string memory key, uint64 value) internal pure {
        writeString(buf, key);
        writeUInt64(buf, value);
    }

    function writeKVInt64(CBORBuffer memory buf, string memory key, int64 value) internal pure {
        writeString(buf, key);
        writeInt64(buf, value);
    }

    function writeKVBool(CBORBuffer memory buf, string memory key, bool value) internal pure {
        writeString(buf, key);
        writeBool(buf, value);
    }

    function writeKVNull(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        writeNull(buf);
    }

    function writeKVUndefined(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        writeUndefined(buf);
    }

    function writeKVMap(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        startMap(buf);
    }

    function writeKVArray(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        startArray(buf);
    }

    function writeFixedNumeric(CBORBuffer memory buf, uint8 major, uint64 value) private pure {
        if (value <= 23) {
            buf.buf.appendUint8(uint8((major << 5) | value));
        } else if (value <= 0xFF) {
            buf.buf.appendUint8(uint8((major << 5) | 24));
            buf.buf.appendInt(value, 1);
        } else if (value <= 0xFFFF) {
            buf.buf.appendUint8(uint8((major << 5) | 25));
            buf.buf.appendInt(value, 2);
        } else if (value <= 0xFFFFFFFF) {
            buf.buf.appendUint8(uint8((major << 5) | 26));
            buf.buf.appendInt(value, 4);
        } else {
            buf.buf.appendUint8(uint8((major << 5) | 27));
            buf.buf.appendInt(value, 8);
        }
    }

    function writeIndefiniteLengthType(CBORBuffer memory buf, uint8 major) private pure {
        buf.buf.appendUint8(uint8((major << 5) | 31));
    }

    function writeDefiniteLengthType(CBORBuffer memory buf, uint8 major, uint64 length) private pure {
        writeFixedNumeric(buf, major, length);
    }

    function writeContentFree(CBORBuffer memory buf, uint8 value) private pure {
        buf.buf.appendUint8(uint8((MAJOR_TYPE_CONTENT_FREE << 5) | value));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/**
 * @title Chainlink Functions billing subscription registry interface.
 */
interface FunctionsBillingRegistryInterface {
    struct RequestBilling {
        // a unique subscription ID allocated by billing system,
        uint64 subscriptionId;
        // the client contract that initiated the request to the DON
        // to use the subscription it must be added as a consumer on the subscription
        address client;
        // customer specified gas limit for the fulfillment callback
        uint32 gasLimit;
        // the expected gas price used to execute the transaction
        uint256 gasPrice;
    }

    enum FulfillResult {
        USER_SUCCESS,
        USER_ERROR,
        INVALID_REQUEST_ID
    }

    /**
     * @notice Get configuration relevant for making requests
     * @return uint32 global max for request gas limit
     * @return address[] list of registered DONs
     */
    function getRequestConfig() external view returns (uint32, address[] memory);

    /**
     * @notice Determine the charged fee that will be paid to the Registry owner
     * @param data Encoded Chainlink Functions request data, use FunctionsClient API to encode a request
     * @param billing The request's billing configuration
     * @return fee Cost in Juels (1e18) of LINK
     */
    function getRequiredFee(bytes calldata data, FunctionsBillingRegistryInterface.RequestBilling memory billing)
        external
        view
        returns (uint96);

    /**
     * @notice Estimate the total cost to make a request: gas re-imbursement, plus DON fee, plus Registry fee
     * @param gasLimit Encoded Chainlink Functions request data, use FunctionsClient API to encode a request
     * @param gasPrice The request's billing configuration
     * @param donFee Fee charged by the DON that is paid to Oracle Node
     * @param registryFee Fee charged by the DON that is paid to Oracle Node
     * @return costEstimate Cost in Juels (1e18) of LINK
     */
    function estimateCost(uint32 gasLimit, uint256 gasPrice, uint96 donFee, uint96 registryFee)
        external
        view
        returns (uint96);

    /**
     * @notice Initiate the billing process for an Functions request
     * @param data Encoded Chainlink Functions request data, use FunctionsClient API to encode a request
     * @param billing Billing configuration for the request
     * @return requestId - A unique identifier of the request. Can be used to match a request to a response in fulfillRequest.
     * @dev Only callable by a node that has been approved on the Registry
     */
    function startBilling(bytes calldata data, RequestBilling calldata billing) external returns (bytes32);

    /**
     * @notice Finalize billing process for an Functions request by sending a callback to the Client contract and then charging the subscription
     * @param requestId identifier for the request that was generated by the Registry in the beginBilling commitment
     * @param response response data from DON consensus
     * @param err error from DON consensus
     * @param transmitter the Oracle who sent the report
     * @param signers the Oracles who had a part in generating the report
     * @param signerCount the number of signers on the report
     * @param reportValidationGas the amount of gas used for the report validation. Cost is split by all fulfillments on the report.
     * @param initialGas the initial amount of gas that should be used as a baseline to charge the single fulfillment for execution cost
     * @return result fulfillment result
     * @dev Only callable by a node that has been approved on the Registry
     * @dev simulated offchain to determine if sufficient balance is present to fulfill the request
     */
    function fulfillAndBill(
        bytes32 requestId,
        bytes calldata response,
        bytes calldata err,
        address transmitter,
        address[31] memory signers, // 31 comes from OCR2Abstract.sol's maxNumOracles constant
        uint8 signerCount,
        uint256 reportValidationGas,
        uint256 initialGas
    ) external returns (FulfillResult);

    /**
     * @notice Gets subscription owner.
     * @param subscriptionId - ID of the subscription
     * @return owner - owner of the subscription.
     */
    function getSubscriptionOwner(uint64 subscriptionId) external view returns (address owner);
}

// SPDX-License-Identifier: BSD-2-Clause
pragma solidity ^0.8.4;

/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for appending to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */
library Buffer {
    /**
     * @dev Represents a mutable buffer. Buffers have a current value (buf) and
     *      a capacity. The capacity may be longer than the current value, in
     *      which case it can be extended without the need to allocate more memory.
     */
    struct buffer {
        bytes buf;
        uint256 capacity;
    }

    /**
     * @dev Initializes a buffer with an initial capacity.
     * @param buf The buffer to initialize.
     * @param capacity The number of bytes of space to allocate the buffer.
     * @return The buffer, for chaining.
     */
    function init(buffer memory buf, uint256 capacity) internal pure returns (buffer memory) {
        if (capacity % 32 != 0) {
            capacity += 32 - (capacity % 32);
        }
        // Allocate space for the buffer data
        buf.capacity = capacity;
        assembly {
            let ptr := mload(0x40)
            mstore(buf, ptr)
            mstore(ptr, 0)
            let fpm := add(32, add(ptr, capacity))
            if lt(fpm, ptr) { revert(0, 0) }
            mstore(0x40, fpm)
        }
        return buf;
    }

    /**
     * @dev Initializes a new buffer from an existing bytes object.
     *      Changes to the buffer may mutate the original value.
     * @param b The bytes object to initialize the buffer with.
     * @return A new buffer.
     */
    function fromBytes(bytes memory b) internal pure returns (buffer memory) {
        buffer memory buf;
        buf.buf = b;
        buf.capacity = b.length;
        return buf;
    }

    function resize(buffer memory buf, uint256 capacity) private pure {
        bytes memory oldbuf = buf.buf;
        init(buf, capacity);
        append(buf, oldbuf);
    }

    /**
     * @dev Sets buffer length to 0.
     * @param buf The buffer to truncate.
     * @return The original buffer, for chaining..
     */
    function truncate(buffer memory buf) internal pure returns (buffer memory) {
        assembly {
            let bufptr := mload(buf)
            mstore(bufptr, 0)
        }
        return buf;
    }

    /**
     * @dev Appends len bytes of a byte string to a buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to copy.
     * @return The original buffer, for chaining.
     */
    function append(buffer memory buf, bytes memory data, uint256 len) internal pure returns (buffer memory) {
        require(len <= data.length);

        uint256 off = buf.buf.length;
        uint256 newCapacity = off + len;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint256 dest;
        uint256 src;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Length of existing buffer data
            let buflen := mload(bufptr)
            // Start address = buffer address + offset + sizeof(buffer length)
            dest := add(add(bufptr, 32), off)
            // Update buffer length if we're extending it
            if gt(newCapacity, buflen) { mstore(bufptr, newCapacity) }
            src := add(data, 32)
        }

        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        unchecked {
            uint256 mask = (256 ** (32 - len)) - 1;
            assembly {
                let srcpart := and(mload(src), not(mask))
                let destpart := and(mload(dest), mask)
                mstore(dest, or(destpart, srcpart))
            }
        }

        return buf;
    }

    /**
     * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chaining.
     */
    function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
        return append(buf, data, data.length);
    }

    /**
     * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
     *      capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chaining.
     */
    function appendUint8(buffer memory buf, uint8 data) internal pure returns (buffer memory) {
        uint256 off = buf.buf.length;
        uint256 offPlusOne = off + 1;
        if (off >= buf.capacity) {
            resize(buf, offPlusOne * 2);
        }

        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + off
            let dest := add(add(bufptr, off), 32)
            mstore8(dest, data)
            // Update buffer length if we extended it
            if gt(offPlusOne, mload(bufptr)) { mstore(bufptr, offPlusOne) }
        }

        return buf;
    }

    /**
     * @dev Appends len bytes of bytes32 to a buffer. Resizes if doing so would
     *      exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to write (left-aligned).
     * @return The original buffer, for chaining.
     */
    function append(buffer memory buf, bytes32 data, uint256 len) private pure returns (buffer memory) {
        uint256 off = buf.buf.length;
        uint256 newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        unchecked {
            uint256 mask = (256 ** len) - 1;
            // Right-align data
            data = data >> (8 * (32 - len));
            assembly {
                // Memory address of the buffer data
                let bufptr := mload(buf)
                // Address = buffer address + sizeof(buffer length) + newCapacity
                let dest := add(bufptr, newCapacity)
                mstore(dest, or(and(mload(dest), not(mask)), data))
                // Update buffer length if we extended it
                if gt(newCapacity, mload(bufptr)) { mstore(bufptr, newCapacity) }
            }
        }
        return buf;
    }

    /**
     * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chhaining.
     */
    function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
        return append(buf, bytes32(data), 20);
    }

    /**
     * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chaining.
     */
    function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
        return append(buf, data, 32);
    }

    /**
     * @dev Appends a byte to the end of the buffer. Resizes if doing so would
     *      exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to write (right-aligned).
     * @return The original buffer.
     */
    function appendInt(buffer memory buf, uint256 data, uint256 len) internal pure returns (buffer memory) {
        uint256 off = buf.buf.length;
        uint256 newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint256 mask = (256 ** len) - 1;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + newCapacity
            let dest := add(bufptr, newCapacity)
            mstore(dest, or(and(mload(dest), not(mask)), data))
            // Update buffer length if we extended it
            if gt(newCapacity, mload(bufptr)) { mstore(bufptr, newCapacity) }
        }
        return buf;
    }
}