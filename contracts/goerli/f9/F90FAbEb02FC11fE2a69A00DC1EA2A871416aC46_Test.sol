// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool _approved) external;

    function getApproved(uint256 tokenId) external view returns (address operator);

    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract ERC721Simple is IERC721 {
    string private _name;

    string private _symbol;

    uint256 private _currentIndex;

    mapping(uint256 => address) private _owners;

    mapping(address => uint256) private _balances;

    mapping(uint256 => address) private _tokenApprovals;

    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {}

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(msg.sender, operator, approved);
    }


    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        data = '';
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function _batchMint(address to, uint256 amount) internal virtual {
        for (uint i; i < amount;) {
             uint256 tokenId = _currentIndex++;
            unchecked {
                _balances[to]++;
                ++i;
            }
            _owners[tokenId] = to;
            emit Transfer(address(0), to, tokenId);
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        delete _tokenApprovals[tokenId];

        unchecked {
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract MetaDataGenerate {
    string internal constant BASE64_TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    string[] private color = [        
        '#FFFFFF','#DDDDDD','#AAAAAA','#888888','#666666','#444444','#000000',
        '#FFB7DD','#FF88C2','#FF44AA','#FF0088','#C10066','#A20055','#8C0044',
        '#FFCCCC','#FF8888','#FF3333','#FF0000','#CC0000','#AA0000','#880000',
        '#FFC8B4','#FFA488','#FF7744','#FF5511','#E63F00','#C63300','#A42D00',
        '#FFDDAA','#FFBB66','#FFAA33','#FF8800','#EE7700','#CC6600','#BB5500',
        '#FFEE99','#FFDD55','#FFCC22','#FFBB00','#DDAA00','#AA7700','#886600',
        '#FFFFBB','#FFFF77','#FFFF33','#FFFF00','#EEEE00','#BBBB00','#888800',
        '#EEFFBB','#DDFF77','#CCFF33','#BBFF00','#99DD00','#88AA00','#668800',
        '#CCFF99','#BBFF66','#99FF33','#77FF00','#66DD00','#55AA00','#227700',
        '#99FF99','#66FF66','#33FF33','#00FF00','#00DD00','#00AA00','#008800',
        '#BBFFEE','#77FFCC','#33FFAA','#00FF99','#00DD77','#00AA55','#008844',
        '#AAFFEE','#77FFEE','#33FFDD','#00FFCC','#00DDAA','#00AA88','#008866',
        '#99FFFF','#66FFFF','#33FFFF','#00FFFF','#00DDDD','#00AAAA','#008888',
        '#CCEEFF','#77DDFF','#33CCFF','#00BBFF','#009FCC','#0088A8','#007799',
        '#CCDDFF','#99BBFF','#5599FF','#0066FF','#0044BB','#003C9D','#003377',
        '#CCCCFF','#9999FF','#5555FF','#0000FF','#0000CC','#0000AA','#000088',
        '#CCBBFF','#9F88FF','#7744FF','#5500FF','#4400CC','#2200AA','#220088',
        '#D1BBFF','#B088FF','#9955FF','#7700FF','#5500DD','#4400B3','#3A0088',
        '#E8CCFF','#D28EFF','#B94FFF','#9900FF','#7700BB','#66009D','#550088',
        '#F0BBFF','#E38EFF','#E93EFF','#CC00FF','#A500CC','#7A0099','#660077',
        '#FFB3FF','#FF77FF','#FF3EFF','#FF00FF','#CC00CC','#990099','#770077'];

    string private SVG_SIMPLE_1 = '<?xml version="1.0" standalone="no"?>';
    string private SVG_SIMPLE_2 = '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240">';
    string private SVG_SIMPLE_3 = '<path fill=';
    string private randomColor;
    string private SVG_SIMPLE_4 = ' stroke="#000" stroke-width=';
    string private widthSize;
    string private SVG_SIMPLE_5 = ' d="M121,229Q89,180 47,145Q9,112 9,65Q9,9 68,9Q96,9 121,33Q145,9 173,9Q233,9 233,65Q233,112 194,145Q152,180 121,229"/> </svg>';

    function random() internal view returns (string memory) {
        uint index = (block.timestamp % 147);
        return color[index]; 
    }

    function SVG_Final() public view returns (string memory) {
        uint size = (block.timestamp % 10) + 3;
        string memory _size = string.concat('"', uint2str(size), '"');
        return 
            string.concat(
                SVG_SIMPLE_1, 
                SVG_SIMPLE_2, 
                SVG_SIMPLE_3,
                random(),
                SVG_SIMPLE_4,
                _size,
                SVG_SIMPLE_5
            );
    }

    string public SVG_SIMPLE = string.concat(
        '<?xml version="1.0" standalone="no"?>',
        '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240">',
        '<path fill="#FF6159" stroke="#000" stroke-width="4" d="M121,229Q89,180 47,145Q9,112 9,65Q9,9 68,9Q96,9 121,33Q145,9 173,9Q233,9 233,65Q233,112 194,145Q152,180 121,229"/> </svg>'
    );
    
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            ++len;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function encodeBase64(bytes memory data)
        internal
        pure
        returns (string memory)
    {
        if (data.length == 0) return "";

        string memory table = BASE64_TABLE;

        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        string memory result = new string(encodedLen + 32);

        assembly {
            mstore(result, encodedLen)

            let tablePtr := add(table, 1)

            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            let resultPtr := add(result, 32)

            for {

            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                let input := mload(dataPtr)

                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(input, 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
            }

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

    function formatTokenURI(
        string memory _name,
        string memory _description,
        string memory _svg
    ) internal pure returns (string memory) {
        return
            string.concat(
                "data:application/json;base64,",
                encodeBase64(
                    bytes(
                        string.concat(
                            '{"name":"',
                            _name,
                            '","description":"',
                            _description,
                            '","image":"',
                            "data:image/svg+xml;base64,",
                            encodeBase64(bytes(_svg)),
                            '"}'
                        )
                    )
                )
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721Simple.sol";
import "./MetaDataGenerate.sol";

contract Test is ERC721Simple, MetaDataGenerate {
    constructor () ERC721Simple("All Metadata On-Chain Testing", "AMOC-Testing") {
        _batchMint(msg.sender, 1);
    }
    
    function tokenURI(uint tokenId) public view override returns (string memory) {
        return formatTokenURI("The basic of the universe", "The basic of the universe", SVG_Final());
    }
}