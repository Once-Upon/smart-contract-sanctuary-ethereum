// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Interfaces/IAirdropClaim.sol";
import "./Interfaces/IReserve.sol";
import "./Interfaces/ISwap.sol";
import "./Interfaces/IVault.sol";
import "./Interfaces/IWhitelist.sol";
import "./Interfaces/IPositionToken.sol";
import "./lib/Utils.sol";

/// @title NF3 Reserve
/// @author Jack Jin
/// @author Priyam Anand
/// @notice This contract inherits from IReserve interface.
/// @dev Functions in this contract are not public callable. They can only be called through the public facing contract(NF3Proxy).
/// @dev This contract has the functions related to reservation swaps.

contract Reserve is Ownable, IReserve {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using Utils for *;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Minimum duration of reservation
    uint256 public minimumReservationDuration = 1 hours;

    /// @notice NF3Market contract address
    address public marketAddress;

    /// @notice Vault contract address
    address public vaultAddress;

    /// @notice Swap contract address
    address public swapAddress;

    /// @notice PositionToken contract address
    address public positionTokenAddress;

    /// @notice Whitelist contract address
    address public whitelistAddress;

    /// @notice Address of airdrop claim contract implementation
    address public airdropClaimImplementation;

    /// @notice mapping from position tokenId to claim contract address
    mapping(uint256 => address) public claimContractAddresses;

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyMarket() {
        if (msg.sender != marketAddress) {
            revert ReserveError(ReserveErrorCodes.NOT_MARKET);
        }
        _;
    }

    /// -----------------------------------------------------------------------
    /// Cancel Actions
    /// -----------------------------------------------------------------------

    /// @notice Inherit from IReserve
    function cancelReserveOffer(
        ReserveOffer calldata _offer,
        bytes memory _offerSignature,
        address _user
    ) external override onlyMarket {
        // Verify offer signature.
        _offer.verifyReserveOfferSignature(_offerSignature);

        // Should be called by the offer owner.
        _offer.owner.itemOwnerOnly(_user);

        // Offer must have correct nonce.
        ISwap(swapAddress).checkNonce(
            _offer.owner,
            _offer.nonce,
            Status.AVAILABLE
        );

        // Update the nonce.
        ISwap(swapAddress).setNonce(
            _offer.owner,
            _offer.nonce,
            Status.EXHAUSTED
        );

        emit ReserveOfferCancelled(_offer);
    }

    function cancelCollectionReserveOffer(
        CollectionReserveOffer calldata _offer,
        bytes memory _offerSignature,
        address _user
    ) external override onlyMarket {
        // verify offer signature
        _offer.verifyCollectionReserveOfferSignature(_offerSignature);

        // should be called by the offer owner
        _offer.owner.itemOwnerOnly(_user);

        // should have the correct nonce
        ISwap(swapAddress).checkNonce(
            _offer.owner,
            _offer.nonce,
            Status.AVAILABLE
        );

        // update the nonce
        ISwap(swapAddress).setNonce(
            _offer.owner,
            _offer.nonce,
            Status.EXHAUSTED
        );

        // emit event
        emit CollectionReserveOfferCancelled(_offer);
    }

    /// -----------------------------------------------------------------------
    /// Reserve swap Actions
    /// -----------------------------------------------------------------------

    /// @notice Inherit from IReserve
    function reserveDeposit(
        Listing calldata _listing,
        bytes memory _listingSignature,
        uint256 _reserveId,
        address _user,
        uint256 _value
    ) external override onlyMarket {
        // Check the signature, nonce and expiration.
        _validateListing(_listing, _listingSignature);

        // check if called by eligible contract
        address intendedFor = _listing.tradeIntendedFor;
        if (!(intendedFor == address(0) || intendedFor == _user)) {
            revert ReserveError(
                ReserveErrorCodes.INTENDED_FOR_PEER_TO_PEER_TRADE
            );
        }

        // Seller should not buy his own listing.
        _listing.owner.notItemOwner(_user);

        ReserveInfo memory reserveInfo = reserveExists(
            _listing.reserves,
            _reserveId
        );

        // Check remaining assets Whitelist
        IWhitelist(whitelistAddress).checkAssetsWhitelist(
            reserveInfo.remaining
        );

        // Check the Eth value.
        reserveInfo.deposit.checkEthAmount(_value);

        // start reservation
        (
            Reservation memory _reservation,
            uint256 _positionTokenId
        ) = _startReservation(
                _listing.listingAssets,
                _listing.royalty,
                reserveInfo,
                _listing.owner,
                _user,
                true
            );

        // Update the nonce.
        ISwap(swapAddress).setNonce(
            _listing.owner,
            _listing.nonce,
            Status.EXHAUSTED
        );

        emit ReserveDeposited(
            _listing,
            _reservation,
            _reserveId,
            _positionTokenId,
            _user
        );
    }

    /// @notice Inherit from IReserve
    function acceptUnlistedReserveOffer(
        ReserveOffer calldata _offer,
        bytes memory _offerSignature,
        Assets calldata _consideration,
        bytes32[] calldata _proof,
        address _user,
        uint256 _value,
        Royalty calldata _royalty
    ) external override onlyMarket {
        // verify offer signature, nonce and expiration
        _validateReserveOffer(_offer, _offerSignature);

        // seller should not accept his owner offer
        _offer.owner.notItemOwner(_user);

        // verify incomming assets to be part of the merkle root
        _offer.considerationRoot.verifyAssetProof(_consideration, _proof);

        // check incomming eth amount
        _consideration.checkEthAmount(_value);

        // Check remaining assets Whitelist
        IWhitelist(whitelistAddress).checkAssetsWhitelist(
            _offer.reserveDetails.remaining
        );

        // start reservation
        (
            Reservation memory _reservation,
            uint256 _positionTokenId
        ) = _startReservation(
                _consideration,
                _royalty,
                _offer.reserveDetails,
                _user,
                _offer.owner,
                false
            );

        // Update the nonce.
        ISwap(swapAddress).setNonce(
            _offer.owner,
            _offer.nonce,
            Status.EXHAUSTED
        );

        // emit events
        emit UnlistedReserveOfferAccepted(
            _offer,
            _reservation,
            _consideration,
            _positionTokenId,
            _user
        );
    }

    /// @notice Inherit from IReserve
    function acceptListedReserveOffer(
        Listing calldata _listing,
        bytes memory _listingSignature,
        ReserveOffer calldata _offer,
        bytes memory _offerSignature,
        bytes32[] calldata _proof,
        address _user
    ) external override onlyMarket {
        // Verify listing signature, nonce and expiration.
        _validateListing(_listing, _listingSignature);

        // Verify offer signature, nonce and expiration.
        _validateReserveOffer(_offer, _offerSignature);

        // Should be called by listing owner.
        _listing.owner.itemOwnerOnly(_user);

        // Should not be called by the offer owner.
        _offer.owner.notItemOwner(_user);

        // Verify listing assets to be present in the consideration root
        _offer.considerationRoot.verifyAssetProof(
            _listing.listingAssets,
            _proof
        );

        // Check remaining assets Whitelist
        IWhitelist(whitelistAddress).checkAssetsWhitelist(
            _offer.reserveDetails.remaining
        );

        // start reservation
        (
            Reservation memory _reservation,
            uint256 _positionTokenId
        ) = _startReservation(
                _listing.listingAssets,
                _listing.royalty,
                _offer.reserveDetails,
                _listing.owner,
                _offer.owner,
                false
            );

        // Update the nonce.
        ISwap(swapAddress).setNonce(
            _listing.owner,
            _listing.nonce,
            Status.EXHAUSTED
        );

        ISwap(swapAddress).setNonce(
            _offer.owner,
            _offer.nonce,
            Status.EXHAUSTED
        );

        // emit event
        emit ListedReserveOfferAccepted(
            _listing,
            _offer,
            _reservation,
            _positionTokenId,
            _user
        );
    }

    function acceptCollectionReserveOffer(
        CollectionReserveOffer calldata _offer,
        bytes memory _signature,
        address[] memory _tokens,
        uint256[] memory _tokenIds,
        bytes32[][] memory _proofs,
        address _user,
        uint256 _value,
        Royalty calldata _royalty
    ) external override onlyMarket {
        // validate offer signature
        _offer.verifyCollectionReserveOfferSignature(_signature);
        ISwap(swapAddress).checkNonce(
            _offer.owner,
            _offer.nonce,
            Status.AVAILABLE
        );
        checkExpiration(_offer.timePeriod);

        // Seller must not be the offer owner
        _offer.owner.notItemOwner(_user);

        // verify incomming assets be same as consideration items
        Assets memory offeredAssets = _offer
            .considerationItems
            .verifySwapAssets(_tokens, _tokenIds, _proofs, _value);

        // Check remaining assets Whitelist
        IWhitelist(whitelistAddress).checkAssetsWhitelist(
            _offer.reserveDetails.remaining
        );

        // start reservation
        (
            Reservation memory _reservation,
            uint256 _positionTokenId
        ) = _startReservation(
                offeredAssets,
                _royalty,
                _offer.reserveDetails,
                _user,
                _offer.owner,
                false
            );

        // update the nonce
        ISwap(swapAddress).setNonce(
            _offer.owner,
            _offer.nonce,
            Status.EXHAUSTED
        );

        // emit event
        emit CollectionReserveOfferAccepted(
            _offer,
            offeredAssets,
            _reservation,
            _positionTokenId,
            _user
        );
    }

    /// @notice Inherit from IReserve
    function payRemains(
        Reservation calldata _reservation,
        uint256 _positionTokenId,
        address _user,
        uint256 _value,
        Royalty calldata _royalty
    ) external override onlyMarket {
        // Check if the buyer is owner of position token.
        checkPositionTokenOwner(_positionTokenId, _user, positionTokenAddress);

        bytes32 dataHash = IPositionToken(positionTokenAddress).dataHash(
            _positionTokenId
        );

        // Check if the position token is of the correct listing.
        checkPositionTokenHash(
            dataHash,
            _reservation.reservedAssets.getPostitionTokenDataHash(
                _reservation.reserveInfo,
                _reservation.assetOwner
            )
        );

        // Check if reservation has expired.
        checkExpiration(
            _reservation.reserveInfo.duration +
                IPositionToken(positionTokenAddress).startTime(_positionTokenId)
        );

        // Check the Eth value.
        _reservation.reserveInfo.remaining.checkEthAmount(_value);

        // transfer remaining balance to the seller
        IVault(vaultAddress).transferAssets(
            _reservation.reserveInfo.remaining,
            _user,
            _reservation.assetOwner,
            _reservation.reservedAssetsRoyalty,
            true
        );

        // transfer listing assets from vault to the buyer
        IVault(vaultAddress).sendAssets(
            _reservation.reservedAssets,
            _user,
            _royalty,
            true
        );

        // transfer claim contract ownership to the buyer
        address _claimContract = claimContractAddresses[_positionTokenId];
        if (_claimContract != address(0)) {
            IAirdropClaim(_claimContract)
                .transferOwnershipAndCompleteReservation(_user);
        }

        // Burn the position token.
        IPositionToken(positionTokenAddress).burn(_positionTokenId);

        emit RemainsPaid(_reservation, _positionTokenId, _user);
    }

    /// @notice Inherit from IReserve
    function claimDefaulted(
        Reservation calldata _reservation,
        uint256 _positionTokenId,
        address _user
    ) external override onlyMarket {
        // Should be called by the listing owner.
        _reservation.assetOwner.itemOwnerOnly(_user);

        bytes32 dataHash = IPositionToken(positionTokenAddress).dataHash(
            _positionTokenId
        );

        // Check if the position token is of the correct listing.
        checkPositionTokenHash(
            dataHash,
            _reservation.reservedAssets.getPostitionTokenDataHash(
                _reservation.reserveInfo,
                _reservation.assetOwner
            )
        );

        // Check the expiration.
        if (
            _reservation.reserveInfo.duration +
                IPositionToken(positionTokenAddress).startTime(
                    _positionTokenId
                ) >
            block.timestamp
        ) revert ReserveError(ReserveErrorCodes.NOT_TIME_TO_CLAIM);

        // transfer listing assets from vault to the buyer
        IVault(vaultAddress).sendAssets(
            _reservation.reservedAssets,
            _reservation.assetOwner,
            _reservation.reservedAssetsRoyalty,
            true
        );

        // Burn the position token.
        IPositionToken(positionTokenAddress).burn(_positionTokenId);

        emit Claimed(_reservation, _positionTokenId, _user);
    }

    /// @notice Inherit from IReserve
    function claimAirdrop(
        Reservation calldata _reservation,
        uint256 _positionTokenId,
        address _airdropContract,
        bytes calldata _data,
        address _user
    ) external override onlyMarket {
        address _positionTokenAddress = positionTokenAddress;
        // Check if the position token is of the correct reservation.
        bytes32 dataHash = IPositionToken(_positionTokenAddress).dataHash(
            _positionTokenId
        );

        checkPositionTokenHash(
            dataHash,
            _reservation.reservedAssets.getPostitionTokenDataHash(
                _reservation.reserveInfo,
                _reservation.assetOwner
            )
        );

        // Can only be called by the position token owner or reservation owner
        if (
            !(_user ==
                IPositionToken(_positionTokenAddress).ownerOf(
                    _positionTokenId
                ) ||
                _user == _reservation.assetOwner)
        ) {
            // revert with error
            revert ReserveError(ReserveErrorCodes.INVALID_USER);
        }

        // check if claim contract already exist
        address _contract = claimContractAddresses[_positionTokenId];

        // if not, deploy a new clone and set the reservation owner as the owner
        if (_contract == address(0)) {
            _contract = Clones.clone(airdropClaimImplementation);
            uint256 timePeriod = _reservation.reserveInfo.duration +
                IPositionToken(_positionTokenAddress).startTime(
                    _positionTokenId
                );
            IAirdropClaim(_contract).initialize(
                _reservation.assetOwner,
                timePeriod
            );
            claimContractAddresses[_positionTokenId] = _contract;
        }

        // load required variables to memory and stack
        address _vaultAddress = vaultAddress;
        Assets memory _assets = Assets({
            tokens: _reservation.reservedAssets.tokens,
            tokenIds: _reservation.reservedAssets.tokenIds,
            paymentTokens: new address[](0),
            amounts: new uint256[](0)
        });

        // transfer the assets to the clone address
        IVault(_vaultAddress).sendAssets(
            _assets,
            _contract,
            Royalty({to: new address[](0), percentage: new uint256[](0)}),
            false
        );

        // call the required function for air drop claim
        IAirdropClaim(_contract).claimAirdrop(_assets, _airdropContract, _data);

        // transfer the assets back from the clone to vault
        IVault(_vaultAddress).receiveAssets(_assets, _contract, false);
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @notice Inherit from IReserve
    function setMinimumReservationDuration(uint256 _minimumReservationDuration)
        external
        override
        onlyOwner
    {
        emit MinimumReservationDurationSet(
            minimumReservationDuration,
            _minimumReservationDuration
        );
        minimumReservationDuration = _minimumReservationDuration;
    }

    /// @notice Inherit from IReserve
    function setMarket(address _marketAddress) external override onlyOwner {
        if (_marketAddress == address(0)) {
            revert ReserveError(ReserveErrorCodes.INVALID_ADDRESS);
        }
        emit MarketSet(marketAddress, _marketAddress);

        marketAddress = _marketAddress;
    }

    /// @notice Inherit from IReserve
    function setVault(address _vaultAddress) external override onlyOwner {
        if (_vaultAddress == address(0)) {
            revert ReserveError(ReserveErrorCodes.INVALID_ADDRESS);
        }
        emit VaultSet(vaultAddress, _vaultAddress);

        vaultAddress = _vaultAddress;
    }

    /// @notice Inherit from IReserve
    function setSwap(address _swapAddress) external override onlyOwner {
        if (_swapAddress == address(0)) {
            revert ReserveError(ReserveErrorCodes.INVALID_ADDRESS);
        }
        emit SwapSet(swapAddress, _swapAddress);

        swapAddress = _swapAddress;
    }

    /// @notice Inherit from IReserve
    function setPositionToken(address _positionTokenAddress)
        external
        override
        onlyOwner
    {
        if (_positionTokenAddress == address(0)) {
            revert ReserveError(ReserveErrorCodes.INVALID_ADDRESS);
        }
        emit PositionTokenSet(positionTokenAddress, _positionTokenAddress);

        positionTokenAddress = _positionTokenAddress;
    }

    /// @notice Inherit from IReserve
    function setWhitelist(address _whitelistAddress)
        external
        override
        onlyOwner
    {
        if (_whitelistAddress == address(0)) {
            revert ReserveError(ReserveErrorCodes.INVALID_ADDRESS);
        }
        emit WhitelistSet(whitelistAddress, _whitelistAddress);
        whitelistAddress = _whitelistAddress;
    }

    /// @notice Inherit from IReserve
    function setAirdropClaimImplementation(address _airdropClaimImplementation)
        external
        override
        onlyOwner
    {
        if (_airdropClaimImplementation == address(0)) {
            revert ReserveError(ReserveErrorCodes.INVALID_ADDRESS);
        }
        emit AirdropClaimImplementationSet(
            airdropClaimImplementation,
            _airdropClaimImplementation
        );
        airdropClaimImplementation = _airdropClaimImplementation;
    }

    /// -----------------------------------------------------------------------
    /// Internal actions
    /// -----------------------------------------------------------------------

    /// @dev Validate common listing details
    /// @param _listing Listing details
    /// @param _signature Listing signature
    function _validateListing(
        Listing calldata _listing,
        bytes memory _signature
    ) internal view {
        _listing.verifyListingSignature(_signature);
        ISwap(swapAddress).checkNonce(
            _listing.owner,
            _listing.nonce,
            Status.AVAILABLE
        );
        checkExpiration(_listing.timePeriod);
    }

    /// @dev Validate common reserve offer details
    /// @param _offer Reserve offer details
    /// @param _signature Reserve offer signature
    function _validateReserveOffer(
        ReserveOffer calldata _offer,
        bytes memory _signature
    ) internal view {
        _offer.verifyReserveOfferSignature(_signature);
        ISwap(swapAddress).checkNonce(
            _offer.owner,
            _offer.nonce,
            Status.AVAILABLE
        );
        checkExpiration(_offer.timePeriod);
    }

    /// @dev Common operations to start a reservation
    /// @param _reservationAssets Assets beging reserved
    /// @param _reservedAssetsRotyaly Royalty offered by the assets owner
    /// @param _reserveInfo Reservation details of the trade
    /// @param _assetsOwner Original owner of the reserved assets
    /// @param _reservedUser User who reserved the assets
    /// @param ethAllowed bool value to allow user of eth in the trade
    function _startReservation(
        Assets memory _reservationAssets,
        Royalty memory _reservedAssetsRotyaly,
        ReserveInfo memory _reserveInfo,
        address _assetsOwner,
        address _reservedUser,
        bool ethAllowed
    ) internal returns (Reservation memory, uint256) {
        Reservation memory _reservation = Reservation({
            reservedAssets: _reservationAssets,
            reservedAssetsRoyalty: _reservedAssetsRotyaly,
            reserveInfo: _reserveInfo,
            assetOwner: _assetsOwner
        });

        // verify reservation duration
        if (_reservation.reserveInfo.duration < minimumReservationDuration) {
            revert ReserveError(ReserveErrorCodes.INVALID_RESERVATION_DURATION);
        }

        // Mint the position token with listing & reserve info.
        uint256 _positionTokenId = IPositionToken(positionTokenAddress).mint(
            _reservation,
            _reservedUser
        );

        // Tranfer deposit to the seller.
        IVault(vaultAddress).transferAssets(
            _reserveInfo.deposit,
            _reservedUser,
            _assetsOwner,
            _reservedAssetsRotyaly,
            ethAllowed
        );

        // Transfer listing assets to the vault.
        IVault(vaultAddress).receiveAssets(
            _reservationAssets,
            _assetsOwner,
            true
        );

        return (_reservation, _positionTokenId);
    }

    /// @dev Check if the item has expired.
    /// @param _timePeriod Listing time period
    function checkExpiration(uint256 _timePeriod) internal view {
        if (_timePeriod < block.timestamp) {
            revert ReserveError(ReserveErrorCodes.TIME_OVERFLOW);
        }
    }

    /// @dev Check if the swap option with given swap id exist or not.
    /// @param _reserves All the swap options
    /// @param _reserveId Swap id to be checked
    /// @return reserve Swap assets at given index
    function reserveExists(ReserveInfo[] calldata _reserves, uint256 _reserveId)
        internal
        pure
        returns (ReserveInfo calldata)
    {
        if (_reserves.length <= _reserveId) {
            revert ReserveError(ReserveErrorCodes.OPTION_DOES_NOT_EXIST);
        }
        return _reserves[_reserveId];
    }

    /// @dev Check if the the position token owner is correct.
    /// @param _positionTokenId postition token's Id
    /// @param _user owner's address
    function checkPositionTokenOwner(
        uint256 _positionTokenId,
        address _user,
        address _positionTokenAddress
    ) internal view {
        if (
            _user !=
            IPositionToken(_positionTokenAddress).ownerOf(_positionTokenId)
        ) {
            revert ReserveError(ReserveErrorCodes.NOT_POSITION_TOKEN_OWNER);
        }
    }

    /// @dev Check if the the position token hashes are the same.
    /// @param _hash1 First hash
    /// @param _hash2 Second hash
    function checkPositionTokenHash(bytes32 _hash1, bytes32 _hash2)
        internal
        pure
    {
        if (_hash1 != _hash2) {
            revert ReserveError(ReserveErrorCodes.INVALID_POSITION_TOKEN);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/Clones.sol)

pragma solidity ^0.8.0;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 *
 * _Available since v3.4._
 */
library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../../utils/DataTypes.sol";

interface IAirdropClaim {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
    enum AirdropClaimErrorCodes {
        ONLY_OWNER,
        ONLY_RESERVE_CONTRACT,
        INVALID_ASSET_TYPE,
        TIME_NOT_ELAPSED,
        COULD_NOT_SEND_KITTY,
        COULD_NOT_SEND_PUNK,
        RESTRICTED_ERC_20_FUNCTION,
        RESTRICTED_ERC_721_FUNCTION,
        RESTRICTED_ERC_1155_FUNCTION
    }

    error AirdropClaimError(AirdropClaimErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Claim Actions
    /// -----------------------------------------------------------------------

    /// @dev Initialize function
    /// @param owner Owner of the current clone
    /// @param timeLock Timestamp for reservation to end
    function initialize(address owner, uint256 timeLock) external;

    /// @dev Core function to claim air drops
    /// @notice This function should be called by the reserve contract after sending
    ///         _assets to this contract
    /// @param assets Assets sent to this contract as part of the function call
    /// @param _contract Address of the airdrop contract to call
    /// @param data Data to pass in the call, ie. Abi encoded function signature with parameters.
    function claimAirdrop(
        Assets calldata assets,
        address _contract,
        bytes calldata data
    ) external;

    /// @dev Core function to update completeness of reservation and update
    ///      owner of this contract. Must be called by reserve contract only
    /// @param _newOwner New owner of the contract
    function transferOwnershipAndCompleteReservation(address _newOwner)
        external;

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Core function to withdraw air dropped assets. Must be called by the
    ///      owner only and either timelock must have expired or reservation has completed
    /// @param tokens : Token addresses begin withdrawn from the contract
    /// @param tokenIds : Token ids of the tokens been airdropped. NOTE : This will be 0 case of ERC20
    /// @param amounts : Amount of tokens being withdrawn. NOTE : This must be 1 in case of ERC721
    /// @param types : Type of the asset
    /// @param to : Address to which the wthdrawn assets are sent
    function withdrawAssets(
        address[] calldata tokens,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        AssetType[] calldata types,
        address to
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../../utils/DataTypes.sol";

/// @title NF3 Reserve Interface
/// @author Jack Jin
/// @author Priyam Anand
/// @dev This interface defines all the functions related to reservation swap features of the platform.

interface IReserve {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum ReserveErrorCodes {
        NOT_MARKET,
        TIME_OVERFLOW,
        NOT_POSITION_TOKEN_OWNER,
        NOT_TIME_TO_CLAIM,
        OPTION_DOES_NOT_EXIST,
        INVALID_POSITION_TOKEN,
        INTENDED_FOR_PEER_TO_PEER_TRADE,
        INVALID_USER,
        INVALID_RESERVATION_DURATION,
        INVALID_ADDRESS
    }

    error ReserveError(ReserveErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when the offer has cancelled.
    /// @param offer Reservation offer info
    event ReserveOfferCancelled(ReserveOffer offer);

    /// @dev Emits when the collectoin offer has been cancelled
    /// @param offer Collection reserve offer info
    event CollectionReserveOfferCancelled(CollectionReserveOffer offer);

    /// @dev Emits when the buyer has deposited reserve assets.
    /// @param listing Listing info
    /// @param reservation Reservation info
    /// @param reserveId Reserve id
    /// @param positionTokenId Token if of the position token
    /// @param user Buyer address
    event ReserveDeposited(
        Listing listing,
        Reservation reservation,
        uint256 reserveId,
        uint256 positionTokenId,
        address indexed user
    );

    /// @dev Emits when the seller has accepted listed reservation offer.
    /// @param reservation Reservation info
    /// @param positionTokenId Token if of the position token
    /// @param user Listing owner
    event ListedReserveOfferAccepted(
        Listing listing,
        ReserveOffer offer,
        Reservation reservation,
        uint256 positionTokenId,
        address indexed user
    );

    /// @dev Emits when the offer has been accepted
    /// @param offer Reservation offer accepted
    /// @param reservation Reservation info
    /// @param considerationItems Assets given by the user
    /// @param positionTokenId Token id of the position token
    /// @param user Asset owner
    event UnlistedReserveOfferAccepted(
        ReserveOffer offer,
        Reservation reservation,
        Assets considerationItems,
        uint256 positionTokenId,
        address indexed user
    );

    /// @dev Emits when the collection offer has been accepted
    /// @param offer Reservation collection offer that is accepted
    /// @param considerationItem Assets given by the user
    /// @param reservation Reservation info
    /// @param positionTokenId TokenId of the position token for this trade
    /// @param user Assets owner
    event CollectionReserveOfferAccepted(
        CollectionReserveOffer offer,
        Assets considerationItem,
        Reservation reservation,
        uint256 positionTokenId,
        address indexed user
    );

    /// @dev Emits when the buyer has paid remaining reserve assets.
    /// @param reservation Reservation info
    /// @param positionTokenId Position token id
    /// @param user Buyer address
    event RemainsPaid(
        Reservation reservation,
        uint256 positionTokenId,
        address indexed user
    );

    /// @dev Emits when the seller has claimed locked assets.
    /// @param reservation Reservation info
    /// @param positionTokenId Position token id
    /// @param user Seller address
    event Claimed(
        Reservation reservation,
        uint256 positionTokenId,
        address user
    );

    /// @dev Emits when new market address has set.
    /// @param oldMarketAddress Previous market contract address
    /// @param newMarketAddress New market contract address
    event MarketSet(address oldMarketAddress, address newMarketAddress);

    /// @dev Emits when new swap address has set.
    /// @param oldSwapAddress Previous swap contract address
    /// @param newSwapAddress New swap contract address
    event SwapSet(address oldSwapAddress, address newSwapAddress);

    /// @dev Emits when new vault address has set.
    /// @param oldVaultAddress Previous vault contract address
    /// @param newVaultAddress New vault contract address
    event VaultSet(address oldVaultAddress, address newVaultAddress);

    /// @dev Emits when new position token address has set.
    /// @param oldPositionTokenAddress Previous position token contract address
    /// @param newPositionTokenAddress New position token contract address
    event PositionTokenSet(
        address oldPositionTokenAddress,
        address newPositionTokenAddress
    );

    /// @dev Emits when new whitelist contract address has set
    /// @param oldWhitelistAddress Previous whitelist contract address
    /// @param newWhitelistAddress New whitelist contract address
    event WhitelistSet(
        address oldWhitelistAddress,
        address newWhitelistAddress
    );

    /// @dev Emits when minimum reservation duration is updated
    /// @param oldMinimumReservationDuration Previous minimum reservation duration
    /// @param newMinimumReservationDuration New minimum reservation duration
    event MinimumReservationDurationSet(
        uint256 oldMinimumReservationDuration,
        uint256 newMinimumReservationDuration
    );

    /// @dev Emits when airdrop claim implementation address is set
    /// @param oldAirdropClaimImplementation Previous air drop claim implementation address
    /// @param newAirdropClaimImplementation New air drop claim implementation address
    event AirdropClaimImplementationSet(
        address oldAirdropClaimImplementation,
        address newAirdropClaimImplementation
    );

    /// -----------------------------------------------------------------------
    /// Cancel Actions
    /// -----------------------------------------------------------------------

    /// @dev Cancel reserve offer.
    /// @param offer Reserve offer info
    /// @param offerSignature Signature of the offer info
    /// @param user Offer owner
    function cancelReserveOffer(
        ReserveOffer calldata offer,
        bytes memory offerSignature,
        address user
    ) external;

    /// @dev Cancel collection reservation offer
    /// @param offer Collection reserve offer info
    /// @param signature Signature of the offer
    /// @param user Offer owner
    function cancelCollectionReserveOffer(
        CollectionReserveOffer calldata offer,
        bytes memory signature,
        address user
    ) external;

    /// -----------------------------------------------------------------------
    /// Reserve swap Actions
    /// -----------------------------------------------------------------------

    /// @dev Deposit reservation assets.
    /// @param listing Listing info
    /// @param listingSignature Signature of listing info
    /// @param reserveId Listing reserve id
    /// @param user Buyer address
    /// @param value Deposit Eth amount of buyer
    function reserveDeposit(
        Listing calldata listing,
        bytes memory listingSignature,
        uint256 reserveId,
        address user,
        uint256 value
    ) external;

    /// @dev Accept reservation offer using a listing.
    /// @param listing Listing info
    /// @param listingSignature Signature of listing info
    /// @param offer Reservation offer info
    /// @param offerSignature Signature of offer info
    /// @param user Listing owner address
    function acceptListedReserveOffer(
        Listing calldata listing,
        bytes memory listingSignature,
        ReserveOffer calldata offer,
        bytes memory offerSignature,
        bytes32[] calldata proof,
        address user
    ) external;

    /// @dev Accept reservation offer without listing
    /// @param offer Reservation offer info
    /// @param offerSignature Signature of offer info
    /// @param consideration Consideration assets provided for the offer
    /// @param proof merkle proof of the consideration assets
    /// @param user Listing owner address
    /// @param value Eth value sent along with the function call
    /// @param royalty Royalty offered by the user
    function acceptUnlistedReserveOffer(
        ReserveOffer calldata offer,
        bytes memory offerSignature,
        Assets calldata consideration,
        bytes32[] calldata proof,
        address user,
        uint256 value,
        Royalty calldata royalty
    ) external;

    /// @dev Accept resevation collection offer
    /// @param offer collection reserve offer
    /// @param signature Signature of the offer
    /// @param tokens Tokens begin offered
    /// @param tokenIds NFT Ids being offered
    /// @param proofs merkle proof that the tokenIds are valid
    /// @param user Address which accepted the offer
    /// @param value Eth value sent along
    /// @param royalty Seller's royalty info
    function acceptCollectionReserveOffer(
        CollectionReserveOffer calldata offer,
        bytes memory signature,
        address[] memory tokens,
        uint256[] memory tokenIds,
        bytes32[][] memory proofs,
        address user,
        uint256 value,
        Royalty calldata royalty
    ) external;

    /// @dev Pay remaining amount.
    /// @param reservation Reservation details
    /// @param positionTokenId Position token id
    /// @param user Buyer address
    /// @param value Remaining Eth amount of buyer
    /// @param royalty Buyer's royalty info
    function payRemains(
        Reservation calldata reservation,
        uint256 positionTokenId,
        address user,
        uint256 value,
        Royalty calldata royalty
    ) external;

    /// @dev Claim the seller's locked assets from the vault when the time is over.
    /// @param reservation Reservation details
    /// @param positionTokenId Position token id
    /// @param user Buyer address
    function claimDefaulted(
        Reservation calldata reservation,
        uint256 positionTokenId,
        address user
    ) external;

    /// @dev Claim ongoing airdrops using the reserved assets
    /// @param reservation Reservation details
    /// @param positionTokenId Position token id
    /// @param airdropContract Address of the air drop contract
    /// @param data Data to pass in the call, ie. ABI encoded function signature with params
    /// @param user function caller's address
    function claimAirdrop(
        Reservation calldata reservation,
        uint256 positionTokenId,
        address airdropContract,
        bytes calldata data,
        address user
    ) external;

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Set Market contract address.
    /// @param marketAddress Market contract address
    function setMarket(address marketAddress) external;

    /// @dev Set Swap contract address.
    /// @param swapAddress Swap contract address
    function setSwap(address swapAddress) external;

    /// @dev Set Vault contract address.
    /// @param vaultAddress Vault contract address
    function setVault(address vaultAddress) external;

    /// @dev Set Position token contract address.
    /// @param positionTokenAddress Position token contract address
    function setPositionToken(address positionTokenAddress) external;

    /// @dev Set Whitelist contract address.
    /// @param whitelistAddress Whitelist contract address
    function setWhitelist(address whitelistAddress) external;

    /// @dev Set air drop claim contract implementation address
    /// @param airdropClaimImplementation Airdrop claim contract address
    function setAirdropClaimImplementation(address airdropClaimImplementation)
        external;

    /// @dev Set minimum reservation duration
    /// @param minimumReservationDuration Minimum reservation duration
    function setMinimumReservationDuration(uint256 minimumReservationDuration)
        external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../../utils/DataTypes.sol";

/// @title NF3 Swap Interface
/// @author Jack Jin
/// @author Priyam Anand
/// @dev This interface defines all the functions related to swap features of the platform.

interface ISwap {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum SwapErrorCodes {
        NOT_MARKET,
        CALLER_NOT_APPROVED,
        INVALID_NONCE,
        ITEM_EXPIRED,
        OPTION_DOES_NOT_EXIST,
        INTENDED_FOR_PEER_TO_PEER_TRADE,
        INVALID_ADDRESS
    }

    error SwapError(SwapErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when listing has cancelled.
    /// @param listing Listing assets, details and seller's info
    event ListingCancelled(Listing listing);

    /// @dev Emits when swap offer has cancelled.
    /// @param offer Offer information
    event SwapOfferCancelled(SwapOffer offer);

    /// @dev Emits when collection offer has cancelled.
    /// @param offer Offer information
    event CollectionSwapOfferCancelled(CollectionSwapOffer offer);

    /// @dev Emits when direct swap has happened.
    /// @param listing Listing assets, details and seller's info
    /// @param offeredAssets Assets offered by the buyer
    /// @param swapId Swap id
    /// @param user Address of the buyer
    event DirectSwapped(
        Listing listing,
        Assets offeredAssets,
        uint256 swapId,
        address indexed user
    );

    /// @dev Emits when swap offer has been accepted by the user.
    /// @param offer Swap offer assets and details
    /// @param considerationItems Assets given by the user
    /// @param user Address of the user who accepted the offer
    event UnlistedSwapOfferAccepted(
        SwapOffer offer,
        Assets considerationItems,
        address indexed user
    );

    /// @dev Emits when swap offer has been accepted by a listing owner.
    /// @param listing Listing assets info
    /// @param offer Swap offer info
    /// @param user Listing owner
    event ListedSwapOfferAccepted(
        Listing listing,
        SwapOffer offer,
        address indexed user
    );

    /// @dev Emits when collection swap offer has accepted by the seller.
    /// @param offer Collection offer assets and details
    /// @param considerationItems Assets given by the seller
    /// @param user Address of the buyer
    event CollectionSwapOfferAccepted(
        CollectionSwapOffer offer,
        Assets considerationItems,
        address indexed user
    );

    /// @dev Emits when status has changed.
    /// @param oldStatus Previous status
    /// @param newStatus New status
    event NonceSet(Status oldStatus, Status newStatus);

    /// @dev Emits when new market address has set.
    /// @param oldMarketAddress Previous market contract address
    /// @param newMarketAddress New market contract address
    event MarketSet(address oldMarketAddress, address newMarketAddress);

    /// @dev Emits when new reserve address has set.
    /// @param oldVaultAddress Previous vault contract address
    /// @param newVaultAddress New vault contract address
    event VaultSet(address oldVaultAddress, address newVaultAddress);

    /// @dev Emits when new reserve address has set.
    /// @param oldReserveAddress Previous reserve contract address
    /// @param newReserveAddress New reserve contract address
    event ReserveSet(address oldReserveAddress, address newReserveAddress);

    /// -----------------------------------------------------------------------
    /// Cancel Actions
    /// -----------------------------------------------------------------------

    /// @dev Cancel listing.
    /// @param listing Listing parameters
    /// @param signature Signature of the listing parameters
    /// @param user Listing owner
    function cancelListing(
        Listing calldata listing,
        bytes memory signature,
        address user
    ) external;

    /// @dev Cancel Swap offer.
    /// @param offer Collection offer patameter
    /// @param signature Signature of the offer patameters
    /// @param user Collection offer owner
    function cancelSwapOffer(
        SwapOffer calldata offer,
        bytes memory signature,
        address user
    ) external;

    /// @dev Cancel collection level offer.
    /// @param offer Collection offer patameter
    /// @param signature Signature of the offer patameters
    /// @param user Collection offer owner
    function cancelCollectionSwapOffer(
        CollectionSwapOffer calldata offer,
        bytes memory signature,
        address user
    ) external;

    /// -----------------------------------------------------------------------
    /// Swap Actions
    /// -----------------------------------------------------------------------

    /// @dev Direct swap of bundle of NFTs + FTs with other bundles.
    /// @param listing Listing assets and details
    /// @param signature Signature as a proof of listing
    /// @param swapId Index of swap option being used
    /// @param tokens NFT addresses being offered
    /// @param tokenIds Token ids of NFT being offered
    /// @param value Eth value sent in the function call
    /// @param royalty Buyer's royalty info
    function directSwap(
        Listing calldata listing,
        bytes memory signature,
        uint256 swapId,
        address user,
        address[] memory tokens,
        uint256[] memory tokenIds,
        bytes32[][] memory proofs,
        uint256 value,
        Royalty calldata royalty
    ) external;

    /// @dev Accpet unlisted direct swap offer.
    /// @dev User should see the swap offer and accpet that offer.
    /// @param offer Multi offer assets and details
    /// @param signature Signature as a proof of offer
    /// @param consideration Consideration assets been provided by the user
    /// @param proof Merkle proof that the considerationItems is valid
    /// @param user Address of the user who accepted this offer
    /// @param royalty Seller's royalty info
    function acceptUnlistedDirectSwapOffer(
        SwapOffer calldata offer,
        bytes memory signature,
        Assets calldata consideration,
        bytes32[] calldata proof,
        address user,
        uint256 value,
        Royalty calldata royalty
    ) external;

    /// @dev Accept listed direct swap offer.
    /// @dev Only listing owner should accept that offer.
    /// @param listing Listing assets and parameters
    /// @param listingSignature Signature as a proof of listing
    /// @param offer Offering assets and parameters
    /// @param offerSignature Signature as a proof of offer
    /// @param proof Mekrle proof that the listed assets are valid
    /// @param user Listing owner
    function acceptListedDirectSwapOffer(
        Listing calldata listing,
        bytes memory listingSignature,
        SwapOffer calldata offer,
        bytes memory offerSignature,
        bytes32[] calldata proof,
        address user
    ) external;

    /// @dev Accept collection offer.
    /// @dev Anyone who holds the consideration assets can accpet this offer.
    /// @param offer Collection offer assets and details
    /// @param signature Signature as a proof of offer
    /// @param tokens NFT addresses being offered
    /// @param tokenIds Token ids of NFT being offered
    /// @param user Seller address
    /// @param value Eth value send in the function call
    /// @param royalty Seller's royalty info
    function acceptCollectionOffer(
        CollectionSwapOffer memory offer,
        bytes memory signature,
        address[] memory tokens,
        uint256[] memory tokenIds,
        bytes32[][] memory proofs,
        address user,
        uint256 value,
        Royalty calldata royalty
    ) external;

    /// -----------------------------------------------------------------------
    /// Storage Actions
    /// -----------------------------------------------------------------------

    /// @dev Set the nonce value of a user. Can only be called by reserve contract.
    /// @param _owner Address of the user
    /// @param _nonce Nonce value of the user
    /// @param _status Status to be set
    function setNonce(
        address _owner,
        uint256 _nonce,
        Status _status
    ) external;

    /// -----------------------------------------------------------------------
    /// View actions
    /// -----------------------------------------------------------------------

    /// @dev Check if the nonce is in correct status.
    /// @param owner Owner address
    /// @param nonce Nonce value
    /// @param status Status of nonce
    function checkNonce(
        address owner,
        uint256 nonce,
        Status status
    ) external view;

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Set Market contract address.
    /// @param _marketAddress Market contract address
    function setMarket(address _marketAddress) external;

    /// @dev Set Vault contract address.
    /// @param _vaultAddress Vault contract address
    function setVault(address _vaultAddress) external;

    /// @dev Set Reserve contract address.
    /// @param _reserveAddress Reserve contract address
    function setReserve(address _reserveAddress) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../../utils/DataTypes.sol";

/// @title NF3 Vault Interface
/// @author Jack Jin
/// @author Priyam Anand
/// @dev This interface defines all the functions related to assets transfer and assets escrow.

interface IVault {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum VaultErrorCodes {
        CALLER_NOT_APPROVED,
        FAILED_TO_SEND_ETH,
        ETH_NOT_ALLOWED,
        INVALID_ASSET_TYPE,
        COULD_NOT_RECEIVE_KITTY,
        COULD_NOT_SEND_KITTY,
        INVALID_PUNK,
        COULD_NOT_RECEIVE_PUNK,
        COULD_NOT_SEND_PUNK,
        INVALID_ADDRESS
    }

    error VaultError(VaultErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when the assets have transferred.
    /// @param assets Assets
    /// @param from Sender address
    /// @param to Receiver address
    event AssetsTransferred(Assets assets, address from, address to);

    /// @dev Emits when the assets have been received by the vault.
    /// @param assets Assets
    /// @param from Sender address
    event AssetsReceived(Assets assets, address from);

    /// @dev Emits when the assets have been sent by the vault.
    /// @param assets Assets
    /// @param to Receiver address
    event AssetsSent(Assets assets, address to);

    /// @dev Emits when new swap address has set.
    /// @param oldSwapAddress Previous swap contract address
    /// @param newSwapAddress New swap contract address
    event SwapSet(address oldSwapAddress, address newSwapAddress);

    /// @dev Emits when new reserve address has set.
    /// @param oldReserveAddress Previous reserve contract address
    /// @param newReserveAddress New reserve contract address
    event ReserveSet(address oldReserveAddress, address newReserveAddress);

    /// @dev Emits when new whitelist contract address has set
    /// @param oldWhitelistAddress Previous whitelist contract address
    /// @param newWhitelistAddress New whitelist contract address
    event WhitelistSet(
        address oldWhitelistAddress,
        address newWhitelistAddress
    );

    /// @dev Emits when new loan contract address has set
    /// @param oldLoanAddress Previous loan contract address
    /// @param newLoanAddress New whitelist contract address
    event LoanSet(address oldLoanAddress, address newLoanAddress);

    /// -----------------------------------------------------------------------
    /// Transfer actions
    /// -----------------------------------------------------------------------

    /// @dev Transfer the assets "assets" from "from" to "to".
    /// @param assets Assets to be transfered
    /// @param from Sender address
    /// @param to Receiver address
    /// @param royalty Royalty info
    /// @param allowEth Bool variable if can send ETH or not
    function transferAssets(
        Assets calldata assets,
        address from,
        address to,
        Royalty calldata royalty,
        bool allowEth
    ) external;

    /// @dev Receive assets "assets" from "from" address to the vault
    /// @param assets Assets to be transfered
    /// @param from Sender address
    function receiveAssets(
        Assets calldata assets,
        address from,
        bool allowEth
    ) external;

    /// @dev Send assets "assets" from the vault to "_to" address
    /// @param assets Assets to be transfered
    /// @param to Receiver address
    /// @param royalty Royalty info
    function sendAssets(
        Assets calldata assets,
        address to,
        Royalty calldata royalty,
        bool allowEth
    ) external;

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Set Swap contract address.
    /// @param swapAddress Swap contract address
    function setSwap(address swapAddress) external;

    /// @dev Set Reserve contract address.
    /// @param reserveAddress Reserve contract address
    function setReserve(address reserveAddress) external;

    /// @dev Set Whitelist contract address.
    /// @param whitelistAddress Whitelist contract address
    function setWhitelist(address whitelistAddress) external;

    /// @dev Set Loan contract address
    /// @param loanAddress Whitelist contract address
    function setLoan(address loanAddress) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../../utils/DataTypes.sol";

/// @title NF3 Swap Interface
/// @author Jack Jin
/// @author Priyam Anand
/// @dev This interface defines all the functions related to whitelisting of tokens

interface IWhitelist {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum WhitelistErrorCodes {
        INVALID_ITEM
    }

    error WhitelistError(WhitelistErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when new tokens are whitelisted and their types are set
    /// @param tokens addresses of tokens that are whitelisted
    /// @param types type of token set to
    event TokensTypeSet(address[] tokens, AssetType[] types);

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    /// @dev Check if all the passed assets are whitelisted
    /// @param assets Assets to check on
    function checkAssetsWhitelist(Assets calldata assets) external view;

    /// @dev Check and return types of assets
    /// @param assets Assets to check on
    /// @return nftType types of nfts sent
    /// @return ftType types of fts sent
    function getAssetsTypes(Assets calldata assets)
        external
        view
        returns (AssetType[] memory, AssetType[] memory);

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Set types of the tokens passed
    /// @param tokens Tokens to set
    /// @param types Types of tokens
    function setTokenTypes(
        address[] calldata tokens,
        AssetType[] calldata types
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../../utils/DataTypes.sol";

/// @title NF3 Position Token Interface
/// @author Jack Jin
/// @author Priyam Anand
/// @dev This interface defines the functions related to position token contract.

interface IPositionToken {
    /// -----------------------------------------------------------------------
    /// Storage actions
    /// -----------------------------------------------------------------------

    /// @dev Mint the position token with listing and reserve info.
    /// @param reservation Reservation details of the trade
    /// @param user Buyer address
    function mint(Reservation memory reservation, address user)
        external
        returns (uint256);

    /// @dev Burn the position token.
    /// @param tokenId Position token id
    function burn(uint256 tokenId) external;

    /// -----------------------------------------------------------------------
    /// View actions
    /// -----------------------------------------------------------------------

    /// @dev Get the owner of position token id.
    /// @param tokenId Position token id
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @dev Get the data hash at the given tokenId.
    /// @param tokenId Position tokenId
    function dataHash(uint256 tokenId) external view returns (bytes32);

    /// @dev Get timestamp when the listing was reserved.
    /// @param tokenId Position tokenId
    function startTime(uint256 tokenId) external view returns (uint256);

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Set Reserve contract address.
    /// @param reserveAddress Reserve contract address
    function setReserve(address reserveAddress) external;

    /// @dev Set base uri.
    /// @param baseURI New base uri
    function setBaseURI(string memory baseURI) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../utils/DataTypes.sol";
import "../../utils/LoanDataTypes.sol";

/// @title NF3 Utils Library
/// @author Jack Jin
/// @author Priyam Anand
/// @dev This library contains all the pure functions that are used across the system of contracts.

library Utils {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum UtilsErrorCodes {
        INVALID_LISTING_SIGNATURE,
        INVALID_SWAP_OFFER_SIGNATURE,
        INVALID_COLLECTION_OFFER_SIGNATURE,
        INVALID_RESERVE_OFFER_SIGNATURE,
        INVALID_ITEMS,
        ONLY_OWNER,
        OWNER_NOT_ALLOWED,
        INVALID_LOAN_OFFER_SIGNATURE,
        INVALID_COLLECTION_LOAN_OFFER_SIGNATURE,
        INVALID_UPDATE_LOAN_OFFER_SIGNATURE,
        INVALID_COLLECTION_RESERVE_OFFER_SIGNATURE
    }

    error UtilsError(UtilsErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /* ===== Verify Signatures ===== */

    /// @dev Check the signature if the listing info is valid or not.
    /// @param _listing Listing info
    /// @param _signature Listing signature
    function verifyListingSignature(
        Listing calldata _listing,
        bytes memory _signature
    ) internal pure {
        address owner = getListingSignatureOwner(_listing, _signature);

        if (_listing.owner != owner) {
            revert UtilsError(UtilsErrorCodes.INVALID_LISTING_SIGNATURE);
        }
    }

    /// @dev Check the signature if the swap offer is valid or not.
    /// @param _offer Offer info
    /// @param _signature Offer signature
    function verifySwapOfferSignature(
        SwapOffer calldata _offer,
        bytes memory _signature
    ) internal pure {
        address owner = getSwapOfferSignatureOwner(_offer, _signature);

        if (_offer.owner != owner) {
            revert UtilsError(UtilsErrorCodes.INVALID_SWAP_OFFER_SIGNATURE);
        }
    }

    /// @dev Check the signature if the collection offer is valid or not.
    /// @param _offer Offer info
    /// @param _signature Offer signature
    function verifyCollectionSwapOfferSignature(
        CollectionSwapOffer calldata _offer,
        bytes memory _signature
    ) internal pure {
        address owner = getCollectionSwapOfferOwner(_offer, _signature);

        if (_offer.owner != owner) {
            revert UtilsError(
                UtilsErrorCodes.INVALID_COLLECTION_OFFER_SIGNATURE
            );
        }
    }

    /// @dev Check the signature if the reserve offer is valid or not.
    /// @param _offer Reserve offer info
    /// @param _signature Reserve offer signature
    function verifyReserveOfferSignature(
        ReserveOffer calldata _offer,
        bytes memory _signature
    ) internal pure {
        address owner = getReserveOfferSignatureOwner(_offer, _signature);

        if (_offer.owner != owner) {
            revert UtilsError(UtilsErrorCodes.INVALID_RESERVE_OFFER_SIGNATURE);
        }
    }

    /// @dev Check the signature if the loan offer is valid or not.
    /// @param _loanOffer Loan offer info
    /// @param _signature Loan offer signature
    function verifyLoanOfferSignature(
        LoanOffer calldata _loanOffer,
        bytes memory _signature
    ) internal pure {
        address owner = getLoanOfferOwer(_loanOffer, _signature);

        if (_loanOffer.owner != owner) {
            revert UtilsError(UtilsErrorCodes.INVALID_LOAN_OFFER_SIGNATURE);
        }
    }

    /// @dev Check the signature if the collection loan offer is valid or not.
    /// @param _loanOffer Collection loan offer info
    /// @param _signature Collection loan offer signature
    function verifyCollectionLoanOfferSignature(
        CollectionLoanOffer calldata _loanOffer,
        bytes memory _signature
    ) internal pure {
        address owner = getCollectionLoanOwner(_loanOffer, _signature);

        if (_loanOffer.owner != owner) {
            revert UtilsError(
                UtilsErrorCodes.INVALID_COLLECTION_LOAN_OFFER_SIGNATURE
            );
        }
    }

    function verifyCollectionReserveOfferSignature(
        CollectionReserveOffer calldata _offer,
        bytes memory _signature
    ) internal pure {
        address owner = getCollectionReserveOfferOwner(_offer, _signature);

        if (_offer.owner != owner) {
            revert UtilsError(
                UtilsErrorCodes.INVALID_COLLECTION_RESERVE_OFFER_SIGNATURE
            );
        }
    }

    /// @dev Check the signature if the update loan offer is valid or not.
    /// @param _loanOffer Update loan offer info
    /// @param _signature Update loan offer signature
    function verifyUpdateLoanSignature(
        LoanUpdateOffer calldata _loanOffer,
        bytes memory _signature
    ) internal pure {
        address owner = getUpdateLoanOfferOwner(_loanOffer, _signature);

        if (_loanOffer.owner != owner) {
            revert UtilsError(
                UtilsErrorCodes.INVALID_UPDATE_LOAN_OFFER_SIGNATURE
            );
        }
    }

    /* ===== Verify Assets ===== */

    /// @dev Verify assets1 and assets2 if they are the same.
    /// @param _assets1 First assets
    /// @param _assets2 Second assets
    function verifyAssets(Assets calldata _assets1, Assets calldata _assets2)
        internal
        pure
    {
        if (
            _assets1.paymentTokens.length != _assets2.paymentTokens.length ||
            _assets1.tokens.length != _assets2.tokens.length
        ) revert UtilsError(UtilsErrorCodes.INVALID_ITEMS);

        unchecked {
            uint256 i;
            for (i = 0; i < _assets1.paymentTokens.length; i++) {
                if (
                    _assets1.paymentTokens[i] != _assets2.paymentTokens[i] ||
                    _assets1.amounts[i] != _assets2.amounts[i]
                ) revert UtilsError(UtilsErrorCodes.INVALID_ITEMS);
            }

            for (i = 0; i < _assets1.tokens.length; i++) {
                if (
                    _assets1.tokens[i] != _assets2.tokens[i] ||
                    _assets1.tokenIds[i] != _assets2.tokenIds[i]
                ) revert UtilsError(UtilsErrorCodes.INVALID_ITEMS);
            }
        }
    }

    /// @dev Verify swap assets to be satisfied as the consideration items by the seller.
    /// @param _swapAssets Swap assets
    /// @param _tokens NFT addresses
    /// @param _tokenIds NFT token ids
    /// @param _value Eth value
    /// @return assets Verified swap assets
    function verifySwapAssets(
        SwapAssets memory _swapAssets,
        address[] memory _tokens,
        uint256[] memory _tokenIds,
        bytes32[][] memory _proofs,
        uint256 _value
    ) internal pure returns (Assets memory) {
        uint256 ethAmount;
        uint256 i;

        // check Eth amounts
        for (i = 0; i < _swapAssets.paymentTokens.length; ) {
            if (_swapAssets.paymentTokens[i] == address(0))
                ethAmount += _swapAssets.amounts[i];
            unchecked {
                ++i;
            }
        }
        if (ethAmount > _value) {
            revert UtilsError(UtilsErrorCodes.INVALID_ITEMS);
        }

        unchecked {
            // check compatible NFTs
            for (i = 0; i < _swapAssets.tokens.length; i++) {
                if (
                    _swapAssets.tokens[i] != _tokens[i] ||
                    (!verifyMerkleProof(
                        _swapAssets.roots[i],
                        _proofs[i],
                        keccak256(abi.encodePacked(_tokenIds[i]))
                    ) && _swapAssets.roots[i] != bytes32(0))
                ) {
                    revert UtilsError(UtilsErrorCodes.INVALID_ITEMS);
                }
            }
        }

        return
            Assets(
                _tokens,
                _tokenIds,
                _swapAssets.paymentTokens,
                _swapAssets.amounts
            );
    }

    /// @dev Verify if the passed asset is present in the merkle root passed.
    /// @param _root Merkle root to check in
    /// @param _consideration Consideration assets
    /// @param _proof Merkle proof
    function verifyAssetProof(
        bytes32 _root,
        Assets calldata _consideration,
        bytes32[] calldata _proof
    ) internal pure {
        bytes32 _leaf = addAssets(_consideration, bytes32(0));

        if (!verifyMerkleProof(_root, _proof, _leaf)) {
            revert UtilsError(UtilsErrorCodes.INVALID_ITEMS);
        }
    }

    /* ===== Check Validations ===== */

    /// @dev Check if the ETH amount is valid.
    /// @param _assets Assets
    /// @param _value ETH amount
    function checkEthAmount(Assets memory _assets, uint256 _value)
        internal
        pure
    {
        uint256 ethAmount;

        for (uint256 i = 0; i < _assets.paymentTokens.length; ) {
            if (_assets.paymentTokens[i] == address(0))
                ethAmount += _assets.amounts[i];
            unchecked {
                ++i;
            }
        }
        if (ethAmount > _value) {
            revert UtilsError(UtilsErrorCodes.INVALID_ITEMS);
        }
    }

    /// @dev Check if the function is called by the item owner.
    /// @param _owner Owner address
    /// @param _caller Caller address
    function itemOwnerOnly(address _owner, address _caller) internal pure {
        if (_owner != _caller) {
            revert UtilsError(UtilsErrorCodes.ONLY_OWNER);
        }
    }

    /// @dev Check if the function is not called by the item owner.
    /// @param _owner Owner address
    /// @param _caller Caller address
    function notItemOwner(address _owner, address _caller) internal pure {
        if (_owner == _caller) {
            revert UtilsError(UtilsErrorCodes.OWNER_NOT_ALLOWED);
        }
    }

    /* ===== Get Functions ===== */

    /// @dev Get the hash of data saved in position token.
    /// @param _listingAssets Listing assets
    /// @param _reserveInfo Reserve ino
    /// @param _listingOwner Listing owner
    /// @return hash Hash of the passed data
    function getPostitionTokenDataHash(
        Assets calldata _listingAssets,
        ReserveInfo calldata _reserveInfo,
        address _listingOwner
    ) internal pure returns (bytes32 hash) {
        hash = addAssets(_listingAssets, hash);

        hash = keccak256(
            abi.encodePacked(getReserveHash(_reserveInfo), _listingOwner, hash)
        );
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    /* ===== Get Owner Of Signatures ===== */

    /// @dev Get the signature owner from listing data info and its signature.
    /// @param _listing Listing info
    /// @param _signature Listing signature
    /// @return owner Listing signature owner
    function getListingSignatureOwner(
        Listing calldata _listing,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = getListingHash(_listing);

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    /// @dev Get the signature owner from the swap offer info and its signature.
    /// @param _offer Swap offer info
    /// @param _signature Swap offer signature
    /// @return owner Swap offer signature owner
    function getSwapOfferSignatureOwner(
        SwapOffer calldata _offer,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = getSwapOfferHash(_offer);

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    /// @dev Get the signature owner from collection offer info and its signature.
    /// @param _offer Collection offer info
    /// @param _signature Collection offer signature
    /// @return owner Collection offer signature owner
    function getCollectionSwapOfferOwner(
        CollectionSwapOffer calldata _offer,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = getCollectionSwapOfferHash(_offer);

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    /// @dev Get the signature owner from reserve offer info and its signature.
    /// @param _offer Reserve offer info
    /// @param _signature Reserve offer signature
    /// @return owner Reserve offer signature owner
    function getReserveOfferSignatureOwner(
        ReserveOffer calldata _offer,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = getReserveOfferHash(_offer);

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    function getCollectionReserveOfferOwner(
        CollectionReserveOffer calldata _offer,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = getCollectionReserveOfferHash(_offer);

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    /// @dev Get the signature owner from loan offer info and its signature.
    /// @param _loanOffer Loan offer info
    /// @param _signature Loan offer signature
    /// @return owner Signature owner
    function getLoanOfferOwer(
        LoanOffer calldata _loanOffer,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                _loanOffer.nftCollateralContract,
                _loanOffer.nftCollateralId,
                _loanOffer.owner,
                _loanOffer.nonce,
                _loanOffer.loanPaymentToken,
                _loanOffer.loanPrincipalAmount,
                _loanOffer.maximumRepaymentAmount,
                _loanOffer.loanDuration,
                _loanOffer.loanInterestRate,
                _loanOffer.adminFees,
                _loanOffer.isLoanProrated,
                _loanOffer.isBorrowerTerms
            )
        );

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    /// @dev Get the signature owner from collection loan offer info and its signature.
    /// @param _loanOffer Collection loan offer info
    /// @param _signature Collection loan offer signature
    /// @return owner Signature owner
    function getCollectionLoanOwner(
        CollectionLoanOffer calldata _loanOffer,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                _loanOffer.nftCollateralContract,
                _loanOffer.nftCollateralIdRoot,
                _loanOffer.owner,
                _loanOffer.nonce,
                _loanOffer.loanPaymentToken,
                _loanOffer.loanPrincipalAmount,
                _loanOffer.maximumRepaymentAmount,
                _loanOffer.loanDuration,
                _loanOffer.loanInterestRate,
                _loanOffer.adminFees,
                _loanOffer.isLoanProrated
            )
        );

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    /// @dev Get the signature owner from update loan offer info and its signature.
    /// @param _loanOffer Update loan offer info
    /// @param _signature Update loan offer signature
    /// @return owner Signature owner
    function getUpdateLoanOfferOwner(
        LoanUpdateOffer calldata _loanOffer,
        bytes memory _signature
    ) internal pure returns (address owner) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                _loanOffer.loanId,
                _loanOffer.maximumRepaymentAmount,
                _loanOffer.loanDuration,
                _loanOffer.loanInterestRate,
                _loanOffer.owner,
                _loanOffer.nonce,
                _loanOffer.isLoanProrated,
                _loanOffer.isBorrowerTerms
            )
        );

        bytes32 signedHash = getSignedMessageHash(hash);

        owner = ECDSA.recover(signedHash, _signature);
    }

    /* ===== Get Hash ===== */

    /// @dev Get the hash of listing info.
    /// @param _listing Listing info
    /// @return hash Hash of the listing info
    function getListingHash(Listing calldata _listing)
        internal
        pure
        returns (bytes32)
    {
        bytes32 signature;
        uint256 i;

        signature = addAssets(_listing.listingAssets, signature);

        unchecked {
            for (i = 0; i < _listing.directSwaps.length; i++) {
                signature = addSwapAssets(_listing.directSwaps[i], signature);
            }

            for (i = 0; i < _listing.reserves.length; i++) {
                signature = addAssets(_listing.reserves[i].deposit, signature);
                signature = addAssets(
                    _listing.reserves[i].remaining,
                    signature
                );
                signature = keccak256(
                    abi.encodePacked(_listing.reserves[i].duration, signature)
                );
            }
        }

        signature = addRoyalty(_listing.royalty, signature);

        signature = keccak256(
            abi.encodePacked(
                _listing.tradeIntendedFor,
                _listing.timePeriod,
                _listing.owner,
                _listing.nonce,
                signature
            )
        );

        return signature;
    }

    /// @dev Get the hash of the swap offer info.
    /// @param _offer Offer info
    /// @return hash Hash of the offer
    function getSwapOfferHash(SwapOffer calldata _offer)
        internal
        pure
        returns (bytes32)
    {
        bytes32 signature;

        signature = addAssets(_offer.offeringItems, signature);

        signature = addRoyalty(_offer.royalty, signature);

        signature = keccak256(
            abi.encodePacked(
                _offer.considerationRoot,
                _offer.timePeriod,
                _offer.owner,
                _offer.nonce,
                signature
            )
        );

        return signature;
    }

    /// @dev Get the hash of collection offer info.
    /// @param _offer Collection offer info
    /// @return hash Hash of the collection offer info
    function getCollectionSwapOfferHash(CollectionSwapOffer calldata _offer)
        internal
        pure
        returns (bytes32)
    {
        bytes32 signature;

        signature = addAssets(_offer.offeringItems, signature);

        signature = addSwapAssets(_offer.considerationItems, signature);

        signature = addRoyalty(_offer.royalty, signature);

        signature = keccak256(
            abi.encodePacked(
                _offer.timePeriod,
                _offer.owner,
                _offer.nonce,
                signature
            )
        );

        return signature;
    }

    /// @dev Get the hash of reserve offer info.
    /// @param _offer Reserve offer info
    /// @return hash Hash of the reserve offer info
    function getReserveOfferHash(ReserveOffer calldata _offer)
        internal
        pure
        returns (bytes32)
    {
        bytes32 signature;

        signature = getReserveHash(_offer.reserveDetails);

        signature = addRoyalty(_offer.royalty, signature);

        signature = keccak256(
            abi.encodePacked(
                _offer.considerationRoot,
                _offer.timePeriod,
                _offer.owner,
                _offer.nonce,
                signature
            )
        );

        return signature;
    }

    function getCollectionReserveOfferHash(
        CollectionReserveOffer calldata _offer
    ) internal pure returns (bytes32) {
        bytes32 signature;
        signature = getReserveHash(_offer.reserveDetails);
        signature = addSwapAssets(_offer.considerationItems, signature);
        signature = addRoyalty(_offer.royalty, signature);

        signature = keccak256(
            abi.encodePacked(
                _offer.timePeriod,
                _offer.owner,
                _offer.nonce,
                signature
            )
        );

        return signature;
    }

    /// @dev Get the hash of reserve info.
    /// @param _reserve Reserve info
    /// @return hash Hash of the reserve info
    function getReserveHash(ReserveInfo calldata _reserve)
        internal
        pure
        returns (bytes32)
    {
        bytes32 signature;

        signature = addAssets(_reserve.deposit, signature);

        signature = addAssets(_reserve.remaining, signature);

        signature = keccak256(abi.encodePacked(_reserve.duration, signature));

        return signature;
    }

    /// @dev Get the hash of the given pair of hashes.
    /// @param _a First hash
    /// @param _b Second hash
    function getHash(bytes32 _a, bytes32 _b) internal pure returns (bytes32) {
        return _a < _b ? _hash(_a, _b) : _hash(_b, _a);
    }

    /// @dev Hash two bytes32 variables efficiently using assembly
    /// @param a First bytes variable
    /// @param b Second bytes variable
    function _hash(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    /// @dev Get the final signed hash by appending the prefix to params hash.
    /// @param _messageHash Hash of the params message
    /// @return hash Final signed hash
    function getSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    /* ===== Verify Merkle Proof ===== */

    /// @dev Verify that the given leaf exist in the passed root and has the correct proof.
    /// @param _root Merkle root of the given criterial
    /// @param _proof Merkle proof of the given leaf and root
    /// @param _leaf Hash of the token id to be searched in the root
    /// @return bool Validation of the leaf, root and proof
    function verifyMerkleProof(
        bytes32 _root,
        bytes32[] memory _proof,
        bytes32 _leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = _leaf;

        unchecked {
            for (uint256 i = 0; i < _proof.length; i++) {
                computedHash = getHash(computedHash, _proof[i]);
            }
        }

        return computedHash == _root;
    }

    /* ===== Make Signature Hashes ===== */

    /// @dev Add the hash of type assets to signature.
    /// @param _assets Assets to be added in hash
    /// @param _sig Hash to which assets need to be added
    /// @return hash Hash result
    function addAssets(Assets calldata _assets, bytes32 _sig)
        internal
        pure
        returns (bytes32)
    {
        _sig = addNFTsArray(_assets.tokens, _assets.tokenIds, _sig);
        _sig = addFTsArray(_assets.paymentTokens, _assets.amounts, _sig);

        return _sig;
    }

    /// @dev Add the hash of type swap assets to signature.
    /// @param _assets Assets to be added in hash
    /// @param _sig Hash to which assets need to be added
    /// @return hash Hash result
    function addSwapAssets(SwapAssets calldata _assets, bytes32 _sig)
        internal
        pure
        returns (bytes32)
    {
        _sig = addSwapNFTsArray(_assets.tokens, _assets.roots, _sig);
        _sig = addFTsArray(_assets.paymentTokens, _assets.amounts, _sig);

        return _sig;
    }

    /// @dev Add the hash of type royalty to signature.
    /// @param _royalty Royalty struct
    /// @param _sig Hash to which assets need to be added
    /// @return hash Hash result
    function addRoyalty(Royalty calldata _royalty, bytes32 _sig)
        internal
        pure
        returns (bytes32)
    {
        unchecked {
            for (uint256 i = 0; i < _royalty.to.length; i++) {
                _sig = keccak256(
                    abi.encodePacked(
                        _royalty.to[i],
                        _royalty.percentage[i],
                        _sig
                    )
                );
            }
            return _sig;
        }
    }

    /// @dev Add the hash of NFT information to signature.
    /// @param _tokens Array of nft address to be hashed
    /// @param _tokenIds Array of NFT tokenIds to be hashed
    /// @param _sig Hash to which assets need to be added
    /// @return hash Hash result
    function addNFTsArray(
        address[] memory _tokens,
        uint256[] memory _tokenIds,
        bytes32 _sig
    ) internal pure returns (bytes32) {
        assembly {
            let len := mload(_tokens)
            if eq(eq(len, mload(_tokenIds)), 0) {
                revert(0, 0)
            }

            let fmp := mload(0x40)

            let tokenPtr := add(_tokens, 0x20)
            let idPtr := add(_tokenIds, 0x20)

            for {
                let tokenIdx := tokenPtr
            } lt(tokenIdx, add(tokenPtr, mul(len, 0x20))) {
                tokenIdx := add(tokenIdx, 0x20)
                idPtr := add(idPtr, 0x20)
            } {
                mstore(fmp, mload(tokenIdx))
                mstore(add(fmp, 0x20), mload(idPtr))
                mstore(add(fmp, 0x40), _sig)

                _sig := keccak256(add(fmp, 0xc), 0x54)
            }
        }
        return _sig;
    }

    /// @dev Add the hash of FT information to signature.
    /// @param _paymentTokens Array of FT address to be hashed
    /// @param _amounts Array of FT amounts to be hashed
    /// @param _sig Hash to which assets need to be added
    /// @return hash Hash result
    function addFTsArray(
        address[] memory _paymentTokens,
        uint256[] memory _amounts,
        bytes32 _sig
    ) internal pure returns (bytes32) {
        assembly {
            let len := mload(_paymentTokens)
            if eq(eq(len, mload(_amounts)), 0) {
                revert(0, 0)
            }

            let fmp := mload(0x40)

            let tokenPtr := add(_paymentTokens, 0x20)
            let idPtr := add(_amounts, 0x20)

            for {
                let tokenIdx := tokenPtr
            } lt(tokenIdx, add(tokenPtr, mul(len, 0x20))) {
                tokenIdx := add(tokenIdx, 0x20)
                idPtr := add(idPtr, 0x20)
            } {
                mstore(fmp, mload(tokenIdx))
                mstore(add(fmp, 0x20), mload(idPtr))
                mstore(add(fmp, 0x40), _sig)
                _sig := keccak256(add(fmp, 0xc), 0x54)
            }
        }
        return _sig;
    }

    /// @dev Add the hash of NFT information to signature.
    /// @param _tokens Array of nft address to be hashed
    /// @param _roots Array of valid tokenId's merkle root to be hashed
    /// @param _sig Hash to which assets need to be added
    /// @return hash Hash result
    function addSwapNFTsArray(
        address[] memory _tokens,
        bytes32[] memory _roots,
        bytes32 _sig
    ) internal pure returns (bytes32) {
        assembly {
            let len := mload(_tokens)
            if eq(eq(len, mload(_roots)), 0) {
                revert(0, 0)
            }

            let fmp := mload(0x40)

            let tokenPtr := add(_tokens, 0x20)
            let idPtr := add(_roots, 0x20)

            for {
                let tokenIdx := tokenPtr
            } lt(tokenIdx, add(tokenPtr, mul(len, 0x20))) {
                tokenIdx := add(tokenIdx, 0x20)
                idPtr := add(idPtr, 0x20)
            } {
                mstore(fmp, mload(tokenIdx))
                mstore(add(fmp, 0x20), mload(idPtr))
                mstore(add(fmp, 0x40), _sig)

                _sig := keccak256(add(fmp, 0xc), 0x54)
            }
        }
        return _sig;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/// @dev Royalties for collection creators and platform fee for platform manager.
///      to[0] is platform owner address.
/// @param to Creators and platform manager address array
/// @param percentage Royalty percentage based on the listed FT
struct Royalty {
    address[] to;
    uint256[] percentage;
}

/// @dev Common Assets type, packing bundle of NFTs and FTs.
/// @param tokens NFT asset address
/// @param tokenIds NFT token id
/// @param paymentTokens FT asset address
/// @param amounts FT token amount
struct Assets {
    address[] tokens;
    uint256[] tokenIds;
    address[] paymentTokens;
    uint256[] amounts;
}

/// @dev Common SwapAssets type, packing Bundle of NFTs and FTs. Notice tokenIds is a 2d array.
///      Each collection address ie. tokens[i] will have an array tokenIds[i] corrosponding to it.
///      This is used to select particular tokenId in corrospoding collection. If tokenIds[i]
///      is empty, this means the entire collection is considered valid.
/// @param tokens NFT asset address
/// @param roots Merkle roots of the criterias. NOTE: bytes32(0) represents the entire collection
/// @param paymentTokens FT asset address
/// @param amounts FT token amount
struct SwapAssets {
    address[] tokens;
    bytes32[] roots;
    address[] paymentTokens;
    uint256[] amounts;
}

/// @dev Common Reserve type, packing data related to reserve listing and reserve offer.
/// @param deposit Assets considered as initial deposit
/// @param remaining Assets considered as due amount
/// @param duration Duration of reserve now swap later
struct ReserveInfo {
    Assets deposit;
    Assets remaining;
    uint256 duration;
}

/// @dev All the reservation details that are stored in the position token
/// @param reservedAssets Assets that were reserved as a part of the reservation
/// @param reservedAssestsRoyalty Royalty offered by the assets owner
/// @param reserveInfo Deposit, remainig and time duriation details of the reservation
/// @param assetOwner Original owner of the reserved assets
struct Reservation {
    Assets reservedAssets;
    Royalty reservedAssetsRoyalty;
    ReserveInfo reserveInfo;
    address assetOwner;
}

/// @dev Listing type, packing the assets being listed, listing parameters, listing owner
///      and users's nonce.
/// @param listingAssets All the assets listed
/// @param directSwaps List of options for direct swap
/// @param reserves List of options for reserve now swap later
/// @param royalty Listing royalty and platform fee info
/// @param timePeriod Time period of listing
/// @param owner Owner's address
/// @param nonce User's nonce
struct Listing {
    Assets listingAssets;
    SwapAssets[] directSwaps;
    ReserveInfo[] reserves;
    Royalty royalty;
    address tradeIntendedFor;
    uint256 timePeriod;
    address owner;
    uint256 nonce;
}

/// @dev Listing type of special NF3 banner listing
/// @param token address of collection
/// @param tokenId token id being listed
/// @param editions number of tokenIds being distributed
/// @param gateCollectionsRoot merkle root for eligible collections
/// @param timePeriod timePeriod of listing
/// @param owner owner of listing
struct NF3GatedListing {
    address token;
    uint256 tokenId;
    uint256 editions;
    bytes32 gatedCollectionsRoot;
    uint256 timePeriod;
    address owner;
}

/// @dev Swap Offer type info.
/// @param offeringItems Assets being offered
/// @param royalty Swap offer royalty info
/// @param considerationRoot Assets to which this offer is made
/// @param timePeriod Time period of offer
/// @param owner Offer owner
/// @param nonce Offer nonce
struct SwapOffer {
    Assets offeringItems;
    Royalty royalty;
    bytes32 considerationRoot;
    uint256 timePeriod;
    address owner;
    uint256 nonce;
}

/// @dev Reserve now swap later type offer info.
/// @param reserveDetails Reservation scheme begin offered
/// @param considerationRoot Assets to which this offer is made
/// @param royalty Reserve offer royalty info
/// @param timePeriod Time period of offer
/// @param owner Offer owner
/// @param nonce Offer nonce
struct ReserveOffer {
    ReserveInfo reserveDetails;
    bytes32 considerationRoot;
    Royalty royalty;
    uint256 timePeriod;
    address owner;
    uint256 nonce;
}

/// @dev Collection offer type info.
/// @param offeringItems Assets being offered
/// @param considerationItems Assets to which this offer is made
/// @param royalty Collection offer royalty info
/// @param timePeriod Time period of offer
/// @param owner Offer owner
/// @param nonce Offer nonce
struct CollectionSwapOffer {
    Assets offeringItems;
    SwapAssets considerationItems;
    Royalty royalty;
    uint256 timePeriod;
    address owner;
    uint256 nonce;
}

/// @dev Collection Reserve type offer info.
/// @param reserveDetails Reservation scheme begin offered
/// @param considerationItems Assets to which this offer is made
/// @param royalty Reserve offer royalty info
/// @param timePeriod Time period of offer
/// @param owner Offer owner
/// @param nonce Offer nonce
struct CollectionReserveOffer {
    ReserveInfo reserveDetails;
    SwapAssets considerationItems;
    Royalty royalty;
    uint256 timePeriod;
    address owner;
    uint256 nonce;
}

enum Status {
    AVAILABLE,
    EXHAUSTED
}

enum AssetType {
    INVALID,
    ETH,
    ERC_20,
    ERC_721,
    ERC_1155,
    KITTIES,
    PUNK
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.3) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/// @dev Common loan offer struct to be used both the borrower and lender
///      to propose new offers,
/// @param nftCollateralContract Address of the NFT contract
/// @param nftCollateralId NFT collateral token id
/// @param owner Offer owner address
/// @param nonce Nonce of owner
/// @param loanPaymentToken Address of the loan payment token
/// @param loanPrincipalAmount Principal amount of the loan
/// @param maximumRepaymentAmount Maximum amount to be repayed
/// @param loanDuration Duration of the loan
/// @param loanInterestRate Interest rate of the loan
/// @param adminFees Admin fees in basis points
/// @param isLoanProrated Flag for interest rate type of loan
/// @param isBorrowerTerms Bool value to represent if borrower's terms were accepted.
///        - if this value is true, this mean msg.sender must be the lender.
///        - if this value is false, this means lender's terms were accepted and msg.sender
///          must be the borrower.
struct LoanOffer {
    address nftCollateralContract;
    uint256 nftCollateralId;
    address owner;
    uint256 nonce;
    address loanPaymentToken;
    uint256 loanPrincipalAmount;
    uint256 maximumRepaymentAmount;
    uint256 loanDuration;
    uint256 loanInterestRate;
    uint256 adminFees;
    bool isLoanProrated;
    bool isBorrowerTerms;
}

/// @dev Collection loan offer struct to be used to making collection
///      specific offers and trait level offers.
/// @param nftCollateralContract Address of the NFT contract
/// @param nftCollateralIdRoot Merkle root of the tokenIds for collateral
/// @param owner Offer owner address
/// @param nonce Nonce of owner
/// @param loanPaymentToken Address of the loan payment token
/// @param loanPrincipalAmount Principal amount of the loan
/// @param maximumRepaymentAmount Maximum amount to be repayed
/// @param loanDuration Duration of the loan
/// @param loanInterestRate Interest rate of the loan
/// @param adminFees Admin fees in basis points
/// @param isLoanProrated Flag for interest rate type of loan
struct CollectionLoanOffer {
    address nftCollateralContract;
    bytes32 nftCollateralIdRoot;
    address owner;
    uint256 nonce;
    address loanPaymentToken;
    uint256 loanPrincipalAmount;
    uint256 maximumRepaymentAmount;
    uint256 loanDuration;
    uint256 loanInterestRate;
    uint256 adminFees;
    bool isLoanProrated;
}

/// @dev Update loan offer struct to propose new terms for an ongoing loan.
/// @param loanId Id of the loan, same as promissory tokenId
/// @param maximumRepaymentAmount Maximum amount to be repayed
/// @param loanDuration Duration of the loan
/// @param loanInterestRate Interest rate of the loan
/// @param owner Offer owner address
/// @param nonce Nonce of owner
/// @param isLoanProrated Flag for interest rate type of loan
/// @param isBorrowerTerms Bool value to represent if borrower's terms were accepted.
///        - if this value is true, this mean msg.sender must be the lender.
///        - if this value is false, this means lender's terms were accepted and msg.sender
///          must be the borrower.
struct LoanUpdateOffer {
    uint256 loanId;
    uint256 maximumRepaymentAmount;
    uint256 loanDuration;
    uint256 loanInterestRate;
    address owner;
    uint256 nonce;
    bool isLoanProrated;
    bool isBorrowerTerms;
}

/// @dev Main loan struct that stores the details of an ongoing loan.
///      This struct is used to create hashes and store them in promissory tokens.
/// @param loanId Id of the loan, same as promissory tokenId
/// @param nftCollateralContract Address of the NFT contract
/// @param nftCollateralId TokenId of the NFT collateral
/// @param loanPaymentToken Address of the ERC20 token involved
/// @param loanPrincipalAmount Principal amount of the loan
/// @param maximumRepaymentAmount Maximum amount to be repayed
/// @param loanStartTime Timestamp of when the loan started
/// @param loanDuration Duration of the loan
/// @param loanInterestRate Interest Rate of the loan
/// @param isLoanProrated Flag for interest rate type of loan
struct Loan {
    uint256 loanId;
    address nftCollateralContract;
    uint256 nftCollateralId;
    address loanPaymentToken;
    uint256 loanPrincipalAmount;
    uint256 maximumRepaymentAmount;
    uint256 loanStartTime;
    uint256 loanDuration;
    uint256 loanInterestRate;
    uint256 adminFees;
    bool isLoanProrated;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}