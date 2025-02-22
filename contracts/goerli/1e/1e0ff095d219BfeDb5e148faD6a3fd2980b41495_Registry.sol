// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRegistry.sol";

contract Registry is IRegistry {
    struct Record {
        address owner;
        address resolver;
    }

    mapping(bytes32 => Record) public records;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyRecordOwner(bytes32 node_) {
        require(
            records[node_].owner == msg.sender,
            "Ownable: caller is not the record owner"
        );
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyRecordOwnerByName(string memory nodeName_) {
        require(
            records[keccak256(abi.encode(nodeName_))].owner == msg.sender,
            "Ownable: caller is not the record owner"
        );
        _;
    }

    /**
    * @dev Adds a new record for a node.
     * @param nodeName_ The node to create.
     * @param owner_ The address of the new owner.
     * @param resolver_ The address of the resolver.
     */
    function setRecordByName(
        string memory nodeName_,
        address owner_,
        address resolver_
    ) external virtual override {
        return setRecord(keccak256(abi.encode(nodeName_)), owner_, resolver_);
    }

    /**
     * @dev Adds a new record for a node.
     * @param node_ The node to create.
     * @param owner_ The address of the new owner.
     * @param resolver_ The address of the resolver.
     */
    function setRecord(
        bytes32 node_,
        address owner_,
        address resolver_
    ) public virtual override {
        require(!recordExists(node_), "Node already exists");
        _setOwner(node_, owner_);
        _setResolver(node_, resolver_);
        emit NewRecord(node_, owner_, resolver_);
    }

    /**
     * @dev Transfers ownership of a node to a new address. May only be called by the current owner of the node.
     * @param node_ The node to transfer ownership of.
     * @param owner_ The address of the new owner.
     */
    function setOwner(bytes32 node_, address owner_)
        public
        virtual
        override
        onlyRecordOwner(node_)
    {
        _setOwner(node_, owner_);
        emit Transfer(node_, owner_);
    }

    /**
    * @dev Transfers ownership of a node to a new address. May only be called by the current owner of the node.
     * @param nodeName_ The name of the node to transfer ownership of.
     * @param owner_ The address of the new owner.
     */
    function setOwnerByName(string memory nodeName_, address owner_)
        external
        virtual
        override
        onlyRecordOwnerByName(nodeName_)
    {
        return setOwner(keccak256(abi.encode(nodeName_)), owner_);
    }

    /**
     * @dev Sets the resolver address for the specified node.
     * @param node_ The node to update.
     * @param resolver_ The address of the resolver.
     */
    function setResolver(bytes32 node_, address resolver_)
        public
        virtual
        override
        onlyRecordOwner(node_)
    {
        emit NewResolver(node_, resolver_);
        records[node_].resolver = resolver_;
    }

    /**
    * @dev Sets the resolver address for the specified node name.
     * @param nodeName_ The name of the node to update.
     * @param resolver_ The address of the resolver.
     */
    function setResolverByName(string memory nodeName_, address resolver_)
        external
        virtual
        override
        onlyRecordOwnerByName(nodeName_)
    {
        return setResolver(keccak256(abi.encode(nodeName_)), resolver_);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node_ The specified node.
     * @return address of the owner.
     */
    function owner(bytes32 node_)
        public
        view
        virtual
        override
        returns (address)
    {
        address addr = records[node_].owner;
        if (addr == address(this)) {
            return address(0x0);
        }

        return addr;
    }

    /**
    * @dev Returns the address that owns the specified node.
     * @param nodeName_ The name of the specified node.
     * @return address of the owner.
     */
    function ownerByName(string memory nodeName_)
        external
        view
        virtual
        override
        returns (address)
    {
        return owner(keccak256(abi.encode(nodeName_)));
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node_ The specified node.
     * @return address of the resolver.
     */
    function resolver(bytes32 node_)
        external
        view
        virtual
        override
        returns (address)
    {
        return records[node_].resolver;
    }

    /**
    * @dev Returns the address of the resolver for the specified node name.
     * @param nodeName_ The specified node name.
     * @return address of the resolver.
     */
    function resolverByName(string memory nodeName_)
        external
        view
        virtual
        override
        returns (address)
    {
        return records[keccak256(abi.encode(nodeName_))].resolver;
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param node_ The specified node.
     * @return Bool if record exists
     */
    function recordExists(bytes32 node_)
        public
        view
        virtual
        override
        returns (bool)
    {
        return records[node_].owner != address(0x0);
    }

    /**
    * @dev Returns whether a record has been imported to the registry.
     * @param nodeName_ The specified node name.
     * @return Bool if record exists
     */
    function recordExistsByName(string memory nodeName_)
        external
        view
        virtual
        override
        returns (bool)
    {
        return records[keccak256(abi.encode(nodeName_))].owner != address(0x0);
    }

    function _setOwner(bytes32 node_, address owner_) internal virtual {
        records[node_].owner = owner_;
    }

    function _setResolver(bytes32 node_, address resolver_) internal {
        records[node_].resolver = resolver_;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    // Logged when new record is created.
    event NewRecord(bytes32 indexed node, address owner, address resolver);

    // Logged when the owner of a node transfers ownership to a new account.
    event Transfer(bytes32 indexed node, address owner);

    // Logged when the resolver for a node changes.
    event NewResolver(bytes32 indexed node, address resolver);

    function setRecord(
        bytes32 node_,
        address owner_,
        address resolver_
    ) external;
    function setRecordByName(
        string memory nodeName_,
        address owner_,
        address resolver_
    ) external;

    function setResolver(bytes32 node_, address resolver_) external;
    function setResolverByName(string memory nodeName_, address resolver_) external;

    function setOwner(bytes32 node_, address owner_) external;
    function setOwnerByName(string memory nodeName_, address owner_) external;

    function owner(bytes32 node_) external view returns (address);
    function ownerByName(string memory nodeName_) external view returns (address);

    function resolver(bytes32 node_) external view returns (address);
    function resolverByName(string memory nodeName_) external view returns (address);

    function recordExists(bytes32 node_) external view returns (bool);
    function recordExistsByName(string memory nodeName_) external view returns (bool);
}