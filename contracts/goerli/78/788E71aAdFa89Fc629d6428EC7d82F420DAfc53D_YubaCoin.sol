/**
 *Submitted for verification at Etherscan.io on 2023-01-23
*/

// File: contracts/YubaToken.sol


pragma solidity >=0.7.0 <0.9.0;
 
contract YubaCoin {
    struct CommissionData{
        uint id;
        address Sender;
        address Receiver;
        uint commissionAmount;
    }

    uint commissionCount=0;
    mapping(uint=>CommissionData) commissionDataById;
    CommissionData[] public CommissionRecord;    //Storing CommissionRecord

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
 
    string public constant name = "Yuba Coin";
    string public constant symbol = "YUBA";
    uint8 public constant decimals = 18;
  
    address public owner;

    mapping(address => uint256) balances;   //to fetch balance

    uint256 totalSupply_; 
    
    uint public constant initialSupply=100 * (10 ** uint256(decimals));
    uint public constant _mintedAmount=100 * (10 ** uint256(decimals)); //per mint amount

    constructor(address _newOwner) {
        totalSupply_ = initialSupply;
        balances[_newOwner] = totalSupply_;
        owner=_newOwner; 
    }

    function getAllCommissionData() public view returns(uint[] memory, address[] memory, address[] memory,uint[] memory){
        uint[] memory id = new uint[](commissionCount);
        address[] memory _sender = new address[](commissionCount);
        address[] memory _receiver = new address[](commissionCount);
        uint[] memory _value = new uint[](commissionCount);
        for (uint i = 0; i < commissionCount; i++) {
            CommissionData storage member = CommissionRecord[i];
            id[i] = member.id;
            _sender[i] = member.Sender;
            _receiver[i] = member.Receiver;
            _value[i] = member.commissionAmount;
        }
        return (id,_sender,_receiver,_value);
    }

    function totalSupply() public view returns (uint256) {         
        return totalSupply_;                    
    }
    
    function balanceOf(address tokenOwner) public view returns (uint) {   
        return balances[tokenOwner];          
    }

    function mintToken(address _target) public {
        require(totalSupply()<10000 * (10 ** uint256(decimals)),"Minting Limit Exceed=====");
        balances[_target]+=_mintedAmount;
        totalSupply_+=_mintedAmount;   
    }
    
    function transfer(address _to, uint256 _value) public  {
        uint transferFees= (_value*25)/100;                                                       
        require(transferFees+_value < balances[msg.sender],"Not Enough Balance");
        require (balances[msg.sender] > _value) ;                           
        require (balances[_to] + _value > balances[_to]);                 
        balances[msg.sender] -= _value;   
        balances[msg.sender]-=transferFees;   
        balances[owner]+=transferFees; 
        emit Transfer(msg.sender,owner,transferFees);
        balances[_to] += (_value); 
        emit Transfer(msg.sender,_to,_value);
        commissionCount++;  
        setCommissionData(commissionCount, msg.sender, _to, transferFees);     
    }

    function ownerBalance() public view returns(uint){
        return balances[owner];
    }

    function transferOwnership(address _new_Owner) public returns (bool status) {
        require(_new_Owner != address(0x0),"Invalid Address");
        require(msg.sender == owner,"unauthorized access");
        owner = _new_Owner;
        return status = true;
    }

    function setCommissionData(uint _id, address sender_Address, address receiver_Address, uint _commissionAmount) internal {
        CommissionRecord.push(CommissionData({
           id:_id,
           Sender:sender_Address,
           Receiver:receiver_Address,
           commissionAmount:_commissionAmount
        }));
    }
}