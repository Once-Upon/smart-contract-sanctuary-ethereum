// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "minter.sol";

contract BridgeMinter{
    address internal pendingOwner;
    address private owner;
    address private notary;
    address private approver;
    address private tokenAddress;
    bool paused = false;
    bool private bridging;

    mapping(bytes32 => bool) private nonces;

    event Bridged(address receiver, uint256 amount);
    event TransferOwnership(address indexed owner, bool indexed confirmed);

    constructor(address _owner, address _approver, address _notary, address _tokenAddress){
        require(_owner != address(0)); // dev: invalid owner
        require(_approver != address(0)); // dev: invalid approver
        require(_notary != address(0)); // dev: invalid notary
        require(_tokenAddress != address(0)); // dev: invalid notary
        owner = _owner;
        approver = _approver;
        notary = _notary;
        tokenAddress = _tokenAddress;
    }

    modifier onlyOwner() {
        require(msg.sender == owner); // dev: invalid owner
        _;
    }

    modifier checkNonce(bytes32 nonce) {
        require(nonces[nonce]==false); // dev: already processed
        _;
    }

    function transferOwnership(address newOwner)
    external
    onlyOwner() {
        pendingOwner = newOwner;

        emit TransferOwnership(pendingOwner, false);
    }

    function confirmOwnership()
    external {
        require(msg.sender == pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);

        emit TransferOwnership(owner, true);
    }

    function setPaused()
    external
    onlyOwner {
        paused = !paused;
    }

    function setApprover(address replacement)
    external
    onlyOwner {
        require(replacement != address(0));
        approver = replacement;
    }

    function setNotary(address replacement)
    external
    onlyOwner {
        require(replacement != address(0));
        notary = replacement;
    }

    function bridge(address sender, uint256 bridgedAmount, bytes32 nonce, bytes32 messageHash, bytes calldata approvedMessage, bytes calldata notarizedMessage) 
    external checkNonce(nonce){
        require(bridging == false); //dev: re-entrancy guard
        bridging = true;
        bytes32 hashToVerify = keccak256(
            abi.encodePacked(nonce,sender, bridgedAmount)
        );

        require(checkEncoding(approvedMessage,messageHash,hashToVerify,approver)); //dev: invalid signature
        require(checkEncoding(notarizedMessage,messageHash,hashToVerify,notary)); //dev: invalid signature
        nonces[nonce]=true;

        IMinter(tokenAddress).mint(sender, bridgedAmount);

        emit Bridged(sender, bridgedAmount);
        bridging = false;
    }

    function checkEncoding(bytes memory signedMessage,bytes32 messageHash, bytes32 hashToVerify, address signer) 
    internal pure returns(bool){

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix,hashToVerify));
        require(messageHash == prefixedHash); //dev: values do not match

        return signer == recoverSigner(messageHash, signedMessage);
    }

    function splitSignature(bytes memory sig)
    internal pure returns (uint8 v, bytes32 r, bytes32 s){
        require(sig.length == 65); // dev: signature invalid

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig)
    internal pure returns (address){
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

/**
 * @dev Interface of to mint ERC20 tokens.
 */
interface IMinter {
    function mint(address to, uint256 value) external;
}