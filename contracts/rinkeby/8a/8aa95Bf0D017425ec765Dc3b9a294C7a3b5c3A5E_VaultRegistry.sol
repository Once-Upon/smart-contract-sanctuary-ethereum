// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/src/ClonesWithImmutableArgs.sol";
import {FERC1155} from "./FERC1155.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IVaultRegistry, VaultInfo} from "./interfaces/IVaultRegistry.sol";
import {VaultFactory} from "./VaultFactory.sol";

/// @title Vault Registry
/// @author Fractional Art
/// @notice Registry contract for tracking all fractional vaults
contract VaultRegistry is IVaultRegistry {
    /// @dev Use clones library with address types
    using ClonesWithImmutableArgs for address;
    /// @notice Address of VaultFactory contract
    address public immutable factory;
    /// @notice Address of FERC1155 token contract
    address public immutable fNFT;
    /// @notice Address of Implementation for FERC1155 token contract
    address public immutable fNFTImplementation;
    /// @notice Mapping of collection address to next token ID type
    mapping(address => uint256) public nextId;
    /// @notice Mapping of vault address to vault information
    mapping(address => VaultInfo) public vaultToToken;

    /// @notice Initializes factory, implementation, and token contracts
    constructor() {
        factory = address(new VaultFactory());
        fNFTImplementation = address(new FERC1155());
        fNFT = fNFTImplementation.clone(
            abi.encodePacked(msg.sender, address(this))
        );
    }

    /// @notice Burns vault tokens
    /// @param _from Source address
    /// @param _value Amount of tokens
    function burn(address _from, uint256 _value) external {
        VaultInfo memory info = vaultToToken[msg.sender];
        uint256 id = info.id;
        if (id == 0) revert UnregisteredVault(msg.sender);
        FERC1155(info.token).burn(_from, id, _value);
    }

    /// @notice Creates a new vault with permissions and plugins
    /// @param _merkleRoot Hash of merkle root for vault permissions
    /// @param _plugins Addresses of plugin contracts
    /// @param _selectors List of function selectors
    /// @return vault Address of Proxy contract
    function create(
        bytes32 _merkleRoot,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault) {
        vault = _deployVault(_merkleRoot, address(fNFT), _plugins, _selectors);
    }

    /// @notice Creates a new vault with permissions and plugins, and transfers ownership to a given owner
    /// @dev This should only be done in limited cases i.e. if you're okay with a trusted individual(s)
    /// having control over the vault. Ideally, execution would be locked behind a Multisig wallet.
    /// @param _merkleRoot Hash of merkle root for vault permissions
    /// @param _owner Address of the vault owner
    /// @param _plugins Addresses of plugin contracts
    /// @param _selectors List of function selectors
    /// @return vault Address of Proxy contract
    function createFor(
        bytes32 _merkleRoot,
        address _owner,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault) {
        vault = _deployVault(_merkleRoot, address(fNFT), _plugins, _selectors);
        IVault(vault).transferOwnership(_owner);
    }

    /// @notice Creates a new vault with permissions and plugins for the message sender
    /// @param _merkleRoot Hash of merkle root for vault permissions
    /// @param _plugins Addresses of plugin contracts
    /// @param _selectors List of function selectors
    /// @return vault Address of Proxy contract
    /// @return token Address of FERC1155 contract
    function createCollection(
        bytes32 _merkleRoot,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault, address token) {
        (vault, token) = createCollectionFor(
            _merkleRoot,
            msg.sender,
            _plugins,
            _selectors
        );
    }

    /// @notice Creates a new vault with permissions and plugins for an existing collection
    /// @param _merkleRoot Hash of merkle root for vault permissions
    /// @param _token Address of FERC1155 contract
    /// @param _plugins Addresses of plugin contracts
    /// @param _selectors List of function selectors
    /// @return vault Address of Proxy contract
    function createInCollection(
        bytes32 _merkleRoot,
        address _token,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault) {
        address controller = FERC1155(_token).controller();
        if (controller != msg.sender)
            revert InvalidController(controller, msg.sender);
        vault = _deployVault(_merkleRoot, _token, _plugins, _selectors);
    }

    /// @notice Mints vault tokens
    /// @param _to Target address
    /// @param _value Amount of tokens
    function mint(address _to, uint256 _value) external {
        VaultInfo memory info = vaultToToken[msg.sender];
        uint256 id = info.id;
        if (id == 0) revert UnregisteredVault(msg.sender);
        FERC1155(info.token).mint(_to, id, _value, "");
    }

    /// @notice Gets the total supply for a token and ID associated with a vault
    /// @param _vault Address of the vault
    /// @return Total supply
    function totalSupply(address _vault) external view returns (uint256) {
        VaultInfo memory info = vaultToToken[_vault];
        return FERC1155(info.token).totalSupply(info.id);
    }

    /// @notice Gets the uri for a given token and ID associated with a vault
    /// @param _vault Address of the vault
    /// @return URI of token
    function uri(address _vault) external view returns (string memory) {
        VaultInfo memory info = vaultToToken[_vault];
        return FERC1155(info.token).uri(info.id);
    }

    /// @notice Creates a new vault with permissions and plugins for a given controller
    /// @param _merkleRoot Hash of merkle root for vault permissions
    /// @param _controller Address of token controller
    /// @param _plugins Addresses of plugin contracts
    /// @param _selectors List of function selectors
    /// @return vault Address of Proxy contract
    /// @return token Address of FERC1155 contract
    function createCollectionFor(
        bytes32 _merkleRoot,
        address _controller,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) public returns (address vault, address token) {
        token = fNFTImplementation.clone(
            abi.encodePacked(_controller, address(this))
        );
        vault = _deployVault(_merkleRoot, token, _plugins, _selectors);
    }

    /// @dev Deploys new vault for specified token, sets merkle root, and installs plugins
    /// @param _merkleRoot Hash of merkle root for vault permissions
    /// @param _token Address of FERC1155 contract
    /// @param _plugins Addresses of plugin contracts
    /// @param _selectors List of function selectors
    /// @return vault Address of Proxy contract
    function _deployVault(
        bytes32 _merkleRoot,
        address _token,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) private returns (address vault) {
        vault = VaultFactory(factory).deploy();
        vaultToToken[vault] = VaultInfo(_token, ++nextId[_token]);
        IVault(vault).setMerkleRoot(_merkleRoot);
        IVault(vault).install(_selectors, _plugins);

        emit VaultDeployed(vault, _token, nextId[_token]);
    }
}

// SPDX-License-Identifier: BSD

pragma solidity ^0.8.4;

/// @title ClonesWithImmutableArgs
/// @author wighawag, zefram.eth
/// @notice Enables creating clone contracts with immutable args
library ClonesWithImmutableArgs {
    error CreateFail();

    /// @notice Creates a clone proxy of the implementation contract, with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function clone(address implementation, bytes memory data)
        internal
        returns (address payable instance)
    {
        // unrealistic for memory ptr or data length to exceed 256 bits
        unchecked {
            uint256 extraLength = data.length + 2; // +2 bytes for telling how much data there is appended to the call
            uint256 creationSize = 0x41 + extraLength;
            uint256 runSize = creationSize - 10;
            uint256 dataPtr;
            uint256 ptr;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                ptr := mload(0x40)

                // -------------------------------------------------------------------------------------------------------------
                // CREATION (10 bytes)
                // -------------------------------------------------------------------------------------------------------------

                // 61 runtime  | PUSH2 runtime (r)     | r                       | –
                mstore(
                    ptr,
                    0x6100000000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x01), shl(240, runSize)) // size of the contract running bytecode (16 bits)

                // creation size = 0a
                // 3d          | RETURNDATASIZE        | 0 r                     | –
                // 81          | DUP2                  | r 0 r                   | –
                // 60 creation | PUSH1 creation (c)    | c r 0 r                 | –
                // 3d          | RETURNDATASIZE        | 0 c r 0 r               | –
                // 39          | CODECOPY              | 0 r                     | [0-runSize): runtime code
                // f3          | RETURN                |                         | [0-runSize): runtime code

                // -------------------------------------------------------------------------------------------------------------
                // RUNTIME (55 bytes + extraLength)
                // -------------------------------------------------------------------------------------------------------------

                // 3d          | RETURNDATASIZE        | 0                       | –
                // 3d          | RETURNDATASIZE        | 0 0                     | –
                // 3d          | RETURNDATASIZE        | 0 0 0                   | –
                // 3d          | RETURNDATASIZE        | 0 0 0 0                 | –
                // 36          | CALLDATASIZE          | cds 0 0 0 0             | –
                // 3d          | RETURNDATASIZE        | 0 cds 0 0 0 0           | –
                // 3d          | RETURNDATASIZE        | 0 0 cds 0 0 0 0         | –
                // 37          | CALLDATACOPY          | 0 0 0 0                 | [0, cds) = calldata
                // 61          | PUSH2 extra           | extra 0 0 0 0           | [0, cds) = calldata
                mstore(
                    add(ptr, 0x03),
                    0x3d81600a3d39f33d3d3d3d363d3d376100000000000000000000000000000000
                )
                mstore(add(ptr, 0x13), shl(240, extraLength))

                // 60 0x37     | PUSH1 0x37            | 0x37 extra 0 0 0 0      | [0, cds) = calldata // 0x37 (55) is runtime size - data
                // 36          | CALLDATASIZE          | cds 0x37 extra 0 0 0 0  | [0, cds) = calldata
                // 39          | CODECOPY              | 0 0 0 0                 | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 36          | CALLDATASIZE          | cds 0 0 0 0             | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 61 extra    | PUSH2 extra           | extra cds 0 0 0 0       | [0, cds) = calldata, [cds, cds+0x37) = extraData
                mstore(
                    add(ptr, 0x15),
                    0x6037363936610000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x1b), shl(240, extraLength))

                // 01          | ADD                   | cds+extra 0 0 0 0       | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | 0 cds 0 0 0 0           | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 73 addr     | PUSH20 0x123…         | addr 0 cds 0 0 0 0      | [0, cds) = calldata, [cds, cds+0x37) = extraData
                mstore(
                    add(ptr, 0x1d),
                    0x013d730000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x20), shl(0x60, implementation))

                // 5a          | GAS                   | gas addr 0 cds 0 0 0 0  | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // f4          | DELEGATECALL          | success 0 0             | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | rds success 0 0         | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | rds rds success 0 0     | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 93          | SWAP4                 | 0 rds success 0 rds     | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 80          | DUP1                  | 0 0 rds success 0 rds   | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3e          | RETURNDATACOPY        | success 0 rds           | [0, rds) = return data (there might be some irrelevant leftovers in memory [rds, cds+0x37) when rds < cds+0x37)
                // 60 0x35     | PUSH1 0x35            | 0x35 sucess 0 rds       | [0, rds) = return data
                // 57          | JUMPI                 | 0 rds                   | [0, rds) = return data
                // fd          | REVERT                | –                       | [0, rds) = return data
                // 5b          | JUMPDEST              | 0 rds                   | [0, rds) = return data
                // f3          | RETURN                | –                       | [0, rds) = return data
                mstore(
                    add(ptr, 0x34),
                    0x5af43d3d93803e603557fd5bf300000000000000000000000000000000000000
                )
            }

            // -------------------------------------------------------------------------------------------------------------
            // APPENDED DATA (Accessible from extcodecopy)
            // (but also send as appended data to the delegatecall)
            // -------------------------------------------------------------------------------------------------------------

            extraLength -= 2;
            uint256 counter = extraLength;
            uint256 copyPtr = ptr + 0x41;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                dataPtr := add(data, 32)
            }
            for (; counter >= 32; counter -= 32) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    mstore(copyPtr, mload(dataPtr))
                }

                copyPtr += 32;
                dataPtr += 32;
            }
            uint256 mask = ~(256**(32 - counter) - 1);
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(copyPtr, and(mload(dataPtr), mask))
            }
            copyPtr += counter;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(copyPtr, shl(240, extraLength))
            }
            // solhint-disable-next-line no-inline-assembly
            assembly {
                instance := create(0, ptr, creationSize)
            }
            if (instance == address(0)) {
                revert CreateFail();
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Clone} from "clones-with-immutable-args/src/Clone.sol";
import {ERC1155} from "@rari-capital/solmate/src/tokens/ERC1155.sol";
import {IFERC1155} from "./interfaces/IFERC1155.sol";
import {INFTReceiver} from "./interfaces/INFTReceiver.sol";
import "./constants/Permit.sol";

/// @title FERC1155
/// @author Fractional Art
/// @notice An ERC-1155 implementation for Fractions
contract FERC1155 is Clone, ERC1155, IFERC1155 {
    /// @notice Name of the token contract
    string public constant NAME = "FERC1155";
    /// @notice Version number of the token contract
    string public constant VERSION = "1";
    /// @notice Address that can deploy new vaults for this collection, manage metadata, etc
    address internal _controller;
    /// @notice URI of contract metadata
    string public contractURI;
    /// @notice Mapping of token type approvals owner => operator => tokenId => approved
    mapping(address => mapping(address => mapping(uint256 => bool)))
        public isApproved;
    /// @notice Mapping of metadata contracts for token ID types => metadata address
    mapping(uint256 => address) public metadata;
    /// @notice Mapping to track account nonces for metadata txs owner => nonces
    mapping(address => uint256) public nonces;
    /// @notice Mapping to track total supply for token ID types => totalSupply
    mapping(uint256 => uint256) public totalSupply;
    /// @notice Mapping to track royalty receivers for token ID types => royaltyAddress
    mapping(uint256 => address) private royaltyAddress;
    /// @notice Mapping to track the royalty percent for token ID types => royaltyPercent
    mapping(uint256 => uint256) private royaltyPercent;

    /// @notice Modifier for restricting function calls to the controller account
    modifier onlyController() {
        address controller_ = controller();
        if (msg.sender != controller_)
            revert InvalidSender(controller_, msg.sender);
        _;
    }

    /// @notice Modifier for restricting function calls to the VaultRegistry
    modifier onlyRegistry() {
        address vaultRegistry = VAULT_REGISTRY();
        if (msg.sender != vaultRegistry)
            revert InvalidSender(vaultRegistry, msg.sender);
        _;
    }

    /// @notice Burns fractions for an ID
    /// @param _from Address to burn fraction tokens from
    /// @param _id Token ID to burn
    /// @param _amount Number of tokens to burn
    function burn(
        address _from,
        uint256 _id,
        uint256 _amount
    ) external onlyRegistry {
        _burn(_from, _id, _amount);
        totalSupply[_id] -= _amount;
    }

    /// @notice Hook to emit the URI update when setting the metadata or updating
    /// @param _id Token ID metadata was updated for
    /// @param _uri URI of metadata
    function emitSetURI(uint256 _id, string memory _uri) external {
        if (msg.sender != metadata[_id])
            revert InvalidSender(metadata[_id], msg.sender);
        emit URI(_uri, _id);
    }

    /// @notice Mints new fractions for an ID
    /// @param _to Address to mint fraction tokens to
    /// @param _id Token ID to mint
    /// @param _amount Number of tokens to mint
    /// @param _data Extra calldata to include in the mint
    function mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external onlyRegistry {
        _mint(_to, _id, _amount, _data);
        totalSupply[_id] += _amount;
    }

    /// @notice Permit function that approves an operator for token type with a valid signature
    /// @param _owner Address of the owner of the token type
    /// @param _operator Address of the spender of the token type
    /// @param _id ID of the token type
    /// @param _approved Approval status for the token type
    /// @param _deadline Expiration of the signature
    /// @param _v The recovery ID (129th byte and chain ID) of the signature used to recover the signer
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function permit(
        address _owner,
        address _operator,
        uint256 _id,
        bool _approved,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (block.timestamp > _deadline)
            revert SignatureExpired(block.timestamp, _deadline);

        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 structHash = _computePermitStructHash(
                _owner,
                _operator,
                _id,
                _approved,
                _deadline
            );

            bytes32 digest = _computeDigest(
                _computeDomainSeparator(),
                structHash
            );

            address signer = ecrecover(digest, _v, _r, _s);

            if (signer == address(0) || signer != _owner)
                revert InvalidSignature(signer, _owner);
        }

        isApproved[_owner][_operator][_id] = _approved;

        emit SingleApproval(_owner, _operator, _id, _approved);
    }

    /// @notice Permit function that approves an operator for all token types with a valid signature
    /// @param _owner Address of the owner of the token type
    /// @param _operator Address of the spender of the token type
    /// @param _approved Approval status for the token type
    /// @param _deadline Expiration of the signature
    /// @param _v The recovery ID (129th byte and chain ID) of the signature used to recover the signer
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function permitAll(
        address _owner,
        address _operator,
        bool _approved,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (block.timestamp > _deadline)
            revert SignatureExpired(block.timestamp, _deadline);

        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 structHash = _computePermitAllStructHash(
                _owner,
                _operator,
                _approved,
                _deadline
            );

            bytes32 digest = _computeDigest(
                _computeDomainSeparator(),
                structHash
            );

            address signer = ecrecover(digest, _v, _r, _s);

            if (signer == address(0) || signer != _owner)
                revert InvalidSignature(signer, _owner);
        }

        isApprovedForAll[_owner][_operator] = _approved;

        emit ApprovalForAll(_owner, _operator, _approved);
    }

    /// @notice Scoped approvals allow us to eliminate some of the risks associated with setting the approval for an entire collection
    /// @param _operator Address of spender account
    /// @param _id ID of the token type
    /// @param _approved Approval status for operator(spender) account
    function setApprovalFor(
        address _operator,
        uint256 _id,
        bool _approved
    ) external {
        isApproved[msg.sender][_operator][_id] = _approved;

        emit SingleApproval(msg.sender, _operator, _id, _approved);
    }

    /// @notice Sets the contract metadata
    /// @param _uri URI of metadata
    function setContractURI(string calldata _uri) external onlyController {
        contractURI = _uri;
    }

    /// @notice Sets the token metadata contract
    /// @param _metadata Address for metadata contract
    /// @param _id Token ID to set the metadata for
    function setMetadata(address _metadata, uint256 _id)
        external
        onlyController
    {
        metadata[_id] = _metadata;
        emit SetMetadata(_metadata, _id);
    }

    /// @notice Sets the token royalties
    /// @param _id Token ID royalties are being updated for
    /// @param _receiver Address to receive royalties
    /// @param _percentage Percentage of royalties on secondary sales
    function setRoyalties(
        uint256 _id,
        address _receiver,
        uint256 _percentage
    ) external onlyController {
        royaltyAddress[_id] = _receiver;
        royaltyPercent[_id] = _percentage;
        emit SetRoyalty(_receiver, _id, _percentage);
    }

    /// @notice Updates the controller address for the FERC1155 token contract
    /// @param _newController Address of new controlling entity
    function transferController(address _newController)
        external
        onlyController
    {
        if (_newController == address(0)) revert ZeroAddress();
        _controller = _newController;
        emit ControllerTransferred(_newController);
    }

    /// @notice Sets the token royalties
    /// @param _id Token ID royalties are being updated for
    /// @param _salePrice Sale price to calculate the royalty for
    function royaltyInfo(uint256 _id, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = royaltyAddress[_id];
        royaltyAmount = (_salePrice * royaltyPercent[_id]) / 100;
    }

    /// @notice Transfer an amount of a token type between two accounts
    /// @param _from Source address for an amount of tokens
    /// @param _to Destination address for an amount of tokens
    /// @param _id ID of the token type
    /// @param _amount The amount of tokens being transferred
    /// @param _data Additional calldata
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public override(ERC1155, IFERC1155) {
        require(
            msg.sender == _from ||
                isApprovedForAll[_from][msg.sender] ||
                isApproved[_from][msg.sender][_id],
            "NOT_AUTHORIZED"
        );

        balanceOf[_from][_id] -= _amount;
        balanceOf[_to][_id] += _amount;

        emit TransferSingle(msg.sender, _from, _to, _id, _amount);

        require(
            _to.code.length == 0
                ? _to != address(0)
                : INFTReceiver(_to).onERC1155Received(
                    msg.sender,
                    _from,
                    _id,
                    _amount,
                    _data
                ) == INFTReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /// @notice Getter for URI of a token type
    /// @param _id ID of the token type
    function uri(uint256 _id)
        public
        view
        override(ERC1155, IFERC1155)
        returns (string memory)
    {
        require(metadata[_id] != address(0), "NO METADATA");
        return IFERC1155(metadata[_id]).uri(_id);
    }

    /// @notice Getter for controller account
    function controller() public view returns (address controllerAddress) {
        _controller == address(0)
            ? controllerAddress = INITIAL_CONTROLLER()
            : controllerAddress = _controller;
    }

    /// @notice Getter for initial controller account immutable argument stored in calldata
    function INITIAL_CONTROLLER() public pure returns (address) {
        return _getArgAddress(0);
    }

    /// @notice VaultRegistry address that is allowed to call mint() and burn()
    function VAULT_REGISTRY() public pure returns (address) {
        return _getArgAddress(20);
    }

    /// @dev Computes hash of permit struct
    /// @param _owner Address of the owner of the token type
    /// @param _operator Address of the spender of the token type
    /// @param _id ID of the token type
    /// @param _approved Approval status for the token type
    /// @param _deadline Expiration of the signature
    function _computePermitStructHash(
        address _owner,
        address _operator,
        uint256 _id,
        bool _approved,
        uint256 _deadline
    ) internal returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    _owner,
                    _operator,
                    _id,
                    _approved,
                    nonces[_owner]++,
                    _deadline
                )
            );
    }

    /// @dev Computes hash of permit all struct
    /// @param _owner Address of the owner of the token type
    /// @param _operator Address of the spender of the token type
    /// @param _approved Approval status for the token type
    /// @param _deadline Expiration of the signature
    function _computePermitAllStructHash(
        address _owner,
        address _operator,
        bool _approved,
        uint256 _deadline
    ) internal returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PERMIT_ALL_TYPEHASH,
                    _owner,
                    _operator,
                    _approved,
                    nonces[_owner]++,
                    _deadline
                )
            );
    }

    /// @dev Computes domain separator to prevent signature collisions
    /// @return Hash of the contract-specific fields
    function _computeDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes(NAME)),
                    keccak256(bytes(VERSION)),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// @dev Computes digest of domain separator and struct hash
    /// @param _domainSeparator Hash of contract-specific fields
    /// @param _structHash Hash of signature fields struct
    /// @return Hash of the signature digest
    function _computeDigest(bytes32 _domainSeparator, bytes32 _structHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", _domainSeparator, _structHash)
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Interface for Vault proxy contract
interface IVault {
    /// @dev Emitted when execution reverted with no reason
    error ExecutionReverted();
    /// @dev Emitted when ownership of the proxy has been renounced
    error Initialized(address _owner, address _newOwner, uint256 _nonce);
    /// @dev Emitted when there is no implementation stored in methods for a function signature
    error MethodNotFound();
    /// @dev Emitted when the caller is not the owner
    error NotAuthorized(address _caller, address _target, bytes4 _selector);
    /// @dev Emitted when the caller is not the owner
    error NotOwner(address _owner, address _caller);
    /// @dev Emitted when the owner is changed during the DELEGATECALL
    error OwnerChanged(address _originalOwner, address _newOwner);
    /// @dev Emitted when passing an EOA or an undeployed contract as the target
    error TargetInvalid(address _target);

    /// @dev Event log for executing transactions
    /// @param _target Address of target contract
    /// @param _data Transaction data being executed
    /// @param _response Return data of delegatecall
    event Execute(address indexed _target, bytes _data, bytes _response);
    /// @dev Event log for installing plugins
    /// @param _selectors List of function selectors
    /// @param _plugins List of plugin contracts
    event InstallPlugin(bytes4[] _selectors, address[] _plugins);
    /// @dev Event log for transferring ownership
    /// @param _oldOwner Address of old owner
    /// @param _newOwner Address of new owner
    event TransferOwnership(
        address indexed _oldOwner,
        address indexed _newOwner
    );
    /// @dev Event log for uninstalling plugins
    /// @param _selectors List of function selectors
    event UninstallPlugin(bytes4[] _selectors);

    function execute(
        address _target,
        bytes memory _data,
        bytes32[] memory _proof
    ) external payable returns (bool success, bytes memory response);

    function init() external;

    function install(bytes4[] memory _selectors, address[] memory _plugins)
        external;

    function merkleRoot() external view returns (bytes32);

    function methods(bytes4) external view returns (address);

    function nonce() external view returns (uint256);

    function owner() external view returns (address);

    function setMerkleRoot(bytes32 _rootHash) external;

    function transferOwnership(address _newOwner) external;

    function uninstall(bytes4[] memory _selectors) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Vault permissions
struct Permission {
    // Address of module contract
    address module;
    // Address of target contract
    address target;
    // Function selector from target contract
    bytes4 selector;
}

/// @dev Vault information
struct VaultInfo {
    // Address of FERC1155 token contract
    address token;
    // ID of the token type
    uint256 id;
}

/// @dev Interface for VaultRegistry contract
interface IVaultRegistry {
    /// @dev Emitted when the caller is not the controller
    error InvalidController(address _controller, address _sender);
    /// @dev Emitted when the caller is not a registered vault
    error UnregisteredVault(address _sender);

    /// @dev Event log for deploying vault
    /// @param _vault Address of the vault
    /// @param _token Address of the token
    /// @param _id Id of the token
    event VaultDeployed(
        address indexed _vault,
        address indexed _token,
        uint256 _id
    );

    function burn(address _from, uint256 _value) external;

    function create(
        bytes32 _merkleRoot,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault);

    function createCollection(
        bytes32 _merkleRoot,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault, address token);

    function createCollectionFor(
        bytes32 _merkleRoot,
        address _controller,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault, address token);

    function createFor(
        bytes32 _merkleRoot,
        address _owner,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault);

    function createInCollection(
        bytes32 _merkleRoot,
        address _token,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault);

    function factory() external view returns (address);

    function fNFT() external view returns (address);

    function fNFTImplementation() external view returns (address);

    function mint(address _to, uint256 _value) external;

    function nextId(address) external view returns (uint256);

    function totalSupply(address _vault) external view returns (uint256);

    function uri(address _vault) external view returns (string memory);

    function vaultToToken(address)
        external
        view
        returns (address token, uint256 id);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Create2ClonesWithImmutableArgs} from "clones-with-immutable-args/src/Create2ClonesWithImmutableArgs.sol";
import {IVaultFactory} from "./interfaces/IVaultFactory.sol";
import {Vault} from "./Vault.sol";

/// @title Vault Factory
/// @author Fractional Art
/// @notice Factory contract for deploying fractional vaults
contract VaultFactory is IVaultFactory {
    /// @dev Use clones library for address types
    using Create2ClonesWithImmutableArgs for address;
    /// @notice Address of Vault proxy contract
    address public implementation;
    /// @dev Internal mapping to track the next seed to be used by an EOA
    mapping(address => bytes32) internal nextSeeds;

    /// @notice Initializes implementation contract
    constructor() {
        implementation = address(new Vault());
    }

    /// @notice Deploys new vault for sender
    /// @return vault Address of deployed vault
    function deploy() external returns (address payable vault) {
        vault = deployFor(msg.sender);
    }

    /// @notice Gets pre-computed address of vault deployed by given account
    /// @param _deployer Address of vault deployer
    /// @return vault Address of next vault
    function getNextAddress(address _deployer)
        external
        view
        returns (address vault)
    {
        bytes32 salt = keccak256(abi.encode(_deployer, nextSeeds[_deployer]));
        (uint256 creationPtr, uint256 creationSize) = implementation
            .cloneCreationCode(abi.encodePacked());

        bytes32 creationHash;
        assembly {
            creationHash := keccak256(creationPtr, creationSize)
        }
        bytes32 data = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, creationHash)
        );
        vault = address(uint160(uint256(data)));
    }

    /// @notice Gets next seed value of given account
    /// @param _deployer Address of vault deployer
    /// @return Value of next seed
    function getNextSeed(address _deployer) external view returns (bytes32) {
        return nextSeeds[_deployer];
    }

    /// @notice Deploys new vault for given address
    /// @param _owner Address of vault owner
    /// @return vault Address of deployed vault
    function deployFor(address _owner) public returns (address payable vault) {
        bytes32 seed = nextSeeds[tx.origin];

        // Prevent front-running the salt by hashing the concatenation of tx.origin and the user-provided seed.
        bytes32 salt = keccak256(abi.encode(tx.origin, seed));

        bytes memory data = abi.encodePacked();
        vault = implementation.clone(salt, data);
        Vault(vault).init();

        // Transfer the ownership from this factory contract to the specified owner.
        Vault(vault).transferOwnership(_owner);

        // Increment the seed.
        unchecked {
            nextSeeds[tx.origin] = bytes32(uint256(seed) + 1);
        }

        // Log the vault via en event.
        emit DeployVault(
            tx.origin,
            msg.sender,
            _owner,
            seed,
            salt,
            address(vault)
        );
    }
}

// SPDX-License-Identifier: BSD
pragma solidity ^0.8.4;

/// @title Clone
/// @author zefram.eth
/// @notice Provides helper functions for reading immutable args from calldata
contract Clone {
    /// @notice Reads an immutable arg with type address
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function _getArgAddress(uint256 argOffset)
        internal
        pure
        returns (address arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            arg := shr(0x60, calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type uint256
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function _getArgUint256(uint256 argOffset)
        internal
        pure
        returns (uint256 arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    /// @notice Reads an immutable arg with type bytes32
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function _getArgBytes32(uint256 argOffset)
        internal
        pure
        returns (bytes32 arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    /// @notice Reads a uint256 array stored in the immutable args.
    /// @param argOffset The offset of the arg in the packed data
    /// @param arrLen Number of elements in the array
    /// @return arr The array
    function _getArgUint256Array(uint256 argOffset, uint64 arrLen)
        internal
        pure
        returns (uint256[] memory arr)
    {
        uint256 offset = _getImmutableArgsOffset();
        uint256 el;
        arr = new uint256[](arrLen);
        for (uint64 i = 0; i < arrLen; i++) {
            assembly {
                // solhint-disable-next-line no-inline-assembly
                el := calldataload(add(add(offset, argOffset), mul(i, 32)))
            }
            arr[i] = el;
        }
        return arr;
    }

    /// @notice Reads a uint256 array stored in the immutable args.
    /// @param argOffset The offset of the arg in the packed data
    /// @param arrLen Number of elements in the array
    /// @return arr The array
    function _getArgBytes32Array(uint256 argOffset, uint64 arrLen)
        internal
        pure
        returns (bytes32[] memory arr)
    {
        uint256 offset = _getImmutableArgsOffset();
        bytes32 el;
        arr = new bytes32[](arrLen);
        for (uint64 i = 0; i < arrLen; i++) {
            assembly {
                // solhint-disable-next-line no-inline-assembly
                el := calldataload(add(add(offset, argOffset), mul(i, 32)))
            }
            arr[i] = el;
        }
        return arr;
    }

    /// @notice Reads an immutable arg with type uint64
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function _getArgUint64(uint256 argOffset)
        internal
        pure
        returns (uint64 arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            arg := shr(0xc0, calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type uint8
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function _getArgUint8(uint256 argOffset) internal pure returns (uint8 arg) {
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            arg := shr(0xf8, calldataload(add(offset, argOffset)))
        }
    }

    /// @return offset The offset of the packed immutable args in calldata
    function _getImmutableArgsOffset() internal pure returns (uint256 offset) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Interface of ERC-1155 token contract for fractions
interface IFERC1155 {
    /// @dev Emitted when caller is not required address
    error InvalidSender(address _required, address _provided);
    /// @dev Emitted when owner signature is invalid
    error InvalidSignature(address _signer, address _owner);
    /// @dev Emitted when deadline for signature has passed
    error SignatureExpired(uint256 _timestamp, uint256 _deadline);
    /// @dev Emitted when new controller is zero address
    error ZeroAddress();

    /// @dev Event log for updating the Controller of the token contract
    /// @param _newController Address of the controller
    event ControllerTransferred(address indexed _newController);
    /// @dev Event log for updating the metadata contract for a token type
    /// @param _metadata Address of the metadata contract that URI data is stored on
    /// @param _id ID of the token type
    event SetMetadata(address indexed _metadata, uint256 _id);
    /// @dev Event log for updating the royalty of a token type
    /// @param _receiver Address of the receiver of secondary sale royalties
    /// @param _id ID of the token type
    /// @param _percentage Royalty percent on secondary sales
    event SetRoyalty(
        address indexed _receiver,
        uint256 _id,
        uint256 _percentage
    );
    /// @dev Event log for approving a spender of a token type
    /// @param _owner Address of the owner of the token type
    /// @param _operator Address of the spender of the token type
    /// @param _id ID of the token type
    /// @param _approved Approval status for the token type
    event SingleApproval(
        address indexed _owner,
        address indexed _operator,
        uint256 _id,
        bool _approved
    );

    function INITIAL_CONTROLLER() external pure returns (address);

    function NAME() external view returns (string memory);

    function VAULT_REGISTRY() external pure returns (address);

    function VERSION() external view returns (string memory);

    function burn(
        address _from,
        uint256 _id,
        uint256 _amount
    ) external;

    function contractURI() external view returns (string memory);

    function controller() external view returns (address controllerAddress);

    function emitSetURI(uint256 _id, string memory _uri) external;

    function isApproved(
        address,
        address,
        uint256
    ) external view returns (bool);

    function metadata(uint256) external view returns (address);

    function mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external;

    function nonces(address) external view returns (uint256);

    function permit(
        address _owner,
        address _operator,
        uint256 _id,
        bool _approved,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function permitAll(
        address _owner,
        address _operator,
        bool _approved,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function royaltyInfo(uint256 _id, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external;

    function setApprovalFor(
        address _operator,
        uint256 _id,
        bool _approved
    ) external;

    function setContractURI(string memory _uri) external;

    function setMetadata(address _metadata, uint256 _id) external;

    function setRoyalties(
        uint256 _id,
        address _receiver,
        uint256 _percentage
    ) external;

    function totalSupply(uint256) external view returns (uint256);

    function transferController(address _newController) external;

    function uri(uint256 _id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Interface for NFT Receiver contract
interface INFTReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4);

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev The EIP-712 typehash for the contract's domain
bytes32 constant DOMAIN_TYPEHASH = keccak256(
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
);

/// @dev The EIP-712 typehash for the permit struct used by the contract
bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address operator,uint256 tokenId,bool approved,uint256 nonce,uint256 deadline)"
);

/// @dev The EIP-712 typehash for the permit all struct used by the contract
bytes32 constant PERMIT_ALL_TYPEHASH = keccak256(
    "PermitAll(address owner,address operator,bool approved,uint256 nonce,uint256 deadline)"
);

// SPDX-License-Identifier: BSD

pragma solidity ^0.8.4;

/// @title ClonesWithImmutableArgs
/// @author wighawag, zefram.eth
/// @notice Enables creating clone contracts with immutable args
library Create2ClonesWithImmutableArgs {
    error CreateFail();

    function cloneCreationCode(address implementation, bytes memory data)
        internal
        pure
        returns (uint256 ptr, uint256 creationSize)
    {
        // unchecked is safe because it is unrealistic for memory ptr or data length to exceed 256 bits
        unchecked {
            uint256 extraLength = data.length + 2; // +2 bytes for telling how much data there is appended to the call
            creationSize = 0x43 + extraLength;
            uint256 runSize = creationSize - 11;
            uint256 dataPtr;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                ptr := mload(0x40)

                // -------------------------------------------------------------------------------------------------------------
                // CREATION (11 bytes)
                // -------------------------------------------------------------------------------------------------------------

                // 3d          | RETURNDATASIZE        | 0                       | –
                // 61 runtime  | PUSH2 runtime (r)     | r 0                     | –
                mstore(
                    ptr,
                    0x3d61000000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x02), shl(240, runSize)) // size of the contract running bytecode (16 bits)

                // creation size = 0b
                // 80          | DUP1                  | r r 0                   | –
                // 60 creation | PUSH1 creation (c)    | c r r 0                 | –
                // 3d          | RETURNDATASIZE        | 0 c r r 0               | –
                // 39          | CODECOPY              | r 0                     | [0-2d]: runtime code
                // 81          | DUP2                  | 0 c  0                  | [0-2d]: runtime code
                // f3          | RETURN                | 0                       | [0-2d]: runtime code
                mstore(
                    add(ptr, 0x04),
                    0x80600b3d3981f300000000000000000000000000000000000000000000000000
                )

                // -------------------------------------------------------------------------------------------------------------
                // RUNTIME
                // -------------------------------------------------------------------------------------------------------------

                // 36          | CALLDATASIZE          | cds                     | –
                // 3d          | RETURNDATASIZE        | 0 cds                   | –
                // 3d          | RETURNDATASIZE        | 0 0 cds                 | –
                // 37          | CALLDATACOPY          | –                       | [0, cds] = calldata
                // 61          | PUSH2 extra           | extra                   | [0, cds] = calldata
                mstore(
                    add(ptr, 0x0b),
                    0x363d3d3761000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x10), shl(240, extraLength))

                // 60 0x38     | PUSH1 0x38            | 0x38 extra              | [0, cds] = calldata // 0x38 (56) is runtime size - data
                // 36          | CALLDATASIZE          | cds 0x38 extra          | [0, cds] = calldata
                // 39          | CODECOPY              | _                       | [0, cds] = calldata
                // 3d          | RETURNDATASIZE        | 0                       | [0, cds] = calldata
                // 3d          | RETURNDATASIZE        | 0 0                     | [0, cds] = calldata
                // 3d          | RETURNDATASIZE        | 0 0 0                   | [0, cds] = calldata
                // 36          | CALLDATASIZE          | cds 0 0 0               | [0, cds] = calldata
                // 61 extra    | PUSH2 extra           | extra cds 0 0 0         | [0, cds] = calldata
                mstore(
                    add(ptr, 0x12),
                    0x603836393d3d3d36610000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x1b), shl(240, extraLength))

                // 01          | ADD                   | cds+extra 0 0 0         | [0, cds] = calldata
                // 3d          | RETURNDATASIZE        | 0 cds 0 0 0             | [0, cds] = calldata
                // 73 addr     | PUSH20 0x123…         | addr 0 cds 0 0 0        | [0, cds] = calldata
                mstore(
                    add(ptr, 0x1d),
                    0x013d730000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x20), shl(0x60, implementation))

                // 5a          | GAS                   | gas addr 0 cds 0 0 0    | [0, cds] = calldata
                // f4          | DELEGATECALL          | success 0               | [0, cds] = calldata
                // 3d          | RETURNDATASIZE        | rds success 0           | [0, cds] = calldata
                // 82          | DUP3                  | 0 rds success 0         | [0, cds] = calldata
                // 80          | DUP1                  | 0 0 rds success 0       | [0, cds] = calldata
                // 3e          | RETURNDATACOPY        | success 0               | [0, rds] = return data (there might be some irrelevant leftovers in memory [rds, cds] when rds < cds)
                // 90          | SWAP1                 | 0 success               | [0, rds] = return data
                // 3d          | RETURNDATASIZE        | rds 0 success           | [0, rds] = return data
                // 91          | SWAP2                 | success 0 rds           | [0, rds] = return data
                // 60 0x36     | PUSH1 0x36            | 0x36 sucess 0 rds       | [0, rds] = return data
                // 57          | JUMPI                 | 0 rds                   | [0, rds] = return data
                // fd          | REVERT                | –                       | [0, rds] = return data
                // 5b          | JUMPDEST              | 0 rds                   | [0, rds] = return data
                // f3          | RETURN                | –                       | [0, rds] = return data

                mstore(
                    add(ptr, 0x34),
                    0x5af43d82803e903d91603657fd5bf30000000000000000000000000000000000
                )
            }

            // -------------------------------------------------------------------------------------------------------------
            // APPENDED DATA (Accessible from extcodecopy)
            // (but also send as appended data to the delegatecall)
            // -------------------------------------------------------------------------------------------------------------

            extraLength -= 2;
            uint256 counter = extraLength;
            uint256 copyPtr;
            assembly {
                copyPtr := add(ptr, 0x43)
            }
            // solhint-disable-next-line no-inline-assembly
            assembly {
                dataPtr := add(data, 32)
            }
            for (; counter >= 32; counter -= 32) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    mstore(copyPtr, mload(dataPtr))
                }

                copyPtr += 32;
                dataPtr += 32;
            }
            uint256 mask = ~(256**(32 - counter) - 1);
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(copyPtr, and(mload(dataPtr), mask))
            }
            copyPtr += counter;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(copyPtr, shl(240, extraLength))
            }
        }
    }

    /// @notice Creates a clone proxy of the implementation contract, with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function clone(
        address implementation,
        bytes32 salt,
        bytes memory data
    ) internal returns (address payable instance) {
        (uint256 creationPtr, uint256 creationSize) = cloneCreationCode(
            implementation,
            data
        );

        // solhint-disable-next-line no-inline-assembly
        assembly {
            instance := create2(0, creationPtr, creationSize, salt)
        }

        // if the create failed, the instance address won't be set
        if (instance == address(0)) {
            revert CreateFail();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Interface for VaultFactory contract
interface IVaultFactory {
    /// @dev Event log for deploying vault
    /// @param _origin Address of transaction origin
    /// @param _deployer Address of sender
    /// @param _owner Address of vault owner
    /// @param _seed Value of seed
    /// @param _salt Value of salt
    /// @param _vault Address of deployed vault
    event DeployVault(
        address indexed _origin,
        address indexed _deployer,
        address indexed _owner,
        bytes32 _seed,
        bytes32 _salt,
        address _vault
    );

    function deploy() external returns (address payable vault);

    function deployFor(address _owner) external returns (address payable vault);

    function getNextAddress(address _deployer)
        external
        view
        returns (address vault);

    function getNextSeed(address _deployer) external view returns (bytes32);

    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IVault} from "./interfaces/IVault.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {NFTReceiver} from "./utils/NFTReceiver.sol";

/// @title Vault
/// @author Fractional Art
/// @notice Proxy contract for storing fractionalized assets
contract Vault is IVault, NFTReceiver {
    /// @notice Address of vault owner
    address public owner;
    /// @notice Merkle root hash of vault permissions
    bytes32 public merkleRoot;
    /// @notice Initializer value
    uint256 public nonce;
    /// @dev Minimum reserve of gas units
    uint256 private constant MIN_GAS_RESERVE = 5_000;
    /// @notice Mapping of function selector to plugin address
    mapping(bytes4 => address) public methods;

    /// @dev Initializes nonce and proxy owner
    function init() external {
        if (nonce != 0) revert Initialized(owner, msg.sender, nonce);
        nonce = 1;
        owner = msg.sender;
        emit TransferOwnership(address(0), msg.sender);
    }

    /// @dev Callback for receiving Ether when the calldata is empty
    receive() external payable {}

    /// @dev Callback for handling plugin transactions
    /// @param _data Transaction data
    /// @return response Return data from executing plugin
    // prettier-ignore
    fallback(bytes calldata _data) external payable returns (bytes memory response) {
        address plugin = methods[msg.sig];
        (,response) = _execute(plugin, _data);
    }

    /// @notice Executes vault transactions through delegatecall
    /// @param _target Target address
    /// @param _data Transaction data
    /// @param _proof Merkle proof of permission hash
    /// @return success Result status of delegatecall
    /// @return response Return data of delegatecall
    function execute(
        address _target,
        bytes calldata _data,
        bytes32[] calldata _proof
    ) external payable returns (bool success, bytes memory response) {
        bytes4 selector;
        assembly {
            selector := calldataload(_data.offset)
        }

        // Generate leaf node by hashing module, target and function selector.
        bytes32 leaf = keccak256(abi.encode(msg.sender, _target, selector));
        // Check that the caller is either a module with permission to call or the owner.
        if (!MerkleProof.verify(_proof, merkleRoot, leaf)) {
            if (msg.sender != owner)
                revert NotAuthorized(msg.sender, _target, selector);
        }

        (success, response) = _execute(_target, _data);
    }

    /// @notice Installs plugin by setting function selector to contract address
    /// @param _selectors List of function selectors
    /// @param _plugins Addresses of plugin contracts
    function install(bytes4[] memory _selectors, address[] memory _plugins)
        external
    {
        if (owner != msg.sender) revert NotOwner(owner, msg.sender);
        uint256 length = _selectors.length;
        for (uint256 i = 0; i < length; i++) {
            methods[_selectors[i]] = _plugins[i];
        }
        emit InstallPlugin(_selectors, _plugins);
    }

    /// @notice Sets merkle root of vault permissions
    /// @param _rootHash Hash of merkle root
    function setMerkleRoot(bytes32 _rootHash) external {
        if (owner != msg.sender) revert NotOwner(owner, msg.sender);
        merkleRoot = _rootHash;
    }

    /// @notice Transfers ownership to given account
    /// @param _newOwner Address of new owner
    function transferOwnership(address _newOwner) external {
        if (owner != msg.sender) revert NotOwner(owner, msg.sender);
        owner = _newOwner;
        emit TransferOwnership(msg.sender, _newOwner);
    }

    /// @notice Uninstalls plugin by setting function selector to zero address
    /// @param _selectors List of function selectors
    function uninstall(bytes4[] memory _selectors) external {
        if (owner != msg.sender) revert NotOwner(owner, msg.sender);
        uint256 length = _selectors.length;
        for (uint256 i = 0; i < length; i++) {
            methods[_selectors[i]] = address(0);
        }
        emit UninstallPlugin(_selectors);
    }

    /// @notice Executes plugin transactions through delegatecall
    /// @param _target Target address
    /// @param _data Transaction data
    /// @return success Result status of delegatecall
    /// @return response Return data of delegatecall
    function _execute(address _target, bytes calldata _data)
        internal
        returns (bool success, bytes memory response)
    {
        // Check that the target is a valid contract
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_target)
        }
        if (codeSize == 0) revert TargetInvalid(_target);
        // Save the owner address in memory to ensure that it cannot be modified during the DELEGATECALL
        address owner_ = owner;
        // Reserve some gas to ensure that the function has enough to finish the execution
        uint256 stipend = gasleft() - MIN_GAS_RESERVE;

        // Delegate call to the target contract
        (success, response) = _target.delegatecall{gas: stipend}(_data);
        if (owner_ != owner) revert OwnerChanged(owner_, owner);

        // Revert if execution was unsuccessful
        if (!success) {
            if (response.length == 0) revert ExecutionReverted();
            _revertedWithReason(response);
        }
    }

    /// @notice Reverts transaction with reason
    function _revertedWithReason(bytes memory _response) internal pure {
        assembly {
            let returndata_size := mload(_response)
            revert(add(32, _response), returndata_size)
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }
        return computedHash;
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ERC721TokenReceiver} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {ERC1155TokenReceiver} from "@rari-capital/solmate/src/tokens/ERC1155.sol";

/// @title NFT Receiver
/// @author Fractional Art
/// @notice Plugin contract for handling receipts of non-fungible tokens
contract NFTReceiver is ERC721TokenReceiver, ERC1155TokenReceiver {
    /// @notice Handles the receipt of a single ERC721 token
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }

    /// @notice Handles the receipt of a single ERC1155 token type
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    /// @notice Handles the receipt of multiple ERC1155 token types
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        require((owner = _ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}