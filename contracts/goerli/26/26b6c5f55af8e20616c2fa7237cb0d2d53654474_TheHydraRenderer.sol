// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/ITheHydra.sol";
import "./interfaces/ITheHydraDataStore.sol";
import "./interfaces/ITheHydraRenderer.sol";
import "./interfaces/IExquisiteGraphics.sol";

import "./lib/DynamicBuffer.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "boringsolidity/contracts/libraries/Base64.sol";

/// @author therightchoyce.eth
/// @title  Upgradeable renderer interface
/// @notice This leaves room for us to change how we return token metadata and
///         unlocks future capability like fully on-chain storage.
contract TheHydraRenderer is ITheHydraRenderer {
    
    // --------------------------------------------------------
    // ~~ Utilities  ~~
    // --------------------------------------------------------
    using Strings for uint256;
    using DynamicBuffer for bytes;

    // --------------------------------------------------------
    // ~~ Internal storage  ~~
    // --------------------------------------------------------
    
    /// @dev The address of the token ownership contract
    ITheHydra public theHydra;

    /// @dev The address of the on-chain data storage contract
    ITheHydraDataStore public dataStore;

    /// @dev The address of the xqstgfx public rendering contract
    IExquisiteGraphics public xqstgfx;

    // --------------------------------------------------------
    // ~~ Constructor  ~~
    // --------------------------------------------------------
    
    /// @param _theHydra The address of the token ownership contract
    /// @param _theHydraDataStore The address of the on-chain data storage contract
    /// @param _xqstgfx The address of the xqstgfx public rendering contract
    constructor(
        address _theHydra,
        address _theHydraDataStore,
        address _xqstgfx
    ) {
        theHydra = ITheHydra(_theHydra);
        dataStore = ITheHydraDataStore(_theHydraDataStore);
        xqstgfx = IExquisiteGraphics(payable(_xqstgfx));
    }

    // --------------------------------------------------------
    // ~~ ERC721 TokenURI implementation  ~~
    // --------------------------------------------------------

    /// @notice Standard URI function to get the token metadata
    /// @param _id Id of token
    function tokenURI(
        uint256 _id
    ) override public view returns (
        string memory
    ) {
        return string(abi.encodePacked(
            dataStore.getOffChainBaseURI(),
            _id.toString()
        ));
    }
    
    /// @notice Get the tokenURI using a custom render type. This allows for retrevial of on-chain, off-chain, or a custom render.. I.E maybe there are multiple sizes
    /// @dev allow the caller to specific the type of render, e.g. on-chain, off-chain, 64px, etc..
    /// @param _id Id of token
    /// @param _renderType specific context for what to render
    function tokenURI(
        uint256 _id, 
        string calldata _renderType
    ) external view returns (string memory)
    {
        return string(abi.encodePacked(
            dataStore.getOffChainBaseURI(),
            _renderType,
            _id.toString()
        ));
    }

    // --------------------------------------------------------
    // ~~ Exquisite Graphics SVG Renderers  ~~
    // --------------------------------------------------------

    /// @notice This takes in the raw byte data in .xqst format and renders a full SVG to bytes memory
    /// @dev Draws pixels using xqstgfx, allocates memory for the SVG data, and creates the svg
    /// @param _data The input data, in .xqst format
    function renderSVG(
        bytes memory _data
    ) public view returns (
        bytes memory
    ) {
        string memory rects = xqstgfx.drawPixelsUnsafe(_data);
        bytes memory svg = DynamicBuffer.allocate(2**19);

        svg.appendSafe(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges" width="100%" height="100%" version="1.1" viewBox="0 0 128 128" fill="#fff"><rect width="128" height="128" fill="#fff" /><g transform="translate(32,32)">',
                rects,
                "</g></svg>"
            )
        );        
        return svg;
    }

    /// @notice This takes in the raw byte data in .xqst format and renders a full SVG as an easy to understand string
    /// @dev Draws pixels using xqstgfx, allocates memory for the SVG data, and creates the svg
    /// @param _data The input data, in .xqst format
    function renderSVG_AsString(
        bytes memory _data
    ) public view returns (
        string memory
    ) {
        return string(renderSVG(_data));
    }

    // --------------------------------------------------------
    // ~~ User Friendly Renderers  ~~
    // --------------------------------------------------------

    function getOnChainSVG(
        uint256 _id
    ) external view returns (
        string memory
    ) {
        bytes memory data = dataStore.getPhotoData(_id);
        return renderSVG_AsString(data);
    }

    function getOnChainSVG_AsBase64(
        uint256 _id
    ) external view returns (
        string memory
    ) {
        bytes memory data = dataStore.getPhotoData(_id);
        bytes memory svg = renderSVG(data);

        bytes memory svgBase64 = DynamicBuffer.allocate(2**19);

        svgBase64.appendSafe("data:image/svg+xml;base64,");
        svgBase64.appendSafe(bytes(Base64.encode(svg)));

        return string(svgBase64);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

/// @author therightchoyce.eth
/// @title  Composable interface for TheHydra contract
/// @notice Allows other contracts to easily call methods exposed in this
///         interface.. IE a Renderer contract will be able to interact
///         with TheHydra's ERC721 functions
interface ITheHydra {
    
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

/// @author therightchoyce.eth
/// @title  Upgradeable data store interface for on-chain art storage
/// @notice This leaves room for us to change how we store data
///         unlocks future capability
interface ITheHydraDataStore {
    function setOffChainBaseURI(string memory _baseURI) external;
    function getOffChainBaseURI() external view returns (string memory);

    function storePhotoData(uint256 _photoId, bytes calldata _data) external;
    function getPhotoData(uint256 _photoId) external view returns (bytes memory);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

/// @author therightchoyce.eth
/// @title  Upgradeable renderer interface
/// @notice This leaves room for us to change how we return token metadata and
///         unlocks future capability like fully on-chain storage.
interface ITheHydraRenderer {

    function tokenURI(uint256 _id) external view returns (string memory);
    function tokenURI(uint256 _id, string calldata _renderType) external view returns (string memory);

    function renderSVG(bytes memory _data) external view returns (bytes memory);
    function renderSVG_AsString(bytes memory _data) external view returns (string memory);

    function getOnChainSVG(uint256 _id) external view returns (string memory);
    function getOnChainSVG_AsBase64(uint256 _id) external view returns (string memory);    
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IExquisiteGraphics {
    struct Header {
        /* HEADER START */
        uint8 version; // 8 bits
        uint16 width; // 8 bits
        uint16 height; // 8 bits
        uint16 numColors; // 16 bits
        uint8 backgroundColorIndex; // 8 bits
        uint16 scale; // 10 bits
        uint8 reserved; // 4 bits
        bool alpha; // 1 bit
        bool hasBackground; // 1 bit
        /* HEADER END */

        /* CALCULATED DATA START */
        uint24 totalPixels; // total pixels in the image
        uint8 bitsPerPixel; // bits per pixel
        uint8 pixelsPerByte; // pixels per byte
        uint16 paletteStart; // number of the byte where the palette starts
        uint16 dataStart; // number of the byte where the data starts
        /* CALCULATED DATA END */
    }

    struct DrawContext {
        bytes data; // the binary data in .xqst format
        Header header; // the header of the data
        string[] palette; // hex color for each color in the image
        uint8[] pixels; // color index (in the palette) for a pixel
    }

    error ExceededMaxPixels();
    error ExceededMaxRows();
    error ExceededMaxColumns();
    error ExceededMaxColors();
    error BackgroundColorIndexOutOfRange();
    error PixelColorIndexOutOfRange();
    error MissingHeader();
    error NotEnoughData();

    /// @notice Draw an SVG from the provided data
    /// @param data Binary data in the .xqst format.
    /// @return string the <svg>
    function draw(bytes memory data) external pure returns (string memory);

    /// @notice Draw an SVG from the provided data. No validation.
    /// @param data Binary data in the .xqst format.
    /// @return string the <svg>
    function drawUnsafe(bytes memory data) external pure returns (string memory);

    /// @notice Draw the <rect> elements of an SVG from the data
    /// @param data Binary data in the .xqst format.
    /// @return string the <rect> elements
    function drawPixels(bytes memory data) external pure returns (string memory);

    /// @notice Draw the <rect> elements of an SVG from the data. No validation
    /// @param data Binary data in the .xqst format.
    /// @return string the <rect> elements
    function drawPixelsUnsafe(bytes memory data) external pure returns (string memory);

    /// @notice validates if the given data is a valid .xqst file
    /// @param data Binary data in the .xqst format.
    /// @return bool true if the data is valid
    function validate(bytes memory data) external pure returns (bool);

    // Check if the header of some data is an XQST Graphics Compatible file
    /// @notice validates the header for some data is a valid .xqst header
    /// @param data Binary data in the .xqst format.
    /// @return bool true if the header is valid
    function validateHeader(bytes memory data) external pure returns (bool);

    /// @notice Decodes the header from a binary .xqst blob
    /// @param data Binary data in the .xqst format.
    /// @return Header the decoded header
    function decodeHeader(bytes memory data) external pure returns (Header memory);

    /// @notice Decodes the palette from a binary .xqst blob
    /// @param data Binary data in the .xqst format.
    /// @return bytes8[] the decoded palette
    function decodePalette(bytes memory data) external pure returns (string[] memory);

    /// @notice Decodes all of the data needed to draw an SVG from the .xqst file
    /// @param data Binary data in the .xqst format.
    /// @return ctx The Draw Context containing all of the decoded data
    function decodeDrawContext(bytes memory data) external pure returns (DrawContext memory ctx);

    /// @notice A way to say "Thank You"
    function ty() external payable;

    /// @notice A way to say "Thank You"
    function ty(string memory message) external payable;

    /// @notice Able to receive ETH from anyone
    receive() external payable;
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2021 the ethier authors (github.com/divergencetech/ethier)

pragma solidity >=0.8.0;

/// @title DynamicBuffer
/// @author David Huber (@cxkoda) and Simon Fremaux (@dievardump). See also
///         https://raw.githubusercontent.com/dievardump/solidity-dynamic-buffer
/// @notice This library is used to allocate a big amount of container memory
//          which will be subsequently filled without needing to reallocate
///         memory.
/// @dev First, allocate memory.
///      Then use `buffer.appendUnchecked(theBytes)` or `appendSafe()` if
///      bounds checking is required.
library DynamicBuffer {
    /// @notice Allocates container space for the DynamicBuffer
    /// @param capacity The intended max amount of bytes in the buffer
    /// @return buffer The memory location of the buffer
    /// @dev Allocates `capacity + 0x60` bytes of space
    ///      The buffer array starts at the first container data position,
    ///      (i.e. `buffer = container + 0x20`)
    function allocate(uint256 capacity)
        internal
        pure
        returns (bytes memory buffer)
    {
        assembly {
            // Get next-free memory address
            let container := mload(0x40)

            // Allocate memory by setting a new next-free address
            {
                // Add 2 x 32 bytes in size for the two length fields
                // Add 32 bytes safety space for 32B chunked copy
                let size := add(capacity, 0x60)
                let newNextFree := add(container, size)
                mstore(0x40, newNextFree)
            }

            // Set the correct container length
            {
                let length := add(capacity, 0x40)
                mstore(container, length)
            }

            // The buffer starts at idx 1 in the container (0 is length)
            buffer := add(container, 0x20)

            // Init content with length 0
            mstore(buffer, 0)
        }

        return buffer;
    }

    /// @notice Appends data to buffer, and update buffer length
    /// @param buffer the buffer to append the data to
    /// @param data the data to append
    /// @dev Does not perform out-of-bound checks (container capacity)
    ///      for efficiency.
    function appendUnchecked(bytes memory buffer, bytes memory data)
        internal
        pure
    {
        assembly {
            let length := mload(data)
            for {
                data := add(data, 0x20)
                let dataEnd := add(data, length)
                let copyTo := add(buffer, add(mload(buffer), 0x20))
            } lt(data, dataEnd) {
                data := add(data, 0x20)
                copyTo := add(copyTo, 0x20)
            } {
                // Copy 32B chunks from data to buffer.
                // This may read over data array boundaries and copy invalid
                // bytes, which doesn't matter in the end since we will
                // later set the correct buffer length, and have allocated an
                // additional word to avoid buffer overflow.
                mstore(copyTo, mload(data))
            }

            // Update buffer length
            mstore(buffer, add(mload(buffer), length))
        }
    }

    /// @notice Appends data to buffer, and update buffer length
    /// @param buffer the buffer to append the data to
    /// @param data the data to append
    /// @dev Performs out-of-bound checks and calls `appendUnchecked`.
    function appendSafe(bytes memory buffer, bytes memory data) internal pure {
        uint256 capacity;
        uint256 length;
        assembly {
            capacity := sub(mload(sub(buffer, 0x20)), 0x40)
            length := mload(buffer)
        }

        require(
            length + data.length <= capacity,
            "DynamicBuffer: Appending out of bounds."
        );
        appendUnchecked(buffer, data);
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
pragma solidity ^0.8.0;

// solhint-disable no-inline-assembly
// solhint-disable no-empty-blocks

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // load the table into memory
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {

            } lt(dataPtr, endPtr) {

            } {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
                case 1 {
                    mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
                }
                case 2 {
                    mstore(sub(resultPtr, 1), shl(248, 0x3d))
                }
        }

        return result;
    }
}