//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SoundPlayer {
    address private NEO = 0x0000000000000000000000000000000000000000;
    //{ songData: [{ i: [2, 192, 128, 0, 2, 192, 128, 3, 0, 0, 32, 222, 60, 0, 0, 0, 2, 188, 3, 1, 3, 55, 241, 60, 67, 53, 5, 75, 5], p: [1, 2, 3, 4, 3, 4], c: [{ n: [123], f: [] }, { n: [118], f: [] }, { n: [123, 111], f: [] }, { n: [118, 106], f: [] }] }, { i: [3, 100, 128, 0, 3, 201, 128, 7, 0, 0, 17, 43, 109, 0, 0, 0, 3, 113, 4, 1, 1, 23, 184, 2, 29, 147, 6, 67, 3], p: [, , 1, 2, 1, 2], c: [{ n: [123, , , , , , , , 123, , , , , , , , 123, , , , , , , , 123, , , , , , , , 126, , , , , , , , 126, , , , , , , , 126, , , , , , , , 126, , , , , , , , 130, , , , , , , , 130, , , , , , , , 130, , , , , , , , 130], f: [] }, { n: [122, , , , , , , , 122, , , , , , , , 122, , , , , , , , 122, , , , , , , , 125, , , , , , , , 125, , , , , , , , 125, , , , , , , , 125, , , , , , , , 130, , , , , , , , 130, , , , , , , , 130, , , , , , , , 130], f: [] }] }, { i: [0, 192, 99, 64, 0, 80, 99, 0, 0, 3, 4, 0, 66, 0, 0, 0, 0, 19, 4, 1, 2, 86, 241, 18, 195, 37, 4, 0, 0], p: [, , 1, 1, 1, 1, 1], c: [{ n: [147, , , , 147, , , , 147, , , , 147, , , , 147, , , , 147, , , , 147, , , , 147], f: [] }] }, { i: [2, 146, 140, 0, 2, 224, 128, 3, 0, 0, 84, 0, 95, 0, 0, 0, 3, 179, 5, 1, 2, 62, 135, 11, 15, 150, 3, 157, 6], p: [, , , , 1, 2], c: [{ n: [147, , 145, , 147, , , , , , , , , , , , 135], f: [11, , , , , , , , , , , , , , , , 11, , , , , , , , , , , , , , , , 27, , , , , , , , , , , , , , , , 84] }, { n: [142, , 140, , 142, , , , , , , , , , , , 130], f: [11, , , , , , , , , , , , , , , , 11, , , , , , , , , , , , , , , , 27, , , , , , , , , , , , , , , , 84] }] }], rowLen: 6615, patternLen: 32, endPattern: 6, numChannels: 4}
    string[2] private soundScript = [
        '<script type="text/javascript"> "use strict"; var songObj = JSON.parse(',
        '); var CPlayer = function () { var _, $, n, e, r, t = function (_) { return Math.sin(6.283184 * _) }, i = function (_) { return .003959503758 * 2 ** ((_ - 128) / 12) }, a = function (_, $, n) { var e, r, t, a, u, o, c = f[_.i[0]], v = _.i[1], s = _.i[3] / 32, l = f[_.i[4]], p = _.i[5], w = _.i[8] / 32, d = _.i[9], g = _.i[10] * _.i[10] * 4, h = _.i[11] * _.i[11] * 4, m = _.i[12] * _.i[12] * 4, L = 1 / m, y = -_.i[13] / 16, C = _.i[14], D = n * 2 ** (2 - _.i[15]), P = new Int32Array(g + h + m), T = 0, B = 0; for (e = 0, r = 0; e < g + h + m; e++, r++)r >= 0 && (C = C >> 8 | (255 & C) << 4, r -= D, u = i($ + (15 & C) + _.i[2] - 128), o = i($ + (15 & C) + _.i[6] - 128) * (1 + 8e-4 * _.i[7])), t = 1, e < g ? t = e / g : e >= g + h && (t = (1 - (t = (e - g - h) * L)) * 3 ** (y * t)), T += u * t ** s, a = c(T) * v, B += o * t ** w, a += l(B) * p, d && (a += (2 * Math.random() - 1) * d), P[e] = 80 * a * t | 0; return P }, f = [t, function (_) { return _ % 1 < .5 ? 1 : -1 }, function (_) { return 2 * (_ % 1) - 1 }, function (_) { var $ = _ % 1 * 4; return $ < 2 ? $ - 1 : 3 - $ }]; this.init = function (t) { _ = t, $ = t.endPattern, n = 0, e = t.rowLen * t.patternLen * ($ + 1) * 2, r = new Int32Array(e) }, this.generate = function () { var i, u, o, c, v, s, l, p, w, d, g, h, m, L, y = new Int32Array(e), C = _.songData[n], D = _.rowLen, P = _.patternLen, T = 0, B = 0, E = !1, b = []; for (o = 0; o <= $; ++o)for (c = 0, l = C.p[o]; c < P; ++c) { var j = l ? C.c[l - 1].f[c] : 0; j && (C.i[j - 1] = C.c[l - 1].f[c + P] || 0, j < 17 && (b = [])); var O = f[C.i[16]], R = C.i[17] / 512, U = 2 ** (C.i[18] - 9) / D, W = C.i[19], A = C.i[20], I = 135.82764118168 * C.i[21] / 44100, k = 1 - C.i[22] / 255, q = 1e-5 * C.i[23], x = C.i[24] / 32, z = C.i[25] / 512, F = 6.283184 * 2 ** (C.i[26] - 9) / D, G = C.i[27] / 255, H = C.i[28] * D & -2; for (v = 0, g = (o * P + c) * D; v < 4; ++v)if (s = l ? C.c[l - 1].n[c + v * P] : 0) { b[s] || (b[s] = a(C, s, D)); var J = b[s]; for (u = 0, i = 2 * g; u < J.length; u++, i += 2)y[i] += J[u] } for (u = 0; u < D; u++)(d = y[p = (g + u) * 2]) || E ? (h = I, W && (h *= O(U * p) * R + .5), T += (h = 1.5 * Math.sin(h)) * B, m = k * (d - B) - T, B += h * m, d = 3 == A ? B : 1 == A ? m : T, q && (d *= q, d = d < 1 ? d > -1 ? t(.25 * d) : -1 : 1, d /= q), d *= x, E = d * d > 1e-5, L = d * (1 - (w = Math.sin(F * p) * z + .5)), d *= w) : L = 0, p >= H && (L += y[p - H + 1] * G, d += y[p - H] * G), y[p] = 0 | L, y[p + 1] = 0 | d, r[p] += 0 | L, r[p + 1] += 0 | d } return ++n / _.numChannels }, this.createAudioBuffer = function (_) { for (var $ = _.createBuffer(2, e / 2, 44100), n = 0; n < 2; n++)for (var t = $.getChannelData(n), i = n; i < e; i += 2)t[i >> 1] = r[i] / 65536; return $ }, this.createWave = function () { var _ = 44 + 2 * e - 8, $ = _ - 36, n = new Uint8Array(44 + 2 * e); n.set([82, 73, 70, 70, 255 & _, _ >> 8 & 255, _ >> 16 & 255, _ >> 24 & 255, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 2, 0, 68, 172, 0, 0, 16, 177, 2, 0, 4, 0, 16, 0, 100, 97, 116, 97, 255 & $, $ >> 8 & 255, $ >> 16 & 255, $ >> 24 & 255]); for (var t = 0, i = 44; t < e; ++t) { var a = r[t]; a = a < -32767 ? -32767 : a > 32767 ? 32767 : a, n[i++] = 255 & a, n[i++] = a >> 8 & 255 } return n }, this.getData = function (_, $) { for (var n = 2 * Math.floor(44100 * _), e = Array($), t = 0; t < 2 * $; t += 1) { var i = n + t; e[t] = _ > 0 && i < r.length ? r[i] / 32768 : 0 } return e } }; function song() { var _ = new CPlayer; _.init(songObj); var $ = !1; setInterval(function () { if (!$ && (document.getElementById("status"), $ = _.generate() >= 1)) { var n = _.createWave(), e = document.createElement("audio"), r = document.createElement("audio"); e.src = URL.createObjectURL(new Blob([n], { type: "audio/wav" })), r.src = URL.createObjectURL(new Blob([n], { type: "audio/wav" })), !function _($, n) { if ($ || n ? $ && !n && (e.currentTime = 0, e.play(), $ = !1) : (r.currentTime = 0, r.play(), $ = !0), $ && r.currentTime >= r.duration - 4.5 || !$ && e.currentTime >= e.duration - 4.5) { _($, !1); return } setTimeout(function () { _($, !0) }, 250) }(!0) } }, 0) } </script>'
    ];

    string[] private songData = [
        "rowLen:",
        ",patternLen:",
        ",endPattern:",
        ",numChannels:"
    ];

    struct Song {
        string song;
        string name;
        string description;
        address owner;
        uint64 rowLen;
        uint64 patternLen;
        uint64 endPattern;
        uint64 numChannels;
    }

    uint256 public songIndex = 0;

    uint256[] public reuseSongIndexes;

    mapping(uint256 => Song) public songs;
    mapping(address => uint256[]) public userSongs;

    constructor() {
        //   NEO = _NEO;
    }

    function addSong(
        string memory _name,
        string memory _description,
        string memory _song,
        uint64 rowLen,
        uint64 patternLen,
        uint64 endPattern,
        uint64 numChannels
    ) public {
        songs[songIndex] = Song(
            _song,
            _name,
            _description,
            msg.sender,
            rowLen,
            patternLen,
            endPattern,
            numChannels
        );

        if (reuseSongIndexes.length > 0) {
            uint256 _songId = reuseSongIndexes[reuseSongIndexes.length - 1];
            reuseSongIndexes.pop();
            songs[_songId] = Song(
                _song,
                _name,
                _description,
                msg.sender,
                rowLen,
                patternLen,
                endPattern,
                numChannels
            );
            userSongs[msg.sender].push(_songId);
            return;
        }

        userSongs[msg.sender].push(songIndex);
        songIndex++;
    }

    function getScriptAndSongByAddress(
        address _address,
        uint256 _index
    ) public view returns (string memory) {
        uint256 _songId = userSongs[_address][_index];
        Song memory _song = songs[_songId];
        bytes memory song = abi.encodePacked(
            "{ songData:",
            _song.song,
            ",rowLen:",
            Strings.toString(_song.rowLen),
            ",patternLen:",
            Strings.toString(_song.patternLen),
            ",endPattern:",
            Strings.toString(_song.endPattern),
            ",numChannels:",
            Strings.toString(_song.numChannels),
            "}"
        );
        bytes memory script = abi.encodePacked(
            soundScript[0],
            song,
            soundScript[1]
        );

        return string(script);
    }

    function getScriptAndSongById(
        uint256 _id
    ) public view returns (string memory) {
        Song memory _song = songs[_id];
        bytes memory song = abi.encodePacked(
            _song.song,
            ",rowLen:",
            Strings.toString(_song.rowLen),
            ",patternLen:",
            Strings.toString(_song.patternLen),
            ",endPattern:",
            Strings.toString(_song.endPattern),
            ",numChannels:",
            Strings.toString(_song.numChannels)
        );
        bytes memory script = abi.encodePacked(
            soundScript[0],
            song,
            soundScript[1]
        );

        return string(script);
    }

    function getSongWithOpt(
        address _address,
        uint256 _index,
        uint64 _rowLen,
        uint64 _patternLen,
        uint64 _endPattern,
        uint64 _numChannels
    ) public view returns (string memory) {
        uint256 _songId = userSongs[_address][_index];
        Song memory _song = songs[_songId];
        bytes memory song = abi.encodePacked(
            "{ songData:",
            _song.song,
            ",rowLen:",
            Strings.toString(_rowLen),
            ",patternLen:",
            Strings.toString(_patternLen),
            ",endPattern:",
            Strings.toString(_endPattern),
            ",numChannels:",
            Strings.toString(_numChannels),
            "}"
        );
        bytes memory script = abi.encodePacked(
            soundScript[0],
            song,
            soundScript[1]
        );

        return string(script);
    }

    function ownerOf(uint256 _index) public view returns (address) {
        return songs[_index].owner;
    }

    function ownerOfByAddress(
        address _address,
        uint256 _index
    ) public view returns (address) {
        uint256 _songId = userSongs[_address][_index];
        return songs[_songId].owner;
    }

    function getOwnerSongs(
        address _address
    ) public view returns (uint256[] memory) {
        return userSongs[_address];
    }

    function editSong(uint256 _id, string memory _song) public {
        require(
            msg.sender == songs[_id].owner,
            "You can only edit your own songs"
        );
        songs[_id].song = _song;
    }

    function editSongOpts(
        uint256 _id,
        uint64 rowLen,
        uint64 patternLen,
        uint64 endPattern,
        uint64 numChannels
    ) public {
        require(
            msg.sender == songs[_id].owner,
            "You can only edit your own songs"
        );
        songs[_id].rowLen = rowLen;
        songs[_id].patternLen = patternLen;
        songs[_id].endPattern = endPattern;
        songs[_id].numChannels = numChannels;
    }

    function removeSongAndMove(uint256 _id) public {
        require(
            msg.sender == songs[_id].owner,
            "You can only edit your own songs"
        );
        uint256[] storage _userSongs = userSongs[msg.sender];
        uint256 _index = 0;
        for (uint256 i = 0; i < _userSongs.length; i++) {
            if (_userSongs[i] == _id) {
                _index = i;

                break;
            }
        }

        for (uint256 i = _index; i < _userSongs.length - 1; i++) {
            _userSongs[i] = _userSongs[i + 1];
        }

        _userSongs.pop();

        delete songs[_id];

        reuseSongIndexes.push(_id);
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