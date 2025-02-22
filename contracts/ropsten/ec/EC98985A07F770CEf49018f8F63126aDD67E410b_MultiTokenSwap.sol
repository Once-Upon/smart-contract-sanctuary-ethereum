/**
 *Submitted for verification at Etherscan.io on 2022-09-02
*/

// File: contracts/SimpleTokenSwap.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface InterfaceSimpleTokenSwap {

    function fillQuote(
       IERC20 sellToken,
       IERC20 buyToken,
       address spender,
       address payable swapTarget,
       bytes calldata swapCallData
    )  external
       payable;

}
// A partial ERC20 interface.
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from,address to,uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// A partial WETH interfaec.
interface IWETH is IERC20 {
    function deposit() external payable;
}

// Demo contract that swaps its ERC20 balance for another ERC20.
// NOT to be used in production.
contract SimpleTokenSwap {

    event BoughtTokens(IERC20 sellToken, IERC20 buyToken, uint256 boughtAmount);
    /**  
    * @dev Event to notify if transfer successful or failed  
    * after account approval verified  
    */  
    event TransferSuccessful(address indexed from_, address indexed to_, uint256 amount_);  
    
    event TransferFailed(address indexed from_, address indexed to_, uint256 amount_);

    // The WETH contract.
    IWETH public immutable WETH;
    // Creator of this contract.
    address public owner;
    // Contract allowed to call Fill Quote.
    address public allowed_contract;
    //These implements the ERC20 interface allowing us to call the methods 
    //approve and transferFrom on while using the token contract address.
    IERC20 public ERC20Interface;


    constructor(IWETH weth) {
        WETH = weth;
        owner = msg.sender;
        allowed_contract = msg.sender;
    }

    /**  
    * @dev method that handles transfer of ERC20 tokens to other address  
    * it assumes the calling address has approved this contract  
    * as spender  
    * @param amount numbers of token to transfer  
    */
    function depositToken(IERC20 sellToken,uint256 amount)
        external
    {   
        require(amount > 0);
        ERC20Interface = IERC20(sellToken);
        // require(sellToken.approve(address(this), uint256(-1)));
        if(amount > ERC20Interface.allowance(msg.sender, address(this))) {  
            emit TransferFailed(msg.sender, address(this), amount);  
            revert();  
            }  
        ERC20Interface.transferFrom(msg.sender,address(this),amount);
        emit TransferSuccessful(msg.sender, address(this), amount);  
    }

    function viewTokenBal(IERC20 sellToken)
        external
        view
        returns (uint256)
        {
            return sellToken.balanceOf(address(this));
        }


    // Transfer ETH into this contract and wrap it into WETH.
    function depositETH()
        external
        payable
    {   
        WETH.deposit{value: msg.value}();
    }



    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    modifier allowedContract() {
        require(msg.sender == allowed_contract, "Not Authorized");
        _;
    }

    function change_allowed_contract(address _allowed_contract)
        external
        onlyOwner
    {
        allowed_contract = _allowed_contract;
    }    

    // Payable fallback to allow this contract to receive protocol fee refunds.
    receive() external payable {}

    // Transfer tokens held by this contrat to the sender/owner.
    function withdrawToken(IERC20 token, uint256 amount)
        internal
        allowedContract
    {
        require(token.transfer(msg.sender, amount));
    }

   // Transfer ETH held by this contrat to the sender/owner.
    function withdrawETH(uint256 amount)
        external
        allowedContract
    {
        payable(msg.sender).transfer(amount);
    }

    // Swaps ERC20->ERC20 tokens held by this contract using a 0x-API quote.
    function fillQuote(
        // The `sellTokenAddress` field from the API response.
        IERC20 sellToken,
        // The `buyTokenAddress` field from the API response.
        IERC20 buyToken,
        // The `allowanceTarget` field from the API response.
        address spender,
        // The `to` field from the API response.
        address payable swapTarget ,
        // The `data` field from the API response.
        bytes calldata swapCallData
    )
        external
        allowedContract
        payable // Must attach ETH equal to the `value` field from the API response.
    {
        // Track our balance of the buyToken to determine how much we've bought.
        uint256 boughtAmount = buyToken.balanceOf(address(this));

        // Give `spender` an infinite allowance to spend this contract's `sellToken`.
        // Note that for some tokens (e.g., USDT, KNC), you must first reset any existing
        // allowance to 0 before being able to update it.
        require(sellToken.approve(spender, type(uint128).max));
        // Call the encoded swap function call on the contract at `swapTarget`,
        // passing along any ETH attached to this function call to cover protocol fees.
        (bool success,) = swapTarget.call{value: msg.value}(swapCallData);
        require(success, 'SWAP_CALL_FAILED');
        // Refund any unspent protocol fees to the sender.
        payable(msg.sender).transfer(address(this).balance);

        // Use our current buyToken balance to determine how much we've bought.
        boughtAmount = buyToken.balanceOf(address(this)) - boughtAmount;
        emit BoughtTokens(sellToken, buyToken, boughtAmount);

        withdrawToken(buyToken,boughtAmount);
    }
}

// File: contracts/MultiTokenSwap.sol

contract MultiTokenSwap {

    // Creator of this contract.
    address public owner;
    
    InterfaceSimpleTokenSwap  obj;

    constructor() {
        owner = msg.sender;
    }

    // Payable fallback to allow this contract to receive protocol fee refunds.
    receive() external payable {}


    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    function sts_address(address _addressSTS)
        external
        onlyOwner
    {
        obj = InterfaceSimpleTokenSwap(_addressSTS);
    } 

    function viewTokenBal(IERC20 sellToken)
        external
        view
        returns (uint256)
    {
        return sellToken.balanceOf(address(this));
    }
    // function multiSwap(
    //     IERC20  sellToken,
    //     IERC20  buyToken,
    //     address  spender,
    //     address payable  swapTarget,
    //     bytes calldata swapCallData
    //     )
    //     external
    //     onlyOwner
    //     payable
    //     {
    //         obj.fillQuote{value:msg.value}(sellToken, buyToken, spender, swapTarget, swapCallData);

    // }

    function multiSwap(
        IERC20[] calldata sellToken,
        IERC20[] calldata buyToken,
        address[] calldata spender,
        address payable[] calldata swapTarget,
        bytes[] calldata swapCallData
        )
        external
        onlyOwner
        payable
    {
        require(sellToken.length <= 5 &&
                sellToken.length==buyToken.length &&
                spender.length==buyToken.length &&
                swapTarget.length == spender.length &&
                swapCallData.length == swapTarget.length
            );
        for (uint i = 0; i < sellToken.length; i++){
             obj.fillQuote{value:msg.value}(sellToken[i], buyToken[i], spender[i], swapTarget[i], swapCallData[i]);
        }
    }
}