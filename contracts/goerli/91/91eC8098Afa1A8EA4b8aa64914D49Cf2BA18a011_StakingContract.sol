// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingContract {
    address private stakedToken;
    address private rewardToken;
    mapping(address => uint256) private stakedBalances;
    mapping(address => uint256) private lastClaimedTime;
    mapping(address => uint256) private rewardBalances;

    constructor(address _stakedToken, address _rewardToken) {
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(stakedBalances[msg.sender] == 0, "Already staked");

        // Transfer staked tokens to the contract
        // Assuming the staked token contract has a transferFrom function
        // and the sender has approved the contract to spend tokens
        // You may need to adapt this based on the actual token contract
        // For example: IERC20(stakedToken).transferFrom(msg.sender, address(this), amount);
        
        stakedBalances[msg.sender] = amount;
        lastClaimedTime[msg.sender] = block.timestamp;
    }

    function unstake() external {
        require(stakedBalances[msg.sender] > 0, "Not staked");
        
        // Transfer staked tokens back to the sender
        // You may need to adapt this based on the actual token contract
        // For example: IERC20(stakedToken).transfer(msg.sender, stakedBalances[msg.sender]);
        
        uint256 reward = calculateReward(msg.sender);
        if (reward > 0) {
            // Transfer reward tokens to the sender
            // You may need to adapt this based on the actual reward token contract
            // For example: IERC20(rewardToken).transfer(msg.sender, reward);
        }

        stakedBalances[msg.sender] = 0;
        lastClaimedTime[msg.sender] = 0;
        rewardBalances[msg.sender] = 0;
    }

    function calculateReward(address account) internal view returns (uint256) {
        uint256 elapsedTime = block.timestamp - lastClaimedTime[account];
        uint256 rewardPerMinute = 10;
        return (elapsedTime / 60) * rewardPerMinute;
    }

    function claimReward() external {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No reward to claim");

        // Transfer reward tokens to the sender
        // You may need to adapt this based on the actual reward token contract
        // For example: IERC20(rewardToken).transfer(msg.sender, reward);
        
        lastClaimedTime[msg.sender] = block.timestamp;
        rewardBalances[msg.sender] += reward;
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return stakedBalances[account];
    }

    function getRewardBalance(address account) external view returns (uint256) {
        return rewardBalances[account];
    }
}