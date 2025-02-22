/**
 *Submitted for verification at Etherscan.io on 2023-03-16
*/

// SPDX-License-Identifier: MIT

/*

   __  __      ______                 __ 
  / / / /___  / ____/________  ____  / /_
 / / / / __ \/ /_  / ___/ __ \/ __ \/ __/
/ /_/ / /_/ / __/ / /  / /_/ / / / / /_  
\____/ .___/_/   /_/   \____/_/ /_/\__/  
    /_/                                  

UpFront Treasury

*/

pragma solidity >=0.8.18 <0.9.0;

interface IERC20 {
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
  function isContract(address _contract) internal view returns (bool) {
    return _contract.code.length > 0;
  }
}

abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}

abstract contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor() {
    _setOwner(_msgSender());
  }

  function owner() external view virtual returns (address) {
    return _owner;
  }

  modifier isOwner() {
    require(_owner == _msgSender(), "Caller must be the owner.");

    _;
  }

  function transferOwnership(address newOwner) external virtual isOwner {
    require(newOwner != address(0));

    _setOwner(newOwner);
  }

  function _setOwner(address newOwner) internal {
    address oldOwner = _owner;
    _owner = newOwner;

    emit OwnershipTransferred(oldOwner, newOwner);
  }
}

abstract contract ReentrancyGuard is Ownable {
  bool internal locked;

  modifier nonReEntrant() {
    require(!locked, "No re-entrancy.");

    locked = true;
    _;
    locked = false;
  }

  function resetLocked() public isOwner {
    locked = false;
  }
}

contract UpFrontTreasury is Context, Ownable, ReentrancyGuard {
  string public constant VERSION = "1.0.2";
  uint256 public count;

  struct tokenInterfaceDataStruct {
    bool exists;
    IERC20 token;
  }

  address[] private tokenInterfaceList;
  mapping(address => tokenInterfaceDataStruct) private tokenInterfaceData;

  event Withdrawn(address indexed to, uint256 amount, address executor);
  event Deposit(address indexed from, uint256 amount);

  receive() external payable {
    emit Deposit(msg.sender, msg.value);
  }

  fallback() external payable {
    require(msg.data.length == 0);

    emit Deposit(msg.sender, msg.value);
  }

  function addTokenInterface(address _contract) external isOwner {
    require(!tokenInterfaceData[_contract].exists, "Interface already exists.");
    require(Address.isContract(_contract), "Not a contract.");

    tokenInterfaceList.push(_contract);
    tokenInterfaceData[_contract].exists = true;
    tokenInterfaceData[_contract].token = IERC20(_contract);
  }

  function listTokenInterfaces() external view returns (address[] memory) {
    return tokenInterfaceList;
  }

  function incrementAsOwner(uint256 i) external isOwner {
    count += i;
  }

  function incrementAsPublic(uint256 i) external {
    count += i;
  }

  function withdraw(address payable _to, uint256 _amount) external payable isOwner nonReEntrant {
    require(getBalance() >= _amount, "Insufficient balance.");

    (bool success, bytes memory response) = _to.call{ value: _amount }("");

    if (!success) {
      if (response.length > 0) {
        assembly {
          let size := mload(response)

          revert(add(32, response), size)
        }
      } else {
        revert("Function call reverted.");
      }
    }

    emit Withdrawn(_to, _amount, msg.sender);
  }

  function withdrawToken(address _contract, address _to, uint256 _amount) external isOwner nonReEntrant {
    require(tokenInterfaceData[_contract].exists, "Unknown token interface.");
    require(getTokenBalance(_contract) >= _amount, "Insufficient balance.");

    bool success = tokenInterfaceData[_contract].token.transfer(_to, _amount);
    require(success, "Transfer error.");

    emit Withdrawn(_to, _amount, msg.sender);
  }

  function getBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getTokenBalance(address _contract) public view returns (uint256) {
    require(tokenInterfaceData[_contract].exists, "Unknown token interface.");

    return tokenInterfaceData[_contract].token.balanceOf(address(this));
  }
}