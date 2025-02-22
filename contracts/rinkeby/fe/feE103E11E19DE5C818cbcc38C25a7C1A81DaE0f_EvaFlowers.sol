// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./FlorToken.sol";

import "./Lab.sol";

contract EvaFlowers is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    uint256 public MAX_TOKENS = 40000; //Max supply of tokens

    uint256 public MINTED_FLOWERS;
    string[] public traits = [
        "Amber",
        "Woody",
        "Flowery",
        "Citrus",
        "Oriental",
        "Fruity"
    ];
    /*Flowers are distributed are follow:
     1500 flowers are going to hold 8 cc
     3000 flowers are going to hold 9 cc
     ....
    */
    uint16[] public flowersDistribution = [
        1500,
        3000,
        6000,
        7500,
        12000,
        3520,
        2200,
        1760,
        440,
        352,
        264,
        176,
        88,
        77,
        77,
        77,
        77,
        66,
        66,
        66,
        66,
        55,
        55,
        55,
        55,
        44,
        44,
        44,
        44,
        33,
        33,
        33,
        33,
        12,
        11,
        10,
        10,
        10,
        10,
        10,
        10,
        10,
        7
    ];
    Lab public lab;

    struct Flower {
        string name;
        uint256 trait;
        uint256 cc;
    }

    mapping(uint256 => Flower) public FlowerCollection;

    constructor() ERC721("EvaFlore Flowers", "FLOWERS") {}

    function mint(address _to) public whenNotPaused {
        require(_msgSender() == address(lab), "Only Lab");

        require(MINTED_FLOWERS <= MAX_TOKENS, "Mint ended");

        _safeMint(_to, MINTED_FLOWERS);
        generate(MINTED_FLOWERS);
        MINTED_FLOWERS++;
    }

    function generate(uint256 tokenId) internal {
        uint256 randomTrait = randomNum(6, block.difficulty, tokenId);
        uint256 numberOfCC = generateRandomCC(tokenId);
        Flower memory newflower = Flower(
            string(abi.encodePacked("Flower #", uint256(tokenId).toString())),
            randomTrait,
            numberOfCC
        );

        FlowerCollection[tokenId] = newflower;
    }

    function getFlowerCC(uint256 tokenId) external view returns (uint256) {
        return FlowerCollection[tokenId].cc;
    }

    /*
@Dev
Gets a random cc based on the flowers distribution
*CC values start from 8 to 50 
*Total numnber of cc values is 43
*The flowersDistribution array is indexed from 0 to 42
*Returns a random number from 0 to 42 and adds up 8 to round it to a correct cc value
*After a cc value is allocated to a flower we decrease the number of flowers allowed to havesame value
*/

    function generateRandomCC(uint256 _tokenId)
        internal
        returns (uint256 value)
    {
        uint256 random = randomNum(43, block.difficulty, _tokenId);
        uint256 ccValue = random + 8;
        if (flowersDistribution[random] > 0) {
            flowersDistribution[random] = flowersDistribution[random] - 1;
            return ccValue;
        } else {
            generateRandomCC(random + 1);
        }
    }

    function getFlowerTraitIndex(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return FlowerCollection[tokenId].trait;
    }

    function randomNum(
        uint256 _mod,
        uint256 _salt,
        uint256 _seed
    ) public view returns (uint256) {
        uint256 num = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    block.number,
                    _salt,
                    _seed
                )
            )
        ) % _mod;
        return num;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function buildMetadata(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        Flower memory token = FlowerCollection[_tokenId];
        string memory baseURI = _baseURI();
        return
            string(
                abi.encodePacked(
                    "data:application/json,",
                    abi.encodePacked(
                        '{"name":"',
                        token.name,
                        '", "trait":"',
                        traits[token.trait],
                        '", "cc":"',
                        (token.cc).toString(),
                        '","uri":"',
                        string(
                            abi.encodePacked(baseURI, (_tokenId).toString())
                        ),
                        '"}'
                    )
                )
            );
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return buildMetadata(_tokenId);
    }

    function setLab(address _lab) external onlyOwner {
        lab = Lab(_lab);
    }

    function burnExtraFlower(uint256 tokenId) external {
        require(msg.sender == address(lab), "only lab");
        _burn(tokenId);
    }

    function burnBatchFlowers(uint256[] calldata tokenIds) external {
        require(msg.sender == address(lab), "only lab");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
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
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

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
    function getApproved(uint256 tokenId) external view returns (address operator);

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
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Lab.sol";

contract EvaStore is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    uint256 public MAX_TOKENS = 1000; //Max supply of stores to be minted

    Lab public lab;

    struct Store {
        string name;
    }

    mapping(uint256 => Store) public StoreCollection;

    constructor() ERC721("EvaStore Store", "STORE") {}

    function mint(address _to) public whenNotPaused {
        require(_msgSender() == address(lab), "Only Lab");
        uint256 minted = totalSupply();

        require(minted <= MAX_TOKENS, "Mint ended");

        _safeMint(_to, minted);
        generate(minted);
    }

    function generate(uint256 tokenId) internal {
        Store memory newStore = Store(
            string(abi.encodePacked("STORE #", uint256(tokenId).toString()))
        );

        StoreCollection[tokenId] = newStore;
    }

    function randomNum(
        uint256 _mod,
        uint256 _salt,
        uint256 _seed
    ) public view returns (uint256) {
        uint256 num = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    block.number,
                    _salt,
                    _seed
                )
            )
        ) % _mod;
        return num;
    }

    function buildMetadata(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        Store memory token = StoreCollection[_tokenId];
        string memory baseURI = _baseURI();
        return
            string(
                abi.encodePacked(
                    "data:application/json,",
                    abi.encodePacked( //add rarity
                        '{"name":"',
                        token.name,
                        '","uri":',
                        string(
                            abi.encodePacked(baseURI, (_tokenId).toString())
                        ),
                        '"}'
                    )
                )
            );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return buildMetadata(_tokenId);
    }

    function setLab(address _lab) external onlyOwner {
        lab = Lab(_lab);
    }
}

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./FlorToken.sol";
import "./EvaPerfumes.sol";
import "./EvaFlowers.sol";
import "./Store.sol";

contract Lab is Ownable, IERC721Receiver, Pausable {
    uint256 public constant MINT_WITH_STAKE_PRICE = .0004 ether; //TBD
    uint256 public constant MINT_WITHOUT_STAKE_PRICE = .0005 ether; //TBD
    uint256 public MAX_MINTABLE_TOKENS = 44500; //Max mintable FLOWERS+STORES+PERFUMES
    uint256 public GENESIS_TOKENS = 10000; //Genesis tokens consist of 1k perfume and 9k flowers
    uint256 public MAX_FLOWERS = 40000; //MAX MINTABLE FLOWERS
    uint256 public MAX_PERFUMES = 4000; //MAX MINTABLE PERFUMES
    uint256 public MAX_MINT_STORE = 500; //1% chance to get a store during generation mint
    uint256 public MAX_INITIAL_PERFUMES = 1000;
    uint256 public MAX_INITIAL_FLOWERS = 9000;
    uint256 public MAX_MANUFACTURED_PERFUMES = 5000; //Perfumes minted after burning a collection of flowers with the exact total of 100cc
    uint256 public MINTED_TOKENS;
    uint256 public MINTED_FLOWERS;
    uint256 public MINTED_STORES;
    uint256 public MINTED_PERFUMES;
    uint256 public MINTED_CHEMISTS;
    uint256 public MANUFACTURED_PERFUMES;
    uint256 public BUILT_STORES; //stores minted after burning perfumes
    uint256 public STAKED_PERFUMES;

    struct StakedPerfum {
        uint256 tokenId;
        uint256 timeStamp;
        address owner;
    }
    struct StakedFlower {
        uint256 tokenId;
        uint256 timeStamp;
        address owner;
    }
    struct userInfo {
        address account;
        uint256 stakedPerfumes;
        uint256 stakedFlowers;
    }
    struct Chemist {
        string operator;
        uint256 utility;
    }

    mapping(address => Chemist) public Chemists;
    mapping(uint256 => StakedPerfum) public StakedPerfumes;
    mapping(uint256 => StakedFlower) public StakedFlowers;
    mapping(address => userInfo) public Users;
    uint256 public florPerDay = 6000 ether; //FLOR per day for flower

    FLOR public flor;
    EvaFlowers public flower;
    EvaPerfumes public perfume;
    EvaStore public store;

    uint256 public florDueToPerfumHolders;
    event TokenStaked(address owner, uint256 tokenId, uint256 value);

    constructor(
        address _flor,
        address _perfume,
        address _flower,
        address _store
    ) {
        flor = FLOR(_flor);

        perfume = EvaPerfumes(_perfume);
        flower = EvaFlowers(_flower);
        store = EvaStore(_store);
    }

    function mint(uint256 amount, bool stakeTokens)
        public
        payable
        whenNotPaused
    {
        require(tx.origin == msg.sender, "Only EOA");
        require(MINTED_TOKENS + amount <= MAX_MINTABLE_TOKENS, "Mint ended");

        if (MINTED_TOKENS < GENESIS_TOKENS) {
            require(
                MINTED_TOKENS + amount <= GENESIS_TOKENS,
                "All tokens on-sale already sold"
            );

            if (msg.sender == owner()) {
                require(msg.value == 0);
            } else {
                if (stakeTokens) {
                    require(
                        amount * MINT_WITH_STAKE_PRICE == msg.value,
                        "Invalid amount"
                    );
                } else {
                    require(
                        amount * MINT_WITHOUT_STAKE_PRICE == msg.value,
                        "Invalid amount"
                    );
                }
            }

            _mintGenesisTokens(amount, stakeTokens);
        } else {
            _mintGenerationTokens(amount, stakeTokens);
        }
    }

    function _mintGenerationTokens(uint256 _amount, bool _stake) internal {
        uint256 totalFlorCost = 0;

        for (uint256 i = 0; i < _amount; i++) {
            uint256 luckyNumber = randomNum(100, i);
            if (
                (luckyNumber < 90 && MAX_FLOWERS > MINTED_FLOWERS) ||
                (MAX_PERFUMES == MINTED_PERFUMES &&
                    MAX_FLOWERS > MINTED_FLOWERS)
            ) {
                if (_stake) {
                    flower.mint(address(this));
                    _stakeFlower(msg.sender, MINTED_FLOWERS);
                } else {
                    flower.mint(msg.sender);
                }
                MINTED_FLOWERS++;
            }
            if (
                (luckyNumber >= 90 &&
                    luckyNumber < 99 &&
                    MAX_PERFUMES > MINTED_PERFUMES) ||
                (MAX_FLOWERS == MINTED_FLOWERS &&
                    MAX_PERFUMES > MINTED_PERFUMES)
            ) {
                if (_stake) {
                    perfume.mint(address(this), false, 0);
                    _stakePerfume(msg.sender, MINTED_PERFUMES);
                } else {
                    perfume.mint(msg.sender, false, 0);
                }
                MINTED_PERFUMES++;
            }

            if (
                luckyNumber == 99 ||
                (MAX_PERFUMES == MINTED_PERFUMES &&
                    MAX_FLOWERS == MINTED_FLOWERS &&
                    MINTED_STORES < MAX_MINT_STORE)
            ) {
                store.mint(msg.sender);
                MINTED_STORES++;
            }

            totalFlorCost += mintCost(MINTED_TOKENS);
            MINTED_TOKENS++;
        }

        flor.burn(msg.sender, totalFlorCost);
    }

    /*

     * Mints genesis tokens
     * If user decides to stake tokens are directly minted to the lab contract

     */

    function _mintGenesisTokens(uint256 _amount, bool _stake) internal {
        for (uint256 i = 0; i < _amount; i++) {
            uint256 luckyNumber = randomNum(10, i);
            if (
                (luckyNumber == 1 && MINTED_PERFUMES < MAX_INITIAL_PERFUMES) ||
                (MINTED_FLOWERS == MAX_INITIAL_FLOWERS &&
                    MINTED_PERFUMES < MAX_INITIAL_PERFUMES)
            ) {
                if (_stake) {
                    perfume.mint(address(this), false, 0);

                    _stakePerfume(msg.sender, MINTED_PERFUMES);
                } else {
                    perfume.mint(msg.sender, false, 0);
                }
                MINTED_PERFUMES++;
            }

            if (
                (luckyNumber != 1 && MINTED_FLOWERS < MAX_INITIAL_FLOWERS) ||
                (MINTED_PERFUMES == MAX_INITIAL_PERFUMES &&
                    MINTED_FLOWERS < MAX_INITIAL_FLOWERS)
            ) {
                if (_stake) {
                    flower.mint(address(this));

                    _stakeFlower(msg.sender, MINTED_FLOWERS);
                } else {
                    flower.mint(msg.sender);
                }
                MINTED_FLOWERS++;
            }

            MINTED_TOKENS++;
        }
    }

    /*
    Function called to mint a new Store
    *Burns 100k FLOR 
    *Burns 5 perfumes
    *Mints a new Store
    +Checks whether tperfumes are staked or not, if not revert
    */

    function buildStore(uint256[] calldata tokenIds) public {
        require(tokenIds.length == 5, "You need 5 perfumes");
        require(BUILT_STORES < 500, "Build ended"); //Max stores to be built is 500

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                StakedPerfumes[tokenIds[i]].owner == _msgSender(),
                "Token isn't staked"
            );
        }
        flor.burn(_msgSender(), 100000 ether); //A store costs 100 000 FLOR to be minted
        perfume.burnBatchPerfumes(tokenIds);
        store.mint(msg.sender);
        BUILT_STORES++;
    }

    /*

    @Dev 
    *Calculates the mint cost depending on the token generation 

    */
    function mintCost(uint256 tokenId) public view returns (uint256) {
        if (tokenId <= 15000 && tokenId >= GENESIS_TOKENS) return 20000 ether; //Generation #1
        if (tokenId <= 20000 && tokenId > 15000) return 25000 ether; //Generation #2
        if (tokenId <= 30000 && tokenId > 20000) return 30000 ether; //Generation #3
        if (tokenId <= 40000 && tokenId > 30000) return 35000 ether; //Generation #4
        if (tokenId <= 44500 && tokenId > 40000) return 40000 ether; //Generation #5
        return 80000 ether; //@TODO: to be decided
    }

    /*

    @Dev 
    Allows players to stake their flowers and perfumes in batch
    @args address of player/holder of tokens 
    @args Array of token ids
    @args type of tokens: flowers or perfumes

    */

    function stake(uint256[] calldata tokenIds, bool areFlowers)
        public
        whenNotPaused
    {
        if (areFlowers) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                flower.transferFrom(msg.sender, address(this), tokenIds[i]);
                _stakeFlower(msg.sender, tokenIds[i]);
            }
        } else {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                perfume.transferFrom(msg.sender, address(this), tokenIds[i]);
                _stakePerfume(msg.sender, tokenIds[i]);
                STAKED_PERFUMES++;
            }
        }
    }

    /*

    @Dev 
    Allows players to manufacture their own perfume after staking a decent amount of flowers 
    @args Array of token ids
    */

    function makePerfume(uint256[] calldata tokenIds) public {
        require(
            MANUFACTURED_PERFUMES < MAX_MANUFACTURED_PERFUMES,
            "Making of perfumes ended"
        );
        uint256 totalCC;
        uint256[] memory flowerTraits = new uint256[](tokenIds.length);
        Chemist memory userChemist = Chemists[msg.sender];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                StakedFlowers[tokenIds[i]].owner == _msgSender(),
                "Flower not staked"
            );
            totalCC += flower.getFlowerCC(tokenIds[i]); //gets the number of cc that the flower holds
            flowerTraits[i] = flower.getFlowerTraitIndex(tokenIds[i]); //gets the index of the flower trait(ranges from 0-5)
        }

        uint256 traitIndex = getTraitIndex(flowerTraits); //If the input is 8 traits (5 boisés, 3 Floral) the returned trait is: boisés.

        if (totalCC == 100) {
            _mintPerfume(msg.sender, traitIndex); //mints perfume with the most reccurent trait
            flower.burnBatchFlowers(tokenIds); //burns the player's flowers
            Chemists[msg.sender].utility -= 1;
        }

        if (totalCC != 100 && userChemist.utility > 0) {
            string memory operator = userChemist.operator; //gets the chemist operator +/-

            if (
                (totalCC > 100 &&
                    keccak256(abi.encodePacked((operator))) ==
                    keccak256(abi.encodePacked(("+")))) ||
                (totalCC < 100 &&
                    keccak256(abi.encodePacked((operator))) ==
                    keccak256(abi.encodePacked(("-"))))
            ) {
                _mintPerfume(msg.sender, traitIndex);
                flower.burnBatchFlowers(tokenIds);
                Chemists[msg.sender].utility -= 1; //decrease the remaining lives of teh chemist
            }
        }
        if (totalCC != 100 && userChemist.utility == 0) {
            flower.burnExtraFlower(tokenIds[tokenIds.length - 1]); //burn last flower if total cc is different than 100 and user has no chemist insurance
        }
    }

    function mintChemist() public {
        require(MINTED_CHEMISTS < 2500, "Mint chemist ended"); //Total amount of chemists to be minted is 2500
        flor.burn(msg.sender, 50000 ether); //A Chemist costs 50 000 FLOR to be minted
        Chemist memory newChemist = Chemist(
            randomNum(2, block.difficulty) == 0 ? "+" : "-",
            randomNum(6, block.difficulty) + 1 //utility/utility ranges from 1-6
        );

        Chemists[msg.sender] = newChemist;
        MINTED_CHEMISTS++;
    }

    function _mintPerfume(address _owner, uint256 traitIndex) internal {
        perfume.mint(_owner, true, traitIndex); //mint new perfume with known trait to player
        MANUFACTURED_PERFUMES++; //keeps track of  the number of manufactured perfumes which has a limit of 5000
    }

    function _stakePerfume(address account, uint256 tokenId) internal {
        StakedPerfum memory newStaking = StakedPerfum(
            tokenId,
            block.timestamp,
            account
        );
        StakedPerfumes[tokenId] = newStaking;
        Users[msg.sender].stakedPerfumes++;

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeFlower(address account, uint256 tokenId) internal {
        StakedFlower memory newStaking = StakedFlower(
            tokenId,
            block.timestamp,
            account
        );
        StakedFlowers[tokenId] = newStaking;
        Users[msg.sender].stakedFlowers++;

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function claimFlowersFlor(uint256[] calldata tokenIds) public {
        uint256 claimAmount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(
                StakedFlowers[tokenIds[i]].owner == _msgSender(),
                "Token isn't staked"
            );

            claimAmount +=
                ((block.timestamp - StakedFlowers[tokenId].timeStamp) *
                    florPerDay) /
                1 days;
            StakedFlowers[tokenId].timeStamp = block.timestamp;
        }
        florDueToPerfumHolders += (claimAmount * 2) / 10; // The 20% of total flor claimed goes to perfume holders
        flor.mint(_msgSender(), (claimAmount * 8) / 10); //20% of due Flor goes to Perfume holders
    }

    /*
    @Dev Calling this function allows the user to claim his due Flor that comes from the 20% tax on each flower claiming
    *The amount to be minted depends on the numbe rof the perfumes he staked, if he has staked 50% of all the staked perfumes he gets 50% of all Flor collected from taxes
    */
    function claimFlorForPerfumeHolders() public {
        uint256 userPerfumes = Users[msg.sender].stakedPerfumes; //GETS THE TOTAL NUMBER OF PERFUMES STAKED BY USER
        uint256 dueAmount = (florDueToPerfumHolders * userPerfumes) /
            STAKED_PERFUMES;
        florDueToPerfumHolders -= dueAmount;

        flor.mint(_msgSender(), dueAmount);
    }

    function unstakeFlowers(uint256[] calldata tokenIds) public {
        uint256 dueFlorAmount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(StakedFlowers[tokenId].owner == _msgSender(), "NOT OWNER"); // the msg sender is the owner of the staked token
            require(
                StakedFlowers[tokenId].timeStamp + 4 days > block.timestamp, //4 * 6000 Flor = 24000 Flor is needed to unstake the flower
                "NOT READY FOR PICKING"
            );

            dueFlorAmount +=
                ((block.timestamp - StakedFlowers[tokenId].timeStamp) *
                    florPerDay) /
                1 days;
            flower.transferFrom(address(this), _msgSender(), tokenId);
            delete StakedFlowers[tokenId];
        }
        //50% chance to lose your flor when unstaking flowers
        if (randomNum(2, dueFlorAmount) == 1) {
            flor.mint(_msgSender(), (dueFlorAmount * 8) / 10); //Tax of 20% applies for Flor claiming
            florDueToPerfumHolders += (dueFlorAmount * 2) / 10; //Credits perfume holders due amount with 20% tax
        } else {
            florDueToPerfumHolders += dueFlorAmount; //sends all Flor to perfume holders
        }
    }

    /*
    @Dev When unstaking perfumes player gets his perfumes and the due amount of Flor collected from staked flowers
    

    */

    function unstakePerfumes(uint256[] calldata tokenIds) public {
        uint256 dueFlorAmount;

        claimFlorForPerfumeHolders(); //claim taxed flowers FLOR if player didn't claim it
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                StakedPerfumes[tokenIds[i]].owner == _msgSender(),
                "NOT OWNER"
            );

            perfume.transferFrom(address(this), _msgSender(), tokenIds[i]);
            dueFlorAmount +=
                ((block.timestamp - StakedPerfumes[tokenIds[i]].timeStamp) *
                    florPerDay) /
                1 days;
            delete StakedPerfumes[tokenIds[i]];
            STAKED_PERFUMES -= 1;
        }
        flor.mint(_msgSender(), dueFlorAmount);
    }

    /*
     * generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function randomNum(uint256 _mod, uint256 _seed)
        public
        view
        returns (uint256)
    {
        uint256 num = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    block.number,
                    _seed
                )
            )
        ) % _mod;
        return num;
    }

    /*
    @dev
    Gets the most frequent element of an array
    @args traits of flowers to be burned
    returns the trait index of the perfume to be minted
    */

    function getTraitIndex(uint256[] memory array)
        public
        pure
        returns (uint256)
    {
        uint256[] memory freq = new uint256[](6); //6: number of flowers traits
        uint256 id;
        uint256 maxIndex = 0;
        uint256 maxFrequence;

        for (uint256 i = 0; i < array.length; i += 1) {
            id = array[i];
            freq[id] = freq[id] + 1;
        }

        for (uint256 i = 0; i < 6; i += 1) {
            if (maxFrequence < freq[i]) {
                maxIndex = i;
                maxFrequence = freq[i];
            }
        }

        return maxIndex;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to lab directly");
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FLOR is ERC20, Ownable {
    // a mapping from an address to whether or not it can mint / burn
    mapping(address => bool) controllers;

    constructor() ERC20("FLOR TOKEN", "FLOR") {}

    /**
     * mints $WOOL to a recipient
     * @param to the recipient of the $WOOL
     * @param amount the amount of $WOOL to mint
     */
    function mint(address to, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can mint");
        _mint(to, amount);
    }

    /**
     * burns $WOOL from a holder
     * @param from the holder of the $WOOL
     * @param amount the amount of $WOOL to burn
     */
    function burn(address from, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can burn");
        _burn(from, amount);
    }

    /**
     * enables an address to mint / burn
     * @param controller the address to enable
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
     * disables an address from minting / burning
     * @param controller the address to disbale
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./FlorToken.sol";
import "./Lab.sol";

contract EvaPerfumes is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    uint256 public MAX_TOKENS = 9000; //Max supply of perfumes to be minted ever

    uint256 public MINTED_PERFUMS;
    Lab public lab;

    string[] public traits = [
        "Amber",
        "Woody",
        "Flowery",
        "Citrus",
        "Oriental",
        "Fruity"
    ];
    struct Perfum {
        string name;
        string trait;
    }

    mapping(uint256 => Perfum) public PerfumCollection;

    constructor() ERC721("EvaFlore Perfumes", "PERFUM") {}

    function mint(
        address _to,
        bool withKnownTrait,
        uint256 traitIndex
    ) public whenNotPaused {
        require(_msgSender() == address(lab), "Only Lab");

        require(MINTED_PERFUMS <= MAX_TOKENS, "Mint ended");

        _safeMint(_to, MINTED_PERFUMS);
        if (withKnownTrait) {
            generateWithKnownTrait(MINTED_PERFUMS, traitIndex);
        } else {
            generate(MINTED_PERFUMS);
        }
        MINTED_PERFUMS++;
    }

    function generate(uint256 tokenId) internal {
        uint256 randomTrait = randomNum(6, block.difficulty, tokenId);
        Perfum memory newPerfum = Perfum(
            string(abi.encodePacked("Perfum #", uint256(tokenId).toString())),
            traits[randomTrait]
        );

        PerfumCollection[tokenId] = newPerfum;
    }

    function generateWithKnownTrait(uint256 tokenId, uint256 traitIndex)
        internal
    {
        Perfum memory newPerfum = Perfum(
            string(abi.encodePacked("Perfum #", uint256(tokenId).toString())),
            traits[traitIndex]
        );

        PerfumCollection[tokenId] = newPerfum;
    }

    function randomNum(
        uint256 _mod,
        uint256 _salt,
        uint256 _seed
    ) public view returns (uint256) {
        uint256 num = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    block.number,
                    _salt,
                    _seed
                )
            )
        ) % _mod;
        return num;
    }

    function buildMetadata(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        Perfum memory token = PerfumCollection[_tokenId];
        string memory baseURI = _baseURI();
        return
            string(
                abi.encodePacked(
                    "data:application/json,",
                    abi.encodePacked( //add rarity
                        '{"name":"',
                        token.name,
                        '", "trait":"',
                        token.trait,
                        '","uri":"',
                        string(
                            abi.encodePacked(baseURI, (_tokenId).toString())
                        ),
                        '"}'
                    )
                )
            );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return buildMetadata(_tokenId);
    }

    function setLab(address _lab) external onlyOwner {
        lab = Lab(_lab);
    }

    function burnBatchPerfumes(uint256[] calldata tokenIds) external {
        require(msg.sender == address(lab), "only lab");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
    }
}