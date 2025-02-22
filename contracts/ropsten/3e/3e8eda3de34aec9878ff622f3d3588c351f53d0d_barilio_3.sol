/**
 *Submitted for verification at Etherscan.io on 2022-05-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
    function decimals(uint256 a) internal pure returns (uint256 b) {
        b = a*10**18;
        return b;
    }
}

interface IERC1155 {
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);
    event URI(string _value, uint256 indexed _id);
    event Paid(address indexed _from, uint256 _value, uint timestamp);
    event Burn(address indexed burner, uint256 _id);

    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
}

contract barilio_3 is IERC1155 {

    using SafeMath for uint256;
    address public ownerContract;
    uint royalty;

    //id => creator
    mapping (uint256 => address) public creators;
    //id => uri
    mapping (uint256 => string) public mapUri;

    struct Item{
        string name;
        uint256 price;
        address creator;
        uint256 totalSupply;
        uint status;
    } 
    //id => Item
    mapping (uint256 => Item) public card;
   
    //id => (owner=>balance)
    mapping (uint256 => mapping (address => uint256)) internal balances; 

    constructor() {
        ownerContract = msg.sender;
        royalty = 15;
    }

    modifier creatorOnly(uint256 _id) { 
        require (creators[_id] == msg.sender);
        _;
    }

    modifier onlyOwner() { 
        require (ownerContract == msg.sender);
        _;
    }
    
    function getRoyalty() public view returns(uint) {
        return royalty;
    }
    function safeRoyalty(uint256 _value) public view returns(uint256) {
        return _value.sub(_value.mul(getRoyalty()).div(100));
    }

    function setRoyalty(uint _royalty) external onlyOwner{
        require( _royalty < 100, "_royalty Big!");
        royalty = _royalty;
    }

    function burn(uint256 _id) public creatorOnly( _id){
        delete creators[_id];
        delete card[_id];
        delete mapUri[_id];

        emit Burn(msg.sender, _id);
    }

    function recieveContract(address payable _owner, uint256 _value) public onlyOwner{
        require(address(this).balance >= _value, "not Summ!");
        _owner.transfer(_value);
    }

    function create(uint256 _id, uint256 _initialSupply, string calldata _uri, string calldata _name, uint256 _price) external {
        require(creators[_id] == address(0x0), "_id not Empty!");
        creators[_id] = msg.sender;

        card[_id].status = 0; // выпущен не продается
        card[_id].name = _name;
        card[_id].price = _price;
        card[_id].creator = msg.sender;
        card[_id].totalSupply = _initialSupply;

        balances[_id][msg.sender] = _initialSupply;
        mapUri[_id] = _uri;

        emit URI (_uri, _id);
        emit TransferSingle (msg.sender, address(0x0), msg.sender, _id, _initialSupply);
    }
    function sellItemStatus( uint256 _id, uint _status) public creatorOnly ( _id){
        require(_status <= 2, "status not!");
        card[_id].status = _status;
    }
    function cardOf(uint256 _id) public view returns (Item memory) {
       return card[_id];
    }
    function balanceOf(address _owner, uint256 _id) public view virtual override returns (uint256) {
        require(_owner != address(0x0), "ERC1155: balance query for the zero address");
        return balances[_id][_owner];
    }
    function getBalance(address _targetAddr) public view returns(uint) {
        return _targetAddr.balance;
    }
    function paymentsCost(uint256 _id, uint256 _totalSupply) public view returns(uint) {
        return card[_id].price.mul(_totalSupply);
    }
    function sell(uint256 _id, uint _amount) public payable{

        require(creators[_id] != address(0x0), "_id not token!");
        require(card[_id].status == 1, "_id not sale!");
        require(msg.value > 0, "erorr value!");

        uint256 _value = msg.value;
        require(msg.sender.balance >= _value, "erorr balance!");
        require(_amount > 0 , "erorr supply!");
        require(balances[_id][creators[_id]] >= _amount , "erorr token na balances!");
        require(paymentsCost(_id, _amount) == _value, "erorr value summ!");

        uint256 summ = safeRoyalty(msg.value);
        payable(creators[_id]).transfer(summ);     
        transferTo(_id,_amount, summ);
        
    }
    function transferTo( uint256 _id, uint256 _amount, uint256 _value) internal {
 
        address _from = creators[_id];
        address _to = msg.sender;

        balances[_id][_from] = balances[_id][_from].sub(_amount);
        balances[_id][_to]   = _amount.add(balances[_id][_to]);
        if (balances[_id][_from]==0)  card[_id].status = 2;

        emit Paid(msg.sender, _value, block.timestamp);
        emit TransferSingle(msg.sender, _from, msg.sender, _id, _amount);
    }
    receive() external payable onlyOwner{
    }
}