/**
 *Submitted for verification at Etherscan.io on 2022-12-05
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address, RecoverError)
    {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs &
            bytes32(
                0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            );
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash)
        internal
        pure
        returns (bytes32)
    {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n",
                    Strings.toString(s.length),
                    s
                )
            );
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
    }
}

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712 {
    /* solhint-disable var-name-mixedcase */
    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    address private immutable _CACHED_THIS;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    bytes32 private immutable _TYPE_HASH;

    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(
            typeHash,
            hashedName,
            hashedVersion
        );
        _CACHED_THIS = address(this);
        _TYPE_HASH = typeHash;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (
            address(this) == _CACHED_THIS && block.chainid == _CACHED_CHAIN_ID
        ) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return
                _buildDomainSeparator(
                    _TYPE_HASH,
                    _HASHED_NAME,
                    _HASHED_VERSION
                );
        }
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    typeHash,
                    nameHash,
                    versionHash,
                    block.chainid,
                    address(this)
                )
            );
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash)
        internal
        view
        virtual
        returns (bytes32)
    {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}

interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
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
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
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

// contract Pausable is Ownable {
//   event Pause();
//   event Unpause();

//   bool public paused = false;

//   /**
//    * @dev Modifier to make a function callable only when the contract is not paused.
//    */
//   modifier whenNotPaused() {
//     require(!paused);
//     _;
//   }

//   /**
//    * @dev Modifier to make a function callable only when the contract is paused.
//    */
//   modifier whenPaused() {
//     require(paused);
//     _;
//   }
//   /**
//    * @dev called by the owner to pause, triggers stopped state
//    */
//   function pause() onlyOwner whenNotPaused public {
//     paused = true;
//     emit Pause();
//   }

//   /**
//    * @dev called by the owner to unpause, returns to normal state
//    */
//   function unpause() onlyOwner whenPaused public {
//     paused = false;
//     emit Unpause();
//   }
// }
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

interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

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
}




contract Proxiable {
    // Code position in storage is keccak256("PROXIABLE") = "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"

    function updateCodeAddress(address newAddress) internal {
        require(
            bytes32(0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7) == Proxiable(newAddress).proxiableUUID(),
            "Not compatible"
        );
        assembly { // solium-disable-line
            sstore(0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7, newAddress)
        }
    }

    function proxiableUUID() public pure returns (bytes32) {
        return 0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7;
    }
} 



contract MarketplaceTest is  Proxiable ,EIP712("Voucher-Domain", "1")

{
    // string private constant SIGNING_DOMAIN = "Voucher-Domain";
    // string private constant SIGNATURE_VERSION = "1";
    uint256 public marketplaceFEE;
    address public marketOwner;
    // address public owner;
    uint public count;
    bool public initalized = false;

  //   constructor() EIP712("Voucher-Domain", "1"){}
    function initialize()  public {
           
        require(marketOwner == address(0), "Already initalized");
        require(!initalized, "Already initalized");
        marketOwner = msg.sender;
        initalized = true;

        
    }
   

    struct Order {
        uint256 tokenId;
        uint256 ethPrice;
        uint256 tokenPrice;
        uint256 createdTime;
        address tokenAddress;
        address coinAddress;
        // address seller;
        bytes signature;
    }

    struct AuctionData {
        // bytes32 auctionId;
        uint256 tokenId;
        uint256 minBid; // Selling Price
        uint256 expiryTime;
        uint256 createdTime;
        address tokenAddress;
        address coinAddress; // can be eth or any Erc-20 token
        // address payable seller;
        bytes signature;
    }

    struct BidData {
        uint256 tokenId;
        uint256 tokenPrice;
        address tokenAddress;
        address coinAddress;
        // address Bidder;
        bytes signature;
    }

    // **********   offer section   **********
    struct Offer {
        uint256 tokenId;
        uint256 Price;
        uint256 time;
        address tokenAddress;
        address coinAddress;
        bytes signature;
    }

    struct Status {
        bool isCancel;
    }

    // struct OrderStatus{
    //     bool isvalid;
    // }

    // struct AuctionStatusStruct{
    //     bool isCancel;
    // }

    struct royalty {
        address contractADDress;
        address owner;
        uint256 amount;
    }

    // Events
    event buyOrderSuccessfull(
        bytes signature,
        address buyer,
        address indexed tokenAddress,
        address indexed coinAddress,
        uint256 indexed tokenId
    );

    event buyOrderCancel(
        bytes signature,
        address buyer,
        address indexed tokenAddress,
        address indexed coinAddress,
        uint256 indexed tokenId
    );

    event offerAccepted(
        bytes signature,
        address buyer,
        address indexed tokenAddress,
        address indexed coinAddress,
        uint256 indexed tokenId
    );

    event offerCancel(
        bytes signature,
        address buyer,
        address indexed tokenAddress,
        address indexed coinAddress,
        uint256 indexed tokenId
    );

    event bidAccepted(
        bytes signature,
        address buyer,
        address indexed tokenAddress,
        address indexed coinAddress,
        uint256 indexed tokenId
    );

    event auctionCancel(
        bytes signature,
        address seller,
        address indexed tokenAddress,
        address indexed coinAddress,
        uint256 indexed tokenId
    );

    // mappings

    // mapping(bytes=>OrderStatus) public orderMap;

    // mapping(bytes=>AuctionStatusStruct) public AuctionStatus;

    // mapping(bytes=>offerStatus) public offerMapping;

    mapping(bytes => Status) public sigValidation;

    mapping(address => mapping(uint256 => Order)) public orderByTokenId;

    mapping(address => royalty) public Royalties;

    //...............................ROYALTIES SECTION............................................................................................................................................

    // for royalties

    function setRoyaltie(address _tokenAddress, uint256 _royaltyAmount) public {
        require(
            _royaltyAmount <= 10000000000000000000,
            "please enter value beteen 0-10 "
        );

        Ownable tokenRegistry = Ownable(_tokenAddress);
        require(tokenRegistry.owner() == msg.sender, "only owner");

        Royalties[_tokenAddress].contractADDress = _tokenAddress;
        Royalties[_tokenAddress].owner = msg.sender;
        Royalties[_tokenAddress].amount = _royaltyAmount;
    }



  function updateCode(address newCode) onlyOwner public {
        updateCodeAddress(newCode);
    }
    function increment() public {
        count++;
    }
    function decrement() public {
        count--;
    }

     modifier onlyOwner() {
        require(msg.sender == marketOwner, "Only owner is allowed to perform this action");
        _;
    }
    //set market Owner and fees
    // percentage of sale that goes to marketplace (e.g: 2.5)

    function setmarketplaceFEE(uint256 _newPrice) public onlyOwner {
        marketplaceFEE = _newPrice;
    }

    function setmarketOwner(address _marketOwner) public onlyOwner {
        marketOwner = _marketOwner;
    }

    function recoverOrder(Order calldata order) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    // keccak256("Order(uint256 tokenId,uint256 ethPrice,uint256 tokenPrice,uint256 createdTime,address tokenAddress,address coinAddress,address seller)"),
                    keccak256(
                        "Order(uint256 tokenId,uint256 ethPrice,uint256 tokenPrice,uint256 createdTime,address tokenAddress,address coinAddress)"
                    ),
                    order.tokenId,
                    order.ethPrice,
                    order.tokenPrice,
                    order.createdTime,
                    order.tokenAddress,
                    order.coinAddress
                    // order.seller
                )
            )
        );
        address signer = ECDSA.recover(digest, order.signature);
        return signer;
    }

    function recoverAuction(AuctionData calldata auction)
        public
        view
        returns (address)
    {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    // keccak256("AuctionData(uint256 tokenId,uint256 minBid,uint256 expiryTime,uint256 createdTime,address tokenAddress,address coinAddress,address seller)"),
                    keccak256(
                        "AuctionData(uint256 tokenId,uint256 minBid,uint256 expiryTime,uint256 createdTime,address tokenAddress,address coinAddress)"
                    ),
                    auction.tokenId,
                    auction.minBid,
                    auction.expiryTime,
                    auction.createdTime,
                    auction.tokenAddress,
                    auction.coinAddress
                    // auction.seller
                )
            )
        );
        address signer = ECDSA.recover(digest, auction.signature);
        return signer;
    }

    function recoverBid(BidData calldata bid) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    // keccak256("BidData(uint256 tokenId,uint256 tokenPrice,address tokenAddress,address coinAddress,address Bidder)"),
                    keccak256(
                        "BidData(uint256 tokenId,uint256 tokenPrice,address tokenAddress,address coinAddress)"
                    ),
                    bid.tokenId,
                    bid.tokenPrice,
                    bid.tokenAddress,
                    bid.coinAddress
                    // bid.Bidder
                )
            )
        );
        address signer = ECDSA.recover(digest, bid.signature);
        return signer;
    }

    function recoverOffer(Offer calldata offer) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "Offer(uint256 tokenId,uint256 Price,uint256 time,address tokenAddress,address coinAddress)"
                    ),
                    offer.tokenId,
                    offer.Price,
                    offer.time,
                    offer.tokenAddress,
                    offer.coinAddress
                )
            )
        );
        address signer = ECDSA.recover(digest, offer.signature);
        return signer;
    }

    function buyOrder1(Order calldata order) public payable {
        //check orderStatus
        require(
            sigValidation[order.signature].isCancel == false,
            "order not active"
        );

        // Check nft registry
        IERC721 tokenRegistry = IERC721(order.tokenAddress);

        // Check order creator is the asset owner

        address tokenOwner = tokenRegistry.ownerOf(order.tokenId);

        require(
            tokenOwner == recoverOrder(order),
            "Marketplace: Only the asset owner can create orders"
        );

        // getting values for royalties
        uint256 royaltyAmount = Royalties[order.tokenAddress].amount;
        address owner = Royalties[order.tokenAddress].owner;

        if (order.coinAddress == 0x0000000000000000000000000000000000000000) {
            require(order.ethPrice > 0, "not enough funds send"); // we should also use _tokenPrice > 0
            require(order.ethPrice == msg.value, "Marketplace: invalid price");

            //royalty calculation
            uint256 value = msg.value; // we can also use oder.amount
            uint256 royaltyCut = (value * royaltyAmount) /
                100000000000000000000;
            uint256 MP_FEE = (value * marketplaceFEE) / 100000000000000000000;
            uint256 sellerCut = value - (royaltyCut + MP_FEE);

            if (royaltyAmount == 0) {
                payable(recoverOrder(order)).transfer(sellerCut);
                payable(marketOwner).transfer(MP_FEE);
            } else {
                payable(recoverOrder(order)).transfer(sellerCut);

                payable(owner).transfer(royaltyCut);

                payable(marketOwner).transfer(MP_FEE);
            }
        } else {
            IERC20 Token;
            Token = IERC20(order.coinAddress);

            // address CoinAddress=order.coinAddress;
            // require (CoinAddress==_coinAddress,"use same token");
            require(
                order.tokenPrice <= Token.balanceOf(msg.sender),
                "Marketplace: invalid price"
            );
            require(
                recoverOrder(order) != msg.sender,
                "Marketplace: unauthorized sender"
            );

            uint256 royaltyCut = (order.tokenPrice * royaltyAmount) /
                100000000000000000000;
            uint256 MP_FEE = (order.tokenPrice * marketplaceFEE) /
                100000000000000000000;
            uint256 sellerCut = order.tokenPrice - (royaltyCut + MP_FEE);
            if (royaltyAmount == 0) {
                Token.transferFrom(msg.sender, recoverOrder(order), sellerCut);
                Token.transferFrom(msg.sender, marketOwner, MP_FEE);
            } else {
                Token.transferFrom(msg.sender, recoverOrder(order), sellerCut);
                Token.transferFrom(msg.sender, owner, royaltyCut);
                Token.transferFrom(msg.sender, marketOwner, MP_FEE);
            }
        }

        tokenRegistry.safeTransferFrom(tokenOwner, msg.sender, order.tokenId);

        sigValidation[order.signature].isCancel = true;

        emit buyOrderSuccessfull(
            order.signature,
            msg.sender,
            order.tokenAddress,
            order.coinAddress,
            order.tokenId
        );
    }

    function cancelOrder(Order calldata order) public returns (bool) {
        require(
            sigValidation[order.signature].isCancel == false,
            "order already cancel"
        ); //  we think this is optional as order is different from each other due to time but this is extra security we can rethink about this

        // Check nft registry
        IERC721 tokenRegistry = IERC721(order.tokenAddress);

        // Check order creator is the asset owner

        address tokenOwner = tokenRegistry.ownerOf(order.tokenId);

        // require(msg.sender == tokenOwner,"ony owner");

        require(
            msg.sender == recoverOrder(order) && msg.sender == tokenOwner,
            "only owner"
        );

        sigValidation[order.signature].isCancel = true;

        emit buyOrderCancel(
            order.signature,
            msg.sender,
            order.tokenAddress,
            order.coinAddress,
            order.tokenId
        );

        return sigValidation[order.signature].isCancel;
    }

    // Auction section

    function acceptBid(AuctionData calldata auction, BidData calldata biD)
        public
    {
        //check auctionrStatus
        require(
            sigValidation[auction.signature].isCancel == false,
            "order not active"
        );

        // Check nft registry

        IERC721 tokenRegistry = IERC721(auction.tokenAddress);
        //coinAdrress object

        IERC20 Token = IERC20(auction.coinAddress);

        // Check order creator is the asset owner

        address tokenOwner = tokenRegistry.ownerOf(auction.tokenId);

        require(
            tokenOwner == recoverAuction(auction),
            "Marketplace: Only the asset owner can create orders"
        );
        // require(biD.Bidder == recoverBid(biD),"INVALID bidder");

        require(
            Token.balanceOf(recoverBid(biD)) >= biD.tokenPrice,
            "dont have enough tokens"
        );

        // require(block.timestamp > bidData.auctionEndTime,"Auction is not ended");

        //    getting values for royalties

        uint256 royaltyAmount = Royalties[auction.tokenAddress].amount;
        address owner = Royalties[auction.tokenAddress].owner;

        if (royaltyAmount == 0) {
            //royalty calculation
            uint256 MP_FEE = (biD.tokenPrice * marketplaceFEE) /
                100000000000000000000;
            uint256 sellerCut = biD.tokenPrice - MP_FEE;

            //sending aura
            Token.transferFrom(recoverBid(biD), msg.sender, sellerCut);
            Token.transferFrom(recoverBid(biD), marketOwner, MP_FEE);
        } else {
            //royalty calculation
            uint256 royaltyCut = (biD.tokenPrice * royaltyAmount) /
                100000000000000000000;
            uint256 MP_FEE = (biD.tokenPrice * marketplaceFEE) /
                100000000000000000000;
            uint256 sellerCut = biD.tokenPrice - (royaltyCut + MP_FEE);

            // sending aura
            Token.transferFrom(recoverBid(biD), msg.sender, sellerCut);
            Token.transferFrom(recoverBid(biD), owner, royaltyCut);
            Token.transferFrom(recoverBid(biD), marketOwner, MP_FEE);
        }

        tokenRegistry.safeTransferFrom(
            recoverAuction(auction),
            recoverBid(biD),
            auction.tokenId
        );

        emit bidAccepted(
            auction.signature,
            recoverBid(biD),
            biD.tokenAddress,
            biD.coinAddress,
            biD.tokenId
        );

        sigValidation[auction.signature].isCancel = true;
    }

    //cancel auction
    function cancelAuction(AuctionData calldata auction) public returns (bool) {
        require(
            sigValidation[auction.signature].isCancel == false,
            "order not active"
        );

        require(
            msg.sender == recoverAuction(auction),
            "Marketplace: Only the asset owner can cancel auction"
        );

        sigValidation[auction.signature].isCancel = true;

        emit auctionCancel(
            auction.signature,
            msg.sender,
            auction.tokenAddress,
            auction.coinAddress,
            auction.tokenId
        );

        return sigValidation[auction.signature].isCancel;
    }

    // Offer section

    function acceptOffer(Offer calldata offer) public {
        require(
            sigValidation[offer.signature].isCancel == false,
            "order not active"
        );

        IERC721 tokenRegistry = IERC721(offer.tokenAddress);

        IERC20 Token = IERC20(offer.coinAddress);

        require(
            msg.sender == tokenRegistry.ownerOf(offer.tokenId),
            "only owner"
        );
        require(
            offer.Price <= Token.balanceOf(recoverOffer(offer)),
            "not enough token balance sent"
        );

        address seller = recoverOffer(offer);

        //    getting values for royalties

        uint256 royaltyAmount = Royalties[offer.tokenAddress].amount;
        address owner = Royalties[offer.tokenAddress].owner;

        if (royaltyAmount == 0) {
            //royalty calculation
            uint256 MP_FEE = (offer.Price * marketplaceFEE) /
                100000000000000000000;
            uint256 sellerCut = offer.Price - MP_FEE;

            //sending aura
            Token.transferFrom(seller, msg.sender, sellerCut);
            Token.transferFrom(seller, marketOwner, MP_FEE);
        } else {
            //royalty calculation
            uint256 royaltyCut = (offer.Price * royaltyAmount) /
                100000000000000000000;
            uint256 MP_FEE = (offer.Price * marketplaceFEE) /
                100000000000000000000;
            uint256 sellerCut = offer.Price - (royaltyCut + MP_FEE);

            // sending aura
            Token.transferFrom(seller, msg.sender, sellerCut);
            Token.transferFrom(seller, owner, royaltyCut);
            Token.transferFrom(seller, marketOwner, MP_FEE);
        }

        // sending token
        tokenRegistry.safeTransferFrom(msg.sender, seller, offer.tokenId);

        emit offerAccepted(
            offer.signature,
            msg.sender,
            offer.tokenAddress,
            offer.coinAddress,
            offer.tokenId
        );

        sigValidation[offer.signature].isCancel = true;
    }

    function cancelOffer(Offer calldata offer) public returns (bool) {
        require(
            sigValidation[offer.signature].isCancel == false,
            "order already cancel"
        ); //  we think this is optional as order is different from each other due to time but this is extra security we can rethink about this

        require(msg.sender == recoverOffer(offer), "only owner");

        sigValidation[offer.signature].isCancel = true;

        emit offerCancel(
            offer.signature,
            recoverOffer(offer),
            offer.tokenAddress,
            offer.coinAddress,
            offer.tokenId
        );

        return sigValidation[offer.signature].isCancel;
    }

    function withdraw() public onlyOwner {
        uint256 totalbalance = address(this).balance;
        (bool hq, ) = payable(marketOwner).call{value: totalbalance}("");
        require(hq);
    }
}