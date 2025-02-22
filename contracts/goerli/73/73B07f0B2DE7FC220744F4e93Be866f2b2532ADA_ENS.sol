// See https://github.com/ensdomains/ens/blob/7e377df83f/contracts/ENS.sol

pragma solidity 0.4.26;


import "./AbstractENS.sol";

/**
 * The ENS registry contract.
 */
contract ENS is AbstractENS {
    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
    }

    mapping(bytes32=>Record) records;

    // Permits modifications only by the owner of the specified node.
    modifier only_owner(bytes32 node) {
        if (records[node].owner != msg.sender) throw;
        _;
    }

    /**
     * Constructs a new ENS registrar.
     */
    function ENS() public {
        records[0].owner = msg.sender;
    }

    /**
     * Returns the address that owns the specified node.
     */
    function owner(bytes32 node) public constant returns (address) {
        return records[node].owner;
    }

    /**
     * Returns the address of the resolver for the specified node.
     */
    function resolver(bytes32 node) public constant returns (address) {
        return records[node].resolver;
    }

    /**
     * Returns the TTL of a node, and any records associated with it.
     */
    function ttl(bytes32 node) public constant returns (uint64) {
        return records[node].ttl;
    }

    /**
     * Transfers ownership of a node to a new address. May only be called by the current
     * owner of the node.
     * @param node The node to transfer ownership of.
     * @param owner The address of the new owner.
     */
    function setOwner(bytes32 node, address owner) only_owner(node) public {
        Transfer(node, owner);
        records[node].owner = owner;
    }

    /**
     * Transfers ownership of a subnode keccak256(node, label) to a new address. May only be
     * called by the owner of the parent node.
     * @param node The parent node.
     * @param label The hash of the label specifying the subnode.
     * @param owner The address of the new owner.
     */
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) only_owner(node) public {
        var subnode = keccak256(node, label);
        NewOwner(node, label, owner);
        records[subnode].owner = owner;
    }

    /**
     * Sets the resolver address for the specified node.
     * @param node The node to update.
     * @param resolver The address of the resolver.
     */
    function setResolver(bytes32 node, address resolver) only_owner(node) public {
        NewResolver(node, resolver);
        records[node].resolver = resolver;
    }

    /**
     * Sets the TTL for the specified node.
     * @param node The node to update.
     * @param ttl The TTL in seconds.
     */
    function setTTL(bytes32 node, uint64 ttl) only_owner(node) public {
        NewTTL(node, ttl);
        records[node].ttl = ttl;
    }
}