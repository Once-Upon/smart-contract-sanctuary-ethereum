// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { ItemType } from "./lib/ConsiderationEnums.sol";
import {
    Order,
    OrderParameters,
    BasicOrderParameters,
    OfferItem,
    ConsiderationItem
} from "./lib/ConsiderationStructs.sol";
import { ConsiderationTypeHashes } from "./lib/ConsiderationTypeHashes.sol";
import {
    ConsiderationInterface
} from "./interfaces/ConsiderationInterface.sol";
import {
    ConduitControllerInterface
} from "./interfaces/ConduitControllerInterface.sol";
import { ZoneInterface } from "./interfaces/ZoneInterface.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {
    ErrorsAndWarnings,
    ErrorsAndWarningsLib
} from "./lib/ErrorsAndWarnings.sol";
import { SafeStaticCall } from "./lib/SafeStaticCall.sol";
import { Murky } from "./lib/Murky.sol";
import {
    RoyaltyEngineInterface
} from "./interfaces/RoyaltyEngineInterface.sol";
import {
    ValidationConfiguration,
    ValidationError,
    ValidationWarning
} from "./lib/SeaportValidatorTypes.sol";
import { SignatureVerification } from "./lib/SignatureVerification.sol";

/**
 * @title SeaportValidator
 * @notice SeaportValidator validates simple orders that adhere to a set of rules defined below:
 *    - The order is either a bid or an ask order (one NFT to buy or one NFT to sell).
 *    - The first consideration is the primary consideration.
 *    - The order pays up to two fees in the fungible token currency. First fee is protocol fee, second is royalty fee.
 *    - In private orders, the last consideration specifies a recipient for the offer item.
 *    - Offer items must be owned and properly approved by the offerer.
 *    - Consideration items must exist.
 */
contract SeaportValidator is ConsiderationTypeHashes, SignatureVerification {
    using ErrorsAndWarningsLib for ErrorsAndWarnings;
    using SafeStaticCall for address;

    ConsiderationInterface constant seaport =
        ConsiderationInterface(0x00000000006c3852cbEf3e08E8dF289169EdE581);
    ConduitControllerInterface constant conduitController =
        ConduitControllerInterface(0x00000000F9490004C11Cef243f5400493c00Ad63);
    RoyaltyEngineInterface constant royaltyEngine =
        RoyaltyEngineInterface(0x0385603ab55642cb4Dd5De3aE9e306809991804f);
    Murky immutable murky;

    constructor() {
        murky = new Murky(false);
    }

    /**
     * @notice Conduct a comprehensive validation of the given order.
     * @param order The order to validate.
     * @return errorsAndWarnings The errors and warnings found in the order.
     */
    function isValidOrder(Order calldata order)
        external
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        return
            isValidOrderWithConfiguration(
                order,
                ValidationConfiguration(address(0), 0, false)
            );
    }

    /**
     * @notice Same as `isValidOrder` but allows for more configuration related to fee validation.
     */
    function isValidOrderWithConfiguration(
        Order memory order,
        ValidationConfiguration memory validationConfiguration
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        errorsAndWarnings.concat(validateTime(order.parameters));
        errorsAndWarnings.concat(validateOfferItems(order.parameters));
        errorsAndWarnings.concat(validateConsiderationItems(order.parameters));
        errorsAndWarnings.concat(validateOrderStatus(order.parameters));
        errorsAndWarnings.concat(isValidZone(order.parameters));
        errorsAndWarnings.concat(
            validateStrictLogic(
                order.parameters,
                validationConfiguration.protocolFeeRecipient,
                validationConfiguration.protocolFeeBips,
                validationConfiguration.checkRoyaltyFee
            )
        );
        errorsAndWarnings.concat(validateSignature(order));
    }

    /**
     * @notice Checks if a conduit key is valid.
     * @param conduitKey The conduit key to check.
     * @return errorsAndWarnings The errors and warnings
     */
    function isValidConduit(bytes32 conduitKey)
        external
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        (, errorsAndWarnings) = getApprovalAddress(conduitKey);
    }

    function validateSignature(Order memory order)
        public
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        uint256 currentCounter = seaport.getCounter(order.parameters.offerer);
        bytes32 orderHash = _deriveOrderHash(order.parameters, currentCounter);

        (bool isValid, , , ) = seaport.getOrderStatus(orderHash);

        if (isValid) {
            return errorsAndWarnings;
        }

        bytes32 eip712Digest = _deriveEIP712Digest(orderHash);
        if (
            !_isValidSignature(
                order.parameters.offerer,
                eip712Digest,
                order.signature
            )
        ) {
            errorsAndWarnings.addError(ValidationError.InvalidSignature);
        }
    }

    /**
     * @notice Check the time validity of an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings The errors and warnings
     */
    function validateTime(OrderParameters memory orderParameters)
        public
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        if (orderParameters.endTime <= orderParameters.startTime) {
            errorsAndWarnings.addError(
                ValidationError.Time_EndTimeBeforeStartTime
            );
            return errorsAndWarnings;
        }

        if (orderParameters.endTime < block.timestamp) {
            errorsAndWarnings.addError(ValidationError.Time_Expired);
            return errorsAndWarnings;
        } else if (orderParameters.endTime > block.timestamp + (30 weeks)) {
            errorsAndWarnings.addWarning(
                ValidationWarning.Time_DistantExpiration
            );
        }

        if (orderParameters.startTime > block.timestamp) {
            errorsAndWarnings.addWarning(ValidationWarning.Time_NotActive);
        }

        if (
            orderParameters.endTime -
                (
                    orderParameters.startTime > block.timestamp
                        ? orderParameters.startTime
                        : block.timestamp
                ) <
            30 minutes
        ) {
            errorsAndWarnings.addWarning(ValidationWarning.Time_ShortOrder);
        }
    }

    /**
     * @notice Validate the status of an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateOrderStatus(OrderParameters memory orderParameters)
        public
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        uint256 currentOffererCounter = seaport.getCounter(
            orderParameters.offerer
        );
        bytes32 orderHash = _deriveOrderHash(
            orderParameters,
            currentOffererCounter
        );
        (, bool isCancelled, uint256 totalFilled, uint256 totalSize) = seaport
            .getOrderStatus(orderHash);
        // Order is cancelled
        if (isCancelled) {
            errorsAndWarnings.addError(ValidationError.Status_Cancelled);
        }

        if (totalSize > 0 && totalFilled == totalSize) {
            errorsAndWarnings.addError(ValidationError.Status_FullyFilled);
        }
    }

    /**
     * @notice Validate all offer items for an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateOfferItems(OrderParameters memory orderParameters)
        public
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        for (uint256 i = 0; i < orderParameters.offer.length; i++) {
            errorsAndWarnings.concat(validateOfferItem(orderParameters, i));
        }

        // You must have an offer item
        if (orderParameters.offer.length == 0) {
            errorsAndWarnings.addError(ValidationError.Offer_ZeroItems);
        }

        if (orderParameters.offer.length > 1) {
            errorsAndWarnings.addWarning(
                ValidationWarning.Offer_MoreThanOneItem
            );
        }
    }

    /**
     * @notice Validate all consideration items for an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateConsiderationItems(OrderParameters memory orderParameters)
        public
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        if (orderParameters.consideration.length == 0) {
            errorsAndWarnings.addWarning(
                ValidationWarning.Consideration_ZeroItems
            );
            return errorsAndWarnings;
        }

        for (uint256 i = 0; i < orderParameters.consideration.length; i++) {
            errorsAndWarnings.concat(
                validateConsiderationItem(orderParameters, i)
            );
        }
    }

    /**
     * @notice Strict validation operates under tight assumptions. It validates protocol
     *    fee, royalty fee, private sale consideration, and overall order format.
     * @dev Only checks first fee recipient provided by RoyaltyRegistry.
     *    Order of consideration items must be as follows:
     *    1. Primary consideration
     *    2. Protocol fee
     *    3. Royalty Fee
     *    4. Private sale consideration
     * @param orderParameters The parameters for the order to validate.
     * @param protocolFeeRecipient The protocol fee recipient. Set to null address for no protocol fee.
     * @param protocolFeeBips The protocol fee in BIPs.
     * @param checkRoyaltyFee Should check for royalty fee. If true, royalty fee must be present as
     *    according to royalty engine. If false, must not have royalty fee.
     * @return errorsAndWarnings The errors and warnings.
     */
    function validateStrictLogic(
        OrderParameters memory orderParameters,
        address protocolFeeRecipient,
        uint256 protocolFeeBips,
        bool checkRoyaltyFee
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        {
            bool canCheckFee = true;
            if (
                orderParameters.offer.length != 1 ||
                orderParameters.consideration.length == 0
            ) {
                // Not bid or ask, can't check fees
                canCheckFee = false;
            } else if (
                isPaymentToken(orderParameters.offer[0].itemType) &&
                isPaymentToken(orderParameters.consideration[0].itemType)
            ) {
                // Not bid or ask, can't check fees
                canCheckFee = false;
            } else if (
                !isPaymentToken(orderParameters.offer[0].itemType) &&
                !isPaymentToken(orderParameters.consideration[0].itemType)
            ) {
                // Not bid or ask, can't check fees
                canCheckFee = false;
            }
            if (!canCheckFee) {
                errorsAndWarnings.addError(ValidationError.InvalidOrderFormat);
                return errorsAndWarnings;
            }
        }

        (
            uint256 tertiaryConsiderationIndex,
            ErrorsAndWarnings memory errorsAndWarningsLocal
        ) = validateSecondaryConsiderationItems(
                orderParameters,
                protocolFeeRecipient,
                protocolFeeBips,
                checkRoyaltyFee
            );

        errorsAndWarnings.concat(errorsAndWarningsLocal);

        if (tertiaryConsiderationIndex != 0) {
            errorsAndWarnings.concat(
                validateTertiaryConsiderationItems(
                    orderParameters,
                    tertiaryConsiderationIndex
                )
            );
        }
    }

    function validateSecondaryConsiderationItems(
        OrderParameters memory orderParameters,
        address protocolFeeRecipient,
        uint256 protocolFeeBips,
        bool checkRoyaltyFee
    )
        internal
        view
        returns (
            uint256 tertiaryConsiderationIndex,
            ErrorsAndWarnings memory errorsAndWarnings
        )
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        // Check protocol fee
        address assetAddress;
        uint256 assetIdentifier;
        uint256 transactionAmountStart;
        uint256 transactionAmountEnd;

        ConsiderationItem memory royaltyFeeConsideration;

        if (isPaymentToken(orderParameters.offer[0].itemType)) {
            // Offer is a bid
            royaltyFeeConsideration.itemType = orderParameters
                .offer[0]
                .itemType;
            royaltyFeeConsideration.token = orderParameters.offer[0].token;
            transactionAmountStart = orderParameters.offer[0].startAmount;
            transactionAmountEnd = orderParameters.offer[0].endAmount;

            assetAddress = orderParameters.consideration[0].token;
            assetIdentifier = orderParameters
                .consideration[0]
                .identifierOrCriteria;
        } else {
            // Assume order must be an ask
            royaltyFeeConsideration.itemType = orderParameters
                .consideration[0]
                .itemType;
            royaltyFeeConsideration.token = orderParameters
                .consideration[0]
                .token;
            transactionAmountStart = orderParameters
                .consideration[0]
                .startAmount;
            transactionAmountEnd = orderParameters.consideration[0].endAmount;

            assetAddress = orderParameters.offer[0].token;
            assetIdentifier = orderParameters.offer[0].identifierOrCriteria;
        }

        if (protocolFeeRecipient != address(0)) {
            if (orderParameters.consideration.length < 2) {
                errorsAndWarnings.addError(ValidationError.ProtocolFee_Missing);
                return (0, errorsAndWarnings);
            }

            ConsiderationItem memory protocolFeeItem = orderParameters
                .consideration[1];

            if (protocolFeeItem.itemType != royaltyFeeConsideration.itemType) {
                errorsAndWarnings.addError(
                    ValidationError.ProtocolFee_ItemType
                );
                return (0, errorsAndWarnings);
            }

            if (protocolFeeItem.token != royaltyFeeConsideration.token) {
                errorsAndWarnings.addError(ValidationError.ProtocolFee_Token);
            }
            if (
                protocolFeeItem.startAmount <
                (transactionAmountStart * protocolFeeBips) / 10000
            ) {
                errorsAndWarnings.addError(
                    ValidationError.ProtocolFee_StartAmount
                );
            }
            if (
                protocolFeeItem.endAmount <
                (transactionAmountEnd * protocolFeeBips) / 10000
            ) {
                errorsAndWarnings.addError(
                    ValidationError.ProtocolFee_EndAmount
                );
            }
            if (protocolFeeItem.recipient != protocolFeeRecipient) {
                errorsAndWarnings.addError(
                    ValidationError.ProtocolFee_Recipient
                );
            }
        }

        // Check royalty fee
        {
            (
                address payable[] memory royaltyRecipients,
                uint256[] memory royaltyAmountsStart
            ) = royaltyEngine.getRoyaltyView(
                    assetAddress,
                    assetIdentifier,
                    transactionAmountStart
                );
            if (royaltyRecipients.length != 0) {
                royaltyFeeConsideration.recipient = royaltyRecipients[0];
                royaltyFeeConsideration.startAmount = royaltyAmountsStart[0];

                (, uint256[] memory royaltyAmountsEnd) = royaltyEngine
                    .getRoyaltyView(
                        assetAddress,
                        assetIdentifier,
                        transactionAmountEnd
                    );
                royaltyFeeConsideration.endAmount = royaltyAmountsEnd[0];
            }
        }

        bool royaltyFeePresent = false;

        if (
            royaltyFeeConsideration.recipient != address(0) && checkRoyaltyFee
        ) {
            uint16 royaltyConsiderationIndex = protocolFeeBips != 0 ? 2 : 1; // 2 if protocol fee, ow 1

            // Check that royalty consideration item exists
            if (
                orderParameters.consideration.length - 1 <
                royaltyConsiderationIndex
            ) {
                errorsAndWarnings.addError(ValidationError.RoyaltyFee_Missing);
                return (0, errorsAndWarnings);
            }

            ConsiderationItem memory royaltyFeeItem = orderParameters
                .consideration[royaltyConsiderationIndex];
            royaltyFeePresent = true;

            if (royaltyFeeItem.itemType != royaltyFeeConsideration.itemType) {
                errorsAndWarnings.addError(ValidationError.RoyaltyFee_ItemType);
                return (0, errorsAndWarnings);
            }
            if (royaltyFeeItem.token != royaltyFeeConsideration.token) {
                errorsAndWarnings.addError(ValidationError.RoyaltyFee_Token);
            }
            if (
                royaltyFeeItem.startAmount < royaltyFeeConsideration.startAmount
            ) {
                errorsAndWarnings.addError(
                    ValidationError.RoyaltyFee_StartAmount
                );
            }
            if (royaltyFeeItem.endAmount < royaltyFeeConsideration.endAmount) {
                errorsAndWarnings.addError(
                    ValidationError.RoyaltyFee_EndAmount
                );
            }
            if (royaltyFeeItem.recipient != royaltyFeeConsideration.recipient) {
                errorsAndWarnings.addError(
                    ValidationError.RoyaltyFee_Recipient
                );
            }
        }

        // Check additional consideration items
        tertiaryConsiderationIndex =
            1 +
            (protocolFeeBips != 0 ? 1 : 0) +
            (royaltyFeePresent ? 1 : 0);
    }

    function validateTertiaryConsiderationItems(
        OrderParameters memory orderParameters,
        uint256 considerationItemIndex
    ) internal pure returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        if (orderParameters.consideration.length <= considerationItemIndex) {
            // Not a private sale
            return errorsAndWarnings;
        }

        ConsiderationItem memory privateSaleConsideration = orderParameters
            .consideration[considerationItemIndex];

        if (isPaymentToken(orderParameters.offer[0].itemType)) {
            errorsAndWarnings.addError(
                ValidationError.Consideration_ExtraItems
            );
            return errorsAndWarnings;
        }

        if (privateSaleConsideration.recipient == orderParameters.offerer) {
            errorsAndWarnings.addError(
                ValidationError.Consideration_PrivateSaleToSelf
            );
            return errorsAndWarnings;
        }

        if (
            privateSaleConsideration.itemType !=
            orderParameters.offer[0].itemType ||
            privateSaleConsideration.token != orderParameters.offer[0].token ||
            orderParameters.offer[0].startAmount !=
            privateSaleConsideration.startAmount ||
            orderParameters.offer[0].endAmount !=
            privateSaleConsideration.endAmount ||
            orderParameters.offer[0].identifierOrCriteria !=
            privateSaleConsideration.identifierOrCriteria
        ) {
            // Invalid private sale, say extra consideration item
            errorsAndWarnings.addError(
                ValidationError.Consideration_ExtraItems
            );
            return errorsAndWarnings;
        }

        if (orderParameters.consideration.length - 1 > considerationItemIndex) {
            // Extra consideration items
            errorsAndWarnings.addError(
                ValidationError.Consideration_ExtraItems
            );
            return errorsAndWarnings;
        }
    }

    /**
     * @notice Validate a consideration item
     * @param orderParameters The parameters for the order to validate
     * @param considerationItemIndex The index of the consideration item to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateConsiderationItem(
        OrderParameters memory orderParameters,
        uint256 considerationItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        errorsAndWarnings.concat(
            validateConsiderationItemParameters(
                orderParameters,
                considerationItemIndex
            )
        );
    }

    /**
     * @notice Validates the parameters of a consideration item including contract validation
     * @param orderParameters The parameters for the order to validate
     * @param considerationItemIndex The index of the consideration item to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateConsiderationItemParameters(
        OrderParameters memory orderParameters,
        uint256 considerationItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        ConsiderationItem memory considerationItem = orderParameters
            .consideration[considerationItemIndex];

        if (
            considerationItem.startAmount == 0 &&
            considerationItem.endAmount == 0
        ) {
            errorsAndWarnings.addError(
                ValidationError.Consideration_AmountZero
            );
        }

        if (considerationItem.recipient == address(0)) {
            errorsAndWarnings.addError(
                ValidationError.Consideration_NullRecipient
            );
        }

        if (considerationItem.itemType == ItemType.ERC721) {
            if (
                considerationItem.startAmount != 1 ||
                considerationItem.endAmount != 1
            ) {
                errorsAndWarnings.addError(ValidationError.ERC721_AmountNotOne);
            }

            if (
                !checkInterface(
                    considerationItem.token,
                    type(IERC721).interfaceId
                )
            ) {
                errorsAndWarnings.addError(ValidationError.ERC721_InvalidToken);
                return errorsAndWarnings;
            }

            // Ensure that token exists. Will return false if owned by null address.
            if (
                !considerationItem.token.safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC721.ownerOf.selector,
                        considerationItem.identifierOrCriteria
                    ),
                    1
                )
            ) {
                errorsAndWarnings.addError(
                    ValidationError.ERC721_IdentifierDNE
                );
            }
        } else if (
            considerationItem.itemType == ItemType.ERC721_WITH_CRITERIA
        ) {
            if (
                !checkInterface(
                    considerationItem.token,
                    type(IERC721).interfaceId
                )
            ) {
                errorsAndWarnings.addError(ValidationError.ERC721_InvalidToken);
            }
        } else if (
            considerationItem.itemType == ItemType.ERC1155 ||
            considerationItem.itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {
            if (
                !checkInterface(
                    considerationItem.token,
                    type(IERC1155).interfaceId
                )
            ) {
                errorsAndWarnings.addError(
                    ValidationError.ERC1155_InvalidToken
                );
            }
        } else if (considerationItem.itemType == ItemType.ERC20) {
            if (considerationItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    ValidationError.ERC20_IdentifierNonZero
                );
            }

            if (
                !considerationItem.token.safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC20.allowance.selector,
                        address(seaport),
                        address(seaport)
                    ),
                    0
                )
            ) {
                // Not an ERC20 token
                errorsAndWarnings.addError(ValidationError.ERC20_InvalidToken);
            }
        } else if (considerationItem.itemType == ItemType.NATIVE) {
            if (considerationItem.token != address(0)) {
                errorsAndWarnings.addError(ValidationError.Native_TokenAddress);
            }
            if (considerationItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    ValidationError.Native_IdentifierNonZero
                );
            }
        } else {
            errorsAndWarnings.addError(ValidationError.InvalidItemType);
        }
    }

    /**
     * @notice Validates an offer item
     * @param orderParameters The parameters for the order to validate
     * @param offerItemIndex The index of the offerItem in offer array to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function validateOfferItem(
        OrderParameters memory orderParameters,
        uint256 offerItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = validateOfferItemParameters(
            orderParameters,
            offerItemIndex
        );
        if (errorsAndWarnings.hasErrors()) {
            // Only validate approvals and balances if parameters are valid
            return errorsAndWarnings;
        }

        errorsAndWarnings.concat(
            validateOfferItemApprovalAndBalance(orderParameters, offerItemIndex)
        );
    }

    /**
     * @notice Validates the OfferItem parameters. This includes token contract validation
     * @dev OfferItems with criteria are currently not allowed
     * @param orderParameters The parameters for the order to validate
     * @param offerItemIndex The index of the offerItem in offer array to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function validateOfferItemParameters(
        OrderParameters memory orderParameters,
        uint256 offerItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        OfferItem memory offerItem = orderParameters.offer[offerItemIndex];

        if (offerItem.startAmount == 0 && offerItem.endAmount == 0) {
            errorsAndWarnings.addError(ValidationError.Offer_AmountZero);
        }

        if (offerItem.itemType == ItemType.ERC721) {
            if (offerItem.startAmount != 1 || offerItem.endAmount != 1) {
                errorsAndWarnings.addError(ValidationError.ERC721_AmountNotOne);
            }

            if (!checkInterface(offerItem.token, type(IERC721).interfaceId)) {
                errorsAndWarnings.addError(ValidationError.ERC721_InvalidToken);
            }
        } else if (offerItem.itemType == ItemType.ERC1155) {
            if (!checkInterface(offerItem.token, type(IERC1155).interfaceId)) {
                errorsAndWarnings.addError(
                    ValidationError.ERC1155_InvalidToken
                );
            }
        } else if (offerItem.itemType == ItemType.ERC20) {
            if (offerItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    ValidationError.ERC20_IdentifierNonZero
                );
            }

            // validate contract
            (, bytes memory res) = offerItem.token.staticcall(
                abi.encodeWithSelector(
                    IERC20.allowance.selector,
                    address(seaport),
                    address(seaport)
                )
            );
            if (res.length == 0) {
                // Not an ERC20 token
                errorsAndWarnings.addError(ValidationError.ERC20_InvalidToken);
            }
        } else if (offerItem.itemType == ItemType.NATIVE) {
            if (offerItem.token != address(0)) {
                errorsAndWarnings.addError(ValidationError.Native_TokenAddress);
            }

            if (offerItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    ValidationError.Native_IdentifierNonZero
                );
            }
        } else {
            errorsAndWarnings.addError(ValidationError.InvalidItemType);
        }
    }

    /**
     * @notice Validates the OfferItem approvals and balances
     * @param orderParameters The parameters for the order to validate
     * @param offerItemIndex The index of the offerItem in offer array to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function validateOfferItemApprovalAndBalance(
        OrderParameters memory orderParameters,
        uint256 offerItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        // Note: If multiple items are of the same token, token amounts are not summed for validation

        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        (
            address approvalAddress,
            ErrorsAndWarnings memory ew
        ) = getApprovalAddress(orderParameters.conduitKey);

        errorsAndWarnings.concat(ew);

        OfferItem memory offerItem = orderParameters.offer[offerItemIndex];

        if (offerItem.itemType == ItemType.ERC721) {
            // TODO: Deal with ERC721 with criteria
            IERC721 token = IERC721(offerItem.token);

            // Check owner
            if (
                !address(token).safeStaticCallAddress(
                    abi.encodeWithSelector(
                        IERC721.ownerOf.selector,
                        offerItem.identifierOrCriteria
                    ),
                    orderParameters.offerer
                )
            ) {
                errorsAndWarnings.addError(ValidationError.ERC721_NotOwner);
            }

            // Check approval
            if (
                !address(token).safeStaticCallAddress(
                    abi.encodeWithSelector(
                        IERC721.getApproved.selector,
                        offerItem.identifierOrCriteria
                    ),
                    approvalAddress
                )
            ) {
                if (
                    !address(token).safeStaticCallBool(
                        abi.encodeWithSelector(
                            IERC721.isApprovedForAll.selector,
                            orderParameters.offerer,
                            approvalAddress
                        ),
                        true
                    )
                ) {
                    errorsAndWarnings.addError(
                        ValidationError.ERC721_NotApproved
                    );
                }
            }
        } else if (offerItem.itemType == ItemType.ERC1155) {
            IERC1155 token = IERC1155(offerItem.token);

            if (
                !address(token).safeStaticCallBool(
                    abi.encodeWithSelector(
                        IERC721.isApprovedForAll.selector,
                        orderParameters.offerer,
                        approvalAddress
                    ),
                    true
                )
            ) {
                errorsAndWarnings.addError(ValidationError.ERC1155_NotApproved);
            }

            uint256 minBalance = offerItem.startAmount < offerItem.endAmount
                ? offerItem.startAmount
                : offerItem.endAmount;

            if (
                !address(token).safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC1155.balanceOf.selector,
                        orderParameters.offerer,
                        offerItem.identifierOrCriteria
                    ),
                    minBalance
                )
            ) {
                errorsAndWarnings.addError(
                    ValidationError.ERC1155_InsufficientBalance
                );
            }
        } else if (offerItem.itemType == ItemType.ERC20) {
            IERC20 token = IERC20(offerItem.token);

            uint256 minBalanceAndAllowance = offerItem.startAmount <
                offerItem.endAmount
                ? offerItem.startAmount
                : offerItem.endAmount;

            if (
                !address(token).safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC20.allowance.selector,
                        orderParameters.offerer,
                        approvalAddress
                    ),
                    minBalanceAndAllowance
                )
            ) {
                errorsAndWarnings.addError(
                    ValidationError.ERC20_InsufficientAllowance
                );
            }

            if (
                !address(token).safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC20.balanceOf.selector,
                        orderParameters.offerer
                    ),
                    minBalanceAndAllowance
                )
            ) {
                errorsAndWarnings.addError(
                    ValidationError.ERC20_InsufficientBalance
                );
            }
        } else if (offerItem.itemType == ItemType.NATIVE) {
            uint256 minBalance = offerItem.startAmount < offerItem.endAmount
                ? offerItem.startAmount
                : offerItem.endAmount;

            if (orderParameters.offerer.balance < minBalance) {
                errorsAndWarnings.addError(
                    ValidationError.Native_InsufficientBalance
                );
            }

            errorsAndWarnings.addWarning(ValidationWarning.Offer_NativeItem);
        } else {
            errorsAndWarnings.addError(ValidationError.InvalidItemType);
        }
    }

    // TODO: Need to add support for order with extra data
    /**
     * @notice Validates the zone call for an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function isValidZone(OrderParameters memory orderParameters)
        public
        view
        returns (ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        if (address(orderParameters.zone).code.length == 0) {
            // Address is EOA. Valid order
            return errorsAndWarnings;
        }

        uint256 currentOffererCounter = seaport.getCounter(
            orderParameters.offerer
        );

        if (
            !orderParameters.zone.safeStaticCallBytes4(
                abi.encodeWithSelector(
                    ZoneInterface.isValidOrder.selector,
                    _deriveOrderHash(orderParameters, currentOffererCounter),
                    msg.sender, /* who should be caller? */
                    orderParameters.offerer,
                    orderParameters.zoneHash
                ),
                ZoneInterface.isValidOrder.selector
            )
        ) {
            errorsAndWarnings.addError(ValidationError.Zone_RejectedOrder);
        }
    }

    /**
     * @notice Gets the approval address for the given conduit key
     * @param conduitKey Conduit key to get approval address for
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function getApprovalAddress(bytes32 conduitKey)
        public
        view
        returns (address, ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));
        if (conduitKey == 0) return (address(seaport), errorsAndWarnings);
        (address conduitAddress, bool exists) = conduitController.getConduit(
            conduitKey
        );
        if (!exists) {
            errorsAndWarnings.addError(ValidationError.Conduit_KeyInvalid);
            conduitAddress = address(0); // Don't return invalid conduit
        }
        return (conduitAddress, errorsAndWarnings);
    }

    /**
     * @notice Safely check that a contract implements an interface
     * @param token The token address to check
     * @param interfaceHash The interface hash to check
     */
    function checkInterface(address token, bytes4 interfaceHash)
        public
        view
        returns (bool)
    {
        return
            token.safeStaticCallBool(
                abi.encodeWithSelector(
                    IERC165.supportsInterface.selector,
                    interfaceHash
                ),
                true
            );
    }

    function isPaymentToken(ItemType itemType) public pure returns (bool) {
        return itemType == ItemType.NATIVE || itemType == ItemType.ERC20;
    }

    /*//////////////////////////////////////////////////////////////
                        Merkle Helpers
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a merkle proof for the the targetIndex contained in includedTokens.
     * @dev `targetIndex` is referring to the index of an element in `includedTokens`.
     *    `includedTokens` must be sorting in ascending order according to the keccak256 hash of the value.
     * @return merkleProof The merkle proof
     * @return errorsAndWarnings Errors and warnings from the operation
     */
    function getMerkleProof(
        uint256[] memory includedTokens,
        uint256 targetIndex
    )
        public
        view
        returns (
            bytes32[] memory merkleProof,
            ErrorsAndWarnings memory errorsAndWarnings
        )
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        (bool success, bytes memory res) = address(murky).staticcall(
            abi.encodeWithSelector(
                murky.getProof.selector,
                includedTokens,
                targetIndex
            )
        );
        if (!success) {
            errorsAndWarnings.addError(ValidationError.MerkleError);
            return (new bytes32[](0), errorsAndWarnings);
        }

        return (abi.decode(res, (bytes32[])), errorsAndWarnings);
    }

    /**
     * @notice Creates a merkle root for includedTokens.
     * @dev `includedTokens` must be sorting in strictly ascending order according to the keccak256 hash of the value.
     * @return merkleRoot The merkle root
     * @return errorsAndWarnings Errors and warnings from the operation
     */
    function getMerkleRoot(uint256[] memory includedTokens)
        public
        view
        returns (bytes32 merkleRoot, ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint8[](0), new uint8[](0));

        (bool success, bytes memory res) = address(murky).staticcall(
            abi.encodeWithSelector(murky.getRoot.selector, includedTokens)
        );
        if (!success) {
            errorsAndWarnings.addError(ValidationError.MerkleError);
            return (0, errorsAndWarnings);
        }

        return (abi.decode(res, (bytes32)), errorsAndWarnings);
    }

    /**
     * @notice Sorts an array of token ids by the keccak256 hash of the id. Required ordering of ids
     *    for other merkle operations.
     * @param includedTokens An array of included token ids.
     * @return sortedTokens The sorted `includedTokens` array.
     */
    function sortMerkleTokens(uint256[] memory includedTokens)
        public
        view
        returns (uint256[] memory sortedTokens)
    {
        return murky.sortUint256ByHash(includedTokens);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// prettier-ignore
enum OrderType {
    // 0: no partial fills, anyone can execute
    FULL_OPEN,

    // 1: partial fills supported, anyone can execute
    PARTIAL_OPEN,

    // 2: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED,

    // 3: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED
}

// prettier-ignore
enum BasicOrderType {
    // 0: no partial fills, anyone can execute
    ETH_TO_ERC721_FULL_OPEN,

    // 1: partial fills supported, anyone can execute
    ETH_TO_ERC721_PARTIAL_OPEN,

    // 2: no partial fills, only offerer or zone can execute
    ETH_TO_ERC721_FULL_RESTRICTED,

    // 3: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC721_PARTIAL_RESTRICTED,

    // 4: no partial fills, anyone can execute
    ETH_TO_ERC1155_FULL_OPEN,

    // 5: partial fills supported, anyone can execute
    ETH_TO_ERC1155_PARTIAL_OPEN,

    // 6: no partial fills, only offerer or zone can execute
    ETH_TO_ERC1155_FULL_RESTRICTED,

    // 7: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC1155_PARTIAL_RESTRICTED,

    // 8: no partial fills, anyone can execute
    ERC20_TO_ERC721_FULL_OPEN,

    // 9: partial fills supported, anyone can execute
    ERC20_TO_ERC721_PARTIAL_OPEN,

    // 10: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC721_FULL_RESTRICTED,

    // 11: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC721_PARTIAL_RESTRICTED,

    // 12: no partial fills, anyone can execute
    ERC20_TO_ERC1155_FULL_OPEN,

    // 13: partial fills supported, anyone can execute
    ERC20_TO_ERC1155_PARTIAL_OPEN,

    // 14: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC1155_FULL_RESTRICTED,

    // 15: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC1155_PARTIAL_RESTRICTED,

    // 16: no partial fills, anyone can execute
    ERC721_TO_ERC20_FULL_OPEN,

    // 17: partial fills supported, anyone can execute
    ERC721_TO_ERC20_PARTIAL_OPEN,

    // 18: no partial fills, only offerer or zone can execute
    ERC721_TO_ERC20_FULL_RESTRICTED,

    // 19: partial fills supported, only offerer or zone can execute
    ERC721_TO_ERC20_PARTIAL_RESTRICTED,

    // 20: no partial fills, anyone can execute
    ERC1155_TO_ERC20_FULL_OPEN,

    // 21: partial fills supported, anyone can execute
    ERC1155_TO_ERC20_PARTIAL_OPEN,

    // 22: no partial fills, only offerer or zone can execute
    ERC1155_TO_ERC20_FULL_RESTRICTED,

    // 23: partial fills supported, only offerer or zone can execute
    ERC1155_TO_ERC20_PARTIAL_RESTRICTED
}

// prettier-ignore
enum BasicOrderRouteType {
    // 0: provide Ether (or other native token) to receive offered ERC721 item.
    ETH_TO_ERC721,

    // 1: provide Ether (or other native token) to receive offered ERC1155 item.
    ETH_TO_ERC1155,

    // 2: provide ERC20 item to receive offered ERC721 item.
    ERC20_TO_ERC721,

    // 3: provide ERC20 item to receive offered ERC1155 item.
    ERC20_TO_ERC1155,

    // 4: provide ERC721 item to receive offered ERC20 item.
    ERC721_TO_ERC20,

    // 5: provide ERC1155 item to receive offered ERC20 item.
    ERC1155_TO_ERC20
}

// prettier-ignore
enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,

    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,

    // 2: ERC721 items
    ERC721,

    // 3: ERC1155 items
    ERC1155,

    // 4: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,

    // 5: ERC1155 items where a number of ids are supported
    ERC1155_WITH_CRITERIA
}

// prettier-ignore
enum Side {
    // 0: Items that can be spent
    OFFER,
    
    // 1: Items that must be received
    CONSIDERATION
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// prettier-ignore
import {
    OrderType,
    BasicOrderType,
    ItemType,
    Side,
    BasicOrderRouteType
} from "./ConsiderationEnums.sol";

/**
 * @dev An order contains eleven components: an offerer, a zone (or account that
 *      can cancel the order or restrict who can fulfill the order depending on
 *      the type), the order type (specifying partial fill support as well as
 *      restricted order status), the start and end time, a hash that will be
 *      provided to the zone when validating restricted orders, a salt, a key
 *      corresponding to a given conduit, a counter, and an arbitrary number of
 *      offer items that can be spent along with consideration items that must
 *      be received by their respective recipient.
 */
struct OrderComponents {
    address offerer;
    address zone;
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 counter;
}

/**
 * @dev An offer item has five components: an item type (ETH or other native
 *      tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
 *      ERC1155), a token address, a dual-purpose "identifierOrCriteria"
 *      component that will either represent a tokenId or a merkle root
 *      depending on the item type, and a start and end amount that support
 *      increasing or decreasing amounts over the duration of the respective
 *      order.
 */
struct OfferItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}

/**
 * @dev A consideration item has the same five components as an offer item and
 *      an additional sixth component designating the required recipient of the
 *      item.
 */
struct ConsiderationItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable recipient;
}

/**
 * @dev A spent item is translated from a utilized offer item and has four
 *      components: an item type (ETH or other native tokens, ERC20, ERC721, and
 *      ERC1155), a token address, a tokenId, and an amount.
 */
struct SpentItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
}

/**
 * @dev A received item is translated from a utilized consideration item and has
 *      the same four components as a spent item, as well as an additional fifth
 *      component designating the required recipient of the item.
 */
struct ReceivedItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
    address payable recipient;
}

/**
 * @dev For basic orders involving ETH / native / ERC20 <=> ERC721 / ERC1155
 *      matching, a group of six functions may be called that only requires a
 *      subset of the usual order arguments. Note the use of a "basicOrderType"
 *      enum; this represents both the usual order type as well as the "route"
 *      of the basic order (a simple derivation function for the basic order
 *      type is `basicOrderType = orderType + (4 * basicOrderRoute)`.)
 */
struct BasicOrderParameters {
    // calldata offset
    address considerationToken; // 0x24
    uint256 considerationIdentifier; // 0x44
    uint256 considerationAmount; // 0x64
    address payable offerer; // 0x84
    address zone; // 0xa4
    address offerToken; // 0xc4
    uint256 offerIdentifier; // 0xe4
    uint256 offerAmount; // 0x104
    BasicOrderType basicOrderType; // 0x124
    uint256 startTime; // 0x144
    uint256 endTime; // 0x164
    bytes32 zoneHash; // 0x184
    uint256 salt; // 0x1a4
    bytes32 offererConduitKey; // 0x1c4
    bytes32 fulfillerConduitKey; // 0x1e4
    uint256 totalOriginalAdditionalRecipients; // 0x204
    AdditionalRecipient[] additionalRecipients; // 0x224
    bytes signature; // 0x244
    // Total length, excluding dynamic array data: 0x264 (580)
}

/**
 * @dev Basic orders can supply any number of additional recipients, with the
 *      implied assumption that they are supplied from the offered ETH (or other
 *      native token) or ERC20 token for the order.
 */
struct AdditionalRecipient {
    uint256 amount;
    address payable recipient;
}

/**
 * @dev The full set of order components, with the exception of the counter,
 *      must be supplied when fulfilling more sophisticated orders or groups of
 *      orders. The total number of original consideration items must also be
 *      supplied, as the caller may specify additional consideration items.
 */
struct OrderParameters {
    address offerer; // 0x00
    address zone; // 0x20
    OfferItem[] offer; // 0x40
    ConsiderationItem[] consideration; // 0x60
    OrderType orderType; // 0x80
    uint256 startTime; // 0xa0
    uint256 endTime; // 0xc0
    bytes32 zoneHash; // 0xe0
    uint256 salt; // 0x100
    bytes32 conduitKey; // 0x120
    uint256 totalOriginalConsiderationItems; // 0x140
    // offer.length                          // 0x160
}

/**
 * @dev Orders require a signature in addition to the other order parameters.
 */
struct Order {
    OrderParameters parameters;
    bytes signature;
}

/**
 * @dev Advanced orders include a numerator (i.e. a fraction to attempt to fill)
 *      and a denominator (the total size of the order) in addition to the
 *      signature and other order parameters. It also supports an optional field
 *      for supplying extra data; this data will be included in a staticcall to
 *      `isValidOrderIncludingExtraData` on the zone for the order if the order
 *      type is restricted and the offerer or zone are not the caller.
 */
struct AdvancedOrder {
    OrderParameters parameters;
    uint120 numerator;
    uint120 denominator;
    bytes signature;
    bytes extraData;
}

/**
 * @dev Orders can be validated (either explicitly via `validate`, or as a
 *      consequence of a full or partial fill), specifically cancelled (they can
 *      also be cancelled in bulk via incrementing a per-zone counter), and
 *      partially or fully filled (with the fraction filled represented by a
 *      numerator and denominator).
 */
struct OrderStatus {
    bool isValidated;
    bool isCancelled;
    uint120 numerator;
    uint120 denominator;
}

/**
 * @dev A criteria resolver specifies an order, side (offer vs. consideration),
 *      and item index. It then provides a chosen identifier (i.e. tokenId)
 *      alongside a merkle proof demonstrating the identifier meets the required
 *      criteria.
 */
struct CriteriaResolver {
    uint256 orderIndex;
    Side side;
    uint256 index;
    uint256 identifier;
    bytes32[] criteriaProof;
}

/**
 * @dev A fulfillment is applied to a group of orders. It decrements a series of
 *      offer and consideration items, then generates a single execution
 *      element. A given fulfillment can be applied to as many offer and
 *      consideration items as desired, but must contain at least one offer and
 *      at least one consideration that match. The fulfillment must also remain
 *      consistent on all key parameters across all offer items (same offerer,
 *      token, type, tokenId, and conduit preference) as well as across all
 *      consideration items (token, type, tokenId, and recipient).
 */
struct Fulfillment {
    FulfillmentComponent[] offerComponents;
    FulfillmentComponent[] considerationComponents;
}

/**
 * @dev Each fulfillment component contains one index referencing a specific
 *      order and another referencing a specific offer or consideration item.
 */
struct FulfillmentComponent {
    uint256 orderIndex;
    uint256 itemIndex;
}

/**
 * @dev An execution is triggered once all consideration items have been zeroed
 *      out. It sends the item in question from the offerer to the item's
 *      recipient, optionally sourcing approvals from either this contract
 *      directly or from the offerer's chosen conduit if one is specified. An
 *      execution is not provided as an argument, but rather is derived via
 *      orders, criteria resolvers, and fulfillments (where the total number of
 *      executions will be less than or equal to the total number of indicated
 *      fulfillments) and returned as part of `matchOrders`.
 */
struct Execution {
    ReceivedItem item;
    address offerer;
    bytes32 conduitKey;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ConsiderationStructs.sol";

uint256 constant EIP712_Order_size = 0x180;
uint256 constant EIP712_OfferItem_size = 0xc0;
uint256 constant EIP712_ConsiderationItem_size = 0xe0;
uint256 constant EIP712_DomainSeparator_offset = 0x02;
uint256 constant EIP712_OrderHash_offset = 0x22;
uint256 constant EIP712_DigestPayload_size = 0x42;
uint256 constant EIP_712_PREFIX = (
    0x1901000000000000000000000000000000000000000000000000000000000000
);

contract ConsiderationTypeHashes {
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    bytes32 internal immutable _OFFER_ITEM_TYPEHASH;
    bytes32 internal immutable _CONSIDERATION_ITEM_TYPEHASH;
    bytes32 internal immutable _ORDER_TYPEHASH;
    bytes32 internal immutable _DOMAIN_SEPARATOR;
    address internal constant seaportAddress =
        address(0x00000000006c3852cbEf3e08E8dF289169EdE581);

    constructor() {
        // Derive hash of the name of the contract.
        _NAME_HASH = keccak256(bytes("Seaport"));

        // Derive hash of the version string of the contract.
        _VERSION_HASH = keccak256(bytes("1.1"));

        bytes memory offerItemTypeString = abi.encodePacked(
            "OfferItem(",
            "uint8 itemType,",
            "address token,",
            "uint256 identifierOrCriteria,",
            "uint256 startAmount,",
            "uint256 endAmount",
            ")"
        );

        // Construct the ConsiderationItem type string.
        // prettier-ignore
        bytes memory considerationItemTypeString = abi.encodePacked(
            "ConsiderationItem(",
                "uint8 itemType,",
                "address token,",
                "uint256 identifierOrCriteria,",
                "uint256 startAmount,",
                "uint256 endAmount,",
                "address recipient",
            ")"
        );

        // Construct the OrderComponents type string, not including the above.
        // prettier-ignore
        bytes memory orderComponentsPartialTypeString = abi.encodePacked(
            "OrderComponents(",
                "address offerer,",
                "address zone,",
                "OfferItem[] offer,",
                "ConsiderationItem[] consideration,",
                "uint8 orderType,",
                "uint256 startTime,",
                "uint256 endTime,",
                "bytes32 zoneHash,",
                "uint256 salt,",
                "bytes32 conduitKey,",
                "uint256 counter",
            ")"
        );
        // Derive the OfferItem type hash using the corresponding type string.
        bytes32 offerItemTypehash = keccak256(offerItemTypeString);

        // Derive ConsiderationItem type hash using corresponding type string.
        bytes32 considerationItemTypehash = keccak256(
            considerationItemTypeString
        );

        // Construct the primary EIP-712 domain type string.
        // prettier-ignore
        _EIP_712_DOMAIN_TYPEHASH = keccak256(
            abi.encodePacked(
                "EIP712Domain(",
                    "string name,",
                    "string version,",
                    "uint256 chainId,",
                    "address verifyingContract",
                ")"
            )
        );

        _OFFER_ITEM_TYPEHASH = offerItemTypehash;
        _CONSIDERATION_ITEM_TYPEHASH = considerationItemTypehash;

        // Derive OrderItem type hash via combination of relevant type strings.
        _ORDER_TYPEHASH = keccak256(
            abi.encodePacked(
                orderComponentsPartialTypeString,
                considerationItemTypeString,
                offerItemTypeString
            )
        );

        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                seaportAddress
            )
        );
    }

    /**
     * @dev Internal pure function to efficiently derive an digest to sign for
     *      an order in accordance with EIP-712.
     *
     * @param orderHash       The order hash.
     *
     * @return value The hash.
     */
    function _deriveEIP712Digest(bytes32 orderHash)
        internal
        view
        returns (bytes32 value)
    {
        bytes32 domainSeparator = _DOMAIN_SEPARATOR;
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(0, EIP_712_PREFIX)

            // Place the domain separator in the next region of scratch space.
            mstore(EIP712_DomainSeparator_offset, domainSeparator)

            // Place the order hash in scratch space, spilling into the first
            // two bytes of the free memory pointer — this should never be set
            // as memory cannot be expanded to that size, and will be zeroed out
            // after the hash is performed.
            mstore(EIP712_OrderHash_offset, orderHash)

            // Hash the relevant region (65 bytes).
            value := keccak256(0, EIP712_DigestPayload_size)

            // Clear out the dirtied bits in the memory pointer.
            mstore(EIP712_OrderHash_offset, 0)
        }
    }

    /**
     * @dev Internal view function to derive the EIP-712 hash for an offer item.
     *
     * @param offerItem The offered item to hash.
     *
     * @return The hash.
     */
    function _hashOfferItem(OfferItem memory offerItem)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _OFFER_ITEM_TYPEHASH,
                    offerItem.itemType,
                    offerItem.token,
                    offerItem.identifierOrCriteria,
                    offerItem.startAmount,
                    offerItem.endAmount
                )
            );
    }

    /**
     * @dev Internal view function to derive the EIP-712 hash for a consideration item.
     *
     * @param considerationItem The consideration item to hash.
     *
     * @return The hash.
     */
    function _hashConsiderationItem(ConsiderationItem memory considerationItem)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _CONSIDERATION_ITEM_TYPEHASH,
                    considerationItem.itemType,
                    considerationItem.token,
                    considerationItem.identifierOrCriteria,
                    considerationItem.startAmount,
                    considerationItem.endAmount,
                    considerationItem.recipient
                )
            );
    }

    /**
     * @dev Internal view function to derive the order hash for a given order.
     *      Note that only the original consideration items are included in the
     *      order hash, as additional consideration items may be supplied by the
     *      caller.
     *
     * @param orderParameters The parameters of the order to hash.
     * @param counter           The counter of the order to hash.
     *
     * @return orderHash The hash.
     */
    function _deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) internal view returns (bytes32 orderHash) {
        // Designate new memory regions for offer and consideration item hashes.
        bytes32[] memory offerHashes = new bytes32[](
            orderParameters.offer.length
        );
        bytes32[] memory considerationHashes = new bytes32[](
            orderParameters.totalOriginalConsiderationItems
        );

        // Iterate over each offer on the order.
        for (uint256 i = 0; i < orderParameters.offer.length; ++i) {
            // Hash the offer and place the result into memory.
            offerHashes[i] = _hashOfferItem(orderParameters.offer[i]);
        }

        // Iterate over each consideration on the order.
        for (
            uint256 i = 0;
            i < orderParameters.totalOriginalConsiderationItems;
            ++i
        ) {
            // Hash the consideration and place the result into memory.
            considerationHashes[i] = _hashConsiderationItem(
                orderParameters.consideration[i]
            );
        }

        // Derive and return the order hash as specified by EIP-712.

        return
            keccak256(
                abi.encode(
                    _ORDER_TYPEHASH,
                    orderParameters.offerer,
                    orderParameters.zone,
                    keccak256(abi.encodePacked(offerHashes)),
                    keccak256(abi.encodePacked(considerationHashes)),
                    orderParameters.orderType,
                    orderParameters.startTime,
                    orderParameters.endTime,
                    orderParameters.zoneHash,
                    orderParameters.salt,
                    orderParameters.conduitKey,
                    counter
                )
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// prettier-ignore
import {
    BasicOrderParameters,
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

/**
 * @title ConsiderationInterface
 * @author 0age
 * @custom:version 1.1
 * @notice Consideration is a generalized ETH/ERC20/ERC721/ERC1155 marketplace.
 *         It minimizes external calls to the greatest extent possible and
 *         provides lightweight methods for common routes as well as more
 *         flexible methods for composing advanced orders.
 *
 * @dev ConsiderationInterface contains all external function interfaces for
 *      Consideration.
 */
interface ConsiderationInterface {
    /**
     * @notice Fulfill an order offering an ERC721 token by supplying Ether (or
     *         the native token for the given chain) as consideration for the
     *         order. An arbitrary number of "additional recipients" may also be
     *         supplied which will each receive native tokens from the fulfiller
     *         as consideration.
     *
     * @param parameters Additional information on the fulfilled order. Note
     *                   that the offerer must first approve this contract (or
     *                   their preferred conduit if indicated by the order) for
     *                   their offered ERC721 token to be transferred.
     *
     * @return fulfilled A boolean indicating whether the order has been
     *                   successfully fulfilled.
     */
    function fulfillBasicOrder(BasicOrderParameters calldata parameters)
        external
        payable
        returns (bool fulfilled);

    /**
     * @notice Fulfill an order with an arbitrary number of items for offer and
     *         consideration. Note that this function does not support
     *         criteria-based orders or partial filling of orders (though
     *         filling the remainder of a partially-filled order is supported).
     *
     * @param order               The order to fulfill. Note that both the
     *                            offerer and the fulfiller must first approve
     *                            this contract (or the corresponding conduit if
     *                            indicated) to transfer any relevant tokens on
     *                            their behalf and that contracts must implement
     *                            `onERC1155Received` to receive ERC1155 tokens
     *                            as consideration.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used, with direct approvals set on
     *                            Consideration.
     *
     * @return fulfilled A boolean indicating whether the order has been
     *                   successfully fulfilled.
     */
    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey)
        external
        payable
        returns (bool fulfilled);

    /**
     * @notice Fill an order, fully or partially, with an arbitrary number of
     *         items for offer and consideration alongside criteria resolvers
     *         containing specific token identifiers and associated proofs.
     *
     * @param advancedOrder       The order to fulfill along with the fraction
     *                            of the order to attempt to fill. Note that
     *                            both the offerer and the fulfiller must first
     *                            approve this contract (or their preferred
     *                            conduit if indicated by the order) to transfer
     *                            any relevant tokens on their behalf and that
     *                            contracts must implement `onERC1155Received`
     *                            to receive ERC1155 tokens as consideration.
     *                            Also note that all offer and consideration
     *                            components must have no remainder after
     *                            multiplication of the respective amount with
     *                            the supplied fraction for the partial fill to
     *                            be considered valid.
     * @param criteriaResolvers   An array where each element contains a
     *                            reference to a specific offer or
     *                            consideration, a token identifier, and a proof
     *                            that the supplied token identifier is
     *                            contained in the merkle root held by the item
     *                            in question's criteria element. Note that an
     *                            empty criteria indicates that any
     *                            (transferable) token identifier on the token
     *                            in question is valid and that no associated
     *                            proof needs to be supplied.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used, with direct approvals set on
     *                            Consideration.
     * @param recipient           The intended recipient for all received items,
     *                            with `address(0)` indicating that the caller
     *                            should receive the items.
     *
     * @return fulfilled A boolean indicating whether the order has been
     *                   successfully fulfilled.
     */
    function fulfillAdvancedOrder(
        AdvancedOrder calldata advancedOrder,
        CriteriaResolver[] calldata criteriaResolvers,
        bytes32 fulfillerConduitKey,
        address recipient
    ) external payable returns (bool fulfilled);

    /**
     * @notice Attempt to fill a group of orders, each with an arbitrary number
     *         of items for offer and consideration. Any order that is not
     *         currently active, has already been fully filled, or has been
     *         cancelled will be omitted. Remaining offer and consideration
     *         items will then be aggregated where possible as indicated by the
     *         supplied offer and consideration component arrays and aggregated
     *         items will be transferred to the fulfiller or to each intended
     *         recipient, respectively. Note that a failing item transfer or an
     *         issue with order formatting will cause the entire batch to fail.
     *         Note that this function does not support criteria-based orders or
     *         partial filling of orders (though filling the remainder of a
     *         partially-filled order is supported).
     *
     * @param orders                    The orders to fulfill. Note that both
     *                                  the offerer and the fulfiller must first
     *                                  approve this contract (or the
     *                                  corresponding conduit if indicated) to
     *                                  transfer any relevant tokens on their
     *                                  behalf and that contracts must implement
     *                                  `onERC1155Received` to receive ERC1155
     *                                  tokens as consideration.
     * @param offerFulfillments         An array of FulfillmentComponent arrays
     *                                  indicating which offer items to attempt
     *                                  to aggregate when preparing executions.
     * @param considerationFulfillments An array of FulfillmentComponent arrays
     *                                  indicating which consideration items to
     *                                  attempt to aggregate when preparing
     *                                  executions.
     * @param fulfillerConduitKey       A bytes32 value indicating what conduit,
     *                                  if any, to source the fulfiller's token
     *                                  approvals from. The zero hash signifies
     *                                  that no conduit should be used, with
     *                                  direct approvals set on this contract.
     * @param maximumFulfilled          The maximum number of orders to fulfill.
     *
     * @return availableOrders An array of booleans indicating if each order
     *                         with an index corresponding to the index of the
     *                         returned boolean was fulfillable or not.
     * @return executions      An array of elements indicating the sequence of
     *                         transfers performed as part of matching the given
     *                         orders.
     */
    function fulfillAvailableOrders(
        Order[] calldata orders,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        uint256 maximumFulfilled
    )
        external
        payable
        returns (bool[] memory availableOrders, Execution[] memory executions);

    /**
     * @notice Attempt to fill a group of orders, fully or partially, with an
     *         arbitrary number of items for offer and consideration per order
     *         alongside criteria resolvers containing specific token
     *         identifiers and associated proofs. Any order that is not
     *         currently active, has already been fully filled, or has been
     *         cancelled will be omitted. Remaining offer and consideration
     *         items will then be aggregated where possible as indicated by the
     *         supplied offer and consideration component arrays and aggregated
     *         items will be transferred to the fulfiller or to each intended
     *         recipient, respectively. Note that a failing item transfer or an
     *         issue with order formatting will cause the entire batch to fail.
     *
     * @param advancedOrders            The orders to fulfill along with the
     *                                  fraction of those orders to attempt to
     *                                  fill. Note that both the offerer and the
     *                                  fulfiller must first approve this
     *                                  contract (or their preferred conduit if
     *                                  indicated by the order) to transfer any
     *                                  relevant tokens on their behalf and that
     *                                  contracts must implement
     *                                  `onERC1155Received` to enable receipt of
     *                                  ERC1155 tokens as consideration. Also
     *                                  note that all offer and consideration
     *                                  components must have no remainder after
     *                                  multiplication of the respective amount
     *                                  with the supplied fraction for an
     *                                  order's partial fill amount to be
     *                                  considered valid.
     * @param criteriaResolvers         An array where each element contains a
     *                                  reference to a specific offer or
     *                                  consideration, a token identifier, and a
     *                                  proof that the supplied token identifier
     *                                  is contained in the merkle root held by
     *                                  the item in question's criteria element.
     *                                  Note that an empty criteria indicates
     *                                  that any (transferable) token
     *                                  identifier on the token in question is
     *                                  valid and that no associated proof needs
     *                                  to be supplied.
     * @param offerFulfillments         An array of FulfillmentComponent arrays
     *                                  indicating which offer items to attempt
     *                                  to aggregate when preparing executions.
     * @param considerationFulfillments An array of FulfillmentComponent arrays
     *                                  indicating which consideration items to
     *                                  attempt to aggregate when preparing
     *                                  executions.
     * @param fulfillerConduitKey       A bytes32 value indicating what conduit,
     *                                  if any, to source the fulfiller's token
     *                                  approvals from. The zero hash signifies
     *                                  that no conduit should be used, with
     *                                  direct approvals set on this contract.
     * @param recipient                 The intended recipient for all received
     *                                  items, with `address(0)` indicating that
     *                                  the caller should receive the items.
     * @param maximumFulfilled          The maximum number of orders to fulfill.
     *
     * @return availableOrders An array of booleans indicating if each order
     *                         with an index corresponding to the index of the
     *                         returned boolean was fulfillable or not.
     * @return executions      An array of elements indicating the sequence of
     *                         transfers performed as part of matching the given
     *                         orders.
     */
    function fulfillAvailableAdvancedOrders(
        AdvancedOrder[] calldata advancedOrders,
        CriteriaResolver[] calldata criteriaResolvers,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled
    )
        external
        payable
        returns (bool[] memory availableOrders, Execution[] memory executions);

    /**
     * @notice Match an arbitrary number of orders, each with an arbitrary
     *         number of items for offer and consideration along with as set of
     *         fulfillments allocating offer components to consideration
     *         components. Note that this function does not support
     *         criteria-based or partial filling of orders (though filling the
     *         remainder of a partially-filled order is supported).
     *
     * @param orders       The orders to match. Note that both the offerer and
     *                     fulfiller on each order must first approve this
     *                     contract (or their conduit if indicated by the order)
     *                     to transfer any relevant tokens on their behalf and
     *                     each consideration recipient must implement
     *                     `onERC1155Received` to enable ERC1155 token receipt.
     * @param fulfillments An array of elements allocating offer components to
     *                     consideration components. Note that each
     *                     consideration component must be fully met for the
     *                     match operation to be valid.
     *
     * @return executions An array of elements indicating the sequence of
     *                    transfers performed as part of matching the given
     *                    orders.
     */
    function matchOrders(
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    ) external payable returns (Execution[] memory executions);

    /**
     * @notice Match an arbitrary number of full or partial orders, each with an
     *         arbitrary number of items for offer and consideration, supplying
     *         criteria resolvers containing specific token identifiers and
     *         associated proofs as well as fulfillments allocating offer
     *         components to consideration components.
     *
     * @param orders            The advanced orders to match. Note that both the
     *                          offerer and fulfiller on each order must first
     *                          approve this contract (or a preferred conduit if
     *                          indicated by the order) to transfer any relevant
     *                          tokens on their behalf and each consideration
     *                          recipient must implement `onERC1155Received` in
     *                          order to receive ERC1155 tokens. Also note that
     *                          the offer and consideration components for each
     *                          order must have no remainder after multiplying
     *                          the respective amount with the supplied fraction
     *                          in order for the group of partial fills to be
     *                          considered valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root. Note that
     *                          an empty root indicates that any (transferable)
     *                          token identifier is valid and that no associated
     *                          proof needs to be supplied.
     * @param fulfillments      An array of elements allocating offer components
     *                          to consideration components. Note that each
     *                          consideration component must be fully met in
     *                          order for the match operation to be valid.
     *
     * @return executions An array of elements indicating the sequence of
     *                    transfers performed as part of matching the given
     *                    orders.
     */
    function matchAdvancedOrders(
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) external payable returns (Execution[] memory executions);

    /**
     * @notice Cancel an arbitrary number of orders. Note that only the offerer
     *         or the zone of a given order may cancel it. Callers should ensure
     *         that the intended order was cancelled by calling `getOrderStatus`
     *         and confirming that `isCancelled` returns `true`.
     *
     * @param orders The orders to cancel.
     *
     * @return cancelled A boolean indicating whether the supplied orders have
     *                   been successfully cancelled.
     */
    function cancel(OrderComponents[] calldata orders)
        external
        returns (bool cancelled);

    /**
     * @notice Validate an arbitrary number of orders, thereby registering their
     *         signatures as valid and allowing the fulfiller to skip signature
     *         verification on fulfillment. Note that validated orders may still
     *         be unfulfillable due to invalid item amounts or other factors;
     *         callers should determine whether validated orders are fulfillable
     *         by simulating the fulfillment call prior to execution. Also note
     *         that anyone can validate a signed order, but only the offerer can
     *         validate an order without supplying a signature.
     *
     * @param orders The orders to validate.
     *
     * @return validated A boolean indicating whether the supplied orders have
     *                   been successfully validated.
     */
    function validate(Order[] calldata orders)
        external
        returns (bool validated);

    /**
     * @notice Cancel all orders from a given offerer with a given zone in bulk
     *         by incrementing a counter. Note that only the offerer may
     *         increment the counter.
     *
     * @return newCounter The new counter.
     */
    function incrementCounter() external returns (uint256 newCounter);

    /**
     * @notice Retrieve the order hash for a given order.
     *
     * @param order The components of the order.
     *
     * @return orderHash The order hash.
     */
    function getOrderHash(OrderComponents calldata order)
        external
        view
        returns (bytes32 orderHash);

    /**
     * @notice Retrieve the status of a given order by hash, including whether
     *         the order has been cancelled or validated and the fraction of the
     *         order that has been filled.
     *
     * @param orderHash The order hash in question.
     *
     * @return isValidated A boolean indicating whether the order in question
     *                     has been validated (i.e. previously approved or
     *                     partially filled).
     * @return isCancelled A boolean indicating whether the order in question
     *                     has been cancelled.
     * @return totalFilled The total portion of the order that has been filled
     *                     (i.e. the "numerator").
     * @return totalSize   The total size of the order that is either filled or
     *                     unfilled (i.e. the "denominator").
     */
    function getOrderStatus(bytes32 orderHash)
        external
        view
        returns (
            bool isValidated,
            bool isCancelled,
            uint256 totalFilled,
            uint256 totalSize
        );

    /**
     * @notice Retrieve the current counter for a given offerer.
     *
     * @param offerer The offerer in question.
     *
     * @return counter The current counter.
     */
    function getCounter(address offerer)
        external
        view
        returns (uint256 counter);

    /**
     * @notice Retrieve configuration information for this contract.
     *
     * @return version           The contract version.
     * @return domainSeparator   The domain separator for this contract.
     * @return conduitController The conduit Controller set for this contract.
     */
    function information()
        external
        view
        returns (
            string memory version,
            bytes32 domainSeparator,
            address conduitController
        );

    /**
     * @notice Retrieve the name of this contract.
     *
     * @return contractName The name of this contract.
     */
    function name() external view returns (string memory contractName);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title ConduitControllerInterface
 * @author 0age
 * @notice ConduitControllerInterface contains all external function interfaces,
 *         structs, events, and errors for the conduit controller.
 */
interface ConduitControllerInterface {
    /**
     * @dev Track the conduit key, current owner, new potential owner, and open
     *      channels for each deployed conduit.
     */
    struct ConduitProperties {
        bytes32 key;
        address owner;
        address potentialOwner;
        address[] channels;
        mapping(address => uint256) channelIndexesPlusOne;
    }

    /**
     * @dev Emit an event whenever a new conduit is created.
     *
     * @param conduit    The newly created conduit.
     * @param conduitKey The conduit key used to create the new conduit.
     */
    event NewConduit(address conduit, bytes32 conduitKey);

    /**
     * @dev Emit an event whenever conduit ownership is transferred.
     *
     * @param conduit       The conduit for which ownership has been
     *                      transferred.
     * @param previousOwner The previous owner of the conduit.
     * @param newOwner      The new owner of the conduit.
     */
    event OwnershipTransferred(
        address indexed conduit,
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Emit an event whenever a conduit owner registers a new potential
     *      owner for that conduit.
     *
     * @param newPotentialOwner The new potential owner of the conduit.
     */
    event PotentialOwnerUpdated(address indexed newPotentialOwner);

    /**
     * @dev Revert with an error when attempting to create a new conduit using a
     *      conduit key where the first twenty bytes of the key do not match the
     *      address of the caller.
     */
    error InvalidCreator();

    /**
     * @dev Revert with an error when attempting to create a new conduit when no
     *      initial owner address is supplied.
     */
    error InvalidInitialOwner();

    /**
     * @dev Revert with an error when attempting to set a new potential owner
     *      that is already set.
     */
    error NewPotentialOwnerAlreadySet(
        address conduit,
        address newPotentialOwner
    );

    /**
     * @dev Revert with an error when attempting to cancel ownership transfer
     *      when no new potential owner is currently set.
     */
    error NoPotentialOwnerCurrentlySet(address conduit);

    /**
     * @dev Revert with an error when attempting to interact with a conduit that
     *      does not yet exist.
     */
    error NoConduit();

    /**
     * @dev Revert with an error when attempting to create a conduit that
     *      already exists.
     */
    error ConduitAlreadyExists(address conduit);

    /**
     * @dev Revert with an error when attempting to update channels or transfer
     *      ownership of a conduit when the caller is not the owner of the
     *      conduit in question.
     */
    error CallerIsNotOwner(address conduit);

    /**
     * @dev Revert with an error when attempting to register a new potential
     *      owner and supplying the null address.
     */
    error NewPotentialOwnerIsZeroAddress(address conduit);

    /**
     * @dev Revert with an error when attempting to claim ownership of a conduit
     *      with a caller that is not the current potential owner for the
     *      conduit in question.
     */
    error CallerIsNotNewPotentialOwner(address conduit);

    /**
     * @dev Revert with an error when attempting to retrieve a channel using an
     *      index that is out of range.
     */
    error ChannelOutOfRange(address conduit);

    /**
     * @notice Deploy a new conduit using a supplied conduit key and assigning
     *         an initial owner for the deployed conduit. Note that the first
     *         twenty bytes of the supplied conduit key must match the caller
     *         and that a new conduit cannot be created if one has already been
     *         deployed using the same conduit key.
     *
     * @param conduitKey   The conduit key used to deploy the conduit. Note that
     *                     the first twenty bytes of the conduit key must match
     *                     the caller of this contract.
     * @param initialOwner The initial owner to set for the new conduit.
     *
     * @return conduit The address of the newly deployed conduit.
     */
    function createConduit(bytes32 conduitKey, address initialOwner)
        external
        returns (address conduit);

    /**
     * @notice Open or close a channel on a given conduit, thereby allowing the
     *         specified account to execute transfers against that conduit.
     *         Extreme care must be taken when updating channels, as malicious
     *         or vulnerable channels can transfer any ERC20, ERC721 and ERC1155
     *         tokens where the token holder has granted the conduit approval.
     *         Only the owner of the conduit in question may call this function.
     *
     * @param conduit The conduit for which to open or close the channel.
     * @param channel The channel to open or close on the conduit.
     * @param isOpen  A boolean indicating whether to open or close the channel.
     */
    function updateChannel(
        address conduit,
        address channel,
        bool isOpen
    ) external;

    /**
     * @notice Initiate conduit ownership transfer by assigning a new potential
     *         owner for the given conduit. Once set, the new potential owner
     *         may call `acceptOwnership` to claim ownership of the conduit.
     *         Only the owner of the conduit in question may call this function.
     *
     * @param conduit The conduit for which to initiate ownership transfer.
     * @param newPotentialOwner The new potential owner of the conduit.
     */
    function transferOwnership(address conduit, address newPotentialOwner)
        external;

    /**
     * @notice Clear the currently set potential owner, if any, from a conduit.
     *         Only the owner of the conduit in question may call this function.
     *
     * @param conduit The conduit for which to cancel ownership transfer.
     */
    function cancelOwnershipTransfer(address conduit) external;

    /**
     * @notice Accept ownership of a supplied conduit. Only accounts that the
     *         current owner has set as the new potential owner may call this
     *         function.
     *
     * @param conduit The conduit for which to accept ownership.
     */
    function acceptOwnership(address conduit) external;

    /**
     * @notice Retrieve the current owner of a deployed conduit.
     *
     * @param conduit The conduit for which to retrieve the associated owner.
     *
     * @return owner The owner of the supplied conduit.
     */
    function ownerOf(address conduit) external view returns (address owner);

    /**
     * @notice Retrieve the conduit key for a deployed conduit via reverse
     *         lookup.
     *
     * @param conduit The conduit for which to retrieve the associated conduit
     *                key.
     *
     * @return conduitKey The conduit key used to deploy the supplied conduit.
     */
    function getKey(address conduit) external view returns (bytes32 conduitKey);

    /**
     * @notice Derive the conduit associated with a given conduit key and
     *         determine whether that conduit exists (i.e. whether it has been
     *         deployed).
     *
     * @param conduitKey The conduit key used to derive the conduit.
     *
     * @return conduit The derived address of the conduit.
     * @return exists  A boolean indicating whether the derived conduit has been
     *                 deployed or not.
     */
    function getConduit(bytes32 conduitKey)
        external
        view
        returns (address conduit, bool exists);

    /**
     * @notice Retrieve the potential owner, if any, for a given conduit. The
     *         current owner may set a new potential owner via
     *         `transferOwnership` and that owner may then accept ownership of
     *         the conduit in question via `acceptOwnership`.
     *
     * @param conduit The conduit for which to retrieve the potential owner.
     *
     * @return potentialOwner The potential owner, if any, for the conduit.
     */
    function getPotentialOwner(address conduit)
        external
        view
        returns (address potentialOwner);

    /**
     * @notice Retrieve the status (either open or closed) of a given channel on
     *         a conduit.
     *
     * @param conduit The conduit for which to retrieve the channel status.
     * @param channel The channel for which to retrieve the status.
     *
     * @return isOpen The status of the channel on the given conduit.
     */
    function getChannelStatus(address conduit, address channel)
        external
        view
        returns (bool isOpen);

    /**
     * @notice Retrieve the total number of open channels for a given conduit.
     *
     * @param conduit The conduit for which to retrieve the total channel count.
     *
     * @return totalChannels The total number of open channels for the conduit.
     */
    function getTotalChannels(address conduit)
        external
        view
        returns (uint256 totalChannels);

    /**
     * @notice Retrieve an open channel at a specific index for a given conduit.
     *         Note that the index of a channel can change as a result of other
     *         channels being closed on the conduit.
     *
     * @param conduit      The conduit for which to retrieve the open channel.
     * @param channelIndex The index of the channel in question.
     *
     * @return channel The open channel, if any, at the specified channel index.
     */
    function getChannel(address conduit, uint256 channelIndex)
        external
        view
        returns (address channel);

    /**
     * @notice Retrieve all open channels for a given conduit. Note that calling
     *         this function for a conduit with many channels will revert with
     *         an out-of-gas error.
     *
     * @param conduit The conduit for which to retrieve open channels.
     *
     * @return channels An array of open channels on the given conduit.
     */
    function getChannels(address conduit)
        external
        view
        returns (address[] memory channels);

    /**
     * @dev Retrieve the conduit creation code and runtime code hashes.
     */
    function getConduitCodeHashes()
        external
        view
        returns (bytes32 creationCodeHash, bytes32 runtimeCodeHash);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {
    AdvancedOrder,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

interface ZoneInterface {
    // Called by Consideration whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view returns (bytes4 validOrderMagicValue);

    // Called by Consideration whenever any extraData is provided by the caller.
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view returns (bytes4 validOrderMagicValue);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1155.sol)

pragma solidity ^0.8.0;

import "../token/ERC1155/IERC1155.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
import {
    ValidationError,
    ValidationWarning
} from "./SeaportValidatorTypes.sol";

pragma solidity ^0.8.10;

struct ErrorsAndWarnings {
    uint8[] errors;
    uint8[] warnings;
}

library ErrorsAndWarningsLib {
    function concat(ErrorsAndWarnings memory ew1, ErrorsAndWarnings memory ew2)
        internal
        pure
    {
        ew1.errors = concatMemory(ew1.errors, ew2.errors);
        ew1.warnings = concatMemory(ew1.warnings, ew2.warnings);
    }

    function addError(ErrorsAndWarnings memory ew, ValidationError err)
        internal
        pure
    {
        ew.errors = pushMemory(ew.errors, uint8(err));
    }

    function addWarning(ErrorsAndWarnings memory ew, ValidationWarning warn)
        internal
        pure
    {
        ew.warnings = pushMemory(ew.warnings, uint8(warn));
    }

    function hasErrors(ErrorsAndWarnings memory ew)
        internal
        pure
        returns (bool)
    {
        return ew.errors.length != 0;
    }

    function hasWarnings(ErrorsAndWarnings memory ew)
        internal
        pure
        returns (bool)
    {
        return ew.warnings.length != 0;
    }

    // Helper Functions
    function concatMemory(uint8[] memory array1, uint8[] memory array2)
        private
        pure
        returns (uint8[] memory)
    {
        if (array1.length == 0) {
            return array2;
        } else if (array2.length == 0) {
            return array1;
        }

        uint8[] memory returnValue = new uint8[](array1.length + array2.length);

        for (uint256 i = 0; i < array1.length; i++) {
            returnValue[i] = array1[i];
        }
        for (uint256 i = 0; i < array2.length; i++) {
            returnValue[i + array1.length] = array2[i];
        }

        return returnValue;
    }

    function pushMemory(uint8[] memory uint8Array, uint8 newValue)
        internal
        pure
        returns (uint8[] memory)
    {
        uint8[] memory returnValue = new uint8[](uint8Array.length + 1);

        for (uint256 i = 0; i < uint8Array.length; i++) {
            returnValue[i] = uint8Array[i];
        }
        returnValue[uint8Array.length] = newValue;

        return returnValue;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library SafeStaticCall {
    function safeStaticCallBool(
        address target,
        bytes memory callData,
        bool expectedReturn
    ) internal view returns (bool) {
        (bool success, bytes memory res) = target.staticcall(callData);
        if (!success) return false;
        if (res.length != 32) return false;

        for (uint256 i = 0; i < 31; i++) {
            if (res[i] != 0) return false;
        }

        return expectedReturn ? res[31] == 0x01 : res[31] == 0;
    }

    function safeStaticCallAddress(
        address target,
        bytes memory callData,
        address expectedReturn
    ) internal view returns (bool) {
        (bool success, bytes memory res) = target.staticcall(callData);
        if (!success) return false;
        if (res.length != 32) return false;

        if (
            bytes32(res) &
                0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF !=
            bytes32(res)
        ) {
            // Ensure only 20 bytes used
            return false;
        }

        return abi.decode(res, (address)) == expectedReturn;
    }

    function safeStaticCallUint256(
        address target,
        bytes memory callData,
        uint256 minExpectedReturn
    ) internal view returns (bool) {
        (bool success, bytes memory res) = target.staticcall(callData);
        if (!success) return false;
        if (res.length != 32) return false;

        return abi.decode(res, (uint256)) >= minExpectedReturn;
    }

    function safeStaticCallBytes4(
        address target,
        bytes memory callData,
        bytes4 expectedReturn
    ) internal view returns (bool) {
        (bool success, bytes memory res) = target.staticcall(callData);
        if (!success) return false;
        if (res.length != 32) return false;
        if (
            bytes32(res) &
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000 !=
            bytes32(res)
        ) {
            // Ensure only 4 bytes used
            return false;
        }

        return abi.decode(res, (bytes4)) == expectedReturn;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Murky {
    bool public immutable HASH_ODD_WITH_ZERO;

    constructor(bool hashOddWithZero) {
        HASH_ODD_WITH_ZERO = hashOddWithZero;
    }

    function verifyProof(
        bytes32 root,
        bytes32[] calldata proof,
        bytes32 valueToProve
    ) external pure returns (bool) {
        // proof length must be less than max array size
        bytes32 rollingHash = valueToProve;
        uint256 length = proof.length;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                rollingHash = hashLeafPairs(rollingHash, proof[i]);
            }
        }
        return root == rollingHash;
    }

    /********************
     * HASHING FUNCTION *
     ********************/

    /// ascending sort and concat prior to hashing
    function hashLeafPairs(bytes32 left, bytes32 right)
        public
        pure
        returns (bytes32 _hash)
    {
        assembly {
            switch lt(left, right)
            case 0 {
                mstore(0x0, right)
                mstore(0x20, left)
            }
            default {
                mstore(0x0, left)
                mstore(0x20, right)
            }
            _hash := keccak256(0x0, 0x40)
        }
    }

    /********************
     * PROOF GENERATION *
     ********************/

    function getRoot(bytes32[] memory data)
        external
        view
        returns (bytes32 result)
    {
        require(data.length > 1, "won't generate root for single leaf");
        bool hashOddWithZero = HASH_ODD_WITH_ZERO;

        processInput(data);

        assembly {
            function hashLeafPairs(left, right) -> _hash {
                switch lt(left, right)
                case 0 {
                    mstore(0x0, right)
                    mstore(0x20, left)
                }
                default {
                    mstore(0x0, left)
                    mstore(0x20, right)
                }
                _hash := keccak256(0x0, 0x40)
            }
            function hashLevel(_data, length, _hashOddWithZero) -> newLength {
                // we will be modifying data in-place, so set result pointer to data pointer
                let _result := _data
                // get length of original data array
                // let length := mload(_data)
                // bool to track if we need to hash the last element of an odd-length array with zero
                let oddLength

                // if length is odd, we need to hash the last element with zero
                switch and(length, 1)
                case 1 {
                    // if length is odd, add 1 so division by 2 will round up
                    newLength := add(1, div(length, 2))
                    oddLength := 1
                }
                default {
                    newLength := div(length, 2)
                }
                // todo: necessary?
                // mstore(_data, newLength)
                let resultIndexPointer := add(0x20, _data)
                let dataIndexPointer := resultIndexPointer

                // stop iterating over for loop at length-1
                let stopIteration := add(_data, mul(length, 0x20))
                // write result array in-place over data array
                for {

                } lt(dataIndexPointer, stopIteration) {

                } {
                    // get next two elements from data, hash them together
                    let data1 := mload(dataIndexPointer)
                    let data2 := mload(add(dataIndexPointer, 0x20))
                    let hashedPair := hashLeafPairs(data1, data2)
                    // overwrite an element of data array with
                    mstore(resultIndexPointer, hashedPair)
                    // increment result pointer by 1 slot
                    resultIndexPointer := add(0x20, resultIndexPointer)
                    // increment data pointer by 2 slot
                    dataIndexPointer := add(0x40, dataIndexPointer)
                }
                // we did not yet hash last index if odd-length
                if oddLength {
                    let data1 := mload(dataIndexPointer)
                    let nextValue
                    switch _hashOddWithZero
                    case 0 {
                        nextValue := data1
                    }
                    default {
                        nextValue := hashLeafPairs(data1, 0)
                    }
                    mstore(resultIndexPointer, nextValue)
                }
            }

            let dataLength := mload(data)
            for {

            } gt(dataLength, 1) {

            } {
                dataLength := hashLevel(data, dataLength, hashOddWithZero)
            }
            result := mload(add(0x20, data))
        }
    }

    function getProof(bytes32[] memory data, uint256 node)
        external
        view
        returns (bytes32[] memory result)
    {
        require(data.length > 1, "won't generate proof for single leaf");
        bool hashOddWithZero = HASH_ODD_WITH_ZERO;

        processInput(data);

        // The size of the proof is equal to the ceiling of log2(numLeaves)
        // Two overflow risks: node, pos
        // node: max array size is 2**256-1. Largest index in the array will be 1 less than that. Also,
        // for dynamic arrays, size is limited to 2**64-1
        // pos: pos is bounded by log2(data.length), which should be less than type(uint256).max
        assembly {
            function hashLeafPairs(left, right) -> _hash {
                switch lt(left, right)
                case 0 {
                    mstore(0x0, right)
                    mstore(0x20, left)
                }
                default {
                    mstore(0x0, left)
                    mstore(0x20, right)
                }
                _hash := keccak256(0x0, 0x40)
            }
            function hashLevel(_data, length, _hashOddWithZero) -> newLength {
                // we will be modifying data in-place, so set result pointer to data pointer
                let _result := _data
                // get length of original data array
                // let length := mload(_data)
                // bool to track if we need to hash the last element of an odd-length array with zero
                let oddLength

                // if length is odd, we'll need to hash the last element with zero
                switch and(length, 1)
                case 1 {
                    // if length is odd, add 1 so division by 2 will round up
                    newLength := add(1, div(length, 2))
                    oddLength := 1
                }
                default {
                    newLength := div(length, 2)
                }
                // todo: necessary?
                // mstore(_data, newLength)
                let resultIndexPointer := add(0x20, _data)
                let dataIndexPointer := resultIndexPointer

                // stop iterating over for loop at length-1
                let stopIteration := add(_data, mul(length, 0x20))
                // write result array in-place over data array
                for {

                } lt(dataIndexPointer, stopIteration) {

                } {
                    // get next two elements from data, hash them together
                    let data1 := mload(dataIndexPointer)
                    let data2 := mload(add(dataIndexPointer, 0x20))
                    let hashedPair := hashLeafPairs(data1, data2)
                    // overwrite an element of data array with
                    mstore(resultIndexPointer, hashedPair)
                    // increment result pointer by 1 slot
                    resultIndexPointer := add(0x20, resultIndexPointer)
                    // increment data pointer by 2 slot
                    dataIndexPointer := add(0x40, dataIndexPointer)
                }
                // we did not yet hash last index if odd-length
                if oddLength {
                    let data1 := mload(dataIndexPointer)
                    let nextValue
                    switch _hashOddWithZero
                    case 0 {
                        nextValue := data1
                    }
                    default {
                        nextValue := hashLeafPairs(data1, 0)
                    }
                    mstore(resultIndexPointer, nextValue)
                }
            }

            // set result pointer to free memory
            result := mload(0x40)
            // get pointer to first index of result
            let resultIndexPtr := add(0x20, result)
            // declare so we can use later
            let newLength
            // put length of data onto stack
            let dataLength := mload(data)
            for {
                // repeat until only one element is left
            } gt(dataLength, 1) {

            } {
                // bool if node is odd
                let oddNodeIndex := and(node, 1)
                // bool if node is last
                let lastNodeIndex := eq(dataLength, add(1, node))
                // store both bools in one value so we can switch on it
                let switchVal := or(shl(1, lastNodeIndex), oddNodeIndex)
                switch switchVal
                // 00 - neither odd nor last
                case 0 {
                    // store data[node+1] at result[i]
                    // get pointer to result[node+1] by adding 2 to node and multiplying by 0x20
                    // to account for the fact that result points to array length, not first index
                    mstore(
                        resultIndexPtr,
                        mload(add(data, mul(0x20, add(2, node))))
                    )
                }
                // 10 - node is last
                case 2 {
                    // store 0 at result[i]
                    mstore(resultIndexPtr, 0)
                }
                // 01 or 11 - node is odd (and possibly also last)
                default {
                    // store data[node-1] at result[i]
                    mstore(resultIndexPtr, mload(add(data, mul(0x20, node))))
                }
                // increment result index
                resultIndexPtr := add(0x20, resultIndexPtr)

                // get new node index
                node := div(node, 2)
                // keep track of how long result array is
                newLength := add(1, newLength)
                // compute the next hash level, overwriting data, and get the new length
                dataLength := hashLevel(data, dataLength, hashOddWithZero)
            }
            // store length of result array at pointer
            mstore(result, newLength)
            // set free mem pointer to word after end of result array
            mstore(0x40, resultIndexPtr)
        }
    }

    /**
     * Hashes each element of the input array in place using keccak256
     */
    function processInput(bytes32[] memory data) public pure {
        // Hash inputs with keccak256
        for (uint256 i = 0; i < data.length; ++i) {
            assembly {
                mstore(
                    add(data, mul(0x20, add(1, i))),
                    keccak256(add(data, mul(0x20, add(1, i))), 0x20)
                )
                // for every element after the first, hashed value must be greater than the last one
                if and(
                    gt(i, 0),
                    iszero(
                        gt(
                            mload(add(data, mul(0x20, add(1, i)))),
                            mload(add(data, mul(0x20, add(1, sub(i, 1)))))
                        )
                    )
                ) {
                    revert(0, 0) // Elements not ordered by hash
                }
            }
        }
    }

    // Sort uint256 in order of the keccak256 hashes
    struct HashAndIntTuple {
        uint256 num;
        bytes32 hash;
    }

    function sortUint256ByHash(uint256[] memory values)
        public
        view
        returns (uint256[] memory sortedValues)
    {
        HashAndIntTuple[] memory toSort = new HashAndIntTuple[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            toSort[i] = HashAndIntTuple(
                values[i],
                keccak256(abi.encode(values[i]))
            );
        }

        quickSort(toSort, 0, int256(toSort.length - 1));

        sortedValues = new uint256[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            sortedValues[i] = toSort[i].num;
        }
    }

    function quickSort(
        HashAndIntTuple[] memory arr,
        int256 left,
        int256 right
    ) internal view {
        int256 i = left;
        int256 j = right;
        if (i == j) return;
        bytes32 pivot = arr[uint256(left + (right - left) / 2)].hash;
        while (i <= j) {
            while (arr[uint256(i)].hash < pivot) i++;
            while (pivot < arr[uint256(j)].hash) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (
                    arr[uint256(j)],
                    arr[uint256(i)]
                );
                i++;
                j--;
            }
        }
        if (left < j) quickSort(arr, left, j);
        if (i < right) quickSort(arr, i, right);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface RoyaltyEngineInterface {
    function getRoyaltyView(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    )
        external
        view
        returns (address payable[] memory recipients, uint256[] memory amounts);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

struct ValidationConfiguration {
    address protocolFeeRecipient;
    uint256 protocolFeeBips;
    bool checkRoyaltyFee;
}

enum ValidationError {
    Time_EndTimeBeforeStartTime,
    Time_Expired,
    Status_Cancelled,
    Status_FullyFilled,
    Offer_ZeroItems,
    Offer_AmountZero,
    Consideration_AmountZero,
    Consideration_NullRecipient,
    Consideration_ExtraItems,
    Consideration_PrivateSaleToSelf,
    ProtocolFee_Missing,
    ProtocolFee_ItemType,
    ProtocolFee_Token,
    ProtocolFee_StartAmount,
    ProtocolFee_EndAmount,
    ProtocolFee_Recipient,
    ERC721_AmountNotOne,
    ERC721_InvalidToken,
    ERC721_IdentifierDNE,
    ERC721_NotOwner,
    ERC721_NotApproved,
    ERC1155_InvalidToken,
    ERC1155_NotApproved,
    ERC1155_InsufficientBalance,
    ERC20_IdentifierNonZero,
    ERC20_InvalidToken,
    ERC20_InsufficientAllowance,
    ERC20_InsufficientBalance,
    Native_TokenAddress,
    Native_IdentifierNonZero,
    Native_InsufficientBalance,
    Zone_RejectedOrder,
    Conduit_KeyInvalid,
    InvalidItemType,
    MerkleError,
    InvalidOrderFormat,
    InvalidSignature,
    RoyaltyFee_Missing,
    RoyaltyFee_ItemType,
    RoyaltyFee_Token,
    RoyaltyFee_StartAmount,
    RoyaltyFee_EndAmount,
    RoyaltyFee_Recipient
}

enum ValidationWarning {
    Time_DistantExpiration,
    Time_NotActive,
    Time_ShortOrder,
    Offer_MoreThanOneItem,
    Offer_NativeItem,
    Consideration_ZeroItems
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ConsiderationConstants.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { SafeStaticCall } from "./SafeStaticCall.sol";

/**
 * @title SignatureVerification
 * @author 0age
 * @notice SignatureVerification contains logic for verifying signatures.
 */
abstract contract SignatureVerification {
    using SafeStaticCall for address;

    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted if either the signature length
     *      is not 64 or 65 bytes or if the recovered signer does not match the
     *      supplied signer. Note that in cases where a 64 or 65 byte signature
     *      is supplied, only standard ECDSA signatures that recover to a
     *      non-zero address are supported.
     *
     * @param signer    The signer for the order.
     * @param digest    The digest to verify the signature against.
     * @param signature A signature from the signer indicating that the order
     *                  has been approved.
     */
    function _isValidSignature(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view returns (bool) {
        // Declare r, s, and v signature parameters.
        bytes32 r;
        bytes32 s;
        uint8 v;

        if (signer.code.length > 0) {
            // If signer is a contract, try verification via EIP-1271.
            return _isValidEIP1271Signature(signer, digest, signature);
        } else if (signature.length == 64) {
            // If signature contains 64 bytes, parse as EIP-2098 signature. (r+s&v)
            // Declare temporary vs that will be decomposed into s and v.
            bytes32 vs;

            (r, vs) = abi.decode(signature, (bytes32, bytes32));

            s = vs & EIP2098_allButHighestBitMask;

            v = uint8(uint256(vs >> 255)) + 27;
        } else if (signature.length == 65) {
            (r, s) = abi.decode(signature, (bytes32, bytes32));
            v = uint8(signature[64]);

            // Ensure v value is properly formatted.
            if (v != 27 && v != 28) {
                return false;
            }
        } else {
            return false;
        }

        // Attempt to recover signer using the digest and signature parameters.
        address recoveredSigner = ecrecover(digest, v, r, s);

        // Disallow invalid signers.
        if (recoveredSigner == address(0) || recoveredSigner != signer) {
            return false;
            // Should a signer be recovered, but it doesn't match the signer...
        }

        return true;
    }

    /**
     * @dev Internal view function to verify the signature of an order using
     *      ERC-1271 (i.e. contract signatures via `isValidSignature`).
     *
     * @param signer    The signer for the order.
     * @param digest    The signature digest, derived from the domain separator
     *                  and the order hash.
     * @param signature A signature (or other data) used to validate the digest.
     */
    function _isValidEIP1271Signature(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view returns (bool) {
        if (
            !signer.safeStaticCallBytes4(
                abi.encodeWithSelector(
                    IERC1271.isValidSignature.selector,
                    digest,
                    signature
                ),
                IERC1271.isValidSignature.selector
            )
        ) {
            return false;
        }
        return true;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/*
 * -------------------------- Disambiguation & Other Notes ---------------------
 *    - The term "head" is used as it is in the documentation for ABI encoding,
 *      but only in reference to dynamic types, i.e. it always refers to the
 *      offset or pointer to the body of a dynamic type. In calldata, the head
 *      is always an offset (relative to the parent object), while in memory,
 *      the head is always the pointer to the body. More information found here:
 *      https://docs.soliditylang.org/en/v0.8.14/abi-spec.html#argument-encoding
 *        - Note that the length of an array is separate from and precedes the
 *          head of the array.
 *
 *    - The term "body" is used in place of the term "head" used in the ABI
 *      documentation. It refers to the start of the data for a dynamic type,
 *      e.g. the first word of a struct or the first word of the first element
 *      in an array.
 *
 *    - The term "pointer" is used to describe the absolute position of a value
 *      and never an offset relative to another value.
 *        - The suffix "_ptr" refers to a memory pointer.
 *        - The suffix "_cdPtr" refers to a calldata pointer.
 *
 *    - The term "offset" is used to describe the position of a value relative
 *      to some parent value. For example, OrderParameters_conduit_offset is the
 *      offset to the "conduit" value in the OrderParameters struct relative to
 *      the start of the body.
 *        - Note: Offsets are used to derive pointers.
 *
 *    - Some structs have pointers defined for all of their fields in this file.
 *      Lines which are commented out are fields that are not used in the
 *      codebase but have been left in for readability.
 */

// Declare constants for name, version, and reentrancy sentinel values.

// Name is right padded, so it touches the length which is left padded. This
// enables writing both values at once. Length goes at byte 95 in memory, and
// name fills bytes 96-109, so both values can be written left-padded to 77.
uint256 constant NameLengthPtr = 77;
uint256 constant NameWithLength = 0x0d436F6E73696465726174696F6E;

uint256 constant Version = 0x312e31;
uint256 constant Version_length = 3;
uint256 constant Version_shift = 0xe8;

uint256 constant _NOT_ENTERED = 1;
uint256 constant _ENTERED = 2;

// Common Offsets
// Offsets for identically positioned fields shared by:
// OfferItem, ConsiderationItem, SpentItem, ReceivedItem

uint256 constant Common_token_offset = 0x20;
uint256 constant Common_identifier_offset = 0x40;
uint256 constant Common_amount_offset = 0x60;

uint256 constant ReceivedItem_size = 0xa0;
uint256 constant ReceivedItem_amount_offset = 0x60;
uint256 constant ReceivedItem_recipient_offset = 0x80;

uint256 constant ReceivedItem_CommonParams_size = 0x60;

uint256 constant ConsiderationItem_recipient_offset = 0xa0;
// Store the same constant in an abbreviated format for a line length fix.
uint256 constant ConsiderItem_recipient_offset = 0xa0;

uint256 constant Execution_offerer_offset = 0x20;
uint256 constant Execution_conduit_offset = 0x40;

uint256 constant InvalidFulfillmentComponentData_error_signature = (
    0x7fda727900000000000000000000000000000000000000000000000000000000
);
uint256 constant InvalidFulfillmentComponentData_error_len = 0x04;

uint256 constant Panic_error_signature = (
    0x4e487b7100000000000000000000000000000000000000000000000000000000
);
uint256 constant Panic_error_offset = 0x04;
uint256 constant Panic_error_length = 0x24;
uint256 constant Panic_arithmetic = 0x11;

uint256 constant MissingItemAmount_error_signature = (
    0x91b3e51400000000000000000000000000000000000000000000000000000000
);
uint256 constant MissingItemAmount_error_len = 0x04;

uint256 constant OrderParameters_offer_head_offset = 0x40;
uint256 constant OrderParameters_consideration_head_offset = 0x60;
uint256 constant OrderParameters_conduit_offset = 0x120;
uint256 constant OrderParameters_counter_offset = 0x140;

uint256 constant Fulfillment_itemIndex_offset = 0x20;

uint256 constant AdvancedOrder_numerator_offset = 0x20;

uint256 constant AlmostOneWord = 0x1f;
uint256 constant OneWord = 0x20;
uint256 constant TwoWords = 0x40;
uint256 constant ThreeWords = 0x60;
uint256 constant FourWords = 0x80;
uint256 constant FiveWords = 0xa0;

uint256 constant FreeMemoryPointerSlot = 0x40;
uint256 constant ZeroSlot = 0x60;
uint256 constant DefaultFreeMemoryPointer = 0x80;

uint256 constant Slot0x80 = 0x80;
uint256 constant Slot0xA0 = 0xa0;

uint256 constant BasicOrder_endAmount_cdPtr = 0x104;
uint256 constant BasicOrder_common_params_size = 0xa0;
uint256 constant BasicOrder_considerationHashesArray_ptr = 0x160;

uint256 constant EIP712_Order_size = 0x180;
uint256 constant EIP712_OfferItem_size = 0xc0;
uint256 constant EIP712_ConsiderationItem_size = 0xe0;
uint256 constant AdditionalRecipients_size = 0x40;

uint256 constant EIP712_DomainSeparator_offset = 0x02;
uint256 constant EIP712_OrderHash_offset = 0x22;
uint256 constant EIP712_DigestPayload_size = 0x42;

uint256 constant receivedItemsHash_ptr = 0x60;

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  data for OrderFulfilled
 *
 *   event OrderFulfilled(
 *     bytes32 orderHash,
 *     address indexed offerer,
 *     address indexed zone,
 *     address fulfiller,
 *     SpentItem[] offer,
 *       > (itemType, token, id, amount)
 *     ReceivedItem[] consideration
 *       > (itemType, token, id, amount, recipient)
 *   )
 *
 *  - 0x00: orderHash
 *  - 0x20: fulfiller
 *  - 0x40: offer offset (0x80)
 *  - 0x60: consideration offset (0x120)
 *  - 0x80: offer.length (1)
 *  - 0xa0: offerItemType
 *  - 0xc0: offerToken
 *  - 0xe0: offerIdentifier
 *  - 0x100: offerAmount
 *  - 0x120: consideration.length (1 + additionalRecipients.length)
 *  - 0x140: considerationItemType
 *  - 0x160: considerationToken
 *  - 0x180: considerationIdentifier
 *  - 0x1a0: considerationAmount
 *  - 0x1c0: considerationRecipient
 *  - ...
 */

// Minimum length of the OrderFulfilled event data.
// Must be added to the size of the ReceivedItem array for additionalRecipients
// (0xa0 * additionalRecipients.length) to calculate full size of the buffer.
uint256 constant OrderFulfilled_baseSize = 0x1e0;
uint256 constant OrderFulfilled_selector = (
    0x9d9af8e38d66c62e2c12f0225249fd9d721c54b83f48d9352c97c6cacdcb6f31
);

// Minimum offset in memory to OrderFulfilled event data.
// Must be added to the size of the EIP712 hash array for additionalRecipients
// (32 * additionalRecipients.length) to calculate the pointer to event data.
uint256 constant OrderFulfilled_baseOffset = 0x180;
uint256 constant OrderFulfilled_consideration_length_baseOffset = 0x2a0;
uint256 constant OrderFulfilled_offer_length_baseOffset = 0x200;

// uint256 constant OrderFulfilled_orderHash_offset = 0x00;
uint256 constant OrderFulfilled_fulfiller_offset = 0x20;
uint256 constant OrderFulfilled_offer_head_offset = 0x40;
uint256 constant OrderFulfilled_offer_body_offset = 0x80;
uint256 constant OrderFulfilled_consideration_head_offset = 0x60;
uint256 constant OrderFulfilled_consideration_body_offset = 0x120;

// BasicOrderParameters
uint256 constant BasicOrder_parameters_cdPtr = 0x04;
uint256 constant BasicOrder_considerationToken_cdPtr = 0x24;
// uint256 constant BasicOrder_considerationIdentifier_cdPtr = 0x44;
uint256 constant BasicOrder_considerationAmount_cdPtr = 0x64;
uint256 constant BasicOrder_offerer_cdPtr = 0x84;
uint256 constant BasicOrder_zone_cdPtr = 0xa4;
uint256 constant BasicOrder_offerToken_cdPtr = 0xc4;
// uint256 constant BasicOrder_offerIdentifier_cdPtr = 0xe4;
uint256 constant BasicOrder_offerAmount_cdPtr = 0x104;
uint256 constant BasicOrder_basicOrderType_cdPtr = 0x124;
uint256 constant BasicOrder_startTime_cdPtr = 0x144;
// uint256 constant BasicOrder_endTime_cdPtr = 0x164;
// uint256 constant BasicOrder_zoneHash_cdPtr = 0x184;
// uint256 constant BasicOrder_salt_cdPtr = 0x1a4;
uint256 constant BasicOrder_offererConduit_cdPtr = 0x1c4;
uint256 constant BasicOrder_fulfillerConduit_cdPtr = 0x1e4;
uint256 constant BasicOrder_totalOriginalAdditionalRecipients_cdPtr = 0x204;
uint256 constant BasicOrder_additionalRecipients_head_cdPtr = 0x224;
uint256 constant BasicOrder_signature_cdPtr = 0x244;
uint256 constant BasicOrder_additionalRecipients_length_cdPtr = 0x264;
uint256 constant BasicOrder_additionalRecipients_data_cdPtr = 0x284;

uint256 constant BasicOrder_parameters_ptr = 0x20;

uint256 constant BasicOrder_basicOrderType_range = 0x18; // 24 values

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  EIP712 data for ConsiderationItem
 *   - 0x80: ConsiderationItem EIP-712 typehash (constant)
 *   - 0xa0: itemType
 *   - 0xc0: token
 *   - 0xe0: identifier
 *   - 0x100: startAmount
 *   - 0x120: endAmount
 *   - 0x140: recipient
 */
uint256 constant BasicOrder_considerationItem_typeHash_ptr = 0x80; // memoryPtr
uint256 constant BasicOrder_considerationItem_itemType_ptr = 0xa0;
uint256 constant BasicOrder_considerationItem_token_ptr = 0xc0;
uint256 constant BasicOrder_considerationItem_identifier_ptr = 0xe0;
uint256 constant BasicOrder_considerationItem_startAmount_ptr = 0x100;
uint256 constant BasicOrder_considerationItem_endAmount_ptr = 0x120;
// uint256 constant BasicOrder_considerationItem_recipient_ptr = 0x140;

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  EIP712 data for OfferItem
 *   - 0x80:  OfferItem EIP-712 typehash (constant)
 *   - 0xa0:  itemType
 *   - 0xc0:  token
 *   - 0xe0:  identifier (reused for offeredItemsHash)
 *   - 0x100: startAmount
 *   - 0x120: endAmount
 */
uint256 constant BasicOrder_offerItem_typeHash_ptr = DefaultFreeMemoryPointer;
uint256 constant BasicOrder_offerItem_itemType_ptr = 0xa0;
uint256 constant BasicOrder_offerItem_token_ptr = 0xc0;
// uint256 constant BasicOrder_offerItem_identifier_ptr = 0xe0;
// uint256 constant BasicOrder_offerItem_startAmount_ptr = 0x100;
uint256 constant BasicOrder_offerItem_endAmount_ptr = 0x120;

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  EIP712 data for Order
 *   - 0x80:   Order EIP-712 typehash (constant)
 *   - 0xa0:   orderParameters.offerer
 *   - 0xc0:   orderParameters.zone
 *   - 0xe0:   keccak256(abi.encodePacked(offerHashes))
 *   - 0x100:  keccak256(abi.encodePacked(considerationHashes))
 *   - 0x120:  orderType
 *   - 0x140:  startTime
 *   - 0x160:  endTime
 *   - 0x180:  zoneHash
 *   - 0x1a0:  salt
 *   - 0x1c0:  conduit
 *   - 0x1e0:  _counters[orderParameters.offerer] (from storage)
 */
uint256 constant BasicOrder_order_typeHash_ptr = 0x80;
uint256 constant BasicOrder_order_offerer_ptr = 0xa0;
// uint256 constant BasicOrder_order_zone_ptr = 0xc0;
uint256 constant BasicOrder_order_offerHashes_ptr = 0xe0;
uint256 constant BasicOrder_order_considerationHashes_ptr = 0x100;
uint256 constant BasicOrder_order_orderType_ptr = 0x120;
uint256 constant BasicOrder_order_startTime_ptr = 0x140;
// uint256 constant BasicOrder_order_endTime_ptr = 0x160;
// uint256 constant BasicOrder_order_zoneHash_ptr = 0x180;
// uint256 constant BasicOrder_order_salt_ptr = 0x1a0;
// uint256 constant BasicOrder_order_conduitKey_ptr = 0x1c0;
uint256 constant BasicOrder_order_counter_ptr = 0x1e0;
uint256 constant BasicOrder_additionalRecipients_head_ptr = 0x240;
uint256 constant BasicOrder_signature_ptr = 0x260;

// Signature-related
bytes32 constant EIP2098_allButHighestBitMask = (
    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
);
bytes32 constant ECDSA_twentySeventhAndTwentyEighthBytesSet = (
    0x0000000000000000000000000000000000000000000000000000000101000000
);
uint256 constant ECDSA_MaxLength = 65;
uint256 constant ECDSA_signature_s_offset = 0x40;
uint256 constant ECDSA_signature_v_offset = 0x60;

bytes32 constant EIP1271_isValidSignature_selector = (
    0x1626ba7e00000000000000000000000000000000000000000000000000000000
);
uint256 constant EIP1271_isValidSignature_signatureHead_negativeOffset = 0x20;
uint256 constant EIP1271_isValidSignature_digest_negativeOffset = 0x40;
uint256 constant EIP1271_isValidSignature_selector_negativeOffset = 0x44;
uint256 constant EIP1271_isValidSignature_calldata_baseLength = 0x64;

uint256 constant EIP1271_isValidSignature_signature_head_offset = 0x40;

// abi.encodeWithSignature("NoContract(address)")
uint256 constant NoContract_error_signature = (
    0x5f15d67200000000000000000000000000000000000000000000000000000000
);
uint256 constant NoContract_error_sig_ptr = 0x0;
uint256 constant NoContract_error_token_ptr = 0x4;
uint256 constant NoContract_error_length = 0x24; // 4 + 32 == 36

uint256 constant EIP_712_PREFIX = (
    0x1901000000000000000000000000000000000000000000000000000000000000
);

uint256 constant ExtraGasBuffer = 0x20;
uint256 constant CostPerWord = 3;
uint256 constant MemoryExpansionCoefficient = 0x200; // 512

uint256 constant Create2AddressDerivation_ptr = 0x0b;
uint256 constant Create2AddressDerivation_length = 0x55;

uint256 constant MaskOverByteTwelve = (
    0x0000000000000000000000ff0000000000000000000000000000000000000000
);

uint256 constant MaskOverLastTwentyBytes = (
    0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
);

uint256 constant MaskOverFirstFourBytes = (
    0xffffffff00000000000000000000000000000000000000000000000000000000
);

uint256 constant Conduit_execute_signature = (
    0x4ce34aa200000000000000000000000000000000000000000000000000000000
);

uint256 constant MaxUint8 = 0xff;
uint256 constant MaxUint120 = 0xffffffffffffffffffffffffffffff;

uint256 constant Conduit_execute_ConduitTransfer_ptr = 0x20;
uint256 constant Conduit_execute_ConduitTransfer_length = 0x01;

uint256 constant Conduit_execute_ConduitTransfer_offset_ptr = 0x04;
uint256 constant Conduit_execute_ConduitTransfer_length_ptr = 0x24;
uint256 constant Conduit_execute_transferItemType_ptr = 0x44;
uint256 constant Conduit_execute_transferToken_ptr = 0x64;
uint256 constant Conduit_execute_transferFrom_ptr = 0x84;
uint256 constant Conduit_execute_transferTo_ptr = 0xa4;
uint256 constant Conduit_execute_transferIdentifier_ptr = 0xc4;
uint256 constant Conduit_execute_transferAmount_ptr = 0xe4;

uint256 constant OneConduitExecute_size = 0x104;

// Sentinel value to indicate that the conduit accumulator is not armed.
uint256 constant AccumulatorDisarmed = 0x20;
uint256 constant AccumulatorArmed = 0x40;
uint256 constant Accumulator_conduitKey_ptr = 0x20;
uint256 constant Accumulator_selector_ptr = 0x40;
uint256 constant Accumulator_array_offset_ptr = 0x44;
uint256 constant Accumulator_array_length_ptr = 0x64;

uint256 constant Accumulator_itemSizeOffsetDifference = 0x3c;

uint256 constant Accumulator_array_offset = 0x20;
uint256 constant Conduit_transferItem_size = 0xc0;
uint256 constant Conduit_transferItem_token_ptr = 0x20;
uint256 constant Conduit_transferItem_from_ptr = 0x40;
uint256 constant Conduit_transferItem_to_ptr = 0x60;
uint256 constant Conduit_transferItem_identifier_ptr = 0x80;
uint256 constant Conduit_transferItem_amount_ptr = 0xa0;

// Declare constant for errors related to amount derivation.
// error InexactFraction() @ AmountDerivationErrors.sol
uint256 constant InexactFraction_error_signature = (
    0xc63cf08900000000000000000000000000000000000000000000000000000000
);
uint256 constant InexactFraction_error_len = 0x04;

// Declare constant for errors related to signature verification.
uint256 constant Ecrecover_precompile = 1;
uint256 constant Ecrecover_args_size = 0x80;
uint256 constant Signature_lower_v = 27;

// error BadSignatureV(uint8) @ SignatureVerificationErrors.sol
uint256 constant BadSignatureV_error_signature = (
    0x1f003d0a00000000000000000000000000000000000000000000000000000000
);
uint256 constant BadSignatureV_error_offset = 0x04;
uint256 constant BadSignatureV_error_length = 0x24;

// error InvalidSigner() @ SignatureVerificationErrors.sol
uint256 constant InvalidSigner_error_signature = (
    0x815e1d6400000000000000000000000000000000000000000000000000000000
);
uint256 constant InvalidSigner_error_length = 0x04;

// error InvalidSignature() @ SignatureVerificationErrors.sol
uint256 constant InvalidSignature_error_signature = (
    0x8baa579f00000000000000000000000000000000000000000000000000000000
);
uint256 constant InvalidSignature_error_length = 0x04;

// error BadContractSignature() @ SignatureVerificationErrors.sol
uint256 constant BadContractSignature_error_signature = (
    0x4f7fb80d00000000000000000000000000000000000000000000000000000000
);
uint256 constant BadContractSignature_error_length = 0x04;

uint256 constant NumBitsAfterSelector = 0xe0;

// 69 is the lowest modulus for which the remainder
// of every selector other than the two match functions
// is greater than those of the match functions.
uint256 constant NonMatchSelector_MagicModulus = 69;
// Of the two match function selectors, the highest
// remainder modulo 69 is 29.
uint256 constant NonMatchSelector_MagicRemainder = 0x1d;

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1271.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}