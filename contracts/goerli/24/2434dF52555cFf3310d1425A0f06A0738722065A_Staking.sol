/**
 *Submitted for verification at Etherscan.io on 2022-11-06
*/

contract Staking {
   
    enum stakingStatus {
        OPENED,
        CLOSED
    }
    struct StakeInfo {
        uint stakedAmount;
        uint  noOfDays;
        uint yearLater;
        stakingStatus status;
    }

    mapping(address => StakeInfo) public stakes;
    
    address manager;


    constructor() {
        manager = msg.sender;
    }

    receive() external payable {

    }

    fallback() external payable {

    }

// This is the staking function - this is triggered once participants desire to stake and unstake their tokens

    function stake(uint _days, uint _amount) external payable{
        StakeInfo storage sData = stakes[msg.sender];
        require(_amount > 0, "You can't stake Zero Tokens");
        require (_days > 14, "Staking period can't be lower than fourteen days");
        sData.status = stakingStatus.OPENED;
        sData.stakedAmount += _amount;
        sData.noOfDays = block.timestamp + (_days * 14 days);
        sData.yearLater = block.timestamp + 365 days;
        
            

    }

    // Function to withdraw stake
    function withdrawStake() external {
        StakeInfo memory userStake = stakes[msg.sender];
        
        require(block.timestamp > userStake.noOfDays, "Staking period not elapsed");
        require(userStake.stakedAmount > 0, "Zero Stake Balance");
        

        uint calculatedYield = calculateYield(userStake.noOfDays, userStake.stakedAmount, userStake.yearLater);
        // determine the transferable token

        uint sendableToken = userStake.stakedAmount + calculatedYield;

        stakes[msg.sender].stakedAmount = 0;
        stakes[msg.sender].noOfDays = 0;

      
        payable(msg.sender).transfer(sendableToken);
        userStake.status = stakingStatus.CLOSED;




    }

    // Function to calculate the yield

    function calculateYield(uint _days, uint _stakedAmount, uint _periodInTheYear) private pure returns(uint yield) {
        uint baseDays = _days/_periodInTheYear;
        yield = baseDays * _stakedAmount;
        
    }

    // Check the balance of the token

    function checkBalance(uint _amountStakable) external view {
        require(msg.sender == manager, "You are not the Manager");
        _amountStakable = address(this).balance;
    }

    

    // show apy
    function showCalculatedAPY() external view returns (uint apy) {
        StakeInfo storage userStake = stakes[msg.sender];
        uint confirmedDays = userStake.noOfDays/userStake.yearLater;
        apy = confirmedDays * userStake.stakedAmount;
    }
}