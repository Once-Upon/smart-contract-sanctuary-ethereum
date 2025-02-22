pragma solidity 0.8.11;

contract Token {
    
    uint8 public decimals;

    function transfer(address _to, uint256 _value) public returns (bool success) {}
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {}

    function allowance(address _owner, address _spender) public returns (uint256 remaining) {}
}

contract BulkSend {
    
    constructor() payable{}
    
    function bulkSendEth(address[] memory addresses, uint256[] memory amounts) public payable returns(bool success){
        for (uint8 i = 0; i < addresses.length; i++) {
            payable(addresses[i]).transfer(amounts[i] * 1 wei);
        }
        
        return true;
    }

    function bulkSendToken(Token tokenAddr, address[] memory addresses, uint256[] memory amounts) public payable returns(bool success){
        uint total = 0;
        address multisendContractAddress = address(this);
        for(uint8 i = 0; i < amounts.length; i++){
            total = total + amounts[i];
        }
        
        require(total <= tokenAddr.allowance(msg.sender, multisendContractAddress));
        
        for (uint8 j = 0; j < addresses.length; j++) {
            tokenAddr.transferFrom(msg.sender, addresses[j], amounts[j]);
        }
      
        return true;  
    }
}