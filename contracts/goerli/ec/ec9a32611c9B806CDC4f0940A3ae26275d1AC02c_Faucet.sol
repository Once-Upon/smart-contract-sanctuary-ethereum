// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.15;

import { InitializableOwnable } from "./InitializableOwnable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract Faucet is InitializableOwnable  {
     
    mapping(address => uint) public lastTimestampList;
    uint public paymentAmount = 50;
    uint public interval = 86400;
    IERC20 token;

    constructor(
        address _tokenAddr,
        uint _paymentAmount
    ) {
        initOwner(msg.sender);
        token = IERC20(_tokenAddr);
        paymentAmount = _paymentAmount;
    }

    // Sends the amount of token to the caller.
    function getTokens() external {
        uint amount = paymentAmount * (10 ** token.decimals());
        
        require(token.balanceOf(address(this)) > amount, "FaucetError: Empty");
        require(block.timestamp - lastTimestampList[msg.sender] > interval, "FaucetError: Try again later");
    
        lastTimestampList[msg.sender] = block.timestamp;
        
        require(token.transfer(msg.sender, amount));
    }  

    // Updates the underlying token address
    function setTokenAddress(address _tokenAddr) external onlyOwner {
        token = IERC20(_tokenAddr);
    } 

    // Updates the interval
    function setFaucetInterval(uint256 _interval) external onlyOwner {
        interval = _interval;
    }

    // Updates the amount paid
    function setAmount(uint256 _amount) external onlyOwner {
        paymentAmount = _amount;
    }

    // Allows the owner to withdraw tokens from the contract.
    function withdrawToken(IERC20 tokenToWithdraw, address to, uint amount) public onlyOwner {
        require(tokenToWithdraw.transfer(to, amount));
    }
}

// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.13;

contract InitializableOwnable {

    address public owner;
    address public newOwner;
    mapping(address => bool) admins;

    bool internal initialized;

    /* ========== MUTATIVE FUNCTIONS ========== */

    function initOwner(address _newOwner) public notInitialized {
        initialized = true;
        owner = _newOwner;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        emit OwnerTransferRequested(owner, _newOwner);
        newOwner = _newOwner;
    }

    function claimOwnership() public {
        require(msg.sender == newOwner, "Claim from wrong address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }

    function addAdmin(address user) public onlyOwner {
        emit AdminAdded(user);
        admins[user] = true;
    }

    function removeAdmin(address user) public onlyOwner {
        emit AdminRemoved(user);
        admins[user] = false;
    }

    /* ========== MODIFIERS ========== */

    modifier notInitialized() {
        require(!initialized, "Not initialized");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdminOrOwner() {
        require(admins[msg.sender] || owner == msg.sender, "Not admin or owner");
        _;
    }

    /* ========== EVENTS ========== */

    event OwnerTransferRequested(
        address indexed oldOwner, 
        address indexed newOwner
    );

    event OwnershipTransferred(
        address indexed oldOwner, 
        address indexed newOwner
    );

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
}