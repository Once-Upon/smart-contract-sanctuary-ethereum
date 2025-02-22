/**
 *Submitted for verification at Etherscan.io on 2022-05-11
*/

pragma solidity ^0.8.7;
interface ERC721 {
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
  event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
 
  function totalSupply() external view returns (uint256 total);
  function balanceOf(address _owner) external view returns (uint256 _balance);
  function ownerOf(uint256 _tokenId) external view returns (address _owner);
  function transfer(address _to, uint256 _tokenId) external;
  function approve(address _to, uint256 _tokenId) external;
  function transferFrom(address _from, address _to, uint256 _tokenId) external;
  function name() external view returns (string memory _name);
  function symbol() external view returns (string memory _symbol);
}

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {

    uint256 c = a / b;

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Ownable {
  address public owner;
 
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor() {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
 
}
 
 
 
contract animalMain is  ERC721,Ownable {
 
  using SafeMath for uint256;
    string public name_ = "1072932";
 
  struct animal {
    bytes32 dna; //DNA
    uint8 star; //幾星級(抽卡的概念)
    uint16 roletype; //(哪種動物 1老虎  2狗  3獅子  4鳥)
  }
 
  animal[] public animals;
  string public symbol_ = "1072932";
 
  mapping (uint => address) public animalToOwner; //每隻動物都有一個獨一無二的編號，呼叫此mapping，得到相對應的主人
  mapping (address => uint) ownerAnimalCount; //回傳某帳號底下的動物數量
  mapping (uint => address) animalApprovals; //和 ERC721 一樣，是否同意被轉走
 
  event Take(address _to, address _from,uint _tokenId);
  event Create(uint _tokenId, bytes32 dna,uint8 star, uint16 roletype);
 
  function name() override external view returns (string memory) {
        return name_;
  }
 
  function symbol() override external view returns (string memory) {
        return symbol_;
  }
 
  function totalSupply() override public view returns (uint256) {
    return animals.length;
  }
 
  function balanceOf(address _owner) override public view returns (uint256 _balance) {
    return ownerAnimalCount[_owner]; // 此方法只是顯示某帳號 餘額
  }
 
  function ownerOf(uint256 _tokenId) override public view returns (address _owner) {
    return animalToOwner[_tokenId]; // 此方法只是顯示某動物 擁有者
  }
 
  function checkAllOwner(uint256[] memory _tokenId, address owner) public view returns (bool) {
    for(uint i=0;i<_tokenId.length;i++){
        if(owner != animalToOwner[_tokenId[i]]){
            return false;   //給予一連串動物，判斷使用者是不是都是同一人
        }
    }
   
    return true;
  }
 
  function seeAnimalDna(uint256 _tokenId) public view returns (bytes32 dna) {
    return animals[_tokenId].dna;
  }
 
  function seeAnimalStar(uint256 _tokenId) public view returns (uint8 star) {
    return animals[_tokenId].star;
  }
 
  function seeAnimalRole(uint256 _tokenId) public view returns (uint16 roletype) {
    return animals[_tokenId].roletype;
  }
 
  function getAnimalByOwner(address _owner) external view returns(uint[] memory) { //此方法回傳所有帳戶內的"動物ID"
    uint[] memory result = new uint[](ownerAnimalCount[_owner]);
    uint counter = 0;
    for (uint i = 0; i < animals.length; i++) {
      if (animalToOwner[i] == _owner) {
        result[counter] = i;
        counter++;
      }
    }
    return result;
  }
 
  function transfer(address _to, uint256 _tokenId) override public {

      require(animalToOwner[_tokenId]==msg.sender);
      ownerAnimalCount[_to]=ownerAnimalCount[_to].add(1);
      ownerAnimalCount[msg.sender]=ownerAnimalCount[msg.sender].sub(1);
      animalToOwner[_tokenId] = _to;
      
    emit Transfer(msg.sender, _to, _tokenId);
  }
 
  function approve(address _to, uint256 _tokenId) override public {
    require(animalToOwner[_tokenId] == msg.sender);
   
    animalApprovals[_tokenId] = _to;
   
    emit Approval(msg.sender, _to, _tokenId);
  }
 
  function transferFrom(address _from, address _to, uint256 _tokenId) override external {
    // Safety check to prevent against an unexpected 0x0 default.
 
   require(animalApprovals[_tokenId] == msg.sender);
   ownerAnimalCount[_to]=ownerAnimalCount[_to].add(1);
   ownerAnimalCount[_from]=ownerAnimalCount[_from].sub(1);
   animalToOwner[_tokenId] = _to;
 
    emit Transfer(_from, _to, _tokenId);
  }
 
  function takeOwnership(uint256 _tokenId) public {
    require(animalToOwner[_tokenId] == msg.sender);
   
    address owner = ownerOf(_tokenId);
 
    ownerAnimalCount[msg.sender] = ownerAnimalCount[msg.sender].add(1);
    ownerAnimalCount[owner] = ownerAnimalCount[owner].sub(1);
    animalToOwner[_tokenId] = msg.sender;
   
    emit Take(msg.sender, owner, _tokenId);
  }
 
  function createAnimal() payable public {
 
       bytes32 dna;
       uint star;
       uint roletype;
       
       dna = keccak256(abi.encodePacked(block.coinbase, blockhash(block.number-1), block.timestamp, msg.sender));

       uint range_of_star = uint(dna)%100;
       if(range_of_star<40){star = 1; }
       else if(range_of_star<65){star = 2; }
       else if(range_of_star<85){star = 3; }
       else if(range_of_star<95){star = 4; }
       else {star = 5; }

       roletype = uint(dna)%4;

       require(msg.value == 0.001 ether);

      animals.push(animal(dna, uint8(star), uint8(roletype)));
      uint id = animals.length - 1;
      animalToOwner[id] = msg.sender;
      ownerAnimalCount[msg.sender]++;
 
  }
 
}