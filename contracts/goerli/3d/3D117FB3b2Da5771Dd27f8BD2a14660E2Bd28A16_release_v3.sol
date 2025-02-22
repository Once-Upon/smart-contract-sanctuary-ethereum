// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contract[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/math/SafeMath.sol";
import "@openzeppelin/[email protected]/math/Math.sol";
import "@openzeppelin/[email protected]/utils/Arrays.sol";
import "@openzeppelin/[email protected]/utils/ReentrancyGuard.sol";
import "./CryptopunksData.sol";
import "./BleachBackground.sol";

contract release_v3 is ERC721, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant MAX_TOKENS = 10000;

    uint256 public constant MAX_TOKENS_PER_PURCHASE = 10;

    // uint256 private price = 80000000000000000; // 0.08 Ether
    uint256 private price = 1; // 1 Wei

    address public renderingContractAddress;
    address public backgroundContractAddress;

    constructor() ERC721("Releasev3", "RV3") Ownable() {}

    function setRenderingContractAddress(address _renderingContractAddress) public onlyOwner {
        renderingContractAddress = _renderingContractAddress;
    }

    function setBackgroundContractAddress(address _backgroundContractAddress) public onlyOwner {
        backgroundContractAddress = _backgroundContractAddress;
    }

    // Mint functionality

    function mint(uint256 _count) public payable nonReentrant {
        uint256 totalSupply = totalSupply();
        require(_count > 0 && _count < MAX_TOKENS_PER_PURCHASE + 1);
        require(totalSupply + _count < MAX_TOKENS + 1);
        require(msg.value >= price.mul(_count));
        for(uint256 i = 0; i < _count; i++){
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    function setPrice(uint256 _newPrice) public onlyOwner() {
        price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return price;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    // Random function

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    // Random punk

    // function randomPunk(uint256 tokenId) public view returns (uint16) {
    //     uint256 v = uint(keccak256(abi.encodePacked("a0867ed705a0", block.timestamp, block.difficulty, toString(tokenId)))) % 10000;
    //     uint16 original = uint16(v);
    //     return original;
    // }



    /// @dev Using keccak256 hash of the work "punk".
    // function randomPunk(uint256 tokenId) public pure returns (uint16) {
    //     uint256 v = uint(keccak256(abi.encodePacked("4c71ce6ba2ee0cfaa5acee977e8e67e2cd9b456dcdf1ab291519d32de27f4ece", toString(tokenId)))) % 10000;
    //     uint16 original = uint16(v);
    //     return original;
    // }

    // Background color

    /// @dev Using keccak256 has of the word "color".
    function backgroundColor(uint256 tokenId) private pure returns (string memory) {

      string[32] memory r;
      string[32] memory s = ["1", "6", "3", "9", "c", "4", "b", "d", "e", "8", "5", "0", "a", "f", "2", "7", "b", "7", "5", "1", "8", "d", "2", "a", "6", "c", "4", "f", "9", "0", "e", "3"];

      uint l = s.length;
      uint i;
      string memory t;

      while (l > 0) {
          uint256 v = random(string(abi.encodePacked("a5c2d689775609d255fc253eff456037883aa539c2155594344ccc1896935bf1", toString(tokenId))));
          i = v % l--;
          t = s[l];
          s[l] = s[i];
          s[i] = t;
      }

      r = s;

      string memory m = r[16];
      string memory f = "f";
      string memory o = "0";
      string memory j;

      if (keccak256(bytes(m)) == keccak256(bytes(f))) {
          j = "ffffff";
      } else if (keccak256(bytes(m)) == keccak256(bytes(o))) {
          j = "000000";
      } else {
          j = string(abi.encodePacked(r[5],r[11],r[7],r[4],r[10],r[15]));
      }

      return j;

    }

    // Make Attributes

    function makeAttributes(uint256 tokenId) private pure returns (string memory) {

        string[2] memory traits;
        // string memory originalPunk = toString(randomPunk(tokenId));
        string memory originalPunk = toString(tokenId);

        traits[0] = string(abi.encodePacked('{"trait_type":"Background Color: #","value":"', backgroundColor(tokenId), '"}'));
        traits[1] = string(abi.encodePacked('{"trait_type":"Original Punk: #","value":"', originalPunk, '"}'));

        string memory attributes = string(abi.encodePacked(traits[0], ',', traits[1]));

        return attributes;
    }

    function replaceValue(string memory svg,uint256 position, string memory replace) internal pure returns (string memory) {
        string memory t = _stringReplace(svg,position,replace);
        return t;
    }

    // function getBleach(uint256 tokenId) public view returns (string memory) {
    //
    //     BleachBackground bleachBackground = BleachBackground(backgroundContractAddress);
    //
    //     uint16 t = uint16(tokenId);
    //
    //     string memory b = bleachBackground.getBleach(t);
    //     return b;
    // }

    function getPlain(uint256 tokenId) public view returns (string memory) {

        CryptopunksData cryptopunksData = CryptopunksData(renderingContractAddress); // Running

        // uint16 t = randomPunk(tokenId);
        uint16 t = uint16(tokenId);

        string memory punkSvg = cryptopunksData.punkImageSvg(t); // Running

        // Add replacement values
        string[24] memory r = ["<","s","v","g",">","<","r","e","c","t",">","<","/","r","e","c","t",">","<","/","s","v","g",">"];

        string memory a = replaceValue(punkSvg,0,r[0]);
        a = replaceValue(a,1,r[1]);
        a = replaceValue(a,2,r[2]);
        a = replaceValue(a,3,r[3]);
        a = replaceValue(a,4,r[4]);
        a = replaceValue(a,5,r[5]);
        a = replaceValue(a,6,r[6]);
        a = replaceValue(a,7,r[7]);
        a = replaceValue(a,8,r[8]);
        a = replaceValue(a,9,r[9]);
        a = replaceValue(a,10,r[10]);
        a = replaceValue(a,11,r[11]);
        a = replaceValue(a,12,r[12]);
        a = replaceValue(a,13,r[13]);
        a = replaceValue(a,14,r[14]);
        a = replaceValue(a,15,r[15]);
        a = replaceValue(a,16,r[16]);
        a = replaceValue(a,17,r[17]);
        a = replaceValue(a,18,r[18]);
        a = replaceValue(a,19,r[19]);
        a = replaceValue(a,20,r[20]);
        a = replaceValue(a,21,r[21]);
        a = replaceValue(a,22,r[22]);
        a = replaceValue(a,23,r[23]);

        return a;

    }


    /// @dev Using keccak256 has of the work "inception".
    function getDescription(uint256 tokenId) public pure returns (string memory) {

        string memory description;
        string memory a = 'Bitcoin: A Peer-to-Peer Electronic Cash System Satoshi Nakamoto [email protected]';
        string memory b = "A purely peer-to-peer version of electronic cash would allow online payments to be sent directly from one party to another without going through a financial institution. Digital signatures provide part of the solution, but the main benefits are lost if a trusted third party is still required to prevent double-spending. We propose a solution to the double-spending problem using a peer-to-peer network. The network timestamps transactions by hashing them into an ongoing chain of hash-based proof-of-work, forming a record that cannot be changed without redoing the proof-of-work. The longest chain not only serves as proof of the sequence of events witnessed, but proof that it came from the largest pool of CPU power. As long as a majority of CPU power is controlled by nodes that are not cooperating to attack the network, they'll generate the longest chain and outpace attackers. The network itself requires minimal structure. Messages are broadcast on a best effort basis, and nodes can leave and rejoin the network at will, accepting the longest proof-of-work chain as proof of what happened while they were gone.";
        string memory c = 'Ethereum: A Next-Generation Smart Contract and Decentralized Application Platform. By Vitalik Buterin (2014).';
        string memory d = 'The intent of Ethereum is to merge together and improve upon the concepts of scripting, altcoins and on-chain meta-protocols, and allow developers to create arbitrary consensus-based applications that have the scalability, standardization, feature-completeness, ease of development and interoperability offered by these different paradigms all at the same time. Ethereum does this by building what is essentially the ultimate abstract foundational layer: a blockchain with a built-in Turing-complete programming language, allowing anyone to write smart contracts and decentralized applications where they can create their own arbitrary rules for ownership, transaction formats and state transition functions. A bare-bones version of Namecoin can be written in two lines of code, and other protocols like currencies and reputation systems can be built in under twenty. Smart contracts, cryptographic "boxes" that contain value and only unlock it if certain conditions are met, can also be built on top of our platform, with vastly more power than that offered by Bitcoin scripting because of the added powers of Turing-completeness, value-awareness, blockchain-awareness and state.';

        uint256 v = uint(keccak256(abi.encodePacked("a8f71cb43dedd4e7213aa5508325496c2f89e81ec48be005c3bd5b3e6c7c3090", toString(tokenId)))) % 4;

        if (v == 0) {
            description = a;
        } else if (v == 1) {
            description = b;
        } else if (v == 2) {
            description = c;
        } else {
            description = d;
        }

        return description;

    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {

        string[5] memory p;

        p[0] = '<svg transform="scale(-1,1) translate(-0,0)" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.2" viewBox="0 0 600 600"> <rect viewBox="0 0 600 600" width="600" height="600" fill="#';

        p[1] = backgroundColor(tokenId);

        p[2] = '" />';

        p[3] = getPlain(tokenId);

        p[4] = '</svg>';

        string memory o = string(abi.encodePacked(p[0], p[1], p[2], p[3], p[4]));
        // o = string(abi.encodePacked(o, p[9], p[10]));

        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Item #', toString(tokenId), '", "description": "', getDescription(tokenId), '", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(o)), '", "attributes": \x5B ', makeAttributes(tokenId), ' \x5D}'))));
        o = string(abi.encodePacked('data:application/json;base64,', json));

        return o;
    }

    // to String utility

    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
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

    // Replace string utility

    function _stringReplace(string memory _string, uint256 _pos, string memory _letter) internal pure returns (string memory) {
        bytes memory _stringBytes = bytes(_string);
        bytes memory result = new bytes(_stringBytes.length);

        for(uint i = 0; i < _stringBytes.length; i++) {
                result[i] = _stringBytes[i];
                if(i==_pos)
                result[i]=bytes(_letter)[0];
            }
            return  string(result);
    }

}

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}

pragma solidity 0.7.6;


contract BleachBackground {

    function getBleach(uint16 index) external pure returns (string memory bleach) {

        bleach = string(abi.encodePacked('data:image/png;base64,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'));

    }

}

/**
 *Submitted for verification at Etherscan.io on 2021-08-18
*/

pragma solidity 0.7.6;

/**
 *   ____                  _                          _          ____        _
 *  / ___|_ __ _   _ _ __ | |_ ___  _ __  _   _ _ __ | | _____  |  _ \  __ _| |_ __ _
 * | |   | '__| | | | '_ \| __/ _ \| '_ \| | | | '_ \| |/ / __| | | | |/ _` | __/ _` |
 * | |___| |  | |_| | |_) | || (_) | |_) | |_| | | | |   <\__ \ | |_| | (_| | || (_| |
 *  \____|_|   \__, | .__/ \__\___/| .__/ \__,_|_| |_|_|\_\___/ |____/ \__,_|\__\__,_|
 *             |___/|_|            |_|
 *
 * On-chain Cryptopunk images and attributes, by Larva Labs.
 *
 * This contract holds the image and attribute data for the Cryptopunks on-chain.
 * The Cryptopunk images are available as raw RGBA pixels, or in SVG format.
 * The punk attributes are available as a comma-separated list.
 * Included in the attribute list is the head type (various color male and female heads,
 * plus the rare zombie, ape, and alien types).
 *
 * This contract was motivated by community members snowfro and 0xdeafbeef, including a proof-of-concept contract created by 0xdeafbeef.
 * Without their involvement, the project would not have come to fruition.
 */
contract CryptopunksData {

    string internal constant SVG_HEADER = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" version="1.2" viewBox="0 0 24 24">';
    string internal constant SVG_FOOTER = '</svg>';

    bytes private palette;
    mapping(uint8 => bytes) private assets;
    mapping(uint8 => string) private assetNames;
    mapping(uint64 => uint32) private composites;
    mapping(uint8 => bytes) private punks;

    address payable internal deployer;
    bool private contractSealed = false;

    modifier onlyDeployer() {
        require(msg.sender == deployer, "Only deployer.");
        _;
    }

    modifier unsealed() {
        require(!contractSealed, "Contract sealed.");
        _;
    }

    constructor() {
        deployer = msg.sender;
    }

    function setPalette(bytes memory _palette) external onlyDeployer unsealed {
        palette = _palette;
    }

    function addAsset(uint8 index, bytes memory encoding, string memory name) external onlyDeployer unsealed {
        assets[index] = encoding;
        assetNames[index] = name;
    }

    function addComposites(uint64 key1, uint32 value1, uint64 key2, uint32 value2, uint64 key3, uint32 value3, uint64 key4, uint32 value4) external onlyDeployer unsealed {
        composites[key1] = value1;
        composites[key2] = value2;
        composites[key3] = value3;
        composites[key4] = value4;
    }

    function addPunks(uint8 index, bytes memory _punks) external onlyDeployer unsealed {
        punks[index] = _punks;
    }

    function sealContract() external onlyDeployer unsealed {
        contractSealed = true;
    }

    /**
     * The Cryptopunk image for the given index.
     * The image is represented in a row-major byte array where each set of 4 bytes is a pixel in RGBA format.
     * @param index the punk index, 0 <= index < 10000
     */
    function punkImage(uint16 index) public view returns (bytes memory) {
        require(index >= 0 && index < 10000);
        bytes memory pixels = new bytes(2304);
        for (uint j = 0; j < 8; j++) {
            uint8 asset = uint8(punks[uint8(index / 100)][(index % 100) * 8 + j]);
            if (asset > 0) {
                bytes storage a = assets[asset];
                uint n = a.length / 3;
                for (uint i = 0; i < n; i++) {
                    uint[4] memory v = [
                        uint(uint8(a[i * 3]) & 0xF0) >> 4,
                        uint(uint8(a[i * 3]) & 0xF),
                        uint(uint8(a[i * 3 + 2]) & 0xF0) >> 4,
                        uint(uint8(a[i * 3 + 2]) & 0xF)
                    ];
                    for (uint dx = 0; dx < 2; dx++) {
                        for (uint dy = 0; dy < 2; dy++) {
                            uint p = ((2 * v[1] + dy) * 24 + (2 * v[0] + dx)) * 4;
                            if (v[2] & (1 << (dx * 2 + dy)) != 0) {
                                bytes4 c = composite(a[i * 3 + 1],
                                        pixels[p],
                                        pixels[p + 1],
                                        pixels[p + 2],
                                        pixels[p + 3]
                                    );
                                pixels[p] = c[0];
                                pixels[p+1] = c[1];
                                pixels[p+2] = c[2];
                                pixels[p+3] = c[3];
                            } else if (v[3] & (1 << (dx * 2 + dy)) != 0) {
                                pixels[p] = 0;
                                pixels[p+1] = 0;
                                pixels[p+2] = 0;
                                pixels[p+3] = 0xFF;
                            }
                        }
                    }
                }
            }
        }
        return pixels;
    }

    /**
     * The Cryptopunk image for the given index, in SVG format.
     * In the SVG, each "pixel" is represented as a 1x1 rectangle.
     * @param index the punk index, 0 <= index < 10000
     */
    function punkImageSvg(uint16 index) external pure returns (string memory svg) {
        // bytes memory pixels = punkImage(index);
        svg = string(abi.encodePacked(SVG_HEADER));
        // bytes memory buffer = new bytes(8);
        // for (uint y = 0; y < 24; y++) {
        //     for (uint x = 0; x < 24; x++) {
        //         uint p = (y * 24 + x) * 4;
        //         if (uint8(pixels[p + 3]) > 0) {
        //             for (uint i = 0; i < 4; i++) {
        //                 uint8 value = uint8(pixels[p + i]);
        //                 buffer[i * 2 + 1] = _HEX_SYMBOLS[value & 0xf];
        //                 value >>= 4;
        //                 buffer[i * 2] = _HEX_SYMBOLS[value & 0xf];
        //             }
        //             svg = string(abi.encodePacked(svg,
        //                 '<rect x="', toString(x), '" y="', toString(y),'" width="1" height="1" shape-rendering="crispEdges" fill="#', string(buffer),'"/>'));
        //         }
        //     }
        // }
        svg = string(abi.encodePacked(svg,'<rect x="9" y="5" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="10" y="5" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="11" y="5" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="12" y="5" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="13" y="5" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="14" y="5" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="9" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="10" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="11" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="12" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="13" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="14" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="15" y="6" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="9" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="10" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="11" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="12" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="13" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="14" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="15" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="16" y="7" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="9" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="10" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="11" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="12" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="13" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="14" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="16" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="8" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="10" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="11" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="12" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="13" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="16" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="9" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="12" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="16" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="10" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="5" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="16" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="11" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="5" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="8" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#507c33ff"/><rect x="10" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#507c33ff"/><rect x="11" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#507c33ff"/><rect x="15" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#507c33ff"/><rect x="16" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="12" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="5" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="8" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="10" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#5d8b43ff"/><rect x="11" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="15" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#5d8b43ff"/><rect x="16" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="13" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="5" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="16" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="14" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="5" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="16" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="18" y="15" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="5" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="9" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="13" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="16" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="18" y="16" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="4" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="5" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="9" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="16" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="17" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="18" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="19" y="17" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="6" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="7" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="9" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="10" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#5f1d09ff"/><rect x="12" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#5f1d09ff"/><rect x="13" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#5f1d09ff"/><rect x="14" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="16" y="18" width="1" height="1" shape-rendering="crispEdges" fill="#fff68eff"/><rect x="8" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="9" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="15" y="19" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="8" y="20" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="9" y="20" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="20" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="11" y="20" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="20" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="13" y="20" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="14" y="20" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="8" y="21" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="9" y="21" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="21" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="21" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="12" y="21" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="13" y="21" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="8" y="22" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="9" y="22" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="22" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="22" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="22" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="8" y="23" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/><rect x="9" y="23" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="10" y="23" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="11" y="23" width="1" height="1" shape-rendering="crispEdges" fill="#ae8b61ff"/><rect x="12" y="23" width="1" height="1" shape-rendering="crispEdges" fill="#000000ff"/>'));

        svg = string(abi.encodePacked(svg, SVG_FOOTER));
    }

    /**
     * The Cryptopunk attributes for the given index.
     * The attributes are a comma-separated list in UTF-8 string format.
     * The first entry listed is not technically an attribute, but the "head type" of the Cryptopunk.
     * @param index the punk index, 0 <= index < 10000
     */
    function punkAttributes(uint16 index) external view returns (string memory text) {
        require(index >= 0 && index < 10000);
        uint8 cell = uint8(index / 100);
        uint offset = (index % 100) * 8;
        for (uint j = 0; j < 8; j++) {
            uint8 asset = uint8(punks[cell][offset + j]);
            if (asset > 0) {
                if (j > 0) {
                    text = string(abi.encodePacked(text, ", ", assetNames[asset]));
                } else {
                    text = assetNames[asset];
                }
            } else {
                break;
            }
        }
    }

    function composite(byte index, byte yr, byte yg, byte yb, byte ya) internal view returns (bytes4 rgba) {
        uint x = uint(uint8(index)) * 4;
        uint8 xAlpha = uint8(palette[x + 3]);
        if (xAlpha == 0xFF) {
            rgba = bytes4(uint32(
                    (uint(uint8(palette[x])) << 24) |
                    (uint(uint8(palette[x+1])) << 16) |
                    (uint(uint8(palette[x+2])) << 8) |
                    xAlpha
                ));
        } else {
            uint64 key =
                (uint64(uint8(palette[x])) << 56) |
                (uint64(uint8(palette[x + 1])) << 48) |
                (uint64(uint8(palette[x + 2])) << 40) |
                (uint64(xAlpha) << 32) |
                (uint64(uint8(yr)) << 24) |
                (uint64(uint8(yg)) << 16) |
                (uint64(uint8(yb)) << 8) |
                (uint64(uint8(ya)));
            rgba = bytes4(composites[key]);
        }
    }

    //// String stuff from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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

}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../math/Math.sol";

/**
 * @dev Collection of functions related to array types.
 */
library Arrays {
   /**
     * @dev Searches a sorted `array` and returns the first index that contains
     * a value greater or equal to `element`. If no such index exists (i.e. all
     * values in the array are strictly less than `element`), the array length is
     * returned. Time complexity O(log n).
     *
     * `array` is expected to be sorted in ascending order, and to contain no
     * repeated elements.
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "./IERC721.sol";

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

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC721.sol";
import "./IERC721Metadata.sol";
import "./IERC721Enumerable.sol";
import "./IERC721Receiver.sol";
import "../../introspection/ERC165.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";
import "../../utils/EnumerableSet.sol";
import "../../utils/EnumerableMap.sol";
import "../../utils/Strings.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata, IERC721Enumerable {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURI;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _holderTokens[owner].length();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
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

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    /**
    * @dev Returns the base URI set via {_setBaseURI}. This will be
    * automatically added as a prefix in {tokenURI} to each token's URI, or
    * to the token ID if no specific URI is set for that token ID.
    */
    function baseURI() public view virtual returns (string memory) {
        return _baseURI;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || ERC721.isApprovedForAll(owner, _msgSender()),
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
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
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
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
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
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
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
        return _tokenOwners.contains(tokenId);
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
        return (spender == owner || getApproved(tokenId) == spender || ERC721.isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     d*
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
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
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

        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

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
        address owner = ERC721.ownerOf(tokenId); // internal owner

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        // Clear metadata (if any)
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }

        _holderTokens[owner].remove(tokenId);

        _tokenOwners.remove(tokenId);

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
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own"); // internal owner
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     */
    function _setBaseURI(string memory baseURI_) internal virtual {
        _baseURI = baseURI_;
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
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
            IERC721Receiver(to).onERC721Received.selector,
            _msgSender(),
            from,
            tokenId,
            _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    function _approve(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId); // internal owner
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
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "../../introspection/IERC165.sol";

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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    /**
     * @dev Converts a `uint256` to its ASCII `string` representation.
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
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * As of v3.0.0, only maps of type `uint256 -> address` (`UintToAddressMap`) are
 * supported.
 */
library EnumerableMap {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct MapEntry {
        bytes32 _key;
        bytes32 _value;
    }

    struct Map {
        // Storage of map keys and values
        MapEntry[] _entries;

        // Position of the entry defined by a key in the `entries` array, plus 1
        // because index 0 means a key is not in the map.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function _set(Map storage map, bytes32 key, bytes32 value) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex == 0) { // Equivalent to !contains(map, key)
            map._entries.push(MapEntry({ _key: key, _value: value }));
            // The entry is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            map._indexes[key] = map._entries.length;
            return true;
        } else {
            map._entries[keyIndex - 1]._value = value;
            return false;
        }
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function _remove(Map storage map, bytes32 key) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex != 0) { // Equivalent to contains(map, key)
            // To delete a key-value pair from the _entries array in O(1), we swap the entry to delete with the last one
            // in the array, and then remove the last entry (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = keyIndex - 1;
            uint256 lastIndex = map._entries.length - 1;

            // When the entry to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            MapEntry storage lastEntry = map._entries[lastIndex];

            // Move the last entry to the index where the entry to delete is
            map._entries[toDeleteIndex] = lastEntry;
            // Update the index for the moved entry
            map._indexes[lastEntry._key] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved entry was stored
            map._entries.pop();

            // Delete the index for the deleted slot
            delete map._indexes[key];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function _contains(Map storage map, bytes32 key) private view returns (bool) {
        return map._indexes[key] != 0;
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function _length(Map storage map) private view returns (uint256) {
        return map._entries.length;
    }

   /**
    * @dev Returns the key-value pair stored at position `index` in the map. O(1).
    *
    * Note that there are no guarantees on the ordering of entries inside the
    * array, and it may change when more entries are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Map storage map, uint256 index) private view returns (bytes32, bytes32) {
        require(map._entries.length > index, "EnumerableMap: index out of bounds");

        MapEntry storage entry = map._entries[index];
        return (entry._key, entry._value);
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     */
    function _tryGet(Map storage map, bytes32 key) private view returns (bool, bytes32) {
        uint256 keyIndex = map._indexes[key];
        if (keyIndex == 0) return (false, 0); // Equivalent to contains(map, key)
        return (true, map._entries[keyIndex - 1]._value); // All indexes are 1-based
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function _get(Map storage map, bytes32 key) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, "EnumerableMap: nonexistent key"); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }

    /**
     * @dev Same as {_get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {_tryGet}.
     */
    function _get(Map storage map, bytes32 key, string memory errorMessage) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, errorMessage); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        return _set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return _remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return _contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

   /**
    * @dev Returns the element stored at position `index` in the set. O(1).
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (uint256(key), address(uint160(uint256(value))));
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     *
     * _Available since v3.4._
     */
    function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool, address) {
        (bool success, bytes32 value) = _tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(value))));
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint160(uint256(_get(map._inner, bytes32(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(UintToAddressMap storage map, uint256 key, string memory errorMessage) internal view returns (address) {
        return address(uint160(uint256(_get(map._inner, bytes32(key), errorMessage))));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity >=0.6.0 <0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
abstract contract ERC165 is IERC165 {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor () internal {
        // Derived contracts need only register support for their own interfaces,
        // we register support for ERC165 itself here
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "./IERC721.sol";

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

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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