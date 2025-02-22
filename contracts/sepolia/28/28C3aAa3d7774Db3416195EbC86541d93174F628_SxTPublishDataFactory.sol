// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./UserRequestString2D.sol";
import "./UserRequestUint256.sol";
import "./UserRequestString.sol";
import "./UserRequestBytes.sol";

/**
 * @title Space and Time Publish Data On-Chain Factory contract
 * @notice Factory contract used to deploy new UserRequest child contracts for automating the requests
 * @notice The contract will be able to create child contracts depending on the choice of contract type, and transfer LINK tokens to them 
 */

contract SxTPublishDataFactory is ConfirmedOwner {

  /// @dev LINK Token amount to be sent to child contract after deployment
  uint96 public childContractFundAmount;

  /// @dev Relay Address
  ISxTRelayProxy public relayContract;

  /// @dev Link Token Address
  LinkTokenInterface public linkToken;

  /// Enum to store choice for selecting which contract you want to deploy
  enum childContractType{STRING2D, UINT, STRING, BYTES} 

  /// Struct to store child contract details
  struct ChildContractDetail{
    ISxTRelayProxy relayContract;
    LinkTokenInterface linkToken;
    childContractType choice;
  }

  /// @dev mapping to store count of deployed contracts for each 
  mapping(childContractType => uint8) public childContractCount;

  /// @dev Keep track of deployed contract details
  mapping(address => ChildContractDetail) public deployedChildContractDetail;

  /// @dev Event emitted when new child contract is deployed using this factory contracts
  event DeployedChildContractByChoice(address indexed deployedChildAddress, ISxTRelayProxy indexed relayContract, LinkTokenInterface indexed linkToken, childContractType choice);

  /// @dev Event emitted when funding amount is updated
  event ChildContractFundAmountUpdated(uint96 indexed childContractFundAmount);

  /// @dev Event emitted when relay contract address is updated
  event RelayAddressUpdated(address indexed relayContract);

  /** 
   * @dev The constructor sets the owner of the contract at the time of deployment
   * @param linkTokenAddress - Address of the LINK token that would be transferred to child contracts and passed to them as parameter
   */
  constructor(ISxTRelayProxy relayContractAddress, LinkTokenInterface linkTokenAddress) 
  ConfirmedOwner(msg.sender)
  {
    relayContract = relayContractAddress;
    linkToken = linkTokenAddress;
    childContractFundAmount = 1 gwei;
  } 

  /**
   * @dev Update relay contract address saved in the contract
   * @dev Only owner can call the function
   * @param relayContractAddress - Address of the new relay address
   */  
  function updateRelay(ISxTRelayProxy relayContractAddress) external onlyOwner {
    relayContract = relayContractAddress;
    emit RelayAddressUpdated(address(relayContract));
  }

  /**
   * @dev Update childContractFundAmount saved in the contract
   * @dev Only owner can call the function
   * @param amount - New funding amount to be updated in the contract
   */
  function updateFundAmount(uint96 amount) external onlyOwner {
    childContractFundAmount = amount;
    emit ChildContractFundAmountUpdated(childContractFundAmount);
  }

  /**
   * @dev Transfer LINK tokens from the contract to other address
   * @dev Used to transfer LINK tokens to child contracts after deployment
   * @dev Only owner can call the function
   * @param receiver - Address to send LINK tokens to
   * @param amount - Amount of link tokens to be transferred
   */
  function transferLINKTokens(address receiver, uint256 amount) public onlyOwner {
    // require(receiver != address(0), "SxTPublishDataFactory: Cannot set to Zero Address");
    require(linkToken.balanceOf(address(this)) >= amount && receiver != address(0), "SxTPublishDataFactory: Insufficient LINK balance or Invalid receiver");
    (bool sent) = linkToken.transfer(receiver, amount);
    require(sent, "SxTPublishDataFactory: Failed to transfer token to user");
  }

  /**
   * @dev Deploy new child contract, on the basis of choice  
   * @dev Also transfers LINK tokens amount equal to childContractFundAmount to newly deployed child contract
   * @dev Only owner can call the function
   * @param choice - Index from Enum childContractType to specify which type of child contract to deploy
   */  
  function deployChildContractByChoice(childContractType choice) external onlyOwner{
    address deployedChildAddress;
    if(childContractType.STRING2D == choice){
      deployedChildAddress = deploy2DStringChild();        
    }
    else if(childContractType.UINT == choice){
      deployedChildAddress= deployUint256Child();
    }
    else if(childContractType.STRING == choice){
      deployedChildAddress = deployStringChild();
    }
    else if(childContractType.BYTES == choice){
      deployedChildAddress = deployBytesChild();
    }
    childContractCount[choice] +=1;
    transferLINKTokens(deployedChildAddress, uint256(childContractFundAmount));  
    emit DeployedChildContractByChoice(deployedChildAddress, relayContract, linkToken, choice);
  }

  /**
   * @dev Internal function to deploy new child contract of type 'String2D'  
   * @return userString2d -Address of new deployed child contract of type 'String2D'
   */    
  function deploy2DStringChild() internal returns(address){
    UserRequestString2D userString2d = new UserRequestString2D(relayContract, linkToken, msg.sender);
    ChildContractDetail memory data = ChildContractDetail(relayContract, linkToken, childContractType.STRING2D);
    deployedChildContractDetail[address(userString2d)] = data;
    return address(userString2d);
  }

  /**
   * @dev Internal function to deploy new child contract of type 'Uint256'  
   * @return userUint -Address of new deployed child contract of type 'Uint256'
   */  
  function deployUint256Child() internal returns(address) {
    UserRequestUint256 userUint = new UserRequestUint256(relayContract, linkToken, msg.sender);
    ChildContractDetail memory data = ChildContractDetail(relayContract, linkToken, childContractType.UINT);
    deployedChildContractDetail[address(userUint)]=data;
    return address(userUint);
  }

  /**
   * @dev Internal function to deploy new child contract of type 'String'  
   * @return userStr -Address of new deployed child contract of type 'String'
   */    
  function deployStringChild() internal returns(address) {
    UserRequestString userStr = new UserRequestString(relayContract, linkToken, msg.sender);
    ChildContractDetail memory data = ChildContractDetail(relayContract, linkToken, childContractType.STRING);
    deployedChildContractDetail[address(userStr)]=data;
    return address(userStr);
  }

  /**
   * @dev Internal function to deploy new child contract of type 'Bytes'  
   * @return userBytes -Address of new deployed child contract of type 'Bytes'
   */
  function deployBytesChild() internal returns(address) {
    UserRequestBytes userBytes = new UserRequestBytes(relayContract, linkToken, msg.sender);
    ChildContractDetail memory data = ChildContractDetail(relayContract,linkToken,childContractType.BYTES);
    deployedChildContractDetail[address(userBytes)]=data;
    return address(userBytes);
  }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./UserRequest.sol";

/**
 * @title User Request Uint256 contract
 * @notice User Request contract for uint256 type of response using chainlink direct request
 * @notice The contract will be able to create the request and get response for that request
 */
contract UserRequestUint256 is UserRequest {

    /// @dev Chainlink Request call response
    uint256 public currentResponse;

    /// @dev Chainlink Request call latest error message
    string public latestError;

    /** 
     * @dev The constructor sets the SxTRelay and LINK token contract address
     * @param sxtRelayAddress - SxT relay contract address which will be used for sending requests, request fee, and receiving response
     * @param chainlinkTokenAddress - LINK Token address
     */
    constructor (ISxTRelayProxy sxtRelayAddress, LinkTokenInterface chainlinkTokenAddress, address ownerAddress)
        UserRequest(sxtRelayAddress, chainlinkTokenAddress, ownerAddress)
    {}

    /**
     * @dev triggers the requestQueryUint256 function of the SxTRelay contract
     * @param query - sql query for which response is needed
     * @param resourceId - resource id for sending request to SxT Gateway
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestQuery(string memory query, string memory resourceId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );        
        requestId = (getSxTRelayContract()).requestQueryUint256(query, resourceId, address(this), this.saveQueryResponse.selector, jobId);
    }

    /**
     * @dev triggers the requestViewUint256 function of the SxTRelay contract
     * @param viewId - Id of view saved in SxT Dapp for which response is needed
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestView(string memory viewId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );
        requestId = (getSxTRelayContract()).requestViewUint256(viewId, address(this), this.saveQueryResponse.selector, jobId);
    }

    /**
     * @dev This function will be called by SxTRelay for providing response for a created request
     * @dev The SxTRelay contract will be looking for the function name saveQueryResponse for saving the response
     * @param requestId - id of request for which response is to be stored
     * @param data - response of the request sent by SxT
     * @param errorMessage - error message send by SxT if there was an error while fetching response for the request
     */
    function saveQueryResponse(bytes32 requestId, uint256 data, string calldata errorMessage) external onlySxTRelay{
        currentRequestId = requestId;
        // Store response
        latestError = errorMessage;
        currentResponse = data;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./UserRequest.sol";

/**
 * @title User Request String2D contract
 * @notice User Request contract for string[][] type of response using chainlink direct request
 * @notice The contract will be able to create the request and get response for that request
 */
contract UserRequestString2D is UserRequest {

    /// @dev Chainlink Request call response
    string[][] public currentResponse;

    /// @dev Chainlink Request call latest error message
    string public latestError;

    /** 
     * @dev The constructor sets the SxTRelay and LINK token contract address
     * @param sxtRelayAddress - SxT relay contract address which will be used for sending requests, request fee, and receiving response
     * @param chainlinkTokenAddress - LINK Token address
     */
    constructor (ISxTRelayProxy sxtRelayAddress, LinkTokenInterface chainlinkTokenAddress, address ownerAddress)
        UserRequest(sxtRelayAddress, chainlinkTokenAddress, ownerAddress)
    {}

    /**
     * @dev triggers the requestQueryString2D function of the SxTRelay contract
     * @param query - sql query for which response is needed
     * @param resourceId - resource id for sending request to SxT Gateway
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestQuery(string memory query, string memory resourceId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );        
        requestId = getSxTRelayContract().requestQueryString2D(query, resourceId, address(this), this.saveQueryResponse.selector, jobId);
    }

    /**
     * @dev triggers the requestViewString2D function of the SxTRelay contract
     * @param viewId - Id of view saved in SxT Dapp for which response is needed
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestView(string memory viewId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );
        requestId = getSxTRelayContract().requestViewString2D(viewId, address(this), this.saveQueryResponse.selector, jobId);
    }
    
    /**
     * @dev This function will be called by SxTRelay for providing response for a created request
     * @dev The SxTRelay contract will be looking for the function name saveQueryResponse for saving the response
     * @param requestId - id of request for which response is to be stored
     * @param data - response of the request sent by SxT
     * @param errorMessage - error message send by SxT if there was an error while fetching response for the request
     */
    function saveQueryResponse(bytes32 requestId, string[][] calldata data, string calldata errorMessage) external onlySxTRelay{
        delete currentResponse;
        currentRequestId = requestId;
        // Store response
        latestError = errorMessage;
        for (uint256 i = 0; i < data.length; i++) {
            uint256 inLength = data[i].length;
            string[] memory row = new string[](inLength);
            for (uint256 j = 0; j < inLength; j++) {
                row[j] = data[i][j];
            }
            currentResponse.push(row);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./UserRequest.sol";


/**
 * @title User Request String contract
 * @notice User Request contract for string type of response using chainlink direct request
 * @notice The contract will be able to create the request and get response for that request
 */
contract UserRequestString is UserRequest {

    /// @dev Chainlink Request call response
    string public currentResponse;

    /// @dev Chainlink Request call latest error message
    string public latestError;

    /** 
     * @dev The constructor sets the SxTRelay and LINK token contract address
     * @param sxtRelayAddress - SxT relay contract address which will be used for sending requests, request fee, and receiving response
     * @param chainlinkTokenAddress - LINK Token address
     */
    constructor (ISxTRelayProxy sxtRelayAddress, LinkTokenInterface chainlinkTokenAddress, address ownerAddress)
        UserRequest(sxtRelayAddress, chainlinkTokenAddress, ownerAddress)
    {}

    /**
     * @dev triggers the requestQueryString function of the SxTRelay contract
     * @param query - sql query for which response is needed
     * @param resourceId - resource id for sending request to SxT Gateway
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestQuery(string memory query, string memory resourceId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );
        requestId = getSxTRelayContract().requestQueryString(query, resourceId, address(this), this.saveQueryResponse.selector, jobId);
    }

    /**
     * @dev triggers the requestViewString function of the SxTRelay contract
     * @param viewId - Id of view saved in SxT Dapp for which response is needed
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestView(string memory viewId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );        
        requestId = getSxTRelayContract().requestViewString(viewId, address(this), this.saveQueryResponse.selector, jobId);
    }

    /**
     * @dev This function will be called by SxTRelay for providing response for a created request
     * @dev The SxTRelay contract will be looking for the function name saveQueryResponse for saving the response
     * @param requestId - id of request for which response is to be stored
     * @param data - response of the request sent by SxT
     * @param errorMessage - error message send by SxT if there was an error while fetching response for the request
     */
    function saveQueryResponse(bytes32 requestId, string calldata data, string calldata errorMessage) external onlySxTRelay{
        currentRequestId = requestId;
        // Store response
        latestError = errorMessage;
        currentResponse = data;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./UserRequest.sol";

/**
 * @title User Request Bytes contract
 * @notice User Request contract for bytes type of response using chainlink direct request
 * @notice The contract will be able to create the request and get response for that request
 */
contract UserRequestBytes is UserRequest {

    /// @dev Chainlink Request call response
    bytes public currentResponse;

    /// @dev Chainlink Request call latest error message
    string public latestError;

    /** 
     * @dev The constructor sets the SxTRelay and LINK token contract address
     * @param sxtRelayAddress - SxT relay contract address which will be used for sending requests, request fee, and receiving response
     * @param chainlinkTokenAddress - LINK Token address
     */
    constructor (ISxTRelayProxy sxtRelayAddress, LinkTokenInterface chainlinkTokenAddress, address ownerAddress)
        UserRequest(sxtRelayAddress, chainlinkTokenAddress, ownerAddress)
    {}

    /**
     * @dev triggers the requestQueryBytes function of the SxTRelay contract
     * @param query - sql query for which response is needed
     * @param resourceId - resource id for sending request to SxT Gateway
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestQuery(string memory query, string memory resourceId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );
        requestId = getSxTRelayContract().requestQueryBytes(query, resourceId, address(this), this.saveQueryResponse.selector, jobId);
    }

    /**
     * @dev triggers the requestViewBytes function of the SxTRelay contract
     * @param viewId - Id of view saved in SxT Dapp for which response is needed
     * @param jobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function runRequestView(string memory viewId, string memory jobId) external nonReentrant returns(bytes32 requestId){
        require(
            getChainlinkToken().approve(
                address(getSxTRelayContract().impl()), 
                getSxTRelayContract().feeInLinkToken()), 
            "UserRequest: Insufficient LINK allowance"
        );        
        requestId = getSxTRelayContract().requestViewBytes(viewId, address(this), this.saveQueryResponse.selector, jobId);
    }

    /**
     * @dev This function will be called by SxTRelay for providing response for a created request
     * @dev The SxTRelay contract will be looking for the function name saveQueryResponse for saving the response
     * @param requestId - id of request for which response is to be stored
     * @param data - response of the request sent by SxT
     * @param errorMessage - error message send by SxT if there was an error while fetching response for the request
     */
    function saveQueryResponse(bytes32 requestId, bytes calldata data, string calldata errorMessage) external onlySxTRelay{
        currentRequestId = requestId;
        // Store response
        latestError = errorMessage;
        currentResponse = data;
    }

    /**
     * @dev This function is used for decoding the latest bytes response to string
     * @return decodedStringResponse - decoded string response
     */
    function getDecodedStringResponse() public view returns(string memory) {
        string memory decodedStringResponse = abi.decode(currentResponse, (string));
        return decodedStringResponse;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interfaces/ISxTRelayProxy.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * @title User Request abstract contract
 * @notice Abstract user contract to be inherited by user contracts to set the SxTRelay and LINK token address
 * @notice The contract specifies some functions to be present in the user contract
 */
abstract contract UserRequest is ReentrancyGuard, ConfirmedOwner{

    /// @dev Zero Address
    address constant ZERO_ADDRESS = address(0);

    /// @dev SxT Request contract address
    ISxTRelayProxy internal sxtRelayContract;

    /// @dev Chainlink token address
    LinkTokenInterface internal chainlinkToken;

    /// @dev Current request Id
    bytes32 public currentRequestId;

    /** 
     * @dev The constructor sets the SxTRelay and validator contract address
     * @param sxtRelayAddress - Address of the SxT request contract address that has Oracle and Job initialized on it
     * @param chainlinkTokenAddress - Address of the LINK token that would be used for payment
     */
    constructor (ISxTRelayProxy sxtRelayAddress, LinkTokenInterface chainlinkTokenAddress, address ownerAddress) 
    ConfirmedOwner(ownerAddress)
    {
        require(sxtRelayAddress != ISxTRelayProxy(ZERO_ADDRESS), "UserRequest: Cannot set to Zero Address");
        require(chainlinkTokenAddress != LinkTokenInterface(ZERO_ADDRESS), "UserRequest: Cannot set to Zero Address");
        sxtRelayContract = sxtRelayAddress;
        chainlinkToken = chainlinkTokenAddress;
    }

    /**
     * @dev Modifier to constraint only the SxTRelay contract to call the function
     */
    modifier onlySxTRelay() {
        require(msg.sender == address(getSxTRelayContract().impl()), "UserRequest: Only callable by SxT Request Contract");
        _;
    }

    /**
     * @dev Get Instance of SxTRelay Contract to interact with
     * @return sxtRelayContract - Address of the SxTRelay contract address
     */
    function getSxTRelayContract() public view returns(ISxTRelayProxy) {
        return sxtRelayContract;
    }

    /**
     * @dev Get Instance of Chainlink token contract to interact with
     * @return chainlinkToken - Address of the LINK token contract
     */
    function getChainlinkToken() public view returns(LinkTokenInterface){
        return chainlinkToken;
    }
    
    /**
     * @dev Withdraw Chainlink from contract
     * @param to - Address to transfer the LINK tokens
     * @param amount - Amount of the LINK tokens to transfer
     */
    function withdrawChainlink(address to, uint256 amount) external nonReentrant onlyOwner {
        bool transferResult = chainlinkToken.transfer(
            to,
            amount
        );
        require(transferResult, "UserRequest: Chainlink token transfer failed");
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./ISxTRelay.sol";

/**
 * @title The SxTRelayProxy contract interface
 * @notice Other contracts can use this interface to call SxTRelayProxy functions
 */
interface ISxTRelayProxy is ISxTRelay {
    
    /**
     * @dev Get the implementation SxTRelay contract address 
     */
    function impl() external view returns (ISxTRelay);

    /**
     * @dev Update implementation SxTRelay contract address 
     */
    function updateImpl(ISxTRelay sxtRelay) external;
    
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConfirmedOwnerWithProposal.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title The SxTRelay contract interface
 * @notice Other contracts can use this interface to call SxTRelay functions
 */
interface ISxTRelay {

    /**
     * @dev Event emitted when the LINK token fee is updated 
     */
    event LinkTokenFeeUpdated(uint256 newFee);

    /**
     * @dev Get the fees for calling the SxT Request Query 
     */
    function feeInLinkToken() external view returns (uint256);

    /**
     * @dev Get the current request ID  
     */
    function currentRequestId() external view returns (bytes32);
    
    /**
     * @dev Set Chainlink operator contract address
     * @param newOperator - Address of the new operator contract deployed
     */
    function setChainlinkOperator(address newOperator) external;

    /**
     * @dev Withdraw Chainlink from contract
     * @param to - Address to transfer the LINK tokens
     * @param amount - Amount of the LINK tokens to transfer
     */
    function withdrawChainlink(address to, uint256 amount) external;

    /**
     * @dev Update the LINK token fee for each request
     * @param newFee - New fee for Chainlink request in LINK token
     */
    function updateLinkTokenFee(uint256 newFee) external;

    /**
     * @dev Execute the request query and response type as string2D
     * @param query - SQL query requested by User contract
     * @param resourceId - Request id requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestQueryString2D(
        string memory query, 
        string memory resourceId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Execute the request query and response type as uint256
     * @param query - SQL query requested by User contract
     * @param resourceId - Request id requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestQueryUint256(
        string memory query, 
        string memory resourceId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Execute the request query and response type as bytes
     * @param query - SQL query requested by User contract
     * @param resourceId - Request id requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestQueryBytes(
        string memory query, 
        string memory resourceId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Execute the request query and response type as string
     * @param query - SQL query requested by User contract
     * @param resourceId - Request id requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestQueryString(
        string memory query, 
        string memory resourceId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Execute the request view and response type as string2D
     * @param viewId - view name requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestViewString2D(
        string memory viewId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Execute the request view and response type as uint256
     * @param viewId - view name requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestViewUint256(
        string memory viewId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Execute the request view and response type as bytes
     * @param viewId - view name requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestViewBytes(
        string memory viewId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Execute the request view and response type as string
     * @param viewId - view name requested by User contract
     * @param callerContract - User contract address that called this requestQuery function
     * @param callbackFunctionId - User contract callback function selector id
     * @param chainlinkJobId - Chainlink Job ID that SxT team has created on the Chainlink Oracle Node
     */
    function requestViewString(
        string memory viewId, 
        address callerContract, 
        bytes4 callbackFunctionId,
        string memory chainlinkJobId
    ) external returns (bytes32);

    /**
     * @dev Chainlink off-chain request callback function to fulfil the request for string2D response
     * @param requestId - The unique id of the request for which the function is triggered
     * @param data - The response data received for the query
     * @param errorMessage - The error message received for the query
     */
    function queryResponseString2D(
        bytes32 requestId, 
        string[][] calldata data,
        string calldata errorMessage
    ) external;

    /**
     * @dev Chainlink off-chain request callback function to fulfil the request for uint256 response
     * @param requestId - The unique id of the request for which the function is triggered
     * @param data - The response data received for the query
     * @param errorMessage - The error message received for the query
     */
    function queryResponseUint256(
        bytes32 requestId, 
        uint256 data,
        string calldata errorMessage
    ) external;

    /**
     * @dev Chainlink off-chain request callback function to fulfil the request for bytes response
     * @param requestId - The unique id of the request for which the function is triggered
     * @param data - The response data received for the query
     * @param errorMessage - The error message received for the query
     */
    function queryResponseBytes(
        bytes32 requestId, 
        bytes calldata data,
        string calldata errorMessage
    ) external;

    /**
     * @dev Chainlink off-chain request callback function to fulfil the request for string response
     * @param requestId - The unique id of the request for which the function is triggered
     * @param data - The response data received for the query
     * @param errorMessage - The error message received for the query
     */
    function queryResponseString(
        bytes32 requestId, 
        string calldata data,
        string calldata errorMessage
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/OwnableInterface.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}