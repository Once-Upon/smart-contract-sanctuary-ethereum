// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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

pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BasicMetaTransaction {

    using SafeMath for uint256;

    event MetaTransactionExecuted(address userAddress, address payable relayerAddress, bytes functionSignature);
    mapping(address => uint256) private nonces;

    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * Main function to be called when user wants to execute meta transaction.
     * The actual function to be called should be passed as param with name functionSignature
     * Here the basic signature recovery is being used. Signature is expected to be generated using
     * personal_sign method.
     * @param userAddress Address of user trying to do meta transaction
     * @param functionSignature Signature of the actual function to be called via meta transaction
     * @param sigR R part of the signature
     * @param sigS S part of the signature
     * @param sigV V part of the signature
     */
    function executeMetaTransaction(address userAddress, bytes memory functionSignature,
        bytes32 sigR, bytes32 sigS, uint8 sigV) public payable returns(bytes memory) {

        require(verify(userAddress, nonces[userAddress], getChainID(), functionSignature, sigR, sigS, sigV), "Signer and signature do not match");
        nonces[userAddress] = nonces[userAddress].add(1);

        // Append userAddress at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(abi.encodePacked(functionSignature, userAddress));

        require(success, "Function call not successful");
        emit MetaTransactionExecuted(userAddress, payable(msg.sender), functionSignature);
        return returnData;
    }

    function getNonce(address user) external view returns(uint256 nonce) {
        nonce = nonces[user];
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function verify(address owner, uint256 nonce, uint256 chainID, bytes memory functionSignature,
        bytes32 sigR, bytes32 sigS, uint8 sigV) public view returns (bool) {

        bytes32 hash = prefixed(keccak256(abi.encodePacked(nonce, this, chainID, functionSignature)));
        address signer = ecrecover(hash, sigV, sigR, sigS);
        require(signer != address(0), "Invalid signature");
		return (owner == signer);
    }

    function msgSender() internal view returns(address sender) {
        if(msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            return msg.sender;
        }
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./BasicMetaTransaction.sol";
// import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

// Author: @avezorgen
contract Escrow is BasicMetaTransaction {
    mapping(bytes32 => details) public deals;
    struct details {
        address buyer;
        address seller;
        uint value;
        uint Bfee;
        uint8 status;
    }

    //buyerConf | sellerConf    = uint8 status
    //     0    |       0       = 0  
    //       created            = 1
    //     1    |       0       = 2
    //     1    |       1       = 3

    address public owner;
    uint public hold;
    uint public limit;

    event Created(address indexed buyer, address indexed seller, bytes32 indexed TxId);
    event BuyerConfim(bytes32 indexed TxId);
    event SellerConfim(bytes32 indexed TxId);
    event Finished(bytes32 indexed TxId);
    event Conflict(bytes32 indexed TxId);

    modifier onlyPerson(address pers) {
        require(msgSender() == pers, "Don't have permission");
        _;
    }

    constructor(uint _limit) {
        owner = msgSender();
        hold = 0;
        limit = _limit;
    }

    function getFee(uint value) internal pure returns(uint fee){
        fee = value / 1e2 * 2;
    }

    function create(address buyer, address seller, uint value, uint8 feeStyle) external {
        require(msgSender() == buyer || msgSender() == seller, "Don't have permission");
        require(value != 0, "Can't provide deal with 0 value");
        bytes32 TxId = keccak256(abi.encode(buyer, seller, block.timestamp));
        require(deals[TxId].value == 0, "Deal already exists");
        require(feeStyle <= 2, "Wrong feeStyle");
        uint Bfee = 0;
        if (feeStyle == 0) Bfee = getFee(value);
        else if (feeStyle == 1) Bfee = getFee(value) / 2;
        deals[TxId] = details(buyer, seller, value - Bfee, Bfee, 1);
        emit Created(buyer, seller, TxId);
    }

    function sendB(bytes32 TxId) external payable onlyPerson(deals[TxId].buyer) {
        require(msg.value == deals[TxId].value + deals[TxId].Bfee, "Wrong money value");
        require(deals[TxId].status == 1, "Money was already sent");
        deals[TxId].status = 2;
        emit BuyerConfim(TxId);
    }

    function sendS(bytes32 TxId) external onlyPerson(deals[TxId].seller) {
        require(deals[TxId].status == 2, "Money was not sent or Subject was already sent");
        deals[TxId].status = 3;
        emit SellerConfim(TxId);
    }

    function cancel(bytes32 TxId) external {
        require(msgSender() == deals[TxId].buyer || msgSender() == deals[TxId].seller, "Don't have permission");
        require(deals[TxId].status != 3, "Can't be cancelled already");
        if (deals[TxId].status == 2) {
            if (msgSender() == deals[TxId].seller) {
                emit Conflict(TxId); //seller отменил сделку, когда buyer уже отправил деньги
            }
            payable(deals[TxId].buyer).transfer(deals[TxId].value + deals[TxId].Bfee);
        }
        delete deals[TxId];
        emit Finished(TxId);
    }

    function approve(bytes32 TxId) external onlyPerson(deals[TxId].buyer) {
        require(deals[TxId].status == 3, "Seller did not confirm the transaction");
        uint InpValue = deals[TxId].value + deals[TxId].Bfee;
        uint fee = getFee(InpValue);
        hold += fee;
        payable(deals[TxId].seller).transfer(InpValue - fee);
        delete deals[TxId];
        emit Finished(TxId);
    }

    function disapprove(bytes32 TxId) external onlyPerson(deals[TxId].buyer) {
        require(deals[TxId].status == 3, "Seller did not confirm the transaction");
        hold += deals[TxId].Bfee;
        payable(msgSender()).transfer(deals[TxId].value); //buyer отправлял и seller отправлял
        delete deals[TxId];
        emit Finished(TxId);
    }

    function withdraw(address target) external onlyPerson(owner) {
        payable(target).transfer(hold);
        hold = 0;
    }

    function setOwner(address newOwner) external onlyPerson(owner) {
        owner = newOwner;
    }

    function setLimit(uint newlimit) external onlyPerson(owner)  {
        limit = newlimit;
    }

    // function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
    //     upkeepNeeded = hold > limit;
    // }

    // function performUpkeep(bytes calldata /* performData */) external override {
    //     if (hold > limit) {
    //         payable(owner).transfer(hold);
    //         hold = 0;
    //     }
    // }
    
    receive() external payable {
        hold += msg.value;
    }
}