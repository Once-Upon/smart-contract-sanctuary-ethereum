// SPDX-License-Identifier: GPL-3.0

// Copyright 2022 ItsaWallet Team

pragma solidity 0.8.17;

import { Pausable } from './Pausable.sol';

contract ItsaSubscription is Pausable {
    //============================================================================
    // Events
    //============================================================================

    event Subscription(
        address indexed subscriber,
        uint256 indexed numberOfDays,
        uint256 prevSubscriptionEndTimestamp,
        uint256 indexed subscriptionEndTimestamp
    );
    event TrialSubscription(
        address indexed subscriber,
        uint256 indexed trialPeriod,
        uint256 indexed trialEndTimestamp
    );
    event BindToSubscription(
        address indexed childAddress,
        address indexed masterAddress,
        bool subscriptionBound
    );
    event ApproveBoundSubscription(
        address indexed masterAddress,
        address indexed childAddress,
        bool boundSubscriptionApproved
    );

    //============================================================================
    // State Variables
    //============================================================================

    address private feeReceiver;
    uint256 private approvedSubscriptionCount = 0;
    uint256 private boundToSubscriptionCount = 0;
    uint256 private childSubscriptionsUpperThreshold = 1000;
    uint256 private dailyFee = 0.0002 ether; // Chosen values depend on the blockchain the contract is running on
    uint256 private freeSubscriptionCount = 0;
    uint256 private maxChildSubscriptions = 5;
    uint256 private maxSubscriptionDays = 1825; // days => 5 years
    uint256 private maxTrialDays = 365; // days
    uint256 private minDailyFee = 0.0001 ether;
    uint256 private paidSubscriptionCount = 0;
    uint256 private subscriptionUpperThreshold = 36500; // 100 years
    uint256 private trialCount = 0;
    uint256 private trialPeriod = 30; // days
    uint256 private constant secondsPerDay = 86400;
    mapping(address => address) private boundToSubscriptions; // every address can be specified to benefit from another's paid subscription
    mapping(address => bool) private freeSubscriptions;
    mapping(address => mapping(uint256 => address)) private approvedToBindSubscriptions; // every address can have a list of bound addresses that share the paid subscription
    mapping(address => uint) private addressApprovedSubscriptionCount;
    mapping(address => uint) private subscriptionEndTimestamps;
    mapping(address => uint) private trialEndTimestamps;

    //============================================================================
    // Constructor
    //============================================================================

    constructor(address _feeReceiver) Pausable(msg.sender) {
        feeReceiver = _feeReceiver;
    }

    //============================================================================
    // Mutative Functions
    //============================================================================

    receive() external payable {}

    function subscribe() external payable whenNotPaused {
        require(
            msg.value != 0 && // some value was sent
                msg.value % dailyFee == 0 && // value must be an exact multiple of the daily fee
                msg.value / dailyFee <= maxSubscriptionDays, // value can not lead to a subscription beyond the threshold
            'ItsaSubscription::subscribe: msg.value is invalid'
        );
        require(
            canGetSubscription(msg.sender),
            'ItsaSubscription::subscribe: user already has a free trial'
        );
        uint256 currentTimestamp;
        uint256 previousTimestamp;
        uint256 numberOfDays = msg.value / dailyFee;
        // when not subscribed yet, increase counter
        if (!isSubscribed(msg.sender)) {
            paidSubscriptionCount++;
            currentTimestamp = block.timestamp;
            previousTimestamp = 0;
        } else {
            previousTimestamp = subscriptionEndTimestamps[msg.sender];
            currentTimestamp = previousTimestamp;
            if (currentTimestamp < block.timestamp) {
                currentTimestamp = block.timestamp;
            }
        }
        uint256 subscriptionEnds = currentTimestamp + (numberOfDays * 1 days);
        subscriptionEndTimestamps[msg.sender] = subscriptionEnds;
        removeBoundSubscription();
        forwardFee(msg.value);
        emit Subscription(msg.sender, numberOfDays, previousTimestamp, subscriptionEnds);
    }

    function trial() external whenNotPaused {
        require(canGetTrial(msg.sender), 'ItsaSubscription::trial: cannot get a trial');
        uint256 trialEnds = block.timestamp + trialPeriod * secondsPerDay;
        trialCount++;
        trialEndTimestamps[msg.sender] = trialEnds;
        emit TrialSubscription(msg.sender, trialPeriod, trialEnds);
    }

    // wallet address can bind itself to a master address, that has a subscription
    // so they share the same subscription
    // Note: the master address, with the paid subscription, needs to approveBoundedSubscription() on this address as well
    // MADE BY CHILD ADDRESS
    function bindToSubscription(address subscriptionAddress) external whenNotPaused {
        require(
            msg.sender != subscriptionAddress,
            'ItsaSubscription::bindToSubscription: cannot bind to self'
        );
        removeBoundSubscription();
        boundToSubscriptionCount++;
        boundToSubscriptions[msg.sender] = subscriptionAddress;
        emit BindToSubscription(msg.sender, subscriptionAddress, true);
    }

    // MADE BY CHILD ADDRESS
    function removeBoundSubscription() public whenNotPaused {
        address boundSubscription = boundToSubscriptions[msg.sender];
        if (boundSubscription != address(0)) {
            boundToSubscriptionCount--;
            boundToSubscriptions[msg.sender] = address(0);
            emit BindToSubscription(msg.sender, boundSubscription, false);
        }
    }

    // MADE BY MASTER ADDRESS
    function approveBoundSubscription(address approveAddress) external whenNotPaused {
        require(
            msg.sender != approveAddress,
            'ItsaSubscription::approveBoundSubscription: approval should be done to another address'
        );
        require(
            addressApprovedSubscriptionCount[msg.sender] < maxChildSubscriptions,
            'ItsaSubscription::approveBoundSubscription: max child subscriptions exceeded'
        );
        require(
            !isApprovedBindToSubscription(msg.sender, approveAddress) &&
                canApproveBoundSubscription(),
            'ItsaSubscription::approveBoundSubscription: cannot approve subscription'
        );
        approvedToBindSubscriptions[msg.sender][
            addressApprovedSubscriptionCount[msg.sender]
        ] = approveAddress;
        addressApprovedSubscriptionCount[msg.sender]++;
        approvedSubscriptionCount++;
        emit ApproveBoundSubscription(msg.sender, approveAddress, true);
    }

    // MADE BY MASTER ADDRESS
    function removeBoundSubscriptionApproval(address approvedAddress) external whenNotPaused {
        require(
            isApprovedBindToSubscription(msg.sender, approvedAddress),
            'ItsaSubscription::removeBoundSubscriptionApproval: address has not been approved'
        );
        for (
            uint256 i = findApprovedBindToIndex(msg.sender, approvedAddress);
            i < addressApprovedSubscriptionCount[msg.sender] - 1;
            i++
        ) {
            approvedToBindSubscriptions[msg.sender][i] = approvedToBindSubscriptions[msg.sender][
                i + 1
            ];
        }
        approvedToBindSubscriptions[msg.sender][
            addressApprovedSubscriptionCount[msg.sender] - 1
        ] = address(0);
        addressApprovedSubscriptionCount[msg.sender]--;
        approvedSubscriptionCount--;
        emit ApproveBoundSubscription(msg.sender, approvedAddress, false);
    }

    // MADE BY MASTER ADDRESS
    function setApprovedMultipleBoundSubscriptions(
        address[] calldata approveAddresses
    ) external whenNotPaused {
        uint256 addressArrayLength = approveAddresses.length;
        require(
            addressApprovedSubscriptionCount[msg.sender] + addressArrayLength <=
                maxChildSubscriptions,
            'ItsaSubscription::setApprovedMultipleBoundSubscriptions: max child subscriptions exceeded'
        );
        require(
            canSetMultiApproveBoundSubscriptions(approveAddresses),
            'ItsaSubscription::setApprovedMultipleBoundSubscriptions: cannot approve subscriptions'
        );
        address[] memory boundAddresses = getBoundAddresses(msg.sender);
        for (uint256 i = 0; i < boundAddresses.length; i++) {
            require(
                !isApprovedBindToSubscription(msg.sender, boundAddresses[i]),
                'ItsaSubscription::setApprovedMultipleBoundSubscriptions: already approved'
            );
        }
        approvedSubscriptionCount =
            approvedSubscriptionCount -
            addressApprovedSubscriptionCount[msg.sender] +
            addressArrayLength;
        addressApprovedSubscriptionCount[msg.sender] = addressArrayLength;
        for (uint256 i = 0; i < maxChildSubscriptions; i++) {
            if (i < addressArrayLength) {
                approvedToBindSubscriptions[msg.sender][i] = approveAddresses[i];
                emit ApproveBoundSubscription(msg.sender, approveAddresses[i], true);
            } else {
                approvedToBindSubscriptions[msg.sender][i] = address(0);
            }
        }
    }

    //============================================================================
    // View Functions
    //============================================================================

    function hasFullAccess(address _address) external view returns (bool) {
        return
            isSubscribed(_address) ||
            hasTrial(_address) ||
            hasFreeSubscription(_address) ||
            isBoundSubscribed(_address);
    }

    function isBoundSubscribed(address _address) public view returns (bool) {
        bool masterIsSubscribed = false;
        if (hasValidBindToSubscription(_address)) {
            masterIsSubscribed = isSubscribed(getMasterSubscription(_address));
        }
        return masterIsSubscribed;
    }

    function canGetSubscription(address _address) public view returns (bool) {
        return !freeSubscriptions[_address];
    }

    function canApproveBoundSubscription() public view returns (bool) {
        return
            !freeSubscriptions[msg.sender] &&
            isSubscribed(msg.sender) &&
            addressApprovedSubscriptionCount[msg.sender] < maxChildSubscriptions;
    }

    function canSetMultiApproveBoundSubscriptions(
        address[] calldata _addresses
    ) public view returns (bool) {
        bool addressIsSender = false;
        uint256 addressArrayLength = _addresses.length;
        for (uint256 i = 0; i < addressArrayLength && !addressIsSender; i++) {
            addressIsSender = _addresses[i] == msg.sender;
        }
        return
            !freeSubscriptions[msg.sender] &&
            isSubscribed(msg.sender) &&
            addressApprovedSubscriptionCount[msg.sender] + addressArrayLength <=
            maxChildSubscriptions &&
            !addressIsSender;
    }

    function isSubscribed(address _address) public view returns (bool) {
        return expiration(_address) != 0;
    }

    function expiration(address _address) public view returns (uint) {
        // take the highest value: of the subscription itself, as well of a bound subscription (if set)
        uint256 endTimestampChild = subscriptionEndTimestamps[_address];
        uint256 endTimestampMaster = 0;
        uint256 endTimestamp;
        if (hasValidBindToSubscription(_address)) {
            endTimestampMaster = subscriptionEndTimestamps[getMasterSubscription(_address)];
        }
        if ((endTimestampMaster == 0) && (endTimestampChild == 0)) {
            return 0;
        }
        endTimestampMaster > endTimestampChild
            ? endTimestamp = endTimestampMaster
            : endTimestamp = endTimestampChild;
        // CAREFUL: WE DO NOT WANT TO RETURN NEGATIVE VALUES, BECAUSE THEY WILL TURN INTO HIGH POSITIVE NUMBERS!
        if (block.timestamp > endTimestamp) {
            return 0;
        }
        return endTimestamp - block.timestamp;
    }

    function hasValidBindToSubscription(address _address) public view returns (bool) {
        address masterAddress = getMasterSubscription(_address);
        return masterAddress != address(0) && isApprovedBindToSubscription(masterAddress, _address);
    }

    function isBoundToSubscription(address _address) public view returns (bool) {
        return boundToSubscriptions[_address] != address(0);
    }

    function getMasterSubscription(address boundAddress) public view returns (address) {
        return boundToSubscriptions[boundAddress];
    }

    function canGetTrial(address _address) public view returns (bool) {
        return
            trialEndTimestamps[_address] == 0 &&
            (subscriptionEndTimestamps[_address] == 0 ||
                subscriptionEndTimestamps[_address] < block.timestamp) &&
            !freeSubscriptions[_address] &&
            !isBoundToSubscription(_address);
    }

    function hasTrial(address _address) public view returns (bool) {
        return trialExpiration(_address) != 0;
    }

    function trialExpiration(address _address) public view returns (uint) {
        if (block.timestamp > trialEndTimestamps[_address]) {
            return 0;
        }
        return trialEndTimestamps[_address] - block.timestamp;
    }

    function hasFreeSubscription(address _address) public view returns (bool) {
        return freeSubscriptions[_address];
    }

    function isApprovedBindToSubscription(
        address masterAddress,
        address approveAddress
    ) public view returns (bool) {
        bool approved = false;
        for (
            uint256 i = 0;
            (i < addressApprovedSubscriptionCount[masterAddress]) && !approved;
            i++
        ) {
            approved = approvedToBindSubscriptions[masterAddress][i] == approveAddress;
        }
        return approved;
    }

    function getBoundAddresses(address masterAddress) public view returns (address[] memory) {
        address[] memory boundAddresses = new address[](
            addressApprovedSubscriptionCount[masterAddress]
        );
        for (uint256 i = 0; i < addressApprovedSubscriptionCount[masterAddress]; i++) {
            boundAddresses[i] = approvedToBindSubscriptions[masterAddress][i];
        }
        return boundAddresses;
    }

    function getFeeReceiver() external view returns (address) {
        return feeReceiver;
    }

    function getApprovedSubscriptionCount() external view returns (uint) {
        return approvedSubscriptionCount;
    }

    function getBoundSubscriptionCount() external view returns (uint) {
        return boundToSubscriptionCount;
    }

    function getChildSubscriptionsUpperThreshold() external view returns (uint) {
        return childSubscriptionsUpperThreshold;
    }

    function getDailyFee() external view returns (uint) {
        return dailyFee;
    }

    function getFreeSubscriptionCount() external view returns (uint) {
        return freeSubscriptionCount;
    }

    function getMaxChildSubscriptions() external view returns (uint) {
        return maxChildSubscriptions;
    }

    function getMaxSubscriptionDays() external view returns (uint) {
        return maxSubscriptionDays;
    }

    function getMaxTrialDays() external view returns (uint) {
        return maxTrialDays;
    }

    function getMinDailyFee() external view returns (uint) {
        return minDailyFee;
    }

    function getpaidSubscriptionCount() external view returns (uint) {
        return paidSubscriptionCount;
    }

    function getSubscriptionUpperThreshold() external view returns (uint) {
        return subscriptionUpperThreshold;
    }

    function getTrialCount() external view returns (uint) {
        return trialCount;
    }

    function getTrialPeriod() external view returns (uint) {
        return trialPeriod;
    }

    function getAddressApprovedSubscriptionCount(
        address masterAddress
    ) external view returns (uint) {
        return addressApprovedSubscriptionCount[masterAddress];
    }

    function getSubscriptionEndTimestamp(address subscriber) external view returns (uint) {
        return subscriptionEndTimestamps[subscriber];
    }

    function getTrialEndTimestamp(address subscriber) external view returns (uint) {
        return trialEndTimestamps[subscriber];
    }

    //============================================================================
    // Functions reserved for the Contract Owner
    //============================================================================

    function payout() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance != 0, 'ItsaSubscription::payout: no balance on the contract');
        forwardFee(balance);
    }

    function subscribeFreeAccount(address _address) external onlyOwner {
        require(
            !hasFreeSubscription(_address),
            'ItsaSubscription::subscribeFreeAccount: address already has a free subscription'
        );
        freeSubscriptionCount++;
        freeSubscriptions[_address] = true;
    }

    function unsubscribeFreeAccount(address _address) external onlyOwner {
        require(
            hasFreeSubscription(_address),
            'ItsaSubscription::unsubscribeFreeAccount: address has no free subscription'
        );
        freeSubscriptionCount--;
        freeSubscriptions[_address] = false;
    }

    function setFeeReceiver(address _newFeeReceiver) external onlyOwner {
        feeReceiver = _newFeeReceiver;
    }

    function setChildSubscriptionsUpperThreshold(uint256 newThreshold) external onlyOwner {
        require(
            newThreshold > maxChildSubscriptions,
            'ItsaSubscription::setChildSubscriptionsUpperThreshold: must be greater than maxChildSubscriptions'
        );
        childSubscriptionsUpperThreshold = newThreshold;
    }

    function setDailyFee(uint256 _dailyFee) external onlyOwner {
        require(_dailyFee > minDailyFee, 'ItsaSubscription::setDailyFee: below minimum threshold');
        dailyFee = _dailyFee;
    }

    function setMaxChildSubscriptions(uint256 maxNumber) external onlyOwner {
        require(
            maxNumber != 0 && maxNumber <= childSubscriptionsUpperThreshold,
            'ItsaSubscription::setMaxChildSubscriptions: outside allowed range'
        );
        maxChildSubscriptions = maxNumber;
    }

    function setMaxSubscriptionDays(uint256 _days) external onlyOwner {
        require(
            _days != 0 && _days <= subscriptionUpperThreshold,
            'ItsaSubscription::setMaxSubscriptionDays: outside allowed range of days'
        );
        maxSubscriptionDays = _days;
    }

    function setMaxTrialDays(uint256 _days) external onlyOwner {
        require(_days != 0, 'ItsaSubscription::setMaxTrialDays: only positive integers allowed');
        maxTrialDays = _days;
    }

    function setMinDailyFee(uint256 _minDailyFee) external onlyOwner {
        require(
            _minDailyFee != 0,
            'ItsaSubscription::setMinDailyFee: only positive integers allowed'
        );
        minDailyFee = _minDailyFee;
    }

    function setSubscriptionUpperThreshold(uint256 _days) external onlyOwner {
        require(
            _days > maxSubscriptionDays,
            'ItsaSubscription::setSubscriptionUpperThreshold: must be greater than maxSubscriptionDays'
        );
        subscriptionUpperThreshold = _days;
    }

    function setTrialPeriod(uint256 _days) external onlyOwner {
        require(
            _days != 0 && _days <= maxTrialDays,
            'ItsaSubscription::setTrialPeriod: outside allowed range of days'
        );
        trialPeriod = _days;
    }

    //============================================================================
    // Internal functions
    //============================================================================

    function forwardFee(uint256 _value) private {
        (bool success, bytes memory data) = feeReceiver.call{ value: _value }('');
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'ItsaSubscription::forwardFee: failed'
        );
    }

    function findApprovedBindToIndex(
        address masterAddress,
        address approveAddress
    ) private view returns (uint) {
        bool found = false;
        uint256 i = 0;
        for (; i < addressApprovedSubscriptionCount[masterAddress] && !found; i++) {
            found = approvedToBindSubscriptions[masterAddress][i] == approveAddress;
        }
        require(found, 'ItsaSubscription::findApprovedBindToIndex: index not found');
        return i - 1;
    }
}

// SPDX-License-Identifier: GPL-3.0

// Copyright 2022 ItsaWallet Team

pragma solidity 0.8.17;

import { Ownable } from './Ownable.sol';

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
    /**
     * @dev Emitted when pause() is called.
     * @param account of contract owner issuing the event.
     * @param unpauseBlock block number when contract will be unpaused.
     */
    event Paused(address account, uint256 unpauseBlock);

    /**
     * @dev Emitted when pause is lifted by unpause() by
     * @param account.
     */
    event Unpaused(address account);

    /**
     * @dev state variable
     */
    uint256 public blockNumberWhenToUnpause = 0;

    constructor(address _owner) Ownable(_owner) {}

    /**
     * @dev Modifier to make a function callable only when the contract is not
     *      paused. It checks whether the current block number
     *      has already reached blockNumberWhenToUnpause.
     */
    modifier whenNotPaused() {
        require(
            block.number >= blockNumberWhenToUnpause,
            'Pausable: Revert - Code execution is still paused'
        );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(
            block.number < blockNumberWhenToUnpause,
            'Pausable: Revert - Code execution is not paused'
        );
        _;
    }

    /**
     * @dev Triggers or extends pause state.
     *
     * Requirements:
     *
     * - @param blocks needs to be greater than 0.
     */
    function pause(uint256 blocks) external onlyOwner {
        require(
            blocks != 0,
            'Pausable: Revert - Pause did not activate. Please enter a positive integer.'
        );
        blockNumberWhenToUnpause = block.number + blocks;
        emit Paused(msg.sender, blockNumberWhenToUnpause);
    }

    /**
     * @dev Returns to normal code execution.
     */
    function unpause() external onlyOwner {
        blockNumberWhenToUnpause = block.number;
        emit Unpaused(msg.sender);
    }
}

// SPDX-License-Identifier: GPL-3.0

// Copyright 2022 ItsaWallet Team

pragma solidity 0.8.17;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of 'user permissions'.
 */
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor(address _owner) {
        owner = _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, 'Ownable: Not owner');
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), 'Ownable: Zero address not allowed');
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}