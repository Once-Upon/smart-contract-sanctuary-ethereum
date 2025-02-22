// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interface/INFTSwap.sol";
import "./interface/IERC20.sol";
import "./interface/IERC721.sol";
import "./interface/IERC1155.sol";

contract NFTSwapBoxWhitelist is INFTSwap, Ownable, AccessControl {

    bytes32 public constant USER_ROLE = keccak256("USER");
    SwapBoxConfig private swapConfig;
    address[] public whitelistERC20Tokens;
    address[] public whitelistERC721Tokens;
    address[] public whitelistERC1155Tokens;

    /// @dev Add `root` to the admin role as a member.
    constructor(address root) {
        _setupRole(DEFAULT_ADMIN_ROLE, root);
        _setRoleAdmin(USER_ROLE, DEFAULT_ADMIN_ROLE);
        swapConfig.usingERC721WhiteList = true;
        swapConfig.usingERC1155WhiteList = true;
        swapConfig.NFTTokenCount = 5;
        swapConfig.ERC20TokenCount = 5;
    }

    /// @dev Restricted to members of the admin role.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Restricted to admins.");
        _;
    }

    /// @dev Return `true` if the account belongs to the admin role.
    function isAdmin(address account) public virtual view returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// @dev Add an account to the admin role. Restricted to admins.
    function addAdmin(address account) public virtual onlyAdmin
    {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
        SetSwapConfig(usingERC721WhiteList, usingERC1155WhiteList, NFTTokenCount, ERC20TokenCount)
     */

    function setUsingERC721Whitelist(bool usingList) external onlyOwner onlyAdmin {
        swapConfig.usingERC721WhiteList = usingList;
    }

    function setUsingERC1155Whitelist(bool usingList) external onlyOwner onlyAdmin {
        swapConfig.usingERC1155WhiteList = usingList;
    }

    function setNFTTokenCount(uint256 limitTokenCount) external onlyOwner onlyAdmin {
        swapConfig.NFTTokenCount = limitTokenCount;
    }

    function setERC20TokenCount(uint256 limitERC20Count) external onlyOwner onlyAdmin {
        swapConfig.ERC20TokenCount = limitERC20Count;
    }
    /**
    Getting swapConfig((usingERC721WhiteList, usingERC1155WhiteList, NFTTokenCount, ERC20TokenCount))
    */
    function getSwapConfig() external view returns(SwapBoxConfig memory) {
        return swapConfig;
    }
    /**
        check assets for creating swapBox
     */
    function _checkAssets(
        ERC721Details[] memory erc721Details,
        ERC20Details memory erc20Details,
        ERC1155Details[] memory erc1155Details,
        address offer,
        address swapBox
    ) external view {
        require(
            (erc721Details.length + erc1155Details.length) <=
                swapConfig.NFTTokenCount,
            "Too much NFTs selected"
        );

        for (uint256 i = 0; i < erc721Details.length; i++) {
            require(
                validateWhiteListERC721Token(erc721Details[i].tokenAddr),
                "Not Allowed ERC721 Token"
            );
            require(
                erc721Details[i].ids.length > 0,
                "Non included ERC721 token"
            );

            for (uint256 j = 0; j < erc721Details[i].ids.length; j++) {
                require(
                    IERC721(erc721Details[i].tokenAddr).getApproved(
                        erc721Details[i].ids[j]
                    ) == swapBox || IERC721(erc721Details[i].tokenAddr).isApprovedForAll(offer,swapBox) == true,
                    "ERC721 tokens must be approved to swap contract"
                );
            }
        }

        // check duplicated token address
        require(
            erc20Details.tokenAddrs.length <= swapConfig.ERC20TokenCount,
            "Too much ERC20 tokens selected"
        );
        for (uint256 i = 0; i < erc20Details.tokenAddrs.length; i++) {
            uint256 tokenCount = 0;
            for (uint256 j = 0; j < erc20Details.tokenAddrs.length; j++) {
                if (erc20Details.tokenAddrs[i] == erc20Details.tokenAddrs[j]) {
                    tokenCount++;
                }
            }

            require(tokenCount == 1, "Invalid ERC20 tokens");
        }

        for (uint256 i = 0; i < erc20Details.tokenAddrs.length; i++) {
            require(
                validateWhiteListERC20Token(erc20Details.tokenAddrs[i]),
                "Not Allowed ERC20 Tokens"
            );
            require(
                IERC20(erc20Details.tokenAddrs[i]).allowance(
                    offer,
                    swapBox
                ) >= erc20Details.amounts[i],
                "ERC20 tokens must be approved to swap contract"
            );
            require(
                IERC20(erc20Details.tokenAddrs[i]).balanceOf(offer) >=
                    erc20Details.amounts[i],
                "Insufficient ERC20 tokens"
            );
        }

        for (uint256 i = 0; i < erc1155Details.length; i++) {
            require(
                validateWhiteListERC1155Token(erc1155Details[i].tokenAddr),
                "Not Allowed ERC1155 Token"
            );
            for (uint256 j = 0; j < erc1155Details[i].ids.length; j++) {
                require(
                    IERC1155(erc1155Details[i].tokenAddr).balanceOf(
                        offer,
                        erc1155Details[i].ids[j]
                    ) > 0,
                    "This token not exist"
                );
                require(
                    IERC1155(erc1155Details[i].tokenAddr).isApprovedForAll(
                        offer,
                        swapBox
                    ),
                    "ERC1155 token must be approved to swap contract"
                );
            }
        }
    }
    /**
        add tokens to Whitelist
     */

    function addWhiteListToken(address erc20Token) external onlyOwner  {
        require(
            validateWhiteListERC20Token(erc20Token) == false,
            "Exist Token"
        );
        whitelistERC20Tokens.push(erc20Token);
    }

    function addWhiliteListERC721Token(address erc721Token) external onlyOwner onlyAdmin {
        require(
            validateWhiteListERC721Token(erc721Token) == false,
            "Exist Token"
        );
        whitelistERC721Tokens.push(erc721Token);
    }

    function addWhiliteListERC1155Token(address erc1155Token)
        external
        onlyOwner onlyAdmin
    {
        require(
            validateWhiteListERC1155Token(erc1155Token) == false,
            "Exist Token"
        );
        whitelistERC1155Tokens.push(erc1155Token);
    }
    /**
        Get function for whitelist
     */

    function getERC20WhiteListTokens() public view returns (address[] memory) {
        return whitelistERC20Tokens;
    }

    function getERC721WhiteListTokens() public view returns (address[] memory) {
        return whitelistERC721Tokens;
    }

    function getERC1155WhiteListTokens()
        public
        view
        returns (address[] memory)
    {
        return whitelistERC1155Tokens;
    }

    /**
        RemoveToken from WhiteList
     */
    function removeFromERC20WhiteList(uint256 index) external onlyOwner  {
        require(index < whitelistERC20Tokens.length, "Invalid element");
        whitelistERC20Tokens[index] = whitelistERC20Tokens[
            whitelistERC20Tokens.length - 1
        ];
        whitelistERC20Tokens.pop();
    }

    function removeFromERC721WhiteList(uint256 index) external onlyOwner onlyAdmin {
        require(index < whitelistERC721Tokens.length, "Invalid element");
        whitelistERC721Tokens[index] = whitelistERC721Tokens[
            whitelistERC721Tokens.length - 1
        ];
        whitelistERC721Tokens.pop();
    }

    function removeFromERC1155WhiteList(uint256 index) external onlyOwner onlyAdmin {
        require(index < whitelistERC1155Tokens.length, "Invalid element");
        whitelistERC1155Tokens[index] = whitelistERC1155Tokens[
            whitelistERC1155Tokens.length - 1
        ];
        whitelistERC1155Tokens.pop();
    }

    // Checking whitelist ERC20 Token
    function validateWhiteListERC20Token(address erc20Token)
        public
        view
        returns (bool)
    {
        for (uint256 i = 0; i < whitelistERC20Tokens.length; i++) {
            if (whitelistERC20Tokens[i] == erc20Token) {
                return true;
            }
        }

        return false;
    }

    // Checking whitelist ERC721 Token
    function validateWhiteListERC721Token(address erc721Token)
        public
        view
        returns (bool)
    {
        if (!swapConfig.usingERC721WhiteList) return true;

        for (uint256 i = 0; i < whitelistERC721Tokens.length; i++) {
            if (whitelistERC721Tokens[i] == erc721Token) {
                return true;
            }
        }

        return false;
    }

    // Checking whitelist ERC1155 Token
    function validateWhiteListERC1155Token(address erc1155Token)
        public
        view
        returns (bool)
    {
        if (!swapConfig.usingERC1155WhiteList) return true;

        for (uint256 i = 0; i < whitelistERC1155Tokens.length; i++) {
            if (whitelistERC1155Tokens[i] == erc1155Token) {
                return true;
            }
        }

        return false;
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
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

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
     *
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleRevoked} event.
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
     *
     * May emit a {RoleRevoked} event.
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
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface INFTSwap {

    event SwapBoxState (
        uint256 swapItemID,
        address owner,
        State state,
        uint256 createdTime,
        uint256 updateTime,
        uint256 gasTokenAmount,
        ERC721Details[] erc721Tokens,
        ERC20Details erc20Tokens,
        ERC1155Details[] erc1155Tokens
    );

    event SwapBoxOffer(
        uint256 listSwapBoxID,
        uint256 offerSwapBoxID
    );

    event SwapBoxWithDrawOffer(
        uint256 listSwapBoxID,
        uint256 offerSwapBoxID
    );

    event SwapBoxDeList(
        uint256 listSwapBoxID,
        State state,
        BoxOffer[] offers
    );

    event SwapBoxDeOffer(
        uint256 offerSwapBoxID,
        State state,
        BoxOffer[] offers
    );

    event Swaped (
        uint256 listID,
        address listOwner,
        uint256 offerID,
        address offerOwner
    );

    struct ERC20Details {
        address[] tokenAddrs;
        uint256[] amounts;
    }
    struct ERC721Details {
        address tokenAddr;
        uint256[] ids;
    }
    struct ERC1155Details {
        address tokenAddr;
        uint256[] ids;
        uint256[] amounts;
    }

    struct BoxOffer {
        uint256 boxID;
        bool active;
    }

    struct ERC20Fee {
        address tokenAddress;
        uint256 feeAmount;
    }

    struct RoyaltyFee {
        address reciever;
        uint256 feeAmount;
    }
    
    struct SwapBox {
        uint256 id;
        address owner;
        ERC721Details[] erc721Tokens;
        ERC20Details erc20Tokens;
        ERC1155Details[] erc1155Tokens;
        uint256 gasTokenAmount;
        uint256 createdTime;
        State state;
        BoxOffer[] offers;
        uint256 nftSwapFee;
        ERC20Fee[] erc20Fees;
        uint256 gasTokenFee;
        RoyaltyFee[] boxRoyaltyFee;
    }

    struct SwapBoxConfig {
        bool usingERC721WhiteList;
        bool usingERC1155WhiteList;
        uint256 NFTTokenCount;
        uint256 ERC20TokenCount;
    }

    

    enum State {
        Initiated,
        Waiting_for_offers,
        Offered,
        Destroyed
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;
interface IERC721{
    function balanceOf(address owner) external view returns (uint256 balance);
    function safeTransferFrom(address from,address to,uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
interface IERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
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