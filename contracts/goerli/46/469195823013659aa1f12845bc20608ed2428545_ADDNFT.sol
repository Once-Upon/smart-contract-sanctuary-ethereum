/**
 *Submitted for verification at Etherscan.io on 2022-11-18
*/

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

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

abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

interface IERC2981Royalties {
    function royaltyInfo(uint256 _tokenId, uint256 _value) external view returns (address _receiver, uint256 _royaltyAmount);
}

abstract contract ERC2981Base is ERC165, IERC2981Royalties {
    struct RoyaltyInfo {
        address recipient;
        uint24 amount;
    }
	
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool){
        return interfaceId == type(IERC2981Royalties).interfaceId || super.supportsInterface(interfaceId);
    }
}

abstract contract ERC2981Royalties is ERC2981Base {
    RoyaltyInfo private _royalties;
	
    function _setRoyalties(address recipient, uint256 value) internal {
        require(value <= 10000, 'ERC2981Royalties: Too high');
        _royalties = RoyaltyInfo(recipient, uint24(value));
    }
	
    function royaltyInfo(uint256, uint256 value) external view override returns (address receiver, uint256 royaltyAmount){
        RoyaltyInfo memory royalties = _royalties;
        receiver = royalties.recipient;
        royaltyAmount = (value * royalties.amount) / 10000;
    }
}

abstract contract ERC721P is Context, ERC165, IERC721, ERC2981Royalties, IERC721Metadata {
    using Address for address;
    string private _name;
    string private _symbol;
    address[] internal _owners;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
	
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165, ERC2981Base) returns (bool) {
        return
        interfaceId == type(IERC721).interfaceId ||
        interfaceId == type(IERC721Metadata).interfaceId ||
		interfaceId == type(IERC2981Royalties).interfaceId ||
        super.supportsInterface(interfaceId);
    }
	
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        uint count = 0;
        uint length = _owners.length;
        for( uint i = 0; i < length; ++i ){
            if( owner == _owners[i] ){
                ++count;
            }
        }
        delete length;
        return count;
    }
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721P.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

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
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return tokenId < _owners.length && _owners[tokenId] != address(0);
    }
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721P.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }
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
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);
        _owners.push(to);

        emit Transfer(address(0), to, tokenId);
    }
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721P.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);
        _owners[tokenId] = address(0);

        emit Transfer(owner, address(0), tokenId);
    }
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721P.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721P.ownerOf(tokenId), to, tokenId);
    }
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
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

abstract contract ERC721Enum is ERC721P, IERC721Enumerable {
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721P) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }
	
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256 tokenId) {
        require(index < ERC721P.balanceOf(owner), "ERC721Enum: owner ioob");
        uint count;
        for( uint i; i < _owners.length; ++i ){
            if( owner == _owners[i] ){
                if( count == index )
                    return i;
                else
                    ++count;
            }
        }
        require(false, "ERC721Enum: owner ioob");
    }
	
    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        require(0 < ERC721P.balanceOf(owner), "ERC721Enum: owner ioob");
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }
    
	function totalSupply() public view virtual override returns (uint256) {
        return _owners.length;
    }
	
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enum.totalSupply(), "ERC721Enum: global ioob");
        return index;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
	function transfer(address recipient, uint256 amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library SafeERC20 {
    using Address for address;
	
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
	
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract ADDNFT is ERC721Enum, Ownable, ReentrancyGuard{

    using Strings for uint256;
	using SafeERC20 for IERC20;
	
    uint256 public SALE_NFT_TIER_ONE   = 450;
	uint256 public SALE_NFT_TIER_TWO   = 450;
	uint256 public SALE_NFT_TIER_THREE = 450;
	
	uint256 public RESERVED_NFT_TIER_ONE   = 50;
	uint256 public RESERVED_NFT_TIER_TWO   = 50;
	uint256 public RESERVED_NFT_TIER_THREE = 50;
	
	uint256 public SALE_PRICE_TIER_ONE   = 0.15 ether;
	uint256 public SALE_PRICE_TIER_TWO   = 0.20 ether;
	uint256 public SALE_PRICE_TIER_THREE = 0.25 ether;
	
	uint256 public MAX_MINT_SALE = 2;
	uint256 public MAX_BY_MINT_IN_TRANSACTION_SALE = 2;
	
	uint256 public NFT_MINTED_TIER_ONE;
	uint256 public NFT_MINTED_TIER_TWO;
	uint256 public NFT_MINTED_TIER_THREE;
	
	uint256 public NFT_MINTED_TIER_ONE_RESERVED;
	uint256 public NFT_MINTED_TIER_TWO_RESERVED;
	uint256 public NFT_MINTED_TIER_THREE_RESERVED;
	
	uint256 public TOKEN_REQUIRED_FOR_MINT = 1000000 * (10**18);
	IERC20 public ADDToken = IERC20(0x0ed134d3b7E003029eeC7ed46e69FD804C4598C4);
	
	bool public saleEnableTierOne;
	bool public saleEnableTierTwo;
	bool public saleEnableTierThree;
	
    string private baseURI;
	
	struct User {
	  uint256 salemint;
	  bool status;
    }
	
	mapping(address => User) public users;
    constructor() ERC721P('Anarchist Development DAO NFT', 'ADD') {}
	
    function _baseURI() internal view virtual returns (string memory) {
        return baseURI;
    }
	
	function mintEnable() external nonReentrant {
	    require(ADDToken.balanceOf(msg.sender) >= TOKEN_REQUIRED_FOR_MINT, "ADD: insufficient balance in wallet");
		
		ADDToken.safeTransferFrom(address(msg.sender), address(this), TOKEN_REQUIRED_FOR_MINT);
		users[msg.sender].status = true;
	}
	
	
	function mintReservedNFTTierOne(address[] calldata _to, uint256[] calldata _count) external onlyOwner nonReentrant{
        require(_to.length == _count.length,"Mismatch between Address and count");

		for(uint i=0; i < _to.length; i++){
		    uint256 totalSupply = totalSupply();
			
		    require(
				NFT_MINTED_TIER_ONE_RESERVED + _count[i] <= RESERVED_NFT_TIER_ONE, 
				"Max limit reached"
			);
			
			for (uint256 j = 0; j < _count[i]; j++) {
				_safeMint(_to[i], totalSupply + j);
				NFT_MINTED_TIER_ONE_RESERVED++;
			}
		}
    }
	
	function mintReservedNFTTierTwo(address[] calldata _to, uint256[] calldata _count) external onlyOwner nonReentrant{
        require(_to.length == _count.length,"Mismatch between Address and count");

		for(uint i=0; i < _to.length; i++){
		    uint256 totalSupply = totalSupply();
			
		    require(
				NFT_MINTED_TIER_TWO_RESERVED + _count[i] <= RESERVED_NFT_TIER_TWO, 
				"Max limit reached"
			);
			
			for (uint256 j = 0; j < _count[i]; j++) {
				_safeMint(_to[i], totalSupply + j);
				NFT_MINTED_TIER_TWO_RESERVED++;
			}
		}
    }
	
	function mintReservedNFTTierThree(address[] calldata _to, uint256[] calldata _count) external onlyOwner nonReentrant{
        require(_to.length == _count.length,"Mismatch between Address and count");

		for(uint i=0; i < _to.length; i++){
		    uint256 totalSupply = totalSupply();
			
		    require(
				NFT_MINTED_TIER_THREE_RESERVED + _count[i] <= RESERVED_NFT_TIER_THREE, 
				"Max limit reached"
			);
			
			for (uint256 j = 0; j < _count[i]; j++) {
				_safeMint(_to[i], totalSupply + j);
				NFT_MINTED_TIER_THREE_RESERVED++;
			}
		}
    }
	
	function mintSaleNFTTierOne(uint256 _count) public payable nonReentrant{
		uint256 totalSupply = totalSupply();
		require(
			saleEnableTierOne, 
			"ADD: sale is not enable"
		);
        require(
			NFT_MINTED_TIER_ONE + _count <= SALE_NFT_TIER_ONE, 
			"ADD: exceeds max sale nft limit"
		);
		require(
			users[msg.sender].status,
			"ADD: minting not open for this address"
		);
		require(
			users[msg.sender].salemint + _count <= MAX_MINT_SALE,
			"ADD: exceeds max mint limit per wallet"
		);
		require(
			_count <= MAX_BY_MINT_IN_TRANSACTION_SALE,
			"ADD: exceeds max mint limit per txn"
		);
		require(
			msg.value >= SALE_PRICE_TIER_ONE * _count,
			"ADD: value below price"
		);
		for (uint256 i = 0; i < _count; i++) {
            _safeMint(msg.sender, totalSupply + i);
			NFT_MINTED_TIER_ONE++;
        }
		users[msg.sender].salemint = users[msg.sender].salemint + _count;
    }
	
	function mintSaleNFTTierTwo(uint256 _count) public payable nonReentrant{
		uint256 totalSupply = totalSupply();
		require(
			saleEnableTierTwo, 
			"ADD: sale is not enable"
		);
        require(
			NFT_MINTED_TIER_TWO + _count <= SALE_NFT_TIER_TWO, 
			"ADD: exceeds max sale nft limit"
		);
		require(
			users[msg.sender].status,
			"ADD: minting not open for this address"
		);
		require(
			users[msg.sender].salemint + _count <= MAX_MINT_SALE,
			"ADD: exceeds max mint limit per wallet"
		);
		require(
			_count <= MAX_BY_MINT_IN_TRANSACTION_SALE,
			"ADD: exceeds max mint limit per txn"
		);
		require(
			msg.value >= SALE_PRICE_TIER_TWO * _count,
			"ADD: value below price"
		);
		for (uint256 i = 0; i < _count; i++) {
            _safeMint(msg.sender, totalSupply + i);
			NFT_MINTED_TIER_TWO++;
        }
		users[msg.sender].salemint = users[msg.sender].salemint + _count;
    }
	
	function mintSaleNFTTierThree(uint256 _count) public payable nonReentrant{
		uint256 totalSupply = totalSupply();
		require(
			saleEnableTierThree, 
			"ADD: sale is not enable"
		);
        require(
			NFT_MINTED_TIER_THREE + _count <= SALE_NFT_TIER_THREE, 
			"ADD: exceeds max sale nft limit"
		);
		require(
			users[msg.sender].status,
			"ADD: minting not open for this address"
		);
		require(
			users[msg.sender].salemint + _count <= MAX_MINT_SALE,
			"ADD: exceeds max mint limit per wallet"
		);
		require(
			_count <= MAX_BY_MINT_IN_TRANSACTION_SALE,
			"ADD: exceeds max mint limit per txn"
		);
		require(
			msg.value >= SALE_PRICE_TIER_THREE * _count,
			"ADD: value below price"
		);
		for (uint256 i = 0; i < _count; i++) {
            _safeMint(msg.sender, totalSupply + i);
			NFT_MINTED_TIER_THREE++;
        }
		users[msg.sender].salemint = users[msg.sender].salemint + _count;
    }
	
    function tokenURI(uint256 _tokenId) external view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: Nonexistent token");
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0	? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), ".json")) : "";
    }
	
    function transferFrom(address _from, address _to, uint256 _tokenId) public override {
        ERC721P.transferFrom(_from, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public override {
        ERC721P.safeTransferFrom(_from, _to, _tokenId, _data);
    }
	
	function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
	
	function migrateTokens(address tokenAddress, uint256 tokenAmount) external onlyOwner nonReentrant{
       IERC20(tokenAddress).safeTransfer(address(msg.sender), tokenAmount);
    }
	
	function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }
	
	function updateSalePrice(uint256 tierOne, uint256 tierTwo, uint256 tierThree) external onlyOwner {
         SALE_PRICE_TIER_ONE   = tierOne;
	     SALE_PRICE_TIER_TWO   = tierTwo;
	     SALE_PRICE_TIER_THREE = tierThree;
    }
	
	function setSaleStatus(bool tierOne, bool tierTwo, bool tierThree) public onlyOwner {
		saleEnableTierOne = tierOne;
		saleEnableTierTwo = tierTwo;
		saleEnableTierThree = tierThree;
    }
	
	function updateSaleMintLimit(uint256 newLimit) external onlyOwner {
	    require(newLimit > 0, "ADD: incorrect value");
        MAX_MINT_SALE = newLimit;
    }
	
	function updateSaleSupply(uint256 tierOne, uint256 tierTwo, uint256 tierThree) external onlyOwner {
	    require(tierOne >= NFT_MINTED_TIER_ONE, "ADD: incorrect value");
		require(tierTwo >= NFT_MINTED_TIER_TWO, "ADD: incorrect value");
		require(tierThree >= NFT_MINTED_TIER_THREE, "ADD: incorrect value");
		
        SALE_NFT_TIER_ONE   = tierOne;
		SALE_NFT_TIER_TWO   = tierTwo;
		SALE_NFT_TIER_THREE = tierThree;
    }
	
	function updateReservedSupply(uint256 tierOne, uint256 tierTwo, uint256 tierThree) external onlyOwner {
	    require(tierOne >= NFT_MINTED_TIER_ONE_RESERVED, "ADD: incorrect value");
		require(tierTwo >= NFT_MINTED_TIER_TWO_RESERVED, "ADD: incorrect value");
		require(tierThree >= NFT_MINTED_TIER_THREE_RESERVED, "ADD: incorrect value");
		
        RESERVED_NFT_TIER_ONE   = tierOne;
		RESERVED_NFT_TIER_TWO   = tierTwo;
		RESERVED_NFT_TIER_THREE = tierThree;
    }
	
	function updateMintLimitPerTransectionSale(uint256 newLimit) external onlyOwner {
	    require(newLimit > 0, "ADD: incorrect value");
        MAX_BY_MINT_IN_TRANSACTION_SALE = newLimit;
    }
	
	function updateTokenRequiredForMint(uint256 newLimit) external onlyOwner {
	    require(ADDToken.totalSupply() >= newLimit, "ADD: incorrect value");
        TOKEN_REQUIRED_FOR_MINT = newLimit;
    }
	
	function setRoyalties(address recipient, uint256 value) public onlyOwner{
        _setRoyalties(recipient, value);
    }
	
	function updateTokenAddress(address newToken) external onlyOwner {
	    require(newToken != address(0), "ADD: zero address");
        ADDToken = IERC20(newToken);
    }
}