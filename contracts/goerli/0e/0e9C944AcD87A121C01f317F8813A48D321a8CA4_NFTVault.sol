// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IAggregatorV3Interface.sol";
import "../interfaces/IStableCoin.sol";
import "../interfaces/IJPEGCardsCigStaking.sol";
import "../interfaces/IUniswapV2Oracle.sol";

/// @title NFT lending vault
/// @notice This contracts allows users to borrow PUSD using NFTs as collateral.
/// The floor price of the NFT collection is fetched using a chainlink oracle, while some other more valuable traits
/// can have an higher price set by the DAO. Users can also increase the price (and thus the borrow limit) of their
/// NFT by submitting a governance proposal. If the proposal is approved the user can lock a percentage of the new price
/// worth of JPEG to make it effective
contract NFTVault is AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IStableCoin;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    error InvalidNFT(uint256 nftIndex);
    error InvalidRate(Rate rate);
    error InvalidNFTType(bytes32 nftType);
    error InvalidUnlockTime(uint256 unlockTime);
    error InvalidAmount(uint256 amount);
    error InvalidPosition(uint256 nftIndex);
    error PositionLiquidated(uint256 nftIndex);
    error Unauthorized();
    error DebtCapReached();
    error InvalidInsuranceMode();
    error NoDebt();
    error NonZeroDebt(uint256 debtAmount);
    error PositionInsuranceExpired(uint256 nftIndex);
    error PositionInsuranceNotExpired(uint256 nftIndex);
    error ZeroAddress();
    error InvalidOracleResults();
    error NoOracleSet();
    error UnknownAction(uint8 action);

    event PositionOpened(address indexed owner, uint256 indexed index);
    event Borrowed(
        address indexed owner,
        uint256 indexed index,
        uint256 amount
    );
    event Repaid(address indexed owner, uint256 indexed index, uint256 amount);
    event PositionClosed(address indexed owner, uint256 indexed index);
    event Liquidated(
        address indexed liquidator,
        address indexed owner,
        uint256 indexed index,
        bool insured
    );
    event Repurchased(address indexed owner, uint256 indexed index);
    event InsuranceExpired(address indexed owner, uint256 indexed index);
    event DaoFloorChanged(uint256 newFloor);
    event JPEGLocked(
        address indexed owner,
        uint256 indexed index,
        uint256 amount,
        uint256 unlockTime
    );
    event JPEGUnlocked(
        address indexed owner,
        uint256 indexed index,
        uint256 amount
    );

    enum BorrowType {
        NOT_CONFIRMED,
        NON_INSURANCE,
        USE_INSURANCE
    }

    struct Position {
        BorrowType borrowType;
        uint256 debtPrincipal;
        uint256 debtPortion;
        uint256 debtAmountForRepurchase;
        uint256 liquidatedAt;
        address liquidator;
    }

    struct Rate {
        uint128 numerator;
        uint128 denominator;
    }

    struct JPEGLock {
        address owner;
        uint256 unlockAt;
        uint256 lockedValue;
    }

    struct VaultSettings {
        Rate debtInterestApr;
        Rate creditLimitRate;
        Rate liquidationLimitRate;
        Rate cigStakedCreditLimitRate;
        Rate cigStakedLiquidationLimitRate;
        Rate valueIncreaseLockRate;
        Rate organizationFeeRate;
        Rate insurancePurchaseRate;
        Rate insuranceLiquidationPenaltyRate;
        uint256 insuranceRepurchaseTimeLimit;
        uint256 borrowAmountCap;
    }

    bytes32 private constant DAO_ROLE = keccak256("DAO_ROLE");
    bytes32 private constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 private constant SETTER_ROLE = keccak256("SETTER_ROLE");

    //accrue required
    uint8 private constant ACTION_BORROW = 0;
    uint8 private constant ACTION_REPAY = 1;
    uint8 private constant ACTION_CLOSE_POSITION = 2;
    uint8 private constant ACTION_LIQUIDATE = 3;
    //no accrue required
    uint8 private constant ACTION_REPURCHASE = 100;
    uint8 private constant ACTION_CLAIM_NFT = 101;
    uint8 private constant ACTION_TRAIT_BOOST = 102;
    uint8 private constant ACTION_UNLOCK_JPEG = 103;

    IStableCoin public stablecoin;
    /// @notice Chainlink ETH/USD price feed
    IAggregatorV3Interface public ethAggregator;
    /// @notice Chainlink JPEG/USD price feed
    IUniswapV2Oracle public jpegOracle;
    /// @notice Chainlink NFT floor oracle
    IAggregatorV3Interface public floorOracle;
    /// @notice Chainlink NFT fallback floor oracle
    IAggregatorV3Interface public fallbackOracle;
    /// @notice The JPEG token
    /// @custom:oz-renamed-from jpegLocker
    IERC20Upgradeable public jpeg;
    /// @notice JPEGCardsCigStaking, cig stakers get an higher credit limit rate and liquidation limit rate.
    /// Immediately reverts to normal rates if the cig is unstaked.
    IJPEGCardsCigStaking public cigStaking;
    IERC721Upgradeable public nftContract;

    /// @notice If true, the floor price won't be fetched using the Chainlink oracle but
    /// a value set by the DAO will be used instead
    bool public daoFloorOverride;
    // @notice If true, the floor price will be fetched using the fallback oracle
    bool public useFallbackOracle;
    /// @notice Total outstanding debt
    uint256 public totalDebtAmount;
    /// @dev Last time debt was accrued. See {accrue} for more info
    uint256 private totalDebtAccruedAt;
    uint256 public totalFeeCollected;
    uint256 private totalDebtPortion;

    VaultSettings public settings;

    /// @dev Keeps track of all the NFTs used as collateral for positions
    EnumerableSetUpgradeable.UintSet private positionIndexes;

    mapping(uint256 => Position) public positions;
    mapping(uint256 => address) public positionOwner;
    /// @custom:oz-renamed-from nftTypeValueETH
    mapping(bytes32 => uint256) private unused1; //unused after upgrade
    /// @custom:oz-renamed-from nftValueETH
    mapping(uint256 => uint256) private unused2; //unused after upgrade
    //bytes32(0) is floor
    mapping(uint256 => bytes32) public nftTypes;

    /// @notice Value of floor set by the DAO. Only used if `daoFloorOverride` is true
    uint256 private overriddenFloorValueETH;

    uint256 public minJPEGToLock;
    /// @notice The trait value multiplier for non floor NFTs. See {applyTraitBoost} for more info.
    mapping(bytes32 => Rate) public nftTypeValueMultiplier;
    /// @notice The JPEG locks. See {applyTraitBoost} for more info.
    mapping(uint256 => JPEGLock) public lockPositions;

    /// @dev Checks if the provided NFT index is valid
    /// @param nftIndex The index to check
    modifier validNFTIndex(uint256 nftIndex) {
        //The standard OZ ERC721 implementation of ownerOf reverts on a non existing nft isntead of returning address(0)
        if (nftContract.ownerOf(nftIndex) == address(0))
            revert InvalidNFT(nftIndex);
        _;
    }

    struct NFTCategoryInitializer {
        bytes32 hash;
        Rate valueMultiplier;
        uint256[] nfts;
    }

    /// @notice This function is only called once during deployment of the proxy contract. It's not called after upgrades.
    /// @param _stablecoin PUSD address
    /// @param _nftContract The NFT contrat address. It could also be the address of an helper contract
    /// if the target NFT isn't an ERC721 (CryptoPunks as an example)
    /// @param _ethAggregator Chainlink ETH/USD price feed address
    /// @param _floorOracle Chainlink floor oracle address
    /// @param _typeInitializers Used to initialize NFT categories with their value and NFT indexes.
    /// Floor NFT shouldn't be initialized this way
    /// @param _settings Initial settings used by the contract
    function initialize(
        IStableCoin _stablecoin,
        IERC20Upgradeable _jpeg,
        IERC721Upgradeable _nftContract,
        IAggregatorV3Interface _ethAggregator,
        IAggregatorV3Interface _floorOracle,
        NFTCategoryInitializer[] calldata _typeInitializers,
        IJPEGCardsCigStaking _cigStaking,
        VaultSettings calldata _settings
    ) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _setupRole(DAO_ROLE, msg.sender);
        _setRoleAdmin(LIQUIDATOR_ROLE, DAO_ROLE);
        _setRoleAdmin(SETTER_ROLE, DAO_ROLE);
        _setRoleAdmin(DAO_ROLE, DAO_ROLE);

        _validateRateBelowOne(_settings.debtInterestApr);
        _validateRateBelowOne(_settings.creditLimitRate);
        _validateRateBelowOne(_settings.liquidationLimitRate);
        _validateRateBelowOne(_settings.cigStakedCreditLimitRate);
        _validateRateBelowOne(_settings.cigStakedLiquidationLimitRate);
        _validateRateBelowOne(_settings.valueIncreaseLockRate);
        _validateRateBelowOne(_settings.organizationFeeRate);
        _validateRateBelowOne(_settings.insurancePurchaseRate);
        _validateRateBelowOne(_settings.insuranceLiquidationPenaltyRate);

        if (
            !_greaterThan(
                _settings.liquidationLimitRate,
                _settings.creditLimitRate
            )
        ) revert InvalidRate(_settings.liquidationLimitRate);

        if (
            !_greaterThan(
                _settings.cigStakedLiquidationLimitRate,
                _settings.cigStakedCreditLimitRate
            )
        ) revert InvalidRate(_settings.cigStakedLiquidationLimitRate);

        if (
            !_greaterThan(
                _settings.cigStakedCreditLimitRate,
                _settings.creditLimitRate
            )
        ) revert InvalidRate(_settings.cigStakedCreditLimitRate);

        if (
            !_greaterThan(
                _settings.cigStakedLiquidationLimitRate,
                _settings.liquidationLimitRate
            )
        ) revert InvalidRate(_settings.cigStakedLiquidationLimitRate);

        stablecoin = _stablecoin;
        jpeg = _jpeg;
        ethAggregator = _ethAggregator;
        floorOracle = _floorOracle;
        cigStaking = _cigStaking;
        nftContract = _nftContract;

        settings = _settings;

        //initializing the categories
        for (uint256 i; i < _typeInitializers.length; ++i) {
            NFTCategoryInitializer memory initializer = _typeInitializers[i];
            if (initializer.hash == bytes32(0))
                revert InvalidNFTType(initializer.hash);
            _validateRateAboveOne(initializer.valueMultiplier);
            nftTypeValueMultiplier[initializer.hash] = initializer
                .valueMultiplier;
            for (uint256 j; j < initializer.nfts.length; j++) {
                nftTypes[initializer.nfts[j]] = initializer.hash;
            }
        }
    }

    /// @dev Function called by the {ProxyAdmin} contract during the upgrade process.
    /// Only called on existing vaults where the `initialize` function has already been called.
    /// It won't be called in new deployments.
    /// Sets the JPEG token address, migrates overridden floor to the new `overriddenFloorValueETH` variable,
    /// clears the `unused1` mapping and sets `DAO_ROLE` as admin for the `SETTER_ROLE`.
    function finalizeUpgrade(IERC20Upgradeable _jpeg, bytes32[] memory _toClear)
        external
    {
        require(address(jpeg) == address(0)); //already finalized
        if (address(_jpeg) == address(0)) revert ZeroAddress();

        _setRoleAdmin(SETTER_ROLE, DAO_ROLE);

        jpeg = _jpeg;
        overriddenFloorValueETH = unused1[bytes32(0)];

        for (uint256 i; i < _toClear.length; ++i) {
            delete unused1[_toClear[i]];
        }
    }

    /// @notice Returns the number of open positions
    /// @return The number of open positions
    function totalPositions() external view returns (uint256) {
        return positionIndexes.length();
    }

    /// @notice Returns all open position NFT indexes
    /// @return The open position NFT indexes
    function openPositionsIndexes() external view returns (uint256[] memory) {
        return positionIndexes.values();
    }

    /// @param _nftIndex The NFT to return the value of
    /// @return The value in ETH of the NFT at index `_nftIndex`, with 18 decimals.
    function getNFTValueETH(uint256 _nftIndex) public view returns (uint256) {
        uint256 floor = getFloorETH();

        bytes32 nftType = nftTypes[_nftIndex];
        if (
            nftType != bytes32(0) &&
            lockPositions[_nftIndex].unlockAt > block.timestamp
        ) {
            Rate memory multiplier = nftTypeValueMultiplier[nftType];
            return (floor * multiplier.numerator) / multiplier.denominator;
        } else return floor;
    }

    /// @param _nftIndex The NFT to return the value of
    /// @return The value in USD of the NFT at index `_nftIndex`, with 18 decimals.
    function getNFTValueUSD(uint256 _nftIndex) public view returns (uint256) {
        uint256 nftValue = getNFTValueETH(_nftIndex);
        return (nftValue * _ethPriceUSD()) / 1 ether;
    }

    /// @param _nftType The NFT type to calculate the JPEG lock amount for
    /// @param _jpegPrice The JPEG price in ETH (18 decimals)
    /// @return The JPEG to lock for the specified `_nftType`
    function calculateJPEGToLock(bytes32 _nftType, uint256 _jpegPrice)
        public
        view
        returns (uint256)
    {
        Rate memory multiplier = nftTypeValueMultiplier[_nftType];

        if (multiplier.numerator == 0 || multiplier.denominator == 0) return 0;

        uint256 floorETH = getFloorETH();
        return
            (((floorETH * multiplier.numerator) /
                multiplier.denominator -
                floorETH) *
                1 ether *
                settings.valueIncreaseLockRate.numerator *
                settings.creditLimitRate.numerator) /
            settings.valueIncreaseLockRate.denominator /
            settings.creditLimitRate.denominator /
            _jpegPrice;
    }

    /// @param _nftIndex The NFT to return the credit limit of
    /// @return The PUSD credit limit of the NFT at index `_nftIndex`.
    function getCreditLimit(uint256 _nftIndex) external view returns (uint256) {
        return _getCreditLimit(positionOwner[_nftIndex], _nftIndex);
    }

    /// @param _nftIndex The NFT to return the liquidation limit of
    /// @return The PUSD liquidation limit of the NFT at index `_nftIndex`.
    function getLiquidationLimit(uint256 _nftIndex)
        public
        view
        returns (uint256)
    {
        return _getLiquidationLimit(positionOwner[_nftIndex], _nftIndex);
    }

    /// @param _nftIndex The NFT to check
    /// @return Whether the NFT at index `_nftIndex` is liquidatable.
    function isLiquidatable(uint256 _nftIndex) external view returns (bool) {
        Position storage position = positions[_nftIndex];
        if (position.borrowType == BorrowType.NOT_CONFIRMED) return false;
        if (position.liquidatedAt > 0) return false;

        uint256 principal = position.debtPrincipal;
        return
            principal + getDebtInterest(_nftIndex) >=
            getLiquidationLimit(_nftIndex);
    }

    /// @param _nftIndex The NFT to check
    /// @return The PUSD debt interest accumulated by the NFT at index `_nftIndex`.
    function getDebtInterest(uint256 _nftIndex) public view returns (uint256) {
        Position storage position = positions[_nftIndex];
        uint256 principal = position.debtPrincipal;
        uint256 debt = position.liquidatedAt != 0
            ? position.debtAmountForRepurchase
            : _calculateDebt(
                totalDebtAmount + _calculateAdditionalInterest(),
                position.debtPortion,
                totalDebtPortion
            );

        //_calculateDebt is prone to rounding errors that may cause
        //the calculated debt amount to be 1 or 2 units less than
        //the debt principal if no time has elapsed in between the first borrow
        //and the _calculateDebt call.
        if (principal > debt) debt = principal;

        unchecked {
            return debt - principal;
        }
    }

    /// @return The floor value for the collection, in ETH.
    function getFloorETH() public view returns (uint256) {
        if (daoFloorOverride) return overriddenFloorValueETH;
        else
            return
                _normalizeAggregatorAnswer(
                    useFallbackOracle ? fallbackOracle : floorOracle
                );
    }

    /// @dev The {accrue} function updates the contract's state by calculating
    /// the additional interest accrued since the last state update
    function accrue() public {
        uint256 additionalInterest = _calculateAdditionalInterest();

        totalDebtAccruedAt = block.timestamp;

        totalDebtAmount += additionalInterest;
        totalFeeCollected += additionalInterest;
    }

    /// @notice Allows to execute multiple actions in a single transaction.
    /// @param _actions The actions to execute.
    /// @param _datas The abi encoded parameters for the actions to execute.
    function doActions(uint8[] calldata _actions, bytes[] calldata _datas)
        external
        nonReentrant
    {
        if (_actions.length != _datas.length) revert();
        bool accrueCalled;
        for (uint256 i; i < _actions.length; ++i) {
            uint8 action = _actions[i];
            if (!accrueCalled && action < 100) {
                accrue();
                accrueCalled = true;
            }

            if (action == ACTION_BORROW) {
                (uint256 nftIndex, uint256 amount, bool useInsurance) = abi
                    .decode(_datas[i], (uint256, uint256, bool));
                _borrow(nftIndex, amount, useInsurance);
            } else if (action == ACTION_REPAY) {
                (uint256 nftIndex, uint256 amount) = abi.decode(
                    _datas[i],
                    (uint256, uint256)
                );
                _repay(nftIndex, amount);
            } else if (action == ACTION_CLOSE_POSITION) {
                uint256 nftIndex = abi.decode(_datas[i], (uint256));
                _closePosition(nftIndex);
            } else if (action == ACTION_LIQUIDATE) {
                (uint256 nftIndex, address recipient) = abi.decode(
                    _datas[i],
                    (uint256, address)
                );
                _liquidate(nftIndex, recipient);
            } else if (action == ACTION_REPURCHASE) {
                uint256 nftIndex = abi.decode(_datas[i], (uint256));
                _repurchase(nftIndex);
            } else if (action == ACTION_CLAIM_NFT) {
                (uint256 nftIndex, address recipient) = abi.decode(
                    _datas[i],
                    (uint256, address)
                );
                _claimExpiredInsuranceNFT(nftIndex, recipient);
            } else if (action == ACTION_TRAIT_BOOST) {
                (uint256 nftIndex, uint256 unlockAt) = abi.decode(
                    _datas[i],
                    (uint256, uint256)
                );
                _applyTraitBoost(nftIndex, unlockAt);
            } else if (action == ACTION_UNLOCK_JPEG) {
                uint256 nftIndex = abi.decode(_datas[i], (uint256));
                _unlockJPEG(nftIndex);
            } else {
                revert UnknownAction(action);
            }
        }
    }

    /// @notice Allows users to lock JPEG tokens to unlock the trait boost for a single non floor NFT.
    /// The trait boost is a multiplicative value increase relative to the collection's floor.
    /// The value increase depends on the NFT's traits and it's set by the DAO.
    /// The ETH value of the JPEG to lock is calculated by applying the `valueIncreaseLockRate` rate to the NFT's new credit limit.
    /// The unlock time is set by the user and has to be greater than `block.timestamp` and the previous unlock time.
    /// After the lock expires, the boost is revoked and the NFT's value goes back to floor.
    /// If a boosted position is closed or liquidated, the JPEG remains locked and the boost will still be applied in case the NFT
    /// is deposited again, even in case of a different owner. The locked JPEG will only be claimable by the original lock creator
    /// once the lock expires. If the lock is renewed by the new owner, the JPEG from the previous lock will be sent back to the original
    /// lock creator.
    /// @dev emits a {JPEGLocked} event
    /// @param _nftIndex The index of the NFT to boost (has to be a non floor NFT)
    /// @param _unlockAt The lock expiration time.
    function applyTraitBoost(uint256 _nftIndex, uint256 _unlockAt)
        external
        nonReentrant
    {
        _applyTraitBoost(_nftIndex, _unlockAt);
    }

    /// @notice Allows lock creators to unlock the JPEG associated to the NFT at index `_nftIndex`, provided the lock expired.
    /// @dev emits a {JPEGUnlocked} event
    /// @param _nftIndex The index of the NFT holding the lock.
    function unlockJPEG(uint256 _nftIndex) external nonReentrant {
        _unlockJPEG(_nftIndex);
    }

    /// @notice Allows users to open positions and borrow using an NFT
    /// @dev emits a {Borrowed} event
    /// @param _nftIndex The index of the NFT to be used as collateral
    /// @param _amount The amount of PUSD to be borrowed. Note that the user will receive less than the amount requested,
    /// the borrow fee and insurance automatically get removed from the amount borrowed
    /// @param _useInsurance Whereter to open an insured position. In case the position has already been opened previously,
    /// this parameter needs to match the previous insurance mode. To change insurance mode, a user needs to close and reopen the position
    function borrow(
        uint256 _nftIndex,
        uint256 _amount,
        bool _useInsurance
    ) external nonReentrant {
        accrue();
        _borrow(_nftIndex, _amount, _useInsurance);
    }

    /// @notice Allows users to repay a portion/all of their debt. Note that since interest increases every second,
    /// a user wanting to repay all of their debt should repay for an amount greater than their current debt to account for the
    /// additional interest while the repay transaction is pending, the contract will only take what's necessary to repay all the debt
    /// @dev Emits a {Repaid} event
    /// @param _nftIndex The NFT used as collateral for the position
    /// @param _amount The amount of debt to repay. If greater than the position's outstanding debt, only the amount necessary to repay all the debt will be taken
    function repay(uint256 _nftIndex, uint256 _amount) external nonReentrant {
        accrue();
        _repay(_nftIndex, _amount);
    }

    /// @notice Allows a user to close a position and get their collateral back, if the position's outstanding debt is 0
    /// @dev Emits a {PositionClosed} event
    /// @param _nftIndex The index of the NFT used as collateral
    function closePosition(uint256 _nftIndex) external nonReentrant {
        accrue();
        _closePosition(_nftIndex);
    }

    /// @notice Allows members of the `LIQUIDATOR_ROLE` to liquidate a position. Positions can only be liquidated
    /// once their debt amount exceeds the minimum liquidation debt to collateral value rate.
    /// In order to liquidate a position, the liquidator needs to repay the user's outstanding debt.
    /// If the position is not insured, it's closed immediately and the collateral is sent to `_recipient`.
    /// If the position is insured, the position remains open (interest doesn't increase) and the owner of the position has a certain amount of time
    /// (`insuranceRepurchaseTimeLimit`) to fully repay the liquidator and pay an additional liquidation fee (`insuranceLiquidationPenaltyRate`), if this
    /// is done in time the user gets back their collateral and their position is automatically closed. If the user doesn't repurchase their collateral
    /// before the time limit passes, the liquidator can claim the liquidated NFT and the position is closed
    /// @dev Emits a {Liquidated} event
    /// @param _nftIndex The NFT to liquidate
    /// @param _recipient The address to send the NFT to
    function liquidate(uint256 _nftIndex, address _recipient)
        external
        nonReentrant
    {
        accrue();
        _liquidate(_nftIndex, _recipient);
    }

    /// @notice Allows liquidated users who purchased insurance to repurchase their collateral within the time limit
    /// defined with the `insuranceRepurchaseTimeLimit`. The user needs to pay the liquidator the total amount of debt
    /// the position had at the time of liquidation, plus an insurance liquidation fee defined with `insuranceLiquidationPenaltyRate`
    /// @dev Emits a {Repurchased} event
    /// @param _nftIndex The NFT to repurchase
    function repurchase(uint256 _nftIndex) external nonReentrant {
        _repurchase(_nftIndex);
    }

    /// @notice Allows the liquidator who liquidated the insured position with NFT at index `_nftIndex` to claim the position's collateral
    /// after the time period defined with `insuranceRepurchaseTimeLimit` has expired and the position owner has not repurchased the collateral.
    /// @dev Emits an {InsuranceExpired} event
    /// @param _nftIndex The NFT to claim
    /// @param _recipient The address to send the NFT to
    function claimExpiredInsuranceNFT(uint256 _nftIndex, address _recipient)
        external
        nonReentrant
    {
        _claimExpiredInsuranceNFT(_nftIndex, _recipient);
    }

    /// @notice Allows the DAO to collect interest and fees before they are repaid
    function collect() external nonReentrant onlyRole(DAO_ROLE) {
        accrue();
        stablecoin.mint(msg.sender, totalFeeCollected);
        totalFeeCollected = 0;
    }

    /// @notice Allows the setter contract to change fields in the `VaultSettings` struct.
    /// @dev Validation and single field setting is handled by an external contract with the
    /// `SETTER_ROLE`. This was done to reduce the contract's size.
    function setSettings(VaultSettings calldata _settings)
        external
        onlyRole(SETTER_ROLE)
    {
        settings = _settings;
    }

    /// @notice Allows the DAO to toggle the fallback oracle
    /// @param _useFallback Whether to use the fallback oracle
    function toggleFallbackOracle(bool _useFallback)
        external
        onlyRole(DAO_ROLE)
    {
        require(address(fallbackOracle) != address(0));
        useFallbackOracle = _useFallback;
    }

    /// @notice Allows the DAO to bypass the floor oracle and override the NFT floor value
    /// @param _newFloor The new floor
    function overrideFloor(uint256 _newFloor) external onlyRole(DAO_ROLE) {
        if (_newFloor == 0) revert InvalidAmount(_newFloor);
        overriddenFloorValueETH = _newFloor;
        daoFloorOverride = true;

        emit DaoFloorChanged(_newFloor);
    }

    /// @notice Allows the DAO to stop overriding floor
    function disableFloorOverride() external onlyRole(DAO_ROLE) {
        daoFloorOverride = false;
    }

    /// @notice Allows the DAO to add an NFT to a specific price category
    /// @param _nftIndexes The indexes to add to the category
    /// @param _type The category hash
    function setNFTType(uint256[] calldata _nftIndexes, bytes32 _type)
        external
        onlyRole(DAO_ROLE)
    {
        if (_type != bytes32(0) && nftTypeValueMultiplier[_type].numerator == 0)
            revert InvalidNFTType(_type);

        for (uint256 i; i < _nftIndexes.length; ++i) {
            nftTypes[_nftIndexes[i]] = _type;
        }
    }

    /// @notice Allows the DAO to change the multiplier of an NFT category
    /// @param _type The category hash
    /// @param _multiplier The new multiplier
    function setNFTTypeMultiplier(bytes32 _type, Rate calldata _multiplier)
        external
        onlyRole(DAO_ROLE)
    {
        if (_type == bytes32(0)) revert InvalidNFTType(_type);
        _validateRateAboveOne(_multiplier);
        nftTypeValueMultiplier[_type] = _multiplier;
    }

    /// @notice Allows the DAO to set the JPEG oracle
    /// @param _oracle new oracle address
    function setjpegOracle(IUniswapV2Oracle _oracle)
        external
        onlyRole(DAO_ROLE)
    {
        if (address(_oracle) == address(0)) revert ZeroAddress();

        jpegOracle = _oracle;
    }

    /// @notice Allows the DAO to change fallback oracle
    /// @param _fallback new fallback address
    function setFallbackOracle(IAggregatorV3Interface _fallback)
        external
        onlyRole(DAO_ROLE)
    {
        if (address(_fallback) == address(0)) revert ZeroAddress();

        fallbackOracle = _fallback;
    }

    /// @notice Allows the DAO to change the minimum amount of JPEG to lock to unlock the trait boost
    function setMinJPEGToLock(uint256 _newAmount) external onlyRole(DAO_ROLE) {
        if (_newAmount == 0) revert InvalidAmount(_newAmount);

        minJPEGToLock = _newAmount;
    }

    /// @dev See {applyTraitBoost}
    function _applyTraitBoost(uint256 _nftIndex, uint256 _unlockAt)
        internal
        validNFTIndex(_nftIndex)
    {
        bytes32 nftType = nftTypes[_nftIndex];
        if (nftType == bytes32(0)) revert InvalidNFTType(nftType);

        JPEGLock storage jpegLock = lockPositions[_nftIndex];
        if (block.timestamp >= _unlockAt || jpegLock.unlockAt >= _unlockAt)
            revert InvalidUnlockTime(_unlockAt);

        uint256 jpegToLock = calculateJPEGToLock(nftType, _jpegPriceETH());

        if (minJPEGToLock >= jpegToLock) revert InvalidNFTType(nftType);

        uint256 previousLockValue = jpegLock.lockedValue;
        address previousOwner = jpegLock.owner;

        jpegLock.lockedValue = jpegToLock;
        jpegLock.unlockAt = _unlockAt;
        jpegLock.owner = msg.sender;

        if (previousOwner == msg.sender) {
            if (jpegToLock > previousLockValue)
                jpeg.safeTransferFrom(
                    msg.sender,
                    address(this),
                    jpegToLock - previousLockValue
                );
            else if (previousLockValue > jpegToLock)
                jpeg.safeTransfer(msg.sender, previousLockValue - jpegToLock);
        } else {
            if (previousLockValue > 0)
                jpeg.safeTransfer(previousOwner, previousLockValue);
            jpeg.safeTransferFrom(msg.sender, address(this), jpegToLock);
        }

        emit JPEGLocked(msg.sender, _nftIndex, jpegToLock, _unlockAt);
    }

    /// @dev See {unlockJPEG}
    function _unlockJPEG(uint256 _nftIndex) internal validNFTIndex(_nftIndex) {
        JPEGLock memory jpegLock = lockPositions[_nftIndex];
        if (jpegLock.owner != msg.sender) revert Unauthorized();

        if (block.timestamp < jpegLock.unlockAt) revert Unauthorized();

        delete lockPositions[_nftIndex];

        jpeg.safeTransfer(msg.sender, jpegLock.lockedValue);

        emit JPEGUnlocked(msg.sender, _nftIndex, jpegLock.lockedValue);
    }

    /// @dev Opens a position
    /// Emits a {PositionOpened} event
    /// @param _owner The owner of the position to open
    /// @param _nftIndex The NFT used as collateral for the position
    function _openPosition(address _owner, uint256 _nftIndex) internal {
        positionOwner[_nftIndex] = _owner;
        positionIndexes.add(_nftIndex);

        nftContract.transferFrom(_owner, address(this), _nftIndex);

        emit PositionOpened(_owner, _nftIndex);
    }

    /// @dev See {borrow}
    function _borrow(
        uint256 _nftIndex,
        uint256 _amount,
        bool _useInsurance
    ) internal validNFTIndex(_nftIndex) {
        address owner = positionOwner[_nftIndex];
        if (owner != msg.sender && owner != address(0)) revert Unauthorized();

        if (_amount == 0) revert InvalidAmount(_amount);

        if (totalDebtAmount + _amount > settings.borrowAmountCap)
            revert DebtCapReached();

        Position storage position = positions[_nftIndex];
        if (position.liquidatedAt != 0) revert PositionLiquidated(_nftIndex);

        BorrowType borrowType = position.borrowType;
        BorrowType targetBorrowType = _useInsurance
            ? BorrowType.USE_INSURANCE
            : BorrowType.NON_INSURANCE;

        if (borrowType == BorrowType.NOT_CONFIRMED)
            position.borrowType = targetBorrowType;
        else if (borrowType != targetBorrowType) revert InvalidInsuranceMode();

        uint256 creditLimit = _getCreditLimit(msg.sender, _nftIndex);
        uint256 debtAmount = _getDebtAmount(_nftIndex);
        if (debtAmount + _amount > creditLimit) revert InvalidAmount(_amount);

        //calculate the borrow fee
        uint256 organizationFee = (_amount *
            settings.organizationFeeRate.numerator) /
            settings.organizationFeeRate.denominator;

        uint256 feeAmount = organizationFee;
        //if the position is insured, calculate the insurance fee
        if (targetBorrowType == BorrowType.USE_INSURANCE) {
            feeAmount +=
                (_amount * settings.insurancePurchaseRate.numerator) /
                settings.insurancePurchaseRate.denominator;
        }
        totalFeeCollected += feeAmount;

        uint256 debtPortion = totalDebtPortion;
        // update debt portion
        if (debtPortion == 0) {
            totalDebtPortion = _amount;
            position.debtPortion = _amount;
        } else {
            uint256 plusPortion = (debtPortion * _amount) / totalDebtAmount;
            totalDebtPortion = debtPortion + plusPortion;
            position.debtPortion += plusPortion;
        }
        position.debtPrincipal += _amount;
        totalDebtAmount += _amount;

        if (positionOwner[_nftIndex] == address(0)) {
            _openPosition(msg.sender, _nftIndex);
        }

        //subtract the fee from the amount borrowed
        stablecoin.mint(msg.sender, _amount - feeAmount);

        emit Borrowed(msg.sender, _nftIndex, _amount);
    }

    /// @dev See {repay}
    function _repay(uint256 _nftIndex, uint256 _amount)
        internal
        validNFTIndex(_nftIndex)
    {
        if (msg.sender != positionOwner[_nftIndex]) revert Unauthorized();

        if (_amount == 0) revert InvalidAmount(_amount);

        Position storage position = positions[_nftIndex];
        if (position.liquidatedAt > 0) revert PositionLiquidated(_nftIndex);

        uint256 debtAmount = _getDebtAmount(_nftIndex);
        if (debtAmount == 0) revert NoDebt();

        uint256 debtPrincipal = position.debtPrincipal;
        uint256 debtInterest = debtAmount - debtPrincipal;

        _amount = _amount > debtAmount ? debtAmount : _amount;

        // burn all payment, the interest is sent to the DAO using the {collect} function
        stablecoin.burnFrom(msg.sender, _amount);

        uint256 paidPrincipal;

        unchecked {
            paidPrincipal = _amount > debtInterest ? _amount - debtInterest : 0;
        }

        uint256 totalPortion = totalDebtPortion;
        uint256 totalDebt = totalDebtAmount;
        uint256 minusPortion = paidPrincipal == debtPrincipal
            ? position.debtPortion
            : (totalPortion * _amount) / totalDebt;

        totalDebtPortion = totalPortion - minusPortion;
        position.debtPortion -= minusPortion;
        position.debtPrincipal -= paidPrincipal;
        totalDebtAmount = totalDebt - _amount;

        emit Repaid(msg.sender, _nftIndex, _amount);
    }

    /// @dev See {closePosition}
    function _closePosition(uint256 _nftIndex)
        internal
        validNFTIndex(_nftIndex)
    {
        if (msg.sender != positionOwner[_nftIndex]) revert Unauthorized();
        if (positions[_nftIndex].liquidatedAt > 0)
            revert PositionLiquidated(_nftIndex);
        uint256 debt = _getDebtAmount(_nftIndex);
        if (debt > 0) revert NonZeroDebt(debt);

        positionOwner[_nftIndex] = address(0);
        delete positions[_nftIndex];
        positionIndexes.remove(_nftIndex);

        // transfer nft back to owner if nft was deposited
        if (nftContract.ownerOf(_nftIndex) == address(this)) {
            nftContract.safeTransferFrom(address(this), msg.sender, _nftIndex);
        }

        emit PositionClosed(msg.sender, _nftIndex);
    }

    /// @dev See {liquidate}
    function _liquidate(uint256 _nftIndex, address _recipient)
        internal
        onlyRole(LIQUIDATOR_ROLE)
        validNFTIndex(_nftIndex)
    {
        address posOwner = positionOwner[_nftIndex];
        if (posOwner == address(0)) revert InvalidPosition(_nftIndex);

        Position storage position = positions[_nftIndex];
        if (position.liquidatedAt > 0) revert PositionLiquidated(_nftIndex);

        uint256 debtAmount = _getDebtAmount(_nftIndex);
        if (debtAmount < _getLiquidationLimit(posOwner, _nftIndex))
            revert InvalidPosition(_nftIndex);

        // burn all payment
        stablecoin.burnFrom(msg.sender, debtAmount);

        // update debt portion
        totalDebtPortion -= position.debtPortion;
        totalDebtAmount -= debtAmount;
        position.debtPortion = 0;

        bool insured = position.borrowType == BorrowType.USE_INSURANCE;
        if (insured) {
            position.debtAmountForRepurchase = debtAmount;
            position.liquidatedAt = block.timestamp;
            position.liquidator = msg.sender;
        } else {
            // transfer nft to liquidator
            positionOwner[_nftIndex] = address(0);
            delete positions[_nftIndex];
            positionIndexes.remove(_nftIndex);
            nftContract.transferFrom(address(this), _recipient, _nftIndex);
        }

        emit Liquidated(msg.sender, posOwner, _nftIndex, insured);
    }

    /// @dev See {repurchase}
    function _repurchase(uint256 _nftIndex) internal validNFTIndex(_nftIndex) {
        Position memory position = positions[_nftIndex];
        if (msg.sender != positionOwner[_nftIndex]) revert Unauthorized();
        if (position.liquidatedAt == 0) revert InvalidPosition(_nftIndex);
        if (position.borrowType != BorrowType.USE_INSURANCE)
            revert InvalidPosition(_nftIndex);
        if (
            block.timestamp >=
            position.liquidatedAt + settings.insuranceRepurchaseTimeLimit
        ) revert PositionInsuranceExpired(_nftIndex);

        uint256 debtAmount = position.debtAmountForRepurchase;
        uint256 penalty = (debtAmount *
            settings.insuranceLiquidationPenaltyRate.numerator) /
            settings.insuranceLiquidationPenaltyRate.denominator;

        // transfer nft to user
        positionOwner[_nftIndex] = address(0);
        delete positions[_nftIndex];
        positionIndexes.remove(_nftIndex);

        // transfer payment to liquidator
        stablecoin.safeTransferFrom(
            msg.sender,
            position.liquidator,
            debtAmount + penalty
        );

        nftContract.safeTransferFrom(address(this), msg.sender, _nftIndex);

        emit Repurchased(msg.sender, _nftIndex);
    }

    /// @dev See {claimExpiredInsuranceNFT}
    function _claimExpiredInsuranceNFT(uint256 _nftIndex, address _recipient)
        internal
        validNFTIndex(_nftIndex)
    {
        if (_recipient == address(0)) revert ZeroAddress();
        Position memory position = positions[_nftIndex];
        address owner = positionOwner[_nftIndex];
        if (owner == address(0)) revert InvalidPosition(_nftIndex);
        if (position.liquidatedAt == 0) revert InvalidPosition(_nftIndex);
        if (
            position.liquidatedAt + settings.insuranceRepurchaseTimeLimit >
            block.timestamp
        ) revert PositionInsuranceNotExpired(_nftIndex);
        if (position.liquidator != msg.sender) revert Unauthorized();

        positionOwner[_nftIndex] = address(0);
        delete positions[_nftIndex];
        positionIndexes.remove(_nftIndex);

        nftContract.transferFrom(address(this), _recipient, _nftIndex);

        emit InsuranceExpired(owner, _nftIndex);
    }

    /// @dev Returns the credit limit of an NFT
    /// @param _nftIndex The NFT to return credit limit of
    /// @return The NFT credit limit
    function _getCreditLimit(address user, uint256 _nftIndex)
        internal
        view
        returns (uint256)
    {
        uint256 value = getNFTValueUSD(_nftIndex);
        if (cigStaking.isUserStaking(user)) {
            return
                (value * settings.cigStakedCreditLimitRate.numerator) /
                settings.cigStakedCreditLimitRate.denominator;
        }
        return
            (value * settings.creditLimitRate.numerator) /
            settings.creditLimitRate.denominator;
    }

    /// @dev Returns the minimum amount of debt necessary to liquidate an NFT
    /// @param _nftIndex The index of the NFT
    /// @return The minimum amount of debt to liquidate the NFT
    function _getLiquidationLimit(address user, uint256 _nftIndex)
        internal
        view
        returns (uint256)
    {
        uint256 value = getNFTValueUSD(_nftIndex);
        if (cigStaking.isUserStaking(user)) {
            return
                (value * settings.cigStakedLiquidationLimitRate.numerator) /
                settings.cigStakedLiquidationLimitRate.denominator;
        }
        return
            (value * settings.liquidationLimitRate.numerator) /
            settings.liquidationLimitRate.denominator;
    }

    /// @dev Calculates current outstanding debt of an NFT
    /// @param _nftIndex The NFT to calculate the outstanding debt of
    /// @return The outstanding debt value
    function _getDebtAmount(uint256 _nftIndex) internal view returns (uint256) {
        uint256 calculatedDebt = _calculateDebt(
            totalDebtAmount,
            positions[_nftIndex].debtPortion,
            totalDebtPortion
        );

        uint256 principal = positions[_nftIndex].debtPrincipal;

        //_calculateDebt is prone to rounding errors that may cause
        //the calculated debt amount to be 1 or 2 units less than
        //the debt principal when the accrue() function isn't called
        //in between the first borrow and the _calculateDebt call.
        return principal > calculatedDebt ? principal : calculatedDebt;
    }

    /// @dev Calculates the total debt of a position given the global debt, the user's portion of the debt and the total user portions
    /// @param total The global outstanding debt
    /// @param userPortion The user's portion of debt
    /// @param totalPortion The total user portions of debt
    /// @return The outstanding debt of the position
    function _calculateDebt(
        uint256 total,
        uint256 userPortion,
        uint256 totalPortion
    ) internal pure returns (uint256) {
        return totalPortion == 0 ? 0 : (total * userPortion) / totalPortion;
    }

    /// @dev Calculates the additional global interest since last time the contract's state was updated by calling {accrue}
    /// @return The additional interest value
    function _calculateAdditionalInterest() internal view returns (uint256) {
        // Number of seconds since {accrue} was called
        uint256 elapsedTime = block.timestamp - totalDebtAccruedAt;
        if (elapsedTime == 0) {
            return 0;
        }

        uint256 totalDebt = totalDebtAmount;
        if (totalDebt == 0) {
            return 0;
        }

        // Accrue interest
        return
            (elapsedTime * totalDebt * settings.debtInterestApr.numerator) /
            settings.debtInterestApr.denominator /
            365 days;
    }

    /// @dev Returns the current ETH price in USD
    /// @return The current ETH price, 18 decimals
    function _ethPriceUSD() internal view returns (uint256) {
        return _normalizeAggregatorAnswer(ethAggregator);
    }

    /// @dev Returns the current JPEG price in ETH
    /// @return result The current JPEG price, 18 decimals
    function _jpegPriceETH() internal returns (uint256 result) {
        IUniswapV2Oracle oracle = jpegOracle;
        if (address(oracle) == address(0)) revert NoOracleSet();
        result = oracle.consultAndUpdateIfNecessary(address(jpeg), 1 ether);
        if (result == 0) revert InvalidOracleResults();
    }

    /// @dev Fetches and converts to 18 decimals precision the latest answer of a Chainlink aggregator
    /// @param aggregator The aggregator to fetch the answer from
    /// @return The latest aggregator answer, normalized
    function _normalizeAggregatorAnswer(IAggregatorV3Interface aggregator)
        internal
        view
        returns (uint256)
    {
        (, int256 answer, , uint256 timestamp, ) = aggregator.latestRoundData();

        if (answer == 0 || timestamp == 0) revert InvalidOracleResults();

        uint8 decimals = aggregator.decimals();

        unchecked {
            //converts the answer to have 18 decimals
            return
                decimals > 18
                    ? uint256(answer) / 10**(decimals - 18)
                    : uint256(answer) * 10**(18 - decimals);
        }
    }

    /// @dev Checks if `r1` is greater than `r2`.
    function _greaterThan(Rate memory _r1, Rate memory _r2)
        internal
        pure
        returns (bool)
    {
        return
            _r1.numerator * _r2.denominator > _r2.numerator * _r1.denominator;
    }

    /// @dev Validates a rate. The denominator must be greater than zero and greater than or equal to the numerator.
    /// @param _rate The rate to validate
    function _validateRateBelowOne(Rate memory _rate) internal pure {
        if (_rate.denominator == 0 || _rate.denominator < _rate.numerator)
            revert InvalidRate(_rate);
    }

    /// @dev Validates a rate. The denominator must be greater than zero and less than or equal to the numerator.
    /// @param _rate The rate to validate
    function _validateRateAboveOne(Rate memory _rate) internal pure {
        if (_rate.denominator == 0 || _rate.numerator < _rate.denominator)
            revert InvalidRate(_rate);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IAggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IStableCoin is IERC20Upgradeable {
    function mint(address _to, uint256 _value) external;

    function burn(uint256 _value) external;

    function burnFrom(address _from, uint256 _value) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IJPEGCardsCigStaking {
    function isUserStaking(address _user) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IUniswapV2Oracle {
    function consultAndUpdateIfNecessary(address token, uint256 amountIn)
        external
        returns (uint256);
    
    function consultUpdated(address token, uint256 amountIn)
        external
        returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
}