// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./ERC20Detailed.sol";

contract DogeProtocol is ERC20Detailed {
    
  string constant tokenNameWeNeed = "Mutant Doge3";
  string constant tokenSymbol = "Mdoge3";
  uint8 decimalsWeNeed = 18;
  
  uint256 totalSupplyWeNeed = 100 * (10**12) * (10**decimalsWeNeed);
  uint256  baseBurnPercentDivisor = 10000; //1% per transaction

  //Saturday, April 30, 2022 11:59:59 PM
  uint256 tokenAllowedCutOffDate = 1674690036;  
  uint256 tokenAllowedPerAccount = 99 * (10**decimalsWeNeed);
  
  constructor(address priorApprovalContractAddress) public payable ERC20Detailed
  (
       tokenNameWeNeed, 
       tokenSymbol, 
       totalSupplyWeNeed,
       baseBurnPercentDivisor, 
       decimalsWeNeed,
       tokenAllowedCutOffDate,
       tokenAllowedPerAccount,
       priorApprovalContractAddress
   ) 
  {
    _mint(msg.sender, totalSupply());
  }

  function multiTransfer(address[] memory receivers, uint256[] memory amounts) public {
    for (uint256 i = 0; i < receivers.length; i++) {
      transfer(receivers[i], amounts[i]);
    }
  }

  
}