// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./TinyERC721.sol";


contract SwoleMice is TinyERC721, Ownable {

    uint256 public constant MAX_SUPPLY = 3333;
    uint256 public maxPer = 3;

    mapping(address => uint256) private _minted;

    constructor() TinyERC721("SwoleMice", "SWOLEM", 3) {
        _safeMint(_msgSender(), 1);
    }

    // View

    function _calculateAux(
        address from,
        address to,
        uint256 tokenId,
        bytes12 current
    ) internal view virtual override returns (bytes12) {
        return
            from == address(0)
                ? bytes12(
                    keccak256(
                        abi.encodePacked(
                            tokenId,
                            to,
                            block.difficulty,
                            block.timestamp
                        )
                    )
                )
                : current;
    }

    function colorHash(uint256 tokenId) public view returns (bytes32) {
        return keccak256(abi.encodePacked(tokenId, _tokenData(tokenId).aux));
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Token does not exist");

        return(
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(
                                abi.encodePacked(
                                    '{"name": "SwoleMouse #',
                                    Strings.toString(tokenId),
                                    '", "description": "SwolMice are a 100% on-chain swol collection. Arm days only.", "image": "data:image/svg+xml;base64,',
                                    Base64.encode(bytes(hashToSVG(bytes32ToLiteralString(colorHash(tokenId))))),
                                    '"}'
                                )
                    ))
                )
            )
        );
    }

    // External
    function mint(uint256 quantity) external {
        require(quantity <= maxPer, "Too many mints per tx");
        require(_minted[msg.sender] + quantity <= maxPer, "Too many mints per wallet");
        require(
            totalSupply() + quantity <= MAX_SUPPLY,
            "Not enough mints left"
        );
        _safeMint(msg.sender, quantity);
        _minted[msg.sender] += quantity;
    }

    // Owner
    function setMaxPer(uint256 _maxPer) external onlyOwner {
        maxPer = _maxPer;
    }

    // Internal 

    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function bytes32ToLiteralString(bytes32 data)
        internal
        pure
        returns (string memory result)
    {
        bytes memory temp = new bytes(65);
        uint256 count;

        for (uint256 i = 0; i < 32; i++) {
            bytes1 currentByte = bytes1(data << (i * 8));

            uint8 c1 = uint8(bytes1((currentByte << 4) >> 4));

            uint8 c2 = uint8(bytes1((currentByte >> 4)));

            if (c2 >= 0 && c2 <= 9) temp[++count] = bytes1(c2 + 48);
            else temp[++count] = bytes1(c2 + 87);

            if (c1 >= 0 && c1 <= 9) temp[++count] = bytes1(c1 + 48);
            else temp[++count] = bytes1(c1 + 87);
        }

        result = string(temp);
    }

        function hashToSVG(string memory _hash)
        internal
        pure
        returns (string memory)
    {
        string memory svgString;

        string memory backgroundColor = string.concat(string.concat('.c11{fill:#', substring(_hash, 1, 7)),'}');
        string memory topColor = string.concat(string.concat('.c10{fill:#', substring(_hash, 7, 13)),'}');
        string memory leftEye = string.concat(string.concat('.c06{fill:#', substring(_hash, 13, 19)),'}');
        string memory rightEye = string.concat(string.concat('.c07{fill:#', substring(_hash, 19, 25)),'}');
        string memory eyes = string.concat(leftEye, rightEye);
        string memory backs = string.concat(topColor, backgroundColor);
        string memory styleString = string.concat(string.concat(string.concat(string.concat('<style>#swol-mouse-svg{shape-rendering: crispedges;} .c00{fill:#8B93AF}.c01{fill:#DAE0EA}.c02{fill:#B3B9D1}.c03{fill:#F5A097}.c04{fill:#403353}.c05{fill:#6D758D}',eyes),'.c08{fill:#000000}.c09{fill:#4B1E0B}'),backs),'</style>');

        string memory svgBody = '<svg id="swol-mouse-svg" version="1.1" width="24" height="24" xmlns="http://www.w3.org/2000/svg"> <rect class="c11" width="100%" height="100%" /> <rect class="c00" x="8" y="9" width="1" height="1"/> <rect class="c01" x="9" y="9" width="1" height="1"/> <rect class="c00" x="13" y="9" width="1" height="1"/> <rect class="c01" x="14" y="9" width="1" height="1"/> <rect class="c02" x="8" y="10" width="1" height="1"/> <rect class="c03" x="9" y="10" width="1" height="1"/> <rect class="c01" x="10" y="10" width="1" height="1"/> <rect class="c01" x="11" y="10" width="1" height="1"/> <rect class="c02" x="12" y="10" width="1" height="1"/> <rect class="c01" x="13" y="10" width="1" height="1"/> <rect class="c01" x="14" y="10" width="1" height="1"/> <rect class="c02" x="9" y="11" width="1" height="1"/> <rect class="c01" x="10" y="11" width="1" height="1"/> <rect class="c01" x="11" y="11" width="1" height="1"/> <rect class="c01" x="12" y="11" width="1" height="1"/> <rect class="c01" x="13" y="11" width="1" height="1"/> <rect class="c04" x="8" y="12" width="1" height="1" /> <rect class="c05" x="9" y="12" width="1" height="1" /> <rect class="c05" x="10" y="12" width="1" height="1" /> <rect class="c06" x="11" y="12" width="1" height="1" /> <rect class="c05" x="12" y="12" width="1" height="1" /> <rect class="c07" x="13" y="12" width="1" height="1" /> <rect class="c04" x="15" y="12" width="1" height="1" /> <rect class="c04" x="9" y="13" width="1" height="1" /> <rect class="c01" x="10" y="13" width="1" height="1"/> <rect class="c01" x="11" y="13" width="1" height="1"/> <rect class="c08" x="12" y="13" width="1" height="1" /> <rect class="c01" x="13" y="13" width="1" height="1"/> <rect class="c04" x="14" y="13" width="1" height="1" /> <rect class="c02" x="9" y="14" width="1" height="1"/> <rect class="c04" x="10" y="14" width="1" height="1" /> <rect class="c01" x="11" y="14" width="1" height="1"/> <rect class="c01" x="12" y="14" width="1" height="1"/> <rect class="c01" x="13" y="14" width="1" height="1"/> <rect class="c01" x="16" y="14" width="1" height="1"/> <rect class="c01" x="17" y="14" width="1" height="1"/> <rect x="9" y="15" width="1" height="1" /> <rect class="c02" x="10" y="15" width="1" height="1"/> <rect class="c01" x="11" y="15" width="1" height="1"/> <rect class="c01" x="12" y="15" width="1" height="1"/> <rect class="c02" x="13" y="15" width="1" height="1"/> <rect x="14" y="15" width="1" height="1" /> <rect class="c02" x="16" y="15" width="1" height="1"/> <rect class="c01" x="17" y="15" width="1" height="1"/> <rect x="8" y="16" width="1" height="1" /> <rect class="c02" x="10" y="16" width="1" height="1"/> <rect class="c01" x="11" y="16" width="1" height="1"/> <rect x="15" y="16" width="1" height="1" /> <rect class="c01" x="17" y="16" width="1" height="1"/> <rect class="c02" x="8" y="17" width="1" height="1"/> <rect class="c10" x="9" y="17" width="1" height="1" /> <rect class="c02" x="10" y="17" width="1" height="1"/> <rect class="c01" x="11" y="17" width="1" height="1"/> <rect class="c10" x="12" y="17" width="1" height="1" /> <rect class="c02" x="14" y="17" width="1" height="1"/> <rect class="c01" x="15" y="17" width="1" height="1"/> <rect class="c01" x="17" y="17" width="1" height="1"/> <rect class="c02" x="7" y="18" width="1" height="1"/> <rect class="c01" x="8" y="18" width="1" height="1"/> <rect class="c10" x="9" y="18" width="1" height="1" /> <rect class="c02" x="10" y="18" width="1" height="1"/> <rect class="c01" x="11" y="18" width="1" height="1"/> <rect class="c10" x="12" y="18" width="1" height="1" /> <rect class="c01" x="13" y="18" width="1" height="1"/> <rect class="c01" x="14" y="18" width="1" height="1"/> <rect class="c01" x="15" y="18" width="1" height="1"/> <rect class="c01" x="16" y="18" width="1" height="1"/> <rect class="c01" x="17" y="18" width="1" height="1"/> <rect class="c02" x="7" y="19" width="1" height="1"/> <rect class="c01" x="8" y="19" width="1" height="1"/> <rect class="c10" x="9" y="19" width="1" height="1" /> <rect class="c10" x="10" y="19" width="1" height="1" /> <rect class="c10" x="11" y="19" width="1" height="1" /> <rect class="c10" x="12" y="19" width="1" height="1" /> <rect class="c02" x="13" y="19" width="1" height="1"/> <rect class="c02" x="14" y="19" width="1" height="1"/> <rect class="c02" x="15" y="19" width="1" height="1"/> <rect class="c02" x="16" y="19" width="1" height="1"/> <rect class="c01" x="7" y="20" width="1" height="1"/> <rect class="c02" x="8" y="20" width="1" height="1"/> <rect class="c10" x="9" y="20" width="1" height="1" /> <rect class="c10" x="10" y="20" width="1" height="1" /> <rect class="c10" x="11" y="20" width="1" height="1" /> <rect class="c10" x="12" y="20" width="1" height="1" /> <rect class="c01" x="7" y="21" width="1" height="1"/> <rect class="c02" x="8" y="21" width="1" height="1"/> <rect class="c10" x="9" y="21" width="1" height="1" /> <rect class="c10" x="10" y="21" width="1" height="1" /> <rect class="c10" x="11" y="21" width="1" height="1" /> <rect class="c10" x="12" y="21" width="1" height="1" /> <rect class="c01" x="7" y="22" width="1" height="1"/> <rect class="c02" x="8" y="22" width="1" height="1"/> <rect class="c10" x="9" y="22" width="1" height="1" /> <rect class="c10" x="10" y="22" width="1" height="1" /> <rect class="c10" x="11" y="22" width="1" height="1" /> <rect class="c10" x="12" y="22" width="1" height="1" /> <rect class="c01" x="7" y="23" width="1" height="1"/> <rect class="c02" x="8" y="23" width="1" height="1"/> <rect class="c10" x="9" y="23" width="1" height="1" /> <rect class="c10" x="10" y="23" width="1" height="1" /> <rect class="c10" x="11" y="23" width="1" height="1" /> <rect class="c10" x="12" y="23" width="1" height="1" />';

        svgString = string(
            abi.encodePacked(
                svgBody,
                styleString,
                '</svg>'
            )
        );

        return svgString;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Base64.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

error ApprovalCallerNotOwnerNorApproved();
error ApprovalQueryForNonexistentToken();
error ApproveToCaller();
error ApprovalToCurrentOwner();
error BalanceQueryForZeroAddress();
error MintToZeroAddress();
error MintZeroQuantity();
error TokenDataQueryForNonexistentToken();
error OwnerQueryForNonexistentToken();
error OperatorQueryForNonexistentToken();
error TransferCallerNotOwnerNorApproved();
error TransferFromIncorrectOwner();
error TransferToNonERC721ReceiverImplementer();
error TransferToZeroAddress();
error URIQueryForNonexistentToken();

contract TinyERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    struct TokenData {
        address owner;
        bytes12 aux;
    }

    uint256 private immutable _maxBatchSize;

    mapping(uint256 => TokenData) private _tokens;
    uint256 private _mintCounter;

    string private _name;
    string private _symbol;

    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxBatchSize_
    ) {
        _name = name_;
        _symbol = symbol_;
        _maxBatchSize = maxBatchSize_;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _mintCounter;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();

        uint256 total = totalSupply();
        uint256 count;
        address lastOwner;
        for (uint256 i; i < total; ++i) {
            address tokenOwner = _tokens[i].owner;
            if (tokenOwner != address(0)) lastOwner = tokenOwner;
            if (lastOwner == owner) ++count;
        }

        return count;
    }

    function _tokenData(uint256 tokenId) internal view returns (TokenData storage) {
        if (!_exists(tokenId)) revert TokenDataQueryForNonexistentToken();

        TokenData storage token = _tokens[tokenId];
        uint256 currentIndex = tokenId;
        while (token.owner == address(0)) {
            unchecked {
                --currentIndex;
            }
            token = _tokens[currentIndex];
        }

        return token;
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert OwnerQueryForNonexistentToken();
        return _tokenData(tokenId).owner;
    }

    function approve(address to, uint256 tokenId) public virtual override {
        TokenData memory token = _tokenData(tokenId);
        address owner = token.owner;
        if (to == owner) revert ApprovalToCurrentOwner();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ApprovalCallerNotOwnerNorApproved();
        }

        _approve(to, tokenId, token);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (operator == _msgSender()) revert ApproveToCaller();

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        TokenData memory token = _tokenData(tokenId);
        if (!_isApprovedOrOwner(_msgSender(), tokenId, token)) revert TransferCallerNotOwnerNorApproved();

        _transfer(from, to, tokenId, token);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        TokenData memory token = _tokenData(tokenId);
        if (!_isApprovedOrOwner(_msgSender(), tokenId, token)) revert TransferCallerNotOwnerNorApproved();

        _safeTransfer(from, to, tokenId, token, _data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        TokenData memory token,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId, token);

        if (to.isContract() && !_checkOnERC721Received(from, to, tokenId, _data))
            revert TransferToNonERC721ReceiverImplementer();
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return tokenId < _mintCounter;
    }

    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId,
        TokenData memory token
    ) internal view virtual returns (bool) {
        address owner = token.owner;
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function _safeMint(address to, uint256 quantity) internal virtual {
        _safeMint(to, quantity, "");
    }

    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal virtual {
        uint256 startTokenId = _mintCounter;
        _mint(to, quantity);

        if (to.isContract()) {
            unchecked {
                for (uint256 i; i < quantity; ++i) {
                    if (!_checkOnERC721Received(address(0), to, startTokenId + i, _data))
                        revert TransferToNonERC721ReceiverImplementer();
                }
            }
        }
    }

    function _mint(address to, uint256 quantity) internal virtual {
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();

        uint256 startTokenId = _mintCounter;
        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        unchecked {
            for (uint256 i; i < quantity; ++i) {
                if (_maxBatchSize == 0 ? i == 0 : i % _maxBatchSize == 0) {
                    TokenData storage token = _tokens[startTokenId + i];
                    token.owner = to;
                    token.aux = _calculateAux(address(0), to, startTokenId + i, 0);
                }

                emit Transfer(address(0), to, startTokenId + i);
            }
            _mintCounter += quantity;
        }

        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId,
        TokenData memory token
    ) internal virtual {
        if (token.owner != from) revert TransferFromIncorrectOwner();
        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfers(from, to, tokenId, 1);

        _approve(address(0), tokenId, token);

        unchecked {
            uint256 nextTokenId = tokenId + 1;
            if (_exists(nextTokenId)) {
                TokenData storage nextToken = _tokens[nextTokenId];
                if (nextToken.owner == address(0)) {
                    nextToken.owner = token.owner;
                    nextToken.aux = token.aux;
                }
            }
        }

        TokenData storage newToken = _tokens[tokenId];
        newToken.owner = to;
        newToken.aux = _calculateAux(from, to, tokenId, token.aux);

        emit Transfer(from, to, tokenId);

        _afterTokenTransfers(from, to, tokenId, 1);
    }

    function _calculateAux(
        address from,
        address to,
        uint256 tokenId,
        bytes12 current
    ) internal view virtual returns (bytes12) {}

    function _approve(
        address to,
        uint256 tokenId,
        TokenData memory token
    ) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(token.owner, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert TransferToNonERC721ReceiverImplementer();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

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
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
                /// @solidity memory-safe-assembly
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