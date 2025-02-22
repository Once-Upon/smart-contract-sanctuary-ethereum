// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interface/IDiamondDawnMine.sol";
import "./interface/IDiamondDawnMineAdmin.sol";
import "./objects/Diamond.sol";
import "./objects/Mine.sol";
import "./utils/MathUtils.sol";
import "./utils/Serializer.sol";

/**
 *    ________    .__                                           .___
 *    \______ \   |__| _____      _____     ____     ____     __| _/
 *     |    |  \  |  | \__  \    /     \   /  _ \   /    \   / __ |
 *     |    `   \ |  |  / __ \_ |  Y Y  \ (  <_> ) |   |  \ / /_/ |
 *    /_______  / |__| (____  / |__|_|  /  \____/  |___|  / \____ |
 *            \/            \/        \/                \/       \/
 *    ________
 *    \______ \   _____    __  _  __   ____
 *     |    |  \  \__  \   \ \/ \/ /  /    \
 *     |    `   \  / __ \_  \     /  |   |  \
 *    /_______  / (____  /   \/\_/   |___|  /
 *            \/       \/                 \/
 *       _____    .__
 *      /     \   |__|   ____     ____
 *     /  \ /  \  |  |  /    \  _/ __ \
 *    /    Y    \ |  | |   |  \ \  ___/
 *    \____|__  / |__| |___|  /  \___  >
 *            \/            \/       \/
 *
 * @title DiamondDawnMine
 * @author Mike Moldawsky (Tweezers)
 */
contract DiamondDawnMine is AccessControlEnumerable, IDiamondDawnMine, IDiamondDawnMineAdmin {
    bool public isLocked; // mine is locked forever.
    bool public isInitialized;
    uint16 public maxDiamonds;
    uint16 public diamondCount;
    address public diamondDawn;
    mapping(uint => string) public manifests;

    // Carat loss of ~35% to ~65% from rough stone to the polished diamond.
    uint8 private constant MIN_EXTRA_ROUGH_POINTS = 37;
    uint8 private constant MAX_EXTRA_ROUGH_POINTS = 74;
    // Carat loss of ~2% to ~8% in the polish process.
    uint8 private constant MIN_EXTRA_POLISH_POINTS = 1;
    uint8 private constant MAX_EXTRA_POLISH_POINTS = 4;

    uint16 private _mineCounter;
    uint16 private _cutCounter;
    uint16 private _polishedCounter;
    uint16 private _rebornCounter;
    uint16 private _randNonce = 0;
    Certificate[] private _mine;
    mapping(uint => Metadata) private _metadata;
    string private _baseTokenURI = "ar://";

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**********************     Modifiers     ************************/
    modifier onlyDiamondDawn() {
        require(_msgSender() == diamondDawn, "Only DD");
        _;
    }

    modifier notInitialized() {
        require(!isInitialized, "Initialized");
        _;
    }

    modifier exists(uint tokenId) {
        require(_metadata[tokenId].state_ != Stage.NO_STAGE, "Don't exist");
        _;
    }

    modifier canProcess(uint tokenId, Stage state_) {
        require(!isLocked, "Locked");
        require(state_ == _metadata[tokenId].state_, "Can't process");
        _;
    }

    modifier mineOverflow(uint cnt) {
        require((diamondCount + cnt) <= maxDiamonds, "Mine overflow");
        _;
    }

    modifier mineNotDry() {
        require(_mine.length > 0, "Dry mine");
        _;
    }

    /**********************     External Functions     ************************/
    function initialize(uint16 maxDiamonds_) external notInitialized {
        diamondDawn = _msgSender();
        maxDiamonds = maxDiamonds_;
        isInitialized = true;
    }

    function forge(uint tokenId) external onlyDiamondDawn canProcess(tokenId, Stage.NO_STAGE) {
        _metadata[tokenId].state_ = Stage.KEY;
        emit Forge(tokenId);
    }

    function mine(uint tokenId) external onlyDiamondDawn mineNotDry canProcess(tokenId, Stage.KEY) {
        uint extraPoints = _getRandomBetween(MIN_EXTRA_ROUGH_POINTS, MAX_EXTRA_ROUGH_POINTS);
        Metadata storage metadata = _metadata[tokenId];
        metadata.state_ = Stage.MINE;
        metadata.rough.id = ++_mineCounter;
        metadata.rough.extraPoints = uint8(extraPoints);
        metadata.rough.shape = extraPoints % 2 == 0 ? RoughShape.MAKEABLE_1 : RoughShape.MAKEABLE_2;
        metadata.certificate = _mineDiamond();
        emit Mine(tokenId);
    }

    function cut(uint tokenId) external onlyDiamondDawn canProcess(tokenId, Stage.MINE) {
        uint extraPoints = _getRandomBetween(MIN_EXTRA_POLISH_POINTS, MAX_EXTRA_POLISH_POINTS);
        Metadata storage metadata = _metadata[tokenId];
        metadata.state_ = Stage.CUT;
        metadata.cut.id = ++_cutCounter;
        metadata.cut.extraPoints = uint8(extraPoints);
        emit Cut(tokenId);
    }

    function polish(uint tokenId) external onlyDiamondDawn canProcess(tokenId, Stage.CUT) {
        Metadata storage metadata = _metadata[tokenId];
        metadata.state_ = Stage.POLISH;
        metadata.polished.id = ++_polishedCounter;
        emit Polish(tokenId);
    }

    function ship(uint tokenId) external onlyDiamondDawn canProcess(tokenId, Stage.POLISH) {
        Metadata storage metadata = _metadata[tokenId];
        require(metadata.reborn.id == 0, "Shipped");
        metadata.reborn.id = ++_rebornCounter;
        emit Ship(tokenId, metadata.reborn.id, metadata.certificate.number);
    }

    function dawn(uint tokenId) external onlyDiamondDawn {
        require(_metadata[tokenId].reborn.id > 0, "Not shipped");
        require(_metadata[tokenId].state_ == Stage.POLISH, "Wrong state");
        _metadata[tokenId].state_ = Stage.DAWN;
        emit Dawn(tokenId);
    }

    function lockMine() external onlyDiamondDawn {
        while (0 < getRoleMemberCount(DEFAULT_ADMIN_ROLE)) {
            _revokeRole(DEFAULT_ADMIN_ROLE, getRoleMember(DEFAULT_ADMIN_ROLE, 0));
        }
        isLocked = true;
    }

    function eruption(Certificate[] calldata diamonds)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        mineOverflow(diamonds.length)
    {
        for (uint i = 0; i < diamonds.length; i++) {
            _mine.push(diamonds[i]);
        }
        diamondCount += uint16(diamonds.length);
    }

    function lostShipment(uint tokenId, Certificate calldata diamond) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Metadata storage metadata = _metadata[tokenId];
        require(metadata.state_ == Stage.POLISH || metadata.state_ == Stage.DAWN, "Wrong shipment state");
        metadata.certificate = diamond;
    }

    function setManifest(Stage stage_, string calldata manifest) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(stage_ != Stage.NO_STAGE);
        manifests[uint(stage_)] = manifest;
    }

    function setBaseTokenURI(string calldata baseTokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseTokenURI;
    }

    function getMetadata(uint tokenId) external view onlyDiamondDawn exists(tokenId) returns (string memory) {
        Metadata memory metadata = _metadata[tokenId];
        string memory noExtensionURI = _getNoExtensionURI(metadata);
        string memory base64Json = Base64.encode(bytes(_getMetadataJson(tokenId, metadata, noExtensionURI)));
        return string(abi.encodePacked("data:application/json;base64,", base64Json));
    }

    function isReady(Stage stage_) external view returns (bool) {
        require(_msgSender() == diamondDawn || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Only DD or admin");
        if (stage_ == Stage.NO_STAGE) return true;
        if (stage_ == Stage.COMPLETED) return true;
        if (stage_ == Stage.MINE && diamondCount != maxDiamonds) return false;
        return bytes(manifests[uint(stage_)]).length > 0;
    }

    /**********************     Private Functions     ************************/

    function _mineDiamond() private returns (Certificate memory) {
        assert(_mine.length > 0);
        uint index = _getRandomBetween(0, _mine.length - 1);
        Certificate memory diamond = _mine[index];
        _mine[index] = _mine[_mine.length - 1]; // swap last diamond with mined diamond
        _mine.pop();
        return diamond;
    }

    function _getRandomBetween(uint min, uint max) private returns (uint) {
        _randNonce++;
        return getRandomInRange(min, max, _randNonce);
    }

    function _getNoExtensionURI(Metadata memory metadata) private view returns (string memory) {
        string memory manifest = manifests[uint(metadata.state_)];
        string memory name = _getResourceName(metadata);
        return string.concat(_baseTokenURI, manifest, "/", name);
    }

    function _getMetadataJson(
        uint tokenId,
        Metadata memory metadata,
        string memory noExtensionURI
    ) private view returns (string memory) {
        Serializer.NFTMetadata memory nftMetadata = Serializer.NFTMetadata({
            name: Serializer.getName(metadata, tokenId),
            image: string.concat(noExtensionURI, ".jpeg"),
            animationUrl: string.concat(noExtensionURI, ".mp4"),
            attributes: _getJsonAttributes(metadata)
        });
        return Serializer.serialize(nftMetadata);
    }

    function _getJsonAttributes(Metadata memory metadata) private view returns (Serializer.Attribute[] memory) {
        Stage state_ = metadata.state_;
        Serializer.Attribute[] memory attributes = new Serializer.Attribute[](_getStateAttrsNum(state_));
        attributes[0] = Serializer.toStrAttribute("Origin", "Metaverse");
        attributes[1] = Serializer.toStrAttribute("Type", Serializer.toTypeStr(state_));
        if (uint(Stage.MINE) <= uint(state_)) {
            attributes[2] = Serializer.toStrAttribute("Stage", Serializer.toStageStr(state_));
            attributes[3] = Serializer.toStrAttribute("Identification", "Natural");
            attributes[4] = Serializer.toAttribute(
                "Carat",
                Serializer.toDecimalStr(_getPoints(metadata, metadata.state_)),
                ""
            );
            attributes[5] = Serializer.toMaxValueAttribute(
                "Mined",
                Strings.toString(metadata.rough.id),
                Strings.toString(_mineCounter),
                "number"
            );
            // TODO: validate "Rough xxx" name convention.
            bool wasProcessed = uint(state_) > uint(Stage.MINE);
            attributes[6] = Serializer.toStrAttribute(wasProcessed ? "Rough Color" : "Color", "Cape");
            attributes[7] = Serializer.toStrAttribute(
                wasProcessed ? "Rough Shape" : "Shape",
                Serializer.toRoughShapeStr(metadata.rough.shape)
            );
        }
        Certificate memory certificate = metadata.certificate;
        if (uint(Stage.CUT) <= uint(state_)) {
            attributes[8] = Serializer.toAttribute(
                "Rough Carat",
                Serializer.toDecimalStr(_getPoints(metadata, Stage.MINE)),
                ""
            );
            attributes[9] = Serializer.toStrAttribute(
                "Color",
                Serializer.toColorStr(certificate.color, certificate.toColor)
            );
            attributes[10] = Serializer.toStrAttribute("Cut", Serializer.toGradeStr(certificate.cut));
            attributes[11] = Serializer.toStrAttribute(
                "Fluorescence",
                Serializer.toFluorescenceStr(certificate.fluorescence)
            );
            attributes[12] = Serializer.toStrAttribute(
                "Measurements",
                Serializer.toMeasurementsStr(
                    certificate.shape,
                    certificate.length,
                    certificate.width,
                    certificate.depth
                )
            );
            attributes[13] = Serializer.toStrAttribute("Shape", Serializer.toShapeStr(certificate.shape));
            // TODO: validate that OpenSea works with 2 attributes named "Cut" or change the name
            attributes[14] = Serializer.toMaxValueAttribute(
                "Cut",
                Strings.toString(metadata.cut.id),
                Strings.toString(_cutCounter),
                "number"
            );
        }
        if (uint(Stage.POLISH) <= uint(state_)) {
            // TODO: change "Cut Carat" name to professional term
            attributes[15] = Serializer.toAttribute(
                "Cut Carat",
                Serializer.toDecimalStr(_getPoints(metadata, Stage.CUT)),
                ""
            );
            attributes[16] = Serializer.toStrAttribute("Clarity", Serializer.toClarityStr(certificate.clarity));
            attributes[17] = Serializer.toStrAttribute("Polish", Serializer.toGradeStr(certificate.polish));
            attributes[18] = Serializer.toStrAttribute("Symmetry", Serializer.toGradeStr(certificate.symmetry));
            attributes[19] = Serializer.toMaxValueAttribute(
                "Polished",
                Strings.toString(metadata.polished.id),
                Strings.toString(_polishedCounter),
                "number"
            );
        }
        if (uint(Stage.DAWN) <= uint(state_)) {
            attributes[20] = Serializer.toStrAttribute("Laboratory", "GIA");
            attributes[21] = Serializer.toAttribute("Report Date", Strings.toString(certificate.date), "date");
            attributes[22] = Serializer.toAttribute("Report Number", Strings.toString(certificate.number), "");
            attributes[23] = Serializer.toMaxValueAttribute(
                "Physical",
                Strings.toString(metadata.reborn.id),
                Strings.toString(_rebornCounter),
                "number"
            );
        }
        return attributes;
    }

    function _getStateAttrsNum(Stage state_) private pure returns (uint) {
        if (state_ == Stage.KEY) return 2;
        if (state_ == Stage.MINE) return 8;
        if (state_ == Stage.CUT) return 15;
        if (state_ == Stage.POLISH) return 20;
        if (state_ == Stage.DAWN) return 24;
        revert("Attributes number");
    }

    function _getPoints(Metadata memory metadata, Stage state_) private pure returns (uint) {
        assert(metadata.certificate.points > 0);
        if (state_ == Stage.MINE) {
            assert(metadata.rough.extraPoints > 0);
            return metadata.certificate.points + metadata.rough.extraPoints;
        } else if (state_ == Stage.CUT) {
            assert(metadata.cut.extraPoints > 0);
            return metadata.certificate.points + metadata.cut.extraPoints;
        } else if (state_ == Stage.POLISH || state_ == Stage.DAWN) return metadata.certificate.points;
        revert("Points");
    }

    function _getResourceName(Metadata memory metadata) private pure returns (string memory) {
        if (metadata.state_ == Stage.KEY || metadata.state_ == Stage.DAWN) return "resource";
        else if (metadata.state_ == Stage.MINE) {
            if (metadata.rough.shape == RoughShape.MAKEABLE_1) return "makeable1";
            if (metadata.rough.shape == RoughShape.MAKEABLE_2) return "makeable2";
        } else if (metadata.certificate.shape == Shape.PEAR) return "pear";
        else if (metadata.certificate.shape == Shape.ROUND) return "round";
        else if (metadata.certificate.shape == Shape.OVAL) return "oval";
        else if (metadata.certificate.shape == Shape.CUSHION) return "cushion";
        revert();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControlEnumerable.sol";
import "./AccessControl.sol";
import "../utils/structs/EnumerableSet.sol";

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view virtual override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {_grantRole} to track enumerable memberships
     */
    function _grantRole(bytes32 role, address account) internal virtual override {
        super._grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {_revokeRole} to track enumerable memberships
     */
    function _revokeRole(bytes32 role, address account) internal virtual override {
        super._revokeRole(role, account);
        _roleMembers[role].remove(account);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Base64.sol)

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
pragma solidity ^0.8.15;

import "../objects/Mine.sol";
import "../objects/System.sol";

interface IDiamondDawnMine {
    event Forge(uint tokenId);
    event Mine(uint tokenId);
    event Cut(uint tokenId);
    event Polish(uint tokenId);
    event Ship(uint tokenId, uint16 physicalId, uint32 number);
    event Dawn(uint tokenId);

    function initialize(uint16 maxDiamond) external;

    function forge(uint tokenId) external;

    function mine(uint tokenId) external;

    function cut(uint tokenId) external;

    function polish(uint tokenId) external;

    function ship(uint tokenId) external;

    function dawn(uint tokenId) external;

    function lockMine() external;

    function getMetadata(uint tokenId) external view returns (string memory);

    function isReady(Stage stage) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../objects/Diamond.sol";
import "../objects/System.sol";

interface IDiamondDawnMineAdmin {
    function eruption(Certificate[] calldata diamonds) external;

    function lostShipment(uint tokenId, Certificate calldata diamond) external;

    function setManifest(Stage stage_, string calldata manifest) external;

    function setBaseTokenURI(string calldata baseTokenURI) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

enum Shape {
    NO_SHAPE,
    PEAR,
    ROUND,
    OVAL,
    CUSHION
}

enum Grade {
    NO_GRADE,
    GOOD,
    VERY_GOOD,
    EXCELLENT
}

enum Clarity {
    NO_CLARITY,
    VS2,
    VS1,
    VVS2,
    VVS1,
    IF,
    FL
}

enum Fluorescence {
    NO_FLUORESCENCE,
    FAINT,
    NONE
}

enum Color {
    NO_COLOR,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z
}

struct Certificate {
    uint32 number; // TODO: check that all certificates are smaller than 4,294,967,296
    uint32 date;
    uint16 length;
    uint16 width;
    uint16 depth;
    uint8 points;
    Clarity clarity;
    Color color;
    Color toColor;
    Grade cut;
    Grade symmetry;
    Grade polish;
    Fluorescence fluorescence;
    Shape shape;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./Diamond.sol";
import "./System.sol";

enum RoughShape {
    NO_SHAPE,
    MAKEABLE_1,
    MAKEABLE_2
}

struct RoughMetadata {
    uint16 id;
    uint8 extraPoints;
    RoughShape shape;
}

struct CutMetadata {
    uint16 id;
    uint8 extraPoints;
}

struct PolishedMetadata {
    uint16 id;
}

struct RebornMetadata {
    uint16 id;
}

struct Metadata {
    Stage state_;
    RoughMetadata rough;
    CutMetadata cut;
    PolishedMetadata polished;
    RebornMetadata reborn;
    Certificate certificate;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

function getRandomInRange(
    uint min,
    uint max,
    uint nonce
) view returns (uint) {
    uint rand = _rand(nonce);
    uint range = max - min + 1;
    return (rand % range) + min;
}

function _rand(uint nonce) view returns (uint) {
    return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, tx.origin, nonce)));
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../objects/Diamond.sol";
import "../objects/Mine.sol";

library Serializer {
    struct NFTMetadata {
        string name;
        string image;
        string animationUrl;
        Attribute[] attributes;
    }

    struct Attribute {
        string traitType;
        string value;
        string maxValue;
        string displayType;
        bool isString;
    }

    function toStrAttribute(string memory traitType, string memory value) public pure returns (Attribute memory) {
        return Attribute({traitType: traitType, value: value, maxValue: "", displayType: "", isString: true});
    }

    function toAttribute(
        string memory traitType,
        string memory value,
        string memory displayType
    ) public pure returns (Attribute memory) {
        return Attribute({traitType: traitType, value: value, maxValue: "", displayType: displayType, isString: false});
    }

    function toMaxValueAttribute(
        string memory traitType,
        string memory value,
        string memory maxValue,
        string memory displayType
    ) public pure returns (Attribute memory) {
        return
            Attribute({
                traitType: traitType,
                value: value,
                maxValue: maxValue,
                displayType: displayType,
                isString: false
            });
    }

    function serialize(NFTMetadata memory metadata) public pure returns (string memory) {
        bytes memory bytes_;
        bytes_ = abi.encodePacked(bytes_, _openObject());
        bytes_ = abi.encodePacked(bytes_, _pushAttr("name", metadata.name, true, false));
        bytes_ = abi.encodePacked(bytes_, _pushAttr("image", metadata.image, true, false));
        bytes_ = abi.encodePacked(bytes_, _pushAttr("animation_url", metadata.animationUrl, true, false));
        bytes_ = abi.encodePacked(bytes_, _pushAttr("attributes", _serializeAttrs(metadata.attributes), false, true));
        bytes_ = abi.encodePacked(bytes_, _closeObject());
        return string(bytes_);
    }

    function _serializeAttrs(Attribute[] memory attributes) public pure returns (string memory) {
        bytes memory bytes_;
        bytes_ = abi.encodePacked(bytes_, _openArray());
        for (uint i = 0; i < attributes.length; i++) {
            Attribute memory attribute = attributes[i];
            bytes_ = abi.encodePacked(bytes_, _pushArray(_serializeAttr(attribute), i == attributes.length - 1));
        }
        bytes_ = abi.encodePacked(bytes_, _closeArray());
        return string(bytes_);
    }

    function _serializeAttr(Attribute memory attribute) public pure returns (string memory) {
        bytes memory bytes_;
        bytes_ = abi.encodePacked(bytes_, _openObject());
        if (bytes(attribute.displayType).length > 0) {
            bytes_ = abi.encodePacked(bytes_, _pushAttr("display_type", attribute.displayType, true, false));
        }
        if (bytes(attribute.maxValue).length > 0) {
            bytes_ = abi.encodePacked(bytes_, _pushAttr("max_value", attribute.maxValue, attribute.isString, false));
        }
        bytes_ = abi.encodePacked(bytes_, _pushAttr("trait_type", attribute.traitType, true, false));
        bytes_ = abi.encodePacked(bytes_, _pushAttr("value", attribute.value, attribute.isString, true));
        bytes_ = abi.encodePacked(bytes_, _closeObject());
        return string(bytes_);
    }

    // Objects
    function _openObject() public pure returns (bytes memory) {
        return abi.encodePacked("{");
    }

    function _closeObject() public pure returns (bytes memory) {
        return abi.encodePacked("}");
    }

    function _pushAttr(
        string memory key,
        string memory value,
        bool isStr,
        bool isLast
    ) public pure returns (bytes memory) {
        if (isStr) value = string.concat('"', value, '"');
        return abi.encodePacked('"', key, '": ', value, isLast ? "" : ",");
    }

    // Arrays
    function _openArray() public pure returns (bytes memory) {
        return abi.encodePacked("[");
    }

    function _closeArray() public pure returns (bytes memory) {
        return abi.encodePacked("]");
    }

    function _pushArray(string memory value, bool isLast) public pure returns (bytes memory) {
        return abi.encodePacked(value, isLast ? "" : ",");
    }

    function toColorStr(Color color, Color toColor) public pure returns (string memory) {
        return
            toColor == Color.NO_COLOR
                ? _toColorStr(color)
                : string.concat(_toColorStr(color), "-", _toColorStr(toColor));
    }

    function toGradeStr(Grade grade) public pure returns (string memory) {
        if (grade == Grade.GOOD) return "Good";
        if (grade == Grade.VERY_GOOD) return "Very Good";
        if (grade == Grade.EXCELLENT) return "Excellent";
        revert();
    }

    function toClarityStr(Clarity clarity) public pure returns (string memory) {
        if (clarity == Clarity.VS2) return "VS2";
        if (clarity == Clarity.VS1) return "VS1";
        if (clarity == Clarity.VVS2) return "VVS2";
        if (clarity == Clarity.VVS1) return "VVS1";
        if (clarity == Clarity.IF) return "IF";
        if (clarity == Clarity.FL) return "FL";
        revert();
    }

    function toFluorescenceStr(Fluorescence fluorescence) public pure returns (string memory) {
        if (fluorescence == Fluorescence.FAINT) return "Faint";
        if (fluorescence == Fluorescence.NONE) return "None";
        revert();
    }

    function toMeasurementsStr(
        Shape shape,
        uint16 length,
        uint16 width,
        uint16 depth
    ) public pure returns (string memory) {
        string memory separator = shape == Shape.ROUND ? " - " : " x ";
        return string.concat(toDecimalStr(length), separator, toDecimalStr(width), " x ", toDecimalStr(depth));
    }

    function toShapeStr(Shape shape) public pure returns (string memory) {
        if (shape == Shape.PEAR) return "Pear";
        if (shape == Shape.ROUND) return "Round";
        if (shape == Shape.OVAL) return "Oval";
        if (shape == Shape.CUSHION) return "Cushion";
        revert();
    }

    function toRoughShapeStr(RoughShape shape) public pure returns (string memory) {
        if (shape == RoughShape.MAKEABLE_1) return "Makeable 1";
        if (shape == RoughShape.MAKEABLE_2) return "Makeable 2";
        revert();
    }

    function getName(Metadata memory metadata, uint tokenId) public pure returns (string memory) {
        if (metadata.state_ == Stage.KEY) return string.concat("Mine Key #", Strings.toString(tokenId));
        if (metadata.state_ == Stage.MINE) return string.concat("Rough Stone #", Strings.toString(metadata.rough.id));
        if (metadata.state_ == Stage.CUT) return string.concat("Formation #", Strings.toString(metadata.cut.id));
        if (metadata.state_ == Stage.POLISH) return string.concat("Diamond #", Strings.toString(metadata.polished.id));
        if (metadata.state_ == Stage.DAWN) return string.concat("Dawn #", Strings.toString(metadata.reborn.id));
        revert();
    }

    function toDecimalStr(uint percentage) public pure returns (string memory) {
        uint remainder = percentage % 100;
        string memory quotient = Strings.toString(percentage / 100);
        if (remainder < 10) return string.concat(quotient, ".0", Strings.toString(remainder));
        return string.concat(quotient, ".", Strings.toString(remainder));
    }

    function toTypeStr(Stage state_) public pure returns (string memory) {
        if (state_ == Stage.KEY) return "Key";
        if (state_ == Stage.MINE || state_ == Stage.CUT || state_ == Stage.POLISH) return "Diamond";
        if (state_ == Stage.DAWN) return "Certificate";
        revert();
    }

    function toStageStr(Stage state_) public pure returns (string memory) {
        if (state_ == Stage.MINE) return "Rough";
        if (state_ == Stage.CUT) return "Cut";
        if (state_ == Stage.POLISH) return "Polished";
        if (state_ == Stage.DAWN) return "Reborn";
        revert();
    }

    function _toColorStr(Color color) public pure returns (string memory) {
        if (color == Color.M) return "M";
        if (color == Color.N) return "N";
        if (color == Color.O) return "O";
        if (color == Color.P) return "P";
        if (color == Color.Q) return "Q";
        if (color == Color.R) return "R";
        if (color == Color.S) return "S";
        if (color == Color.T) return "T";
        if (color == Color.U) return "U";
        if (color == Color.V) return "V";
        if (color == Color.W) return "W";
        if (color == Color.X) return "X";
        if (color == Color.Y) return "Y";
        if (color == Color.Z) return "Z";
        revert();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

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
        mapping(bytes32 => uint256) _indexes;
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

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

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
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

enum Stage {
    NO_STAGE,
    KEY,
    MINE,
    CUT,
    POLISH,
    DAWN,
    COMPLETED
}