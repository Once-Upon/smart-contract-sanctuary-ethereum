// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IFixedPriceSignatureMinter, EditionMintData, MintInfo } from "./interfaces/IFixedPriceSignatureMinter.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/**
 * @title IFixedPriceSignatureMinter
 * @dev Module for fixed-price, signature-authorizd mints of Sound editions.
 * @author Sound.xyz
 */
contract FixedPriceSignatureMinter is IFixedPriceSignatureMinter, BaseMinter {
    using ECDSA for bytes32;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev EIP-712 Typed structured data hash (used for checking signature validity).
     *      https://eips.ethereum.org/EIPS/eip-712
     */
    bytes32 public constant MINT_TYPEHASH =
        keccak256(
            "EditionInfo(address buyer,uint128 mintId,uint32 claimTicket,uint32 quantityLimit,address affiliate)"
        );

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data
     *      `edition` => `mintId` => EditionMintData
     */
    mapping(address => mapping(uint128 => EditionMintData)) internal _editionMintData;

    /**
     * @dev A mapping of bitmaps where each bit represents whether the ticket has been claimed.
     *      `edition` => `mintId` => `index` => bit array
     */
    mapping(address => mapping(uint128 => mapping(uint256 => uint256))) internal _claimsBitmaps;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) public returns (uint128 mintId) {
        if (signer == address(0)) revert SignerIsZeroAddress();
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.signer = signer;
        data.maxMintable = maxMintable;
        // prettier-ignore
        emit FixedPriceSignatureMintCreated(
            edition,
            mintId,
            price,
            signer,
            maxMintable,
            startTime,
            endTime,
            affiliateFeeBPS
        );
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        uint32 signedQuantity,
        address affiliate,
        bytes calldata signature,
        uint32 claimTicket
    ) public payable {
        if (quantity > signedQuantity) revert ExceedsSignedQuantity();

        EditionMintData storage data = _editionMintData[edition][mintId];

        data.totalMinted = _incrementTotalMinted(data.totalMinted, quantity, data.maxMintable);

        _validateSignatureAndClaim(signature, data.signer, claimTicket, edition, mintId, signedQuantity, affiliate);

        _mint(edition, mintId, quantity, affiliate);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        unchecked {
            // Won't overflow, as `price` is 96 bits, and `quantity` is 32 bits.
            return _editionMintData[edition][mintId].price * quantity;
        }
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function mintInfo(address edition, uint128 mintId) public view override returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.mintPaused,
            mintData.price,
            mintData.maxMintable,
            type(uint32).max, // maxMintablePerAccount
            mintData.totalMinted,
            mintData.signer
        );

        return combinedMintData;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IFixedPriceSignatureMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IFixedPriceSignatureMinter).interfaceId;
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function checkClaimTickets(
        address edition,
        uint128 mintId,
        uint32[] calldata claimTickets
    ) external view returns (bool[] memory claimed) {
        claimed = new bool[](claimTickets.length);
        // Will not overflow due to max block gas limit bounding the size of `claimTickets`.
        unchecked {
            for (uint256 i = 0; i < claimTickets.length; i++) {
                (uint256 storedBit, , , ) = _getBitForClaimTicket(edition, mintId, claimTickets[i]);
                claimed[i] = storedBit == 1;
            }
        }
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32 separator) {
        separator = keccak256(
            abi.encode(keccak256("EIP712Domain(uint256 chainId,address edition)"), block.chainid, address(this))
        );
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Validates and claims the signed message required to mint.
     * @param signature      The signed message to authorize the mint.
     * @param expectedSigner The address of the signer that authorizes mints.
     * @param claimTicket    The ticket number to enforce single-use of the signature.
     * @param edition        The edition address.
     * @param mintId         The mint instance ID.
     * @param signedQuantity The max quantity this buyer has been approved to mint.
     * @param affiliate      The affiliate address.
     */
    function _validateSignatureAndClaim(
        bytes calldata signature,
        address expectedSigner,
        uint32 claimTicket,
        address edition,
        uint128 mintId,
        uint32 signedQuantity,
        address affiliate
    ) private {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(MINT_TYPEHASH, msg.sender, mintId, claimTicket, signedQuantity, affiliate))
            )
        );

        if (digest.recover(signature) != expectedSigner) revert InvalidSignature();

        (
            uint256 storedBit,
            uint256 ticketGroup,
            uint256 ticketGroupOffset,
            uint256 ticketGroupIdx
        ) = _getBitForClaimTicket(edition, mintId, claimTicket);

        if (storedBit != 0) revert SignatureAlreadyUsed();

        // Flip the bit to 1 to indicate that the ticket has been claimed
        _claimsBitmaps[edition][mintId][ticketGroupIdx] = ticketGroup | (uint256(1) << ticketGroupOffset);
    }

    /**
     * @dev Gets the bit variables associated with a ticket number
     * @param edition      The edition address.
     * @param mintId       The mint instance ID.
     * @param claimTicket The ticket number.
     * @return ticketGroup       The bit array for this ticket number.
     * @return ticketGroupIdx    The index of the the local group.
     * @return ticketGroupOffset The offset/index for the ticket number in the local group.
     * @return storedBit         The stored bit at this ticket number's index within the local group.
     */
    function _getBitForClaimTicket(
        address edition,
        uint128 mintId,
        uint32 claimTicket
    )
        private
        view
        returns (
            uint256 ticketGroup,
            uint256 ticketGroupIdx,
            uint256 ticketGroupOffset,
            uint256 storedBit
        )
    {
        unchecked {
            ticketGroupIdx = claimTicket >> 8;
            ticketGroupOffset = claimTicket & 255;
        }

        // cache the local group for efficiency
        ticketGroup = _claimsBitmaps[edition][mintId][ticketGroupIdx];

        // gets the stored bit
        storedBit = (ticketGroup >> ticketGroupOffset) & uint256(1);

        return (storedBit, ticketGroup, ticketGroupOffset, ticketGroupIdx);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Gas optimized ECDSA wrapper.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ECDSA.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ECDSA.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol)
library ECDSA {
    function recover(bytes32 hash, bytes calldata signature) internal view returns (address result) {
        assembly {
            if eq(signature.length, 65) {
                // Copy the free memory pointer so that we can restore it later.
                let m := mload(0x40)
                // Directly copy `r` and `s` from the calldata.
                calldatacopy(0x40, signature.offset, 0x40)

                // If `s` in lower half order, such that the signature is not malleable.
                // prettier-ignore
                if iszero(gt(mload(0x60), 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0)) {
                    mstore(0x00, hash)
                    // Compute `v` and store it in the scratch space.
                    mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40))))
                    pop(
                        staticcall(
                            gas(), // Amount of gas left for the transaction.
                            0x01, // Address of `ecrecover`.
                            0x00, // Start of input.
                            0x80, // Size of input.
                            0x40, // Start of output.
                            0x20 // Size of output.
                        )
                    )
                    // Restore the zero slot.
                    mstore(0x60, 0)
                    // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                    result := mload(sub(0x60, returndatasize()))
                }
                // Restore the free memory pointer.
                mstore(0x40, m)
            }
        }
    }

    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal view returns (address result) {
        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)
            // prettier-ignore
            let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

            // If `s` in lower half order, such that the signature is not malleable.
            // prettier-ignore
            if iszero(gt(s, 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0)) {
                mstore(0x00, hash)
                mstore(0x20, add(shr(255, vs), 27))
                mstore(0x40, r)
                mstore(0x60, s)
                pop(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        0x01, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x40, // Start of output.
                        0x20 // Size of output.
                    )
                )
                // Restore the zero slot.
                mstore(0x60, 0)
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                result := mload(sub(0x60, returndatasize()))
            }
            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        assembly {
            // Store into scratch space for keccak256.
            mstore(0x20, hash)
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            // 0x40 - 0x04 = 0x3c
            result := keccak256(0x04, 0x3c)
        }
    }

    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        assembly {
            // We need at most 128 bytes for Ethereum signed message header.
            // The max length of the ASCII reprenstation of a uint256 is 78 bytes.
            // The length of "\x19Ethereum Signed Message:\n" is 26 bytes (i.e. 0x1a).
            // The next multiple of 32 above 78 + 26 is 128 (i.e. 0x80).

            // Instead of allocating, we temporarily copy the 128 bytes before the
            // start of `s` data to some variables.
            let m3 := mload(sub(s, 0x60))
            let m2 := mload(sub(s, 0x40))
            let m1 := mload(sub(s, 0x20))
            // The length of `s` is in bytes.
            let sLength := mload(s)

            let ptr := add(s, 0x20)

            // `end` marks the end of the memory which we will compute the keccak256 of.
            let end := add(ptr, sLength)

            // Convert the length of the bytes to ASCII decimal representation
            // and store it into the memory.
            // prettier-ignore
            for { let temp := sLength } 1 {} {
                ptr := sub(ptr, 1)
                mstore8(ptr, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            // Copy the header over to the memory.
            mstore(sub(ptr, 0x20), "\x00\x00\x00\x00\x00\x00\x19Ethereum Signed Message:\n")
            // Compute the keccak256 of the memory.
            result := keccak256(sub(ptr, 0x1a), sub(end, sub(ptr, 0x1a)))

            // Restore the previous memory.
            mstore(s, sLength)
            mstore(sub(s, 0x20), m1)
            mstore(sub(s, 0x40), m2)
            mstore(sub(s, 0x60), m3)
        }
    }
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title Minter Base
 * @dev The `BaseMinter` class maintains a central storage record of edition mint instances.
 */
abstract contract BaseMinter is IMinterModule {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev This is the denominator, in basis points (BPS), for:
     * - platform fees
     * - affiliate fees
     */
    uint16 private constant _MAX_BPS = 10_000;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The next mint ID. Shared amongst all editions connected.
     */
    uint128 private _nextMintId;

    /**
     * @dev How much platform fees have been accrued.
     */
    uint128 private _platformFeesAccrued;

    /**
     * @dev Maps an edition and the mint ID to a mint instance.
     */
    mapping(address => mapping(uint256 => BaseData)) internal _baseData;

    /**
     * @dev Maps an address to how much affiliate fees have they accrued.
     */
    mapping(address => uint128) private _affiliateFeesAccrued;

    /**
     * @dev The fee registry. Used for handling platform fees.
     */
    ISoundFeeRegistry public immutable feeRegistry;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) {
        if (address(feeRegistry_) == address(0)) revert FeeRegistryIsZeroAddress();
        feeRegistry = feeRegistry_;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function setEditionMintPaused(
        address edition,
        uint128 mintId,
        bool paused
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _baseData[edition][mintId].mintPaused = paused;
        emit MintPausedSet(edition, mintId, paused);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _setTimeRange(edition, mintId, startTime, endTime);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function setAffiliateFee(
        address edition,
        uint128 mintId,
        uint16 feeBPS
    ) public virtual override onlyEditionOwnerOrAdmin(edition) onlyValidAffiliateFeeBPS(feeBPS) {
        _baseData[edition][mintId].affiliateFeeBPS = feeBPS;
        emit AffiliateFeeSet(edition, mintId, feeBPS);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForAffiliate(address affiliate) public override {
        uint256 accrued = _affiliateFeesAccrued[affiliate];
        if (accrued != 0) {
            _affiliateFeesAccrued[affiliate] = 0;
            SafeTransferLib.safeTransferETH(affiliate, accrued);
        }
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForPlatform() public override {
        uint256 accrued = _platformFeesAccrued;
        if (accrued != 0) {
            _platformFeesAccrued = 0;
            SafeTransferLib.safeTransferETH(feeRegistry.soundFeeAddress(), accrued);
        }
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Getter for the max basis points.
     */
    function MAX_BPS() external pure returns (uint16) {
        return _MAX_BPS;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function affiliateFeesAccrued(address affiliate) external view returns (uint128) {
        return _affiliateFeesAccrued[affiliate];
    }

    /**
     * @inheritdoc IMinterModule
     */
    function platformFeesAccrued() external view returns (uint128) {
        return _platformFeesAccrued;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function isAffiliated(
        address, /* edition */
        uint128, /* mintId */
        address affiliate
    ) public view virtual override returns (bool) {
        return affiliate != address(0);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function nextMintId() public view returns (uint128) {
        return _nextMintId;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IMinterModule).interfaceId || interfaceId == this.supportsInterface.selector;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address minter,
        uint32 quantity
    ) public view virtual override returns (uint128);

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Restricts the function to be only callable by the owner or admin of `edition`.
     * @param edition The edition address.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) virtual {
        if (
            msg.sender != OwnableRoles(edition).owner() &&
            !OwnableRoles(edition).hasAnyRole(msg.sender, ISoundEditionV1(edition).ADMIN_ROLE())
        ) revert Unauthorized();

        _;
    }

    /**
     * @dev Restricts the start time to be less than the end time.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    modifier onlyValidTimeRange(uint32 startTime, uint32 endTime) virtual {
        if (startTime >= endTime) revert InvalidTimeRange();
        _;
    }

    /**
     * @dev Restricts the affiliate fee numerator to not excced the `MAX_BPS`.
     */
    modifier onlyValidAffiliateFeeBPS(uint16 affiliateFeeBPS) virtual {
        if (affiliateFeeBPS > _MAX_BPS) revert InvalidAffiliateFeeBPS();
        _;
    }

    /**
     * @dev Creates an edition mint instance.
     * @param edition The edition address.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @return mintId The ID for the mint instance.
     * Calling conditions:
     * - Must be owner or admin of the edition.
     */
    function _createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    )
        internal
        onlyEditionOwnerOrAdmin(edition)
        onlyValidTimeRange(startTime, endTime)
        onlyValidAffiliateFeeBPS(affiliateFeeBPS)
        returns (uint128 mintId)
    {
        mintId = _nextMintId;

        BaseData storage data = _baseData[edition][mintId];
        data.startTime = startTime;
        data.endTime = endTime;
        data.affiliateFeeBPS = affiliateFeeBPS;

        _nextMintId = mintId + 1;

        emit MintConfigCreated(edition, msg.sender, mintId, startTime, endTime, affiliateFeeBPS);
    }

    /**
     * @dev Sets the time range for an edition mint.
     * Note: If calling from a child contract, the child is responsible for access control.
     * @param edition The edition address.
     * @param mintId The ID for the mint instance.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    function _setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) internal onlyValidTimeRange(startTime, endTime) {
        _baseData[edition][mintId].startTime = startTime;
        _baseData[edition][mintId].endTime = endTime;

        emit TimeRangeSet(edition, mintId, startTime, endTime);
    }

    /**
     * @dev Mints `quantity` of `edition` to `to` with a required payment of `requiredEtherValue`.
     * Note: this function should be called at the end of a function due to it refunding any
     * excess ether paid, to adhere to the checks-effects-interactions pattern.
     * Otherwise, a reentrancy guard must be used.
     * @param edition The edition address.
     * @param mintId The ID for the mint instance.
     * @param quantity The quantity of tokens to mint.
     * @param affiliate The affiliate (referral) address.
     */
    function _mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) internal {
        BaseData storage baseData = _baseData[edition][mintId];

        /* --------------------- GENERAL CHECKS --------------------- */

        uint32 startTime = baseData.startTime;
        uint32 endTime = baseData.endTime;
        if (block.timestamp < startTime) revert MintNotOpen(block.timestamp, startTime, endTime);
        if (block.timestamp > endTime) revert MintNotOpen(block.timestamp, startTime, endTime);
        if (baseData.mintPaused) revert MintPaused();

        /* ----------- AFFILIATE AND PLATFORM FEES LOGIC ------------ */

        uint128 requiredEtherValue = totalPrice(edition, mintId, msg.sender, quantity);

        // Reverts if the payment is not exact.
        if (msg.value < requiredEtherValue) revert Underpaid(msg.value, requiredEtherValue);

        uint128 remainingPayment = _deductPlatformFee(requiredEtherValue);

        // Check if the mint is an affiliated mint.
        bool affiliated = isAffiliated(edition, mintId, affiliate);
        uint128 affiliateFee;
        unchecked {
            if (affiliated) {
                // Compute the affiliate fee.
                // Won't overflow, as `remainingPayment` is 128 bits, and `affiliateFeeBPS` is 16 bits.
                affiliateFee = (remainingPayment * baseData.affiliateFeeBPS) / _MAX_BPS;
                // Deduct the affiliate fee from the remaining payment.
                // Won't underflow as `affiliateFee <= remainingPayment`.
                remainingPayment -= affiliateFee;
                // Increment the affiliate fees accrued.
                // Overflow is incredibly unrealistic.
                _affiliateFeesAccrued[affiliate] += affiliateFee;
            }
        }

        /* ------------------------- MINT --------------------------- */

        uint32 fromTokenId = uint32(ISoundEditionV1(edition).mint{ value: remainingPayment }(msg.sender, quantity));

        if (affiliated) {
            // Emit the event.
            emit MintedWithAffiliate(edition, mintId, fromTokenId, quantity, affiliateFee, affiliate);
        }

        /* ------------------------- REFUND ------------------------- */

        unchecked {
            // Note: We do this at the end to avoid creating a reentrancy vector.
            // Refund the user any ETH they spent over the current total price of the NFTs.
            if (msg.value > requiredEtherValue) {
                SafeTransferLib.safeTransferETH(msg.sender, msg.value - requiredEtherValue);
            }
        }
    }

    /**
     * @dev Deducts the platform fee from `requiredEtherValue`.
     * @param requiredEtherValue The amount of Ether required.
     * @return remainingPayment The remaining payment Ether amount.
     */
    function _deductPlatformFee(uint128 requiredEtherValue) internal returns (uint128 remainingPayment) {
        unchecked {
            // Compute the platform fee.
            uint128 platformFee = feeRegistry.platformFee(requiredEtherValue);
            // Increment the platform fees accrued.
            // Overflow is incredibly unrealistic.
            _platformFeesAccrued += platformFee;
            // Deduct the platform fee.
            // Won't underflow as `platformFee <= requiredEtherValue`;
            remainingPayment = requiredEtherValue - platformFee;
        }
    }

    /**
     * @dev Increments `totalMinted` with `quantity`, reverting if `totalMinted + quantity > maxMintable`.
     * @param totalMinted The current total number of minted tokens.
     * @param maxMintable The maximum number of mintable tokens.
     * @return `totalMinted` + `quantity`.
     */
    function _incrementTotalMinted(
        uint32 totalMinted,
        uint32 quantity,
        uint32 maxMintable
    ) internal pure returns (uint32) {
        unchecked {
            // Won't overflow as both are 32 bits.
            uint256 sum = uint256(totalMinted) + uint256(quantity);
            if (sum > maxMintable) {
                uint32 available;
                // Note that the `maxMintable` may vary and drop over time
                // and cause `totalMinted` to be greater than `maxMintable`.
                if (maxMintable > totalMinted) {
                    available = maxMintable - totalMinted;
                }
                revert ExceedsAvailableSupply(available);
            }
            return uint32(sum);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a fixed-price signature mint.
 */
struct EditionMintData {
    // The price at which each token will be sold, in ETH.
    uint96 price;
    // Whitelist signer address.
    address signer;
    // The maximum number of tokens that can can be minted for this sale.
    uint32 maxMintable;
    // The total number of tokens minted so far for this sale.
    uint32 totalMinted;
}

/**
 * @dev All the information about a fixed-price signature mint (combines EditionMintData with BaseData).
 */
struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 price;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    address signer;
}

/**
 * @title IFixedPriceSignatureMinter
 * @dev Interface for the `FixedPriceSignatureMinter` module.
 * @author Sound.xyz
 */
interface IFixedPriceSignatureMinter is IMinterModule {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a new fixed price signature mint is created.
     * @param edition         The edition address.
     * @param mintId          The mint ID.
     * @param signer          The address of the signer that authorizes mints.
     * @param maxMintable     The maximum number of tokens that can be minted.
     * @param startTime       The time minting can begin.
     * @param endTime         The time minting will end.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     */
    event FixedPriceSignatureMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        address signer,
        uint32 maxMintable,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    );

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Cannot mint more than the signed quantity.
     */
    error ExceedsSignedQuantity();

    /**
     * @dev The signature is invalid.
     */
    error InvalidSignature();

    /**
     * @dev The mint sigature can only be used a single time.
     */
    error SignatureAlreadyUsed();

    /**
     * @dev The signer can't be the zero address.
     */
    error SignerIsZeroAddress();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Initializes a fixed-price signature mint instance.
     * @param edition         The edition address.
     * @param price           The price to mint a token.
     * @param signer          The address of the signer that authorizes mints.
     * @param maxMintable_    The maximum number of tokens that can be minted.
     * @param startTime       The time minting can begin.
     * @param endTime         The time minting will end.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @return mintId         The ID of the new mint instance.
     */
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) external returns (uint128 mintId);

    /**
     * @dev Mints a token for a particular mint instance.
     * @param mintId         The mint ID.
     * @param quantity       The quantity of tokens to mint.
     * @param signedQuantity The max quantity this buyer has been approved to mint.
     * @param affiliate      The affiliate address.
     * @param signature      The signed message to authorize the mint.
     * @param claimTicket    The ticket number to enforce single-use of the signature.
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        uint32 signedQuantity,
        address affiliate,
        bytes calldata signature,
        uint32 claimTicket
    ) external payable;

    // =============================================================
    //               PUBLIC / EXTERNAL READ FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the EIP-712 type hash of the signature for minting.
     * @return typeHash The constant value.
     */
    function MINT_TYPEHASH() external view returns (bytes32 typeHash);

    /**
     * @dev Returns IFixedPriceSignatureMinter.MintInfo instance containing the full minter parameter set.
     * @param edition   The edition to get the mint instance for.
     * @param mintId    The ID of the mint instance.
     * @return Information about this mint.
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory);

    /**
     * @dev Returns an array of booleans on whether each claim ticket has been claimed.
     * @param edition      The edition to get the mint instance for.
     * @param mintId       The ID of the mint instance.
     * @param claimTickets The claim tickets to check.
     * @return claimed The computed values.
     */
    function checkClaimTickets(
        address edition,
        uint128 mintId,
        uint32[] calldata claimTickets
    ) external view returns (bool[] memory claimed);

    /**
     * @dev Returns the EIP-712 domain separator of the signature for minting.
     * @return separator The constant value.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32 separator);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

/**
 * @title ISoundFeeRegistry
 * @author Sound.xyz
 */
interface ISoundFeeRegistry {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the `soundFeeAddress` is changed.
     */
    event SoundFeeAddressSet(address soundFeeAddress);

    /**
     * @dev Emitted when the `platformFeeBPS` is changed.
     */
    event PlatformFeeSet(uint16 platformFeeBPS);

    // =============================================================
    //                             ERRORS
    // =============================================================

    /**
     * @dev The sound fee address must not be address(0).
     */
    error InvalidSoundFeeAddress();

    /**
     * @dev The platform fee numerator must not exceed `_MAX_BPS`.
     */
    error InvalidPlatformFeeBPS();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Sets the `soundFeeAddress`.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param soundFeeAddress_ The sound fee address.
     */
    function setSoundFeeAddress(address soundFeeAddress_) external;

    /**
     * @dev Sets the `platformFeePBS`.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param platformFeeBPS_ Platform fee amount in bps (basis points).
     */
    function setPlatformFeeBPS(uint16 platformFeeBPS_) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev The sound protocol's address that receives platform fees.
     * @return The configured value.
     */
    function soundFeeAddress() external view returns (address);

    /**
     * @dev The numerator of the platform fee.
     * @return The configured value.
     */
    function platformFeeBPS() external view returns (uint16);

    /**
     * @dev The platform fee for `requiredEtherValue`.
     * @param requiredEtherValue The required Ether value for payment.
     * @return fee The computed value.
     */
    function platformFee(uint128 requiredEtherValue) external view returns (uint128 fee);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundFeeRegistry } from "./ISoundFeeRegistry.sol";

/**
 * @title IMinterModule
 * @notice The interface for Sound protocol minter modules.
 */
interface IMinterModule is IERC165 {
    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct BaseData {
        // The start unix timestamp of the mint.
        uint32 startTime;
        // The end unix timestamp of the mint.
        uint32 endTime;
        // The affiliate fee in basis points.
        uint16 affiliateFeeBPS;
        // Whether the mint is paused.
        bool mintPaused;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the mint instance for an `edition` is created.
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     */
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    );

    /**
     * @dev Emitted when the `paused` status of `edition` is updated.
     * @param edition The edition address.
     * @param mintId  The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param paused  The new paused status.
     */
    event MintPausedSet(address indexed edition, uint128 mintId, bool paused);

    /**
     * @dev Emitted when the `paused` status of `edition` is updated.
     * @param edition   The edition address.
     * @param mintId    The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param startTime The start time of the mint.
     * @param endTime   The end time of the mint.
     */
    event TimeRangeSet(address indexed edition, uint128 indexed mintId, uint32 startTime, uint32 endTime);

    /**
     * @notice Emitted when the `affiliateFeeBPS` is updated.
     * @param edition The edition address.
     * @param mintId  The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param bps     The affiliate fee basis points.
     */
    event AffiliateFeeSet(address indexed edition, uint128 indexed mintId, uint16 bps);

    /**
     * @notice Emitted when a mint with an affiliate happens.
     * @param edition      The edition address.
     * @param mintId       The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param fromTokenId  The first token ID of the batch.
     * @param quantity     The size of the batch.
     * @param affiliateFee The cut paid to the affiliate.
     * @param affiliate    The affiliate's address.
     */
    event MintedWithAffiliate(
        address indexed edition,
        uint128 indexed mintId,
        uint32 fromTokenId,
        uint32 quantity,
        uint128 affiliateFee,
        address affiliate
    );

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The Ether value paid is below the value required.
     * @param paid The amount sent to the contract.
     * @param required The amount required to mint.
     */
    error Underpaid(uint256 paid, uint256 required);

    /**
     * @dev The number minted has exceeded the max mintable amount.
     * @param available The number of tokens remaining available for mint.
     */
    error ExceedsAvailableSupply(uint32 available);

    /**
     * @dev The mint is not opened.
     * @param blockTimestamp The current block timestamp.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /**
     * @dev The mint is paused.
     */
    error MintPaused();

    /**
     * @dev The `startTime` is not less than the `endTime`.
     */
    error InvalidTimeRange();

    /**
     * @dev Unauthorized caller
     */
    error Unauthorized();

    /**
     * @dev The affiliate fee numerator must not exceed `MAX_BPS`.
     */
    error InvalidAffiliateFeeBPS();

    /**
     * @dev Fee registry cannot be the zero address.
     */
    error FeeRegistryIsZeroAddress();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Sets the paused status for (`edition`, `mintId`).
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     */
    function setEditionMintPaused(
        address edition,
        uint128 mintId,
        bool paused
    ) external;

    /**
     * @dev Sets the time range for an edition mint.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) external;

    /**
     * @dev Sets the affiliate fee for (`edition`, `mintId`).
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     */
    function setAffiliateFee(
        address edition,
        uint128 mintId,
        uint16 affiliateFeeBPS
    ) external;

    /**
     * @dev Withdraws all the accrued fees for `affiliate`.
     */
    function withdrawForAffiliate(address affiliate) external;

    /**
     * @dev Withdraws all the accrued fees for the platform.
     */
    function withdrawForPlatform() external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev The total fees accrued for `affiliate`.
     * @param affiliate The affiliate's address.
     * @return The latest value.
     */
    function affiliateFeesAccrued(address affiliate) external view returns (uint128);

    /**
     * @dev The total fees accrued for the platform.
     * @return The latest value.
     */
    function platformFeesAccrued() external view returns (uint128);

    /**
     * @dev Whether `affiliate` is affiliated for (`edition`, `mintId`).
     * @param edition   The edition's address.
     * @param mintId    The mint ID.
     * @param affiliate The affiliate's address.
     * @return The computed value.
     */
    function isAffiliated(
        address edition,
        uint128 mintId,
        address affiliate
    ) external view returns (bool);

    /**
     * @dev The total price for `quantity` tokens for (`edition`, `mintId`).
     * @param edition   The edition's address.
     * @param mintId    The mint ID.
     * @param mintId    The minter's address.
     * @param quantity  The number of tokens to mint.
     * @return The computed value.
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address minter,
        uint32 quantity
    ) external view returns (uint128);

    /**
     * @dev The next mint ID.
     *      A mint ID is assigned sequentially starting from (0, 1, 2, ...),
     *      and is shared amongst all editions connected to the minter contract.
     * @return The latest value.
     */
    function nextMintId() external view returns (uint128);

    /**
     * @dev The interface ID of the minter.
     * @return The constant value.
     */
    function moduleInterfaceId() external view returns (bytes4);

    /**
     * @dev The fee registry. Used for handling platform fees.
     * @return The immutable value.
     */
    function feeRegistry() external view returns (ISoundFeeRegistry);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { IERC165Upgradeable } from "openzeppelin-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import { IMetadataModule } from "./IMetadataModule.sol";

/**
 * @title ISoundEditionV1
 * @notice The interface for Sound edition contracts.
 */
interface ISoundEditionV1 is IERC721AUpgradeable, IERC2981Upgradeable {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the metadata module is set.
     * @param metadataModule the address of the metadata module.
     */
    event MetadataModuleSet(IMetadataModule metadataModule);

    /**
     * @dev Emitted when the `baseURI` is set.
     * @param baseURI the base URI of the edition.
     */
    event BaseURISet(string baseURI);

    /**
     * @dev Emitted when the `contractURI` is set.
     * @param contractURI The contract URI of the edition.
     */
    event ContractURISet(string contractURI);

    /**
     * @dev Emitted when the metadata is frozen (e.g.: `baseURI` can no longer be changed).
     * @param metadataModule The address of the metadata module.
     * @param baseURI        The base URI of the edition.
     * @param contractURI    The contract URI of the edition.
     */
    event MetadataFrozen(IMetadataModule metadataModule, string baseURI, string contractURI);

    /**
     * @dev Emitted when the `fundingRecipient` is set.
     * @param fundingRecipient The address of the funding recipient.
     */
    event FundingRecipientSet(address fundingRecipient);

    /**
     * @dev Emitted when the `royaltyBPS` is set.
     * @param bps The new royalty, measured in basis points.
     */
    event RoyaltySet(uint16 bps);

    /**
     * @dev Emitted when the edition's maximum mintable token quantity is set.
     * @param newMax The new maximum mintable token quantity.
     */
    event EditionMaxMintableSet(uint32 newMax);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The edition's metadata is frozen (e.g.: `baseURI` can no longer be changed).
     */
    error MetadataIsFrozen();

    /**
     * @dev The given `royaltyBPS` is invalid.
     */
    error InvalidRoyaltyBPS();

    /**
     * @dev The given `randomnessLockedAfterMinted` value is invalid.
     */
    error InvalidRandomnessLock();

    /**
     * @dev The requested quantity exceeds the edition's remaining mintable token quantity.
     * @param available The number of tokens remaining available for mint.
     */
    error ExceedsEditionAvailableSupply(uint32 available);

    /**
     * @dev The given amount is invalid.
     */
    error InvalidAmount();

    /**
     * @dev The given `fundingRecipient` address is invalid.
     */
    error InvalidFundingRecipient();

    /**
     * @dev The `editionMaxMintable` has already been reached.
     */
    error MaximumHasAlreadyBeenReached();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Initializes the contract.
     * @param name_                         Name of the collection.
     * @param symbol_                       Symbol of the collection.
     * @param metadataModule_               Address of metadata module, address(0x00) if not used.
     * @param baseURI_                      Base URI.
     * @param contractURI_                  Contract URI for OpenSea storefront.
     * @param fundingRecipient_             Address that receives primary and secondary royalties.
     * @param royaltyBPS_                   Royalty amount in bps (basis points).
     * @param editionMaxMintable_           The maximum amount of tokens mintable for this edition.
     * @param mintRandomnessTokenThreshold_ Token supply after which randomness gets locked.
     * @param mintRandomnessTimeThreshold_  Timestamp after which randomness gets locked.
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        IMetadataModule metadataModule_,
        string memory baseURI_,
        string memory contractURI_,
        address fundingRecipient_,
        uint16 royaltyBPS_,
        uint32 editionMaxMintable_,
        uint32 mintRandomnessTokenThreshold_,
        uint32 mintRandomnessTimeThreshold_
    ) external;

    /**
     * @dev Mints `quantity` tokens to addrress `to`
     *      Each token will be assigned a token ID that is consecutively increasing.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have either the
     *   `ADMIN_ROLE`, `MINTER_ROLE`, which can be granted via {grantRole}.
     *   Multiple minters, such as different minter contracts,
     *   can be authorized simultaneously.
     *
     * @param to       Address to mint to.
     * @param quantity Number of tokens to mint.
     * @return fromTokenId The first token ID minted.
     */
    function mint(address to, uint256 quantity) external payable returns (uint256 fromTokenId);

    /**
     * @dev Withdraws collected ETH royalties to the fundingRecipient
     */
    function withdrawETH() external;

    /**
     * @dev Withdraws collected ERC20 royalties to the fundingRecipient
     * @param tokens array of ERC20 tokens to withdraw
     */
    function withdrawERC20(address[] calldata tokens) external;

    /**
     * @dev Sets metadata module.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param metadataModule Address of metadata module.
     */
    function setMetadataModule(IMetadataModule metadataModule) external;

    /**
     * @dev Sets global base URI.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param baseURI The base URI to be set.
     */
    function setBaseURI(string memory baseURI) external;

    /**
     * @dev Sets contract URI.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param contractURI The contract URI to be set.
     */
    function setContractURI(string memory contractURI) external;

    /**
     * @dev Freezes metadata by preventing any more changes to base URI.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     */
    function freezeMetadata() external;

    /**
     * @dev Sets funding recipient address.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param fundingRecipient Address to be set as the new funding recipient.
     */
    function setFundingRecipient(address fundingRecipient) external;

    /**
     * @dev Sets royalty amount in bps (basis points).
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param bps The new royalty basis points to be set.
     */
    function setRoyalty(uint16 bps) external;

    /**
     * @dev Reduces the maximum mintable quantity for the edition.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param newMax The maximum mintable quantity to be set.
     */
    function reduceEditionMaxMintable(uint32 newMax) external;

    /**
     * @dev Sets a minted token count, after which `mintRandomness` gets locked.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param mintRandomnessTokenThreshold The token quantity to be set.
     */
    function setMintRandomnessLock(uint32 mintRandomnessTokenThreshold) external;

    /**
     * @dev Sets the timestamp, after which `mintRandomness` gets locked.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param mintRandomnessTimeThreshold_ The randomness timestamp to be set.
     */
    function setRandomnessLockedTimestamp(uint32 mintRandomnessTimeThreshold_) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the minter role flag.
     * @return The constant value.
     */
    function MINTER_ROLE() external view returns (uint256);

    /**
     * @dev Returns the admin role flag.
     * @return The constant value.
     */
    function ADMIN_ROLE() external view returns (uint256);

    /**
     * @dev Returns the base token URI for the collection.
     * @return The configured value.
     */
    function baseURI() external view returns (string memory);

    /**
     * @dev Returns the contract URI to be used by Opensea.
     *      See: https://docs.opensea.io/docs/contract-level-metadata
     * @return The configured value.
     */
    function contractURI() external view returns (string memory);

    /**
     * @dev Returns the address of the funding recipient.
     * @return The configured value.
     */
    function fundingRecipient() external view returns (address);

    /**
     * @dev Returns the maximum amount of tokens mintable for this edition.
     * @return The configured value.
     */
    function editionMaxMintable() external view returns (uint32);

    /**
     * @dev Returns the token count after which randomness gets locked.
     * @return The configured value.
     */
    function mintRandomnessTokenThreshold() external view returns (uint32);

    /**
     * @dev Returns the timestamp after which randomness gets locked.
     * @return The configured value.
     */
    function mintRandomnessTimeThreshold() external view returns (uint32);

    /**
     * @dev Returns the address of the metadata module.
     * @return The configured value.
     */
    function metadataModule() external view returns (IMetadataModule);

    /**
     * @dev Returns the randomness based on latest block hash, which is stored upon each mint
     *      unless `randomnessLockedAfterMinted` or `randomnessLockedTimestamp`
     *      have been surpassed.
     *      Used for game mechanics like the Sound Golden Egg.
     * @return The latest value.
     */
    function mintRandomness() external view returns (bytes9);

    /**
     * @dev Returns the royalty basis points.
     * @return The configured value.
     */
    function royaltyBPS() external view returns (uint16);

    /**
     * @dev Returns whether the metadata module is frozen.
     * @return The configured value.
     */
    function isMetadataFrozen() external view returns (bool);

    /**
     * @dev Returns the next token ID to be minted.
     * @return The latest value.
     */
    function nextTokenId() external view returns (uint256);

    /**
     * @dev Returns the total amount of tokens minted.
     * @return The latest value.
     */
    function totalMinted() external view returns (uint256);

    /**
     * @dev Informs other contracts which interfaces this contract supports.
     *      Required by https://eips.ethereum.org/EIPS/eip-165
     * @param interfaceId The interface id to check.
     * @return Whether the `interfaceId` is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override(IERC721AUpgradeable, IERC165Upgradeable)
        returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple single owner and multiroles authorization mixin.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/auth/OwnableRoles.sol)
/// @dev While the ownable portion follows [EIP-173](https://eips.ethereum.org/EIPS/eip-173)
/// for compatibility, the nomenclature for the 2-step ownership handover and roles
/// may be unique to this codebase.
abstract contract OwnableRoles {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The `newOwner` cannot be the zero address.
    error NewOwnerIsZeroAddress();

    /// @dev `bytes4(keccak256(bytes("Unauthorized()")))`.
    uint256 private constant _UNAUTHORIZED_ERROR_SELECTOR = 0x82b42900;

    /// @dev `bytes4(keccak256(bytes("NewOwnerIsZeroAddress()")))`.
    uint256 private constant _NEW_OWNER_IS_ZERO_ADDRESS_ERROR_SELECTOR = 0x7448fbae;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ownership is transferred from `oldOwner` to `newOwner`.
    /// This event is intentionally kept the same as OpenZeppelin's Ownable to be
    /// compatible with indexers and [EIP-173](https://eips.ethereum.org/EIPS/eip-173),
    /// despite it not being as lightweight as a single argument event.
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /// @dev An ownership handover to `newOwner` is proposed.
    event OwnershipHandoverProposed(address indexed newOwner);

    /// @dev The ownership handover is cancelled.
    event OwnershipHandoverCanceled();

    /// @dev The `user`'s roles is updated to `roles`.
    /// Each bit of `roles` represents whether the role is set.
    event RolesUpdated(address indexed user, uint256 indexed roles);

    /// @dev `keccak256(bytes("OwnershipTransferred(address,address)"))`.
    uint256 private constant _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE =
        0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;

    /// @dev `keccak256(bytes("OwnershipHandoverProposed(address)"))`.
    uint256 private constant _OWNERSHIP_HANDOVER_PROPOSED_EVENT_SIGNATURE =
        0xbddead5759d93d1c80803f9e8dcce528b941a7cdbf365abc5ad97e8743460d17;

    /// @dev `keccak256(bytes("OwnershipHandoverCanceled()"))`.
    uint256 private constant _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE =
        0x8422bba0a447c9e0309f7f8ab02fe9cc65654c78bb03841856db33a0536c524c;

    /// @dev `keccak256(bytes("RolesUpdated(address,uint256)"))`.
    uint256 private constant _ROLES_UPDATED_EVENT_SIGNATURE =
        0x715ad5ce61fc9595c7b415289d59cf203f23a94fa06f04af7e489a0a76e1fe26;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The owner slot is given by: `not(_OWNER_SLOT_NOT)`.
    /// It is intentionally choosen to be a high value
    /// to avoid collision with lower slots.
    /// The choice of manual storage layout is to enable compatibility
    /// with both regular and upgradeable contracts.
    ///
    /// The handover receipient slot is given by: `add(not(_OWNER_SLOT_NOT), 1)`.
    ///
    /// The role slot of `user` is given by:
    /// ```
    ///     mstore(0x00, or(shl(96, user), _OWNER_SLOT_NOT))
    ///     let roleSlot := keccak256(0x00, 0x20)
    /// ```
    /// This automatically ignores the upper bits of the `user` in case
    /// they are not clean, as well as keep the `keccak256` under 32-bytes.
    uint256 private constant _OWNER_SLOT_NOT = 0x8b78c6d8;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Initializes the owner directly without authorization guard.
    /// This function must be called upon initialization,
    /// regardless of whether the contract is upgradeable or not.
    /// This is to enable generalization to both regular and upgradeable contracts,
    /// and to save gas in case the initial owner is not the caller.
    /// For performance reasons, this function will not check if there
    /// is an existing owner.
    function _initializeOwner(address newOwner) internal virtual {
        assembly {
            // Clean the upper 96 bits.
            newOwner := shr(96, shl(96, newOwner))
            // Store the new value.
            sstore(not(_OWNER_SLOT_NOT), newOwner)
            // Emit the {OwnershipTransferred} event.
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newOwner)
        }
    }

    /// @dev Sets the owner directly without authorization guard.
    function _setOwner(address newOwner) internal virtual {
        assembly {
            let ownerSlot := not(_OWNER_SLOT_NOT)
            // Clean the upper 96 bits.
            newOwner := shr(96, shl(96, newOwner))
            // Emit the {OwnershipTransferred} event.
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(ownerSlot), newOwner)
            // Store the new value.
            sstore(ownerSlot, newOwner)
        }
    }

    /// @dev Grants the roles directly without authorization guard.
    /// Each bit of `roles` represents the role to turn on.
    function _grantRoles(address user, uint256 roles) internal virtual {
        assembly {
            // Clean the upper 96 bits, but don't shift it back yet.
            user := shl(96, user)
            // Compute the role slot.
            mstore(0x00, or(user, _OWNER_SLOT_NOT))
            let roleSlot := keccak256(0x00, 0x20)
            // Load the current value and `or` it with `roles`.
            let newRoles := or(sload(roleSlot), roles)
            // Store the new value.
            sstore(roleSlot, newRoles)
            // Emit the {RolesUpdated} event.
            log3(0, 0, _ROLES_UPDATED_EVENT_SIGNATURE, shr(96, user), newRoles)
        }
    }

    /// @dev Removes the roles directly without authorization guard.
    /// Each bit of `roles` represents the role to turn off.
    function _removeRoles(address user, uint256 roles) internal virtual {
        assembly {
            // Clean the upper 96 bits, but don't shift it back yet.
            user := shl(96, user)
            // Compute the role slot.
            mstore(0x00, or(user, _OWNER_SLOT_NOT))
            let roleSlot := keccak256(0x00, 0x20)
            // Load the current value.
            let currentRoles := sload(roleSlot)
            // Use `and` to compute the intersection of `currentRoles` and `roles`,
            // `xor` it with `currentRoles` to flip the bits in the intersection.
            let newRoles := xor(currentRoles, and(currentRoles, roles))
            // Then, store the new value.
            sstore(roleSlot, newRoles)
            // Emit the {RolesUpdated} event.
            log3(0, 0, _ROLES_UPDATED_EVENT_SIGNATURE, shr(96, user), newRoles)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  PUBLIC UPDATE FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Allows the owner to transfer the ownership to `newOwner`.
    function transferOwnership(address newOwner) public virtual onlyOwner {
        assembly {
            // Clean the upper 96 bits.
            newOwner := shr(96, shl(96, newOwner))
            // Reverts if the `newOwner` is the zero address.
            if iszero(newOwner) {
                mstore(0x00, _NEW_OWNER_IS_ZERO_ADDRESS_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Emit the {OwnershipTransferred} event.
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, caller(), newOwner)
            // Store the new value.
            sstore(not(_OWNER_SLOT_NOT), newOwner)
        }
    }

    /// @dev Allows the owner to renounce their ownership.
    function renounceOwnership() public virtual onlyOwner {
        assembly {
            // Emit the {OwnershipTransferred} event.
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, caller(), 0)
            // Store the new value.
            sstore(not(_OWNER_SLOT_NOT), 0)
        }
    }

    /// @dev Initiates a two step ownership transfer.
    /// Only one proposal can be active at once.
    /// If there is an existing active ownership handover, it will be overwritten.
    function proposeOwnershipHandover(address newOwner) public virtual onlyOwner {
        assembly {
            // Clean the upper 96 bits.
            newOwner := shr(96, shl(96, newOwner))
            // Reverts if the `newOwner` is the zero address.
            if iszero(newOwner) {
                mstore(0x00, _NEW_OWNER_IS_ZERO_ADDRESS_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Store the `newOwner` in the proposal slot.
            sstore(add(not(_OWNER_SLOT_NOT), 1), newOwner)
            // Emit the {OwnershipHandoverProposed} event.
            log2(0, 0, _OWNERSHIP_HANDOVER_PROPOSED_EVENT_SIGNATURE, newOwner)
        }
    }

    /// @dev Cancels a two step ownership transfer.
    /// Cancel the pending ownership handover, if any.
    function cancelOwnershipHandover() public virtual onlyOwner {
        assembly {
            sstore(add(not(_OWNER_SLOT_NOT), 1), 0)
            // Emit the {OwnershipHandoverCanceled} event.
            log1(0, 0, _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE)
        }
    }

    /// @dev Receive a two step ownership transfer.
    /// It will close the handover upon success.
    function receiveOwnershipHandover() public virtual {
        assembly {
            let ownerSlot := not(_OWNER_SLOT_NOT)
            // If the caller is not the handover receipient.
            if iszero(eq(caller(), sload(add(ownerSlot, 1)))) {
                mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
            sstore(add(ownerSlot, 1), 0)
            // Emit the {OwnershipTransferred} event.
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(ownerSlot), caller())
            // Store the caller as the new owner.
            sstore(ownerSlot, caller())
        }
    }

    /// @dev Allows the owner to grant `user` `roles`.
    /// If the `user` already has a role, then it will be an no-op for the role.
    function grantRoles(address user, uint256 roles) public virtual onlyOwner {
        _grantRoles(user, roles);
    }

    /// @dev Allows the owner to remove `user` `roles`.
    /// If the `user` does not have a role, then it will be an no-op for the role.
    function revokeRoles(address user, uint256 roles) public virtual onlyOwner {
        _removeRoles(user, roles);
    }

    /// @dev Allow the caller to remove their own roles.
    /// If the caller does not have a role, then it will be an no-op for the role.
    function renounceRoles(uint256 roles) public virtual {
        _removeRoles(msg.sender, roles);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PUBLIC READ FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the owner of the contract.
    function owner() public view virtual returns (address result) {
        assembly {
            result := sload(not(_OWNER_SLOT_NOT))
        }
    }

    /// @dev Returns the receiver of the current ownership handover, if any.
    function ownershipHandoverReceiver() public view virtual returns (address result) {
        assembly {
            result := sload(add(not(_OWNER_SLOT_NOT), 1))
        }
    }

    /// @dev Returns whether `user` has any of `roles`.
    function hasAnyRole(address user, uint256 roles) public view virtual returns (bool result) {
        assembly {
            // Compute the role slot.
            mstore(0x00, or(shl(96, user), _OWNER_SLOT_NOT))
            // Load the stored value, and set the result to whether the
            // `and` intersection of the value and `roles` is not zero.
            result := iszero(iszero(and(sload(keccak256(0x00, 0x20)), roles)))
        }
    }

    /// @dev Returns whether `user` has all of `roles`.
    function hasAllRoles(address user, uint256 roles) public view virtual returns (bool result) {
        assembly {
            // Compute the role slot.
            mstore(0x00, or(shl(96, user), _OWNER_SLOT_NOT))
            // Whether the stored value is contains all the set bits in `roles`.
            result := eq(and(sload(keccak256(0x00, 0x20)), roles), roles)
        }
    }

    /// @dev Returns the roles of `user`.
    function rolesOf(address user) public view virtual returns (uint256 roles) {
        assembly {
            // Compute the role slot.
            mstore(0x00, or(shl(96, user), _OWNER_SLOT_NOT))
            // Load the stored value.
            roles := sload(keccak256(0x00, 0x20))
        }
    }

    /// @dev Convenience function to return a `roles` bitmap from the `ordinals`.
    /// This is meant for frontends like Etherscan, and is therefore not fully optimized.
    /// Not recommended to be called on-chain.
    function rolesFromOrdinals(uint8[] memory ordinals) public pure returns (uint256 roles) {
        assembly {
            // Skip the length slot.
            let o := add(ordinals, 0x20)
            // `shl` 5 is equivalent to multiplying by 0x20.
            let end := add(o, shl(5, mload(ordinals)))
            // prettier-ignore
            for {} iszero(eq(o, end)) { o := add(o, 0x20) } {
                roles := or(roles, shl(and(mload(o), 0xff), 1))
            }
        }
    }

    /// @dev Convenience function to return a `roles` bitmap from the `ordinals`.
    /// This is meant for frontends like Etherscan, and is therefore not fully optimized.
    /// Not recommended to be called on-chain.
    function ordinalsFromRoles(uint256 roles) public pure returns (uint8[] memory ordinals) {
        assembly {
            // Grab the pointer to the free memory.
            let ptr := add(mload(0x40), 0x20)
            // The absence of lookup tables, De Bruijn, etc., here is intentional for
            // smaller bytecode, as this function is not meant to be called on-chain.
            // prettier-ignore
            for { let i := 0 } 1 { i := add(i, 1) } {
                mstore(ptr, i)
                // `shr` 5 is equivalent to multiplying by 0x20.
                // Push back into the ordinals array if the bit is set.
                ptr := add(ptr, shl(5, and(roles, 1)))
                roles := shr(1, roles)
                // prettier-ignore
                if iszero(roles) { break }
            }
            // Set `ordinals` to the start of the free memory.
            ordinals := mload(0x40)
            // Allocate the memory.
            mstore(0x40, ptr)
            // Store the length of `ordinals`.
            mstore(ordinals, shr(5, sub(ptr, add(ordinals, 0x20))))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Marks a function as only callable by the owner.
    modifier onlyOwner() virtual {
        assembly {
            // If the caller is not the stored owner, revert.
            if iszero(eq(caller(), sload(not(_OWNER_SLOT_NOT)))) {
                mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        _;
    }

    /// @dev Marks a function as only callable by an account with `roles`.
    modifier onlyRoles(uint256 roles) virtual {
        assembly {
            // Compute the role slot.
            mstore(0x00, or(shl(96, caller()), _OWNER_SLOT_NOT))
            // Load the stored value, and if the `and` intersection
            // of the value and `roles` is zero, revert.
            if iszero(and(sload(keccak256(0x00, 0x20)), roles)) {
                mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        _;
    }

    /// @dev Marks a function as only callable by the owner or by an account
    /// with `roles`. Checks for ownership first, then lazily checks for roles.
    modifier onlyOwnerOrRoles(uint256 roles) virtual {
        assembly {
            // If the caller is not the stored owner.
            if iszero(eq(caller(), sload(not(_OWNER_SLOT_NOT)))) {
                // Compute the role slot.
                mstore(0x00, or(shl(96, caller()), _OWNER_SLOT_NOT))
                // Load the stored value, and if the `and` intersection
                // of the value and `roles` is zero, revert.
                if iszero(and(sload(keccak256(0x00, 0x20)), roles)) {
                    mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                    revert(0x1c, 0x04)
                }
            }
        }
        _;
    }

    /// @dev Marks a function as only callable by an account with `roles`
    /// or the owner. Checks for roles first, then lazily checks for ownership.
    modifier onlyRolesOrOwner(uint256 roles) virtual {
        assembly {
            // Compute the role slot.
            mstore(0x00, or(shl(96, caller()), _OWNER_SLOT_NOT))
            // Load the stored value, and if the `and` intersection
            // of the value and `roles` is zero, revert.
            if iszero(and(sload(keccak256(0x00, 0x20)), roles)) {
                // If the caller is not the stored owner.
                if iszero(eq(caller(), sload(not(_OWNER_SLOT_NOT)))) {
                    mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                    revert(0x1c, 0x04)
                }
            }
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ROLE CONSTANTS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // IYKYK

    uint256 internal constant _ROLE_0 = 1 << 0;
    uint256 internal constant _ROLE_1 = 1 << 1;
    uint256 internal constant _ROLE_2 = 1 << 2;
    uint256 internal constant _ROLE_3 = 1 << 3;
    uint256 internal constant _ROLE_4 = 1 << 4;
    uint256 internal constant _ROLE_5 = 1 << 5;
    uint256 internal constant _ROLE_6 = 1 << 6;
    uint256 internal constant _ROLE_7 = 1 << 7;
    uint256 internal constant _ROLE_8 = 1 << 8;
    uint256 internal constant _ROLE_9 = 1 << 9;
    uint256 internal constant _ROLE_10 = 1 << 10;
    uint256 internal constant _ROLE_11 = 1 << 11;
    uint256 internal constant _ROLE_12 = 1 << 12;
    uint256 internal constant _ROLE_13 = 1 << 13;
    uint256 internal constant _ROLE_14 = 1 << 14;
    uint256 internal constant _ROLE_15 = 1 << 15;
    uint256 internal constant _ROLE_16 = 1 << 16;
    uint256 internal constant _ROLE_17 = 1 << 17;
    uint256 internal constant _ROLE_18 = 1 << 18;
    uint256 internal constant _ROLE_19 = 1 << 19;
    uint256 internal constant _ROLE_20 = 1 << 20;
    uint256 internal constant _ROLE_21 = 1 << 21;
    uint256 internal constant _ROLE_22 = 1 << 22;
    uint256 internal constant _ROLE_23 = 1 << 23;
    uint256 internal constant _ROLE_24 = 1 << 24;
    uint256 internal constant _ROLE_25 = 1 << 25;
    uint256 internal constant _ROLE_26 = 1 << 26;
    uint256 internal constant _ROLE_27 = 1 << 27;
    uint256 internal constant _ROLE_28 = 1 << 28;
    uint256 internal constant _ROLE_29 = 1 << 29;
    uint256 internal constant _ROLE_30 = 1 << 30;
    uint256 internal constant _ROLE_31 = 1 << 31;
    uint256 internal constant _ROLE_32 = 1 << 32;
    uint256 internal constant _ROLE_33 = 1 << 33;
    uint256 internal constant _ROLE_34 = 1 << 34;
    uint256 internal constant _ROLE_35 = 1 << 35;
    uint256 internal constant _ROLE_36 = 1 << 36;
    uint256 internal constant _ROLE_37 = 1 << 37;
    uint256 internal constant _ROLE_38 = 1 << 38;
    uint256 internal constant _ROLE_39 = 1 << 39;
    uint256 internal constant _ROLE_40 = 1 << 40;
    uint256 internal constant _ROLE_41 = 1 << 41;
    uint256 internal constant _ROLE_42 = 1 << 42;
    uint256 internal constant _ROLE_43 = 1 << 43;
    uint256 internal constant _ROLE_44 = 1 << 44;
    uint256 internal constant _ROLE_45 = 1 << 45;
    uint256 internal constant _ROLE_46 = 1 << 46;
    uint256 internal constant _ROLE_47 = 1 << 47;
    uint256 internal constant _ROLE_48 = 1 << 48;
    uint256 internal constant _ROLE_49 = 1 << 49;
    uint256 internal constant _ROLE_50 = 1 << 50;
    uint256 internal constant _ROLE_51 = 1 << 51;
    uint256 internal constant _ROLE_52 = 1 << 52;
    uint256 internal constant _ROLE_53 = 1 << 53;
    uint256 internal constant _ROLE_54 = 1 << 54;
    uint256 internal constant _ROLE_55 = 1 << 55;
    uint256 internal constant _ROLE_56 = 1 << 56;
    uint256 internal constant _ROLE_57 = 1 << 57;
    uint256 internal constant _ROLE_58 = 1 << 58;
    uint256 internal constant _ROLE_59 = 1 << 59;
    uint256 internal constant _ROLE_60 = 1 << 60;
    uint256 internal constant _ROLE_61 = 1 << 61;
    uint256 internal constant _ROLE_62 = 1 << 62;
    uint256 internal constant _ROLE_63 = 1 << 63;
    uint256 internal constant _ROLE_64 = 1 << 64;
    uint256 internal constant _ROLE_65 = 1 << 65;
    uint256 internal constant _ROLE_66 = 1 << 66;
    uint256 internal constant _ROLE_67 = 1 << 67;
    uint256 internal constant _ROLE_68 = 1 << 68;
    uint256 internal constant _ROLE_69 = 1 << 69;
    uint256 internal constant _ROLE_70 = 1 << 70;
    uint256 internal constant _ROLE_71 = 1 << 71;
    uint256 internal constant _ROLE_72 = 1 << 72;
    uint256 internal constant _ROLE_73 = 1 << 73;
    uint256 internal constant _ROLE_74 = 1 << 74;
    uint256 internal constant _ROLE_75 = 1 << 75;
    uint256 internal constant _ROLE_76 = 1 << 76;
    uint256 internal constant _ROLE_77 = 1 << 77;
    uint256 internal constant _ROLE_78 = 1 << 78;
    uint256 internal constant _ROLE_79 = 1 << 79;
    uint256 internal constant _ROLE_80 = 1 << 80;
    uint256 internal constant _ROLE_81 = 1 << 81;
    uint256 internal constant _ROLE_82 = 1 << 82;
    uint256 internal constant _ROLE_83 = 1 << 83;
    uint256 internal constant _ROLE_84 = 1 << 84;
    uint256 internal constant _ROLE_85 = 1 << 85;
    uint256 internal constant _ROLE_86 = 1 << 86;
    uint256 internal constant _ROLE_87 = 1 << 87;
    uint256 internal constant _ROLE_88 = 1 << 88;
    uint256 internal constant _ROLE_89 = 1 << 89;
    uint256 internal constant _ROLE_90 = 1 << 90;
    uint256 internal constant _ROLE_91 = 1 << 91;
    uint256 internal constant _ROLE_92 = 1 << 92;
    uint256 internal constant _ROLE_93 = 1 << 93;
    uint256 internal constant _ROLE_94 = 1 << 94;
    uint256 internal constant _ROLE_95 = 1 << 95;
    uint256 internal constant _ROLE_96 = 1 << 96;
    uint256 internal constant _ROLE_97 = 1 << 97;
    uint256 internal constant _ROLE_98 = 1 << 98;
    uint256 internal constant _ROLE_99 = 1 << 99;
    uint256 internal constant _ROLE_100 = 1 << 100;
    uint256 internal constant _ROLE_101 = 1 << 101;
    uint256 internal constant _ROLE_102 = 1 << 102;
    uint256 internal constant _ROLE_103 = 1 << 103;
    uint256 internal constant _ROLE_104 = 1 << 104;
    uint256 internal constant _ROLE_105 = 1 << 105;
    uint256 internal constant _ROLE_106 = 1 << 106;
    uint256 internal constant _ROLE_107 = 1 << 107;
    uint256 internal constant _ROLE_108 = 1 << 108;
    uint256 internal constant _ROLE_109 = 1 << 109;
    uint256 internal constant _ROLE_110 = 1 << 110;
    uint256 internal constant _ROLE_111 = 1 << 111;
    uint256 internal constant _ROLE_112 = 1 << 112;
    uint256 internal constant _ROLE_113 = 1 << 113;
    uint256 internal constant _ROLE_114 = 1 << 114;
    uint256 internal constant _ROLE_115 = 1 << 115;
    uint256 internal constant _ROLE_116 = 1 << 116;
    uint256 internal constant _ROLE_117 = 1 << 117;
    uint256 internal constant _ROLE_118 = 1 << 118;
    uint256 internal constant _ROLE_119 = 1 << 119;
    uint256 internal constant _ROLE_120 = 1 << 120;
    uint256 internal constant _ROLE_121 = 1 << 121;
    uint256 internal constant _ROLE_122 = 1 << 122;
    uint256 internal constant _ROLE_123 = 1 << 123;
    uint256 internal constant _ROLE_124 = 1 << 124;
    uint256 internal constant _ROLE_125 = 1 << 125;
    uint256 internal constant _ROLE_126 = 1 << 126;
    uint256 internal constant _ROLE_127 = 1 << 127;
    uint256 internal constant _ROLE_128 = 1 << 128;
    uint256 internal constant _ROLE_129 = 1 << 129;
    uint256 internal constant _ROLE_130 = 1 << 130;
    uint256 internal constant _ROLE_131 = 1 << 131;
    uint256 internal constant _ROLE_132 = 1 << 132;
    uint256 internal constant _ROLE_133 = 1 << 133;
    uint256 internal constant _ROLE_134 = 1 << 134;
    uint256 internal constant _ROLE_135 = 1 << 135;
    uint256 internal constant _ROLE_136 = 1 << 136;
    uint256 internal constant _ROLE_137 = 1 << 137;
    uint256 internal constant _ROLE_138 = 1 << 138;
    uint256 internal constant _ROLE_139 = 1 << 139;
    uint256 internal constant _ROLE_140 = 1 << 140;
    uint256 internal constant _ROLE_141 = 1 << 141;
    uint256 internal constant _ROLE_142 = 1 << 142;
    uint256 internal constant _ROLE_143 = 1 << 143;
    uint256 internal constant _ROLE_144 = 1 << 144;
    uint256 internal constant _ROLE_145 = 1 << 145;
    uint256 internal constant _ROLE_146 = 1 << 146;
    uint256 internal constant _ROLE_147 = 1 << 147;
    uint256 internal constant _ROLE_148 = 1 << 148;
    uint256 internal constant _ROLE_149 = 1 << 149;
    uint256 internal constant _ROLE_150 = 1 << 150;
    uint256 internal constant _ROLE_151 = 1 << 151;
    uint256 internal constant _ROLE_152 = 1 << 152;
    uint256 internal constant _ROLE_153 = 1 << 153;
    uint256 internal constant _ROLE_154 = 1 << 154;
    uint256 internal constant _ROLE_155 = 1 << 155;
    uint256 internal constant _ROLE_156 = 1 << 156;
    uint256 internal constant _ROLE_157 = 1 << 157;
    uint256 internal constant _ROLE_158 = 1 << 158;
    uint256 internal constant _ROLE_159 = 1 << 159;
    uint256 internal constant _ROLE_160 = 1 << 160;
    uint256 internal constant _ROLE_161 = 1 << 161;
    uint256 internal constant _ROLE_162 = 1 << 162;
    uint256 internal constant _ROLE_163 = 1 << 163;
    uint256 internal constant _ROLE_164 = 1 << 164;
    uint256 internal constant _ROLE_165 = 1 << 165;
    uint256 internal constant _ROLE_166 = 1 << 166;
    uint256 internal constant _ROLE_167 = 1 << 167;
    uint256 internal constant _ROLE_168 = 1 << 168;
    uint256 internal constant _ROLE_169 = 1 << 169;
    uint256 internal constant _ROLE_170 = 1 << 170;
    uint256 internal constant _ROLE_171 = 1 << 171;
    uint256 internal constant _ROLE_172 = 1 << 172;
    uint256 internal constant _ROLE_173 = 1 << 173;
    uint256 internal constant _ROLE_174 = 1 << 174;
    uint256 internal constant _ROLE_175 = 1 << 175;
    uint256 internal constant _ROLE_176 = 1 << 176;
    uint256 internal constant _ROLE_177 = 1 << 177;
    uint256 internal constant _ROLE_178 = 1 << 178;
    uint256 internal constant _ROLE_179 = 1 << 179;
    uint256 internal constant _ROLE_180 = 1 << 180;
    uint256 internal constant _ROLE_181 = 1 << 181;
    uint256 internal constant _ROLE_182 = 1 << 182;
    uint256 internal constant _ROLE_183 = 1 << 183;
    uint256 internal constant _ROLE_184 = 1 << 184;
    uint256 internal constant _ROLE_185 = 1 << 185;
    uint256 internal constant _ROLE_186 = 1 << 186;
    uint256 internal constant _ROLE_187 = 1 << 187;
    uint256 internal constant _ROLE_188 = 1 << 188;
    uint256 internal constant _ROLE_189 = 1 << 189;
    uint256 internal constant _ROLE_190 = 1 << 190;
    uint256 internal constant _ROLE_191 = 1 << 191;
    uint256 internal constant _ROLE_192 = 1 << 192;
    uint256 internal constant _ROLE_193 = 1 << 193;
    uint256 internal constant _ROLE_194 = 1 << 194;
    uint256 internal constant _ROLE_195 = 1 << 195;
    uint256 internal constant _ROLE_196 = 1 << 196;
    uint256 internal constant _ROLE_197 = 1 << 197;
    uint256 internal constant _ROLE_198 = 1 << 198;
    uint256 internal constant _ROLE_199 = 1 << 199;
    uint256 internal constant _ROLE_200 = 1 << 200;
    uint256 internal constant _ROLE_201 = 1 << 201;
    uint256 internal constant _ROLE_202 = 1 << 202;
    uint256 internal constant _ROLE_203 = 1 << 203;
    uint256 internal constant _ROLE_204 = 1 << 204;
    uint256 internal constant _ROLE_205 = 1 << 205;
    uint256 internal constant _ROLE_206 = 1 << 206;
    uint256 internal constant _ROLE_207 = 1 << 207;
    uint256 internal constant _ROLE_208 = 1 << 208;
    uint256 internal constant _ROLE_209 = 1 << 209;
    uint256 internal constant _ROLE_210 = 1 << 210;
    uint256 internal constant _ROLE_211 = 1 << 211;
    uint256 internal constant _ROLE_212 = 1 << 212;
    uint256 internal constant _ROLE_213 = 1 << 213;
    uint256 internal constant _ROLE_214 = 1 << 214;
    uint256 internal constant _ROLE_215 = 1 << 215;
    uint256 internal constant _ROLE_216 = 1 << 216;
    uint256 internal constant _ROLE_217 = 1 << 217;
    uint256 internal constant _ROLE_218 = 1 << 218;
    uint256 internal constant _ROLE_219 = 1 << 219;
    uint256 internal constant _ROLE_220 = 1 << 220;
    uint256 internal constant _ROLE_221 = 1 << 221;
    uint256 internal constant _ROLE_222 = 1 << 222;
    uint256 internal constant _ROLE_223 = 1 << 223;
    uint256 internal constant _ROLE_224 = 1 << 224;
    uint256 internal constant _ROLE_225 = 1 << 225;
    uint256 internal constant _ROLE_226 = 1 << 226;
    uint256 internal constant _ROLE_227 = 1 << 227;
    uint256 internal constant _ROLE_228 = 1 << 228;
    uint256 internal constant _ROLE_229 = 1 << 229;
    uint256 internal constant _ROLE_230 = 1 << 230;
    uint256 internal constant _ROLE_231 = 1 << 231;
    uint256 internal constant _ROLE_232 = 1 << 232;
    uint256 internal constant _ROLE_233 = 1 << 233;
    uint256 internal constant _ROLE_234 = 1 << 234;
    uint256 internal constant _ROLE_235 = 1 << 235;
    uint256 internal constant _ROLE_236 = 1 << 236;
    uint256 internal constant _ROLE_237 = 1 << 237;
    uint256 internal constant _ROLE_238 = 1 << 238;
    uint256 internal constant _ROLE_239 = 1 << 239;
    uint256 internal constant _ROLE_240 = 1 << 240;
    uint256 internal constant _ROLE_241 = 1 << 241;
    uint256 internal constant _ROLE_242 = 1 << 242;
    uint256 internal constant _ROLE_243 = 1 << 243;
    uint256 internal constant _ROLE_244 = 1 << 244;
    uint256 internal constant _ROLE_245 = 1 << 245;
    uint256 internal constant _ROLE_246 = 1 << 246;
    uint256 internal constant _ROLE_247 = 1 << 247;
    uint256 internal constant _ROLE_248 = 1 << 248;
    uint256 internal constant _ROLE_249 = 1 << 249;
    uint256 internal constant _ROLE_250 = 1 << 250;
    uint256 internal constant _ROLE_251 = 1 << 251;
    uint256 internal constant _ROLE_252 = 1 << 252;
    uint256 internal constant _ROLE_253 = 1 << 253;
    uint256 internal constant _ROLE_254 = 1 << 254;
    uint256 internal constant _ROLE_255 = 1 << 255;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller.
library SafeTransferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error ETHTransferFailed();

    error TransferFromFailed();

    error TransferFailed();

    error ApproveFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ETH OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function safeTransferETH(address to, uint256 amount) internal {
        assembly {
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
                // Store the function selector of `ETHTransferFailed()`.
                mstore(0x00, 0xb12d13eb)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0x00, 0x23b872dd)
            mstore(0x20, from) // Append the "from" argument.
            mstore(0x40, to) // Append the "to" argument.
            mstore(0x60, amount) // Append the "amount" argument.

            if iszero(
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    // We use 0x64 because that's the total length of our calldata (0x04 + 0x20 * 3)
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFromFailed()`.
                mstore(0x00, 0x7939f424)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }
    }

    function safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0x00, 0xa9059cbb)
            mstore(0x20, to) // Append the "to" argument.
            mstore(0x40, amount) // Append the "amount" argument.

            if iszero(
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    // We use 0x44 because that's the total length of our calldata (0x04 + 0x20 * 2)
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    call(gas(), token, 0, 0x1c, 0x44, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFailed()`.
                mstore(0x00, 0x90b8ec18)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x40, memPointer) // Restore the memPointer.
        }
    }

    function safeApprove(
        address token,
        address to,
        uint256 amount
    ) internal {
        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0x00, 0x095ea7b3)
            mstore(0x20, to) // Append the "to" argument.
            mstore(0x40, amount) // Append the "amount" argument.

            if iszero(
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    // We use 0x44 because that's the total length of our calldata (0x04 + 0x20 * 2)
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    call(gas(), token, 0, 0x1c, 0x44, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `ApproveFailed()`.
                mstore(0x00, 0x3e3f8f73)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x40, memPointer) // Restore the memPointer.
        }
    }
}

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creator: Chiru Labs

pragma solidity ^0.8.4;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721AUpgradeable {
    /**
     * The caller must own the token or be an approved operator.
     */
    error ApprovalCallerNotOwnerNorApproved();

    /**
     * The token does not exist.
     */
    error ApprovalQueryForNonexistentToken();

    /**
     * Cannot query the balance for the zero address.
     */
    error BalanceQueryForZeroAddress();

    /**
     * Cannot mint to the zero address.
     */
    error MintToZeroAddress();

    /**
     * The quantity of tokens minted must be more than zero.
     */
    error MintZeroQuantity();

    /**
     * The token does not exist.
     */
    error OwnerQueryForNonexistentToken();

    /**
     * The caller must own the token or be an approved operator.
     */
    error TransferCallerNotOwnerNorApproved();

    /**
     * The token must be owned by `from`.
     */
    error TransferFromIncorrectOwner();

    /**
     * Cannot safely transfer to a contract that does not implement the
     * ERC721Receiver interface.
     */
    error TransferToNonERC721ReceiverImplementer();

    /**
     * Cannot transfer to the zero address.
     */
    error TransferToZeroAddress();

    /**
     * The token does not exist.
     */
    error URIQueryForNonexistentToken();

    /**
     * The `quantity` minted with ERC2309 exceeds the safety limit.
     */
    error MintERC2309QuantityExceedsLimit();

    /**
     * The `extraData` cannot be set on an unintialized ownership slot.
     */
    error OwnershipNotInitializedForExtraData();

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Stores the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
        // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
        uint24 extraData;
    }

    // =============================================================
    //                         TOKEN COUNTERS
    // =============================================================

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() external view returns (uint256);

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // =============================================================
    //                            IERC721
    // =============================================================

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables
     * (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in `owner`'s account.
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
     * @dev Safely transfers `tokenId` token from `from` to `to`,
     * checking first that contract recipients are aware of the ERC721 protocol
     * to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move
     * this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
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
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
     * whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
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
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
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
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
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
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    // =============================================================
    //                           IERC2309
    // =============================================================

    /**
     * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981Upgradeable is IERC165Upgradeable {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
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
interface IERC165Upgradeable {
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/**
 * @title IMetadataModule
 * @notice The interface for custom metadata modules.
 */
interface IMetadataModule {
    /**
     * @dev When implemented, SoundEdition's `tokenURI` redirects execution to this `tokenURI`.
     * @param tokenId The token ID to retrieve the token URI for.
     * @return The token URI string.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}