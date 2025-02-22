/**
 *Submitted for verification at Etherscan.io on 2022-11-18
*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBaseRegistrarImplementation {
    function ownerOf(uint256 tokenId) external view returns (address);
    function reclaim(uint256 id, address owner) external;
    function transferFrom(address from, address to, uint256 tokenId) external;

}

interface IENSRegistryWithFallback {
    function setResolver(bytes32 node, address resolver) external;
}

interface IResolver {
    function setContenthash(bytes32 node, bytes calldata hash) external;
}

contract ENSBatchOps {
    IBaseRegistrarImplementation ensRegistrar = IBaseRegistrarImplementation(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    struct WhatToSet {
        bool shouldSetController;
        bool shouldSetResolver;
        bool shouldSetContenthash;
    }

    function batchUpdate(
        uint256[] calldata ids,
        address controller,
        address resolver,
        bytes[] calldata contenthashes,
        WhatToSet[] calldata whatToSet
    ) public {
        // process each domain individually
        for (uint i=0; i<ids.length; i++){
            // check if the domain is owned
            require(msg.sender == ensRegistrar.ownerOf(ids[i]), "You do not own all the domains");

            // temporarily transfer domain to this contract
            ensRegistrar.transferFrom(msg.sender, address(this), ids[i]);

            // update
            if (whatToSet[i].shouldSetController) {
                ensRegistrar.reclaim(ids[i], controller);
            }
            if (whatToSet[i].shouldSetResolver) {
                ensRegistry.setResolver(ethNamehash(ids[i]), resolver);
            }
            if (whatToSet[i].shouldSetContenthash) {
                IResolver(resolver).setContenthash(ethNamehash(ids[i]), contenthashes[i]);
            }

            // transfer the domain back to the original owner
            ensRegistrar.transferFrom(address(this), msg.sender, ids[i]);
        }
    }

    function ethNamehash(uint id) public pure returns (bytes32 namehash) {
        bytes32 eth = keccak256(abi.encodePacked(
            uint(0),
            keccak256(abi.encodePacked('eth'))
        ));
        return keccak256(abi.encodePacked(
            eth,
            id
        ));
    }

}