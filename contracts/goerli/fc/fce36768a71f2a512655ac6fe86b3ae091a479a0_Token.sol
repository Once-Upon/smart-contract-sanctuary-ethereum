/**
 *Submitted for verification at Etherscan.io on 2022-08-30
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;





abstract contract  BasicToken  {
    uint256 public totalSupply;
    bool public allowTransfer;

    function balanceOf(address _owner)  external virtual returns (uint256 balance);
    function transfer(address _to, uint256 _value) external virtual returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external virtual returns (bool success);
    function approve(address _spender, uint256 _value) external virtual returns (bool success);
    function allowance(address _owner, address _spender) external virtual returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract StandardToken is BasicToken {

    function transfer(address _to, uint256 _value) public override returns (bool success) {
        require(allowTransfer);
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
       emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool success) {
        require(allowTransfer);
        require(balances[_from] >= _value && allowed[_from][msg.sender] >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
       emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public override view returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public override returns (bool success) {
        require(allowTransfer);
        allowed[msg.sender][_spender] = _value;
       emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public override view  returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}


contract Token is StandardToken {

    string public name = "BASIC ERC20 SALE";
    uint8 public decimals = 18;
    string public symbol = "BASIC";
    string public version = 'BASIC 0.1';
    address public mintableAddress;

     constructor(address sale_address) {
        balances[msg.sender] = 0;
        totalSupply = 0;
        name = name;
        decimals = decimals;
        symbol = symbol;
        mintableAddress = sale_address;
        allowTransfer = true;
        createTokens();
    }

    // creates all tokens 5 million
    // this address will hold all tokens
    // all community contrubutions coins will be taken from this address
    function createTokens() internal {
        uint256 total = 5000000000000000000000000;
        balances[address(this)] = total;
        totalSupply = total;
    }

    function changeTransfer(bool allowed) external {
        require(msg.sender == mintableAddress);
        allowTransfer = allowed;
    }

    function mintToken(address to, uint256 amount) external returns (bool success) {
        //require(msg.sender == mintableAddress ,"Should be owner");
        require(balances[address(this)] >= amount , "contract balance should be > than amount");
        balances[address(this)] -= amount;
        balances[to] += amount;
       emit Transfer(address(this),to, amount);
        return true;
    }

    function approveAndCall(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
       emit Approval(msg.sender, _spender, _value);

        //require(_spender.call(bytes4(bytes32(keccak256("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _value, this, _extraData));
        return true;
    }
}