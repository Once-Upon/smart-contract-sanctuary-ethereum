// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/* Interface Imports */
import { IL1StandardBridge } from "./IL1StandardBridge.sol";
import { IL1ERC20Bridge } from "./IL1ERC20Bridge.sol";
import { IL2ERC20Bridge } from "../../L2/messaging/IL2ERC20Bridge.sol";
import { INahmiiStandardERC20 } from "../../standards/INahmiiStandardERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* Library Imports */
import { CrossDomainEnabled } from "../../libraries/bridge/CrossDomainEnabled.sol";
import { Lib_PredeployAddresses } from "../../libraries/constants/Lib_PredeployAddresses.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

/**
 * @title L1StandardBridge
 * @dev The L1 ETH and ERC20 bridge is a contract which works together with a corresponding L2
 *      bridge to make it possible to bridge ETH and ERC20 tokens from Ethereum to Nahmii.
 */
contract L1StandardBridge is IL1StandardBridge, CrossDomainEnabled {
    using SafeERC20 for IERC20;

    /********************************
     * External Contract References *
     ********************************/

    address public remoteTokenBridge;

    // Maps L1 token to L2 token to balance of the L1 token locked
    mapping(address => mapping(address => uint256)) public locks;

    /***************
     * Constructor *
     ***************/

    // This contract lives behind a proxy, so the constructor parameters will go unused.
    constructor() CrossDomainEnabled(address(0)) {}

    /******************
     * Initialization *
     ******************/

    /**
     * @param _localMessenger L1 Messenger address being used for cross-chain communications.
     * @param _remoteTokenBridge L2 standard bridge address.
     */
    // slither-disable-next-line external-function
    function initialize(address _localMessenger, address _remoteTokenBridge) public {
        require(messenger == address(0), "Contract has already been initialized.");
        messenger = _localMessenger;
        remoteTokenBridge = _remoteTokenBridge;
    }

    /**************
     * Bridging *
     **************/

    /**
     * @dev Modifier requiring sender to be EOA.  This check could be bypassed by a malicious
     * contract via initcode, but it takes care of the user error we want to avoid.
     */
    modifier onlyEOA() {
        // Used to stop bridging from contracts (avoid accidentally lost tokens)
        require(!Address.isContract(msg.sender), "Account not EOA");
        _;
    }

    /**
     * @dev This function can be called with no data
     * to bridge an amount of ETH to the caller's balance on L2.
     * Since the receive function doesn't take data, a conservative
     * default amount is forwarded to L2.
     */
    receive() external payable onlyEOA {
        _initiateETHBridge(msg.sender, msg.sender, 0, 200_000, bytes(""));
    }

    /**
     * @inheritdoc IL1StandardBridge
     */
    function bridgeETH(
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external payable onlyEOA {
        _initiateETHBridge(msg.sender, msg.sender, _localGasLimit, _remoteGasLimit, _data);
    }

    /**
     * @inheritdoc IL1StandardBridge
     */
    function bridgeETHTo(
        address _to,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external payable {
        _initiateETHBridge(msg.sender, _to, _localGasLimit, _remoteGasLimit, _data);
    }

    /**
     * @dev Performs the logic for bridging by storing the ETH and informing the L2 ETH Gateway of
     * the bridge.
     * @param _from Account to pull the ETH from on L1.
     * @param _to Account to give the ETH to on L2.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function _initiateETHBridge(
        address _from,
        address _to,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes memory _data
    ) internal {
        // Construct calldata for finalizeBridge call
        bytes memory message = abi.encodeWithSelector(
            IL2ERC20Bridge.finalizeBridge.selector,
            address(0),
            Lib_PredeployAddresses.NVM_ETH,
            _from,
            _to,
            msg.value,
            _localGasLimit,
            _remoteGasLimit,
            _data
        );

        // Send calldata into L2
        // slither-disable-next-line reentrancy-events
        sendCrossDomainMessage(remoteTokenBridge, _remoteGasLimit, message);

        // slither-disable-next-line reentrancy-events
        emit ETHBridgeInitiated(_from, _to, msg.value, _localGasLimit, _remoteGasLimit, _data);
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     */
    function bridgeERC20(
        address _localToken,
        address _remoteToken,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external virtual onlyEOA {
        _initiateERC20Bridge(
            _localToken,
            _remoteToken,
            msg.sender,
            msg.sender,
            _amount,
            _localGasLimit,
            _remoteGasLimit,
            _data
        );
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     */
    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external virtual {
        _initiateERC20Bridge(
            _localToken,
            _remoteToken,
            msg.sender,
            _to,
            _amount,
            _localGasLimit,
            _remoteGasLimit,
            _data
        );
    }

    /**
     * @dev Performs the logic for bridging by informing the remote bridge
     * contract of the bridge and lock or burn the local funds.
     * @param _localToken Address of the L1 ERC20 we are bridging
     * @param _remoteToken Address of the L1 respective L2 ERC20
     * @param _from Account to pull the ERC20 from on L1
     * @param _to Account to give the ERC20 to on L2
     * @param _amount Amount of the ERC20 to bridge.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function _initiateERC20Bridge(
        address _localToken,
        address _remoteToken,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) internal {
        if (ERC165Checker.supportsInterface(_localToken, type(INahmiiStandardERC20).interfaceId)) {
            // Check that the remote token is a match of the local token
            require(
                _remoteToken == INahmiiStandardERC20(_localToken).remoteToken(),
                "L1StandardBridge: remote token does not match given value"
            );

            // When a bridge operation is initiated, we burn the sender's local funds.
            // slither-disable-next-line reentrancy-events
            INahmiiStandardERC20(_localToken).burn(_from, _amount);
        } else {
            // When a bridge operation is initiated, the transfer the sender's local funds to
            // this bridge.
            // to itself for future local bridge operation finalizations.
            // slither-disable-next-line reentrancy-events, reentrancy-benign
            IERC20(_localToken).safeTransferFrom(_from, address(this), _amount);

            // Mark that the amount of this local/remote token pair is escrowed in
            // this bridge
            // slither-disable-next-line reentrancy-benign
            locks[_localToken][_remoteToken] = locks[_localToken][_remoteToken] + _amount;
        }

        // Construct calldata for l2ERC20Bridge.finalizeBridge(...)
        bytes memory message = abi.encodeWithSelector(
            IL2ERC20Bridge.finalizeBridge.selector,
            _localToken,
            _remoteToken,
            _from,
            _to,
            _amount,
            _localGasLimit,
            _remoteGasLimit,
            _data
        );

        // Send calldata into L2
        // slither-disable-next-line reentrancy-events, reentrancy-benign
        sendCrossDomainMessage(remoteTokenBridge, _remoteGasLimit, message);

        // slither-disable-next-line reentrancy-events
        emit ERC20BridgeInitiated(
            _localToken,
            _remoteToken,
            _from,
            _to,
            _amount,
            _localGasLimit,
            _remoteGasLimit,
            _data
        );
    }

    /*************************
     * Cross-chain Functions *
     *************************/

    /**
     * @inheritdoc IL1StandardBridge
     */
    function finalizeETHBridge(
        address _from,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external onlyFromCrossDomainAccount(remoteTokenBridge) {
        // slither-disable-next-line reentrancy-events
        (bool success, ) = _to.call{ value: _amount }(new bytes(0));
        if (success) {
            // slither-disable-next-line reentrancy-events
            emit ETHBridgeFinalized(_from, _to, _amount, _localGasLimit, _remoteGasLimit, _data);
        } else {
            // Construct calldata for l2ERC20Bridge.finalizeBridge(...)
            bytes memory message = abi.encodeWithSelector(
                IL2ERC20Bridge.finalizeBridge.selector,
                address(0),
                Lib_PredeployAddresses.NVM_ETH,
                _to,
                _from,
                _amount,
                _localGasLimit,
                _remoteGasLimit,
                _data
            );

            // Send calldata into L2
            // slither-disable-next-line reentrancy-events
            sendCrossDomainMessage(remoteTokenBridge, _remoteGasLimit, message);

            // slither-disable-next-line reentrancy-events
            emit ETHBridgeFailed(_from, _to, _amount, _localGasLimit, _remoteGasLimit, _data);
        }
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     */
    function finalizeERC20Bridge(
        address _localToken,
        address _remoteToken,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external onlyFromCrossDomainAccount(remoteTokenBridge) {
        require(_localToken != address(this), "L1StandardBridge: local token cannot be self");

        if (
            ERC165Checker.supportsInterface(_localToken, type(INahmiiStandardERC20).interfaceId) &&
            _remoteToken == INahmiiStandardERC20(_localToken).remoteToken()
        ) {
            // When a bridge operation is finalized, we mint local funds to the recipient.
            INahmiiStandardERC20(_localToken).mint(_to, _amount);

            // slither-disable-next-line reentrancy-events
            emit ERC20BridgeFinalized(
                _localToken,
                _remoteToken,
                _from,
                _to,
                _amount,
                _localGasLimit,
                _remoteGasLimit,
                _data
            );
        } else if (locks[_localToken][_remoteToken] >= _amount) {
            // Mark that the amount of local/remote token pair is no longer escrowed in
            // this bridge
            locks[_localToken][_remoteToken] = locks[_localToken][_remoteToken] - _amount;

            // When a bridge operation is finalized, we transfer the funds to the recipient.
            IERC20(_localToken).safeTransfer(_to, _amount);

            // slither-disable-next-line reentrancy-events
            emit ERC20BridgeFinalized(
                _localToken,
                _remoteToken,
                _from,
                _to,
                _amount,
                _localGasLimit,
                _remoteGasLimit,
                _data
            );
        } else {
            // This case could happen if there is a malicious local token, or if a user somehow
            // specified the wrong local token address to bridge into.
            // In either case, we stop the process here and construct a message to
            // bridge to the remote domain so that users can get their funds out in some cases.
            // There is no way to prevent malicious token contracts altogether, but this does limit
            // user error and mitigate some forms of malicious contract behavior.

            // Construct calldata for l2ERC20Bridge.finalizeBridge(...)
            bytes memory message = abi.encodeWithSelector(
                IL2ERC20Bridge.finalizeBridge.selector,
                _localToken,
                _remoteToken,
                _to,
                _from,
                _amount,
                _localGasLimit,
                _remoteGasLimit,
                _data
            );

            // Send message to L2 bridge
            // slither-disable-next-line reentrancy-events, reentrancy-benign
            sendCrossDomainMessage(remoteTokenBridge, _remoteGasLimit, message);

            // slither-disable-next-line reentrancy-events
            emit ERC20BridgeFailed(
                _localToken,
                _remoteToken,
                _from,
                _to,
                _amount,
                _localGasLimit,
                _remoteGasLimit,
                _data
            );
        }
    }

    /*****************************
     * Temporary - Migrating ETH *
     *****************************/

    /**
     * @dev Adds ETH balance to the account. This is meant to allow for ETH
     * to be migrated from an old gateway to a new gateway.
     * NOTE: This is left for one upgrade only so we are able to receive the migrated ETH from the
     * old contract
     */
    function donateETH() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.9.0;

import "./IL1ERC20Bridge.sol";

/**
 * @title IL1StandardBridge
 */
interface IL1StandardBridge is IL1ERC20Bridge {
    /**********
     * Events *
     **********/

    event ETHBridgeInitiated(
        address indexed _from,
        address indexed _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes _data
    );

    event ETHBridgeFinalized(
        address indexed _from,
        address indexed _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes _data
    );

    event ETHBridgeFailed(
        address indexed _from,
        address indexed _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes _data
    );

    /********************
     * Public Functions *
     ********************/

    /**
     * @dev Initiate a bridge of an amount of the ETH to the caller's balance on L2.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function bridgeETH(
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external payable;

    /**
     * @dev Initiate a bridge of an amount of ETH to a recipient's balance on L2.
     * @param _to L2 address to credit the withdrawal to.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function bridgeETHTo(
        address _to,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external payable;

    /*************************
     * Cross-chain Functions *
     *************************/

    /**
     * @dev Finalize a bridge from L2 to L1, and credit funds to the recipient's balance of the
     * L1 ETH token. Since only the xDomainMessenger can call this function, it will never be called
     * before the bridge is finalized.
     * @param _from L2 address initiating the transfer.
     * @param _to L1 address to credit the ERC20 to.
     * @param _amount Amount of the ERC20 to bridge.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function finalizeETHBridge(
        address _from,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.9.0;

/**
 * @title IL1ERC20Bridge
 */
interface IL1ERC20Bridge {
    /**********
     * Events *
     **********/

    event ERC20BridgeInitiated(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        uint32 localGasLimit,
        uint32 remoteGasLimit,
        bytes data
    );

    event ERC20BridgeFinalized(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        uint32 localGasLimit,
        uint32 remoteGasLimit,
        bytes data
    );

    event ERC20BridgeFailed(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        uint32 localGasLimit,
        uint32 remoteGasLimit,
        bytes data
    );

    /********************
     * Public Functions *
     ********************/

    /**
     * @dev get the address of the corresponding L2 bridge contract.
     * @return Address of the corresponding L2 bridge contract.
     */
    function remoteTokenBridge() external returns (address);

    /**
     * @dev Initiate a bridge of an amount of the ERC20 to the caller's balance on L2.
     * @param _localToken Address of the L1 ERC20 we are bridging
     * @param _remoteToken Address of the L1 respective L2 ERC20
     * @param _amount Amount of the ERC20 to bridge
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function bridgeERC20(
        address _localToken,
        address _remoteToken,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external;

    /**
     * @dev Initiate a bridge of an amount of ERC20 to a recipient's balance on L2.
     * @param _localToken Address of the L1 ERC20 we are bridging
     * @param _remoteToken Address of the L1 respective L2 ERC20
     * @param _to L2 address to credit the ERC20 to.
     * @param _amount Amount of the ERC20 to bridge.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external;

    /*************************
     * Cross-chain Functions *
     *************************/

    /**
     * @dev Finalize a bridge from L2 to L1, and credit funds to the recipient's balance of the
     * L1 ERC20 token.
     * @param _localToken Address of L1 token to finalizeBridge for.
     * @param _remoteToken Address of L2 token where bridge was initiated.
     * @param _from L2 address initiating the transfer.
     * @param _to L1 address to credit the ERC20 to.
     * @param _amount Amount of the ERC20 to bridge.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Data provided by the sender on L2. This data is provided
     *   solely as a convenience for external contracts. Aside from enforcing a maximum
     *   length, these contracts provide no guarantees about its content.
     */
    function finalizeERC20Bridge(
        address _localToken,
        address _remoteToken,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title IL2ERC20Bridge
 */
interface IL2ERC20Bridge {
    /**********
     * Events *
     **********/

    event BridgeInitiated(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        uint32 localGasLimit,
        uint32 remoteGasLimit,
        bytes data
    );

    event BridgeFinalized(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        uint32 localGasLimit,
        uint32 remoteGasLimit,
        bytes data
    );

    event BridgeFailed(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        uint32 localGasLimit,
        uint32 remoteGasLimit,
        bytes data
    );

    /********************
     * Public Functions *
     ********************/

    /**
     * @dev Get the address of the corresponding L1 bridge contract.
     * @return Address of the corresponding L1 bridge contract.
     */
    function remoteTokenBridge() external returns (address);

    /**
     * @dev Initiate a bridge of some tokens to the caller's account on L1.
     * @param _localToken Address of L2 ERC20 we are bridging.
     * @param _remoteToken Address of the L1 respective L2 ERC20.
     * @param _amount Amount of the token to withdraw.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function bridge(
        address _localToken,
        address _remoteToken,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external;

    /**
     * @dev Initiate a bridge of some token to a recipient's account on L1.
     * @param _localToken Address of L2 ERC20 we are bridging.
     * @param _remoteToken Address of the L1 respective L2 ERC20.
     * @param _to L1 address to credit the withdrawal to.
     * @param _amount Amount of the token to withdraw.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _data Optional data to forward to L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function bridgeTo(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _localGasLimit,
        uint32 _remoteGasLimit,
        bytes calldata _data
    ) external;

    /*************************
     * Cross-chain Functions *
     *************************/

    /**
     * @dev Finalize a bridge from L1 to L2, and credits funds to the recipient's balance of this
     * L2 token.
     * @param _remoteToken Address for the l1 token this is called with
     * @param _localToken Address for the l2 token this is called with
     * @param _from Account to pull the deposit from on L2.
     * @param _to Address to receive the withdrawal at
     * @param _amount Amount of the token to withdraw
     * @param _remoteGasLimit Minimum gas limit for the bridge message on the other domain.
     * @param _localGasLimit Minimum gas limit for the reverse bridge message on this domain.
     * @param _data Data provider by the sender on L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function finalizeBridge(
        address _remoteToken,
        address _localToken,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _remoteGasLimit,
        uint32 _localGasLimit,
        bytes calldata _data
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface INahmiiStandardERC20 is IERC20, IERC165 {
    function remoteToken() external returns (address);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;

    function native() external returns (bool);

    /**
     * @notice Initializes a NahmiiStandardERC20 token with the provided args
     *
     * @param _localBridge   Address of the bridge on this network.
     * @param _remoteToken   Address of the NahmiiStandardERC20 token on the other network.
     */
    function initialize(address _localBridge, address _remoteToken) external;

    event Mint(address indexed _account, uint256 _amount);
    event Burn(address indexed _account, uint256 _amount);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.9.0;

/* Interface Imports */
import { ICrossDomainMessenger } from "./ICrossDomainMessenger.sol";

/**
 * @title CrossDomainEnabled
 * @dev Helper contract for contracts performing cross-domain communications
 *
 * Compiler used: defined by inheriting contract
 */
contract CrossDomainEnabled {
    /*************
     * Variables *
     *************/

    // Messenger contract used to send and recieve messages from the other domain.
    address public messenger;

    /***************
     * Constructor *
     ***************/

    /**
     * @param _messenger Address of the CrossDomainMessenger on the current layer.
     */
    constructor(address _messenger) {
        messenger = _messenger;
    }

    /**********************
     * Function Modifiers *
     **********************/

    /**
     * Enforces that the modified function is only callable by a specific cross-domain account.
     * @param _sourceDomainAccount The only account on the originating domain which is
     *  authenticated to call this function.
     */
    modifier onlyFromCrossDomainAccount(address _sourceDomainAccount) {
        require(
            msg.sender == address(getCrossDomainMessenger()),
            "NVM_XCHAIN: messenger contract unauthenticated"
        );

        require(
            getCrossDomainMessenger().xDomainMessageSender() == _sourceDomainAccount,
            "NVM_XCHAIN: wrong sender of cross-domain message"
        );

        _;
    }

    /**********************
     * Internal Functions *
     **********************/

    /**
     * Gets the messenger, usually from storage. This function is exposed in case a child contract
     * needs to override.
     * @return The address of the cross-domain messenger contract which should be used.
     */
    function getCrossDomainMessenger() internal virtual returns (ICrossDomainMessenger) {
        return ICrossDomainMessenger(messenger);
    }

    /**q
     * Sends a message to an account on another domain
     * @param _crossDomainTarget The intended recipient on the destination domain
     * @param _message The data to send to the target (usually calldata to a function with
     *  `onlyFromCrossDomainAccount()`)
     * @param _gasLimit The gasLimit for the receipt of the message on the target domain.
     */
    function sendCrossDomainMessage(
        address _crossDomainTarget,
        uint32 _gasLimit,
        bytes memory _message
    ) internal {
        // slither-disable-next-line reentrancy-events, reentrancy-benign
        getCrossDomainMessenger().sendMessage(_crossDomainTarget, _message, _gasLimit);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title Lib_PredeployAddresses
 */
library Lib_PredeployAddresses {
    address internal constant L2_TO_L1_MESSAGE_PASSER = 0x4200000000000000000000000000000000000000;
    address internal constant L1_MESSAGE_SENDER = 0x4200000000000000000000000000000000000001;
    address internal constant DEPLOYER_WHITELIST = 0x4200000000000000000000000000000000000002;
    address payable internal constant NVM_ETH = payable(0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000);
    address internal constant L2_CROSS_DOMAIN_MESSENGER =
        0x4200000000000000000000000000000000000007;
    address internal constant LIB_ADDRESS_MANAGER = 0x4200000000000000000000000000000000000008;
    address internal constant PROXY_EOA = 0x4200000000000000000000000000000000000009;
    address internal constant L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;
    address internal constant SEQUENCER_FEE_WALLET = 0x4200000000000000000000000000000000000011;
    address internal constant NAHMII_STANDARD_ERC20_FACTORY =
        0x4200000000000000000000000000000000000012;
    address internal constant L1_BLOCK_NUMBER = 0x4200000000000000000000000000000000000013;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
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
        return functionCall(target, data, "Address: low-level call failed");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

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

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165Checker {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface,
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return
            _supportsERC165Interface(account, type(IERC165).interfaceId) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) && _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds)
        internal
        view
        returns (bool[] memory)
    {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in _interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);
        (bool success, bytes memory result) = account.staticcall{gas: 30000}(encodedParams);
        if (result.length < 32) return false;
        return success && abi.decode(result, (bool));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.9.0;

/**
 * @title ICrossDomainMessenger
 */
interface ICrossDomainMessenger {
    /**********
     * Events *
     **********/

    event SentMessage(
        address indexed target,
        address sender,
        bytes message,
        uint256 messageNonce,
        uint256 gasLimit
    );
    event RelayedMessage(bytes32 indexed msgHash);
    event FailedRelayedMessage(bytes32 indexed msgHash);

    /*************
     * Variables *
     *************/

    function xDomainMessageSender() external view returns (address);

    /********************
     * Public Functions *
     ********************/

    /**
     * Sends a cross domain message to the target messenger.
     * @param _target Target contract address.
     * @param _message Message to send to the target.
     * @param _gasLimit Gas limit for the provided message.
     */
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}