// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./ProductOrder.sol";

contract ProductOrderFactory {
    event POCreated(address PO, address purchaser, uint256 amountOfMoney, uint256 acceptTimeStamp);

    function createProductOrder(address vendorAddress, uint256 PONo, uint256 timeToAccept, uint256 timeToShip) public payable {
        address purchaser = msg.sender;
        uint256 amountOfMoney = msg.value;
        uint256 acceptTimeStamp = block.timestamp;

        ProductOrder productOrder = new ProductOrder(purchaser, vendorAddress, PONo, amountOfMoney, timeToAccept, acceptTimeStamp, timeToShip);
        address POAddress = address(productOrder);
        
        payable(POAddress).transfer(msg.value);

        // Sets up Upkeep for new contract.
        //     https://docs.chain.link/docs/chainlink-automation/automation-economics/
        //     https://automation.chain.link/?_ga=2.66826409.62596235.1667583413-1479646050.1660059585

        emit POCreated(POAddress, purchaser, amountOfMoney, acceptTimeStamp);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error ProductOrder__NotPurchaser();
error ProductOrder__NotVendor();


contract ProductOrder is KeeperCompatibleInterface {
    // State of Order
    enum POState {
	    SENT,
	    CANCELLED,
	    ACCEPTED,
	    DISPUTE,
        END,
        DISPUTE_END
    }
    POState private s_state;
    
    // All addresses
    address private immutable i_purchaserAddress;
    address private immutable i_vendorAddress;

    // Amount of Money currently in contract
    uint256 private s_amountOfMoney;

    // Identifier to know what purchase order it is.
    uint256 private immutable i_PONo;

    // Timing to accept and shipping
    uint256 private immutable i_timeToAccept;
    uint256 private immutable i_acceptTimeStamp;
    uint256 private immutable i_timeToShip;
    uint256 private s_shippingTimeStamp;

    // Dispute Variables
    int256 private s_tokenWorthGot = -1;
    uint256 private s_tokenWorthShipped;

    // Events??

    // Modifiers
    modifier onlyPurchaser() {
        if (msg.sender != i_purchaserAddress) revert ProductOrder__NotPurchaser();
        _;
    }
    modifier onlyVendor() {
        if (msg.sender != i_vendorAddress) revert ProductOrder__NotVendor();
        _;
    }

    constructor(address purchaserAddress, address vendorAddress, uint256 PONo, uint256 amountOfMoney, uint256 timeToAccept, uint256 acceptTimeStamp, uint256 timeToShip) {
        i_purchaserAddress = purchaserAddress;
        i_vendorAddress = vendorAddress;
        i_PONo = PONo;
        s_amountOfMoney = amountOfMoney;
        i_timeToAccept = timeToAccept;
        i_acceptTimeStamp = acceptTimeStamp;
        i_timeToShip = timeToShip;
        
        s_state = POState.SENT;
    }

    receive() external payable {}

    fallback() external payable {}

    function cancelOrder() public payable onlyPurchaser {
        require(s_state == POState.SENT);

        payable(i_purchaserAddress).transfer(s_amountOfMoney);
        s_amountOfMoney = 0;

        s_state = POState.CANCELLED;
    }

    function recievePurchaseOrder(bool orderAccepted, uint256 amountOfPOAccepted) public onlyVendor {
        require(s_state == POState.SENT);
        require(amountOfPOAccepted <= s_amountOfMoney);

        if (!orderAccepted) {
            s_state = POState.CANCELLED;
            payable(i_purchaserAddress).transfer(s_amountOfMoney);
            s_amountOfMoney = 0;
        }
        else {
            s_state = POState.ACCEPTED;
            s_shippingTimeStamp = block.timestamp;
            payable(i_purchaserAddress).transfer(s_amountOfMoney - amountOfPOAccepted);
            s_amountOfMoney = amountOfPOAccepted;
        }
    }

    function setShipmentValue(uint256 shipmentValue) public payable onlyPurchaser {
        require(s_state == POState.ACCEPTED);
        require(shipmentValue <= s_amountOfMoney);
        require(shipmentValue >= 0);

        if (shipmentValue == s_amountOfMoney) {
            s_state = POState.END;
            payable(i_vendorAddress).transfer(s_amountOfMoney);
            s_amountOfMoney = 0;
        }
        else {
            s_state == POState.DISPUTE;
            s_tokenWorthGot = int256(shipmentValue);
        }
    }

    function setPurchaserDispute(int256 tokenWorthGot) public onlyPurchaser {
        s_tokenWorthGot = tokenWorthGot;
    }

    function setVendorDispute(uint256 tokenWorthShipped) public onlyVendor {
        s_tokenWorthShipped = tokenWorthShipped;
    }

    function checkUpkeep(bytes memory) public override returns (bool upkeepNeeded, bytes memory) {
        // If s_state is SENT
        //     upkeepNeeded equals if (block.timestamp - i_acceptTimeStamp) is greater than i_timeToAccept.
        // If s_state is ACCEPTED
        //     upkeepNeeded both conditions (AND)
        //         (block.timestamp - s_shippingTimeStamp) is greater than i_timeToShip
        //         s_tokenWorthGot equals -1
        // If s_state is DISPUTE
        //     upkeepNeeded equals if s_tokenWorthGot and s_tokenWorthShipped are equal.
    }

    function performUpkeep(bytes calldata) external override {
        // Gets upkeepNeeded bool from checkUpkeep() function
        // Requires upkeepNeeded to be true.
        // If s_state is SENT or ACCEPTED
        //     s_state is set to CANCELLED
        //     Refunds s_amountOfMoney to purchaserAddress.
        //     Sets s_amountOfMoney to 0.
        // If s_state is DISPUTE
        //     s_state is set to DISPUTE_END
        //     Sends (s_amountOfMoney - s_tokenWorthShipped) to i_purchaserAddress
        //     Sets s_amountOfMoney to s_tokenWorthShipped.
        //     Sends s_tokenWorthShipped token to i_vendorAddress.
        //     Sets s_amountOfMoney to 0.
    }

    function getState() public view returns(POState) {
        return s_state;
    }

    function getPurchaserAddress() public view returns(address) {
        return i_purchaserAddress;
    }

    function getVendorAddress() public view returns(address) {
        return i_vendorAddress;
    }

    function getAmountOfMoney() public view returns(uint256) {
        return s_amountOfMoney;
    }

    function getPONo() public view returns(uint256) {
        return i_PONo;
    }

    function getTimeToAccept() public view returns(uint256) {
        return i_timeToAccept;
    }

    function getAcceptTimeStamp() public view returns(uint256) {
        return i_acceptTimeStamp;
    }

    function getTimeToShip() public view returns(uint256) {
        return i_timeToShip;
    }

    function getShippingTimeStamp() public view returns(uint256) {
        return s_shippingTimeStamp;
    }

    function getTokenWorthGot() public view returns(int256) {
        return s_tokenWorthGot;
    }

    function getTokenWorthShipped() public view returns(uint256) {
        return s_tokenWorthShipped;
    }
}

// SPDX-License-Identifier: MIT
/**
 * @notice This is a deprecated interface. Please use AutomationCompatibleInterface directly.
 */
pragma solidity ^0.8.0;
import {AutomationCompatibleInterface as KeeperCompatibleInterface} from "./AutomationCompatibleInterface.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}