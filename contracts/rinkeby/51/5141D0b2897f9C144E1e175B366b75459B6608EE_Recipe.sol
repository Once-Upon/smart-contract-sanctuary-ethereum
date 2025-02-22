// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

// ============ Imports ============



import "./library/ERC721.sol";
import "./library/Ownable.sol";
import "./library/ReentrancyGuard.sol";
import "./library/Base64.sol";
import "./library/Strings.sol";
import "./library/ItemComponents.sol";
import "./library/ItemTokenId.sol";
import "./library/ItemMetadata.sol";
import "./library/RecipeRequirements.sol";

interface LootBagInterface {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}
//needs to be a 721, transfers recipe to contract once used, and transfers back when reassembled
contract Recipe is ERC721, ReentrancyGuard, Ownable, RecipeRequirements {

    LootBagInterface lootBagContract = LootBagInterface(0x3F1FF071D3d994e39e4D1a6fDBA82717AE35c918);

    //for testing
    //LootBagInterface lootBagContract;

    constructor() ERC721("Recipes (for Adventurers)", "MaterialBag") {
        //for testing
        //lootBagContract = LootBagInterface(_lootBagContract);
        transferOwnership(newOwner);
    }

    string public PROVENANCE = "";
    uint256 public ownersPrice; //0 ETH
    uint256 public membersPrice; //0 ETH
    uint256 public publicPrice = 10000000000000000; //0.01 ETH
    bool public saleIsActive = true;
    address newOwner = 0x14E3b144a3638C9d58F2019fe4C24ED147EAD207;

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function setMembersPrice(uint256 newPrice) public onlyOwner {
        membersPrice = newPrice;
    }

    function setPublicPrice(uint256 newPrice) public onlyOwner {
        publicPrice = newPrice;
    }

    function setProvenance(string memory prov) public onlyOwner {
        PROVENANCE = prov;
    }

    //Private sale minting (reserved for LootBag owners)
    function mintWithLoot(uint lootBagId) public payable nonReentrant {
        require(saleIsActive, "Sale must be active to mint");
        require(membersPrice <= msg.value, "Ether value sent is not correct");
        require(lootBagContract.ownerOf(lootBagId) == msg.sender, "Not the owner of this loot bag.");
        require(!_exists(lootBagId), "This token has already been minted");

        _safeMint(msg.sender, lootBagId);
    }
    function multiMintWithLoot(uint[] memory lootBagIds) public payable nonReentrant {
        require(saleIsActive, "Sale must be active to mint");
        require((membersPrice * lootBagIds.length) <= msg.value, "Ether value sent is not correct");
        
        for (uint i=0; i<lootBagIds.length; i++) {
            require(lootBagContract.ownerOf(lootBagIds[i]) == msg.sender, "Not the owner of this loot bag.");
            require(!_exists(lootBagIds[i]), "One of these tokens has already been minted");
            _safeMint(msg.sender, lootBagIds[i]);
        }
    }

    //Public sale minting
    function mint(uint lootBagId) public payable nonReentrant {
        require(saleIsActive, "Sale must be active to mint");
        require(publicPrice <= msg.value, "Ether value sent is not correct");
        require(lootBagId > 8000 && lootBagId < 15101, "Token ID invalid");
        require(!_exists(lootBagId), "This token has already been minted");

        _safeMint(msg.sender, lootBagId);
    }
    function multiMint(uint[] memory lootBagIds) public payable nonReentrant {
        require(saleIsActive, "Sale must be active to mint");
        require((publicPrice * lootBagIds.length) <= msg.value, "Ether value sent is not correct");
        
        for (uint i=0; i<lootBagIds.length; i++) {
            require(lootBagIds[i] > 8000 && lootBagIds[i] < 15101, "Token ID invalid");
            require(!_exists(lootBagIds[i]), "One of these tokens have already been minted");
            _safeMint(msg.sender, lootBagIds[i]);
        }
    }

    //Owner mint
    function ownerMint(uint lootBagId) public payable nonReentrant onlyOwner {
        require(ownersPrice <= msg.value, "Ether value sent is not correct");
        require(lootBagId > 15100 && lootBagId < 16001, "Token ID invalid");
        require(!_exists(lootBagId), "This token has already been minted");

        _safeMint(msg.sender, lootBagId);
    }
    function ownerMultiMint(uint[] memory lootBagIds) public payable nonReentrant onlyOwner {
        require((ownersPrice * lootBagIds.length) <= msg.value, "Ether value sent is not correct");
        
        for (uint i=0; i<lootBagIds.length; i++) {
            require(lootBagIds[i] > 15100 && lootBagIds[i] < 16001, "Token ID invalid");
            require(!_exists(lootBagIds[i]), "One of these tokens has already been minted");
            _safeMint(msg.sender, lootBagIds[i]);
        }
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        
        RecipeItemNames memory recipeNames;
        RecipeItemIds memory recipeIds;

        (recipeNames, recipeIds) = getRecipeRequirements(tokenId);

        string[15] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = recipeNames.gem;

        parts[2] = '</text><text x="10" y="40" class="base">';

        parts[3] = recipeNames.rune;

        parts[4] = '</text><text x="10" y="60" class="base">';

        parts[5] = recipeNames.material;

        parts[6] = '</text><text x="10" y="80" class="base">';

        parts[7] = recipeNames.charm;

        parts[8] = '</text><text x="10" y="100" class="base">';

        parts[9] = recipeNames.tool;

        parts[10] = '</text><text x="10" y="120" class="base">';

        parts[11] = recipeNames.element;

        parts[12] = '</text><text x="10" y="140" class="base">';

        parts[13] = recipeNames.requirement;

        parts[14] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
        output = string(abi.encodePacked(output, parts[9], parts[10], parts[11], parts[12], parts[13], parts[14]));
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Recipe for ', recipeNames.recipe, '", "description": "Recipe is randomized adventurer gear generated and stored on chain. Stats, images, and other functionality are intentionally omitted for others to interpret. Feel free to use Recipe in any way you want.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./IERC721Metadata.sol";
import "./Address.sol";
import "./Context.sol";
import "./Strings.sol";
import "./ERC165.sol";

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

pragma solidity ^0.8.0;

import "./Context.sol";

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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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

    constructor() {
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

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

/// [MIT License]
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

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: Unlicense

/*

    Components.sol
    
    This is a utility contract to make it easier for other
    contracts to work with Loot properties.
    
    Call weaponComponents(), chestComponents(), etc. to get 
    an array of attributes that correspond to the item. 
    
    The return format is:
    
    uint256[5] =>
        [0] = Item ID
        [1] = Suffix ID (0 for none)
        [2] = Name Prefix ID (0 for none)
        [3] = Name Suffix ID (0 for none)
        [4] = Augmentation (0 = false, 1 = true)
    
    See the item and attribute tables below for corresponding IDs.

*/

pragma solidity ^0.8.4;

import "./Strings.sol";

contract ItemComponents {

    //items:
    string[] internal weapons = [
        "Warhammer", // 0
        "Quarterstaff", // 1
        "Maul", // 2
        "Mace", // 3
        "Club", // 4
        "Katana", // 5
        "Falchion", // 6
        "Scimitar", // 7
        "Long Sword", // 8
        "Short Sword", // 9
        "Ghost Wand", // 10
        "Grave Wand", // 11
        "Bone Wand", // 12
        "Wand", // 13
        "Grimoire", // 14
        "Chronicle", // 15
        "Tome", // 16
        "Book" // 17
    ];
    uint256 constant weaponsLength = 18;

    string[] internal chestArmor = [
        "Divine Robe", // 0
        "Silk Robe", // 1
        "Linen Robe", // 2
        "Robe", // 3
        "Shirt", // 4
        "Demon Husk", // 5
        "Dragonskin Armor", // 6
        "Studded Leather Armor", // 7
        "Hard Leather Armor", // 8
        "Leather Armor", // 9
        "Holy Chestplate", // 10
        "Ornate Chestplate", // 11
        "Plate Mail", // 12
        "Chain Mail", // 13
        "Ring Mail" // 14
    ];
    uint256 constant chestLength = 15;

    string[] internal headArmor = [
        "Ancient Helm", // 0
        "Ornate Helm", // 1
        "Great Helm", // 2
        "Full Helm", // 3
        "Helm", // 4
        "Demon Crown", // 5
        "Dragon's Crown", // 6
        "War Cap", // 7
        "Leather Cap", // 8
        "Cap", // 9
        "Crown", // 10
        "Divine Hood", // 11
        "Silk Hood", // 12
        "Linen Hood", // 13
        "Hood" // 14
    ];
    uint256 constant headLength = 15;

    string[] internal waistArmor = [
        "Ornate Belt", // 0
        "War Belt", // 1
        "Plated Belt", // 2
        "Mesh Belt", // 3
        "Heavy Belt", // 4
        "Demonhide Belt", // 5
        "Dragonskin Belt", // 6
        "Studded Leather Belt", // 7
        "Hard Leather Belt", // 8
        "Leather Belt", // 9
        "Brightsilk Sash", // 10
        "Silk Sash", // 11
        "Wool Sash", // 12
        "Linen Sash", // 13
        "Sash" // 14
    ];
    uint256 constant waistLength = 15;

    string[] internal footArmor = [
        "Holy Greaves", // 0
        "Ornate Greaves", // 1
        "Greaves", // 2
        "Chain Boots", // 3
        "Heavy Boots", // 4
        "Demonhide Boots", // 5
        "Dragonskin Boots", // 6
        "Studded Leather Boots", // 7
        "Hard Leather Boots", // 8
        "Leather Boots", // 9
        "Divine Slippers", // 10
        "Silk Slippers", // 11
        "Wool Shoes", // 12
        "Linen Shoes", // 13
        "Shoes" // 14
    ];
    uint256 constant footLength = 15;

    string[] internal handArmor = [
        "Holy Gauntlets", // 0
        "Ornate Gauntlets", // 1
        "Gauntlets", // 2
        "Chain Gloves", // 3
        "Heavy Gloves", // 4
        "Demon's Hands", // 5
        "Dragonskin Gloves", // 6
        "Studded Leather Gloves", // 7
        "Hard Leather Gloves", // 8
        "Leather Gloves", // 9
        "Divine Gloves", // 10
        "Silk Gloves", // 11
        "Wool Gloves", // 12
        "Linen Gloves", // 13
        "Gloves" // 14
    ];
    uint256 constant handLength = 15;

    string[] internal necklaces = [
        "Necklace", // 0
        "Amulet", // 1
        "Pendant" // 2
    ];
    uint256 constant necklacesLength = 3;

    string[] internal rings = [
        "Gold Ring", // 0
        "Silver Ring", // 1
        "Bronze Ring", // 2
        "Platinum Ring", // 3
        "Titanium Ring" // 4
    ];
    uint256 constant ringsLength = 5;
    
    string[] internal suffixes = [
        "of Power",
        "of Giants",
        "of Titans",
        "of Skill",
        "of Perfection",
        "of Brilliance",
        "of Enlightenment",
        "of Protection",
        "of Anger",
        "of Rage",
        "of Fury",
        "of Vitriol",
        "of the Fox",
        "of Detection",
        "of Reflection",
        "of the Twins"
    ];
    
    string[] internal namePrefixes = [
        "Agony", "Apocalypse", "Armageddon", "Beast", "Behemoth", "Blight", "Blood", "Bramble", 
        "Brimstone", "Brood", "Carrion", "Cataclysm", "Chimeric", "Corpse", "Corruption", "Damnation", 
        "Death", "Demon", "Dire", "Dragon", "Dread", "Doom", "Dusk", "Eagle", "Empyrean", "Fate", "Foe", 
        "Gale", "Ghoul", "Gloom", "Glyph", "Golem", "Grim", "Hate", "Havoc", "Honour", "Horror", "Hypnotic", 
        "Kraken", "Loath", "Maelstrom", "Mind", "Miracle", "Morbid", "Oblivion", "Onslaught", "Pain", 
        "Pandemonium", "Phoenix", "Plague", "Rage", "Rapture", "Rune", "Skull", "Sol", "Soul", "Sorrow", 
        "Spirit", "Storm", "Tempest", "Torment", "Vengeance", "Victory", "Viper", "Vortex", "Woe", "Wrath",
        "Light's", "Shimmering"  
    ];
    
    string[] internal nameSuffixes = [
        "Bane",
        "Root",
        "Bite",
        "Song",
        "Roar",
        "Grasp",
        "Instrument",
        "Glow",
        "Bender",
        "Shadow",
        "Whisper",
        "Shout",
        "Growl",
        "Tear",
        "Peak",
        "Form",
        "Sun",
        "Moon"
    ];

    uint256 constant suffixesLength = 16;

    uint256 constant namePrefixesLength = 69;

    uint256 constant nameSuffixesLength = 18;

    function itemRandom(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function weaponComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "WEAPON", weaponsLength);
    }

    function chestComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "CHEST", chestLength);
    }

    function headComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "HEAD", headLength);
    }

    function waistComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "WAIST", waistLength);
    }

    function footComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "FOOT", footLength);
    }

    function handComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "HAND", handLength);
    }

    function neckComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "NECK", necklacesLength);
    }

    function ringComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "RING", ringsLength);
    }

    function itemPluck(
        uint256 tokenId,
        string memory keyPrefix,
        uint256 sourceArrayLength
    ) public pure returns (uint256[5] memory) {
        uint256[5] memory components;

        uint256 rand = itemRandom(
            string(abi.encodePacked(keyPrefix, Strings.toString(tokenId)))
        );

        components[0] = rand % sourceArrayLength;
        components[1] = 0;
        components[2] = 0;

        uint256 greatness = rand % 21;
        if (greatness > 14) {
            components[1] = (rand % suffixesLength) + 1;
        }
        if (greatness >= 19) {
            components[2] = (rand % namePrefixesLength) + 1;
            components[3] = (rand % nameSuffixesLength) + 1;
            if (greatness == 19) {
                // ...
            } else {
                components[4] = 1;
            }
        }

        return components;
    }
}

//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;



library ItemTokenId {
    // 2 bytes
    uint256 constant SHIFT = 16;

    /// Encodes an array of Loot components and an item type (weapon, chest etc.)
    /// to a token id
    function toId(uint256[5] memory components, uint256 itemType)
        internal
        pure
        returns (uint256)
    {
        uint256 id = itemType;
        id += encode(components[0], 1);
        id += encode(components[1], 2);
        id += encode(components[2], 3);
        id += encode(components[3], 4);
        id += encode(components[4], 5);

        return id;
    }

    /// Decodes a token id to an array of Loot components and its item type (weapon, chest etc.)
    function fromId(uint256 id)
        internal
        pure
        returns (uint256[5] memory components, uint256 itemType)
    {
        itemType = decode(id, 0);
        components[0] = decode(id, 1);
        components[1] = decode(id, 2);
        components[2] = decode(id, 3);
        components[3] = decode(id, 4);
        components[4] = decode(id, 5);
    }

    /// Masks the component with 0xff and left shifts it by `idx * 2 bytes
    function encode(uint256 component, uint256 idx)
        private
        pure
        returns (uint256)
    {
        return (component & 0xff) << (SHIFT * idx);
    }

    /// Right shifts the provided token id by `idx * 2 bytes` and then masks the
    /// returned value with 0xff.
    function decode(uint256 id, uint256 idx) private pure returns (uint256) {
        return (id >> (SHIFT * idx)) & 0xff;
    }
}

//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ItemComponents.sol";
import "./ItemTokenId.sol";
import "./Base64.sol";
import "./Strings.sol";

contract ItemMetadata is ItemComponents {

    uint256 internal constant WEAPON = 0x0;
    uint256 internal constant CHEST = 0x1;
    uint256 internal constant HEAD = 0x2;
    uint256 internal constant WAIST = 0x3;
    uint256 internal constant FOOT = 0x4;
    uint256 internal constant HAND = 0x5;
    uint256 internal constant NECK = 0x6;
    uint256 internal constant RING = 0x7;

    string[] internal itemTypes = [
        "Weapon",
        "Chest",
        "Head",
        "Waist",
        "Foot",
        "Hand",
        "Neck",
        "Ring"
    ];

    struct ItemIds {
        uint256 weapon;
        uint256 chest;
        uint256 head;
        uint256 waist;
        uint256 foot;
        uint256 hand;
        uint256 neck;
        uint256 ring;
    }
    struct ItemNames {
        string weapon;
        string chest;
        string head;
        string waist;
        string foot;
        string hand;
        string neck;
        string ring;
    }

    //rare materials

    // @notice Given an ERC1155 token id, it returns its name by decoding and parsing
    // the id
    function tokenName(uint256 id) public view returns (string memory) {
        (uint256[5] memory components, uint256 itemType) = ItemTokenId.fromId(id);
        return componentsToString(components, itemType);
    }

    // Returns the "vanilla" item name w/o any prefix/suffixes or augmentations
    function itemName(uint256 itemType, uint256 idx) public view returns (string memory) {
        string[] storage arr;
        if (itemType == WEAPON) {
            arr = weapons;
        } else if (itemType == CHEST) {
            arr = chestArmor;
        } else if (itemType == HEAD) {
            arr = headArmor;
        } else if (itemType == WAIST) {
            arr = waistArmor;
        } else if (itemType == FOOT) {
            arr = footArmor;
        } else if (itemType == HAND) {
            arr = handArmor;
        } else if (itemType == NECK) {
            arr = necklaces;
        } else if (itemType == RING) {
            arr = rings;
        } else {
            revert("Unexpected armor piece");
        }

        return arr[idx];
    }

    // Creates the token description given its components and what type it is
    function componentsToString(uint256[5] memory components, uint256 itemType)
        public
        view
        returns (string memory)
    {
        // item type: what slot to get
        // components[0] the index in the array
        string memory item = itemName(itemType, components[0]);

        // We need to do -1 because the 'no description' is not part of loot copmonents

        // add the suffix
        if (components[1] > 0) {
            item = string(
                abi.encodePacked(item, " ", ItemComponents.suffixes[components[1] - 1])
            );
        }

        // add the name prefix / suffix
        if (components[2] > 0) {
            // prefix
            string memory namePrefixSuffix = string(
                abi.encodePacked("'", ItemComponents.namePrefixes[components[2] - 1])
            );
            if (components[3] > 0) {
                namePrefixSuffix = string(
                    abi.encodePacked(namePrefixSuffix, " ", ItemComponents.nameSuffixes[components[3] - 1])
                );
            }

            namePrefixSuffix = string(abi.encodePacked(namePrefixSuffix, "' "));

            item = string(abi.encodePacked(namePrefixSuffix, item));
        }

        // add the augmentation
        if (components[4] > 0) {
            item = string(abi.encodePacked(item, " +1"));
        }

        return item;
    }

    // View helpers for getting the item ID that corresponds to a bag's items
    function weaponId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(weaponComponents(tokenId), WEAPON);
    }

    function chestId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(chestComponents(tokenId), CHEST);
    }

    function headId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(headComponents(tokenId), HEAD);
    }

    function waistId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(waistComponents(tokenId), WAIST);
    }

    function footId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(footComponents(tokenId), FOOT);
    }

    function handId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(handComponents(tokenId), HAND);
    }

    function neckId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(neckComponents(tokenId), NECK);
    }

    function ringId(uint256 tokenId) public pure returns (uint256) {
        return ItemTokenId.toId(ringComponents(tokenId), RING);
    }

    // Given an erc721 bag, returns the erc1155 token ids of the items in the bag
    function ids(uint256 tokenId) public pure returns (ItemIds memory) {
        return
            ItemIds({
                weapon: weaponId(tokenId),
                chest: chestId(tokenId),
                head: headId(tokenId),
                waist: waistId(tokenId),
                foot: footId(tokenId),
                hand: handId(tokenId),
                neck: neckId(tokenId),
                ring: ringId(tokenId)
            });
    }

    // Given an ERC721 bag, returns the names of the items in the bag
    function seeItems(uint256 tokenId) public view returns (ItemNames memory) {
        ItemIds memory items = ids(tokenId);
        return
            ItemNames({
                weapon: tokenName(items.weapon),
                chest: tokenName(items.chest),
                head: tokenName(items.head),
                waist: tokenName(items.waist),
                foot: tokenName(items.foot),
                hand: tokenName(items.hand),
                neck: tokenName(items.neck),
                ring: tokenName(items.ring)
            });
    }
        /// @notice Returns the attributes associated with this item.
    /// @dev Opensea Standards: https://docs.opensea.io/docs/metadata-standards
    function attributes(uint256 id) public view returns (string memory) {
        (uint256[5] memory components, uint256 itemType) = ItemTokenId.fromId(id);
        // should we also use components[0] which contains the item name?
        string memory slot = itemTypes[itemType];
        string memory res = string(abi.encodePacked('[', trait("Slot", slot)));

        string memory item = itemName(itemType, components[0]);
        res = string(abi.encodePacked(res, ", ", trait("Item", item)));

        if (components[1] > 0) {
            string memory data = suffixes[components[1] - 1];
            res = string(abi.encodePacked(res, ", ", trait("Suffix", data)));
        }

        if (components[2] > 0) {
            string memory data = namePrefixes[components[2] - 1];
            res = string(abi.encodePacked(res, ", ", trait("Name Prefix", data)));
        }

        if (components[3] > 0) {
            string memory data = nameSuffixes[components[3] - 1];
            res = string(abi.encodePacked(res, ", ", trait("Name Suffix", data)));
        }

        if (components[4] > 0) {
            res = string(abi.encodePacked(res, ", ", trait("Augmentation", "Yes")));
        }

        res = string(abi.encodePacked(res, ']'));

        return res;
    }

    // Helper for encoding as json w/ trait_type / value from opensea
    function trait(string memory _traitType, string memory _value) internal pure returns (string memory) {
        return string(abi.encodePacked('{',
            '"trait_type": "', _traitType, '", ',
            '"value": "', _value, '"',
        '}'));
      }


}

//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./MaterialTokenId.sol";
import "./ItemTokenId.sol";
import "./Base64.sol";
import "./Strings.sol";

contract RecipeRequirements {

    string[] internal gems = [
        'Amethyst',
        'Topaz',
        'Sapphire',
        'Emerald',
        'Ruby',
        'Diamond',
        'Skull'
    ];

    uint256 constant gemsLength = 7;

    string[] internal runes = [	
        'El Rune',
        'Eld Rune',
        'Tir Rune',	
        'Nef Rune',	
        'Ith Rune',	
        'Tal Rune',	
        'Ral Rune',	
        'Ort Rune',	
        'Thul Rune',	
        'Amn Rune',	
        'Shael Rune',	
        'Dol Rune',	
        'Hel Rune',	
        'Io Rune',	
        'Lum Rune',	
        'Ko Rune',	
        'Fal Rune',	
        'Lem Rune',	
        'Pul Rune',	
        'Um Rune',	
        'Mal Rune',	
        'Ist Rune',	
        'Gul Rune',	
        'Vex Rune',	
        'Lo Rune',	
        'Sur Rune',	
        'Ber Rune',	
        'Jah Rune',	
        'Cham Rune',	
        'Zod Rune',	
        'Eth Rune',	
        'Sol Rune',	
        'Ohm Rune',	
        'Avax Rune',	
        'Fantom Rune',	
        'Dot Rune'	
    ];	

    uint256 constant runesLength = 35;

    string[] internal materials = [
        'Tin',
        'Iron',
        'Copper',
        'Bronze',
        'Silver',
        'Gold',
        'Leather Hide',
        'Silk',
        'Wool',
        'Obsidian',
        'Flametal',
        'Black Metal',
        'Dragon Skin',
        'Demon Hide',
        'Holy Water',
        'Force Crystals'
    ];

    uint256 constant materialsLength = 16;
    
    string[] internal charms = [
        'Arcing Charm',
        'Azure Charm',
        'Beryl Charm',
        'Bloody Charm',
        'Bronze Charm',
        'Burly Charm',
        'Burning Charm',
        'Chilling Charm',
        'Cobalt Charm',
        'Coral Charm',
        'Emerald Charm',
        'Entrapping Charm',
        'Fanatic Charm',
        'Fine Charm',
        'Forked Charm',
        'Foul Charm',
        'Hibernal Charm',
        'Iron Charm',
        'Jade Charm',
        'Lapis Charm',
        'Toxic Charm',
        'Amber Charm',
        'Boreal Charm',
        'Crimson Charm',
        'Ember Charm',
        'Ethereal Charm',
        'Flaming Charm',
        'Fungal Charm',
        'Garnet Charm',
        'Hexing Charm',
        'Jagged Charm',
        'Russet Charm',
        'Sanguinary Charm',
        'Tangerine Charm'
    ];

    uint256 constant charmsLength = 34;

    string[] internal tools = [
        'Anvil',
        'Fermenter',
        'Hanging Brazier',
        'Bronze Nails',
        'Adze',
        'Hammer',
        'Cultivator'
    ];

    uint256 constant toolsLength = 7;

    string[] internal elements = [		
        'Earth',		
        'Fire',		
        'Wind',		
        'Water',		
        'Mist',		
        'Shadow',		
        'Spirit',		
        'Power',		
        'Time',		
        'Infinity',		
        'Space',
        'Reality'		
    ];	

    uint256 constant elementsLength = 12;

    string[] internal requirements= [	
        'Strength',	
        'Intelligence',	
        'Wisdom',	
        'Dexterity',	
        'Constitution',	
        'Charisma',	
        'Mana'	
    ];

    uint256 constant requirementsLength = 7;

    string[] internal itemTypes = [
        "Weapon",
        "Chest",
        "Head",
        "Waist",
        "Foot",
        "Hand",
        "Neck",
        "Ring"
    ];

    struct ItemIds {
        uint256 weapon;
        uint256 chest;
        uint256 head;
        uint256 waist;
        uint256 foot;
        uint256 hand;
        uint256 neck;
        uint256 ring;
    }
    struct ItemNames {
        string weapon;
        string chest;
        string head;
        string waist;
        string foot;
        string hand;
        string neck;
        string ring;
    }

    struct RecipeItemNames {
        string recipe;
        string gem;
        string rune;
        string material; 
        string charm; 
        string tool;
        string element; 
        string requirement;
    }

    struct RecipeItemIds {
        uint recipe;
        uint gem;
        uint rune;
        uint material; 
        uint charm; 
        uint tool;
        uint element; 
        uint requirement;
    }

    
    string[] internal rareGems = [
        'Diamond',
        'Skull'
    ];

    uint[] internal rareGemsIndices = [
        5,
        6
    ];

    uint256 constant rareGemsLength = 2;

    string[] internal rareRunes = [
        'Eth Rune',
        'Sol Rune',
        'Ohm Rune',
        'Avax Rune',
        'Fantom Rune',
        'Dot Rune'
    ];

    uint[] internal rareRunesIndices = [
        30,
        31,
        32,
        33,
        34,
        35
    ];

    uint256 constant rareRunesLength = 6;

    string[] internal rareMaterials = [
        'Holopad',
        'Obsidian',
        'Flametal',
        'Black Metal',
        'Dragon Skin',
        'Demon Hide',
        'Holy Water',
        'Force Crystals'
    ];

    uint[] internal rareMaterialsIndices = [
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16
    ];

    uint256 constant rareMaterialsLength = 8;

    string[] internal rareCharms = [
        'Amber Charm',
        'Boreal Charm',
        'Crimson Charm',
        'Ember Charm',
        'Ethereal Charm',
        'Flaming Charm',
        'Fungal Charm',
        'Garnet Charm',
        'Hexing Charm',
        'Jagged Charm',
        'Russet Charm',
        'Sanguinary Charm',
        'Tangerine Charm'
    ];

    uint[] internal rareCharmsIndices = [
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33
    ];

    uint256 constant rareCharmsLength = 13;

    string[] internal rareElements = [
        'Spirit',
        'Power',
        'Time',
        'Infinity',
        'Space',
        'Reality'
    ];

    uint[] internal rareElementsIndices = [
        6,
        7,
        8,
        9,
        10,
        11 
    ];

    uint256 constant rareElementsLength = 6;

    //items:
    string[] internal weapons = [
        "Warhammer", // 0
        "Quarterstaff", // 1
        "Maul", // 2
        "Mace", // 3
        "Club", // 4
        "Katana", // 5
        "Falchion", // 6
        "Scimitar", // 7
        "Long Sword", // 8
        "Short Sword", // 9
        "Ghost Wand", // 10
        "Grave Wand", // 11
        "Bone Wand", // 12
        "Wand", // 13
        "Grimoire", // 14
        "Chronicle", // 15
        "Tome", // 16
        "Book" // 17
    ];
    uint256 constant weaponsLength = 18;

    string[] internal chestArmor = [
        "Divine Robe", // 0
        "Silk Robe", // 1
        "Linen Robe", // 2
        "Robe", // 3
        "Shirt", // 4
        "Demon Husk", // 5
        "Dragonskin Armor", // 6
        "Studded Leather Armor", // 7
        "Hard Leather Armor", // 8
        "Leather Armor", // 9
        "Holy Chestplate", // 10
        "Ornate Chestplate", // 11
        "Plate Mail", // 12
        "Chain Mail", // 13
        "Ring Mail" // 14
    ];
    uint256 constant chestLength = 15;

    string[] internal headArmor = [
        "Ancient Helm", // 0
        "Ornate Helm", // 1
        "Great Helm", // 2
        "Full Helm", // 3
        "Helm", // 4
        "Demon Crown", // 5
        "Dragon's Crown", // 6
        "War Cap", // 7
        "Leather Cap", // 8
        "Cap", // 9
        "Crown", // 10
        "Divine Hood", // 11
        "Silk Hood", // 12
        "Linen Hood", // 13
        "Hood" // 14
    ];
    uint256 constant headLength = 15;

    string[] internal waistArmor = [
        "Ornate Belt", // 0
        "War Belt", // 1
        "Plated Belt", // 2
        "Mesh Belt", // 3
        "Heavy Belt", // 4
        "Demonhide Belt", // 5
        "Dragonskin Belt", // 6
        "Studded Leather Belt", // 7
        "Hard Leather Belt", // 8
        "Leather Belt", // 9
        "Brightsilk Sash", // 10
        "Silk Sash", // 11
        "Wool Sash", // 12
        "Linen Sash", // 13
        "Sash" // 14
    ];
    uint256 constant waistLength = 15;

    string[] internal footArmor = [
        "Holy Greaves", // 0
        "Ornate Greaves", // 1
        "Greaves", // 2
        "Chain Boots", // 3
        "Heavy Boots", // 4
        "Demonhide Boots", // 5
        "Dragonskin Boots", // 6
        "Studded Leather Boots", // 7
        "Hard Leather Boots", // 8
        "Leather Boots", // 9
        "Divine Slippers", // 10
        "Silk Slippers", // 11
        "Wool Shoes", // 12
        "Linen Shoes", // 13
        "Shoes" // 14
    ];
    uint256 constant footLength = 15;

    string[] internal handArmor = [
        "Holy Gauntlets", // 0
        "Ornate Gauntlets", // 1
        "Gauntlets", // 2
        "Chain Gloves", // 3
        "Heavy Gloves", // 4
        "Demon's Hands", // 5
        "Dragonskin Gloves", // 6
        "Studded Leather Gloves", // 7
        "Hard Leather Gloves", // 8
        "Leather Gloves", // 9
        "Divine Gloves", // 10
        "Silk Gloves", // 11
        "Wool Gloves", // 12
        "Linen Gloves", // 13
        "Gloves" // 14
    ];
    uint256 constant handLength = 15;

    string[] internal necklaces = [
        "Necklace", // 0
        "Amulet", // 1
        "Pendant" // 2
    ];
    uint256 constant necklacesLength = 3;

    string[] internal rings = [
        "Gold Ring", // 0
        "Silver Ring", // 1
        "Bronze Ring", // 2
        "Platinum Ring", // 3
        "Titanium Ring" // 4
    ];
    uint256 constant ringsLength = 5;
    
    string[] internal suffixes = [
        "of Power",
        "of Giants",
        "of Titans",
        "of Skill",
        "of Perfection",
        "of Brilliance",
        "of Enlightenment",
        "of Protection",
        "of Anger",
        "of Rage",
        "of Fury",
        "of Vitriol",
        "of the Fox",
        "of Detection",
        "of Reflection",
        "of the Twins"
    ];
    
    string[] internal namePrefixes = [
        "Agony", "Apocalypse", "Armageddon", "Beast", "Behemoth", "Blight", "Blood", "Bramble", 
        "Brimstone", "Brood", "Carrion", "Cataclysm", "Chimeric", "Corpse", "Corruption", "Damnation", 
        "Death", "Demon", "Dire", "Dragon", "Dread", "Doom", "Dusk", "Eagle", "Empyrean", "Fate", "Foe", 
        "Gale", "Ghoul", "Gloom", "Glyph", "Golem", "Grim", "Hate", "Havoc", "Honour", "Horror", "Hypnotic", 
        "Kraken", "Loath", "Maelstrom", "Mind", "Miracle", "Morbid", "Oblivion", "Onslaught", "Pain", 
        "Pandemonium", "Phoenix", "Plague", "Rage", "Rapture", "Rune", "Skull", "Sol", "Soul", "Sorrow", 
        "Spirit", "Storm", "Tempest", "Torment", "Vengeance", "Victory", "Viper", "Vortex", "Woe", "Wrath",
        "Light's", "Shimmering"  
    ];
    
    string[] internal nameSuffixes = [
        "Bane",
        "Root",
        "Bite",
        "Song",
        "Roar",
        "Grasp",
        "Instrument",
        "Glow",
        "Bender",
        "Shadow",
        "Whisper",
        "Shout",
        "Growl",
        "Tear",
        "Peak",
        "Form",
        "Sun",
        "Moon"
    ];

    uint256 constant suffixesLength = 16;

    uint256 constant namePrefixesLength = 69;

    uint256 constant nameSuffixesLength = 18;

    uint256 internal constant WEAPON = 0x0;
    uint256 internal constant CHEST = 0x1;
    uint256 internal constant HEAD = 0x2;
    uint256 internal constant WAIST = 0x3;
    uint256 internal constant FOOT = 0x4;
    uint256 internal constant HAND = 0x5;
    uint256 internal constant NECK = 0x6;
    uint256 internal constant RING = 0x7;

    uint256 internal constant GEMS = 0x0;
    uint256 internal constant RUNES = 0x1;
    uint256 internal constant MATERIALS = 0x2;
    uint256 internal constant CHARMS = 0x3;
    uint256 internal constant TOOLS = 0x4;
    uint256 internal constant ELEMENTS = 0x5;
    uint256 internal constant REQUIREMENTS = 0x6;

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }
    
    function tokenName(uint256 id) public view returns (string memory) {
        (uint256[5] memory components, uint256 itemType) = ItemTokenId.fromId(id);
        return componentsToString(components, itemType);
    }

    // Returns the "vanilla" item name w/o any prefix/suffixes or augmentations
    function itemName(uint256 itemType, uint256 idx) public view returns (string memory) {
        string[] storage arr;
        if (itemType == WEAPON) {
            arr = weapons;
        } else if (itemType == CHEST) {
            arr = chestArmor;
        } else if (itemType == HEAD) {
            arr = headArmor;
        } else if (itemType == WAIST) {
            arr = waistArmor;
        } else if (itemType == FOOT) {
            arr = footArmor;
        } else if (itemType == HAND) {
            arr = handArmor;
        } else if (itemType == NECK) {
            arr = necklaces;
        } else if (itemType == RING) {
            arr = rings;
        } else {
            revert("Unexpected armor piece");
        }

        return arr[idx];
    }

        // Creates the token description given its components and what type it is
    function componentsToString(uint256[5] memory components, uint256 itemType)
        public
        view
        returns (string memory)
    {
        // item type: what slot to get
        // components[0] the index in the array
        string memory item = itemName(itemType, components[0]);

        // We need to do -1 because the 'no description' is not part of loot copmonents

        // add the suffix
        if (components[1] > 0) {
            item = string(
                abi.encodePacked(item, " ", suffixes[components[1] - 1])
            );
        }

        // add the name prefix / suffix
        if (components[2] > 0) {
            // prefix
            string memory namePrefixSuffix = string(
                abi.encodePacked("'", namePrefixes[components[2] - 1])
            );
            if (components[3] > 0) {
                namePrefixSuffix = string(
                    abi.encodePacked(namePrefixSuffix, " ", nameSuffixes[components[3] - 1])
                );
            }

            namePrefixSuffix = string(abi.encodePacked(namePrefixSuffix, "' "));

            item = string(abi.encodePacked(namePrefixSuffix, item));
        }

        // add the augmentation
        if (components[4] > 0) {
            item = string(abi.encodePacked(item, " +1"));
        }

        return item;
    }

    
    function weaponComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "WEAPON", weaponsLength);
    }

    function chestComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "CHEST", chestLength);
    }

    function headComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "HEAD", headLength);
    }

    function waistComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "WAIST", waistLength);
    }

    function footComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "FOOT", footLength);
    }

    function handComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "HAND", handLength);
    }

    function neckComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "NECK", necklacesLength);
    }

    function ringComponents(uint256 tokenId)
        public
        pure
        returns (uint256[5] memory)
    {
        return itemPluck(tokenId, "RING", ringsLength);
    }

    function itemPluck(
        uint256 tokenId,
        string memory keyPrefix,
        uint256 sourceArrayLength
    ) public pure returns (uint256[5] memory) {
        uint256[5] memory components;

        uint256 rand = random(
            string(abi.encodePacked(keyPrefix, Strings.toString(tokenId)))
        );

        components[0] = rand % sourceArrayLength;
        components[1] = 0;
        components[2] = 0;

        uint256 greatness = rand % 21;
        if (greatness > 14) {
            components[1] = (rand % suffixesLength) + 1;
        }
        if (greatness >= 19) {
            components[2] = (rand % namePrefixesLength) + 1;
            components[3] = (rand % nameSuffixesLength) + 1;
            if (greatness == 19) {
                // ...
            } else {
                components[4] = 1;
            }
        }

        return components;
    }

    
    // View helpers for getting the item ID that corresponds to a bag's items
    function gemId(uint256 tokenId) public pure returns (uint256) {
        return MaterialTokenId.toId(gemComponents(tokenId), GEMS);
    }

    function runeId(uint256 tokenId) public pure returns (uint256) {
        return MaterialTokenId.toId(runeComponents(tokenId), RUNES);
    }

    function materialId(uint256 tokenId) public pure returns (uint256) {
        return MaterialTokenId.toId(materialComponents(tokenId), MATERIALS);
    }

    function charmId(uint256 tokenId) public pure returns (uint256) {
        return MaterialTokenId.toId(charmComponents(tokenId), CHARMS);
    }

    function toolId(uint256 tokenId) public pure returns (uint256) {
        return MaterialTokenId.toId(toolComponents(tokenId), TOOLS);
    }

    function elementId(uint256 tokenId) public pure returns (uint256) {
        return MaterialTokenId.toId(elementComponents(tokenId), ELEMENTS);
    }

    function requirementId(uint256 tokenId) public pure returns (uint256) {
        return MaterialTokenId.toId(requirementComponents(tokenId), REQUIREMENTS);
    }

        function gemComponents(uint256 tokenId)
        internal
        pure
        returns (uint256[1] memory)
    {
        return pluck(tokenId, "GEM", gemsLength);
    }

    function runeComponents(uint256 tokenId)
        internal
        pure
        returns (uint256[1] memory)
    {
        return pluck(tokenId, "RUNE", runesLength);
    }

    function materialComponents(uint256 tokenId)
        internal
        pure
        returns (uint256[1] memory)
    {
        return pluck(tokenId, "MATERIAL", materialsLength);
    }

    function charmComponents(uint256 tokenId)
        internal
        pure
        returns (uint256[1] memory)
    {
        return pluck(tokenId, "CHARM", charmsLength);
    }

    function toolComponents(uint256 tokenId)
        internal
        pure
        returns (uint256[1] memory)
    {
        return pluck(tokenId, "TOOL", toolsLength);
    }

    function elementComponents(uint256 tokenId)
        internal
        pure
        returns (uint256[1] memory)
    {
        return pluck(tokenId, "ELEMENT", elementsLength);
    }

    function requirementComponents(uint256 tokenId)
        internal
        pure
        returns (uint256[1] memory)
    {
        return pluck(tokenId, "REQUIREMENT", requirementsLength);
    }

    function pluck(
        uint256 tokenId,
        string memory keyPrefix,
        uint256 sourceArrayLength
    ) internal pure returns (uint256[1] memory) {
        uint256[1] memory components;

        uint256 rand = random(
            string(abi.encodePacked(keyPrefix, Strings.toString(tokenId)))
        );

        components[0] = rand % sourceArrayLength;
        return components;
    }


    function getRecipeName(uint tokenId, uint256 vanilla) internal view returns(string memory) {
        uint256 rand = random(string(abi.encodePacked(Strings.toString(tokenId)))) % 8;
        string memory vanillaOutput;
        string memory fullOutput;
        uint256[5] memory components;
        uint256 itemType;

        if (rand == 0){
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, weaponComponents, 0x0));
            fullOutput = tokenName(itemId(tokenId, weaponComponents, 0x0));
        } 
        else if (rand == 1){
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, chestComponents, CHEST));
            fullOutput = tokenName(itemId(tokenId, chestComponents, CHEST));
        }
        else if (rand == 2){
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, waistComponents, WAIST));
            fullOutput = tokenName(itemId(tokenId, waistComponents, WAIST));
        }
        else if (rand == 3){
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, footComponents, FOOT));
            fullOutput = tokenName(itemId(tokenId, footComponents, FOOT));
        }
        else if (rand == 4){
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, headComponents, HEAD));
            fullOutput = tokenName(itemId(tokenId, headComponents, HEAD));
        }
        else if (rand == 5){
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, handComponents, HAND));
            fullOutput = tokenName(itemId(tokenId, handComponents, HAND));
        }        
        else if (rand == 6){
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, neckComponents, NECK));
            fullOutput = tokenName(itemId(tokenId, neckComponents, NECK));
        }        
        else {
            (components, itemType) = ItemTokenId.fromId(itemId(tokenId, ringComponents, RING));
            fullOutput = tokenName(itemId(tokenId, ringComponents, RING));
        }

        vanillaOutput = itemName(itemType, components[0]);

        if (vanilla == 1) {
            return vanillaOutput;
        }
        return fullOutput;

    }

    function getRecipeRequirements(uint tokenId) internal view returns(RecipeItemNames memory, RecipeItemIds memory){

        RecipeItemNames memory recipeNames;
        RecipeItemIds memory recipeIds;
        uint256[1] memory index;
        uint256 rand = random(string(abi.encodePacked(Strings.toString(tokenId))));

        uint256 legendary; 

        recipeIds.recipe = tokenId;
        recipeNames.recipe = getRecipeName(tokenId, 1);

        //check if legendary:
        if (compareStrings(recipeNames.recipe, 'Light Saber')) {
            //require specific item
            recipeNames.material = 'Force Crystals';
            index[0] = 16;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Katana')){
            //require specific item
            recipeNames.material = 'Flametal';
            index[0] = 11;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Obsidian Blade')){
            //require specific item
            recipeNames.material = 'Obsidian';
            index[0] = 10;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Divine Robe') || compareStrings(recipeNames.recipe, 'Divine Hood') || compareStrings(recipeNames.recipe, 'Divine Gloves')) {
            //require specific item
            recipeNames.charm = 'Ethereal Charm';
            index[0] = 25;
            recipeIds.charm = MaterialTokenId.toId(index, CHARMS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Ethereal Silk Robe') || compareStrings(recipeNames.recipe, 'Ethereal Silk Hood') || compareStrings(recipeNames.recipe, 'Ethereal Silk Gloves')){
            //require specific item
            recipeNames.material = 'Silk';
            index[0] = 7;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Holo Robe')){
            //require specific item
            recipeNames.material = 'Holopad';
            index[0] = 9;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Holy Gauntlets')){
            //require specific item
            recipeNames.material = 'Holy Water';
            index[0] = 15;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Infinity Gauntlets')){
            //require specific item
            recipeNames.element = 'Infinity';
            index[0] = 9;
            recipeIds.element = MaterialTokenId.toId(index, ELEMENTS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Space Ring')){
            //require specific item
            recipeNames.element = 'Space';
            index[0] = 10;
            recipeIds.element = MaterialTokenId.toId(index, ELEMENTS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Reality Ring')){
            //require specific item
            recipeNames.element = 'Reality'; 
            index[0] = 11;
            recipeIds.element = MaterialTokenId.toId(index, ELEMENTS);
            legendary = 1; 
        }
        else if (compareStrings(recipeNames.recipe, 'Chrono Ring')){
            //require specific item
            recipeNames.element = 'Time';
            index[0] = 8;
            recipeIds.element = MaterialTokenId.toId(index, ELEMENTS);
            legendary = 1; 
        }
        //check if uncommon
        else if (compareStrings(recipeNames.recipe, 'Demon Husk') || compareStrings(recipeNames.recipe, 'Demonhide Belt') || compareStrings(recipeNames.recipe, 'Demonhide Boots') || compareStrings(recipeNames.recipe, "Demon's Hands")) {
            //require specific item
            recipeNames.material = 'Demon Hide';
            index[0] = 14;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
        }
        else if (compareStrings(recipeNames.recipe, 'Dragonskin Armor') || compareStrings(recipeNames.recipe, 'Dragonskin Belt') || compareStrings(recipeNames.recipe, 'Dragonskin Boots') || compareStrings(recipeNames.recipe, "Dragonskin Gloves")) {
            //require specific item
            recipeNames.material = 'Dragon Skin';
            index[0] = 13;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
        }
        else if (compareStrings(recipeNames.recipe, 'Holy Chestplate') || compareStrings(recipeNames.recipe, 'Holy Sandles')) {
            //require specific item
            recipeNames.material = 'Holy Water';
            index[0] = 15;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
        }
        else if (compareStrings(recipeNames.recipe, 'Hard Leather Belt') || compareStrings(recipeNames.recipe, 'Leather Belt') || compareStrings(recipeNames.recipe, 'Hard Leather Gloves') || compareStrings(recipeNames.recipe, 'Leather Gloves')) {
            //require specific item
            recipeNames.material = 'Leather Hide';
            index[0] = 6;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
        }
        else if (compareStrings(recipeNames.recipe, 'Brightsilk Sash') || compareStrings(recipeNames.recipe, 'Silk Sash') ||  compareStrings(recipeNames.recipe, 'Silk Slippers')) {
            //require specific item
            recipeNames.material = 'Silk';
            index[0] = 7;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
        }
        else if (compareStrings(recipeNames.recipe, 'Wool Gloves')) {
            //require specific item
            recipeNames.material = 'Wool';
            index[0] = 8;
            recipeIds.material = MaterialTokenId.toId(index, MATERIALS);
        }
        else if (compareStrings(recipeNames.recipe, 'Divine Slippers')) {
            //require specific item
            recipeNames.charm = 'Ethereal Charm';
            index[0] = 25;
            recipeIds.charm = MaterialTokenId.toId(index, CHARMS);
        }
        //check if rare
        else if (compareStrings(recipeNames.recipe, 'Ghost Wand') || compareStrings(recipeNames.recipe, 'Grimoire') || compareStrings(recipeNames.recipe, 'Chronicle') || compareStrings(recipeNames.recipe, 'Ornate Gauntlets')){
            //require rare item
            if (rand % 5 == 0) {
                (recipeNames.gem, recipeIds.gem) = getRareItem(tokenId, GEMS);
            }
            else if (rand % 5 == 1) {
                (recipeNames.rune, recipeIds.rune) = getRareItem(tokenId, RUNES);
            }
            else if (rand % 5 == 2) {
                (recipeNames.charm, recipeIds.charm) = getRareItem(tokenId, CHARMS);
            }
            else if (rand % 5 == 3) {
                (recipeNames.element, recipeIds.element) = getRareItem(tokenId, ELEMENTS);
            }
            else {
                (recipeNames.material, recipeIds.material) = getRareItem(tokenId, MATERIALS);
            }
        }

        //fill rare item for legendary: 
        if (legendary == 1) {
            //require rare item
            if (rand % 5 == 0) {
                (recipeNames.gem, recipeIds.gem) = getRareItem(tokenId, GEMS);
            }
            else if (rand % 5 == 1 && (compareStrings(recipeNames.element, ''))){
                (recipeNames.element, recipeIds.element) = getRareItem(tokenId, ELEMENTS);
            }
            else if (rand % 5 == 2 && (compareStrings(recipeNames.charm, ''))) {
                (recipeNames.charm, recipeIds.charm) = getRareItem(tokenId, CHARMS);
            }
            else if (rand % 5 == 3 && (compareStrings(recipeNames.material, ''))) {
                (recipeNames.material, recipeIds.material) = getRareItem(tokenId, MATERIALS);
            }
            else {
                (recipeNames.rune, recipeIds.rune) = getRareItem(tokenId, RUNES);
            }
        }

        //fill in rest of the requirements 
        if (compareStrings(recipeNames.gem, '')){
            recipeIds.gem = gemId(tokenId);
            recipeNames.gem = materialTokenName(recipeIds.gem);
        }
        if (compareStrings(recipeNames.rune, '')){
            recipeIds.rune = runeId(tokenId);
            recipeNames.rune = materialTokenName(recipeIds.rune);
        }
        if (compareStrings(recipeNames.charm, '')){
            recipeIds.charm = charmId(tokenId);
            recipeNames.charm = materialTokenName(recipeIds.charm);
        }
        if (compareStrings(recipeNames.element, '')){
            recipeIds.element = elementId(tokenId);
            recipeNames.element = materialTokenName(recipeIds.element);
        }
        if (compareStrings(recipeNames.material, '')){
            recipeIds.material = materialId(tokenId);
            recipeNames.material = materialTokenName(recipeIds.material);
        }

        recipeIds.tool = toolId(tokenId);
        recipeNames.tool = materialTokenName(recipeIds.tool);
        recipeIds.requirement = requirementId(tokenId);
        recipeNames.requirement = materialTokenName(recipeIds.requirement);
        recipeNames.recipe = getRecipeName(tokenId, 0);

        return (recipeNames, recipeIds);
    }

        function materialTokenName(uint256 id) public view returns (string memory) {
        (uint256[1] memory components, uint256 itemType) = MaterialTokenId.fromId(id);
        return materialItemName(itemType, components[0]);
    }

    // Returns the "vanilla" item name w/o any prefix/suffixes or augmentations
    function materialItemName(uint256 itemType, uint256 idx) public view returns (string memory) {
        string[] storage arr;
        if (itemType == GEMS) {
            arr = gems;
        } else if (itemType == RUNES) {
            arr = runes;
        } else if (itemType == MATERIALS) {
            arr = materials;
        } else if (itemType == CHARMS) {
            arr = charms;
        } else if (itemType == TOOLS) {
            arr = tools;
        } else if (itemType == ELEMENTS) {
            arr = elements;
        } else if (itemType == REQUIREMENTS) {
            arr = requirements;
        } else {
            revert("Unexpected material item");
        }

        return arr[idx];
    }


    function getRareItem(uint tokenId, uint itemType) private view returns(string memory, uint) {
        uint256 rand = random(string(abi.encodePacked(Strings.toString(tokenId))));
        uint256[1] memory index;

        if (itemType == GEMS) {
            rand = rand % rareGemsLength;
            index[0] = rareGemsIndices[rand];
            return (rareGems[rand], MaterialTokenId.toId(index, GEMS));
        }
        else if (itemType == RUNES) {
            rand = rand % rareRunesLength;
            index[0] = rareRunesIndices[rand];
            return (rareRunes[rand], MaterialTokenId.toId(index, RUNES));
        }
        else if (itemType == MATERIALS) {
            rand = rand % rareMaterialsLength;
            index[0] = rareMaterialsIndices[rand];
            return (rareMaterials[rand], MaterialTokenId.toId(index, MATERIALS));
        }
        else if (itemType == CHARMS) {
            rand = rand % rareCharmsLength;
            index[0] = rareCharmsIndices[rand];
            return (rareCharms[rand], MaterialTokenId.toId(index, CHARMS));
        }
        else {
            rand = rand % rareElementsLength;
            index[0] = rareElementsIndices[rand];
            return (rareElements[rand], MaterialTokenId.toId(index, ELEMENTS));
        }
    }

    function compareStrings(string memory s1, string memory s2) private pure returns(bool){
        return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

    function itemId(
        uint256 tokenId,
        function(uint256) view returns (uint256[5] memory) componentsFn,
        uint256 itemType
    ) private view returns (uint256) {
        uint256[5] memory components = componentsFn(tokenId);
        return ItemTokenId.toId(components, itemType);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

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

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;


/*
TOKEN ID FOR MATERIALS

Library to generate tokenIDs for different components, based on token type and attributes. 

*/

library MaterialTokenId {
    // 2 bytes
    uint256 constant SHIFT = 16;

    /// Encodes an array of CrafterLodge components and an item type (gem, rune etc.)
    /// to a token id
    function toId(uint256[1] memory components, uint256 itemType)
        internal
        pure
        returns (uint256)
    {
        uint256 id = itemType;
        id += encode(components[0], 1);

        return id;
    }

    /// Decodes a token id to an array of CrafterLodge components and an item type (gem, rune etc.) 
    function fromId(uint256 id)
        internal
        pure
        returns (uint256[1] memory components, uint256 itemType)
    {
        itemType = decode(id, 0);
        components[0] = decode(id, 1);
    }

    /// Masks the component with 0xff and left shifts it by `idx * 2 bytes
    function encode(uint256 component, uint256 idx)
        private
        pure
        returns (uint256)
    {
        return (component & 0xff) << (SHIFT * idx);
    }

    /// Right shifts the provided token id by `idx * 2 bytes` and then masks the
    /// returned value with 0xff.
    function decode(uint256 id, uint256 idx) private pure returns (uint256) {
        return (id >> (SHIFT * idx)) & 0xff;
    }
}