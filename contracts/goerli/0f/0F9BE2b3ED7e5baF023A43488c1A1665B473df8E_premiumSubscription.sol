// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface IERC20 {

    /// @param _owner The address from which the balance will be retrieved
    /// @return balance the balance
    function balanceOf(address _owner) external view returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return success Whether the transfer was successful or not
    function transfer(address _to, uint256 _value)  external returns (bool success);

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return success Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return success Whether the approval was successful or not
    function approve(address _spender  , uint256 _value) external returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return remaining Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract TI is IERC20 {

    uint256 public totalSupply;
    uint256 constant private MAX_UINT256 = 2**256 - 1;
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    address payable owner;

    event Mint(address indexed _to, uint256 _value);

    /*
    The following variables are OPTIONAL vanities. One does not have to include them.
    They allow one to customise the token contract & in no way influences the core functionality.
    Some wallets/interfaces might not even bother to look at this information.
    */
    string public name;                   //fancy name: eg Simon Bucks
    uint8 public decimals;                //How many decimals to show.
    string public symbol;                 //An identifier: eg SBX

    modifier onlyOwner(){
        require(msg.sender == owner,'Only owner');
        _;

    }

    constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string  memory _tokenSymbol) {
        balances[msg.sender] = _initialAmount;               // Give the creator all initial tokens
        totalSupply = _initialAmount;                        // Update total supply
        name = _tokenName;                                   // Set the name for display purposes
        decimals = _decimalUnits;                            // Amount of decimals for display purposes
        symbol = _tokenSymbol;                               // Set the symbol for display purposes
        owner = payable(msg.sender);
    }

    function transfer(address _to, uint256 _value) public override returns (bool success) {
        require(balances[msg.sender] >= _value, "token balance is lower than the value requested");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool success) {
        uint256 allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && allowance >= _value, "token balance or allowance is lower than amount requested");
        balances[_to] += _value;
        balances[_from] -= _value;
        if (allowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    function balanceOf(address _owner) public override view returns (uint256 balance) {
        return balances[_owner];
    }

    function mint(address _to, uint256 _value) onlyOwner public{
        totalSupply += _value;
        balances[_to] += _value;
        
    }

    function approve(address _spender, uint256 _value) public override returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    function allowance(address _owner, address _spender) public override view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./ERC20.sol";
contract premiumSubscription{

    address payable public owner;
    IERC20 public paymenToken;

    struct subcriptionMetadata{
        address supcripter;
        uint256 startTime;
        uint256 endTime;
        bool isValid;
    }
    
    struct premiumMetadata{
        uint256 expriedTime;
        uint24 price;
    }
        // level
    mapping(uint8 => premiumMetadata) public premiumLevel;
    mapping(address => subcriptionMetadata) public premiumUsers;

    constructor(address _paymentToken){
        owner = payable(msg.sender);
        paymenToken = IERC20(_paymentToken);

        premiumLevel[1] = premiumMetadata(30*(1 days), 99);
        premiumLevel[2] = premiumMetadata(180*(1 days), 560);
        premiumLevel[3] = premiumMetadata(360*(1 days), 899);
    }

    modifier onlyOwner(){
        require(msg.sender == owner,'Only owner');
        _;

    }

    function isPremiumUser(address _user) public view returns(bool){
        return premiumUsers[_user].endTime > block.timestamp && premiumUsers[_user].isValid == true;
    }

    function upgradePremium(uint8 _level) public{
        paymenToken.transferFrom(msg.sender, address(this) , premiumLevel[_level].price);

        premiumUsers[msg.sender] = subcriptionMetadata(msg.sender,block.timestamp, block.timestamp + premiumLevel[_level].expriedTime, true);
        
    }

    function updateValidUserStatus(address _user, bool _premiumStatus) public onlyOwner{
        premiumUsers[_user].isValid = _premiumStatus;
    }

    function updateERC20(address _newERC20) public onlyOwner{
        paymenToken = IERC20(_newERC20);
    }

    function updateOwner(address payable _newOwner) public onlyOwner{
        owner = _newOwner;
    }

    function updatePremiumLevel(premiumMetadata memory __newMedata,uint8 _level)public onlyOwner{
        premiumLevel[_level] = __newMedata;
    }

    function getExpriedTime(address _user) public view returns(uint256){
        return premiumUsers[_user].endTime;
    }
}