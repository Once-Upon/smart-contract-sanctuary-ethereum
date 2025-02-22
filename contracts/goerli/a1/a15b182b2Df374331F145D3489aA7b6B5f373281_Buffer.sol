// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;



import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract Buffer is ReentrancyGuard {

   
    uint256 public royaltyFeePercent = 1000;
    uint256 private montageShare = 1000;
    
    address public marketWallet = 0xB15DFb31A96b94ec150A237Bfc3d464Affe774f7; 
    address public owner = 0xB15DFb31A96b94ec150A237Bfc3d464Affe774f7;
    address private validPayee;
    

   
    event WithdrawnCheck(address to, uint256 amount);
    event PayeeAdded(address payee);
    event FeeReceived(address to, uint256 amount);
    event PayeeReset(address resetPayee);

    modifier onlyOwner() {
		_checkOwner();
		_;
    }

    modifier onlyGoodAddy() {

        require (tx.origin == msg.sender, "No external contract calls plz.");
        require (msg.sender != address(0));
        _;

    }


    function _checkOwner() internal view {
        require(msg.sender == owner, "Only owner can call this function");
       
    }

    

    //============ Function to Receive ETH ============
    receive() external payable {
       
        uint256 montageFee = msg.value * montageShare / 10000;
       
        _transfer(marketWallet, montageFee);
       
        emit FeeReceived(address(this), msg.value);
    }

    //============ Function to Add Valid Payee ============
    function addValidPayee(address _newPayee) external onlyOwner onlyGoodAddy {
         validPayee = _newPayee;
         emit PayeeAdded(validPayee);
    }

      
       
    //============ Function to Withdraw ETH ============
    function withdraw(uint256 _shareAmount) external nonReentrant onlyGoodAddy {
         require (msg.sender == validPayee, "This address is not authorized for withdrawal");
      
        
        _transfer(validPayee, _shareAmount); 
        validPayee = address(0);


        emit WithdrawnCheck(validPayee, _shareAmount);
        emit PayeeReset(validPayee);
    }


    
    
    // adopted from https://github.com/lexDAO/Kali/blob/main/contracts/libraries/SafeTransferLib.sol
    error TransferFailed();
    //============ Function to Transfer ETH to Address ============
    function _transfer(address to, uint256 amount) internal {
        bool callStatus;
        assembly {
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }
        if (!callStatus) revert TransferFailed();
    }

    
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}