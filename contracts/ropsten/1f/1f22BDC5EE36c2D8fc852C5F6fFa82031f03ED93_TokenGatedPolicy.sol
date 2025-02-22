//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IRegistrarController.sol";
import "./Policy.sol";

contract TokenGatedPolicy is Policy {
    constructor(
        address _CNSControlerAddr,
        address _ensAddr,
        address _baseRegistrarAddr,
        address _resolverAddr,
        address _registrarControllerAddr
    )
        Policy(
            _CNSControlerAddr,
            _ensAddr,
            _baseRegistrarAddr,
            _resolverAddr,
            _registrarControllerAddr
        )
    {
        require(_CNSControlerAddr != address(0), "Invalid address");
    }

    struct _tokenGated {
        address tokenAddress;
    }

    struct historyMint {
        bytes32 subnode;
        address minter;
        uint256 tokenId;
    }

    mapping(string => _tokenGated) public tokenGated;
    mapping(address => historyMint[]) internal historyMints;

    /**
     * Function: permissionCheck [public].
     * @param _domain The domain
     * @param _account The account to check.
     */
    function permissionCheck(string memory _domain, address _account)
        public
        view
        virtual
        returns (bool)
    {
        bool _permission = false;
        if (tokenGated[_domain].tokenAddress == address(0)) {
            return false;
        }

        uint256 _holdingBalance = getTokenHoldingBalance(_domain, _account);

        if (_holdingBalance > 0) {
            _permission = true;
        }

        return _permission;
    }

    /**
     * Function: getTokenHoldingBalance [internal].
     * @param _domain The domain
     * @param _account The account to check.
     */
    function getTokenHoldingBalance(string memory _domain, address _account)
        internal
        view
        returns (uint256)
    {
        return IERC721(tokenGated[_domain].tokenAddress).balanceOf(_account);
    }

    /**
     * Function: setTokenGated [public].
     * @param _domain The domain
     * @param _tokenAddress The NFT token Address.
     */
    function setTokenGated(string memory _domain, address _tokenAddress)
        public
        onlyDomainOwner(_domain, msg.sender)
        isUseThisPolicy(_domain, address(this))
    {
        _setTokenGated(_domain, _tokenAddress);
    }

    /**
     * Function: setTokenGated [internal].
     * @param _domain The domain
     * @param _tokenAddress The NFT token Address.
     */
    function _setTokenGated(string memory _domain, address _tokenAddress)
        internal
    {
        tokenGated[_domain] = _tokenGated(_tokenAddress);
    }

    /**
     * Function register subdomain be able to customize for keep other data.
     */
    function registerSubdomain(
        string memory _domain,
        string memory _subdomain,
        bytes32 _subnode,
        uint256 _tokenId
    ) public {
        //get tokengated address
        address tokengated_address = tokenGated[_domain].tokenAddress;

        //check NFT holding balance
        require(
            permissionCheck(_domain, msg.sender),
            "Permission denied (not holding token)"
        );

        //check Owner Of tokenId
        require(
            isNFTOwner(tokengated_address, _tokenId, msg.sender),
            "You are not owner of this token"
        );
        bool _permission = true;

        //check minted
        for (uint256 i = 0; i < historyMints[tokengated_address].length; i++) {
            if (historyMints[tokengated_address][i].tokenId == _tokenId) {
                _permission = false;
                if (historyMints[tokengated_address][i].minter == msg.sender) {
                    //cannot mint
                    revert("You have already minted with this NFT tokenId");
                } else {
                    _permission = true;
                    //remove old owner subdomain and burn SBT
                    registrarctl.removeSubdomainWithNode(
                        historyMints[tokengated_address][i].subnode
                    );
                    //delete old minter data
                    delete historyMints[tokengated_address][i];
                }
            }
        }

        require(_permission, "You have already minted with this NFT tokenId");

        if (_permission) {
            //register subdomain
            registrarctl.registerSubdomain(
                _domain,
                _subdomain,
                _subnode,
                msg.sender
            );
            //add history mint
            historyMints[tokengated_address].push(
                historyMint(_subnode, msg.sender, _tokenId)
            );
        }
    }

    function unRegisterDomain(string memory _domain, bool _wipe)
        public
        virtual
        override
        onlyDomainOwner(_domain, msg.sender)
    {
        address tokengated_address = tokenGated[_domain].tokenAddress;
        delete tokenGated[_domain];
        delete historyMints[tokengated_address];

        if (_wipe) {
            registrarctl.unRegisterDomain(_domain);
        } else {
            registrarctl.unRegisterDomainWithoutBurn(_domain);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

interface IRegistrarController {
    function unRegisterDomain(string memory _domain) external;

    function registerDomain(
        uint256 _tokenId,
        string memory _domain,
        bytes32 _node,
        address _policy
    ) external;

    function registerSubdomain(
        string memory _domain,
        string memory _subdomain,
        bytes32 _subnode,
        address _owner
    ) external;

    function unRegisterDomainWithoutBurn(string memory _domain) external;

    function registerDomain(
        uint256 _tokenId,
        string memory _domain,
        bytes32 _node,
        address _policy,
        address _sender
    ) external;

    function removeSubdomainWithNode(bytes32 _subnode) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "../interfaces/IRegistrarController.sol";
import "../access/CNSAccessControl.sol";

contract Policy is CNSAccessControl {
    IRegistrarController internal registrarctl;

    constructor(
        address _CNSControlerAddr,
        address _ensAddr,
        address _baseRegistrarAddr,
        address _resolverAddr,
        address _registrarControllerAddr
    )
        CNSAccessControl(
            _CNSControlerAddr,
            _ensAddr,
            _baseRegistrarAddr,
            _resolverAddr
        )
    {
        require(_CNSControlerAddr != address(0), "Invalid address");
        registrarctl = IRegistrarController(_registrarControllerAddr);
    }

    function registerDomain(
        uint256 _tokenId,
        string memory _domain,
        bytes32 _node
    ) public virtual isDomainOwner(_tokenId, msg.sender) {
        registrarctl.registerDomain(
            _tokenId,
            _domain,
            _node,
            address(this),
            msg.sender
        );
    }

    function unRegisterDomain(string memory _domain, bool _wipe)
        public
        virtual
        onlyDomainOwner(_domain, msg.sender)
    {
        if (_wipe) {
            registrarctl.unRegisterDomain(_domain);
        } else {
            registrarctl.unRegisterDomainWithoutBurn(_domain);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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

//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "../interfaces/ICNSController.sol";
import "../libs/ENSController.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract CNSAccessControl is ENSController {
    ICNSController internal cns;

    constructor(
        address _CNSControlerAddr,
        address _ensAddr,
        address _baseRegistrarAddr,
        address _resolverAddr
    ) ENSController(_ensAddr, _baseRegistrarAddr, _resolverAddr) {
        require(_CNSControlerAddr != address(0), "Invalid address");
        cns = ICNSController(_CNSControlerAddr);
    }

    modifier isNotRegisterDomain(string memory _domain) {
        require(!cns.isRegisterDomain(_domain), "Domain is already registered");
        _;
    }

    modifier isRegisterDomain(string memory _domain) {
        require(cns.isRegisterDomain(_domain));
        _;
    }

    modifier isDomainOwner(uint256 _tokenId, address _account) {
        require(_account == registrar.ownerOf(_tokenId));
        _;
    }

    modifier isPolicy(address _policy) {
        require(cns.isActivePolicy(_policy));
        _;
    }

    modifier onlyPolicyOrDomainOwner(address _sender, string memory _domain) {
        require(
            cns.isActivePolicy(_sender) || cns.isDomainOwner(_domain, _sender)
        );
        _;
    }

    modifier onlyPolicy() {
        require(cns.isActivePolicy(msg.sender));
        _;
    }

    modifier onlyDomainOwner(string memory _domain, address _sender) {
        require(cns.isDomainOwner(_domain, _sender));
        _;
    }

    modifier isUseThisPolicy(string memory _domain, address _policy) {
        require(cns.checkPolicy(_domain) == _policy);
        _;
    }

    modifier isNotMintWithPolicy(
        string memory _domain,
        address _account,
        address _policy
    ) {
        require(!cns.checkMintSubdomainWithPolicy(_domain, _account, _policy));
        _;
    }

    function isNFTOwner(
        address _tokenAddress,
        uint256 _tokenId,
        address _account
    ) public view returns (bool) {
        return _account == IERC721(_tokenAddress).ownerOf(_tokenId);
    }

    function checkMintWithPolicy(
        string memory _domain,
        address _account,
        address _policy
    ) public returns (bool) {
        return !cns.checkMintSubdomainWithPolicy(_domain, _account, _policy);
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "../structures/Domain.sol";

interface ICNSController {
    function isRegisterDomain(string memory _domain)
        external
        view
        returns (bool);

    function registerDomain(Domain memory _domain) external;

    function registerSubdomain(
        string memory _domain,
        string memory _subdomain,
        bytes32 _subnode,
        address _owner
    ) external;

    function isActivePolicy(address _policy) external view returns (bool);

    function getDomain(string memory _domain)
        external
        view
        returns (Domain memory);

    function isDomainOwner(string memory _domain, address _account)
        external
        view
        returns (bool);

    function unRegisterDomain(string memory _domain) external;

    function unRegisterDomainWithoutBurn(string memory _domain) external;

    function checkPolicy(string memory _domain) external view returns (address);

    function checkMintSubdomainWithPolicy(
        string memory _domain,
        address _account,
        address _policy
    ) external returns (bool);

    function removeSubdomainWithNode(bytes32 _subnode) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import "@ensdomains/ens-contracts/contracts/resolvers/Resolver.sol";
import "../interfaces/IRegistrar.sol";

contract ENSController {
    ENS public ens;
    Registrar internal registrar;
    Resolver internal resolver;

    /**
     * Constructor.
     * @param ensAddr The address of the ENS registry.
     */
    constructor(
        address ensAddr,
        address baseRegistrarAddr,
        address resolverAddr
    ) {
        require(address(ensAddr) != address(0), "Invalid address");
        require(address(baseRegistrarAddr) != address(0), "Invalid address");
        require(address(resolverAddr) != address(0), "Invalid address");

        ens = ENS(ensAddr);
        registrar = Registrar(baseRegistrarAddr);
        resolver = Resolver(resolverAddr);
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

struct Domain {
    string domain;
    uint256 tokenId;
    address owner;
    bytes32 node;
    address policy;
    uint256 subdomainCount;
}

pragma solidity >=0.8.4;

interface ENS {

    // Logged when the owner of a node assigns a new owner to a subnode.
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

    // Logged when the owner of a node transfers ownership to a new account.
    event Transfer(bytes32 indexed node, address owner);

    // Logged when the resolver for a node changes.
    event NewResolver(bytes32 indexed node, address resolver);

    // Logged when the TTL of a node changes
    event NewTTL(bytes32 indexed node, uint64 ttl);

    // Logged when an operator is added or removed.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setRecord(bytes32 node, address owner, address resolver, uint64 ttl) external virtual;
    function setSubnodeRecord(bytes32 node, bytes32 label, address owner, address resolver, uint64 ttl) external virtual;
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) external virtual returns(bytes32);
    function setResolver(bytes32 node, address resolver) external virtual;
    function setOwner(bytes32 node, address owner) external virtual;
    function setTTL(bytes32 node, uint64 ttl) external virtual;
    function setApprovalForAll(address operator, bool approved) external virtual;
    function owner(bytes32 node) external virtual view returns (address);
    function resolver(bytes32 node) external virtual view returns (address);
    function ttl(bytes32 node) external virtual view returns (uint64);
    function recordExists(bytes32 node) external virtual view returns (bool);
    function isApprovedForAll(address owner, address operator) external virtual view returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./profiles/IABIResolver.sol";
import "./profiles/IAddressResolver.sol";
import "./profiles/IAddrResolver.sol";
import "./profiles/IContentHashResolver.sol";
import "./profiles/IDNSRecordResolver.sol";
import "./profiles/IDNSZoneResolver.sol";
import "./profiles/IInterfaceResolver.sol";
import "./profiles/INameResolver.sol";
import "./profiles/IPubkeyResolver.sol";
import "./profiles/ITextResolver.sol";
import "./ISupportsInterface.sol";
/**
 * A generic resolver interface which includes all the functions including the ones deprecated
 */
interface Resolver is ISupportsInterface, IABIResolver, IAddressResolver, IAddrResolver, IContentHashResolver, IDNSRecordResolver, IDNSZoneResolver, IInterfaceResolver, INameResolver, IPubkeyResolver, ITextResolver {
    /* Deprecated events */
    event ContentChanged(bytes32 indexed node, bytes32 hash);

    function setABI(bytes32 node, uint256 contentType, bytes calldata data) external;
    function setAddr(bytes32 node, address addr) external;
    function setAddr(bytes32 node, uint coinType, bytes calldata a) external;
    function setContenthash(bytes32 node, bytes calldata hash) external;
    function setDnsrr(bytes32 node, bytes calldata data) external;
    function setName(bytes32 node, string calldata _name) external;
    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external;
    function setText(bytes32 node, string calldata key, string calldata value) external;
    function setInterface(bytes32 node, bytes4 interfaceID, address implementer) external;
    function multicall(bytes[] calldata data) external returns(bytes[] memory results);

    /* Deprecated functions */
    function content(bytes32 node) external view returns (bytes32);
    function multihash(bytes32 node) external view returns (bytes memory);
    function setContent(bytes32 node, bytes32 hash) external;
    function setMultihash(bytes32 node, bytes calldata hash) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

/**
 * @dev Interface of the Base Registrar Implementation of ENS.
 */
interface Registrar {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./IABIResolver.sol";
import "../ResolverBase.sol";

interface IABIResolver {
    event ABIChanged(bytes32 indexed node, uint256 indexed contentType);
    /**
     * Returns the ABI associated with an ENS node.
     * Defined in EIP205.
     * @param node The ENS node to query
     * @param contentTypes A bitwise OR of the ABI formats accepted by the caller.
     * @return contentType The content type of the return value
     * @return data The ABI data
     */
    function ABI(bytes32 node, uint256 contentTypes) external view returns (uint256, bytes memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/**
 * Interface for the new (multicoin) addr function.
 */
interface IAddressResolver {
    event AddressChanged(bytes32 indexed node, uint coinType, bytes newAddress);

    function addr(bytes32 node, uint coinType) external view returns(bytes memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/**
 * Interface for the legacy (ETH-only) addr function.
 */
interface IAddrResolver {
    event AddrChanged(bytes32 indexed node, address a);

    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) external view returns (address payable);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IContentHashResolver {
    event ContenthashChanged(bytes32 indexed node, bytes hash);

    /**
     * Returns the contenthash associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function contenthash(bytes32 node) external view returns (bytes memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IDNSRecordResolver {
    // DNSRecordChanged is emitted whenever a given node/name/resource's RRSET is updated.
    event DNSRecordChanged(bytes32 indexed node, bytes name, uint16 resource, bytes record);
    // DNSRecordDeleted is emitted whenever a given node/name/resource's RRSET is deleted.
    event DNSRecordDeleted(bytes32 indexed node, bytes name, uint16 resource);
    // DNSZoneCleared is emitted whenever a given node's zone information is cleared.
    event DNSZoneCleared(bytes32 indexed node);

    /**
     * Obtain a DNS record.
     * @param node the namehash of the node for which to fetch the record
     * @param name the keccak-256 hash of the fully-qualified name for which to fetch the record
     * @param resource the ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types
     * @return the DNS record in wire format if present, otherwise empty
     */
    function dnsRecord(bytes32 node, bytes32 name, uint16 resource) external view returns (bytes memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IDNSZoneResolver {
    // DNSZonehashChanged is emitted whenever a given node's zone hash is updated.
    event DNSZonehashChanged(bytes32 indexed node, bytes lastzonehash, bytes zonehash);

    /**
     * zonehash obtains the hash for the zone.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function zonehash(bytes32 node) external view returns (bytes memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IInterfaceResolver {
    event InterfaceChanged(bytes32 indexed node, bytes4 indexed interfaceID, address implementer);

    /**
     * Returns the address of a contract that implements the specified interface for this name.
     * If an implementer has not been set for this interfaceID and name, the resolver will query
     * the contract at `addr()`. If `addr()` is set, a contract exists at that address, and that
     * contract implements EIP165 and returns `true` for the specified interfaceID, its address
     * will be returned.
     * @param node The ENS node to query.
     * @param interfaceID The EIP 165 interface ID to check for.
     * @return The address that implements this interface, or 0 if the interface is unsupported.
     */
    function interfaceImplementer(bytes32 node, bytes4 interfaceID) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface INameResolver {
    event NameChanged(bytes32 indexed node, string name);

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in EIP181.
     * @param node The ENS node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IPubkeyResolver {
    event PubkeyChanged(bytes32 indexed node, bytes32 x, bytes32 y);

    /**
     * Returns the SECP256k1 public key associated with an ENS node.
     * Defined in EIP 619.
     * @param node The ENS node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubkey(bytes32 node) external view returns (bytes32 x, bytes32 y);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface ITextResolver {
    event TextChanged(bytes32 indexed node, string indexed indexedKey, string key);

    /**
     * Returns the text data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return The associated text data.
     */
    function text(bytes32 node, string calldata key) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISupportsInterface {
    function supportsInterface(bytes4 interfaceID) external pure returns(bool);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./SupportsInterface.sol";

abstract contract ResolverBase is SupportsInterface {
    function isAuthorised(bytes32 node) internal virtual view returns(bool);

    modifier authorised(bytes32 node) {
        require(isAuthorised(node));
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ISupportsInterface.sol";

abstract contract SupportsInterface is ISupportsInterface {
    function supportsInterface(bytes4 interfaceID) virtual override public pure returns(bool) {
        return interfaceID == type(ISupportsInterface).interfaceId;
    }
}