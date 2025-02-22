// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "./Base64.sol";
import "./WordTable.sol";
import "./ColorMaker.sol";

error MintPriceNotPaid();
error MaxSupply();
error MaxAddressMints();
error NonExistentTokenURI();
error WithdrawTransfer();

contract YourStory is WordTable, ColorMaker, ERC721Royalty {
    using Strings for uint256;
    uint256 public currentTokenId;
    uint256 public constant TOTAL_SUPPLY = 10_000;
    uint256 public constant BASE_MINT_PRICE = 0.00001 ether;
    uint256 public constant MAX_MINTS = 16;

    mapping(uint256 => address) private tokenIdToMintSeed;
    mapping(address => uint256) private mintCount;

    constructor(address royaltyReciever, uint96 feeNumerator)
        ERC721("Your Story", "STORY")
    {
        _setDefaultRoyalty(royaltyReciever, feeNumerator);
    }

    function contractURI() public view returns (string memory) {
        return
            '{"name": "Your Story", "description": "An on-chain story generated from your address","image": "https://alfred-words-proto.vercel.app/image.png", "external_link": "https://alfred-words-proto.vercel.app/", "seller_fee_basis_points": 1000, "fee_recipient": royaltyReciever }';
    }

    function mintTo(address recipient) public payable returns (uint256) {
        if (msg.value != (BASE_MINT_PRICE * (currentTokenId + 1))) {
            revert MintPriceNotPaid();
        }
        uint256 newTokenId = ++currentTokenId;
        if (newTokenId > TOTAL_SUPPLY) {
            revert MaxSupply();
        }

        // check minters individual max
        uint256 newMintCount = ++mintCount[msg.sender];
        if (newMintCount > MAX_MINTS) {
            revert MaxAddressMints();
        }
        mintCount[msg.sender] = newMintCount;

        // set tokenId to address seed used to generate;
        // getAltSeed(msg.sender, mintCount);
        tokenIdToMintSeed[newTokenId] = msg.sender;

        _safeMint(recipient, newTokenId);
        return newTokenId;
    }

    function minted() public view returns (uint256) {
        return mintCount[msg.sender];
    }

    function seed(uint256 tokenId) public view returns (address) {
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenURI();
        }
        return tokenIdToMintSeed[tokenId];
    }

    function getSentance(uint256 tokenId) public view returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenURI();
        }

        address mintSeed = tokenIdToMintSeed[tokenId];
        if (mintSeed == address(0)) {
            revert NonExistentTokenURI();
        }

        string memory output;
        string[40] memory sentance = addressToSentanceViaMapping(mintSeed);

        output = string(
            abi.encodePacked(
                sentance[0],
                " ",
                sentance[1],
                " ",
                sentance[2],
                " ",
                sentance[3],
                " ",
                sentance[4],
                " ",
                sentance[5],
                " ",
                sentance[6],
                " ",
                sentance[7],
                " ",
                sentance[8]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                " ",
                sentance[9],
                " ",
                sentance[10],
                " ",
                sentance[11],
                " ",
                sentance[12],
                " ",
                sentance[13],
                " ",
                sentance[14],
                " ",
                sentance[15],
                " ",
                sentance[16]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                " ",
                sentance[17],
                " ",
                sentance[18],
                " ",
                sentance[19],
                " ",
                sentance[20],
                " ",
                sentance[21],
                " ",
                sentance[22],
                " ",
                sentance[23],
                " ",
                sentance[24]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                " ",
                sentance[25],
                " ",
                sentance[26],
                " ",
                sentance[27],
                " ",
                sentance[28],
                " ",
                sentance[29],
                " ",
                sentance[30],
                " ",
                sentance[31],
                " ",
                sentance[32]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                " ",
                sentance[33],
                " ",
                sentance[34],
                " ",
                sentance[35],
                " ",
                sentance[36],
                " ",
                sentance[37],
                " ",
                sentance[38],
                " ",
                sentance[39]
            )
        );
        return output;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenURI();
        }

        address mintSeed = tokenIdToMintSeed[tokenId];
        if (mintSeed == address(0)) {
            revert NonExistentTokenURI();
        }
        string[2] memory colors = addressToColorStrings(mintSeed);
        string[40] memory sentance = addressToSentanceViaMapping(mintSeed);

        string[34] memory parts;

        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base {fill: #';
        parts[1] = colors[1]; // colors 1 is font, colors 0 is background
        parts[
            2
        ] = "; font-family: American Typewriter, Georgia, serif; font-size: 15px; }</style>";
        parts[3] = '<rect width="100%" height="100%" fill="#';
        parts[4] = colors[0];
        parts[5] = '"/><text x="10" y="20" class="base">';
        parts[6] = string(
            abi.encodePacked(sentance[0], " ", sentance[1], " ", sentance[2])
        );
        parts[7] = '</text><text x="10" y="40" class="base">';
        parts[8] = string(
            abi.encodePacked(sentance[3], " ", sentance[4], " ", sentance[5])
        );
        parts[9] = '</text><text x="10" y="60" class="base">';
        parts[10] = string(
            abi.encodePacked(sentance[6], " ", sentance[7], " ", sentance[8])
        );
        parts[11] = '</text><text x="10" y="80" class="base">';
        parts[12] = string(
            abi.encodePacked(sentance[9], " ", sentance[10], " ", sentance[11])
        );
        parts[13] = '</text><text x="10" y="100" class="base">';
        parts[14] = string(
            abi.encodePacked(sentance[12], " ", sentance[13], " ", sentance[14])
        );
        parts[15] = '</text><text x="10" y="120" class="base">';
        parts[16] = string(
            abi.encodePacked(sentance[15], " ", sentance[16], " ", sentance[17])
        );
        parts[17] = '</text><text x="10" y="140" class="base">';
        parts[18] = string(
            abi.encodePacked(sentance[18], " ", sentance[19], " ", sentance[20])
        );
        parts[19] = '</text><text x="10" y="160" class="base">';
        parts[20] = string(
            abi.encodePacked(sentance[21], " ", sentance[22], " ", sentance[23])
        );
        parts[21] = '</text><text x="10" y="180" class="base">';
        parts[22] = string(
            abi.encodePacked(sentance[24], " ", sentance[25], " ", sentance[26])
        );
        parts[23] = '</text><text x="10" y="200" class="base">';
        parts[24] = string(
            abi.encodePacked(sentance[27], " ", sentance[28], " ", sentance[29])
        );
        parts[25] = '</text><text x="10" y="220" class="base">';
        parts[26] = string(
            abi.encodePacked(sentance[30], " ", sentance[31], " ", sentance[32])
        );
        parts[27] = '</text><text x="10" y="240" class="base">';
        parts[28] = string(
            abi.encodePacked(sentance[33], " ", sentance[34], " ", sentance[35])
        );
        parts[29] = '</text><text x="10" y="260" class="base">';
        parts[30] = string(
            abi.encodePacked(sentance[36], " ", sentance[37], " ", sentance[38])
        );
        parts[31] = '</text><text x="10" y="280" class="base">';
        parts[32] = sentance[39];
        parts[33] = "</text></svg>";

        string memory output = string(
            abi.encodePacked(
                parts[0],
                parts[1],
                parts[2],
                parts[3],
                parts[4],
                parts[5],
                parts[6],
                parts[7],
                parts[8]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                parts[9],
                parts[10],
                parts[11],
                parts[12],
                parts[13],
                parts[14],
                parts[15],
                parts[16]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                parts[17],
                parts[18],
                parts[19],
                parts[20],
                parts[21],
                parts[22],
                parts[23],
                parts[24]
            )
        );
        output = string(
            abi.encodePacked(
                output,
                parts[25],
                parts[26],
                parts[27],
                parts[28],
                parts[29],
                parts[30],
                parts[31],
                parts[32]
            )
        );
        output = string(abi.encodePacked(output, parts[33]));

        string memory attributes = '"attributes": [';

        for (uint256 i = 0; i < 22; i++) {
            attributes = string(
                abi.encodePacked(
                    attributes,
                    '{"trait_type": "',
                    toString(i),
                    '", "value": "',
                    sentance[i],
                    '" }, '
                )
            );
        }
        // 22 starts with "
        // 23 ends with "
        // 31 starts with "
        // 34 ends with "

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "22", ',
                '"value": ',
                sentance[22],
                '" }, '
            )
        );

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "23", ',
                '"value": "',
                sentance[23],
                " }, "
            )
        );

        for (uint256 i = 24; i < 31; i++) {
            attributes = string(
                abi.encodePacked(
                    attributes,
                    '{"trait_type": "',
                    toString(i),
                    '", "value": "',
                    sentance[i],
                    '" }, '
                )
            );
        }

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "31", ',
                '"value": ',
                sentance[31],
                '" }, '
            )
        );

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "32',
                '", "value": "',
                sentance[32],
                '" }, '
            )
        );

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "33',
                '", "value": "',
                sentance[33],
                '" }, '
            )
        );

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "34", ',
                '"value": "',
                sentance[34],
                " }, "
            )
        );

        for (uint256 i = 35; i < 40; i++) {
            attributes = string(
                abi.encodePacked(
                    attributes,
                    '{"trait_type": "',
                    toString(i),
                    '", "value": "',
                    sentance[i],
                    '" }, '
                )
            );
        }

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "Background Color", "value": "#',
                colors[0],
                '"}, ',
                '{"trait_type": "Font Color", "value": "#',
                colors[1],
                '"}]'
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Your Story #',
                        toString(tokenId),
                        '", "description": "A generative story from your address',
                        '", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '",',
                        attributes,
                        "}"
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/ERC721.sol)

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
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
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
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
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
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
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
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
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
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
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
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
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

        _afterTokenTransfer(address(0), to, tokenId);
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
        delete _tokenApprovals[tokenId];

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
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
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
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

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/ERC721Royalty.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../../common/ERC2981.sol";
import "../../../utils/introspection/ERC165.sol";

/**
 * @dev Extension of ERC721 with the ERC2981 NFT Royalty Standard, a standardized way to retrieve royalty payment
 * information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC721Royalty is ERC2981, ERC721 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally clears the royalty information for the token.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
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

/// SPDX-License-Identifier: MIT
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

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
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "stringutils/strings.sol";

error ArrayIdxOutOfBounds();
error WordIdxOutofBounds();

contract WordTable {
    using strings for *;

    mapping(string => uint8) charToHex;

    constructor() {
        charToHex["0"] = 0;
        charToHex["1"] = 1;
        charToHex["2"] = 2;
        charToHex["3"] = 3;
        charToHex["4"] = 4;
        charToHex["5"] = 5;
        charToHex["6"] = 6;
        charToHex["7"] = 7;
        charToHex["8"] = 8;
        charToHex["9"] = 9;
        charToHex["a"] = 10;
        charToHex["b"] = 11;
        charToHex["c"] = 12;
        charToHex["d"] = 13;
        charToHex["e"] = 14;
        charToHex["f"] = 15;
    }

    string[40][16] public WORDS = [
        [
            "For a few",
            "moons",
            "you burn",
            "hackers,",
            "squeezing them",
            "from",
            "quaint",
            "sawdust,",
            "while Leonhard,",
            "frazzled",
            "through",
            "the tiniest",
            "enigmas and",
            "pigeons,",
            "yanks",
            "a monster.",
            "You whip",
            "the infinite",
            "minstrel",
            "lurking",
            "about the",
            "arena.",
            '"I dried',
            'the truffles,"',
            "barks",
            "the magician,",
            "as she crawls",
            "with",
            "the cheeks.",
            "Relieved,",
            "you beg,",
            '"We need to',
            "faint",
            "over",
            'the brass."',
            "You shave",
            "the retinas.",
            "Monday's",
            "yacht",
            "trolls."
        ],
        [
            "For several",
            "months",
            "you shun",
            "giants,",
            "besprinkling them",
            "about",
            "half-deserted",
            "pliers,",
            "while Rudolf,",
            "tangled",
            "in",
            "greedy",
            "dollars and",
            "flags,",
            "weds",
            "a grenade.",
            "You shoulder",
            "the hairy",
            "feather",
            "wandering",
            "under the",
            "ziggurat.",
            '"I dropped',
            'the sinews,"',
            "jabbers",
            "the actuary,",
            "as he marches",
            "within",
            "the heaps.",
            "Bewildered,",
            "you puff,",
            '"We could',
            "smile",
            "in",
            'the ghost."',
            "You unravel",
            "the drool.",
            "June's",
            "gold",
            "looms."
        ],
        [
            "For two",
            "decades",
            "you weave",
            "threads,",
            "pulverizing them",
            "under",
            "curious",
            "dawn,",
            "while Aleister,",
            "exalted",
            "under",
            "canned",
            "pixels and",
            "scree,",
            "taps",
            "a cacodemon.",
            "You hate",
            "the painful",
            "pistol",
            "wriggling",
            "through the",
            "pueblo.",
            '"I ate',
            'the mangos,"',
            "bleats",
            "the infant,",
            "as she galumphs",
            "out of",
            "the zombies.",
            "Gobsmacked,",
            "you chortle,",
            '"We have to',
            "drill",
            "outside",
            'the hunger."',
            "You blunt",
            "the elbows.",
            "Yesterday's",
            "ink",
            "chokes."
        ],
        [
            "For three",
            "eternities",
            "you abash",
            "cloths,",
            "dragooning them",
            "against",
            "heavenly",
            "stones,",
            "while Pierre,",
            "crippled",
            "inside",
            "fearsome",
            "opium and",
            "maggots,",
            "fondles",
            "a god.",
            "You dread",
            "the wounded",
            "starlet",
            "swinging",
            "off of the",
            "crag.",
            '"I fried',
            'the garlic,"',
            "roars",
            "the officer,",
            "as he pivots",
            "through",
            "the fiends.",
            "Amused,",
            "you burble,",
            string(abi.encodePacked('"We shouldn', "'t")), // "We shouldn't
            "swoon",
            "through",
            'the chaff."',
            "You beam",
            "the orchids.",
            "March's",
            "news",
            "coagulates."
        ],
        [
            "For four",
            "epochs",
            "you skewer",
            "flowers,",
            "shrouding them",
            "inside",
            "immortal",
            "sriracha,",
            "while Zeno,",
            "intrigued",
            "with",
            "proper",
            "ledges and",
            "orgies",
            "licks",
            "a juke-box.",
            "You plow",
            "the next",
            "weed",
            "ricocheting",
            "over the",
            "bog.",
            '"I peeled',
            'the geraniums,"',
            "sings",
            "the firefighter,",
            "as she plunges",
            "by",
            "the visitors.",
            "Aroused,",
            "you object,",
            '"We must',
            "sprint",
            "from",
            'the mink."',
            "You gobble",
            "the lions.",
            "Saturday's",
            "frolic",
            "blackens."
        ],
        [
            "For five",
            "years",
            "you bang",
            "eyes,",
            "melting them",
            "in",
            "dreary",
            "terrors,",
            "while Euclid,",
            "galvanized",
            "off",
            "psychedelic",
            "patterns and",
            "rainbows,",
            "summons",
            "a mountain.",
            "You kiss",
            "the scarlet",
            "insect",
            "inching",
            "opposite the",
            "arcade.",
            '"I broiled',
            'the brie,"',
            "bellows",
            "the scientist,",
            "as he charges",
            "beyond",
            "the branches.",
            "Nonplussed,",
            "you plead,",
            '"We should',
            "hurdle",
            "upon",
            'the night."',
            "You find",
            "the ewes.",
            "Next week's",
            "melee",
            "gropes."
        ],
        [
            "For six",
            "aeons",
            "you seize",
            "labials,",
            "whetting them",
            "off",
            "rosy-fingered",
            "stars,",
            "while Ada,",
            "chagrined",
            "about",
            "frosty",
            "iron and",
            "ciphers,",
            "reveals",
            "blood.",
            "You conjure",
            "the hazy",
            "barnacle",
            "sneaking",
            "past the",
            "stadium.",
            '"I puked up',
            'the dregs,"',
            "shrieks",
            "the soldier,",
            "as she shuffles",
            "off",
            "the matchsticks.",
            "Amazed,",
            "you sputter,",
            '"We might',
            "toil",
            "onto",
            'the podium."',
            "You blast",
            "the adults.",
            "Today's",
            "chore",
            "daunts."
        ],
        [
            "For seven",
            "suns",
            "you catch",
            "apes,",
            "chaining them",
            "within",
            "somnolent",
            "oysters,",
            "while Friedrich,",
            "drunk",
            "out of",
            "pure",
            "gutturals and",
            "loam,",
            "spits on",
            "a circuit.",
            "You steal",
            "the gnarled",
            "seagull",
            "creeping",
            "outside the",
            "yard.",
            '"I spanked',
            'the gristle,"',
            "yells",
            "the hoss,",
            "as he squirms",
            "into",
            "the brine.",
            "Flummoxed,",
            "you whine,",
            '"We can',
            "obsess",
            "about",
            'the scrilla."',
            "You gather",
            "the dilettantes.",
            "Tomorrow's",
            "angst",
            "knocks."
        ],
        [
            "For eight",
            "millennia",
            "you gnaw",
            "toddlers,",
            "nurturing them",
            "on",
            "subtle",
            "giggles,",
            "while Edgar,",
            "captivated",
            "beyond",
            "lifeless",
            "nouns and",
            "digests,",
            "defeats",
            "an anvil.",
            "You dump",
            "the rusty",
            "lover",
            "prancing",
            "on the",
            "tavern.",
            '"I sliced',
            'the slime,"',
            "hollers",
            "the judge,",
            "as she rambles",
            "from",
            "the lumps.",
            "Appalled,",
            "you blabber,",
            string(abi.encodePacked('"We won', "'t")), // "We won't
            "hallucinate",
            "out of",
            'the dead."',
            "You dodge",
            "the laity.",
            "May's",
            "rime",
            "fizzles."
        ],
        [
            "For nine",
            "days",
            "you bend",
            "oxen,",
            "spearing them",
            "with",
            "cheap",
            "fish-eggs,",
            "while Satoshi,",
            "consumed",
            "from",
            "oily",
            "hashes and",
            "fame,",
            "hides",
            "a ladder.",
            "You clasp",
            "the forgotten",
            "fang",
            "bumping",
            "above the",
            "glacier.",
            '"I smashed',
            'the eggs,"',
            "screams",
            "the bishop,",
            "as he maunders",
            "on",
            "the worms.",
            "Fascinated,",
            "you rant,",
            string(abi.encodePacked('"We ain', "'t gotta")), // "We ain't gotta
            "doze",
            "above",
            'the pulse."',
            "You spring",
            "the diphthongs.",
            "April's",
            "dongle",
            "snarls."
        ],
        [
            "For ten",
            "hours",
            "you slay",
            "ears,",
            "grasping them",
            "beyond",
            "tedious",
            "pincers,",
            "while Alan,",
            "buoyed",
            "into",
            "frenetic",
            "furnaces and",
            "chambers,",
            "denies",
            "a secret.",
            "You throw",
            "the howling",
            "myth",
            "tiptoeing",
            "amid the",
            "Albertina.",
            '"I rubbed',
            'the burgers,"',
            "shouts",
            "the mime,",
            "as she speeds",
            "over",
            "the bracken.",
            "Exhausted,",
            "you stammer,",
            string(abi.encodePacked('"We needn', "'t")), // "We needn't
            "fly",
            "across",
            'the vibe."',
            "You tidy",
            "the owls.",
            "Your",
            "blazer",
            "beckons."
        ],
        [
            "For eleven",
            "weeks",
            "you diffuse",
            "yokels,",
            "gorging them",
            "out of",
            "weary",
            "claws,",
            "while Zelda,",
            "withered",
            "by",
            "familiar",
            "queens and",
            "glaciers,",
            "revs",
            "a disaster.",
            "You ponder",
            "the nauseous",
            "spore",
            "sashaying",
            "around the",
            "forest.",
            '"I sucked',
            'the yuzu,"',
            "jeers",
            "the devil,",
            "as he shoots",
            "against",
            "the starlings.",
            "Disgusted,",
            "you rave,",
            string(abi.encodePacked('"We mustn', "'t")), // "We mustn't
            "drive",
            "behind",
            'the grizzlies."',
            "You buoy",
            "the punks.",
            "Sunday's",
            "plug",
            "lurches."
        ],
        [
            "For twelve",
            "minutes",
            "you check",
            "flames,",
            "pounding them",
            "over",
            "bulky",
            "guts,",
            "while Ludwig,",
            "ruined",
            "on",
            "mystical",
            "axioms and",
            "doubt,",
            "squeezes",
            "a nun.",
            "You strike",
            "the white",
            "stardust",
            "swaggering",
            "beyond the",
            "playa.",
            '"I basted',
            'the fat,"',
            "says",
            "the astrologer,",
            "as she drifts",
            "about",
            "the symbols.",
            "Frustrated,",
            "you counter,",
            string(abi.encodePacked('"We couldn', "'t")), // "We couldn't
            "swim",
            "against",
            'the sasquatch."',
            "You fix",
            "the stench.",
            "January's",
            "slag",
            "ogles."
        ],
        [
            "For thirteen",
            "fortnights",
            "you arch",
            "tigers,",
            "beating them",
            "into",
            "unsmelled",
            "jaws,",
            "while Kurt,",
            "embroiled",
            "against",
            "crumbling",
            "ice and",
            "magic,",
            "starves",
            "a sledge.",
            "You spoil",
            "the loathsome",
            "milkmaid",
            "zigzagging",
            "far from the",
            "porch.",
            '"I shucked',
            'the coconuts,"',
            "blurts",
            "the phrenologist,",
            "as he glides",
            "under",
            "the toadstools.",
            "Awestruck,",
            "you wonder,",
            '"We might not',
            "fall",
            "into",
            'the snowman."',
            "You bury",
            "the logs.",
            "This",
            "oath",
            "pops."
        ],
        [
            "For many",
            "seasons",
            "you undo",
            "lambs,",
            "twisting them",
            "through",
            "jolly",
            "posts,",
            "while David,",
            "charmed",
            "over",
            "alien",
            "brains and",
            "vertices,",
            "fumbles",
            "a toad.",
            "You cork",
            "the spoiled",
            "gridlock",
            "stomping",
            "in the",
            "park.",
            '"I rocked',
            'the aardvarks,"',
            "yaps",
            "the witness,",
            "as she stumbles",
            "among",
            "the clogs.",
            "Annoyed,",
            "you moan,",
            '"We will',
            "plot",
            "around",
            'the kelp."',
            "You quench",
            "the ogres.",
            "August's",
            "derby",
            "blazes."
        ],
        [
            "For fifteen",
            "centuries",
            "you whisper",
            "odors,",
            "devouring them",
            "to",
            "the civilest",
            "hovels,",
            "while Mary,",
            "tempted",
            "within",
            "scurvid",
            "optics and",
            "eyebrows,",
            "plucks",
            "an idiot.",
            "You maul",
            "the big",
            "barb",
            "skulking",
            "inside the",
            "castle.",
            '"I digested',
            'the pizza,"',
            "chides",
            "the butcher,",
            "as he flees",
            "inside",
            "the socks.",
            "Confused,",
            "you mumble,",
            string(abi.encodePacked('"We can', "'t")), // "We can't,
            "joke",
            "inside",
            'the skulls."',
            "You jolt",
            "the cables.",
            "Friday's",
            "heir",
            "dangles."
        ]
    ];

    function uint8ToHexStringPair(uint8 num)
        public
        view
        returns (string[2] memory hexStr)
    {
        strings.slice memory numHexSlice = Strings.toHexString(num).toSlice();
        numHexSlice.nextRune(); // 0
        numHexSlice.nextRune(); // x
        hexStr[0] = numHexSlice.nextRune().toString();
        hexStr[1] = numHexSlice.nextRune().toString();
        return hexStr;
    }

    function addressToHexStringArray(address addr)
        public
        view
        returns (string[40] memory hexStrArr)
    {
        bytes20 addrBytes = bytes20(addr);

        for (uint8 i = 0; i < 20; i++) {
            string[2] memory hexStrPair = uint8ToHexStringPair(
                uint8(addrBytes[i])
            );
            hexStrArr[i * 2] = hexStrPair[0];
            hexStrArr[i * 2 + 1] = hexStrPair[1];
        }
        return hexStrArr;
    }

    function addressToSentance(address addr)
        public
        view
        returns (string[40] memory sentance)
    {
        bytes20 addrBytes = bytes20(addr);

        for (uint8 i = 0; i < 20; i++) {
            string[2] memory hexStrPair = uint8ToHexStringPair(
                uint8(addrBytes[i])
            );

            sentance[i * 2] = WORDS[hexCharToUint(hexStrPair[0])][i * 2];
            sentance[i * 2 + 1] = WORDS[hexCharToUint(hexStrPair[1])][
                i * 2 + 1
            ];
        }
        return sentance;
    }

    function addressToSentanceViaMapping(address addr)
        public
        view
        returns (string[40] memory sentance)
    {
        bytes20 addrBytes = bytes20(addr);

        for (uint8 i = 0; i < 20; i++) {
            string[2] memory hexStrPair = uint8ToHexStringPair(
                uint8(addrBytes[i])
            );

            sentance[i * 2] = WORDS[charToHex[hexStrPair[0]]][i * 2];
            sentance[i * 2 + 1] = WORDS[charToHex[hexStrPair[1]]][i * 2 + 1];
        }
        return sentance;
    }

    function isEqual(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function hexCharToUint(string memory hexChar)
        public
        pure
        returns (uint8 num)
    {
        if (isEqual(hexChar, "0")) return 0;
        if (isEqual(hexChar, "1")) return 1;
        if (isEqual(hexChar, "2")) return 2;
        if (isEqual(hexChar, "3")) return 3;
        if (isEqual(hexChar, "4")) return 4;
        if (isEqual(hexChar, "5")) return 5;
        if (isEqual(hexChar, "6")) return 6;
        if (isEqual(hexChar, "7")) return 7;
        if (isEqual(hexChar, "8")) return 8;
        if (isEqual(hexChar, "9")) return 9;
        if (isEqual(hexChar, "a")) return 10;
        if (isEqual(hexChar, "b")) return 11;
        if (isEqual(hexChar, "c")) return 12;
        if (isEqual(hexChar, "d")) return 13;
        if (isEqual(hexChar, "e")) return 14;
        if (isEqual(hexChar, "f")) return 15;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "stringutils/strings.sol";

contract ColorMaker {
    using strings for *;

    constructor() {}

    function addressToColorStrings(address addr)
        public
        pure
        returns (string[2] memory colors)
    {
        bytes20 addrBytes = bytes20(addr);

        bytes1 first = bytes1(addrBytes[0]);
        bytes1 second = bytes1(addrBytes[1]);
        bytes1 third = bytes1(addrBytes[2]);

        uint8 r = uint8(first);
        uint8 g = uint8(second);
        uint8 b = uint8(third);

        colors[0] = uint8ToHexColorString(r, g, b);
        colors[1] = uint8ToHexColorString(~r, ~g, ~b);
        return colors;
    }

    function uint8ToHexColorString(
        uint8 r,
        uint8 g,
        uint8 b
    ) private pure returns (string memory hexColorString) {
        strings.slice memory rSlice = Strings.toHexString(r).toSlice();
        strings.slice memory gSlice = Strings.toHexString(g).toSlice(); // g string LOL
        strings.slice memory bSlice = Strings.toHexString(b).toSlice();

        rSlice.nextRune();
        rSlice.nextRune();
        strings.slice memory rNibble1 = rSlice.nextRune();
        strings.slice memory rNibble2 = rSlice.nextRune();
        string memory rString = rNibble1.concat(rNibble2);

        gSlice.nextRune();
        gSlice.nextRune();
        strings.slice memory gNibble1 = gSlice.nextRune();
        strings.slice memory gNibble2 = gSlice.nextRune();
        string memory gString = gNibble1.concat(gNibble2);

        bSlice.nextRune();
        bSlice.nextRune();
        strings.slice memory bNibble1 = bSlice.nextRune();
        strings.slice memory bNibble2 = bSlice.nextRune();
        string memory bString = bNibble1.concat(bNibble2);

        return string(abi.encodePacked(rString, gString, bString));
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}

/*
 * @title String & slice utility library for Solidity contracts.
 * @author Nick Johnson <[email protected]>
 *
 * @dev Functionality in this library is largely implemented using an
 *      abstraction called a 'slice'. A slice represents a part of a string -
 *      anything from the entire string to a single character, or even no
 *      characters at all (a 0-length slice). Since a slice only has to specify
 *      an offset and a length, copying and manipulating slices is a lot less
 *      expensive than copying and manipulating the strings they reference.
 *
 *      To further reduce gas costs, most functions on slice that need to return
 *      a slice modify the original one instead of allocating a new one; for
 *      instance, `s.split(".")` will return the text up to the first '.',
 *      modifying s to only contain the remainder of the string after the '.'.
 *      In situations where you do not want to modify the original slice, you
 *      can make a copy first with `.copy()`, for example:
 *      `s.copy().split(".")`. Try and avoid using this idiom in loops; since
 *      Solidity has no memory management, it will result in allocating many
 *      short-lived slices that are later discarded.
 *
 *      Functions that return two slices come in two versions: a non-allocating
 *      version that takes the second slice as an argument, modifying it in
 *      place, and an allocating version that allocates and returns the second
 *      slice; see `nextRune` for example.
 *
 *      Functions that have to copy string data will return strings rather than
 *      slices; these can be cast back to slices for further processing if
 *      required.
 *
 *      For convenience, some functions are provided with non-modifying
 *      variants that create a new slice and return both; for instance,
 *      `s.splitNew('.')` leaves s unmodified, and returns two values
 *      corresponding to the left and right parts of the string.
 */

pragma solidity ^0.8.0;

library strings {
    struct slice {
        uint _len;
        uint _ptr;
    }

    function memcpy(uint dest, uint src, uint len) private pure {
        // Copy word-length chunks while possible
        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = type(uint).max;
        if (len > 0) {
            mask = 256 ** (32 - len) - 1;
        }
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /*
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self) internal pure returns (slice memory) {
        uint ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    /*
     * @dev Returns the length of a null-terminated bytes32 string.
     * @param self The value to find the length of.
     * @return The length of the string, from 0 to 32.
     */
    function len(bytes32 self) internal pure returns (uint) {
        uint ret;
        if (self == 0)
            return 0;
        if (uint(self) & type(uint128).max == 0) {
            ret += 16;
            self = bytes32(uint(self) / 0x100000000000000000000000000000000);
        }
        if (uint(self) & type(uint64).max == 0) {
            ret += 8;
            self = bytes32(uint(self) / 0x10000000000000000);
        }
        if (uint(self) & type(uint32).max == 0) {
            ret += 4;
            self = bytes32(uint(self) / 0x100000000);
        }
        if (uint(self) & type(uint16).max == 0) {
            ret += 2;
            self = bytes32(uint(self) / 0x10000);
        }
        if (uint(self) & type(uint8).max == 0) {
            ret += 1;
        }
        return 32 - ret;
    }

    /*
     * @dev Returns a slice containing the entire bytes32, interpreted as a
     *      null-terminated utf-8 string.
     * @param self The bytes32 value to convert to a slice.
     * @return A new slice containing the value of the input argument up to the
     *         first null.
     */
    function toSliceB32(bytes32 self) internal pure returns (slice memory ret) {
        // Allocate space for `self` in memory, copy it there, and point ret at it
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x20))
            mstore(ptr, self)
            mstore(add(ret, 0x20), ptr)
        }
        ret._len = len(self);
    }

    /*
     * @dev Returns a new slice containing the same data as the current slice.
     * @param self The slice to copy.
     * @return A new slice containing the same data as `self`.
     */
    function copy(slice memory self) internal pure returns (slice memory) {
        return slice(self._len, self._ptr);
    }

    /*
     * @dev Copies a slice to a new string.
     * @param self The slice to copy.
     * @return A newly allocated string containing the slice's text.
     */
    function toString(slice memory self) internal pure returns (string memory) {
        string memory ret = new string(self._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    /*
     * @dev Returns the length in runes of the slice. Note that this operation
     *      takes time proportional to the length of the slice; avoid using it
     *      in loops, and call `slice.empty()` if you only need to know whether
     *      the slice is empty or not.
     * @param self The slice to operate on.
     * @return The length of the slice in runes.
     */
    function len(slice memory self) internal pure returns (uint l) {
        // Starting at ptr-31 means the LSB will be the byte we care about
        uint ptr = self._ptr - 31;
        uint end = ptr + self._len;
        for (l = 0; ptr < end; l++) {
            uint8 b;
            assembly { b := and(mload(ptr), 0xFF) }
            if (b < 0x80) {
                ptr += 1;
            } else if(b < 0xE0) {
                ptr += 2;
            } else if(b < 0xF0) {
                ptr += 3;
            } else if(b < 0xF8) {
                ptr += 4;
            } else if(b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
    }

    /*
     * @dev Returns true if the slice is empty (has a length of 0).
     * @param self The slice to operate on.
     * @return True if the slice is empty, False otherwise.
     */
    function empty(slice memory self) internal pure returns (bool) {
        return self._len == 0;
    }

    /*
     * @dev Returns a positive number if `other` comes lexicographically after
     *      `self`, a negative number if it comes before, or zero if the
     *      contents of the two slices are equal. Comparison is done per-rune,
     *      on unicode codepoints.
     * @param self The first slice to compare.
     * @param other The second slice to compare.
     * @return The result of the comparison.
     */
    function compare(slice memory self, slice memory other) internal pure returns (int) {
        uint shortest = self._len;
        if (other._len < self._len)
            shortest = other._len;

        uint selfptr = self._ptr;
        uint otherptr = other._ptr;
        for (uint idx = 0; idx < shortest; idx += 32) {
            uint a;
            uint b;
            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }
            if (a != b) {
                // Mask out irrelevant bytes and check again
                uint mask = type(uint).max; // 0xffff...
                if(shortest < 32) {
                  mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
                }
                unchecked {
                    uint diff = (a & mask) - (b & mask);
                    if (diff != 0)
                        return int(diff);
                }
            }
            selfptr += 32;
            otherptr += 32;
        }
        return int(self._len) - int(other._len);
    }

    /*
     * @dev Returns true if the two slices contain the same text.
     * @param self The first slice to compare.
     * @param self The second slice to compare.
     * @return True if the slices are equal, false otherwise.
     */
    function equals(slice memory self, slice memory other) internal pure returns (bool) {
        return compare(self, other) == 0;
    }

    /*
     * @dev Extracts the first rune in the slice into `rune`, advancing the
     *      slice to point to the next rune and returning `self`.
     * @param self The slice to operate on.
     * @param rune The slice that will contain the first rune.
     * @return `rune`.
     */
    function nextRune(slice memory self, slice memory rune) internal pure returns (slice memory) {
        rune._ptr = self._ptr;

        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }

        uint l;
        uint b;
        // Load the first byte of the rune into the LSBs of b
        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) }
        if (b < 0x80) {
            l = 1;
        } else if(b < 0xE0) {
            l = 2;
        } else if(b < 0xF0) {
            l = 3;
        } else {
            l = 4;
        }

        // Check for truncated codepoints
        if (l > self._len) {
            rune._len = self._len;
            self._ptr += self._len;
            self._len = 0;
            return rune;
        }

        self._ptr += l;
        self._len -= l;
        rune._len = l;
        return rune;
    }

    /*
     * @dev Returns the first rune in the slice, advancing the slice to point
     *      to the next rune.
     * @param self The slice to operate on.
     * @return A slice containing only the first rune from `self`.
     */
    function nextRune(slice memory self) internal pure returns (slice memory ret) {
        nextRune(self, ret);
    }

    /*
     * @dev Returns the number of the first codepoint in the slice.
     * @param self The slice to operate on.
     * @return The number of the first codepoint in the slice.
     */
    function ord(slice memory self) internal pure returns (uint ret) {
        if (self._len == 0) {
            return 0;
        }

        uint word;
        uint length;
        uint divisor = 2 ** 248;

        // Load the rune into the MSBs of b
        assembly { word:= mload(mload(add(self, 32))) }
        uint b = word / divisor;
        if (b < 0x80) {
            ret = b;
            length = 1;
        } else if(b < 0xE0) {
            ret = b & 0x1F;
            length = 2;
        } else if(b < 0xF0) {
            ret = b & 0x0F;
            length = 3;
        } else {
            ret = b & 0x07;
            length = 4;
        }

        // Check for truncated codepoints
        if (length > self._len) {
            return 0;
        }

        for (uint i = 1; i < length; i++) {
            divisor = divisor / 256;
            b = (word / divisor) & 0xFF;
            if (b & 0xC0 != 0x80) {
                // Invalid UTF-8 sequence
                return 0;
            }
            ret = (ret * 64) | (b & 0x3F);
        }

        return ret;
    }

    /*
     * @dev Returns the keccak-256 hash of the slice.
     * @param self The slice to hash.
     * @return The hash of the slice.
     */
    function keccak(slice memory self) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }

    /*
     * @dev Returns true if `self` starts with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function startsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        if (self._ptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let selfptr := mload(add(self, 0x20))
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
        }
        return equal;
    }

    /*
     * @dev If `self` starts with `needle`, `needle` is removed from the
     *      beginning of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function beyond(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        bool equal = true;
        if (self._ptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let selfptr := mload(add(self, 0x20))
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            }
        }

        if (equal) {
            self._len -= needle._len;
            self._ptr += needle._len;
        }

        return self;
    }

    /*
     * @dev Returns true if the slice ends with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function endsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        uint selfptr = self._ptr + self._len - needle._len;

        if (selfptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
        }

        return equal;
    }

    /*
     * @dev If `self` ends with `needle`, `needle` is removed from the
     *      end of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function until(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        uint selfptr = self._ptr + self._len - needle._len;
        bool equal = true;
        if (selfptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            }
        }

        if (equal) {
            self._len -= needle._len;
        }

        return self;
    }

    // Returns the memory address of the first byte of the first occurrence of
    // `needle` in `self`, or the first byte after `self` if not found.
    function findPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr = selfptr;
        uint idx;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }

                bytes32 needledata;
                assembly { needledata := and(mload(needleptr), mask) }

                uint end = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly { ptrdata := and(mload(ptr), mask) }

                while (ptrdata != needledata) {
                    if (ptr >= end)
                        return selfptr + selflen;
                    ptr++;
                    assembly { ptrdata := and(mload(ptr), mask) }
                }
                return ptr;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }

                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr;
                    ptr += 1;
                }
            }
        }
        return selfptr + selflen;
    }

    // Returns the memory address of the first byte after the last occurrence of
    // `needle` in `self`, or the address of `self` if not found.
    function rfindPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }

                bytes32 needledata;
                assembly { needledata := and(mload(needleptr), mask) }

                ptr = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly { ptrdata := and(mload(ptr), mask) }

                while (ptrdata != needledata) {
                    if (ptr <= selfptr)
                        return selfptr;
                    ptr--;
                    assembly { ptrdata := and(mload(ptr), mask) }
                }
                return ptr + needlelen;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }
                ptr = selfptr + (selflen - needlelen);
                while (ptr >= selfptr) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr + needlelen;
                    ptr -= 1;
                }
            }
        }
        return selfptr;
    }

    /*
     * @dev Modifies `self` to contain everything from the first occurrence of
     *      `needle` to the end of the slice. `self` is set to the empty slice
     *      if `needle` is not found.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function find(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len -= ptr - self._ptr;
        self._ptr = ptr;
        return self;
    }

    /*
     * @dev Modifies `self` to contain the part of the string from the start of
     *      `self` to the end of the first occurrence of `needle`. If `needle`
     *      is not found, `self` is set to the empty slice.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function rfind(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len = ptr - self._ptr;
        return self;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and `token` to everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function split(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = self._ptr;
        token._len = ptr - self._ptr;
        if (ptr == self._ptr + self._len) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
            self._ptr = ptr + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and returning everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` up to the first occurrence of `delim`.
     */
    function split(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        split(self, needle, token);
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and `token` to everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function rsplit(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = ptr;
        token._len = self._len - (ptr - self._ptr);
        if (ptr == self._ptr) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and returning everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` after the last occurrence of `delim`.
     */
    function rsplit(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        rsplit(self, needle, token);
    }

    /*
     * @dev Counts the number of nonoverlapping occurrences of `needle` in `self`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return The number of occurrences of `needle` found in `self`.
     */
    function count(slice memory self, slice memory needle) internal pure returns (uint cnt) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr) + needle._len;
        while (ptr <= self._ptr + self._len) {
            cnt++;
            ptr = findPtr(self._len - (ptr - self._ptr), ptr, needle._len, needle._ptr) + needle._len;
        }
    }

    /*
     * @dev Returns True if `self` contains `needle`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return True if `needle` is found in `self`, false otherwise.
     */
    function contains(slice memory self, slice memory needle) internal pure returns (bool) {
        return rfindPtr(self._len, self._ptr, needle._len, needle._ptr) != self._ptr;
    }

    /*
     * @dev Returns a newly allocated string containing the concatenation of
     *      `self` and `other`.
     * @param self The first slice to concatenate.
     * @param other The second slice to concatenate.
     * @return The concatenation of the two strings.
     */
    function concat(slice memory self, slice memory other) internal pure returns (string memory) {
        string memory ret = new string(self._len + other._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr, self._len);
        memcpy(retptr + self._len, other._ptr, other._len);
        return ret;
    }

    /*
     * @dev Joins an array of slices, using `self` as a delimiter, returning a
     *      newly allocated string.
     * @param self The delimiter to use.
     * @param parts A list of slices to join.
     * @return A newly allocated string containing all the slices in `parts`,
     *         joined with `self`.
     */
    function join(slice memory self, slice[] memory parts) internal pure returns (string memory) {
        if (parts.length == 0)
            return "";

        uint length = self._len * (parts.length - 1);
        for(uint i = 0; i < parts.length; i++)
            length += parts[i]._len;

        string memory ret = new string(length);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        for(uint i = 0; i < parts.length; i++) {
            memcpy(retptr, parts[i]._ptr, parts[i]._len);
            retptr += parts[i]._len;
            if (i < parts.length - 1) {
                memcpy(retptr, self._ptr, self._len);
                retptr += self._len;
            }
        }

        return ret;
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
// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}