// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
// TODO https://medium.com/@thelasthash/%EF%B8%8F-gas-optimization-with-hardhat-1e553eaea311
// TODO GAS https://www.npmjs.com/package/hardhat-gas-reporter
// TODO security
// 


// TODO calldata
// TODO bytes32 - string
// TODO uint usage - packing optimization



//  ..                                                 
//                        .        :kk:        .                                       
//                    .;oo'       cO00Oc       ,ol,.                                   
//                  .lKW0,      .cO0000Oc.      ,0WKl.                                 
//                 .xWMO'      .l00000000l.      'OMWd.                                
//                .xWMM0,      ;O00000000O;      ,0MMWx.                               
//               .kWMMMM0,     .l00000000l.     ,0MMMMWx.                              
//              .kWMMMMMMK;     .l00000Ol.     ;KMMMMMMWk.                             
//              ,KMMMMMMMMK;     .cO00Oc.     ;KMMMMMMMMK,                             
//               ;KMMMMMMMMK:      ckkc      :KMMMMMMMMK;                              
//                ,0MMMMMMMMX:      ..      :XMMMMMMMM0,                               
//                 ,0MMMMMMMMXc            cXMMMMMMMM0,                                
//                  'OWMMMMMMMXc          cXMMMMMMMMO'                                 
//                   .OWMMMMMMMNl        lNMMMMMMMWO.                                  
//                    .kWMMMMMMMNo.    .oNMMMMMMMWk.                                   
//                     .kWMMMMMMMNo.  .oNMMMMMMMWk.                                    
//                      .xWMMMMMMMWo''oWMMMMMMMWx.                                     
//                ..     .xWMMMMMMMWXXWMMMMMMMWx.     ..                               
//               'lc.     .dWMMMMMMMMMMMMMMMMWd.     .ox,                              
//              'looc.     .oNMMMMMMMMMMMMMMNo.     'dkkx;                             
//             ,odoodl.     .oNMMMMMMMMMMMMNo.     'dkkkkx;                            
//            ,oooooodl.     .lNMMMMMMMMMMNl.     ,dkkkkkkx;                           
//           ,ooooooooo;       lXMMMMMMMMXl       ckkkkkkkkx:                          
//          ;ooooooooo:.        cXMMMMMMXc        .ckkkkkkkkx:.                        
//         ;ooooooooo;.          :XMMMMX:          .ckkkkkkkkkc.                       
//        ;ooooooooo;             :XMMX:            .ckkkkkkkkkc.                      
//      .;ooooooooo;               :kk:              .:xkkkkkkkkc.                     
//     .:oooooooool,.                                .:xkkkkkkkkkl.                    
//     ,cccccccccccc:,.                           .':lddodddoododo;                    
//                                                 ................   
contract CryptaSubscription is Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;

    constructor() { 
        subscriptionTypes[1] = SubscriptionType(1, "light");
        subscriptionTypes[2] = SubscriptionType(2, "plus");
        subscriptionTypes[3] = SubscriptionType(3, "pro");
        subscriptionTypes[4] = SubscriptionType(4, "builder");
        subscriptionTypes[5] = SubscriptionType(5, "partner");

        _subscriptionTypesNum = 4;

        subscriptionTimes[1] = SubscriptionTime(1, 30, "month");
        subscriptionTimes[2] = SubscriptionTime(2, 365, "year");
        _subscriptionTimesNum = 2;

        _subscriptionSigner = _msgSender();
    }
    // prevent double payment of the same sub
    modifier isSubActive(string calldata subId) {
        require(!subscriptions[subId], "SUB_ACTIVE");
        _;
    }
    // validate amount
    modifier validateAmount(uint256 _amount) {
        require(msg.value == _amount, "INVALID_AMOUNT");
        _;
    }
    // validate affiliate address
    modifier validateAffiliateAddress(address _affiliateAddress) {
        require(_affiliateAddress != address(0), "ZERO_ADDRESS_FORBIDDEN");
        _;
    }
    
    /** 
     * @dev array for holding the subscribers with subscription end timestamp
     */ 
    struct Subscription {
        string subId;
        uint64 affiliateFee;
        uint64 typeId;
        uint64 timeId;
        uint256 amount;
        uint256 endTime;
        address tokenAddress;
        address affiliateAddress;
    }

    struct Payment {
        string subId;
        uint64 typeId;
        uint64 timeId;
        uint256 amount;
        address tokenAddress;
    }

    struct Affiliate {
        uint64 affiliateFee;
        address affiliateAddress;
    }

    /** 
     * @dev subscription describer
     */ 
    struct SubscriptionType {
        uint64 id;
        string name;
    }

    /** 
     * @dev structure of an order
     * order id is generated by a connected dapp
     */
    struct Order {
        address buyer; 
        string orderId;
        uint64 amount;
    }
    /**
     * @dev baseTimeUnit for calculation is week, 
     * subLength is daily based, as we set the sub end time based on this
     */
    struct SubscriptionTime {
        uint64 id;
        uint64 subLength;
        string name;
    }

    address private _subscriptionSigner; 
    /**
    * Project Gnosis Wallet
    */
    address payable public vaultWallet; 

    /** 
     * @dev array for holding the interfaces of the contracts which can be involved in the subscription
     */
    address[] passes;
    mapping(address => Subscription) public subscribers;
    mapping(string => bool) public subscriptions;
    mapping(string => Order) public orders;
    mapping(uint64 => SubscriptionType) public subscriptionTypes;
    mapping(uint64 => SubscriptionTime) public subscriptionTimes;
    
    uint64 public immutable baseTimeUnit = 1 days;
    uint64 public ordersNum;
    uint64 public subscriptionsNum;
    
    uint64 private _subscriptionTimesNum;
    uint64 private _subscriptionTypesNum;
    
    event Subscribed(
        address indexed from,
        string subId, 
        string subTypeName,
        string subTimeName
    );

    /**
     * Does the given user member of a collection, which was granted Crypta acees as a whole?
     * @param _user The wallet address of the user.
     */
    function hasActivePass (address _user) external view returns(address, bool) {
        IERC721 helper;
        uint256 length = passes.length;

        for (uint i = 0; i < length;) {
            helper = IERC721(passes[i]);
            if (helper.balanceOf(_user) > 0) {
                return (passes[i], true);
            }
            unchecked { ++i; }
        }

        return (_user, false);
    }

    function getSubscription(string calldata _subId) external view returns(bool) {
        return subscriptions[_subId];
    }

    function setSubscriptionSigner(address signer) external onlyOwner {
        _subscriptionSigner = signer;
    }

    function setVaultWallet(address payable wallet) external onlyOwner {
        vaultWallet = wallet;
    }

    /**
     * Checks if the given address has an active subscription. Exceptional collections has by default.
     */
    function hasActiveSubscription(address _user) external view returns(Subscription memory) {
        if (block.timestamp < subscribers[_user].endTime) {
            return subscribers[_user];
        }

        Subscription memory empty;
        return empty;
    }

     /**
     * Adds a collection to the full access list. 
     * All the collection owners will have access to Crypta basic.
     */
    function setPass(address _contractAddress) external onlyOwner {
        passes.push(_contractAddress);
    }
    /**
     * Removes a collection from the full access list.
     */
    function removePass(address _contractAddress) external onlyOwner {
        uint256 length = passes.length;
        require(length > 0, "PASSES_EMPTY");
        for (uint i = 0; i < length;) {
            if (passes[i] == _contractAddress) {
                passes[i] = passes[length - 1];
                passes.pop();
            }
            unchecked { ++i; }
        }
    }

    /**
     * Owner can only gift monthly subscription, but for any tier
     */
    function giftSubscription(
        address _user,
        Payment calldata payment,
        Affiliate calldata affiliate
    ) external onlyOwner {
        require(subscriptionTypes[payment.typeId].id == payment.typeId, "INVALID_SUBTYPE");
        require(subscriptionTimes[payment.timeId].id == payment.timeId, "INVALID_INTERVAL");
       
        _handleSubscription (
            _user,
            payment,
            affiliate
        );
    }

    /**
     * Owner can create a new subscription time.
     * @param _subLength How many days does this timeframe contains? This is needed for end date calculation.
     * @param _name The fantasy name if the time period.
     */
    function addSubscriptionTime (
        uint16 _subLength,
        string memory _name) external onlyOwner {
        _subscriptionTimesNum++;

        subscriptionTimes[_subscriptionTimesNum] = SubscriptionTime(
            _subscriptionTimesNum,
            _subLength,
            _name
        ); 
    }

    /**
     * Owner can edit subscription time.
     */
    function editSubscriptionTime (
        uint64 _subTimeId,
        uint64 _subLength,
        string memory _name
    ) external onlyOwner {
        require(subscriptionTimes[_subTimeId].id == _subTimeId, "INVALID_SUBTIME");
        
        subscriptionTimes[_subTimeId].subLength = _subLength;
        subscriptionTimes[_subTimeId].name = _name;
    }
    
    /**
     * Owner can create a new subscription tier
     * Example: (0.1, "builder") will create a tier named "builder" with a price 0.1 ether
     * Basic understanding: the price is for one month
     * @param _name The fantasy name of the tier.
     */
    function addSubscriptionType(
        string calldata _name
    ) external onlyOwner {
        _subscriptionTypesNum++;
        subscriptionTypes[_subscriptionTypesNum] = SubscriptionType(_subscriptionTypesNum, _name);
    }

    /**
     * Owner can edit subscription tier based on tier id.
     */
    function editSubscriptionType(
        uint64 _subTypeId, 
        string memory _name
    ) external onlyOwner {
        require(subscriptionTypes[_subTypeId].id == _subTypeId, "INVALID_SUBTYPE");

        subscriptionTypes[_subTypeId].name = _name;
    } 

    /** 
     * @dev for testing, should not be in the mainnet contract
     */
    function endSubscription(address _user) external onlyOwner {
        delete subscribers[_user];
    }

    function withdraw() external nonReentrant onlyOwner {
        SafeTransferLib.safeTransferETH(vaultWallet, address(this).balance);
    }

    function withdrawERC20(address _token) external onlyOwner {
        IERC20 targetToken = IERC20(_token);
        uint256 balance = targetToken.balanceOf(address(this));
        require(balance > 0, "EMPTY_BALANCE");
        SafeTransferLib.safeTransferFrom(_token, address(this), vaultWallet, balance);
    }

    function executePayment(
        address _customer
    ) external {
        require(subscribers[_customer].endTime < block.timestamp, "SUB_ACTIVE");
        require(subscribers[_customer].tokenAddress != address(0), "TOKEN_INVALID");
        // Handle ERC20 payment
        _handleErc20Payment(subscribers[_customer].amount, subscribers[_customer].tokenAddress, _customer);
        // Check if the subscription is affiliate based
        if (subscribers[_customer].affiliateAddress != address(0x0) && subscribers[_customer].affiliateFee > 0) {
            // Handle affiliate payment 
            _comissionPayoutErc20(
                subscribers[_customer].tokenAddress,
                subscribers[_customer].affiliateAddress,
                subscribers[_customer].amount,
                subscribers[_customer].affiliateFee
            );
        }
        // Update new subscription end time
        subscribers[_customer].endTime = calculateExpireTimestap(subscribers[_customer].timeId);
    }

    /** 
     * Subscription times: 1 = month, 2 = year
     * Subscription types: 1 = builder, 2 = investor, 3 = community
     */ 
    function startSubscription (
        bytes calldata _sig, 
        Payment calldata payment,
        Affiliate calldata aff
    ) external payable 
    nonReentrant
    whenNotPaused
    isSubActive(payment.subId)
    validateAmount(payment.amount)
    {    
        bytes32 hash = keccak256(abi.encodePacked(payment.subId, payment.amount, payment.typeId));
        require(_matchSigner(hash, _sig), "INVALID_SIGNER");
        require(aff.affiliateFee == 0, "AFF_INVALID");
        _handleSubscription(
            msg.sender,
            payment,
            aff
        );
    }

    /** 
     * Start subscription but with affiliate parameters to pay out comissioners
     */ 
    function startSubscriptionAffiliate (
        bytes calldata _sig, 
        Payment calldata payment,
        Affiliate calldata affiliate
    ) external payable 
    nonReentrant 
    whenNotPaused 
    isSubActive(payment.subId) 
    validateAmount(payment.amount)
    validateAffiliateAddress(affiliate.affiliateAddress)
    {
        bytes32 hash = keccak256(abi.encodePacked(payment.subId, payment.timeId, payment.amount, affiliate.affiliateAddress, affiliate.affiliateFee));
        require(_matchSigner(hash, _sig), "INVALID_SIGNER");
        _handleSubscription(
            msg.sender,
            payment,
            affiliate
        );
        _comissionPayout(payable(affiliate.affiliateAddress), payment.amount, affiliate.affiliateFee);
    }

    function startSubscriptionErc20 (
        bytes calldata _sig, 
        Payment calldata payment,
        Affiliate calldata affiliate
    ) external 
    nonReentrant
    whenNotPaused
    isSubActive(payment.subId)
    {
        // validate inputs
        bytes32 hash = keccak256(abi.encodePacked(payment.subId, payment.timeId, payment.amount, payment.tokenAddress));
        require(_matchSigner(hash, _sig), "INVALID_SIGNER");
        require(affiliate.affiliateFee == 0, "AFF_INVALID");
        _handleErc20Payment(payment.amount, payment.tokenAddress, msg.sender);
        _handleSubscription(
            msg.sender,
            payment,
            affiliate
        );
    }

    /** 
     * Start subscription but with affiliate parameters to pay out comissioners
     */ 
    function startSubscriptionAffiliateErc20 (
        bytes calldata _sig, 
        Payment calldata payment,
        Affiliate calldata affiliate
    ) external 
    nonReentrant
    whenNotPaused
    isSubActive(payment.subId)
    validateAffiliateAddress(affiliate.affiliateAddress)
    {
    
        bytes32 hash = keccak256(abi.encodePacked(payment.subId, payment.timeId, payment.amount, payment.tokenAddress, affiliate.affiliateAddress, affiliate.affiliateFee));
        require(_matchSigner(hash, _sig), "INVALID_SIGNER");

        _handleErc20Payment(payment.amount, payment.tokenAddress, msg.sender);
        _comissionPayoutErc20(payment.tokenAddress, affiliate.affiliateAddress, payment.amount, affiliate.affiliateFee);

        _handleSubscription(
            msg.sender,
            payment,
            affiliate
        );
        
    }

    function _handleSubscription (
        address customer,
        Payment calldata payment,
        Affiliate calldata affiliate
    ) private returns(uint256)   {
        require(subscriptionTypes[payment.typeId].id == payment.typeId, "INVALID_SUBTYPE");
        uint256 _subscriptionEndTime = calculateExpireTimestap(payment.timeId);
        Subscription memory _subscription = Subscription(
            payment.subId,
            affiliate.affiliateFee,
            payment.typeId,
            payment.timeId,
            payment.amount,
            _subscriptionEndTime,
            payment.tokenAddress,
            affiliate.affiliateAddress
        );
        subscribers[customer] = _subscription;
        subscriptions[payment.subId] = true;
        ++subscriptionsNum;
        emit Subscribed(
            customer, 
            payment.subId,
            subscriptionTypes[payment.typeId].name,
            subscriptionTimes[payment.timeId].name 
        );
        return _subscriptionEndTime;
    }

    function calculateExpireTimestap(uint64 _subTimeId) internal view returns(uint256) {
        uint64 _subscriptionLength;
        uint256 _expiration;

        _subscriptionLength = subscriptionTimes[_subTimeId].subLength;
        _expiration = (block.timestamp + (_subscriptionLength * baseTimeUnit));
        return _expiration;
    }

    function _handleErc20Payment(uint256 _amount, address _token, address _sender) internal {
        // check the balance 
        IERC20 tokenInterface;
        tokenInterface = IERC20(_token);
        require(_amount <= tokenInterface.balanceOf(_sender), "INVALID_BALANCE");
        // Handle payment
        require(tokenInterface.allowance(_sender, address(this)) >= _amount, "ALLOWANCE_EMPTY");
        require(tokenInterface.transferFrom(_sender, address(this), _amount), "PAYMENT_FAILED");
    }

    function _comissionPayout(address payable _to, uint256 _purchaseAmount, uint256 _comission) internal {
       if (_purchaseAmount > 0 && _comission > 0) {
            uint256 u1total = (_purchaseAmount * _comission) / 100;
            if (address(this).balance >= u1total) {
                _to.transfer(u1total);
            }
       }
    }

    function _comissionPayoutErc20(address _token, address _to, uint256 _purchaseAmount, uint256 _comission) internal {
       if (_purchaseAmount > 0 && _comission > 0) {
        uint256 u1total = (_purchaseAmount * _comission) / 100;
        IERC20 tokenInterface;
        tokenInterface = IERC20(_token);
        if (tokenInterface.balanceOf(address(this)) >= u1total) {
            tokenInterface.transferFrom(address(this), _to, u1total);
        }
       }
    }

    function _matchSigner(bytes32 _hash, bytes calldata _signature) private view returns(bool) {
        return _subscriptionSigner == ECDSA.recover(ECDSA.toEthSignedMessageHash(_hash), _signature);
    }

    function eq(string memory a, string memory b) internal pure returns (bool result) {
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }
}

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Gas optimized ECDSA wrapper.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ECDSA.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ECDSA.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol)
library ECDSA {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The signature is invalid.
    error InvalidSignature();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The number which `s` must not exceed in order for
    /// the signature to be non-malleable.
    bytes32 private constant _MALLEABILITY_THRESHOLD =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    RECOVERY OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Note: as of the Solady version v0.0.68, these functions will
    // revert upon recovery failure for more safety.

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the `signature`.
    ///
    /// This function does NOT accept EIP-2098 short form signatures.
    /// Use `recover(bytes32 hash, bytes32 r, bytes32 vs)` for EIP-2098
    /// short form signatures instead.
    function recover(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)
            // Directly copy `r` and `s` from the calldata.
            calldatacopy(0x40, signature.offset, 0x40)
            // Store the `hash` in the scratch space.
            mstore(0x00, hash)
            // Compute `v` and store it in the scratch space.
            mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40))))
            pop(
                staticcall(
                    gas(), // Amount of gas left for the transaction.
                    and(
                        // If the signature is exactly 65 bytes in length.
                        eq(signature.length, 65),
                        // If `s` in lower half order, such that the signature is not malleable.
                        lt(mload(0x60), add(_MALLEABILITY_THRESHOLD, 1))
                    ), // Address of `ecrecover`.
                    0x00, // Start of input.
                    0x80, // Size of input.
                    0x00, // Start of output.
                    0x20 // Size of output.
                )
            )
            result := mload(0x00)
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                // Store the function selector of `InvalidSignature()`.
                mstore(0x00, 0x8baa579f)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Restore the zero slot.
            mstore(0x60, 0)
            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the EIP-2098 short form signature defined by `r` and `vs`.
    ///
    /// This function only accepts EIP-2098 short form signatures.
    /// See: https://eips.ethereum.org/EIPS/eip-2098
    ///
    /// To be honest, I do not recommend using EIP-2098 signatures
    /// for simplicity, performance, and security reasons. Most if not
    /// all clients support traditional non EIP-2098 signatures by default.
    /// As such, this method is intentionally not fully inlined.
    /// It is merely included for completeness.
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        uint8 v;
        bytes32 s;
        /// @solidity memory-safe-assembly
        assembly {
            s := shr(1, shl(1, vs))
            v := add(shr(255, vs), 27)
        }
        result = recover(hash, v, r, s);
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the signature defined by `v`, `r`, `s`.
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)
            mstore(0x00, hash)
            mstore(0x20, and(v, 0xff))
            mstore(0x40, r)
            mstore(0x60, s)
            pop(
                staticcall(
                    gas(), // Amount of gas left for the transaction.
                    // If `s` in lower half order, such that the signature is not malleable.
                    lt(s, add(_MALLEABILITY_THRESHOLD, 1)), // Address of `ecrecover`.
                    0x00, // Start of input.
                    0x80, // Size of input.
                    0x00, // Start of output.
                    0x20 // Size of output.
                )
            )
            result := mload(0x00)
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                // Store the function selector of `InvalidSignature()`.
                mstore(0x00, 0x8baa579f)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Restore the zero slot.
            mstore(0x60, 0)
            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   TRY-RECOVER OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // WARNING!
    // These functions will NOT revert upon recovery failure.
    // Instead, they will return the zero address upon recovery failure.
    // It is critical that the returned address is NEVER compared against
    // a zero address (e.g. an uninitialized address variable).

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the `signature`.
    ///
    /// This function does NOT accept EIP-2098 short form signatures.
    /// Use `recover(bytes32 hash, bytes32 r, bytes32 vs)` for EIP-2098
    /// short form signatures instead.
    function tryRecover(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(xor(signature.length, 65)) {
                // Copy the free memory pointer so that we can restore it later.
                let m := mload(0x40)
                // Directly copy `r` and `s` from the calldata.
                calldatacopy(0x40, signature.offset, 0x40)
                // If `s` in lower half order, such that the signature is not malleable.
                if iszero(gt(mload(0x60), _MALLEABILITY_THRESHOLD)) {
                    // Store the `hash` in the scratch space.
                    mstore(0x00, hash)
                    // Compute `v` and store it in the scratch space.
                    mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40))))
                    pop(
                        staticcall(
                            gas(), // Amount of gas left for the transaction.
                            0x01, // Address of `ecrecover`.
                            0x00, // Start of input.
                            0x80, // Size of input.
                            0x40, // Start of output.
                            0x20 // Size of output.
                        )
                    )
                    // Restore the zero slot.
                    mstore(0x60, 0)
                    // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                    result := mload(xor(0x60, returndatasize()))
                }
                // Restore the free memory pointer.
                mstore(0x40, m)
            }
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the EIP-2098 short form signature defined by `r` and `vs`.
    ///
    /// This function only accepts EIP-2098 short form signatures.
    /// See: https://eips.ethereum.org/EIPS/eip-2098
    ///
    /// To be honest, I do not recommend using EIP-2098 signatures
    /// for simplicity, performance, and security reasons. Most if not
    /// all clients support traditional non EIP-2098 signatures by default.
    /// As such, this method is intentionally not fully inlined.
    /// It is merely included for completeness.
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (address result)
    {
        uint8 v;
        bytes32 s;
        /// @solidity memory-safe-assembly
        assembly {
            s := shr(1, shl(1, vs))
            v := add(shr(255, vs), 27)
        }
        result = tryRecover(hash, v, r, s);
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the signature defined by `v`, `r`, `s`.
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)
            // If `s` in lower half order, such that the signature is not malleable.
            if iszero(gt(s, _MALLEABILITY_THRESHOLD)) {
                // Store the `hash`, `v`, `r`, `s` in the scratch space.
                mstore(0x00, hash)
                mstore(0x20, and(v, 0xff))
                mstore(0x40, r)
                mstore(0x60, s)
                pop(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        0x01, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x40, // Start of output.
                        0x20 // Size of output.
                    )
                )
                // Restore the zero slot.
                mstore(0x60, 0)
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                result := mload(xor(0x60, returndatasize()))
            }
            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HASHING OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns an Ethereum Signed Message, created from a `hash`.
    /// This produces a hash corresponding to the one signed with the
    /// [`eth_sign`](https://eth.wiki/json-rpc/API#eth_sign)
    /// JSON-RPC method as part of EIP-191.
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Store into scratch space for keccak256.
            mstore(0x20, hash)
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            // 0x40 - 0x04 = 0x3c
            result := keccak256(0x04, 0x3c)
        }
    }

    /// @dev Returns an Ethereum Signed Message, created from `s`.
    /// This produces a hash corresponding to the one signed with the
    /// [`eth_sign`](https://eth.wiki/json-rpc/API#eth_sign)
    /// JSON-RPC method as part of EIP-191.
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        assembly {
            // The length of "\x19Ethereum Signed Message:\n" is 26 bytes (i.e. 0x1a).
            // If we reserve 2 words, we'll have 64 - 26 = 38 bytes to store the
            // ASCII decimal representation of the length of `s` up to about 2 ** 126.

            // Instead of allocating, we temporarily copy the 64 bytes before the
            // start of `s` data to some variables.
            let m1 := mload(sub(s, 0x20))
            // The length of `s` is in bytes.
            let sLength := mload(s)
            let ptr := add(s, 0x20)
            let w := not(0)
            // `end` marks the end of the memory which we will compute the keccak256 of.
            let end := add(ptr, sLength)
            // Convert the length of the bytes to ASCII decimal representation
            // and store it into the memory.
            for { let temp := sLength } 1 {} {
                ptr := add(ptr, w) // `sub(ptr, 1)`.
                mstore8(ptr, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            // Copy the header over to the memory.
            mstore(sub(ptr, 0x20), "\x00\x00\x00\x00\x00\x00\x19Ethereum Signed Message:\n")
            // Compute the keccak256 of the memory.
            result := keccak256(sub(ptr, 0x1a), sub(end, sub(ptr, 0x1a)))
            // Restore the previous memory.
            mstore(s, sLength)
            mstore(sub(s, 0x20), m1)
        }
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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
     * by making the `nonReentrant` function external, and making it call a
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller.
library SafeTransferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /// @dev The ERC20 `transferFrom` has failed.
    error TransferFromFailed();

    /// @dev The ERC20 `transfer` has failed.
    error TransferFailed();

    /// @dev The ERC20 `approve` has failed.
    error ApproveFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Suggested gas stipend for contract receiving ETH
    /// that disallows any storage writes.
    uint256 internal constant _GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    /// @dev Suggested gas stipend for contract receiving ETH to perform a few
    /// storage reads and writes, but low enough to prevent griefing.
    /// Multiply by a small constant (e.g. 2), if needed.
    uint256 internal constant _GAS_STIPEND_NO_GRIEF = 100000;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ETH OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` (in wei) ETH to `to`.
    /// Reverts upon failure.
    function safeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
                // Store the function selector of `ETHTransferFailed()`.
                mstore(0x00, 0xb12d13eb)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    /// The `gasStipend` can be set to a low enough value to prevent
    /// storage writes or gas griefing.
    ///
    /// If sending via the normal procedure fails, force sends the ETH by
    /// creating a temporary contract which uses `SELFDESTRUCT` to force send the ETH.
    ///
    /// Reverts if the current contract has insufficient balance.
    function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // If insufficient balance, revert.
            if lt(selfbalance(), amount) {
                // Store the function selector of `ETHTransferFailed()`.
                mstore(0x00, 0xb12d13eb)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(gasStipend, to, amount, 0, 0, 0, 0)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                // We can directly use `SELFDESTRUCT` in the contract creation.
                // We don't check and revert upon failure here, just in case
                // `SELFDESTRUCT`'s behavior is changed some day in the future.
                // (If that ever happens, we will riot, and port the code to use WETH).
                pop(create(amount, 0x0b, 0x16))
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a gas stipend
    /// equal to `_GAS_STIPEND_NO_GRIEF`. This gas stipend is a reasonable default
    /// for 99% of cases and can be overriden with the three-argument version of this
    /// function if necessary.
    ///
    /// If sending via the normal procedure fails, force sends the ETH by
    /// creating a temporary contract which uses `SELFDESTRUCT` to force send the ETH.
    ///
    /// Reverts if the current contract has insufficient balance.
    function forceSafeTransferETH(address to, uint256 amount) internal {
        // Manually inlined because the compiler doesn't inline functions with branches.
        /// @solidity memory-safe-assembly
        assembly {
            // If insufficient balance, revert.
            if lt(selfbalance(), amount) {
                // Store the function selector of `ETHTransferFailed()`.
                mstore(0x00, 0xb12d13eb)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(_GAS_STIPEND_NO_GRIEF, to, amount, 0, 0, 0, 0)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                // We can directly use `SELFDESTRUCT` in the contract creation.
                // We don't check and revert upon failure here, just in case
                // `SELFDESTRUCT`'s behavior is changed some day in the future.
                // (If that ever happens, we will riot, and port the code to use WETH).
                pop(create(amount, 0x0b, 0x16))
            }
        }
    }

    /// @dev Sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    /// The `gasStipend` can be set to a low enough value to prevent
    /// storage writes or gas griefing.
    ///
    /// Simply use `gasleft()` for `gasStipend` if you don't need a gas stipend.
    ///
    /// Note: Does NOT revert upon failure.
    /// Returns whether the transfer of ETH is successful instead.
    function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and check if it succeeded or not.
            success := call(gasStipend, to, amount, 0, 0, 0, 0)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0x00, 0x23b872dd)
            mstore(0x20, from) // Append the "from" argument.
            mstore(0x40, to) // Append the "to" argument.
            mstore(0x60, amount) // Append the "amount" argument.

            if iszero(
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    // We use 0x64 because that's the total length of our calldata (0x04 + 0x20 * 3)
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFromFailed()`.
                mstore(0x00, 0x7939f424)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0x00, 0xa9059cbb)
            mstore(0x20, to) // Append the "to" argument.
            mstore(0x40, amount) // Append the "amount" argument.

            if iszero(
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    // We use 0x44 because that's the total length of our calldata (0x04 + 0x20 * 2)
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    call(gas(), token, 0, 0x1c, 0x44, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFailed()`.
                mstore(0x00, 0x90b8ec18)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x40, memPointer) // Restore the memPointer.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// Reverts upon failure.
    function safeApprove(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0x00, 0x095ea7b3)
            mstore(0x20, to) // Append the "to" argument.
            mstore(0x40, amount) // Append the "amount" argument.

            if iszero(
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    // We use 0x44 because that's the total length of our calldata (0x04 + 0x20 * 2)
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    call(gas(), token, 0, 0x1c, 0x44, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `ApproveFailed()`.
                mstore(0x00, 0x3e3f8f73)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x40, memPointer) // Restore the memPointer.
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