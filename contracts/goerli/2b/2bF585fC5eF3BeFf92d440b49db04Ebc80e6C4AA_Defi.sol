// SPDX-License-Identifier: MIT

// USDC Address: 0x07865c6E87B9F70255377e024ace6630C1Eaa37F
pragma solidity >=0.8.0 <0.9.0;

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract Defi {
    uint256 interestRate;
    uint256 rateOfEth;
    address owner;
    uint256 totalStakedAmount;
    uint256 totalInterest;
    address usdcTokenAddress = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;

    struct stake {
        uint256 stakingAmount;
        uint256 stakedDate;
        uint256 collectedInterest;
    }

    stake public stakerDetail;

    mapping(address => stake) public stakerData;

    address[] public stakerId;

    constructor() {
        interestRate = 2;
        rateOfEth = 1500;
        owner = msg.sender;
        totalStakedAmount = 10000000000000000;
        totalInterest = 10;
    }

    // Function to approve address
    function approveusdc() public {
        IERC20 usdcToken = IERC20(usdcTokenAddress);
        bool success = usdcToken.approve(msg.sender, 100);
        require(success, "Failed to approve usdc tokens");
    }

    // Functions to deposit ethereum and earn interest
    // Deposit Ethereum
    function depositEth() public payable {
        stake storage userStake = stakerData[msg.sender];
        totalStakedAmount += msg.value;
        if (userStake.stakingAmount > 0) {
            userStake.stakingAmount += msg.value;
        } else {
            stakerDetail = stake(msg.value, block.timestamp, 0);
            stakerData[msg.sender] = stakerDetail;
            stakerId.push(msg.sender);
        }
    }

    // Set rate of eth
    function setRateOfEth(uint256 rateOfEthereum) public {
        rateOfEth = rateOfEthereum;
    }

    // Test function to get interest amount rate
    function getInterestAmtRate(address sender) public view returns (uint256) {
        uint256 interestAmountRate = (stakerData[sender].stakingAmount * 1e18) /
            totalStakedAmount;
        return interestAmountRate / 1e18;
    }

    // Pay interest to customer
    function payInterest() public {
        for (uint256 i = 0; i <= 1; i++) {
            //Calculate, interestAmountRate, e.g. if total is 100 and the user has 10, then it's interestAmountRate is 0.1
            uint256 interestAmountRate = uint256(
                stakerData[stakerId[i]].stakingAmount
            ) / uint256(totalStakedAmount);
            // uint256 interestAmount = interestAmountRate *
            //     stakerData[stakerId[i]].stakingAmount;
            // Add this amount to the mapping of stakerData
            stakerData[stakerId[i]].stakingAmount += interestAmountRate;
        }
        totalInterest = 0;
    }

    // Borrowing functions
    function borrow() public {}

    // Test functions
    function viewTotalInterest() public view returns (uint256) {
        return totalInterest;
    }

    // Get data of given address
    function getDataOfAddress(address addressReceipient)
        public
        view
        returns (uint256)
    {
        return stakerData[addressReceipient].collectedInterest;
    }

    // Withdraw Ethereum
    function withdraw() public payable {
        stake storage userStake = stakerData[msg.sender];
        require(userStake.stakingAmount > 0, "You must be staked to withdraw");
        address payable recipient = payable(msg.sender);
        recipient.transfer(userStake.stakingAmount);
    }

    // Transfer USDC from contract to address
    function transferUSDC(address recipient, uint256 amount) public payable {
        IERC20(usdcTokenAddress).transfer(recipient, amount);
    }

    // Transfer USDC
    function sendUSDC(uint256 amount, address contractAddress) public {
        IERC20(usdcTokenAddress).transferFrom(
            msg.sender,
            contractAddress,
            amount
        );
    }

    // Check balance of USDC
    function checkUSDCBalance() public view returns (uint256) {
        return
            IERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F).balanceOf(
                0xfAAe0B09e9A80d142A11cd846CD9329F2E96f55F
            );
    }

    // Get balance of USDC
    function getContractUSDCBalance(address checkBalance)
        public
        view
        returns (uint256)
    {
        return IERC20(usdcTokenAddress).balanceOf(checkBalance);
    }

    //Send ETH
    function sendBalance() public {
        address payable recipient = payable(msg.sender);
        recipient.transfer(address(this).balance);
    }
}