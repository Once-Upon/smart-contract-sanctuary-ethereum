// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "../interfaces/IEventProxy.sol";
import "../interfaces/events/EventWrapper.sol";
import "../interfaces/events/IEventReceiver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import {OwnableUpgradeable as Ownable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EventProxy is Initializable, IEventProxy, Ownable {
    /// @dev FxPortal's FxChild
    // solhint-disable-next-line var-name-mixedcase
    address public STATE_SENDER;

    // sender => enabled. Only enabled senders emit events. Others are noop.
    mapping(address => bool) public registeredSenders;

    uint256 public lastProcessedStateId;

    // sender => event => Destination[]
    mapping(address => mapping(bytes32 => address[])) public destinations;

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();

    }

    function setSenderRegistration(address _sender, bool _allowed) external override onlyOwner {
        require(_sender != address(0), "INVALID_ADDRESS");
        registeredSenders[_sender] = _allowed;

        emit SenderRegistered(_sender, _allowed);
    }

    function registerDestinations(
        DestinationsBySenderAndEventType[] memory destinationsBySenderAndEventType
    ) external override onlyOwner {
        for (uint256 i = 0; i < destinationsBySenderAndEventType.length; i++) {
            DestinationsBySenderAndEventType memory config = destinationsBySenderAndEventType[i];
            require(config.sender != address(0), "INVALID_SENDER_ADDRESS");
            require(config.eventType != "", "INVALID_EVENT_TYPE");
            require(config.destinations.length != 0, "MUST_SPECIFY_AT_LEAST_ONE_DESTINATION");

            // consider improving efficiency by overwriting existing
            // slots and pushing/popping if we need more/less
            delete destinations[config.sender][config.eventType];

            for (uint256 y = 0; y < config.destinations.length; y++) {
                require(config.destinations[y] != address(0), "INVALID_L2_ENDPOINT_ADDRESS");
                destinations[config.sender][config.eventType].push(config.destinations[y]);
            }
        }

        emit RegisterDestinations(destinationsBySenderAndEventType);
    }

    function getRegisteredDestinations(address sender, bytes32 eventType)
        external
        view
        override
        returns (address[] memory)
    {
        return destinations[sender][eventType];
    }

    /// @notice Recieves payload from mainnet
    /// @param rootMessageSender Sender from mainnet
    /// @param data Event we are sending
    /// @dev Manager will be sending events with current vote session key
    function processMessageFromRoot(
        address rootMessageSender,
        bytes calldata data
    ) external override {
        require(registeredSenders[rootMessageSender], "INVALID_ROOT_SENDER");

        //Must have sent something, at least an event type, so we know how to route
        require(data.length > 0, "NO_DATA");

        //Determine event type
        bytes32 eventType = abi.decode(data[:32], (bytes32));
        require(eventType != "", "INVALID_EVENT_TYPE");

        address[] memory targetDestinations = destinations[rootMessageSender][eventType];
        for (uint256 i = 0; i < targetDestinations.length; i++) {
            address destination = targetDestinations[i];
            IEventReceiver(destination).onEventReceive(rootMessageSender, eventType, data);

            emit EventSent(eventType, rootMessageSender, destination, data);
        }
    }

    // TODO: this should take the index for the targeted destination so we don't have to loop
    function unregisterDestination(
        address _sender,
        address _l2Endpoint,
        bytes32 _eventType
    ) external override onlyOwner {
        address[] storage destination = destinations[_sender][_eventType];

        uint256 index = 256**2 - 1;
        for (uint256 i = 0; i < destination.length; i++) {
            if (destination[i] == _l2Endpoint) {
                index = i;
                break;
            }
        }

        require(index < 256**2 - 1, "DESTINATION_DOES_NOT_EXIST");

        for (uint256 i = index; i < destination.length - 1; i++) {
            destination[i] = destination[i + 1];
        }
        destination.pop();

        emit UnregisterDestination(_sender, _l2Endpoint, _eventType);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.11;
pragma experimental ABIEncoderV2;

import "../fxPortal/IFxMessageProcessor.sol";

/**
 *  @title Used to route events coming from the State Sender system.
 *  An event has a “type” and the contract can determine where it needs to be forwarded/copied for processing.
 */
interface IEventProxy is IFxMessageProcessor {
    struct DestinationsBySenderAndEventType {
        address sender;
        bytes32 eventType;
        address[] destinations;
    }

    event SenderRegistrationChanged(address sender, bool allowed);
    event DestinationRegistered(address sender, address destination);
    event DestinationUnregistered(address sender, address destination);
    event SenderRegistered(address sender, bool allowed);
    event RegisterDestinations(DestinationsBySenderAndEventType[]);
    event UnregisterDestination(address sender, address l2Endpoint, bytes32 eventType);
    event EventSent(bytes32 eventType, address sender, address destination, bytes data);
    event SetGateway(bytes32 name, address gateway);

    /// @notice Toggles a senders ability to send an event through the contract
    /// @param sender Address of sender
    /// @param allowed Allowed to send event
    /// @dev Contracts should call as themselves, and so it will be the contract addresses registered here
    function setSenderRegistration(address sender, bool allowed) external;

    /// @notice For a sender/eventType, register destination contracts that should receive events
    /// @param destinationsBySenderAndEventType Destinations specifies all the destinations for a given sender/eventType combination
    /// @dev this COMPLETELY REPLACES all destinations for the sender/eventType
    function registerDestinations(
        DestinationsBySenderAndEventType[] memory destinationsBySenderAndEventType
    ) external;

    /// @notice retrieves all the registered destinations for a sender/eventType key
    function getRegisteredDestinations(address sender, bytes32 eventType)
        external
        view
        returns (address[] memory);

    /// @notice For a sender, unregister destination contracts on Polygon
    /// @param sender Address of sender
    function unregisterDestination(
        address sender,
        address l2Endpoint,
        bytes32 eventType
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.11;

/// @notice Simple structure for events sent to Governance layer
struct EventWrapper {
    bytes32 eventType;
    bytes data;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

interface IEventReceiver {
    /// @notice Receive an encoded event from a contract on a different chain
    /// @param sender Contract address of sender on other chain
    /// @param eventType Encoded event type
    /// @param data Event Event data
    function onEventReceive(
        address sender,
        bytes32 eventType,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/Initializable.sol";
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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.11;

// IFxMessageProcessor represents interface to process message
interface IFxMessageProcessor {
    function processMessageFromRoot(address rootMessageSender, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}