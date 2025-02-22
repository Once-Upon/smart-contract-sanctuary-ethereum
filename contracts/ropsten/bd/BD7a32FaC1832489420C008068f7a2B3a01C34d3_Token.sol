/**
 *Submitted for verification at Etherscan.io on 2022-08-05
*/

pragma solidity ^0.4.24;
contract SafeMath {
  function safeMul(uint256 a, uint256 b) pure internal returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
  function safeDiv(uint256 a, uint256 b) pure internal returns (uint256) {
    assert(b > 0);
    uint256 c = a / b;
    assert(a == b * c + a % b);
    return c;
  }
  function safeSub(uint256 a, uint256 b) pure internal returns (uint256) {
    assert(b <= a);
    return a - b;
  }
  function safeAdd(uint256 a, uint256 b) pure internal returns (uint256) {
    uint256 c = a + b;
    assert(c>=a && c>=b);
    return c;
  }
  function safePow(uint a, uint b) pure internal returns (uint){
      return a**b;
  }
}
contract ERC20{
    function transfer(address , uint256 ) external {}
}
contract Token is SafeMath{
    string public name = "MED29";
    string public symbol = "MED29";
    uint8 public decimals = 18;
    uint256 public totalSupply = 10000000e18;
    uint public tokenPrice = 1000000000000000;
    address public owner = 0xA37f5E382b3634d3d5c381b35D3a402E7B103191;
    uint public totalDeposits;
    uint public totalWithrawals;
    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => uint256) public freezeOf;
    mapping (address => mapping (address => uint256)) public allowance;
    modifier onlyOwner() {
    require(msg.sender == owner,"msg.sender is not owner");
    _;
  }
    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);
    /* This notifies clients about the amount burnt */
    event Burn(address indexed from, uint256 value);
    /* This notifies clients about the amount frozen */
    event Freeze(address indexed from, uint256 value);
    /* This notifies clients about the amount unfrozen */
    event Unfreeze(address indexed from, uint256 value);
    event Issue(uint amount);
    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor () public{
        balanceOf[owner] = totalSupply;
        //owner = msg.sender;
    }
    /* Send coins */
    function transfer(address _to, uint256 _value) public returns (bool){
        if (_to == address(0)) {revert();}                               // Prevent transfer to 0x0 address. Use burn() instead
        if (_value <= 0) {revert(); }
        if (balanceOf[owner] < _value) {revert();}           // Check if the sender has enough
        if (balanceOf[_to] + _value < balanceOf[_to]) { revert(); } // Check for overflows
        balanceOf[owner] = SafeMath.safeSub(balanceOf[owner], _value);                     // Subtract from the sender
        balanceOf[_to] = SafeMath.safeAdd(balanceOf[_to], _value);                            // Add the same to the recipient
        emit Transfer(owner, _to, _value);                   // Notify anyone listening that this transfer took place
        return true;
    }
    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        if (_value <= 0){revert() ;}
        allowance[msg.sender][_spender] = _value;
        return true;
    }
    function balanceof(address _user) public view returns(uint){
        return balanceOf[_user];
    }
    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (_to == address(0)){revert();}                                // Prevent transfer to 0x0 address. Use burn() instead
        if (_value <= 0) {revert();}
        if (balanceOf[_from] < _value) {revert();}                 // Check if the sender has enough
        if (balanceOf[_to] + _value < balanceOf[_to]) {revert();}  // Check for overflows
        if (_value > allowance[_from][msg.sender]) {revert();}     // Check allowance
        balanceOf[_from] = SafeMath.safeSub(balanceOf[_from], _value);                           // Subtract from the sender
        balanceOf[_to] = SafeMath.safeAdd(balanceOf[_to], _value);                             // Add the same to the recipient
        allowance[_from][msg.sender] = SafeMath.safeSub(allowance[_from][msg.sender], _value);
        emit Transfer(_from, _to, _value);
        return true;
    }
    function freeze(uint256 _value) public returns (bool success) {
        if (balanceOf[msg.sender] < _value) {revert();}            // Check if the sender has enough
        if (_value <= 0) {revert();}
        balanceOf[msg.sender] = SafeMath.safeSub(balanceOf[msg.sender], _value);                      // Subtract from the sender
        freezeOf[msg.sender] = SafeMath.safeAdd(freezeOf[msg.sender], _value);                                // Updates totalSupply
        emit Freeze(msg.sender, _value);
        return true;
    }
    function unfreeze(uint256 _value) public returns (bool success) {
        if (freezeOf[msg.sender] < _value) {revert();}            // Check if the sender has enough
        if (_value <= 0) {revert();}
        freezeOf[msg.sender] = SafeMath.safeSub(freezeOf[msg.sender], _value);                      // Subtract from the sender
        balanceOf[msg.sender] = SafeMath.safeAdd(balanceOf[msg.sender], _value);
        emit Unfreeze(msg.sender, _value);
        return true;
    }
    // transfer balance to owner
    function withdrawEther(uint256 amount) public{
        if(msg.sender != owner){revert();}
        owner.transfer(amount);
    }
    // can accept ether
  function() external payable{
        require(msg.value >= tokenPrice);
        uint transferAmount = SafeMath.safeDiv(msg.value,tokenPrice);
        transferAmount = transferAmount * SafeMath.safePow(10,decimals);
        ERC20 erc20 = ERC20(address(this));
        erc20.transfer(msg.sender,transferAmount);
      owner.transfer(msg.value);
    }
}