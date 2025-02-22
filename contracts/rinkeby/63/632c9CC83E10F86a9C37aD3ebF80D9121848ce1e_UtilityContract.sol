//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


interface NFTAddress {
    function tokenURI(uint256) external view returns (string memory);
    function uri(uint256) external view returns (string memory);
}

interface TokenBalance {
    function balanceOf(address) external view returns (uint256); 
}

interface OpenSea {
    function getOrderStatus(bytes32 orderHash) external view returns (
        bool, bool, uint256, uint256);
}

interface LooksRare {
    function isUserOrderNonceExecutedOrCancelled(address, uint256) external view returns (bool);
}

interface X2Y2 {
    function inventoryStatus(bytes32) external view returns (uint8);
}

interface NFTBalance {
    function balanceOf(address) external view returns (uint256);
    function ownerOf(uint256) external view returns (address); 
}

interface ERC1155 {
    function balanceOf(address, uint256) external view returns (uint256);
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

contract UtilityContract is Ownable {

    address private _weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
    address private _usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // mainnet
    address private _usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // mainnet

    // address private _usdt = 0x3B00Ef435fA4FcFF5C209a37d1f3dcff37c705aD; // Rinkeby
    // address private _usdc = 0xeb8f08a975Ab53E34D8a0330E0D34de942C95926; // Rinkeby 
    // address private _weth = 0xc778417E063141139Fce010982780140Aa0cD5Ab; // Rinkeby

    address public openseaAddress = 0x00000000006c3852cbEf3e08E8dF289169EdE581; // Mainnet
    address public looksRareAddress = 0x59728544B08AB483533076417FbBB2fD0B17CE3a; // Mainnet 
    address public x2y2Address = 0x74312363e45DCaBA76c59ec49a7Aa8A65a67EeD3; // Mainnet
    
    struct tokenBalances {
        uint256 ETH;
        uint256 WETH;
        uint256 USDC;
        uint256 USDT;
    }

    struct OrderStatus {
        bool isValidated;
        bool isCancelled;
        uint256 totalFilled;
        uint256 totalSize;
    }

    struct BluechipContract {
        address _address;
        string _name;
        string _image;
    } 

    struct ListingValidator {
        address ERC721Owner;
        uint256 ERC1155Quantity;
        OrderStatus seaportOrderStatus;
        bool looksRareOrderStatus;
        uint8 x2y2OrderStatus;
        bool IsApprovedForAll;
    }

    mapping (address => BluechipContract) public getBluechipContract;

    constructor() {}

    function updateOpenSeaAddress(address _address) external onlyOwner {
        openseaAddress = _address;
    }

    function updateLooksRareAddress(address _address) external onlyOwner {
        looksRareAddress = _address;
    }

    function updateX2Y2Address(address _address) external onlyOwner {
        x2y2Address = _address;
    }

    function updateTokenAddress(address _wethAddress, address _usdcAddress, address _usdtAddress) external onlyOwner {
        _weth = _wethAddress;
        _usdc = _usdcAddress;
        _usdt = _usdtAddress;
    }

    function getTokenUri(address _address, uint256[] memory _tokenID) public view returns (string[] memory) {
        string[] memory listOfTokenURI = new string[](_tokenID.length);
        for(uint256 i=0; i<_tokenID.length; i++){
            try NFTAddress(_address).tokenURI(_tokenID[i]) {
                listOfTokenURI[i] =  NFTAddress(_address).tokenURI(_tokenID[i]);
            }
            catch {
                try NFTAddress(_address).uri(_tokenID[i]) {
                    listOfTokenURI[i] = NFTAddress(_address).uri(_tokenID[i]);
                }
                catch {
                    listOfTokenURI[i] = "Error in Token";
                }
            }
        }
        return listOfTokenURI; 
    }

    function getTokenBalances(address _address) public view returns (tokenBalances memory) {
        tokenBalances memory _tokenBalance;
        _tokenBalance.ETH = address(_address).balance;
        _tokenBalance.WETH = TokenBalance(_weth).balanceOf(_address);
        _tokenBalance.USDC = TokenBalance(_usdc).balanceOf(_address);
        _tokenBalance.USDT = TokenBalance(_usdt).balanceOf(_address);
        return _tokenBalance;
    }

    function getNFTBalances(address _address, address[] memory _contractAddress) public view returns (uint256[] memory, bool[] memory) {
        uint256[] memory nftBalances = new uint256[](_contractAddress.length);
        bool[] memory failedTx = new bool[](_contractAddress.length);
        for(uint256 i=0; i<_contractAddress.length; i++){
            try NFTBalance(_contractAddress[i]).balanceOf(_address) {
                nftBalances[i] = NFTBalance(_contractAddress[i]).balanceOf(_address);
                failedTx[i] = false;
            }
            catch {
                nftBalances[i] = 0;
                failedTx[i] = true;
            }
        }
        return (nftBalances,failedTx);
    }

    function getUserData(address _address, address[] memory _contractAddress) external view returns (tokenBalances memory, uint256[] memory, bool[] memory) {
        uint256[] memory nftBalances = new uint256[](_contractAddress.length);
        bool[] memory failedTx = new bool[](_contractAddress.length);
        (nftBalances, failedTx) = getNFTBalances(_address, _contractAddress);
        return (getTokenBalances(_address),nftBalances, failedTx);
    }

    function getOrderStatus(bytes32 _orderHash) public view returns (OrderStatus memory, bool) {
        OrderStatus memory orderStatus; 
        bool failedTx;
        try OpenSea(openseaAddress).getOrderStatus(_orderHash) {
            (orderStatus.isValidated,orderStatus.isCancelled, orderStatus.totalFilled, orderStatus.totalSize) = OpenSea(openseaAddress).getOrderStatus(_orderHash);
            failedTx = false;
        }
        catch {
            failedTx = true;
        }
        return (orderStatus,failedTx);
    }

    function getMultipleOrderStatus(bytes32[] memory _orderHash) public view returns (OrderStatus[] memory, bool[] memory){
        OrderStatus[] memory orderStatus = new OrderStatus[](_orderHash.length);
        bool[] memory failedTx = new bool[](_orderHash.length);
        for(uint256 i=0; i<_orderHash.length; i++){
            (orderStatus[i], failedTx[i]) = getOrderStatus(_orderHash[i]);
        } 
        return (orderStatus, failedTx);
    }

    function getUserOrderNonceExecutedOrCancelled(address _address, uint256 _orderNonce) public view returns (bool, bool) {
        bool failedTx;
        bool result;
        try LooksRare(looksRareAddress).isUserOrderNonceExecutedOrCancelled(_address, _orderNonce) {
            result = LooksRare(looksRareAddress).isUserOrderNonceExecutedOrCancelled(_address, _orderNonce);
            failedTx = false;
        }
        catch {
            failedTx = true;
        }
        return (result, failedTx);
    }

    function getMultipleUserOrderNonce(address[] memory _address, uint256[] memory _orderNonce) public view returns (bool[] memory, bool[] memory) {
        require(_address.length == _orderNonce.length, "Length of Array's Passed not equal");
        bool[] memory status = new bool[](_address.length);
        bool[] memory failedTx = new bool[](_address.length);
        for(uint256 i=0; i<_address.length; i++) {
            (status[i], failedTx[i]) = getUserOrderNonceExecutedOrCancelled(_address[i], _orderNonce[i]);
        }
        return (status, failedTx);
    }

    function getInventoryStatusX2Y2(bytes32 _bytes) public view returns (uint8, bool) {
        uint8 result;
        bool failedTx;
        try X2Y2(x2y2Address).inventoryStatus(_bytes) {
            result = X2Y2(x2y2Address).inventoryStatus(_bytes);
            failedTx = false;
        }
        catch {
            failedTx = true;
        }
        return (result, failedTx);
    }

    function getMultipleInventoryStatusX2Y2(bytes32[] memory _bytes) public view returns (uint8[] memory, bool[] memory) {
        uint8[] memory _int8 = new uint8[](_bytes.length);
        bool[] memory failedTx = new bool[](_bytes.length);
        for(uint256 i=0; i<_bytes.length; i++) {
            (_int8[i], failedTx[i]) = getInventoryStatusX2Y2(_bytes[i]);
        }
        return (_int8, failedTx);
    }

    function getAllMarketData(bytes32[] memory _seaportBytes, address[] memory _looksrareAddress, uint256[] memory _looksRareOrderNonce, bytes32[] memory _x2y2Bytes) 
    external view returns (OrderStatus[] memory, bool[] memory, uint8[] memory, bool[] memory, bool[] memory, bool[] memory) {
        require(_looksrareAddress.length == _looksRareOrderNonce.length, "Length should be equal");
        // OrderStatus[] memory seaPortOrder = new OrderStatus[](_seaportBytes.length);
        (OrderStatus[] memory seaportOrder,bool[] memory failedTx1) = getMultipleOrderStatus(_seaportBytes);
        (bool[] memory looksrareStatus, bool[] memory failedTx2) = getMultipleUserOrderNonce(_looksrareAddress, _looksRareOrderNonce);
        (uint8[] memory _x2y2Int8, bool[] memory failedTx3) = getMultipleInventoryStatusX2Y2(_x2y2Bytes);
        return (seaportOrder, looksrareStatus, _x2y2Int8, failedTx1, failedTx2, failedTx3);
    }

    function getERC721Balance(address[] memory _address, address _contractAddress) public view returns (uint256[] memory) {
        uint256[] memory _balanceERC721 = new uint256[](_address.length);
        for(uint256 i=0; i < _address.length; i++) {
            _balanceERC721[i] = NFTBalance(_contractAddress).balanceOf(_address[i]);
        }
        return _balanceERC721;
    }

    function getERC721Owner(uint256[] memory _tokenId, address _contractAddress) public view returns (address[] memory, bool[] memory) {
        address[] memory _addressERC721 = new address[](_tokenId.length);
        bool[] memory failedTx = new bool[](_tokenId.length);
        for(uint256 i=0; i < _tokenId.length; i++) {
            try NFTBalance(_contractAddress).ownerOf(_tokenId[i]) {
                _addressERC721[i] = NFTBalance(_contractAddress).ownerOf(_tokenId[i]);
                failedTx[i] = false;
            }
            catch {
                failedTx[i] = true;
            }
        }
        return (_addressERC721, failedTx);
    }

    function getERC1155Balance(address[] memory _address, uint256[] memory _tokenId, address _contractAddress) public view returns (uint256[] memory, bool[] memory) {
        require(_address.length == _tokenId.length, "Length Should be equal");
        uint256[] memory _balanceERC1155 = new uint256[](_address.length);
        bool[] memory failedTx = new bool[](_address.length);
        for(uint256 i=0; i < _address.length; i++) {
            try ERC1155(_contractAddress).balanceOf(_address[i],_tokenId[i]) {
                _balanceERC1155[i] = ERC1155(_contractAddress).balanceOf(_address[i],_tokenId[i]);
                failedTx[i] = false;
            }
            catch {
                failedTx[i] = true;
            }
        }
        return (_balanceERC1155, failedTx);
    }

    function checkIsApprovedForAll(address _owner, address _operator, address _contract) public view returns (bool, bool) {
        try ERC1155(_contract).isApprovedForAll(_owner, _operator) {
            return (ERC1155(_contract).isApprovedForAll(_owner, _operator), false);
        }
        catch {
            return (ERC1155(_contract).isApprovedForAll(_owner, _operator), true);
        }
    }

    function checkMultipleIsApprovedForAll(address[] memory _owner, address[] memory _operator, address _contract) public view returns (bool[] memory, bool[] memory) {
        require(_owner.length == _operator.length, "Length of Owner Array & Operator Not the same");
        bool[] memory _status = new bool[](_owner.length);
        bool[] memory failedTx = new bool[](_owner.length);
        for(uint256 i=0; i<_owner.length; i++) {
            (_status[i], failedTx[i]) = checkIsApprovedForAll(_owner[i], _operator[i], _contract);
        }
        return (_status, failedTx);
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function validateContractListing(address contract_address, uint256 token_id, string memory token_standard, address from_address, address operator_address, string memory marketPlace, bytes32 order_hash, uint256 nonce) public view returns (ListingValidator memory, bool) {
        ListingValidator memory _listingValidator;
        bool failedTx = false;
        bool failedTx2 = false;
        
        if(compareStrings(token_standard, "ERC721")){
            _listingValidator.ERC721Owner = NFTBalance(contract_address).ownerOf(token_id);
        }
        else if(compareStrings(token_standard, "ERC1155")){
            _listingValidator.ERC1155Quantity = ERC1155(contract_address).balanceOf(from_address,token_id);
        }

        if(compareStrings(marketPlace, "Seaport")){
            (_listingValidator.seaportOrderStatus, failedTx) = getOrderStatus(order_hash);
        }
        else if(compareStrings(marketPlace, "LooksRare")){
            (_listingValidator.looksRareOrderStatus, failedTx) = getUserOrderNonceExecutedOrCancelled(contract_address, nonce);
        }
        else if(compareStrings(marketPlace, "X2Y2")){
            (_listingValidator.x2y2OrderStatus, failedTx) = getInventoryStatusX2Y2(order_hash);
        }

        (_listingValidator.IsApprovedForAll, failedTx2) = checkIsApprovedForAll(from_address, operator_address, contract_address);

        return (_listingValidator, failedTx || failedTx2);
    }

    function accessBalanceNFT721(address _address, address[] memory _contractAddress) view public returns (uint256[] memory, bool[] memory) {
        uint256[] memory nftBalances = new uint256[](_contractAddress.length);
        bool[] memory failedTx = new bool[](_contractAddress.length);

        for(uint256 i=0; i<_contractAddress.length; i++){
            try NFTBalance(_contractAddress[i]).balanceOf(_address) {
                nftBalances[i] = NFTBalance(_contractAddress[i]).balanceOf(_address);
                failedTx[i] = false;
            }
            catch {
                nftBalances[i] = 0;
                failedTx[i] = true;
            }
        }
        return (nftBalances, failedTx);
    }

    function accessBalanceNFT1155(address _address, address[] memory _contractAddress, uint256[] memory _tokenIds) view public returns (uint256[] memory, bool[] memory) {
        require(_contractAddress.length == _tokenIds.length, "Length of contract address and token id's need to be same");
        uint256[] memory nftBalances = new uint256[](_contractAddress.length);
        bool[] memory failedTx = new bool[](_contractAddress.length);

        for(uint256 i=0; i<_contractAddress.length; i++){
            try ERC1155(_contractAddress[i]).balanceOf(_address,_tokenIds[i]) {
                nftBalances[i] = ERC1155(_contractAddress[i]).balanceOf(_address,_tokenIds[i]);
                failedTx[i] = false;
            }
            catch {
                failedTx[i] = true;
            }
        }
        return (nftBalances, failedTx);
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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